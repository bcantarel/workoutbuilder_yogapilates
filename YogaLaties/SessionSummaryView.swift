//
//  SessionSummaryView.swift
//  YogaLaties
//
//  Step 16 — Session Summary Screen
//
//  Displayed after the last exercise completes. Shows the user what they
//  accomplished — total time, exercise count, yoga/pilates mix — and lets
//  them replay the routine or head back to My Routines.
//
//  CGI ANALOGY: The **Render Complete Report** that pops up when the farm
//  finishes a sequence. It shows:
//    • Total render time (wall-clock duration of the session)
//    • Shots completed (exercise count)
//    • Category breakdown (yoga / pilates — like VFX vs. animation shots)
//    • A per-shot summary table (the exercise recap list)
//    • Two actions: "Resubmit" (Go Again) or "Close" (Done)
//  The report reads from the same shot list the engine used, so the stats
//  are always accurate even if the user skipped exercises.
//
//  Key SwiftUI concepts introduced in this file
//  ─────────────────────────────────────────────
//  .onAppear + withAnimation
//    We use a local @State Bool that flips on appear to trigger the trophy
//    bounce. Wrapping the state change in `withAnimation` tells SwiftUI to
//    animate everything that changes as a result — in this case the scale
//    and opacity of the trophy icon.
//    CGI ANALOGY: A deferred spawn that fires when the report window opens,
//    triggering a short camera-shake or particle burst to celebrate.
//
//  LazyVStack
//    Like VStack but only builds each row when it scrolls into view.
//    For a short exercise list it makes no difference, but it's a good
//    habit that scales well when lists grow.
//    CGI ANALOGY: Level-of-detail loading — only materialise geometry that
//    is actually on screen.
//

import SwiftUI
import SwiftData


// ─────────────────────────────────────────────
// MARK: - SessionSummaryView
// ─────────────────────────────────────────────

struct SessionSummaryView: View {

    // Passed in from ActiveSessionView.
    let routine: Routine
    let library: [Exercise]

    // Called when the user taps "Go Again" — the parent resets and restarts.
    let onReplay: () -> Void

    // ── Environment ────────────────────────────────────────────────────────
    // `dismiss` lets this view pop itself off the navigation stack,
    // equivalent to tapping the Back button.
    //
    // CGI ANALOGY: The "Close Report" button that sends a close-window event
    // back to the application host, which is responsible for destroying it.
    @Environment(\.dismiss) private var dismiss

    // ── Animation state ────────────────────────────────────────────────────
    // Starts false; flips to true on .onAppear to trigger the trophy bounce.
    @State private var showTrophy = false


    // ─────────────────────────────────────────────
    // MARK: - Computed stats
    // ─────────────────────────────────────────────

    // Slots sorted into the order they were performed.
    // CGI ANALOGY: The shot list sorted by cut-order index, matching the
    // sequence in which the farm rendered them.
    private var sortedSlots: [RoutineExercise] {
        routine.exercises.sorted { $0.sortIndex < $1.sortIndex }
    }

    // Sum of every exercise's effective duration (respects per-slot overrides).
    // CGI ANALOGY: Total wall-clock render time across all shots.
    private var totalSeconds: Int {
        sortedSlots.reduce(0) { $0 + $1.effectiveDuration(in: library) }
    }

    // Human-readable time string: "8m 30s" or just "45s".
    private var formattedTime: String {
        let m = totalSeconds / 60
        let s = totalSeconds % 60
        return m > 0 ? "\(m)m \(s)s" : "\(s)s"
    }

    // How many exercises were yoga vs. pilates.
    private var yogaCount: Int {
        sortedSlots.filter {
            $0.resolvedExercise(in: library)?.category == .yoga
        }.count
    }

    private var pilatesCount: Int {
        sortedSlots.filter {
            $0.resolvedExercise(in: library)?.category == .pilates
        }.count
    }


