//
//  SessionEngine.swift
//  YogaLaties
//
//  Step 13 — Session Timer Engine
//
//  A pure state-machine class that drives a workout session. It knows nothing
//  about the UI — it just tracks time, advances through exercises, and exposes
//  state for any view to observe.
//
//  CGI ANALOGY: This is the **Render Farm Dispatcher**.
//  - The Routine is the shot list submitted to the farm.
//  - Each RoutineExercise is one shot in that list, with its own frame budget.
//  - The engine is the dispatcher: it picks up the first shot, counts down its
//    frame budget one frame per second, marks it done when the budget runs out,
//    then automatically loads the next shot. You can pause the dispatcher,
//    resume it, skip a shot forward or re-queue the previous one.
//  - The SwiftUI views are the Render Manager GUI — they read the dispatcher's
//    status board (@Observable properties) but never touch the timer directly.
//
//  Key iOS 17 concept: @Observable
//  ─────────────────────────────────
//  `@Observable` is a Swift macro (introduced in iOS 17 / Swift 5.9) that
//  automatically makes a class's properties trackable by SwiftUI. Any view
//  that reads one of these properties inside its `body` will re-render when
//  that property changes — without you having to write any extra code.
//
//  CGI ANALOGY: Imagine every property has an invisible Shotgrid webhook
//  attached to it. When the value changes, the webhook fires and tells every
//  subscribed dashboard widget (SwiftUI view) to redraw.
//
//  Why @Observable instead of ObservableObject / @Published?
//  `@Observable` is the modern replacement (iOS 17+). It's simpler: no
//  `@Published` needed on every property, and `@State` / `@Bindable` in views
//  replace `@ObservedObject` / `@StateObject`. We use it here because the
//  project targets iOS 17+.
//
//  Key concept: Combine Timer
//  ──────────────────────────
//  `Timer.publish(every:on:in:)` is a Combine publisher — think of it as a
//  metronome that emits a tick every N seconds on a chosen thread.
//  `.autoconnect()` starts the metronome as soon as the first subscriber
//  attaches. `.sink { }` is that subscriber — the closure runs on every tick.
//  We store the result in an `AnyCancellable`; cancelling it stops the timer.
//
//  CGI ANALOGY: A render-farm heartbeat signal. Every second the farm sends a
//  "frame rendered" ping. The dispatcher's `.sink` receives each ping and
//  decrements the remaining frame budget for the current shot.
//

import Foundation
import Combine     // for Timer.publish, AnyCancellable


// ─────────────────────────────────────────────
// MARK: - SessionEngine
// ─────────────────────────────────────────────

@Observable
final class SessionEngine {

    // ── Read-only state exposed to views ───────────────────────────────────

    /// Index into `slots` — which shot the farm is currently rendering.
    /// CGI ANALOGY: The "current shot" highlighted in the dispatch queue.
    private(set) var currentIndex: Int = 0

    /// The resolved Exercise for `slots[currentIndex]`, or nil once finished.
    /// CGI ANALOGY: The asset currently loaded on the render node.
    private(set) var currentExercise: Exercise?

    /// Seconds left on the current exercise's frame budget.
    /// CGI ANALOGY: Remaining frame count for the active shot.
    private(set) var secondsRemaining: Int = 0

    /// True while the countdown timer is actively ticking.
    /// CGI ANALOGY: The farm dispatcher status — "RENDERING" vs "PAUSED".
    private(set) var isRunning: Bool = false

    /// True after the last exercise completes.
    /// CGI ANALOGY: All shots rendered; the sequence is done.
    private(set) var isFinished: Bool = false

    /// The full frame budget for the *current* exercise — never changes once
    /// the shot is loaded, so the view can compute arc progress as
    /// `Double(secondsRemaining) / Double(currentTotalDuration)`.
    ///
    /// CGI ANALOGY: The total frame count assigned to the current shot.
    /// The remaining-frames counter counts down; this is the denominator
    /// that lets the progress bar know how full to draw itself.
    private(set) var currentTotalDuration: Int = 0

    /// The resolved Exercise immediately *after* the current one, or nil if
    /// the current exercise is the last in the session.
    ///
    /// CGI ANALOGY: The "Next Shot" preview in the dispatch queue — the one
    /// that will be loaded as soon as the current shot finishes.
    var nextExercise: Exercise? {
        let nextIndex = currentIndex + 1
        guard nextIndex < slots.count else { return nil }
        return slots[nextIndex].resolvedExercise(in: library)
    }


    // ── Private internals ──────────────────────────────────────────────────

    /// The ordered exercise slots for this session, sorted by sortIndex.
    /// Immutable after init — the shot list doesn't change mid-render.
    private let slots: [RoutineExercise]

    /// The exercise library used to resolve exerciseID → Exercise.
    private let library: [Exercise]

    /// Holds the active Combine subscription to the 1-second timer.
    /// Setting this to nil (or calling cancel()) stops the timer — like
    /// pulling the plug on the render farm heartbeat.
    ///
    /// CGI ANALOGY: The handle to the active render job. Cancelling it
    /// tells the farm to stop dispatching frames for the current shot.
    private var timerCancellable: AnyCancellable?


    // ── Init ───────────────────────────────────────────────────────────────

    /// Creates a new engine from a `Routine` and the full exercise library.
    ///
    /// - Parameters:
    ///   - routine: The saved routine whose shots this session will run through.
    ///   - library: The full `[Exercise]` array from `ExerciseLibrary.load()`.
    ///
    /// CGI ANALOGY: Submitting a shot list to the dispatcher. The dispatcher
    /// reads the list, sorts it into cut order, and cues up the first shot —
    /// but doesn't start rendering until you call `start()`.
    init(routine: Routine, library: [Exercise]) {
        self.library = library

        // Sort the routine's exercise slots into cut order.
        // CGI ANALOGY: Sorting the submitted shot list by cut-order index
        // before feeding it into the render queue.
        self.slots = routine.exercises.sorted { $0.sortIndex < $1.sortIndex }

        // Cue up the first shot without starting the timer.
        if let first = slots.first {
            currentExercise      = first.resolvedExercise(in: library)
            secondsRemaining     = first.effectiveDuration(in: library)
            currentTotalDuration = first.effectiveDuration(in: library)
        }
    }


