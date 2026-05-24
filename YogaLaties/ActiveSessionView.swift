//
//  ActiveSessionView.swift
//  YogaLaties
//
//  Step 15 — Full Active Session Screen
//
//  The guided workout view. Shows the current exercise, a live countdown ring
//  that shrinks in real time, transport controls, a "next up" preview card, and
//  a pause overlay. Wires the SessionEngine to the VoiceCoach so speech fires
//  automatically as the session progresses.
//
//  CGI ANALOGY: The polished Render Farm Monitor dashboard. It shows:
//    • The shot currently rendering (exercise hero)
//    • A real-time progress ring draining as frames are consumed (countdown arc)
//    • The upcoming shot in the queue (next-up card)
//    • Transport controls (pause, skip back, skip forward)
//    • A frozen/dimmed overlay when the farm is paused
//  All of this just reads from the SessionEngine (dispatcher) — it never
//  touches the timer or shot list directly.
//
//  Key concepts introduced in this file
//  ──────────────────────────────────────
//  Circle().trim(from:to:)
//    Draws only a portion of the circle's stroke — `from: 0, to: 0.75` draws
//    three-quarters of the ring. We animate `to:` down from 1.0 → 0.0 as time
//    runs out. CGI ANALOGY: a progress arc that drains like a depleting render
//    budget.
//
//  .contentTransition(.numericText(countsDown: true))
//    iOS 17 API: animates number changes with a rolling-digit effect, the same
//    way an airport departure board flips. Passing `countsDown: true` makes the
//    digits roll in the downward direction, which matches our countdown.
//
//  .onChange(of:) { old, new in }
//    iOS 17 two-parameter onChange: fires whenever a value changes, giving you
//    both the old and new value. We use it to detect specific transitions
//    (currentIndex changed → new exercise; secondsRemaining == 5 → warning).
//    CGI ANALOGY: A Shotgrid event listener that fires only when a specific
//    field on the shot record changes.
//

import SwiftUI
import SwiftData


// ─────────────────────────────────────────────
// MARK: - ActiveSessionView
// ─────────────────────────────────────────────

struct ActiveSessionView: View {

    // Passed in from RoutineDetailView.
    let routine: Routine

    // ── Owned objects ──────────────────────────────────────────────────────

    // The engine is the single source of truth for all session state.
    // @State makes SwiftUI own it for the lifetime of this screen.
    // nil for the brief instant before .onAppear fires.
    //
    // CGI ANALOGY: The dispatcher object — allocated when the monitor opens,
    // destroyed when it closes.
    @State private var engine: SessionEngine?

    // CoachSettings from the environment — provides voice + rate to the coach.
    // Injected at the app root in YogaLatiesApp.
    //
    // CGI ANALOGY: Reading the project's global PA patch-bay settings —
    // this view doesn't own the settings, it just reads from the shared node.
    @Environment(CoachSettings.self) private var coachSettings

    // The voice coach — created in startSession() so it can be handed the
    // live CoachSettings reference from the environment.
    // nil for the instant before onAppear fires.
    @State private var coach: VoiceCoach?

    // Loaded once; passed to the engine at creation.
    private let library: [Exercise] = ExerciseLibrary.load()


    // ─────────────────────────────────────────────
    // MARK: - Body
    // ─────────────────────────────────────────────

