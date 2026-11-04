import Foundation

/// What the user wants from a look: "job interview", "date night", "quiet luxury", and so on.
///
/// The goal is free text that is sent to the AI service, so it is normalised once, here: whitespace
/// and line breaks collapse to single spaces, control characters are dropped, and the length is capped.
struct StyleGoal: Equatable, Sendable {

    /// Longest goal we accept. Long enough for a sentence, short enough to keep requests small.
    static let maxLength = 160

    /// Tap-to-fill ideas shown under the goal field. Each one must be a valid goal on its own.
    static let suggestions: [String] = [
        "Job interview",
        "Polished for work",
        "Date night",
        "Smart casual",
        "Relaxed weekend",
        "Streetwear",
        "Clean and minimal",
        "Wedding guest",
    ]

    /// The normalised goal text. Never empty.
    let text: String

    /// Returns nil when there is nothing meaningful to send (empty or whitespace-only input).
    init?(_ raw: String) {
        let cleaned = StyleGoal.sanitize(raw)
        guard !cleaned.isEmpty else { return nil }
        self.text = cleaned
    }

    static func sanitize(_ raw: String) -> String {
        var result = ""
        var lastWasSpace = true // starts true so leading whitespace is dropped

        for scalar in raw.unicodeScalars {
            let isSeparator = CharacterSet.whitespacesAndNewlines.contains(scalar)
                || CharacterSet.controlCharacters.contains(scalar)
            if isSeparator {
                if !lastWasSpace {
                    result.append(" ")
                    lastWasSpace = true
                }
            } else {
                result.unicodeScalars.append(scalar)
                lastWasSpace = false
            }
        }

        if result.hasSuffix(" ") {
            result.removeLast()
        }

        if result.count > maxLength {
            // Cut by Character so an emoji or accented letter is never split in half.
            result = String(result.prefix(maxLength)).trimmingCharacters(in: .whitespaces)
        }
        return result
    }
}
