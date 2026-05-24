//
//  Haptics.swift
//  YogaLaties
//
//  Step 17 — Haptic Feedback Helper
//
//  A lightweight namespace that wraps UIKit's haptic generators into
//  single-line call sites. Call these anywhere in the app without having
//  to manually instantiate generators each time.
//
//  CGI ANALOGY: Think of this as a **Sound Design Patch-Bay** — a central
//  panel with named output channels (light tap, medium thud, success chime).
//  Any scene in the film calls the patch-bay by name; the patch-bay handles
//  routing to the actual hardware. No scene needs to know whether the
//  sound is a UIImpactFeedbackGenerator or a UINotificationFeedbackGenerator.
//
//  iOS Haptic types used here
//  ───────────────────────────
//  UIImpactFeedbackGenerator(style:)
//    Simulates a physical collision. Three intensities:
//    • .light   — a gentle tap; good for routine UI interactions.
//    • .medium  — a satisfying thud; good for significant transitions.
//    • .heavy   — a strong thump; reserved for major events.
//    CGI ANALOGY: Light = a soft cloth drape settling; Medium = a prop
//    hitting the floor; Heavy = a door slamming.
//
//  UINotificationFeedbackGenerator
//    Three semantic variants: .success, .warning, .error.
//    • .success — a double-tap pattern; universally understood as "done!".
//    CGI ANALOGY: The short fanfare that plays when the render farm reports
//    "All shots complete."
//
//  Usage
//  ──────
//    Haptics.light()     // button tap
//    Haptics.medium()    // exercise transition
//    Haptics.success()   // workout complete
//

import UIKit


// ─────────────────────────────────────────────
// MARK: - Haptics
// ─────────────────────────────────────────────
//
// Using a caseless enum as a namespace (same pattern as ExerciseLibrary)
// means nobody can accidentally write `let h = Haptics()`. All methods are
// static and called directly on the type.
//
// CGI ANALOGY: A pure utility module — like a Python module full of
// standalone functions that you import and call; no object needed.

enum Haptics {

    // ── Impact feedback ────────────────────────────────────────────────────

    /// Gentle tap — routine button presses, minor list interactions.
    static func light() {
        let g = UIImpactFeedbackGenerator(style: .light)
        g.impactOccurred()
    }

    /// Satisfying thud — exercise transitions, significant state changes.
    static func medium() {
        let g = UIImpactFeedbackGenerator(style: .medium)
        g.impactOccurred()
    }

    /// Strong bump — reserved for dramatic moments (currently unused,
    /// available for future use).
    static func heavy() {
        let g = UIImpactFeedbackGenerator(style: .heavy)
        g.impactOccurred()
    }


    // ── Notification feedback ──────────────────────────────────────────────

    /// Success double-tap — fires when a workout session completes.
    /// CGI ANALOGY: The "Render Complete" notification ping.
    static func success() {
        let g = UINotificationFeedbackGenerator()
        g.notificationOccurred(.success)
    }

    /// Warning pattern — available for future error / caution states.
    static func warning() {
        let g = UINotificationFeedbackGenerator()
        g.notificationOccurred(.warning)
    }
}
