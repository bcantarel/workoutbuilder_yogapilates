//
//  ContentView.swift
//  YogaLaties
//
//  Created by Brandi Cantarel on 5/9/26.
//

import SwiftUI

// ─────────────────────────────────────────────
// MARK: - Root App Entry Point
// ─────────────────────────────────────────────
//
// CGI ANALOGY: Think of ContentView as the "master scene" in a CGI pipeline.
// It wraps everything in a NavigationStack — the equivalent of the main camera
// rig that the whole film is shot through. Every push to a detail view is like
// the camera dolly-zooming into a specific asset in the scene.

struct ContentView: View {
    var body: some View {
        NavigationStack {
            ExerciseListView()
        }
    }
}


// ─────────────────────────────────────────────
// MARK: - Exercise List View
// ─────────────────────────────────────────────
//
// CGI ANALOGY: This is the "asset browser" panel you'd see in Houdini or Maya —
// a scrollable catalogue of every rig in the project, grouped by type (character,
// prop, environment). Here our "types" are Yoga and Pilates.

struct ExerciseListView: View {

    // @State is SwiftUI's reactive variable.
    // CGI ANALOGY: Imagine a scene parameter (like a frame-range slider) that,
    // when you change it, automatically triggers a re-render of anything that
    // depends on it. `exercises` drives the whole list — update it and the UI
    // redraws itself, just like changing a node value in a node graph refreshes
    // the viewport downstream.
    @State private var exercises: [Exercise] = []

    var body: some View {
        // `List` is a lazily-rendered, scrollable container.
        // CGI ANALOGY: Like a level-of-detail (LOD) system — only the rows
        // currently on screen are fully rendered; off-screen rows are deferred,
        // just as a LOD system only loads high-res geometry for what the camera
        // can actually see.
        List {
            // We iterate over every Category case (Yoga, then Pilates) and
            // create a Section for each group.
            // CGI ANALOGY: Each Section is a "render layer" — separate passes
            // that are composited together into the final image, letting you
            // work on Yoga and Pilates independently before the merge.
            ForEach(Exercise.Category.allCases, id: \.self) { category in
                let group = exercises.filter { $0.category == category }
                if !group.isEmpty {
                    Section {
                        ForEach(group) { exercise in
                            // NavigationLink is the "portal" to the detail view.
                            // CGI ANALOGY: Think of it as a hyperlink inside a
                            // rendered turntable — clicking an asset opens its
                            // full shader/rig breakdown sheet.
                            NavigationLink(value: exercise) {
                                ExerciseRowView(exercise: exercise)
                            }
                        }
                    } header: {
                        CategoryHeaderView(category: category)
                    }
                }
            }
        }
        .navigationTitle("Exercises")
        .navigationBarTitleDisplayMode(.large)
        // `navigationDestination` registers what view to push when the user
        // taps a NavigationLink whose value is an Exercise.
        // CGI ANALOGY: This is the "material assignment" step — you tell the
        // renderer "when you encounter an Exercise token, render it using the
        // ExerciseDetailView shader."
        .navigationDestination(for: Exercise.self) { exercise in
            ExerciseDetailView(exercise: exercise)
        }
        // `.task` runs async work when the view appears, on a background thread.
        // CGI ANALOGY: Like kicking off a render farm job the moment the scene
        // loads — the UI stays responsive (main thread) while the data work
        // happens off to the side, then the result streams back in.
        .task {
            if exercises.isEmpty {
                exercises = ExerciseLibrary.load()
            }
        }
    }
}


// ─────────────────────────────────────────────
// MARK: - Category Section Header
// ─────────────────────────────────────────────
//
// CGI ANALOGY: A render-pass label card — the bold "Beauty Pass" or "Shadow Pass"
// separator you'd see in a compositing tree like Nuke, telling you which layer
// you're looking at.

struct CategoryHeaderView: View {
    let category: Exercise.Category

    var icon: String {
        switch category {
        case .yoga:    return "figure.mind.and.body"
        case .pilates: return "figure.core.training"
        }
    }

    var accentColor: Color {
        switch category {
        case .yoga:    return .indigo
        case .pilates: return .teal
        }
    }

    var body: some View {
        Label(category.rawValue, systemImage: icon)
            .font(.headline)
            .foregroundStyle(accentColor)
            .textCase(nil)          // prevent SwiftUI's default ALLCAPS on section headers
            .padding(.vertical, 2)
    }
}


// ─────────────────────────────────────────────
// MARK: - Exercise Row View
// ─────────────────────────────────────────────
//
// CGI ANALOGY: Each row is a "thumbnail render" of an asset — a quick, low-cost
// preview (name + duration + badge) rather than the full 4K beauty render you'd
// get on the detail screen. The thumbnail tells you just enough to know which
// asset you want before you commit to opening it fully.

struct ExerciseRowView: View {
    let exercise: Exercise

