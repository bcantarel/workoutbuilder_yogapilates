//
//  RoutineBuilderView.swift
//  YogaLaties
//
//  Step 11 — Routine Builder
//  Lets the user name a routine, pick exercises from the library,
//  drag to reorder, adjust per-exercise duration, and save to SwiftData.
//

import SwiftUI
import SwiftData


// ─────────────────────────────────────────────
// MARK: - BuilderEntry  (scratch / staging struct)
// ─────────────────────────────────────────────
//
// CGI ANALOGY: BuilderEntry is a "staging layer" — a cheap, in-memory
// copy of one exercise slot that you work with freely while the builder
// sheet is open. None of it touches SwiftData until the user taps Save.
// Think of it like working on a Photoshop scratch layer: you only flatten
// it to the master document (SwiftData) when you're happy with the result.
//
// Why a separate struct and not RoutineExercise directly?
// Because RoutineExercise is a SwiftData @Model (a managed object), and
// creating managed objects before you're ready to persist them causes
// headaches. BuilderEntry is a plain Swift struct — zero overhead, freely
// discardable if the user taps Cancel.

struct BuilderEntry: Identifiable {

    // A fresh UUID for each slot — this is what ForEach uses to track
    // identity when the user drags to reorder. It's NOT the Exercise's id.
    // CGI ANALOGY: The shot's internal render-farm job ID — only meaningful
    // within this session; doesn't survive outside the builder sheet.
    let id = UUID()

    let exercise: Exercise

    // Starts at the library default; the user may change it per slot.
    // CGI ANALOGY: The per-shot frame-range that begins as a copy of the
    // master asset's default range, then diverges only if the director
    // explicitly overrides it for this slot.
    var durationSeconds: Int

    init(exercise: Exercise) {
        self.exercise = exercise
        self.durationSeconds = exercise.durationSeconds
    }
}


// ─────────────────────────────────────────────
// MARK: - Routine Builder View
// ─────────────────────────────────────────────
//
// Handles both CREATE (no existing routine) and EDIT (existing routine passed in).
//
// CGI ANALOGY: This is the Sequence Editor panel. Opening it fresh creates a
// brand-new sequence. Opening it from an existing sequence card pre-loads that
// sequence's shot list so you can rename it, add/remove/reorder shots, and
// republish. The panel never knows or cares which mode it's in — it just works
// on whatever shot list it was handed at launch.

struct RoutineBuilderView: View {

    // The write handle to the production vault — injected by the environment.
    // CGI ANALOGY: Your authenticated Shotgrid API client, ready to commit
    // records. You don't create it yourself; the app hands it to you.
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // The existing Routine being edited, or nil when creating a new one.
    // CGI ANALOGY: The "source sequence" the editor pre-loaded from, or nil
    // if we opened a blank new-sequence form.
    let editingRoutine: Routine?

    // Local scratch state — @State without defaults so the two inits below
    // can supply different starting values.
    // CGI ANALOGY: The scratch layer in Photoshop — these values live only in
    // this sheet. They get flushed to the vault (SwiftData) only on Save.
    @State private var routineName: String
    @State private var entries: [BuilderEntry]
    @State private var showPicker = false

    // ── Init: creating a brand-new routine ─────────────────────────────────
    //
    // CGI ANALOGY: Opening a blank "New Sequence" form — empty name field,
    // empty shot list.
    init() {
        self.editingRoutine = nil
        _routineName = State(initialValue: "")
        _entries    = State(initialValue: [])
    }

    // ── Init: editing an existing routine ──────────────────────────────────
    //
    // Pre-populates the scratch layer from the existing Routine record.
    // `ExerciseLibrary.load()` resolves each RoutineExercise back to a full
    // Exercise struct so BuilderEntry (which needs the complete asset) can be
    // constructed.
    //
    // CGI ANALOGY: Loading an existing sequence into the editor — the shot list
    // comes pre-populated with all its shots, each carrying its per-shot
    // overrides. The editor is now working on a "hot copy"; the original record
    // in the vault is only updated when the user taps Save.
    init(editingRoutine: Routine) {
        self.editingRoutine = editingRoutine

        let library = ExerciseLibrary.load()

        // Resolve each RoutineExercise → BuilderEntry, in sortIndex order.
        // compactMap silently drops any orphaned slots whose exercise was removed
        // from the JSON library (shouldn't happen, but defensive is good).
        let loaded: [BuilderEntry] = editingRoutine.exercises
            .sorted { $0.sortIndex < $1.sortIndex }
            .compactMap { re in
                guard let ex = re.resolvedExercise(in: library) else { return nil }
                var entry = BuilderEntry(exercise: ex)
                // Carry over any per-slot duration override.
                entry.durationSeconds = re.effectiveDuration(in: library)
                return entry
            }

        _routineName = State(initialValue: editingRoutine.name)
        _entries    = State(initialValue: loaded)
    }

    // ── Dynamic nav title ──────────────────────────────────────────────────
    private var navigationTitle: String {
        editingRoutine == nil ? "New Routine" : "Edit Routine"
    }

