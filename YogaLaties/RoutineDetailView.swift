//
//  RoutineDetailView.swift
//  YogaLaties
//
//  Step 12 — Routine Detail
//  Shows a saved routine's contents, lets the user edit it via the builder
//  sheet, and launches the active session when they tap Start Workout.
//
//  CGI ANALOGY: This is the Sequence Detail panel in your production browser —
//  the view you see after double-clicking a sequence card. It shows the
//  ordered shot list with per-shot metadata, has an "Edit Sequence" button to
//  open the blocking editor, and a "Start Render" button to kick off the
//  render farm job (the live workout session).
//

import SwiftUI
import SwiftData

struct RoutineDetailView: View {

    // The Routine record we're displaying.
    // Passed in by value from MyRoutinesView's NavigationLink; SwiftData
    // keeps this as a live reference so edits made in the builder sheet are
    // immediately reflected here.
    //
    // CGI ANALOGY: The sequence entity object checked out from Shotgrid — a
    // live handle, not a static snapshot.
    let routine: Routine

    // The exercise library, resolved once for this view's lifetime.
    // CGI ANALOGY: The asset library loaded into memory for this shot-list
    // review session — we won't reload it on every frame.
    private let library: [Exercise] = ExerciseLibrary.load()

    // Controls whether the Edit sheet is presented.
    @State private var showEditor = false

    // Controls navigation to the active session screen.
    @State private var navigateToSession = false

    // ── Derived data ───────────────────────────────────────────────────────

    /// Exercises sorted by their cut-order index, then resolved to full
    /// Exercise structs. Orphaned slots (exercise removed from library) are
    /// silently dropped — same way a retired asset is skipped in a render list.
    private var sortedSlots: [(re: RoutineExercise, exercise: Exercise)] {
        routine.exercises
            .sorted { $0.sortIndex < $1.sortIndex }
            .compactMap { re in
                guard let ex = re.resolvedExercise(in: library) else { return nil }
                return (re: re, exercise: ex)
            }
    }

    /// Human-readable total workout duration label.
    private var totalDurationLabel: String {
        let total = routine.exercises.reduce(0) { $0 + $1.effectiveDuration(in: library) }
        let mins = total / 60
        let secs  = total % 60
        guard total > 0 else { return "—" }
        if mins == 0 { return "\(secs) sec" }
        if secs == 0 { return "\(mins) min" }
        return "\(mins) min \(secs) sec"
    }


    // ── Body ───────────────────────────────────────────────────────────────

