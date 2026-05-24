//
//  MyRoutinesView.swift
//  YogaLaties
//
//  Displays the user's saved routines from SwiftData.
//  Supports: create new (+ button → builder sheet), swipe-to-delete, reorder,
//  and a friendly empty state when no routines exist yet.
//

import SwiftUI
import SwiftData

struct MyRoutinesView: View {

    // CGI ANALOGY: `@Query` is a **live render queue filter** — always watching
    // the production vault (SwiftData). Any time a Routine is added, deleted, or
    // renamed, @Query fires and SwiftUI redraws the list automatically. No manual
    // refresh; it's like a Shotgrid dashboard widget that stays in sync with the DB.
    @Query(sort: \Routine.createdAt, order: .reverse)
    private var routines: [Routine]

    // CGI ANALOGY: The authenticated Shotgrid API client — your write handle to
    // the vault. Use it to delete records. Injected by the environment; you never
    // create it yourself.
    @Environment(\.modelContext) private var modelContext

    // Controls whether the Routine Builder sheet is showing.
    // CGI ANALOGY: A boolean flag that tells the compositor to bring the
    // "New Sequence" panel into view on top of the main sequence browser.
    @State private var showBuilder = false

    var body: some View {
        NavigationStack {
            Group {
                if routines.isEmpty {
                    emptyStateView
                } else {
                    routineListView
                }
            }
            .navigationTitle("My Routines")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                // Show Edit button only when there are routines to edit.
                if !routines.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        EditButton()
                    }
                }
                // The + button is always present so the user can create a routine
                // even from the empty state — no hunting around for a way to start.
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showBuilder = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("New Routine")
                }
            }
            // The Routine Builder sheet.
            // CGI ANALOGY: Presenting the "New Sequence" creation dialog on top of
            // the sequence browser. The sheet has its own NavigationStack and
            // Save/Cancel buttons; dismissing it returns to this view.
            .sheet(isPresented: $showBuilder) {
                RoutineBuilderView()
            }
        }
    }


    // MARK: - Empty State

    // CGI ANALOGY: The "No sequences in this project yet" placeholder that Shotgrid
    // shows before any sequences have been created. A clear invitation to start.
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "figure.yoga")
                .font(.system(size: 72))
                .foregroundStyle(.indigo.opacity(0.35))

            Text("No Routines Yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Tap + to build your first custom routine\nfrom the exercise library.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding()
    }


    // MARK: - Routine List

    private var routineListView: some View {
        List {
            ForEach(routines) { routine in
                // CGI ANALOGY: Each row is a clickable Sequence card. Tapping it
                // pushes a Sequence Detail panel onto the navigation stack — the
                // same as double-clicking a card in Shotgrid to open its detail page.
                NavigationLink {
                    RoutineDetailView(routine: routine)
                } label: {
                    routineRow(for: routine)
                }
            }
            // Swipe-to-delete (or tap the red circle in edit mode).
            // CGI ANALOGY: "Archive and remove sequence from vault." The cascade
            // rule on Routine deletes all child RoutineExercises automatically —
            // exactly like Shotgrid cascading from a sequence delete to its shots.
            .onDelete(perform: deleteRoutines)
        }
        .listStyle(.insetGrouped)
    }


    // MARK: - Routine Row

    // CGI ANALOGY: Each row is a Sequence card in the browser — shows the sequence
    // name and how many shots (exercises) are in it.
    private func routineRow(for routine: Routine) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text(routine.name)
                    .font(.headline)

                HStack(spacing: 10) {
                    // Exercise count badge.
                    Label(exerciseCountLabel(for: routine), systemImage: "figure.mind.and.body")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    // Total duration badge — sum of effective durations.
                    // Uses the library-default durations (overrides resolved at session time).
                    Label(totalDurationLabel(for: routine), systemImage: "timer")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }


    // MARK: - Helpers

    private func exerciseCountLabel(for routine: Routine) -> String {
        let n = routine.exerciseCount
        return n == 1 ? "1 exercise" : "\(n) exercises"
    }

    private func totalDurationLabel(for routine: Routine) -> String {
        // Sum the sortedExercises durations. durationOverride takes priority if set.
        // We don't have access to the library here, so fall back to a simple
        // sum using RoutineExercise.durationOverride ?? a rough estimate.
        // (Full resolution happens in the Session Engine, Step 13.)
        let total = routine.exercises.reduce(0) { sum, re in
            sum + (re.durationOverride ?? 30)  // 30 s as a conservative fallback
        }
        let mins = total / 60
        let secs  = total % 60
        if total == 0  { return "—" }
        if mins  == 0  { return "\(secs) sec" }
        if secs  == 0  { return "\(mins) min" }
        return "\(mins) min \(secs) sec"
    }

    private func deleteRoutines(at offsets: IndexSet) {
        Haptics.light()
        for index in offsets {
            modelContext.delete(routines[index])
        }
    }
}


// ─────────────────────────────────────────────
// MARK: - Preview
// ─────────────────────────────────────────────

#Preview("With Routines") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Routine.self, RoutineExercise.self,
        configurations: config
    )
    let ctx = container.mainContext

    let morning = Routine(name: "Morning Flow")
    ctx.insert(morning)
    ctx.insert(RoutineExercise(exerciseID: UUID(), sortIndex: 0))

    let evening = Routine(name: "Evening Stretch")
    ctx.insert(evening)

    return MyRoutinesView()
        .modelContainer(container)
}

#Preview("Empty State") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Routine.self, RoutineExercise.self,
        configurations: config
    )
    return MyRoutinesView()
        .modelContainer(container)
}