    // ─────────────────────────────────────────────
    // MARK: - Public Controls
    // ─────────────────────────────────────────────

    /// Starts the countdown from the beginning of the first exercise.
    /// Safe to call only once; ignored if already running or finished.
    ///
    /// CGI ANALOGY: Clicking "Start Render" in the farm dispatcher.
    func start() {
        guard !isRunning, !isFinished, !slots.isEmpty else { return }
        isRunning = true
        armTimer()
    }

    /// Pauses the countdown mid-exercise.
    /// CGI ANALOGY: Clicking "Pause" on the active render job —
    /// the frame counter freezes; progress is preserved.
    func pause() {
        guard isRunning else { return }
        isRunning = false
        cancelTimer()
    }

    /// Resumes a paused countdown from where it was stopped.
    /// CGI ANALOGY: Clicking "Resume" — the dispatcher picks up exactly
    /// where it left off, same shot, same remaining frame budget.
    func resume() {
        guard !isRunning, !isFinished else { return }
        isRunning = true
        armTimer()
    }

    /// Immediately skips to the next exercise (or ends the session if on the last).
    /// CGI ANALOGY: Clicking "Skip Shot" in the queue — the current shot is
    /// marked done without waiting for its full frame budget to expire, and
    /// the next shot is loaded.
    func skipForward() {
        advance()
    }

    /// Goes back to the beginning of the previous exercise (or restarts the
    /// current one if already on the first).
    /// CGI ANALOGY: Clicking "Requeue Previous Shot" — the dispatcher re-cues
    /// the shot that came before the current one and resets its frame budget.
    func skipBack() {
        let target = max(0, currentIndex - 1)
        load(index: target)
    }


    // ─────────────────────────────────────────────
    // MARK: - Timer Internals
    // ─────────────────────────────────────────────

    /// Creates and starts the 1-second Combine timer.
    ///
    /// CGI ANALOGY: Connecting the render farm heartbeat signal.
    /// `.publish(every: 1)` = the farm emits a "frame done" ping every second.
    /// `.autoconnect()` = the signal starts as soon as we subscribe.
    /// `.sink { }` = our dispatcher callback that runs on each ping.
    private func armTimer() {
        timerCancellable = Timer
            .publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                // `[weak self]` prevents a retain cycle — the closure holds a
                // weak pointer to the engine, so the engine can be deallocated
                // if the session screen is dismissed.
                //
                // CGI ANALOGY: The heartbeat callback holds only a weak
                // reference to the dispatcher, so it doesn't accidentally keep
                // the dispatcher alive after the render manager is closed.
                self?.tick()
            }
    }

    /// Cancels the active timer subscription.
    /// Setting `timerCancellable = nil` calls `cancel()` automatically because
    /// `AnyCancellable` cancels itself when it's deallocated.
    ///
    /// CGI ANALOGY: Disconnecting the heartbeat signal — no more pings arrive.
    private func cancelTimer() {
        timerCancellable = nil
    }

    /// Called once per second while the timer is running.
    ///
    /// Two cases:
    /// 1. `secondsRemaining > 0` → decrement by one (the frame budget ticks down).
    /// 2. `secondsRemaining == 0` → the budget is exhausted; auto-advance.
    ///
    /// CGI ANALOGY: The per-frame callback in the dispatcher.
    ///   • Each call marks one frame rendered.
    ///   • When the remaining frame count hits zero, the shot is complete and
    ///     the dispatcher automatically loads the next one.
    private func tick() {
        if secondsRemaining > 0 {
            secondsRemaining -= 1
        } else {
            // Budget exhausted — move to the next shot.
            advance()
        }
    }

    /// Moves the engine to the next exercise slot.
    /// If the current slot is the last one, marks the session finished.
    ///
    /// CGI ANALOGY: The dispatcher's "shot complete" handler — stamps the
    /// current shot DONE, then either loads the next shot or marks the
    /// entire sequence COMPLETE if this was the last shot.
    private func advance() {
        let next = currentIndex + 1
        if next < slots.count {
            load(index: next)
        } else {
            // All shots rendered — session complete.
            isFinished = true
            isRunning  = false
            cancelTimer()
            currentExercise  = nil
            secondsRemaining = 0
        }
    }

    /// Loads a specific slot index — updates all published state in one place.
    /// Keeps the timer running or stopped based on `isRunning`.
    ///
    /// CGI ANALOGY: The dispatcher loading a shot onto a render node —
    /// it stamps the node with the new shot's metadata (frame budget,
    /// asset reference) without changing whether the farm is running or paused.
    private func load(index: Int) {
        guard index < slots.count else { return }
        let slot = slots[index]

        currentIndex         = index
        currentExercise      = slot.resolvedExercise(in: library)
        secondsRemaining     = slot.effectiveDuration(in: library)
        currentTotalDuration = slot.effectiveDuration(in: library)

        // If we changed index during a running session we need to restart the
        // timer so we get a fresh 1-second interval (avoids the partial-second
        // artefact where the new shot's first tick fires almost immediately).
        //
        // CGI ANALOGY: When you skip to a new shot, the heartbeat clock is
        // reset so the first "frame rendered" ping fires a full second later —
        // not mid-frame.
        if isRunning {
            cancelTimer()
            armTimer()
        }
    }
}
