//
//  VoiceCoach.swift
//  YogaLaties
//
//  Step 14 — Voice Coach
//
//  Wraps AVSpeechSynthesizer and drives all spoken announcements during a
//  workout session. Voice, speech rate, and pitch are read from CoachSettings
//  on every utterance, so changes made in the Settings tab take effect
//  immediately for the next announcement — no restart needed.
//
//  Tone variations
//  ───────────────
//  Rather than one flat voice throughout, each announcement type adjusts the
//  base settings slightly to match the emotional moment:
//
//    • Exercise start   — two queued utterances: the name (slight pitch bump
//                         for emphasis) then the coaching cue (user pitch,
//                         with a 0.55 s pause so it lands calmly after the name)
//    • Countdown        — rate ticked up ×1.15 (capped at 0.65) for a subtle
//                         sense of urgency; pitch unchanged
//    • Workout complete — pitch raised ×1.10 (capped at 1.3) for a warm,
//                         celebratory feel
//
//  CGI ANALOGY: The PA amplifier unit on a render farm. The CoachSettings
//  object is the patch bay — the operator changes which voice actor is wired
//  in and at what output level, and the very next announcement goes out with
//  those new settings. This class adds a small "EQ rack" on top: it nudges
//  the signal for each type of announcement the way a mixing engineer would
//  boost the highs on a congratulatory sting versus a calm instruction.
//

import AVFoundation


// ─────────────────────────────────────────────
// MARK: - VoiceCoach
// ─────────────────────────────────────────────

final class VoiceCoach {

    private let synthesizer = AVSpeechSynthesizer()

    // The settings object this coach reads from.
    // Stored as a reference (class), so any change the user makes in
    // SettingsView is visible here instantly — no re-injection needed.
    private let settings: CoachSettings

    init(settings: CoachSettings) {
        self.settings = settings
        Self.configureAudioSession()
    }

    /// Sets up AVAudioSession so the speech synthesizer is audible on a
    /// physical device regardless of the ring/silent switch position.
    ///
    /// Without this, AVSpeechSynthesizer defaults to the "soloAmbient"
    /// category, which iOS silences when the silent switch is on or when
    /// another app holds the audio focus. `.playback` + `.spokenAudio`
    /// tells iOS: "this is intentional spoken audio — keep it playing."
    ///
    /// CGI ANALOGY: Routing the PA output to the main speakers instead of
    /// the monitor mix — without this, the signal exists but nobody hears it.
    private static func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .spokenAudio,
                options: .duckOthers   // briefly lowers music/podcasts while speaking
            )
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // Non-fatal — the synthesizer may still work in some scenarios.
            print("⚠️ VoiceCoach: audio session setup failed: \(error)")
        }
    }


    // ─────────────────────────────────────────────
    // MARK: - Public Announcements
    // ─────────────────────────────────────────────

    /// Called when a new exercise starts.
    /// Speaks the exercise name first, then — after a natural pause —
    /// delivers the full coaching cue at the user's chosen pitch.
    func announceExerciseStart(_ exercise: Exercise) {
        stop()

        // Utterance 1 — the exercise name.
        // A small pitch bump (×1.05) gives it a slight emphasis, like a
        // teacher announcing the next move before explaining it.
        synthesizer.speak(makeUtterance(
            text:     exercise.name + ".",
            rate:     settings.speechRate,
            pitch:    min(settings.pitchMultiplier * 1.05, 1.3),
            preDelay: 0.15
        ))

        // Utterance 2 — the coaching cue.
        // The 0.55 s pre-delay creates the natural beat of silence between
        // hearing the pose name and receiving the instruction, matching how
        // a real yoga teacher would pause to let the student settle.
        synthesizer.speak(makeUtterance(
            text:     exercise.coachCue,
            rate:     settings.speechRate,
            pitch:    settings.pitchMultiplier,
            preDelay: 0.55
        ))
    }

    /// Called at roughly the midpoint of a long exercise.
    /// Intentionally does NOT call stop() — it queues after the coaching cue
    /// so the trainer waits for the description to finish before speaking.
    /// If the exercise ends or a skip happens before this plays, the new
    /// exercise's stop() call cleanly discards it.
    func announceBreathingReminder() {
        synthesizer.speak(makeUtterance(
            text:     "Keep that breath flowing... you're doing beautifully.",
            rate:     max(settings.speechRate * 0.95, 0.25),   // fractionally softer
            pitch:    settings.pitchMultiplier * 0.97,          // just a touch lower
            preDelay: 0.3
        ))
    }

    /// Called when `secondsRemaining` drops to 10.
    /// Interrupts ongoing speech — this cue is time-sensitive.
    func announceTenSecondWarning(nextExercise: Exercise?) {
        let text = nextExercise != nil
            ? "10 more seconds — almost there!"
            : "10 seconds — finish strong!"
        stop()
        synthesizer.speak(makeUtterance(
            text:     text,
            rate:     min(settings.speechRate * 1.10, 0.65),
            pitch:    settings.pitchMultiplier,
            preDelay: 0.1
        ))
    }

    /// Called when `secondsRemaining` drops to 5.
    /// Rate ticked up slightly for a subtle sense of urgency.
    func announceCountdownWarning(nextExercise: Exercise?) {
        let text: String
        if let next = nextExercise {
            text = "5 seconds. Next up — \(next.name)."
        } else {
            text = "5 seconds. Last one — finish strong!"
        }

        stop()
        synthesizer.speak(makeUtterance(
            text:     text,
            rate:     min(settings.speechRate * 1.15, 0.65),
            pitch:    settings.pitchMultiplier,
            preDelay: 0.1
        ))
    }

    /// Called when the entire session finishes.
    /// Pitch nudged up ×1.10 for a warm, celebratory tone.
    func announceWorkoutComplete(routineName: String) {
        stop()
        synthesizer.speak(makeUtterance(
            text:     "Workout complete! Great job finishing \(routineName).",
            rate:     settings.speechRate,
            pitch:    min(settings.pitchMultiplier * 1.10, 1.3),
            preDelay: 0.2
        ))
    }

    /// Immediately silences any in-progress speech.
    func stop() {
        guard synthesizer.isSpeaking else { return }
        synthesizer.stopSpeaking(at: .immediate)
    }


    // ─────────────────────────────────────────────
    // MARK: - Private
    // ─────────────────────────────────────────────

    /// Builds a fully configured AVSpeechUtterance.
    /// All public announcement methods route through here so there is a
    /// single place to wire up voice, rate, pitch, volume, and delay.
    private func makeUtterance(
        text:     String,
        rate:     Float,
        pitch:    Float,
        preDelay: TimeInterval = 0.1
    ) -> AVSpeechUtterance {
        let u               = AVSpeechUtterance(string: text)
        u.voice             = settings.resolvedVoice
        u.rate              = rate
        u.pitchMultiplier   = pitch
        u.volume            = 1.0
        u.preUtteranceDelay = preDelay
        return u
    }
}
