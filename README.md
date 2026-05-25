# YogaLaties

A guided yoga & Pilates workout app for iPhone. Inspired by the Wii Fit routine builder — you assemble a custom exercise sequence and a voice coach walks you through every move, hands-free.

## Features

- **Exercise Library** — 20 bundled exercises split across two disciplines:
  - *Yoga (10):* Mountain Pose, Tree Pose, Warrior I, Downward Dog, Child's Pose, Cobra Pose, Chair Pose, Bridge Pose, Cat Stretch, Sun Salutation, and more
  - *Pilates (10):* The Hundred, Roll-Up, Roll-Over, Single Leg Stretch, Double Leg Kick, Plank, and more
- **Routine Builder** — create, reorder, and save unlimited custom routines using SwiftData
- **Guided Sessions** — tap Start on any routine and the app automatically counts down each exercise and advances to the next
- **Voice Coach** — spoken announcements (exercise name + coaching cue) powered by AVSpeechSynthesizer, with tone variations for countdowns and session completion
- **Customisable Coach** — choose from any system voice and adjust speech rate and pitch; changes take effect immediately mid-session
- **Session Summary** — post-workout recap showing total time and exercises completed
- **Haptic Feedback** — subtle haptics on key transitions for a polished feel

## Tech Stack

| Concern | Solution |
|---|---|
| Language | Swift 5.9 |
| UI | SwiftUI (iOS 17+) |
| Persistence | SwiftData |
| Voice | AVSpeechSynthesizer |
| Preferences | UserDefaults |
| Exercise data | Bundled `exercises.json` |

## Project Structure

```
YogaLaties/
├── YogaLaties/
│   ├── YogaLatiesApp.swift        # App entry point
│   ├── MainTabView.swift          # Tab bar shell
│   ├── ContentView.swift          # Exercise library browse & detail
│   ├── MyRoutinesView.swift       # Saved routines list
│   ├── RoutineDetailView.swift    # Routine detail & start
│   ├── RoutineBuilderView.swift   # Create / edit a routine
│   ├── ExercisePickerView.swift   # Add exercises to a routine
│   ├── ActiveSessionView.swift    # Guided workout screen
│   ├── SessionSummaryView.swift   # Post-workout results
│   ├── SettingsView.swift         # Voice coach preferences
│   ├── SessionEngine.swift        # Timer state machine (@Observable)
│   ├── VoiceCoach.swift           # AVSpeechSynthesizer wrapper
│   ├── CoachSettings.swift        # Shared voice preferences
│   ├── Exercise.swift             # Exercise struct + Category enum
│   ├── Routine.swift              # SwiftData Routine model
│   ├── RoutineExercise.swift      # SwiftData slot model
│   ├── ExerciseLibrary.swift      # Loads exercises.json at runtime
│   ├── ExerciseIcon.swift         # Image-name → asset helper
│   ├── Haptics.swift              # Haptic feedback helper
│   └── Assets.xcassets/           # Exercise images (3 sizes), app icon
├── YogaLatiesTests/
└── YogaLatiesUITests/
```

## Architecture Notes

**SessionEngine** is a pure state machine decoupled from the UI. It owns the countdown timer, tracks the current exercise index, and exposes `@Observable` properties that views react to automatically — no view ever touches the timer directly.

**Exercise data** is a plain struct loaded from `exercises.json` at launch, not a SwiftData model. Exercises are read-only library data; SwiftData is reserved for user-generated routines.

**VoiceCoach** reads from `CoachSettings` on every utterance, so voice, rate, and pitch changes in Settings take effect for the very next announcement without restarting the session.

## Requirements

- Xcode 15+
- iOS 17+
- No third-party dependencies

## Getting Started

1. Clone or download the repo
2. Open `YogaLaties.xcodeproj` in Xcode
3. Select your target device or simulator (iPhone, iOS 17+)
4. Build & run (`⌘R`)

No API keys, no accounts, no setup beyond Xcode.
