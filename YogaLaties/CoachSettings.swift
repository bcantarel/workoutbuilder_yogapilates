//
//  CoachSettings.swift
//  YogaLaties
//
//  The single source of truth for the user's voice-coach preferences.
//  Lives in the SwiftUI environment so any view — Settings, ActiveSession,
//  VoicePreview — all read from the same object.
//
//  CGI ANALOGY: This is the **Project Preferences** file in a DCC like Maya
//  or Houdini — one central config that every tool in the pipeline reads.
//  When a director changes the default frame rate in Project Settings, every
//  scene, every render node, and every export preset picks it up automatically.
//  CoachSettings plays exactly that role for the voice coach: one change here
//  is felt everywhere.
//
//  Persistence: UserDefaults
//  ──────────────────────────
//  UserDefaults is Apple's built-in key-value store for small, lightweight
//  preferences — perfect for a float and a string. It's NOT appropriate for
//  structured relational data (that's what SwiftData is for), but for "what
//  voice does the user prefer?" it's exactly the right tool.
//
//  How the @Observable + didSet pattern works:
//  • `@Observable` makes SwiftUI track the stored properties automatically —
//    any view that reads `settings.speechRate` in its body will re-render
//    when that property changes.
//  • `didSet` is a Swift property observer that fires after the value is set.
//    We use it to persist the new value to UserDefaults immediately, so the
//    preference survives app restarts.
//  CGI ANALOGY: `didSet` is like an auto-save hook — every time you adjust a
//  slider in the DCC's preferences panel, it silently writes the new value to
//  the preferences file. No explicit save button needed.
//

import Foundation
import AVFoundation


// ─────────────────────────────────────────────
// MARK: - CoachSettings
// ─────────────────────────────────────────────

@Observable
final class CoachSettings {

    // ── Keys for UserDefaults ──────────────────────────────────────────────
    private enum Keys {
        static let voiceIdentifier  = "yogalaties.coach.voiceIdentifier"
        static let speechRate       = "yogalaties.coach.speechRate"
        static let pitchMultiplier  = "yogalaties.coach.pitchMultiplier"
    }

    var voiceIdentifier: String = UserDefaults.standard.string(forKey: Keys.voiceIdentifier) ?? "" {
        didSet { UserDefaults.standard.set(voiceIdentifier, forKey: Keys.voiceIdentifier) }
    }

    var speechRate: Float = {
        let stored = UserDefaults.standard.float(forKey: Keys.speechRate)
        return stored > 0 ? stored : 0.30
    }() {
        didSet { UserDefaults.standard.set(speechRate, forKey: Keys.speechRate) }
    }

    // ── Pitch ──────────────────────────────────────────────────────────────
    // AVSpeechUtterance.pitchMultiplier: 0.5 (low) → 2.0 (high).
    // We expose a narrower 0.80–1.30 range — anything outside that starts to
    // sound unnatural on typical synthesis voices.
    // Default 1.05: just a hair above neutral, feels warm without being shrill.
    //
    // CGI ANALOGY: Like adjusting the "harmonic resonance" on a voice-over
    // track — small tweaks have a big impact on perceived warmth and energy.
    var pitchMultiplier: Float = {
        let stored = UserDefaults.standard.float(forKey: Keys.pitchMultiplier)
        return stored > 0 ? stored : 1.05
    }() {
        didSet { UserDefaults.standard.set(pitchMultiplier, forKey: Keys.pitchMultiplier) }
    }

    var pitchLabel: String {
        switch pitchMultiplier {
        case ..<0.90: return "Very Calm"
        case ..<0.98: return "Calm"
        case ..<1.08: return "Neutral"
        case ..<1.18: return "Warm"
        default:      return "Upbeat"
        }
    }

    // ── Voice Resolution ───────────────────────────────────────────────────
    //
    // resolvedVoice is what VoiceCoach actually passes to every utterance.
    //
    // The old behaviour was: if no voice chosen → AVSpeechSynthesisVoice(language: "en-US")
    // That always returned the compact "Samantha" voice, even when the user had
    // downloaded a Premium voice. This fixes it: Auto now climbs the quality
    // ladder (Premium → Enhanced → system default) so downloaded voices are
    // used automatically without the user having to select one by name.
    //
    // CGI ANALOGY: Like a texture-resolution fallback chain — the renderer tries
    // 4K first, drops to 2K if unavailable, then 1K; it never stubbornly serves
    // a 512px proxy when a 4K asset is sitting right there on disk.
    //
    var resolvedVoice: AVSpeechSynthesisVoice? {
        guard !voiceIdentifier.isEmpty else {
            return CoachSettings.bestAvailableEnglishVoice()
        }
        // User picked a specific voice. Fall back to best-available if it
        // was deleted from the device (e.g. storage reclaimed by iOS).
        return AVSpeechSynthesisVoice(identifier: voiceIdentifier)
            ?? CoachSettings.bestAvailableEnglishVoice()
    }

    var selectedVoiceName: String {
        if voiceIdentifier.isEmpty {
            // Show the user what "Auto" actually resolved to.
            if let auto = CoachSettings.bestAvailableEnglishVoice() {
                return "Auto — \(auto.name)"
            }
            return "Auto (Best Available)"
        }
        return AVSpeechSynthesisVoice(identifier: voiceIdentifier)?.name
            ?? "Unknown Voice"
    }

    // Returns the highest-quality English voice installed on this device.
    // Prefers en-US; falls back to any English dialect if en-US has nothing
    // better than compact.
    //
    // CGI ANALOGY: The texture-picker function in a render farm that scans the
    // asset library and returns the highest-res version of the requested map
    // that is actually present on disk.
    static func bestAvailableEnglishVoice() -> AVSpeechSynthesisVoice? {
        let all = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en") && $0.voiceTraits != .isNoveltyVoice }

        // Prefer US English; only widen to all English if nothing good found.
        let usPool  = all.filter { $0.language == "en-US" }
        let pool    = usPool.isEmpty ? all : usPool

        if let v = pool.first(where: { $0.quality == .premium  }) { return v }
        if let v = pool.first(where: { $0.quality == .enhanced }) { return v }

        // Nothing downloaded yet — return system default.
        return AVSpeechSynthesisVoice(language: "en-US")
    }

    var speedLabel: String {
        switch speechRate {
        case ..<0.33: return "Very Slow"
        case ..<0.39: return "Slow"
        case ..<0.46: return "Calm"
        case ..<0.52: return "Normal"
        case ..<0.58: return "Brisk"
        default:      return "Fast"
        }
    }
}
