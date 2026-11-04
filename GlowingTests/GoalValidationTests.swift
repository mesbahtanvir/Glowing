import Testing
import Foundation
@testable import Glowing

/// Everything `StyleGoal` does to the text a person types before it is sent to the AI service.
@MainActor
@Suite("Goal validation")
struct GoalValidationTests {

    // MARK: Nothing to send

    @Test func inputWithNothingVisibleIsNotAGoal() {
        let blanks: [String] = [
            "",
            " ",
            "\t\n\r",
            "\u{00A0}",                // no-break space
            "\u{2003}",                // em space
            "\u{3000}",                // ideographic space
            "\u{2028}\u{2029}",        // line and paragraph separators
            "\u{0085}",                // next line
            "\u{0007}\u{0008}",        // control characters
            "\u{E0041}\u{E0042}",      // invisible tag characters
            " \u{0007}\u{E0041}\t ",   // a mix of the above
            "\u{200B}",                // zero-width space
            "\u{200D}",                // zero-width joiner on its own
            "\u{200C}\u{200D}",        // both joiners
            "\u{FEFF}",                // byte order mark
            "\u{2060}",                // word joiner
            "\u{00AD}",                // soft hyphen
            " \u{200B} \u{200D} ",     // invisible characters and spaces
        ]
        for raw in blanks {
            #expect(StyleGoal(raw) == nil, "\(scalars(raw)) should not count as a goal")
        }
    }

    // MARK: Separators

    @Test func everyKindOfSeparatorBecomesOneSpace() {
        let cases: [(raw: String, expected: String)] = [
            ("  Job interview  ", "Job interview"),
            ("Job    interview", "Job interview"),
            ("Job\u{00A0}\u{00A0}interview", "Job interview"),
            ("Job\u{2003}interview", "Job interview"),
            ("Job\u{3000}interview", "Job interview"),
            ("Job\ninterview", "Job interview"),
            ("Job\r\ninterview", "Job interview"),
            ("Job\n\n\ninterview", "Job interview"),
            ("Job\tinterview", "Job interview"),
            ("Job\u{2028}interview", "Job interview"),
            ("Job\u{2029}interview", "Job interview"),
            ("Job\u{0085}interview", "Job interview"),
            ("Job\u{0007}interview", "Job interview"),
            ("Job \u{0007} \t interview", "Job interview"),
            ("\n\nJob interview\n\n", "Job interview"),
        ]
        for (raw, expected) in cases {
            #expect(StyleGoal(raw)?.text == expected, "\(scalars(raw)) should become \"\(expected)\"")
        }
    }

    // MARK: Characters that must survive

    @Test func textThatNeedsJoinersAndMarksIsLeftAlone() {
        let family = "\u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467}"                         // three emoji joined by U+200D
        let persian = "\u{0645}\u{06CC}\u{200C}\u{062E}\u{0648}\u{0627}\u{0647}\u{0645}"    // spelled with U+200C
        let samples: [String] = [
            family,
            "Family \(family) brunch",
            persian,
            "\u{1F1E8}\u{1F1E6}",                // a flag: two regional indicators
            "\u{1F44D}\u{1F3FD}",                // thumbs up with a skin-tone modifier
            "1\u{FE0F}\u{20E3}",                 // keycap
            "\u{2764}\u{FE0F}",                  // heart with the emoji presentation selector
            "cafe\u{0301}",                      // e + combining acute accent
            "co\u{00AD}operate",                 // soft hyphen between letters
            "abc\u{200F}",                       // right-to-left mark after text
            "Date night \u{1F457}",              // plain emoji
            "Za\u{017C}\u{00F3}\u{0142}\u{0107} g\u{0119}\u{015B}l\u{0105}",   // accented Latin
            "\u{65E5}\u{672C}\u{8A9E}\u{306E}\u{76EE}\u{6A19}",                // Japanese
        ]
        for sample in samples {
            #expect(StyleGoal(sample)?.text == sample, "\(scalars(sample)) should be kept as it is")
        }
    }

