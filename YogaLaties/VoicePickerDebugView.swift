//
//  VoicePickerDebugView.swift
//  YogaLaties
//
//  ⚠️  DEVELOPMENT TOOL — delete this file before shipping.
//
//  Lists every English voice installed on the device, lets you preview each
//  one with a real coaching phrase, and shows its identifier so you can paste
//  it into VoiceCoach.swift.
//
//  HOW TO USE:
//  1. Temporarily add a third tab in MainTabView.swift pointing here, e.g.:
//       Tab("Voice", systemImage: "waveform") { VoicePickerDebugView() }
//  2. Run the app on a real device (simulator voices are limited).
//  3. Tap ▶ on any voice to hear it speak the sample phrase.
//  4. When you find one you like, copy its identifier from the grey label.
//  5. Paste it into VoiceCoach.swift — replace the language: init with:
//       AVSpeechSynthesisVoice(identifier: "<paste here>")
//  6. Delete this file and remove the tab.
//
//  TIP: Download Enhanced / Premium voices first in
//  Settings → Accessibility → Spoken Content → Voices → English.
//  They sound dramatically better and are free.
//

import SwiftUI
import AVFoundation


// ─────────────────────────────────────────────
// MARK: - VoicePickerDebugView
// ─────────────────────────────────────────────

struct VoicePickerDebugView: View {

    // The sample text spoken when you tap ▶.
    // Edit this to match your actual coach cues so you hear exactly
    // how the voice will sound during a real workout.
    @State private var sampleText = "Mountain Pose. Stand tall, feet together, arms at your sides, and breathe steadily. 5 seconds. Next up — Warrior Pose."

    @State private var searchText  = ""
    @State private var playingID: String? = nil     // identifier of the voice currently speaking

    private let synthesizer = AVSpeechSynthesizer()

    // All English voices, sorted: Premium first, then Enhanced, then Compact.
    private var allVoices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice
            .speechVoices()
            .filter { $0.language.hasPrefix("en") }
            .sorted {
                // Higher quality tier sorts earlier.
                if $0.quality != $1.quality { return $0.quality.rawValue > $1.quality.rawValue }
                return $0.name < $1.name
            }
    }

    // Filtered by the search field.
    private var filteredVoices: [AVSpeechSynthesisVoice] {
        guard !searchText.isEmpty else { return allVoices }
        return allVoices.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.language.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List {

                // ── Sample text editor ─────────────────────────────────────
                Section {
                    TextEditor(text: $sampleText)
                        .font(.subheadline)
                        .frame(minHeight: 80)
                } header: {
                    Text("Sample phrase")
                } footer: {
                    Text("Edit this to match a real coach cue, then tap ▶ on each voice.")
                }

                // ── Voice list ─────────────────────────────────────────────
                Section {
                    ForEach(filteredVoices, id: \.identifier) { voice in
                        voiceRow(voice)
                    }
                } header: {
                    Text("\(filteredVoices.count) English voices")
                }
            }
            .navigationTitle("Voice Picker")
            .searchable(text: $searchText, prompt: "Filter by name or locale")
            .onDisappear { synthesizer.stopSpeaking(at: .immediate) }
        }
    }


    // ── One voice row ──────────────────────────────────────────────────────

    @ViewBuilder
    private func voiceRow(_ voice: AVSpeechSynthesisVoice) -> some View {
        HStack(spacing: 12) {

            // ▶ / ■ play/stop button
            Button {
                togglePlayback(voice)
            } label: {
                Image(systemName: playingID == voice.identifier
                      ? "stop.circle.fill"
                      : "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(
                        playingID == voice.identifier ? .orange : .indigo
                    )
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 3) {

                // Voice name + locale
                HStack(spacing: 6) {
                    Text(voice.name)
                        .font(.body)
                        .fontWeight(.medium)

                    Text(voice.language)
                        .font(.caption2)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.15))
                        .clipShape(Capsule())
                }

                // Quality tier badge
                qualityBadge(for: voice.quality)

                // Identifier — tap & hold to copy
                Text(voice.identifier)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)   // long-press → Copy
            }
        }
        .padding(.vertical, 4)
        // Highlight the currently playing row
        .listRowBackground(
            playingID == voice.identifier
                ? Color.orange.opacity(0.08)
                : Color.clear
        )
    }


    // ── Quality tier badge ─────────────────────────────────────────────────

    @ViewBuilder
    private func qualityBadge(for quality: AVSpeechSynthesisVoiceQuality) -> some View {
        let (label, color): (String, Color) = switch quality {
        case .premium:  ("Premium ★",  .indigo)
        case .enhanced: ("Enhanced ◆", .teal)
        default:        ("Compact",    .secondary)
        }

        Text(label)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.12))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }


    // ── Playback logic ─────────────────────────────────────────────────────

    private func togglePlayback(_ voice: AVSpeechSynthesisVoice) {
        if playingID == voice.identifier {
            // Tapping the playing voice stops it.
            synthesizer.stopSpeaking(at: .immediate)
            playingID = nil
        } else {
            synthesizer.stopSpeaking(at: .immediate)

            let utterance = AVSpeechUtterance(string: sampleText)
            utterance.voice          = voice
            utterance.rate           = 0.48
            utterance.pitchMultiplier = 1.08
            utterance.volume         = 1.0

            playingID = voice.identifier
            synthesizer.speak(utterance)

            // Clear the playing indicator after a generous timeout in case
            // the delegate isn't wired (keeps UI tidy).
            let duration = sampleText.count  // rough proxy for speech length
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(duration) * 0.08 + 3) {
                if playingID == voice.identifier { playingID = nil }
            }
        }
    }
}


// ─────────────────────────────────────────────
// MARK: - Preview
// ─────────────────────────────────────────────

#Preview {
    VoicePickerDebugView()
}
