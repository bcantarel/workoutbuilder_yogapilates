//
//  SettingsView.swift
//  YogaLaties
//
//  The Settings tab. Lets the user tune the voice coach:
//    • Speech speed — a slider from Very Slow → Fast with live preview
//    • Voice — a searchable list of all installed English voices, grouped
//      by quality tier, each with a ▶ preview button and a ✓ when selected
//
//  CGI ANALOGY: The project's "Output Settings" panel — lets the director
//  configure which "voice actor" (AVSpeechSynthesisVoice) is wired into the
//  PA system and at what "playback speed" (speechRate). All downstream render
//  nodes (workout sessions) pick up changes automatically.
//
//  Key iOS 17 concept: @Bindable
//  ──────────────────────────────
//  CoachSettings lives in the environment as an @Observable object. To bind
//  a SwiftUI control (Slider, Picker, etc.) to one of its properties, we need
//  a *binding* — a two-way live connection that reads the current value AND
//  writes changes back. With @Observable we get bindings by declaring a local
//  `@Bindable var settings = settings` inside `body`. After that line,
//  `$settings.speechRate` is a valid Binding<Float> for the Slider.
//
//  CGI ANALOGY: A `@Bindable` wrapper is like attaching a "parameter expression"
//  channel in Houdini — the slider in the UI is wired directly to the parameter;
//  dragging it writes back to the source immediately.
//

import SwiftUI
import AVFoundation


// ─────────────────────────────────────────────
// MARK: - SettingsView
// ─────────────────────────────────────────────

struct SettingsView: View {

    @Environment(CoachSettings.self) private var settings

    // Search text for filtering the voice list.
    @State private var searchText = ""

    // Identifier of whichever voice is currently being previewed (▶ button).
    // nil = nothing playing.
    @State private var previewingID: String? = nil

    // A dedicated synthesizer just for previews in this view.
    // Separate from the session coach so it never interrupts a live workout.
    //
    // CGI ANALOGY: A "scratchpad render node" — lets you test a new voice or
    // speed setting without sending it to the main render queue.
    @State private var previewSynth = AVSpeechSynthesizer()


    // ── Derived voice data ──────────────────────────────────────────────────

    /// The ISO language code for the current device locale (e.g. "fr", "en", "es").
    private var currentLangCode: String {
        Locale.current.language.languageCode?.identifier ?? "en"
    }

    /// True when the user has downloaded at least one Enhanced or Premium voice
    /// for the current device language. Used to show/hide the "download better voices" tip.
    private var hasHighQualityVoices: Bool {
        AVSpeechSynthesisVoice.speechVoices().contains {
            $0.language.hasPrefix(currentLangCode) &&
            ($0.quality == .enhanced || $0.quality == .premium)
        }
    }

    /// All voices for the current device language, grouped by quality tier.
    /// Premium first (best), then Enhanced, then Compact.
    /// CGI ANALOGY: Like showing all texture resolutions available for a given
    /// asset — 4K, 2K, 1K — filtered to the current project's language "asset set".
    private var voiceGroups: [(title: String, voices: [AVSpeechSynthesisVoice])] {
        let langVoices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix(currentLangCode) && $0.voiceTraits != .isNoveltyVoice }

        let premium  = langVoices.filter { $0.quality == .premium  }.sorted { $0.name < $1.name }
        let enhanced = langVoices.filter { $0.quality == .enhanced }.sorted { $0.name < $1.name }
        let compact  = langVoices.filter { $0.quality == .default  }.sorted { $0.name < $1.name }

