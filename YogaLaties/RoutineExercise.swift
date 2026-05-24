import Foundation
import SwiftData

// CGI ANALOGY: A RoutineExercise is an individual **Shot** inside a Sequence.
// It doesn't store the full asset (geometry, textures) — it stores a *reference*
// to the asset by ID, plus any per-shot overrides (like a custom frame range
// that differs from the master asset's default).
//
// Why not store a direct SwiftData relationship to Exercise?
// Because Exercise is a plain Swift struct loaded from a JSON bundle file —
// it lives outside SwiftData's managed world entirely. Storing its UUID is
// the right pattern: it's like storing a Shotgrid asset code string ("PROP_0042")
// rather than embedding the whole FBX inline in the shot record.

@Model
final class RoutineExercise {

    // The UUID of the Exercise this slot refers to.
    // At runtime we look this up against ExerciseLibrary.shared.exercises.
    //
    // CGI ANALOGY: The asset's production code. "Go find PROP_0042 in the
    // asset library and load it." The shot record stays lean; the geometry
    // lives in its own managed asset file.
    var exerciseID: UUID

    // An optional per-slot duration override, in seconds.
    // If nil → use the Exercise's own `durationSeconds` (the master default).
    // If set → use this value instead, e.g. the user wants 45 s for Mountain Pose
    //          in this specific routine even though the library default is 30 s.
    //
    // CGI ANALOGY: A per-shot frame-range override. The master asset says
    // "render for 48 frames", but this shot says "hold for 72 frames instead".
    // The override lives on the shot, not on the shared asset.
    var durationOverride: Int?

    // The position of this exercise within its parent routine's ordered list.
    // We store this explicitly so SwiftData can sort the array predictably.
    // CGI ANALOGY: The shot's cut-order index in the sequence.
    var sortIndex: Int

    // Back-reference to the parent Routine.
    // `@Relationship` with no delete rule here because we want the Routine
    // (parent) to own the cascade — the parent declared deleteRule: .cascade
    // on its side. We just need the pointer home.
    //
    // CGI ANALOGY: Every Shot knows which Sequence it belongs to — this is
    // the "parent sequence" field on the shot record.
    var routine: Routine?

    // Convenience: resolve this slot to a live Exercise from the shared library.
    // Returns nil if the library was somehow updated and the exercise removed.
    //
    // CGI ANALOGY: Calling this is like asking the asset server to resolve
    // PROP_0042 into a loaded mesh — it can return nil if the asset was
    // retired from the library.
    func resolvedExercise(in library: [Exercise]) -> Exercise? {
        library.first { $0.id == exerciseID }
    }

    // The effective duration to use when the coach timer runs.
    // Reads the override if set, otherwise falls back to the library default.
    func effectiveDuration(in library: [Exercise]) -> Int {
        if let override = durationOverride { return override }
        return resolvedExercise(in: library)?.durationSeconds ?? 30
    }

    init(exerciseID: UUID, sortIndex: Int, durationOverride: Int? = nil) {
        self.exerciseID = exerciseID
        self.sortIndex = sortIndex
        self.durationOverride = durationOverride
    }
}
