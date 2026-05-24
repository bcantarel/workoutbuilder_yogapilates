//
//  ExerciseIcon.swift
//  YogaLaties
//
//  This file is the entire "asset pipeline" for exercise imagery.
//  It has two jobs:
//    1. Map each imageName string → an SF Symbol fallback (used until real art arrives)
//    2. Provide ExerciseImageView — a smart view that checks Assets.xcassets first,
//       then falls back to the SF Symbol. Swapping in real icons requires zero code
//       changes: just drop the PDF/PNG into the asset catalog with the matching name.
//
//  CGI ANALOGY: Think of this file as a "texture resolver" node in a shading network.
//  The node checks whether a hi-res texture exists in the project's texture library
//  (Assets.xcassets). If it finds one, it loads it. If not, it outputs a flat-colour
//  stand-in (the SF Symbol) so the rest of the render doesn't break. The moment you
//  add the real texture to the library, the resolver picks it up automatically —
//  no changes anywhere else in the graph.

import SwiftUI

// ─────────────────────────────────────────────
// MARK: - SF Symbol Fallback Map
// ─────────────────────────────────────────────
//
// CGI ANALOGY: This dictionary is the "proxy library" — a catalogue of stand-in
// assets mapped to the same names as the final hero assets. A Houdini artist would
// call these "temp geos": correct names, placeholder geometry, ready to swap.
//
// Key   = imageName from exercises.json  (must match exactly, character-for-character)
// Value = SF Symbol name                 (all symbols below require iOS 16+)

enum ExerciseIcon {

    static let symbolMap: [String: String] = [

        // ── Yoga ──────────────────────────────────────────
        // Mountain Pose: standing upright, arms at sides
        "mountain_pose":            "figure.stand",

        // Downward Dog: inverted-V stretch, hips high
        "downward_dog":             "figure.flexibility",

        // Warrior I: deep lunge, arms raised overhead
        "warrior_one":              "figure.step.training",

        // Child's Pose: curled forward, forehead to mat
        "childs_pose":              "figure.roll",

        // Tree Pose: single-leg balance, arms overhead
        "tree_pose":                "figure.mind.and.body",

        // ── Pilates ───────────────────────────────────────
        // The Hundred: lying down, arms pulsing (high intensity)
        "pilates_hundred":          "figure.highintensity.intervaltraining",

        // Roll Up: controlled sit-up, spine articulation
        "pilates_rollup":           "figure.roll",

        // Single Leg Stretch: alternating leg pulls, core work
        "pilates_single_leg_stretch": "figure.step.training",

        // Plank: straight body hold, core braced
        "pilates_plank":            "figure.core.training",

        // Swan Dive: prone back extension, chest lifted
        "pilates_swan":             "figure.flexibility",
    ]

    /// Returns the SF Symbol name for a given imageName, with a safe default.
    ///
    /// CGI ANALOGY: The fallback is the "missing texture" checker — if a key isn't
    /// in the proxy library, you get a neutral grey rather than a crash.
    static func symbol(for imageName: String) -> String {
        symbolMap[imageName] ?? "figure.mind.and.body"
    }
}


// ─────────────────────────────────────────────
// MARK: - ExerciseImageView  (the smart resolver)
// ─────────────────────────────────────────────
//
// CGI ANALOGY: This view is the texture resolver node itself. Given an exercise,
// it asks: "Is there a hi-res asset in the catalog?" If yes → use it. If no →
// output the SF Symbol proxy. The rest of the scene never needs to know which
// path was taken; it just receives a correctly-shaped image either way.
//
// ADDING REAL ICONS:
//   1. Export your EPS as a PDF in Preview (File → Export → PDF)
//   2. In Xcode, open Assets.xcassets → + → New Image Set
//   3. Name the image set exactly as it appears in exercises.json
//      (e.g. "warrior_one" — no spaces, lowercase, underscores)
//   4. Drag your PDF into the "Universal" slot
//   Done. This view will pick it up automatically on the next build.

struct ExerciseImageView: View {

    let exercise: Exercise

    /// Drives the circle background and SF Symbol tint.
    /// Real photo assets ignore this color; it only applies to the SF Symbol path.
    var size: CGFloat = 44

    private var categoryColor: Color {
        switch exercise.category {
        case .yoga:    return .indigo
        case .pilates: return .teal
        }
    }

    // UIImage(named:) checks Assets.xcassets at runtime.
    // Returns nil if no image set with that name exists — the signal to fall back.
    // CGI ANALOGY: This is the "does this texture exist in the library?" query
    // that the resolver fires before deciding which path to take.
    private var hasRealAsset: Bool {
        UIImage(named: exercise.imageName) != nil
    }

    var body: some View {
        ZStack {
            // Tinted circle background — visible behind both real assets and SF Symbols.
            // For real photos you'd likely want .clear or a shadow instead; adjust as your
            // art direction evolves.
            Circle()
                .fill(categoryColor.opacity(hasRealAsset ? 0.08 : 0.15))
                .frame(width: size, height: size)

            if hasRealAsset {
                // ── Real asset path ──────────────────────────────────────────
                // CGI ANALOGY: The hi-res texture is on disk → load it for the
                // beauty render. `.scaledToFit` keeps the aspect ratio intact,
                // just like "fit" mode in a UV projection.
                Image(exercise.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size * 0.72, height: size * 0.72)
                    .clipShape(Circle())
            } else {
                // ── SF Symbol fallback path ──────────────────────────────────
                // CGI ANALOGY: No texture found → output the proxy stand-in.
                // The font size is 45 % of the container so it sits comfortably
                // inside the circle, mirroring how a thumbnail crop is padded.
                Image(systemName: ExerciseIcon.symbol(for: exercise.imageName))
                    .font(.system(size: size * 0.45))
                    .foregroundStyle(categoryColor)
            }
        }
        .frame(width: size, height: size)
    }
}


// ─────────────────────────────────────────────
// MARK: - Previews
// ─────────────────────────────────────────────

#Preview("SF Symbol fallback (no real asset)") {
    // Simulates the state before any EPS/PDF is added to the asset catalog.
    HStack(spacing: 16) {
        ExerciseImageView(exercise: .sampleExercise, size: 44)
        ExerciseImageView(exercise: .sampleExercise, size: 80)
        ExerciseImageView(exercise: .sampleExercise, size: 120)
    }
    .padding()
}