        var groups: [(String, [AVSpeechSynthesisVoice])] = []
        if !premium.isEmpty  { groups.append(("Premium ★",  premium))  }
        if !enhanced.isEmpty { groups.append(("Enhanced ◆", enhanced)) }
        if !compact.isEmpty  { groups.append(("Compact",    compact))  }
        return groups
    }

    /// Personal Voice — user-recorded synthetic voices from
    /// Settings → Accessibility → Personal Voice (iOS 17+).
    /// Requires AVSpeechSynthesizer.requestPersonalVoiceAuthorization() to have
    /// been called first, otherwise this list is always empty.
    private var personalVoices: [AVSpeechSynthesisVoice] {
        guard #available(iOS 17, *) else { return [] }
        return AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.voiceTraits.contains(.isPersonalVoice) }
            .sorted { $0.name < $1.name }
    }

    /// A localised path to where the user downloads voices for their language.
    /// Points to the right language section in iOS Settings automatically.
    private var voiceDownloadPath: String {
        switch currentLangCode {
        case "fr": return String(localized: "voice.download_path.fr")
        case "es": return String(localized: "voice.download_path.es")
        case "pt": return String(localized: "voice.download_path.pt")
        default:   return String(localized: "voice.download_path.en")
        }
    }

    /// Voice groups filtered by the search bar.
    private var filteredGroups: [(title: String, voices: [AVSpeechSynthesisVoice])] {
        guard !searchText.isEmpty else { return voiceGroups }
        return voiceGroups.compactMap { group in
            let filtered = group.voices.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.language.localizedCaseInsensitiveContains(searchText)
            }
            return filtered.isEmpty ? nil : (group.title, filtered)
        }
    }


    // ── Body ────────────────────────────────────────────────────────────────

    var body: some View {
        // `@Bindable var settings = settings` creates a bindable wrapper so
        // $settings.speechRate etc. work as two-way bindings in controls.
        // This is the iOS 17 @Observable pattern — no @ObservedObject needed.
        @Bindable var settings = settings

        NavigationStack {
            List {
                speedSection(settings: $settings.speechRate)
                pitchSection(settings: $settings.pitchMultiplier)
                voiceSections(settings: settings)
            }
            .navigationTitle("Settings")
            .searchable(text: $searchText,
                        placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Search voices")
            .onDisappear { previewSynth.stopSpeaking(at: .immediate) }
        }
    }


    // ─────────────────────────────────────────────
    // MARK: - Speed Section
    // ─────────────────────────────────────────────

    private func speedSection(settings speechRate: Binding<Float>) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 14) {

                // Label row: name on left, current value label on right.
                HStack {
                    Text("Speech Speed")
                        .font(.body)
                    Spacer()
                    Text(self.settings.speedLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .animation(.easeInOut, value: self.settings.speedLabel)
                }

                // The slider itself.
                // Range 0.25 → 0.65 covers all practical coaching speeds while
                // keeping the extremes usable. The full 0.0–1.0 range is
                // available in the API but 0.0 sounds comically robotic and
                // 1.0 sounds like a legal disclaimer voiceover.
                Slider(value: speechRate, in: 0.25...0.65, step: 0.05)
                    .tint(.indigo)

                // "Slow" / "Fast" end labels below the slider.
                HStack {
                    Text("Slower").font(.caption2).foregroundStyle(.secondary)
                    Spacer()
                    Text("Faster").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 6)

            // Preview button — speaks a sample coaching phrase at the
            // currently selected rate so the user can hear the change live.
            Button {
                previewCurrentSettings(voiceIdentifier: self.settings.voiceIdentifier,
                                       rate: self.settings.speechRate,
                                       pitch: self.settings.pitchMultiplier,
                                       tag: "__speed_preview__")
            } label: {
                Label(previewingID == "__speed_preview__"
                      ? "Stop Preview"
                      : "Preview Speed",
                      systemImage: previewingID == "__speed_preview__"
                      ? "stop.circle" : "play.circle")
                    .foregroundStyle(.indigo)
            }

        } header: {
            Text("Coach Speed")
        } footer: {
            Text("\"Calm\" (~0.40) works well for yoga. Adjust until it feels right for you.")
        }
    }


    // ─────────────────────────────────────────────
    // MARK: - Pitch Section
    // ─────────────────────────────────────────────

    private func pitchSection(settings pitchMultiplier: Binding<Float>) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 14) {

                // Label row.
                HStack {
                    Text("Voice Pitch")
                        .font(.body)
                    Spacer()
                    Text(self.settings.pitchLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .animation(.easeInOut, value: self.settings.pitchLabel)
                }

                // Slider: 0.80 (very calm) → 1.30 (upbeat).
                // The full API range is 0.5–2.0 but values outside this
                // narrower band sound unnatural on most synthesis voices.
                Slider(value: pitchMultiplier, in: 0.80...1.30, step: 0.05)
                    .tint(.indigo)

                // End labels.
                HStack {
                    Text("Calmer").font(.caption2).foregroundStyle(.secondary)
                    Spacer()
                    Text("More Upbeat").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 6)

            // Preview button.
            Button {
                previewCurrentSettings(voiceIdentifier: self.settings.voiceIdentifier,
                                       rate: self.settings.speechRate,
                                       pitch: self.settings.pitchMultiplier,
                                       tag: "__pitch_preview__")
            } label: {
                Label(previewingID == "__pitch_preview__"
                      ? "Stop Preview"
                      : "Preview Pitch",
                      systemImage: previewingID == "__pitch_preview__"
                      ? "stop.circle" : "play.circle")
                    .foregroundStyle(.indigo)
            }

        } header: {
            Text("Coach Pitch")
        } footer: {
            Text("\"Neutral\" is the default. Lower values feel more meditative; higher values feel more energising.")
        }
    }


    // ─────────────────────────────────────────────
    // MARK: - Voice Sections
    // ─────────────────────────────────────────────

    @ViewBuilder
    private func voiceSections(settings: CoachSettings) -> some View {

        // ── Download tip ────────────────────────────────────────────────────
        // Shown only when the user has no Enhanced or Premium voices installed.
        // Once they download one, this section disappears automatically.
        //
        // CGI ANALOGY: The "missing texture" warning in a DCC viewport — it
        // appears when only proxy assets are found and disappears the moment
        // the high-res files land in the asset library.
        if !hasHighQualityVoices {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Free upgrade available", systemImage: "arrow.down.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.indigo)
                    Text("voice.tip.description")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("voice.tip.how_to")
                        .font(.subheadline.weight(.medium))
                    Text(voiceDownloadPath)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            } header: {
                Text("Improve Voice Quality")
            }
        }

        // "Auto" row — always at the top.
        // Shows the name of the voice Auto will actually use (e.g. "Auto — Ava")
        // so the user can see the benefit of downloading a Premium voice.
        Section {
            voiceRow(
                name: settings.selectedVoiceName,   // "Auto — Ava" or "Auto (Best Available)"
                locale: "en-US",
                quality: nil,
                identifier: "",                     // empty string = Auto mode
                isSelected: settings.voiceIdentifier.isEmpty,
                settings: settings
            )
        } header: {
            Text("Coach Voice")
        } footer: {
            Text("Auto always uses the best voice you have installed. Download a Premium voice and Auto upgrades instantly — no selection needed.")
        }

        // Personal Voice — shown first if the user has one recorded.
        // Requires iOS 17+ and prior authorization via requestPersonalVoiceAuthorization().
        if !personalVoices.isEmpty {
            Section {
                ForEach(personalVoices, id: \.identifier) { voice in
                    voiceRow(
                        name: voice.name,
                        locale: voice.language,
                        quality: voice.quality,
                        identifier: voice.identifier,
                        isSelected: settings.voiceIdentifier == voice.identifier,
                        settings: settings
                    )
                }
            } header: {
                Text("Personal Voice 🎙")
            } footer: {
                Text("Your personally recorded voice, created in Settings → Accessibility → Personal Voice.")
            }
        }

        // Quality-grouped voice rows.
        ForEach(filteredGroups, id: \.title) { group in
            Section(group.title) {
                ForEach(group.voices, id: \.identifier) { voice in
                    voiceRow(
                        name: voice.name,
                        locale: voice.language,
                        quality: voice.quality,
                        identifier: voice.identifier,
                        isSelected: settings.voiceIdentifier == voice.identifier,
                        settings: settings
                    )
                }
            }
        }

        if filteredGroups.isEmpty && !searchText.isEmpty {
            Section {
                Text("No voices match \"\(searchText)\".")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            }
        }
    }


    // ─────────────────────────────────────────────
    // MARK: - Voice Row
    // ─────────────────────────────────────────────

    private func voiceRow(
        name: String,
        locale: String,
        quality: AVSpeechSynthesisVoiceQuality?,
        identifier: String,
        isSelected: Bool,
        settings: CoachSettings
    ) -> some View {
        HStack(spacing: 12) {

            // ▶ / ■ preview button.
            Button {
                toggleVoicePreview(identifier: identifier,
                                   rate: settings.speechRate)
            } label: {
                Image(systemName: previewingID == identifier && identifier != ""
                      ? "stop.circle.fill"
                      : "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(
                        previewingID == identifier ? .orange : .indigo.opacity(0.8)
                    )
            }
            .buttonStyle(.plain)

            // Name, locale chip, quality badge.
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(name)
                        .font(.body)
                        .fontWeight(isSelected ? .semibold : .regular)

                    Text(locale)
                        .font(.caption2)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.12))
                        .clipShape(Capsule())
                }

                if let quality {
                    qualityBadge(quality)
                }
            }

            Spacer()

            // ✓ Selected indicator.
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.indigo)
            }
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())      // makes the whole row tappable
        .onTapGesture {
            settings.voiceIdentifier = identifier
        }
        // Highlight the row being previewed.
        .listRowBackground(
            previewingID == identifier && !identifier.isEmpty
                ? Color.orange.opacity(0.07)
                : Color.clear
        )
    }


    // ─────────────────────────────────────────────
    // MARK: - Quality Badge
    // ─────────────────────────────────────────────

    @ViewBuilder
    private func qualityBadge(_ quality: AVSpeechSynthesisVoiceQuality) -> some View {
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


    // ─────────────────────────────────────────────
    // MARK: - Preview Playback
    // ─────────────────────────────────────────────

    // Sample text that exercises the voice on real coaching phrases.
    private let previewText = "Mountain Pose. Stand tall, feet together, arms at your sides, and breathe steadily. 5 seconds — next up, Warrior Pose."

    /// Previews the selected voice at the current speed and pitch settings.
    private func toggleVoicePreview(identifier: String, rate: Float) {
        previewSynth.stopSpeaking(at: .immediate)

        // Tapping the playing voice stops it.
        if previewingID == identifier {
            previewingID = nil
            return
        }

        let voice = identifier.isEmpty
            ? AVSpeechSynthesisVoice(language: "en-US")
            : AVSpeechSynthesisVoice(identifier: identifier)

        speakPreview(text: previewText, voice: voice, rate: rate,
                     pitch: settings.pitchMultiplier, tag: identifier)
    }

    /// Previews the current speed/pitch with whatever voice is selected.
    private func previewCurrentSettings(
        voiceIdentifier: String,
        rate: Float,
        pitch: Float = 1.05,
        tag: String = "__speed_preview__"
    ) {
        previewSynth.stopSpeaking(at: .immediate)

        if previewingID == tag {
            previewingID = nil
            return
        }

        let voice = voiceIdentifier.isEmpty
            ? AVSpeechSynthesisVoice(language: "en-US")
            : AVSpeechSynthesisVoice(identifier: voiceIdentifier)

        speakPreview(text: previewText, voice: voice, rate: rate, pitch: pitch, tag: tag)
    }

    private func speakPreview(
        text: String,
        voice: AVSpeechSynthesisVoice?,
        rate: Float,
        pitch: Float,
        tag: String
    ) {
        let utterance             = AVSpeechUtterance(string: text)
        utterance.voice           = voice
        utterance.rate            = rate
        utterance.pitchMultiplier = pitch
        utterance.volume          = 1.0
        utterance.preUtteranceDelay = 0.1

        previewingID = tag
        previewSynth.speak(utterance)

        // Clear the indicator after an estimated duration.
        // word count × avg seconds/word at given rate, + buffer.
        let words    = Double(text.split(separator: " ").count)
        let estSecs  = (words / 2.5) * Double(0.5 / rate) + 1.5
        DispatchQueue.main.asyncAfter(deadline: .now() + estSecs) {
            if previewingID == tag { previewingID = nil }
        }
    }
}


// ─────────────────────────────────────────────
// MARK: - Preview
// ─────────────────────────────────────────────

#Preview {
    SettingsView()
        .environment(CoachSettings())
}