    var body: some View {
        ZStack {
            if let engine {
                if engine.isFinished {
                    // ── Session Summary ────────────────────────────────────
                    // Replace the old placeholder with the real summary screen.
                    // onReplay resets the engine so the user can go again
                    // without leaving this navigation context.
                    SessionSummaryView(
                        routine: routine,
                        library: library,
                        onReplay: replay
                    )
                } else {
                    // ── Background gradient ────────────────────────────────
                    // Subtle category-tinted wash behind all content.
                    // CGI ANALOGY: A colour temperature overlay in the comp
                    // that shifts slightly between shots.
                    backgroundGradient(for: engine.currentExercise?.category)
                        .ignoresSafeArea()

                    // ── Main session layout ────────────────────────────────
                    sessionLayout(engine: engine)

                    // ── Pause overlay ──────────────────────────────────────
                    // Dims the screen and shows a large resume button when
                    // the session is paused.
                    // CGI ANALOGY: The "PAUSED" overlay that the render
                    // manager throws over the dashboard when the farm is held.
                    if !engine.isRunning {
                        pauseOverlay(engine: engine)
                    }
                }
            } else {
                ProgressView("Loading…")
            }
        }
        .navigationTitle(routine.name)
        .navigationBarTitleDisplayMode(.inline)
        // Hide the back button while actively running — tapping it by accident
        // mid-pose would be frustrating. It reappears when paused or finished.
        .navigationBarBackButtonHidden(engine?.isRunning == true)
        // ── Lifecycle ─────────────────────────────────────────────────────
        .onAppear  { startSession() }
        .onDisappear {
            engine?.pause()
            coach?.stop()
        }
        // ── Voice coach wiring ─────────────────────────────────────────────
        // These three .onChange modifiers are the "event listeners" that
        // connect the engine's state machine to the voice coach.
        //
        // CGI ANALOGY: Shotgrid field-change webhooks — "when this field on the
        // shot record changes value, fire this callback."
        //
        // 1) New exercise loaded → announce name + coach cue + haptic thud.
        .onChange(of: engine?.currentIndex) { _, _ in
            guard let engine, let exercise = engine.currentExercise else { return }
            coach?.announceExerciseStart(exercise)
            // Medium impact signals the transition between exercises —
            // like a physical "next pose" cue from the mat.
            Haptics.medium()
        }
        // 2) Timer milestones → breathing reminder, 10-second warning, 5-second warning.
        //
        //    • Breathing reminder  — midpoint of exercises ≥ 45 s.
        //      Queued after the coaching cue (no stop()), so the trainer waits
        //      for the description to finish before gently checking in.
        //    • 10-second warning   — interrupts; fires for any exercise > 15 s.
        //    • 5-second warning    — interrupts; fires for any exercise > 8 s.
        //
        //    All three share one onChange to keep the logic in one place and
        //    avoid three separate subscriptions all watching the same property.
        .onChange(of: engine?.secondsRemaining) { _, newValue in
            guard let engine, let newValue else { return }
            let total    = engine.currentTotalDuration
            let midpoint = total / 2

            if newValue == 5, total > 8 {
                // 5-second countdown — time-sensitive, interrupts.
                coach?.announceCountdownWarning(nextExercise: engine.nextExercise)
            } else if newValue == 10, total > 15 {
                // 10-second countdown — time-sensitive, interrupts.
                coach?.announceTenSecondWarning(nextExercise: engine.nextExercise)
            } else if newValue == midpoint, total >= 45, midpoint > 12 {
                // Breathing reminder at midpoint — queued, does not interrupt.
                // Guard: total ≥ 45 s gives the coaching cue time to finish
                // before the reminder plays; midpoint > 12 keeps it clear of
                // the 10-second warning.
                coach?.announceBreathingReminder()
            }
        }
        // 3) Session finished → congratulate + success haptic.
        .onChange(of: engine?.isFinished) { _, isFinished in
            guard isFinished == true else { return }
            coach?.announceWorkoutComplete(routineName: routine.name)
            // Success notification pattern — the iOS "all done" double-tap.
            Haptics.success()
        }
    }


    // ─────────────────────────────────────────────
    // MARK: - Session layout
    // ─────────────────────────────────────────────

    private func sessionLayout(engine: SessionEngine) -> some View {
        VStack(spacing: 0) {
            Spacer()

            // ── Exercise hero ──────────────────────────────────────────────
            if let exercise = engine.currentExercise {
                exerciseHero(exercise: exercise,
                             index: engine.currentIndex,
                             total: routine.exercises.count)
            }

            Spacer().frame(height: 36)

            // ── Countdown ring ─────────────────────────────────────────────
            countdownRing(engine: engine)

            Spacer().frame(height: 36)

            // ── Transport controls ─────────────────────────────────────────
            transportControls(engine: engine)

            Spacer()

            // ── Next-up card ───────────────────────────────────────────────
            // Only visible when there is a following exercise.
            if let next = engine.nextExercise {
                nextUpCard(exercise: next)
                    .padding(.bottom, 20)
            }
        }
        .padding(.horizontal)
    }


    // ─────────────────────────────────────────────
    // MARK: - Exercise Hero
    // ─────────────────────────────────────────────
    //
    // Large icon + name + category badge + position counter.
    // Uses .id(exercise.id) so SwiftUI replaces the entire block when the
    // exercise changes, triggering the transition animation.
    //
    // CGI ANALOGY: The shot-preview thumbnail that updates each time the
    // dispatcher loads a new shot. .id() is like clearing the preview cache
    // so the new asset renders fresh rather than morphing the old one.