    /// Converts raw seconds to a human-readable string: "30 sec", "1 min 30 sec", "2 min".
    /// CGI ANALOGY: Like a timecode formatter in an NLE — raw frame counts become
    /// "01:23:45:12" so a human can actually read the number.
    var durationLabel: String {
        let mins = exercise.durationSeconds / 60
        let secs = exercise.durationSeconds % 60
        switch (mins, secs) {
        case (0, let s):         return "\(s) sec"
        case (let m, 0):         return "\(m) min"
        default:                 return "\(mins) min \(secs) sec"
        }
    }

    var categoryColor: Color {
        switch exercise.category {
        case .yoga:    return .indigo
        case .pilates: return .teal
        }
    }

    var body: some View {
        HStack(spacing: 12) {

            // ExerciseImageView is the texture resolver — it checks Assets.xcassets
            // for a real icon first, falls back to an SF Symbol if none exists yet.
            // CGI ANALOGY: The little coloured swatch next to a material slot —
            // but now it shows the actual texture if one is loaded, or a proxy otherwise.
            ExerciseImageView(exercise: exercise, size: 44)

            // Name + duration stacked vertically.
            VStack(alignment: .leading, spacing: 3) {
                Text(exercise.displayName)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)

                Text(durationLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Category badge chip on the trailing edge.
            // CGI ANALOGY: The render-layer tag you stamp on every output EXR
            // so the compositor knows which pass it belongs to at a glance.
            Text(exercise.category.rawValue)
                .font(.caption2)
                .fontWeight(.semibold)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(categoryColor.opacity(0.12), in: Capsule())
                .foregroundStyle(categoryColor)
        }
        .padding(.vertical, 4)
    }
}


// ─────────────────────────────────────────────
// MARK: - Exercise Detail View
// ─────────────────────────────────────────────
//
// CGI ANALOGY: This is the full 4K beauty render of a single asset — every field
// exposed, the equivalent of opening an asset's property editor in your DCC tool
// and seeing every parameter: name, shader, rig, textures, notes.

struct ExerciseDetailView: View {
    let exercise: Exercise

    var categoryColor: Color {
        switch exercise.category {
        case .yoga:    return .indigo
        case .pilates: return .teal
        }
    }

    var durationLabel: String {
        let mins = exercise.durationSeconds / 60
        let secs = exercise.durationSeconds % 60
        switch (mins, secs) {
        case (0, let s): return "\(s) seconds"
        case (let m, 0): return "\(m) minute\(m == 1 ? "" : "s")"
        default:         return "\(mins) min \(secs) sec"
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // Hero image — large resolver at the top of the detail card.
                // CGI ANALOGY: The "hero shot" beauty render — full-res texture if it
                // exists, SF Symbol proxy if not. Same node, larger render target.
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(categoryColor.opacity(0.12))
                    ExerciseImageView(exercise: exercise, size: 140)
                        .padding(24)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal)

                // Meta cards — each field in its own card.
                // CGI ANALOGY: The individual parameter slots in a shader node —
                // each one isolated so you can see exactly what drives the output.
                VStack(spacing: 12) {
                    DetailCard(label: "Category",
                               value: exercise.category.rawValue,
                               icon: "tag.fill",
                               color: categoryColor)

                    DetailCard(label: "Duration",
                               value: durationLabel,
                               icon: "timer",
                               color: .orange)

                    DetailCard(label: "Image Reference",
                               value: exercise.imageName,
                               icon: "photo",
                               color: .gray)
                }
                .padding(.horizontal)

                // Coach Cue card — the spoken guidance text.
                // CGI ANALOGY: The "director's note" attached to an animation
                // keyframe — the creative intent that drives what the final output
                // should feel like, separate from the raw technical parameters.
                VStack(alignment: .leading, spacing: 8) {
                    Label("Coach Cue", systemImage: "waveform.and.mic")
                        .font(.headline)
                        .foregroundStyle(categoryColor)
                        .padding(.horizontal)

                    Text(exercise.displayCoachCue)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineSpacing(4)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color(.secondarySystemBackground))
                        )
                        .padding(.horizontal)
                }
            }
            .padding(.bottom, 32)
        }
        .navigationTitle(exercise.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }
}


// ─────────────────────────────────────────────
// MARK: - Detail Card (reusable sub-component)
// ─────────────────────────────────────────────
//
// CGI ANALOGY: A reusable "gizmo" or helper node in a node graph — you wire it in
// wherever you need the same shaped output (label + value in a styled card), just
// with different input parameters. DRY in CGI, DRY in SwiftUI.

struct DetailCard: View {
    let label: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
            }
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemBackground))
        )
    }
}


// ─────────────────────────────────────────────
// MARK: - Previews
// ─────────────────────────────────────────────
//
// CGI ANALOGY: A "playblast" — a quick, cheap render you use during development
// to check your work without waiting for a full production render. Xcode's Canvas
// panel is your playblast viewport.

#Preview("Exercise List") {
    // We inject one sample exercise so the preview never needs exercises.json.
    // CGI ANALOGY: A stub asset — a grey-shaded stand-in proxy you use while the
    // real texture is still being painted. Same shape, none of the final detail.
    NavigationStack {
        ExerciseListView()
    }
}

#Preview("Exercise Detail") {
    NavigationStack {
        ExerciseDetailView(exercise: .sampleExercise)
    }
}
