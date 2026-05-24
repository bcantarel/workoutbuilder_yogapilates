//
//  ExercisePickerView.swift
//  YogaLaties
//
//  A multi-select exercise browser presented as a sheet from RoutineBuilderView.
//  The user taps exercises to select them, then taps "Add N" to hand them back.
//

import SwiftUI


// ─────────────────────────────────────────────
// MARK: - Exercise Picker View
// ─────────────────────────────────────────────
//
// CGI ANALOGY: This is the studio's **asset browser** window — a searchable,
// grouped catalogue of every available exercise (prop). The director (user)
// flags the assets they want, clicks "Add to Shot List", and the browser
// hands the selection back to the calling view. The browser stays separate
// from the production vault; it's purely a selection tool.
//
// Communication pattern: `onAdd` is a closure the caller provides.
// CGI ANALOGY: Think of it as a callback hook — "when the user confirms
// their selection, call this function with the chosen assets."

struct ExercisePickerView: View {

    // The callback handed to us by RoutineBuilderView.
    // After the user taps Add, we call this with the selected exercises,
    // then dismiss ourselves.
    let onAdd: ([Exercise]) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var allExercises: [Exercise] = []

    // We use an Array (not a Set) so the order the user taps exercises is
    // preserved — exercises get appended to the routine in selection order.
    @State private var selected: [Exercise] = []

    @State private var searchText = ""

    // Filter exercises by name or category when the user types in the search bar.
    private var filtered: [Exercise] {
        guard !searchText.isEmpty else { return allExercises }
        let query = searchText
        return allExercises.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            $0.category.rawValue.localizedCaseInsensitiveContains(query)
        }
    }

    // Button label changes dynamically: "Add" → "Add 3" as the user taps.
    // CGI ANALOGY: Like a "Confirm Import (3 assets)" button in an asset browser
    // that shows a live count of what you've flagged.
    private var addButtonLabel: String {
        selected.isEmpty ? "Add" : "Add \(selected.count)"
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(Exercise.Category.allCases, id: \.self) { category in
                    let group = filtered.filter { $0.category == category }
                    if !group.isEmpty {
                        Section {
                            ForEach(group) { exercise in
                                pickerRow(for: exercise)
                            }
                        } header: {
                            // Reuses the same styled header from ContentView —
                            // same category colours and icons, consistent visual language.
                            CategoryHeaderView(category: category)
                        }
                    }
                }
            }
            // Built-in iOS search bar — filters `filtered` automatically as the user types.
            // CGI ANALOGY: The search field in Maya's Hypershade or Houdini's asset browser.
            .searchable(text: $searchText, prompt: "Search exercises")
            .navigationTitle("Add Exercises")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(addButtonLabel) {
                        onAdd(selected)    // hand the ordered selection back to the builder
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(selected.isEmpty)
                }
            }
            // Load the exercise library as soon as the sheet appears.
            .task {
                if allExercises.isEmpty {
                    allExercises = ExerciseLibrary.load()
                }
            }
        }
    }


    // MARK: - Picker Row

    // A single exercise row with a tap-to-toggle checkmark.
    //
    // CGI ANALOGY: Clicking an asset thumbnail in an asset browser to "flag it"
    // for import. Flagged assets show a filled circle; unflagged ones show an
    // empty circle. You can flag and unflag freely before confirming.
    @ViewBuilder
    private func pickerRow(for exercise: Exercise) -> some View {

        // `firstIndex(of:)` gives us both selection state AND tap order in one call.
        // nil  → not selected  |  Int → 0-based position in the tap sequence.
        let selectionIndex = selected.firstIndex(of: exercise)
        let isSelected     = selectionIndex != nil
        let color          = categoryColor(for: exercise)

        Button {
            if isSelected {
                // Deselect: remove from the ordered array.
                // The numbers on all later rows shift down automatically because
                // they're derived live from `selected.firstIndex(of:)`.
                selected.removeAll { $0 == exercise }
            } else {
                // Select: append in tap order.
                selected.append(exercise)
            }
        } label: {
            HStack(spacing: 12) {

                // Reuse the same smart image resolver from ExerciseIcon.swift.
                ExerciseImageView(exercise: exercise, size: 40)

                VStack(alignment: .leading, spacing: 3) {
                    Text(exercise.name)
                        .font(.body)
                        .foregroundStyle(.primary)

                    Text(durationLabel(for: exercise))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Numbered selection badge — mirrors the iOS Photos multi-select UX.
                // Shows the tap-order number inside a filled circle when selected,
                // or a dim empty circle when not selected.
                // Numbers shift automatically if an earlier selection is removed.
                selectionBadge(index: selectionIndex, color: color)
                    .animation(.easeInOut(duration: 0.15), value: isSelected)
            }
            // Makes the entire row (not just the text) tappable.
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Selection Badge

    /// Renders either a numbered filled circle (selected) or a dim empty circle (unselected).
    @ViewBuilder
    private func selectionBadge(index: Int?, color: Color) -> some View {
        if let index {
            // Filled circle with the 1-based selection number inside.
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 26, height: 26)
                Text("\(index + 1)")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
            }
        } else {
            // Empty placeholder circle — same size as the badge so rows don't shift.
            Image(systemName: "circle")
                .font(.title3)
                .foregroundStyle(.secondary.opacity(0.4))
                .frame(width: 26, height: 26)
        }
    }


    // MARK: - Helpers

    private func durationLabel(for exercise: Exercise) -> String {
        let secs = exercise.durationSeconds
        let mins = secs / 60
        let rem  = secs % 60
        if mins == 0 { return "\(secs) sec" }
        if rem  == 0 { return "\(mins) min" }
        return "\(mins) min \(rem) sec"
    }

    private func categoryColor(for exercise: Exercise) -> Color {
        switch exercise.category {
        case .yoga:    return .indigo
        case .pilates: return .teal
        }
    }
}


// ─────────────────────────────────────────────
// MARK: - Preview
// ─────────────────────────────────────────────

#Preview {
    ExercisePickerView { picked in
        print("Selected: \(picked.map(\.name).joined(separator: ", "))")
    }
}
