import Foundation

/// What the user wants from a look: "job interview", "date night", "quiet luxury", and so on.
///
/// The goal is free text that is sent to the AI service, so it is normalised once, here: whitespace,
/// line breaks and control characters collapse to single spaces, invisible "tag" characters are removed,
/// and the length is capped. Joiners are left alone: emoji sequences (a family, a flag) and some scripts
/// (Persian, for one) depend on the zero-width joiner and non-joiner.
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

    /// Invisible characters that can carry text no one can see. They have no place in a goal.
    private static let tagCharacters: ClosedRange<UInt32> = 0xE0000...0xE007F

    static func sanitize(_ raw: String) -> String {
        var result = ""
        var lastWasSpace = true // starts true so leading whitespace is dropped

        for scalar in raw.unicodeScalars {
            if tagCharacters.contains(scalar.value) { continue }

            // Not `CharacterSet.controlCharacters`: that also covers format characters (category Cf),
            // which would turn the joiners in emoji sequences and some scripts into spaces.
            let isSeparator = CharacterSet.whitespacesAndNewlines.contains(scalar)
                || scalar.properties.generalCategory == .control
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