    var body: some View {
        List {
            // ── Summary Section ───────────────────────────────────────────
            // A quick at-a-glance header: exercise count + total time.
            // CGI ANALOGY: The sequence summary card at the top of the
            // Shotgrid sequence page — shows shot count and estimated runtime.
            Section {
                HStack(spacing: 0) {
                    summaryTile(
                        value: "\(sortedSlots.count)",
                        label: sortedSlots.count == 1 ? "exercise" : "exercises",
                        icon: "figure.mind.and.body",
                        color: .indigo
                    )

                    Divider().padding(.vertical, 8)

                    summaryTile(
                        value: totalDurationLabel,
                        label: "total time",
                        icon: "timer",
                        color: .teal
                    )
                }
                .frame(maxWidth: .infinity)
            }

            // ── Shot List Section ─────────────────────────────────────────
            // CGI ANALOGY: The ordered shot list for this sequence — each row
            // is one shot with its asset name, category tag, and frame range.
            if sortedSlots.isEmpty {
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundStyle(.orange)
                            Text("No exercises in this routine.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 20)
                        Spacer()
                    }
                }
            } else {
                Section("Exercises") {
                    ForEach(Array(sortedSlots.enumerated()), id: \.element.re.id) { index, slot in
                        exerciseRow(index: index + 1, slot: slot)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(routine.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") { showEditor = true }
            }
        }
        // ── Edit sheet ────────────────────────────────────────────────────
        // CGI ANALOGY: Opens the blocking editor pre-loaded with this sequence.
        // On Save the existing Routine record is updated in-place; on Cancel
        // nothing changes.
        .sheet(isPresented: $showEditor) {
            RoutineBuilderView(editingRoutine: routine)
        }
        // ── Start Workout button ──────────────────────────────────────────
        // Pinned above the home indicator so it's always reachable.
        // CGI ANALOGY: The "Submit to Render Farm" button — always visible,
        // disabled only when the shot list is empty (nothing to render).
        .safeAreaInset(edge: .bottom) {
            startButton
        }
        // ── Navigation to active session ──────────────────────────────────
        .navigationDestination(isPresented: $navigateToSession) {
            ActiveSessionView(routine: routine)
        }
    }


    // MARK: - Sub-views

    /// One exercise row: index badge, thumbnail, name, category pill, duration.
    ///
    /// CGI ANALOGY: A single shot row in the sequence editor — shows the shot
    /// number, thumbnail, asset name, department tag, and frame range.
    private func exerciseRow(
        index: Int,
        slot: (re: RoutineExercise, exercise: Exercise)
    ) -> some View {
        let ex = slot.exercise
        let duration = slot.re.effectiveDuration(in: library)
        let isOverridden = slot.re.durationOverride != nil

        return HStack(spacing: 12) {

            // Shot number badge.
            // CGI ANALOGY: The shot cut-order index shown in the left gutter
            // of a shot list (0010, 0020, etc. — here just 1, 2, 3…).
            Text("\(index)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(minWidth: 20, alignment: .trailing)

            // Exercise thumbnail / SF Symbol fallback.
            ExerciseImageView(exercise: ex, size: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(ex.name)
                    .font(.body)
                    .fontWeight(.medium)

                // Category badge — colour-coded like department tags in Shotgrid.
                categoryBadge(for: ex.category)
            }

            Spacer()

            // Duration label — tinted when a per-slot override is active.
            // CGI ANALOGY: The per-shot frame range in orange when it diverges
            // from the master asset's default frame range.
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(duration)s")
                    .font(.callout.monospacedDigit())
                    .fontWeight(.medium)
                    .foregroundStyle(isOverridden ? categoryColor(for: ex.category) : .primary)

                if isOverridden {
                    Text("custom")
                        .font(.caption2)
                        .foregroundStyle(categoryColor(for: ex.category).opacity(0.8))
                }
            }
        }
        .padding(.vertical, 2)
    }

    /// Two-column summary tile used in the overview section.
    private func summaryTile(
        value: String,
        label: String,
        icon: String,
        color: Color
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.headline)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    /// Coloured pill badge for the exercise category.
    /// CGI ANALOGY: The department tag chip on a Shotgrid shot row —
    /// "ART", "FX", "COMP" shown in department-specific colours.
    private func categoryBadge(for category: Exercise.Category) -> some View {
        Text(category.rawValue)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(categoryColor(for: category).opacity(0.15))
            .foregroundStyle(categoryColor(for: category))
            .clipShape(Capsule())
    }

    private func categoryColor(for category: Exercise.Category) -> Color {
        switch category {
        case .yoga:    return .indigo
        case .pilates: return .teal
        }
    }

    /// Prominent "Start Workout" button pinned to the bottom of the screen.
    ///
    /// CGI ANALOGY: The "Submit to Render Farm" button in the sequence viewer —
    /// tapping it kicks off the render job (the live guided session).
    /// Disabled when the sequence has no shots to render.
    private var startButton: some View {
        Button {
            navigateToSession = true
        } label: {
            Label("Start Workout", systemImage: "play.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(sortedSlots.isEmpty ? Color.secondary.opacity(0.2) : Color.indigo)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .disabled(sortedSlots.isEmpty)
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(.bar)           // matches the system translucent toolbar look
    }
}


// ─────────────────────────────────────────────
// MARK: - Preview
// ─────────────────────────────────────────────

#Preview("With Exercises") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Routine.self, RoutineExercise.self,
        configurations: config
    )
    let ctx = container.mainContext
    let library = ExerciseLibrary.load()

    let routine = Routine(name: "Morning Flow")
    ctx.insert(routine)

    for (i, ex) in library.prefix(4).enumerated() {
        let re = RoutineExercise(exerciseID: ex.id, sortIndex: i)
        re.routine = routine
        routine.exercises.append(re)
        ctx.insert(re)
    }

    return NavigationStack {
        RoutineDetailView(routine: routine)
    }
    .modelContainer(container)
}

#Preview("Empty Routine") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Routine.self, RoutineExercise.self,
        configurations: config
    )
    let ctx = container.mainContext
    let routine = Routine(name: "Empty Routine")
    ctx.insert(routine)

    return NavigationStack {
        RoutineDetailView(routine: routine)
    }
    .modelContainer(container)
}