    // Save is only enabled when a name exists AND at least one exercise is added.
    // CGI ANALOGY: The "Publish to Vault" button is greyed out until the sequence
    // has a name and at least one shot in the shot list.
    private var canSave: Bool {
        !routineName.trimmingCharacters(in: .whitespaces).isEmpty && !entries.isEmpty
    }

    // Running total of all slot durations — shown in the section header.
    private var totalDurationLabel: String {
        let total = entries.reduce(0) { $0 + $1.durationSeconds }
        let mins = total / 60
        let secs  = total % 60
        if mins == 0 { return "\(secs) sec total" }
        if secs  == 0 { return "\(mins) min total" }
        return "\(mins) min \(secs) sec total"
    }

    var body: some View {
        NavigationStack {
            List {

                // ── Section 1: Routine Name ────────────────────────────────
                Section("Routine Name") {
                    TextField("e.g. Morning Flow", text: $routineName)
                        .autocorrectionDisabled()
                }

                // ── Section 2: Exercise Slots ─────────────────────────────
                Section {
                    if entries.isEmpty {
                        emptyExercisesHint
                    } else {
                        // `ForEach($entries)` — binding-based ForEach (iOS 17+).
                        // CGI ANALOGY: Iterating over shot-list records and getting
                        // a live reference to each one, so edits inside each row
                        // propagate back to the array immediately — like editing
                        // a shot record in-place in Shotgrid without a round-trip.
                        ForEach($entries) { $entry in
                            BuilderExerciseRow(entry: $entry)
                        }
                        // Drag-to-reorder: user holds the three-line handle and
                        // drags a row to a new position.
                        // CGI ANALOGY: Dragging shots up or down in the shot list
                        // to change the cut order.
                        .onMove { from, to in
                            entries.move(fromOffsets: from, toOffset: to)
                            Haptics.light()
                        }
                        // Swipe-to-delete (in edit mode: tap the red circle).
                        // CGI ANALOGY: Removing a shot from the sequence — it
                        // doesn't delete the asset from the library, just removes
                        // this slot from the shot list.
                        .onDelete { offsets in
                            entries.remove(atOffsets: offsets)
                            Haptics.light()
                        }
                    }
                } header: {
                    exercisesSectionHeader
                } footer: {
                    if !entries.isEmpty {
                        Text("Tap ● to remove  ·  Hold ≡ to reorder  ·  Tap ＋/－ to adjust duration")
                            .font(.caption2)
                    }
                }
            }
            // Always-on edit mode so drag handles and delete circles are always visible.
            // CGI ANALOGY: The shot list is always in "edit mode" — you never have to
            // click an Edit button to get the move/delete handles; they're always there.
            .environment(\.editMode, .constant(.active))
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Save") { saveRoutine() }
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
                // Bottom toolbar: the "Add Exercises" button lives here so it
                // doesn't compete for space with Save/Cancel.
                ToolbarItem(placement: .bottomBar) {
                    Button {
                        showPicker = true
                    } label: {
                        Label("Add Exercises", systemImage: "plus.circle.fill")
                            .font(.body.weight(.medium))
                    }
                }
                // Spacer pushes the Add button to the leading edge of the bottom bar.
                ToolbarItem(placement: .bottomBar) { Spacer() }
            }
            // The exercise picker sheet.
            .sheet(isPresented: $showPicker) {
                ExercisePickerView { picked in
                    // Append picked exercises in the order the user selected them.
                    // Duplicates are intentional — you might want the same exercise twice.
                    for exercise in picked {
                        entries.append(BuilderEntry(exercise: exercise))
                    }
                    // Light tap confirms exercises were added.
                    if !picked.isEmpty { Haptics.light() }
                }
            }
        }
    }


    // MARK: - Sub-views

    // Shown when no exercises have been added yet.
    // CGI ANALOGY: The "empty shot list" placeholder in a brand-new sequence card.
    private var emptyExercisesHint: some View {
        HStack {
            Spacer()
            VStack(spacing: 10) {
                Image(systemName: "plus.circle.dashed")
                    .font(.system(size: 44))
                    .foregroundStyle(.indigo.opacity(0.4))
                Text("Tap \"Add Exercises\" below\nto build your routine.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 24)
            Spacer()
        }
        // Prevent the hint card from showing edit-mode chrome (red circle, drag handle).
        .deleteDisabled(true)
        .moveDisabled(true)
    }

    // The header for the Exercises section — shows count + total duration.
    private var exercisesSectionHeader: some View {
        HStack {
            Text("Exercises")
            Spacer()
            if !entries.isEmpty {
                Text("\(entries.count)  ·  \(totalDurationLabel)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(nil)
            }
        }
    }


    // MARK: - Save

    /// Commits the in-memory builder state to SwiftData — handles both
    /// create-new and edit-existing modes in one function.
    ///
    /// CGI ANALOGY: Flattening the scratch layers and publishing the sequence
    /// back to the production vault.
    ///   • Create mode  → new Sequence record inserted into the vault.
    ///   • Edit mode    → existing Sequence record mutated in-place; old shots
    ///                    are deleted and replaced with the revised shot list.
    /// Either way, @Query in MyRoutinesView picks up the change automatically —
    /// no manual refresh, just like a Shotgrid live dashboard widget.
    private func saveRoutine() {

        let trimmedName = routineName.trimmingCharacters(in: .whitespaces)

        // ── Determine / prepare the parent Routine record ──────────────────
        let routine: Routine

        if let existing = editingRoutine {
            // EDIT MODE: update the live record directly.
            // CGI ANALOGY: Opening the existing sequence record in Shotgrid and
            // changing its name field, then replacing all its shots with the
            // revised list. The sequence's UUID and createdAt stay untouched.
            existing.name = trimmedName

            // Delete all existing exercise slots so we can rebuild from scratch.
            // The cascade delete rule on Routine would handle this automatically
            // if we deleted the parent — but we're keeping the parent, so we
            // manually wipe the children before re-adding them.
            // CGI ANALOGY: Clearing the shot list before re-populating it from
            // the updated blocking pass, rather than trying to diff the old list.
            for re in existing.exercises {
                modelContext.delete(re)
            }
            existing.exercises = []
            routine = existing

        } else {
            // CREATE MODE: brand new Routine record.
            routine = Routine(name: trimmedName)
            modelContext.insert(routine)
        }

        // ── Re-create exercise slots from builder entries ───────────────────
        for (index, entry) in entries.enumerated() {

            // Only store a durationOverride when the value diverges from the
            // library default — keeps the vault lean and avoids phantom overrides.
            // CGI ANALOGY: We only write a per-shot frame-range override to the
            // shot record if it actually differs from the master asset default.
            let override: Int? = entry.durationSeconds != entry.exercise.durationSeconds
                ? entry.durationSeconds
                : nil

            let re = RoutineExercise(
                exerciseID: entry.exercise.id,
                sortIndex: index,
                durationOverride: override
            )

            // Wire the child to its parent — satisfies the @Relationship inverse.
            // CGI ANALOGY: Setting the "parent sequence" field on the shot record.
            re.routine = routine
            routine.exercises.append(re)
            modelContext.insert(re)
        }

        dismiss()
    }
}


// ─────────────────────────────────────────────
// MARK: - Builder Exercise Row
// ─────────────────────────────────────────────
//
// CGI ANALOGY: One row in the shot list — shows the asset thumbnail, name,
// category, and the per-shot frame-range control. The duration +/- buttons
// are the frame-range sliders of the routine builder.

struct BuilderExerciseRow: View {
    @Binding var entry: BuilderEntry

    private var categoryColor: Color {
        switch entry.exercise.category {
        case .yoga:    return .indigo
        case .pilates: return .teal
        }
    }

    // True when the user has changed the duration from the library default.
    private var isDurationOverridden: Bool {
        entry.durationSeconds != entry.exercise.durationSeconds
    }

    var body: some View {
        HStack(spacing: 12) {

            // Asset thumbnail — resolves to SF Symbol until real art is added.
            ExerciseImageView(exercise: entry.exercise, size: 40)

            // Name + category label.
            // .frame(maxWidth: .infinity) ensures this VStack claims the
            // available horizontal space before the duration control, preventing
            // iOS edit-mode controls (delete circle + reorder handle) from
            // squeezing the text to one character per line.
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.exercise.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Text(entry.exercise.category.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Duration control — compact +/- buttons with the current value in between.
            // A small dot appears when the value has been overridden from the library default,
            // so the user knows at a glance which slots have custom durations.
            durationControl
        }
        .padding(.vertical, 2)
    }

    private var durationControl: some View {
        HStack(spacing: 4) {

            // Minimum duration: 5 seconds.
            Button {
                entry.durationSeconds = max(5, entry.durationSeconds - 5)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(categoryColor.opacity(0.75))
            }
            .buttonStyle(.plain)

            // Current value — shows a small tint when overridden from default.
            // CGI ANALOGY: The frame-range field turns orange in many DCCs when
            // it has been customised away from the scene default.
            VStack(spacing: 1) {
                Text("\(entry.durationSeconds)s")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(isDurationOverridden ? categoryColor : .secondary)
                    .frame(minWidth: 34, alignment: .center)

                // Tiny override indicator dot.
                Circle()
                    .fill(isDurationOverridden ? categoryColor : .clear)
                    .frame(width: 4, height: 4)
            }

            // Maximum duration: 10 minutes (600 seconds).
            Button {
                entry.durationSeconds = min(600, entry.durationSeconds + 5)
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(categoryColor.opacity(0.75))
            }
            .buttonStyle(.plain)
        }
    }
}


// ─────────────────────────────────────────────
// MARK: - Preview
// ─────────────────────────────────────────────

#Preview("Empty Builder") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Routine.self, RoutineExercise.self,
        configurations: config
    )
    return RoutineBuilderView()
        .modelContainer(container)
}
