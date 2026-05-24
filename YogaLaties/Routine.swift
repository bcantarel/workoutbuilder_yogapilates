import Foundation
import SwiftData

// CGI ANALOGY: A Routine is like a **Shot Sequence** in your production database.
// It's a named container that holds an ordered list of assets (exercises) to
// be rendered one after another. The sequence itself doesn't contain the raw
// geometry — it references individual Shot assets (RoutineExercises) by ID.
//
// `@Model` is the SwiftData magic macro. It tells the framework:
//   "Register this class as a persistent asset type in the database."
// Under the hood it generates the schema, relationships, and change-tracking
// automatically — exactly like Shotgrid auto-generating entity tables for
// custom asset types you define.

@Model
final class Routine {

    // `@Attribute(.unique)` ensures no two Routines share the same UUID —
    // like a unique primary key constraint in Shotgrid or a UUID node ID in Houdini.
    @Attribute(.unique) var id: UUID

    // The human-readable name the user gives their routine, e.g. "Morning Flow".
    var name: String

    // When the routine was first created — useful for sorting by newest first.
    // Like the `sg_created_at` field on every Shotgrid entity.
    var createdAt: Date

    // The ordered list of exercises in this routine.
    //
    // CGI ANALOGY: This is the **shot list** for the sequence — an ordered
    // array of Shot references. Each RoutineExercise knows which exercise it
    // points to and can carry per-shot overrides (like a per-shot frame range).
    //
    // SwiftData relationship rules at work here:
    // • `@Relationship(deleteRule: .cascade)` means: if you delete a Routine,
    //   all its RoutineExercise children are deleted automatically — like
    //   deleting a sequence in Shotgrid and having it cascade-delete all linked shots.
    // • `inverse: \RoutineExercise.routine` tells SwiftData how the two
    //   models point back to each other, so it can keep the graph consistent.
    @Relationship(deleteRule: .cascade, inverse: \RoutineExercise.routine)
    var exercises: [RoutineExercise]

    // A computed property — derived on the fly, never stored.
    // CGI ANALOGY: Like a Houdini expression that reads frameCount from the
    // shot list rather than being baked into the asset itself.
    var exerciseCount: Int { exercises.count }

    // Designated initialiser.
    // Swift requires you to initialise every stored property before use —
    // similar to PHP's __construct() or Python's __init__().
    init(name: String) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
        self.exercises = []
    }
}
