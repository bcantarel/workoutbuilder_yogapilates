import Foundation

// Like a Python dataclass or PHP value object — a plain data container.
// `Identifiable` means every Exercise has a unique id SwiftUI can track (like a DB primary key).
// `Codable` = automatic JSON encode/decode (like Python's dataclasses-json or PHP's json_decode into typed objects).
// `Hashable` means Swift can put Exercises in Sets or use them as Dictionary keys.
struct Exercise: Identifiable, Codable, Hashable {

    // UUID() generates a random ID — equivalent to Python's uuid.uuid4() or PHP's Ramsey\Uuid.
    // `let` = constant (like PHP's readonly or Python's frozen dataclass field).
    let id: UUID
    let name: String
    let category: Category
    let durationSeconds: Int
    let imageName: String
    let coachCue: String  // spoken aloud by AVSpeechSynthesizer

    // Nested enum — think of it like a PHP-style backed enum or Python's Enum class.
    // `String` raw value means each case encodes as its label in JSON ("Yoga", "Pilates").
    // `CaseIterable` lets you do `Category.allCases` — like Python's list(MyEnum).
    enum Category: String, Codable, CaseIterable {
        case yoga = "Yoga"
        case pilates = "Pilates"
    }

    // `static` is the same concept as in PHP/Python — belongs to the type, not an instance.
    // SwiftUI Previews need sample data the way Django's fixtures or PHP seeders do for dev.
    static let sampleExercise = Exercise(
        id: UUID(),
        name: "Mountain Pose",
        category: .yoga,
        durationSeconds: 30,
        imageName: "mountain_pose",
        coachCue: "Stand tall, feet together, arms at your sides, and breathe steadily."
    )
}
