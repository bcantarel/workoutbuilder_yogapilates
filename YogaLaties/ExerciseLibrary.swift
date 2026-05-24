import Foundation

// `enum` with no cases is a Swift idiom for a "namespace" — it can never be instantiated,
// just like a PHP abstract class with only static methods, or a Python module of functions.
enum ExerciseLibrary {

    // Bundle.main is the app's own package — think of it like __DIR__ in PHP or
    // importlib.resources in Python. It's where Xcode copies bundled files at build time.
    static func load() -> [Exercise] {
        guard let url = Bundle.main.url(forResource: "exercises", withExtension: "json") else {
            // `fatalError` crashes with a message — only appropriate for a programmer error
            // (missing bundled file), not a user-facing error. Same role as Python's `assert`
            // or PHP's `throw new LogicException`.
            fatalError("exercises.json not found in app bundle — make sure it is added to the target.")
        }

        do {
            let data = try Data(contentsOf: url)         // read raw bytes — like file_get_contents() or open().read()
            let decoder = JSONDecoder()                   // Swift's built-in JSON parser
            return try decoder.decode([Exercise].self, from: data)  // decode into [Exercise] array
        } catch {
            fatalError("Failed to decode exercises.json: \(error)")
        }
    }
}