    // ─────────────────────────────────────────────
    // MARK: - Body
    // ─────────────────────────────────────────────

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {

                trophySection
                statsSection
                exerciseRecapSection
                buttonSection
            }
            .padding(.horizontal)
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
        .navigationTitle("Session Complete")
        .navigationBarTitleDisplayMode(.inline)
        // Hide the back button — the user should use the "Done" button below
        // so they see the full summary rather than backing out immediately.
        .navigationBarBackButtonHidden(true)
        .onAppear {
            // Small delay so the view is fully on screen before the bounce.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) {
                    showTrophy = true
                }
                // Success haptic lands with the trophy pop — feels like a
                // physical reward for finishing the session.
                Haptics.success()
            }
        }
    }


    // ─────────────────────────────────────────────
    // MARK: - Trophy Section
    // ─────────────────────────────────────────────
    //
    // Large animated trophy icon + congratulatory headline.
    // The icon scales from 0 → 1 when showTrophy flips, creating a satisfying
    // "pop" on entry. Using .spring() gives it a slight overshoot — exactly
    // the same technique used for the bounce on app icons when you download
    // something from the App Store.
    //
    // CGI ANALOGY: The "Render Complete" celebration burst — a particle or
    // camera shake that fires once when the sequence finishes. One-shot,
    // driven by a boolean flag, never loops.

    private var trophySection: some View {
        VStack(spacing: 16) {

            Image(systemName: "trophy.fill")
                .font(.system(size: 88))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.yellow, .orange],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: .orange.opacity(0.35), radius: 16, x: 0, y: 8)
                // Scale from 0 → 1 when showTrophy flips.
                // CGI ANALOGY: A spawn-from-zero scale animation on the trophy
                // geometry, triggered by a scene event flag.
                .scaleEffect(showTrophy ? 1.0 : 0.0)

            Text("Great work!")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("\"\(routine.name)\" complete")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 12)
    }


    // ─────────────────────────────────────────────
    // MARK: - Stats Section
    // ─────────────────────────────────────────────
    //
    // Three stat cards in a row: Total Time | Exercises | Mix.
    // Each card is an equal-width tile using a HStack with .frame(maxWidth: .infinity).
    //
    // CGI ANALOGY: The three KPI cells at the top of a render report —
    //   Wall Time | Shot Count | VFX vs. Anim breakdown.

    private var statsSection: some View {
        HStack(spacing: 12) {
            statCard(
                value: formattedTime,
                label: "Total Time",
                color: .indigo
            )
            statCard(
                value: "\(sortedSlots.count)",
                label: "Exercises",
                color: .teal
            )
            mixCard
        }
    }

    // A single stat tile.
    private func statCard(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(color)
                .minimumScaleFactor(0.7)   // shrinks text if too wide, rather than clipping
                .lineLimit(1)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // The yoga / pilates mix card — shows coloured dots instead of a plain number.
    // CGI ANALOGY: A shot-type legend in the render report (VFX shots shown as
    // purple dots, animation shots as teal dots).
    private var mixCard: some View {
        VStack(spacing: 6) {
            VStack(spacing: 3) {
                if yogaCount > 0 {
                    Label("\(yogaCount) yoga", systemImage: "circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.indigo)
                }
                if pilatesCount > 0 {
                    Label("\(pilatesCount) pilates", systemImage: "circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.teal)
                }
            }
            Text("Mix")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }


    // ─────────────────────────────────────────────
    // MARK: - Exercise Recap Section
    // ─────────────────────────────────────────────
    //
    // A compact, non-interactive list of every exercise performed in order.
    // Each row shows the image, name, category badge, and duration.
    //
    // CGI ANALOGY: The per-shot table in the render report — shot code,
    // asset name, render time, and pass type (VFX / anim).

    private var exerciseRecapSection: some View {
        VStack(alignment: .leading, spacing: 8) {

            Text("What you did")
                .font(.headline)
                .padding(.bottom, 2)

            LazyVStack(spacing: 0) {
                ForEach(Array(sortedSlots.enumerated()), id: \.element.id) { index, slot in
                    if let exercise = slot.resolvedExercise(in: library) {
                        recapRow(
                            index: index,
                            exercise: exercise,
                            duration: slot.effectiveDuration(in: library),
                            isLast: index == sortedSlots.count - 1
                        )
                    }
                }
            }
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    // One row in the recap list.
    private func recapRow(
        index: Int,
        exercise: Exercise,
        duration: Int,
        isLast: Bool
    ) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {

                // Step number badge.
                Text("\(index + 1)")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .frame(width: 20, alignment: .trailing)

                // Small exercise icon.
                ExerciseImageView(exercise: exercise, size: 32)

                // Name.
                Text(exercise.name)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                // Category pill.
                categoryBadge(for: exercise.category)

                // Duration.
                Text("\(duration)s")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 36, alignment: .trailing)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            // Divider between rows (omit after the last one).
            if !isLast {
                Divider()
                    .padding(.leading, 56)
            }
        }
    }


    // ─────────────────────────────────────────────
    // MARK: - Button Section
    // ─────────────────────────────────────────────
    //
    // Two full-width buttons stacked vertically:
    //   1. "Go Again" — prominent filled style → calls onReplay
    //   2. "Done"     — plain secondary style  → dismiss back to My Routines
    //
    // CGI ANALOGY:
    //   "Resubmit to Farm" — re-queues the same shot list for another pass.
    //   "Close Report"     — dismisses the report window.

    private var buttonSection: some View {
        VStack(spacing: 12) {

            Button {
                Haptics.medium()
                onReplay()
            } label: {
                Label("Go Again", systemImage: "arrow.counterclockwise")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.indigo)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.secondary.opacity(0.12))
                    .foregroundStyle(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }


    // ─────────────────────────────────────────────
    // MARK: - Helpers
    // ─────────────────────────────────────────────

    private func categoryBadge(for category: Exercise.Category) -> some View {
        let color: Color = category == .yoga ? .indigo : .teal
        return Text(category.rawValue)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}


// ─────────────────────────────────────────────
// MARK: - Preview
// ─────────────────────────────────────────────

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Routine.self, RoutineExercise.self,
        configurations: config
    )
    let ctx = container.mainContext
    let library = ExerciseLibrary.load()

    let routine = Routine(name: "Morning Flow")
    ctx.insert(routine)
    for (i, ex) in library.prefix(6).enumerated() {
        let re = RoutineExercise(exerciseID: ex.id, sortIndex: i)
        re.routine = routine
        routine.exercises.append(re)
        ctx.insert(re)
    }

    return NavigationStack {
        SessionSummaryView(
            routine: routine,
            library: library,
            onReplay: { print("Replay tapped") }
        )
    }
    .modelContainer(container)
}