    private func exerciseHero(exercise: Exercise, index: Int, total: Int) -> some View {
        VStack(spacing: 12) {

            ExerciseImageView(exercise: exercise, size: 110)
                .shadow(color: accentColor(for: exercise.category).opacity(0.3),
                        radius: 12, x: 0, y: 6)
                .transition(.opacity.combined(with: .scale(scale: 0.80)))
                .id("icon-\(exercise.id)")

            Text(exercise.name)
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .id("name-\(exercise.id)")

            HStack(spacing: 12) {
                categoryBadge(for: exercise.category)

                Text("\(index + 1) of \(total)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: exercise.id)
    }


    // ─────────────────────────────────────────────
    // MARK: - Countdown Ring
    // ─────────────────────────────────────────────
    //
    // A circular arc that drains from full (1.0) to empty (0.0) as the
    // exercise time runs out, with the seconds count in the centre.
    //
    // How Circle().trim works:
    //   trim(from: 0, to: 1.0) → full ring
    //   trim(from: 0, to: 0.5) → half ring
    //   trim(from: 0, to: 0.0) → invisible
    //   .rotationEffect(.degrees(-90)) → arc starts at the top (12 o'clock)
    //   rather than the right (3 o'clock), which is the natural start point.
    //
    // CGI ANALOGY: A depleting render-budget progress arc — like the circular
    // progress bars in many DCC render managers that drain as frames complete.

    private func countdownRing(engine: SessionEngine) -> some View {
        let fraction = engine.currentTotalDuration > 0
            ? Double(engine.secondsRemaining) / Double(engine.currentTotalDuration)
            : 0.0

        let color = accentColor(for: engine.currentExercise?.category)

        return ZStack {

            // Background track — always a full circle, very faint.
            Circle()
                .stroke(color.opacity(0.12), lineWidth: 14)
                .frame(width: 168, height: 168)

            // Draining arc — shrinks as secondsRemaining decreases.
            // .animation(.linear(duration: 1)) makes the arc shrink smoothly
            // over exactly 1 second per tick, matching the timer perfectly.
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: 168, height: 168)
                .animation(.linear(duration: 1), value: engine.secondsRemaining)

            // Centre label — seconds remaining.
            VStack(spacing: 2) {
                Text("\(engine.secondsRemaining)")
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    // Rolling-digit animation that counts downward.
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.linear(duration: 0.25), value: engine.secondsRemaining)
                    .foregroundStyle(color)

                Text("seconds")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }


    // ─────────────────────────────────────────────
    // MARK: - Transport Controls
    // ─────────────────────────────────────────────
    //
    // ◀◀  (skip back)   ⏸/▶ (pause/resume)   ▶▶ (skip forward)
    //
    // CGI ANALOGY: The VCR-style transport buttons on the render monitor —
    // requeue previous shot | pause/resume the farm | skip to next shot.

    private func transportControls(engine: SessionEngine) -> some View {
        HStack(spacing: 44) {

            // ◀◀ Skip back — disabled on the first exercise.
            Button {
                Haptics.light()
                engine.skipBack()
                // Re-announce after skip so the user knows what they landed on.
                if let ex = engine.currentExercise { coach?.announceExerciseStart(ex) }
            } label: {
                Image(systemName: "backward.end.fill")
                    .font(.title)
            }
            .foregroundStyle(engine.currentIndex == 0 ? .tertiary : .primary)
            .disabled(engine.currentIndex == 0)

            // ⏸/▶ Play / Pause — the hero button.
            Button {
                Haptics.light()
                if engine.isRunning {
                    engine.pause()
                    coach?.stop()
                } else {
                    engine.resume()
                    // Re-announce current exercise on resume so the user is
                    // re-oriented if they were away for a while.
                    if let ex = engine.currentExercise { coach?.announceExerciseStart(ex) }
                }
            } label: {
                Image(systemName: engine.isRunning ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(accentColor(for: engine.currentExercise?.category))
                    .symbolEffect(.bounce, value: engine.isRunning)
            }

            // ▶▶ Skip forward.
            Button {
                Haptics.light()
                engine.skipForward()
                if let ex = engine.currentExercise { coach?.announceExerciseStart(ex) }
            } label: {
                Image(systemName: "forward.end.fill")
                    .font(.title)
                    .foregroundStyle(.primary)
            }
        }
    }


    // ─────────────────────────────────────────────
    // MARK: - Pause Overlay
    // ─────────────────────────────────────────────
    //
    // Dims the screen with a translucent layer and centres a large resume
    // button. This makes "paused" state visually obvious and provides a big
    // easy tap target to get back into the session.
    //
    // CGI ANALOGY: The "FARM PAUSED" banner the render manager throws over
    // the dashboard — unmistakeable, but easy to dismiss.

    private func pauseOverlay(engine: SessionEngine) -> some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("Paused")
                    .font(.title)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)

                Button {
                    Haptics.light()
                    engine.resume()
                    if let ex = engine.currentExercise { coach?.announceExerciseStart(ex) }
                } label: {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 90))
                        .foregroundStyle(.white)
                        .shadow(radius: 20)
                }
            }
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.25), value: engine.isRunning)
    }


    // ─────────────────────────────────────────────
    // MARK: - Next-Up Card
    // ─────────────────────────────────────────────
    //
    // A compact card at the bottom of the screen that previews the upcoming
    // exercise so the user can mentally prepare before the transition.
    //
    // CGI ANALOGY: The "Next in Queue" row in the render dispatch panel —
    // shows which shot will be loaded once the current one finishes.

    private func nextUpCard(exercise: Exercise) -> some View {
        HStack(spacing: 12) {

            ExerciseImageView(exercise: exercise, size: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text("Next up")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(exercise.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            Spacer()

            categoryBadge(for: exercise.category)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .transition(.opacity.combined(with: .move(edge: .bottom)))
        .animation(.easeInOut(duration: 0.4), value: exercise.id)
        .id("nextup-\(exercise.id)")
    }


    // ─────────────────────────────────────────────
    // MARK: - Helpers
    // ─────────────────────────────────────────────

    /// Tears down the current session and starts a fresh one from the top.
    /// Called by SessionSummaryView's "Go Again" button.
    ///
    /// CGI ANALOGY: Clicking "Resubmit to Farm" — cancels the completed job,
    /// clears the render monitor state, and dispatches the same shot list again.
    private func replay() {
        engine?.pause()
        coach?.stop()
        engine = nil
        coach  = nil
        startSession()
    }

    private func startSession() {
        guard engine == nil else { return }

        // Create the coach first, wired to the live settings object.
        // From this point on, any change the user makes in SettingsView is
        // picked up automatically on the next speak() call.
        let c = VoiceCoach(settings: coachSettings)
        coach = c

        let e = SessionEngine(routine: routine, library: library)
        engine = e
        e.start()

        // Manually announce the first exercise — onChange(of: currentIndex)
        // won't fire for index 0 since the engine starts there and never
        // *changes* to 0.
        if let firstExercise = e.currentExercise {
            c.announceExerciseStart(firstExercise)
        }
    }

    /// Returns the accent colour for a given exercise category, defaulting to
    /// indigo if the category is unknown (e.g. engine not yet started).
    private func accentColor(for category: Exercise.Category?) -> Color {
        switch category {
        case .yoga:    return .indigo
        case .pilates: return .teal
        case nil:      return .indigo
        }
    }

    /// Subtle full-screen gradient tinted by category — changes smoothly as
    /// exercises advance.
    private func backgroundGradient(for category: Exercise.Category?) -> LinearGradient {
        let color = accentColor(for: category)
        return LinearGradient(
            colors: [color.opacity(0.18), color.opacity(0.04), .clear],
            startPoint: .top,
            endPoint: .center
        )
    }

    /// Coloured pill badge matching the style used in RoutineDetailView.
    private func categoryBadge(for category: Exercise.Category) -> some View {
        Text(category.rawValue)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(accentColor(for: category).opacity(0.15))
            .foregroundStyle(accentColor(for: category))
            .clipShape(Capsule())
    }
}


// ─────────────────────────────────────────────
// MARK: - Preview
// ─────────────────────────────────────────────

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Routine.self, RoutineExercise.self,
        configurations: config
    )
    let ctx = container.mainContext
    let library = ExerciseLibrary.load()

    let routine = Routine(name: "Morning Flow")
    ctx.insert(routine)
    for (i, ex) in library.prefix(5).enumerated() {
        let re = RoutineExercise(exerciseID: ex.id, sortIndex: i)
        re.routine = routine
        routine.exercises.append(re)
        ctx.insert(re)
    }

    return NavigationStack {
        ActiveSessionView(routine: routine)
    }
    .modelContainer(container)
}