    // MARK: Invisible tag characters

    @Test func invisibleTagCharactersAreRemovedWithoutLeavingASpace() {
        let cases: [(raw: String, expected: String)] = [
            ("Date\u{E0041}\u{E0042} night", "Date night"),
            ("a\u{E0000}b", "ab"),                 // first code point of the tag block
            ("a\u{E0001}b", "ab"),                 // the language tag
            ("a\u{E007F}b", "ab"),                 // last code point of the block (cancel tag)
            ("Da\u{E0074}\u{E0065}te", "Date"),    // tag letters spelling out hidden text
        ]
        for (raw, expected) in cases {
            #expect(StyleGoal(raw)?.text == expected, "\(scalars(raw)) should become \"\(expected)\"")
        }
    }

    @Test func theFirstCodePointAfterTheTagBlockIsKept() {
        let raw = "a\u{E0080}b"
        #expect(StyleGoal(raw)?.text == raw)
    }

    // MARK: Length

    @Test func theLimitIsTheDocumentedOne() {
        // The backend contract says a goal is at most 160 characters. Change both together.
        #expect(StyleGoal.maxLength == 160)
    }

    @Test func aGoalAtTheLimitIsKeptAndAnythingOverIsCut() {
        let atLimit = String(repeating: "a", count: StyleGoal.maxLength)
        #expect(StyleGoal(atLimit)?.text == atLimit)
        #expect(StyleGoal(atLimit + "a")?.text == atLimit)
        #expect(StyleGoal(atLimit + "bcdef")?.text == atLimit)
    }

    @Test func cuttingNeverLeavesATrailingSpace() {
        // The 160th character would be a space, so the cut text must be trimmed back.
        let raw = String(repeating: "a", count: StyleGoal.maxLength - 1) + " bbb"
        #expect(StyleGoal(raw)?.text == String(repeating: "a", count: StyleGoal.maxLength - 1))
    }

    @Test func lengthIsCountedInCharactersNotScalarsOrBytes() {
        let units: [String] = [
            "\u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467}",   // family: five scalars, one character
            "e\u{0301}",                                     // letter plus accent: two scalars, one character
            "\u{1F1E8}\u{1F1E6}",                            // flag: two scalars, one character
            "\u{1F457}",                                     // plain emoji: four bytes, one character
        ]
        for unit in units {
            let raw = String(repeating: unit, count: StyleGoal.maxLength * 2)
            let text = StyleGoal(raw)?.text ?? ""
            let expected = String(repeating: unit, count: StyleGoal.maxLength)
            #expect(text == expected, "\(scalars(unit)) repeated should be cut on a character boundary")
        }
    }

    // MARK: Stability

    @Test func cleaningTwiceGivesTheSameResultAsCleaningOnce() {
        let samples: [String] = [
            "  Job \n\n  interview\t ",
            "Date\u{0007} night",
            "Date\u{E0041} night",
            "\u{200D}  \u{200B}",
            String(repeating: "a ", count: 300),
            String(repeating: "\u{1F468}\u{200D}\u{1F469}", count: 200),
            "cafe\u{0301}   au   lait",
            "",
        ]
        for sample in samples {
            let once = StyleGoal.sanitize(sample)
            #expect(StyleGoal.sanitize(once) == once, "\(scalars(String(sample.prefix(12)))) should clean to a fixed point")
        }
    }

    @Test func goalsThatCleanToTheSameTextAreEqual() {
        #expect(StyleGoal("Job  interview") == StyleGoal(" Job\ninterview "))
        #expect(StyleGoal("Job interview") != StyleGoal("Date night"))
    }

    // MARK: Suggestions

    @Test func everySuggestionFitsTheLimit() {
        for suggestion in StyleGoal.suggestions {
            #expect(suggestion.count <= StyleGoal.maxLength, "\"\(suggestion)\" is longer than a goal may be")
        }
    }
}
