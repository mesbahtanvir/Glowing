import Testing
import Foundation
import UIKit
@testable import Glowing

/// Wraps text in JSON quotes. The text must not itself contain quotes or backslashes.
private func quoted(_ text: String) -> String {
    "\"\(text)\""
}

/// Everything `OutfitAdvice.parse` does with what the AI service sends back.
@MainActor
@Suite("Response validation")
struct ResponseValidationTests {

    // MARK: Is there an outfit at all?

    @Test func theVisibilityFlagIsReadForgivingly() {
        // Anything that doesn't clearly say "false" means there is an outfit to advise on.
        let meansVisible = ["true", quoted("true"), quoted(" TRUE "), "null", quoted("maybe"), quoted(""), "[]", "{}"]
        for value in meansVisible {
            let result = parseResult("{\"summary\": \"ok\", \"isOutfitVisible\": \(value)}")
            #expect(isSuccess(result), "isOutfitVisible \(value) should mean an outfit is visible")
        }

        let meansHidden = ["false", quoted("false"), quoted(" False "), quoted("FALSE")]
        for value in meansHidden {
            let result = parseResult("{\"summary\": \"ok\", \"isOutfitVisible\": \(value)}")
            #expect(result == .failure(.noOutfitVisible(tip: nil)), "isOutfitVisible \(value) should mean no outfit")
        }
    }

    @Test func theTipTravelsWithAMissingOutfit() {
        let cases: [(json: String, expected: String?)] = [
            (#"{"isOutfitVisible": false, "photoFeedback": "Step back."}"#, "Step back."),
            (#"{"isOutfitVisible": false, "photoFeedback": "  Step back.  "}"#, "Step back."),
            (#"{"isOutfitVisible": false, "photoFeedback": null}"#, nil),
            (#"{"isOutfitVisible": false, "photoFeedback": ""}"#, nil),
            (#"{"isOutfitVisible": false, "photoFeedback": "none"}"#, nil),
            (#"{"isOutfitVisible": false, "photoFeedback": 5}"#, nil),
            (#"{"isOutfitVisible": false}"#, nil),
        ]
        for (json, expected) in cases {
            #expect(parseResult(json) == .failure(.noOutfitVisible(tip: expected)), "\(json)")
        }
    }

    @Test func aMissingOutfitWinsOverAnythingElseInTheResponse() {
        // Even a response that also carries a summary and items is refused when it says nothing is visible.
        let json = responseJSON(objective: [itemJSON(title: "A")], extra: ", \"isOutfitVisible\": false")
        #expect(parseResult(json) == .failure(.noOutfitVisible(tip: nil)))
    }

    @Test func aResponseWithNothingToShowIsUnusable() {
        let empties: [String] = [
            "{}",
            #"{"isOutfitVisible": true}"#,
            #"{"summary": ""}"#,
            #"{"summary": "   \n"}"#,
            #"{"summary": null, "objective": [], "subjective": []}"#,
            #"{"objective": [{"title": "", "suggestion": ""}]}"#,
            #"{"objective": [{"title": "Only a title"}]}"#,
            #"{"error": {"message": "rate limited"}}"#,
            #"{"choices": []}"#,
        ]
        for json in empties {
            #expect(parseResult(json) == .failure(.unusableResponse), "\(json)")
        }
    }

    // MARK: Required and optional item fields

    @Test func anItemNeedsAUsableTitleAndSuggestion() {
        let cases: [(name: String, item: String)] = [
            ("no title", #"{"suggestion": "Try this."}"#),
            ("no suggestion", #"{"title": "A title"}"#),
            ("blank title", #"{"title": "  ", "suggestion": "Try this."}"#),
            ("blank suggestion", #"{"title": "A title", "suggestion": "\n"}"#),
            ("placeholder title", #"{"title": "null", "suggestion": "Try this."}"#),
            ("placeholder suggestion", #"{"title": "A title", "suggestion": "N/A"}"#),
            ("numeric title", #"{"title": 42, "suggestion": "Try this."}"#),
            ("boolean title", #"{"title": true, "suggestion": "Try this."}"#),
            ("array title", #"{"title": ["A"], "suggestion": "Try this."}"#),
            ("object suggestion", #"{"title": "A title", "suggestion": {"text": "x"}}"#),
            ("null suggestion", #"{"title": "A title", "suggestion": null}"#),
            ("empty object", "{}"),
        ]
        for (name, item) in cases {
            let advice = parsedAdvice(responseJSON(objective: [item]))
            #expect(advice?.objective.isEmpty == true, "an item with \(name) should be dropped")
        }
    }

    @Test func everythingBesidesTitleAndSuggestionIsOptional() {
        let item = #"{"title": "A title", "suggestion": "Try this."}"#
        let parsed = parsedAdvice(responseJSON(objective: [item]))?.objective.first

        #expect(parsed?.title == "A title")
        #expect(parsed?.suggestion == "Try this.")
        #expect(parsed?.observation == "")
        #expect(parsed?.rationale == "")
        #expect(parsed?.principle == .other)
        #expect(parsed?.impact == .medium)
    }

    @Test func optionalFieldsOfTheWrongTypeFallBackQuietly() {
        let wrongTypes = ["42", "true", "[\"a\"]", "{\"a\": 1}", "null"]
        for wrong in wrongTypes {
            let item = "{\"title\": \"A\", \"suggestion\": \"B\", \"observation\": \(wrong), \"rationale\": \(wrong), \"principle\": \(wrong), \"impact\": \(wrong)}"
            let parsed = parsedAdvice(responseJSON(objective: [item]))?.objective.first

            #expect(parsed != nil, "\(wrong) in the optional fields should not drop the item")
            #expect(parsed?.observation == "", "\(wrong) as an observation")
            #expect(parsed?.rationale == "", "\(wrong) as a rationale")
            #expect(parsed?.principle == .other, "\(wrong) as a principle")
            #expect(parsed?.impact == .medium, "\(wrong) as an impact")
        }
    }

    @Test func textIsTrimmedButOtherwiseKeptExactly() {
        let item = #"{"title": "  Mix patterns 🎨 \n", "suggestion": "Try:\nA\nB", "observation": "  café  ", "rationale": "می"}"#
        let parsed = parsedAdvice(responseJSON(objective: [item]))?.objective.first

        #expect(parsed?.title == "Mix patterns 🎨")
        #expect(parsed?.suggestion == "Try:\nA\nB")     // inner line breaks are kept
        #expect(parsed?.observation == "café")
        #expect(parsed?.rationale == "می")
    }

    // MARK: Enumerations

    @Test func everyPrincipleIsRecognisedInAnyReasonableSpelling() {
        for principle in FashionPrinciple.allCases where principle != .other {
            let spellings = [
                principle.rawValue,
                principle.rawValue.uppercased(),
                principle.rawValue.capitalized,
                principle.rawValue.replacingOccurrences(of: "_", with: " "),
                principle.rawValue.replacingOccurrences(of: "_", with: "-"),
                "  \(principle.rawValue)  ",
            ]
            for spelling in spellings {
                let parsed = parsedAdvice(responseJSON(objective: [itemJSON(principle: spelling, title: "A")]))?.objective.first
                #expect(parsed?.principle == principle, "\"\(spelling)\" should read as \(principle.rawValue)")
            }
        }
    }

    @Test func unrecognisedPrinciplesBecomeOther() {
        for junk in ["", "vibes", "COLOUR", "fit!", "texture/pattern", "123"] {
            let parsed = parsedAdvice(responseJSON(objective: [itemJSON(principle: junk, title: "A")]))?.objective.first
            #expect(parsed?.principle == .other, "\"\(junk)\" is not a principle")
        }
    }

    @Test func everyImpactIsRecognisedInAnyReasonableSpelling() {
        for impact in AdviceImpact.allCases {
            let spellings = [impact.rawValue, impact.rawValue.uppercased(), impact.rawValue.capitalized, "  \(impact.rawValue)  "]
            for spelling in spellings {
                let parsed = parsedAdvice(responseJSON(objective: [itemJSON(impact: spelling, title: "A")]))?.objective.first
                #expect(parsed?.impact == impact, "\"\(spelling)\" should read as \(impact.rawValue)")
            }
        }
    }

    @Test func unrecognisedImpactsBecomeMedium() {
        for junk in ["", "huge", "critical", "1", "highest", "high-ish"] {
            let parsed = parsedAdvice(responseJSON(objective: [itemJSON(impact: junk, title: "A")]))?.objective.first
            #expect(parsed?.impact == .medium, "\"\(junk)\" is not an impact")
        }
    }

    @Test func goalAlignmentIsReadForgivingly() {
        let cases: [(value: String, expected: GoalAlignment?)] = [
            (quoted("on_target"), .onTarget),
            (quoted("On Target"), .onTarget),
            (quoted("on-target"), .onTarget),
            (quoted(" ON_TARGET "), .onTarget),
            (quoted("close"), .close),
            (quoted("CLOSE"), .close),
            (quoted("off_target"), .offTarget),
            (quoted("off target"), .offTarget),
            (quoted("Off-Target"), .offTarget),
            ("null", nil),
            (quoted(""), nil),
            (quoted("nearly there"), nil),
            (quoted("target"), nil),
            ("5", nil),
            ("true", nil),
            ("[]", nil),
        ]
        for (value, expected) in cases {
            let advice = parsedAdvice("{\"summary\": \"ok\", \"goalAlignment\": \(value)}")
            #expect(advice != nil, "\(value) should not make the response unusable")
            #expect(advice?.goalAlignment == expected, "goalAlignment \(value)")
        }
    }

    // MARK: Summary and style

    @Test func summaryAndStyleAreTrimmedAndPlaceholdersIgnored() {
        let cases: [(json: String, summary: String, style: String)] = [
            (#"{"summary": "  Nice.  ", "detectedStyle": "  smart casual "}"#, "Nice.", "smart casual"),
            (#"{"summary": "Nice.", "detectedStyle": "N/A"}"#, "Nice.", ""),
            (#"{"summary": "Nice.", "detectedStyle": "none"}"#, "Nice.", ""),
            (#"{"summary": "Nice.", "detectedStyle": null}"#, "Nice.", ""),
            (#"{"summary": "Nice.", "detectedStyle": 5}"#, "Nice.", ""),
            (#"{"summary": "Nice.", "detectedStyle": ["a"]}"#, "Nice.", ""),
        ]
        for c in cases {
            let advice = parsedAdvice(c.json)
            #expect(advice?.summary == c.summary, "\(c.json)")
            #expect(advice?.detectedStyle == c.style, "\(c.json)")
        }
    }

    // MARK: Notes

    @Test func notesSkipJunkAndKeepTheRest() {
        let json = #"{"summary": "ok", "strengths": ["ok", null, 5, true, "", "  ", "none", "N/A", "null", ["x"], {"a": 1}, "fine"]}"#
        #expect(parsedAdvice(json)?.strengths == ["ok", "fine"])
    }

    @Test func notesAreCappedAfterTheJunkIsRemoved() {
        let json = #"{"summary": "ok", "limitations": ["", "none", "A", "B", "C", "D", "E"]}"#
        #expect(parsedAdvice(json)?.limitations == ["A", "B", "C"])
    }

    @Test func notesOfTheWrongShapeAreIgnored() {
        for shape in [quoted("text"), "5", "true", "{\"a\": 1}", "null"] {
            let json = "{\"summary\": \"ok\", \"strengths\": \(shape), \"limitations\": \(shape)}"
            let advice = parsedAdvice(json)
            #expect(advice?.strengths.isEmpty == true, "\(shape) as strengths")
            #expect(advice?.limitations.isEmpty == true, "\(shape) as limitations")
        }
    }

    // MARK: Lists of items

    @Test func aStrayEntryCostsOnlyItself() {
        let valid = itemJSON(title: "Keeper")
        let junk = [quoted("oops"), "42", "null", "true", "[1, 2]", "{}", #"{"title": "No suggestion"}"#]
        let advice = parsedAdvice(responseJSON(objective: junk + [valid]))

        #expect(advice?.objective.map(\.title) == ["Keeper"])
        // Its id follows its place in the original list, so ids stay unique and stable.
        #expect(advice?.objective.first?.id == "objective-\(junk.count)")
    }

    @Test func listsOfTheWrongShapeAreIgnored() {
        for shape in [quoted("none"), "5", "true", "{\"a\": 1}", "null"] {
            let json = "{\"summary\": \"ok\", \"objective\": \(shape), \"subjective\": \(shape)}"
            let advice = parsedAdvice(json)
            #expect(advice?.objective.isEmpty == true, "\(shape) as the objective list")
            #expect(advice?.subjective.isEmpty == true, "\(shape) as the subjective list")
        }
    }

    @Test func itemsAreOrderedByImpactThenByTheModelsOrder() {
        let items = [
            itemJSON(impact: "low", title: "A"),
            itemJSON(impact: "high", title: "B"),
            itemJSON(impact: "medium", title: "C"),
            itemJSON(impact: "high", title: "D"),
        ]
        let advice = parsedAdvice(responseJSON(objective: items))
        #expect(advice?.objective.map(\.title) == ["B", "D", "C", "A"])
    }

    @Test func theBiggestImpactSurvivesTheCap() {
        let lows = (0..<5).map { itemJSON(impact: "low", title: "Low \($0)") }
        let high = itemJSON(impact: "high", title: "High")
        let advice = parsedAdvice(responseJSON(objective: lows + [high]))

        // The high-impact item came last but is sorted first, so the cap trims a low one instead.
        #expect(advice?.objective.map(\.title) == ["High", "Low 0", "Low 1", "Low 2"])
    }

    @Test func eachLensIsCappedAndNumberedOnItsOwn() {
        let items = (0..<9).map { itemJSON(title: "Item \($0)") }
        let advice = parsedAdvice(responseJSON(objective: items, subjective: items))

        #expect(advice?.objective.count == OutfitAdvice.maxItemsPerKind)
        #expect(advice?.subjective.count == OutfitAdvice.maxItemsPerKind)
        #expect(advice?.objective.first?.id == "objective-0")
        #expect(advice?.subjective.first?.id == "subjective-0")
    }

    @Test func theCapsMatchWhatThePromptAsksFor() {
        // The prompt tells the model how many points to give. If the client's caps change, the prompt must too.
        #expect(OutfitAdvice.maxItemsPerKind == 4)
        #expect(OutfitAdvice.maxNotes == 3)
        #expect(FashionAdvicePrompt.systemPrompt.contains("1 to 4 most valuable points"))
        #expect(FashionAdvicePrompt.systemPrompt.contains("at most 3 short items"))
    }

    @Test func aHugeResponseIsHandled() {
        let many = (0..<2000).map { itemJSON(title: "Item \($0)") }
        let notes = (0..<1000).map { "\"Note \($0)\"" }.joined(separator: ",")
        let extra = ", \"strengths\": [\(notes)], \"limitations\": [\(notes)]"
        let advice = parsedAdvice(responseJSON(objective: many, subjective: many, extra: extra))

        #expect(advice?.objective.count == OutfitAdvice.maxItemsPerKind)
        #expect(advice?.subjective.count == OutfitAdvice.maxItemsPerKind)
        #expect(advice?.strengths.count == OutfitAdvice.maxNotes)
        #expect(advice?.limitations.count == OutfitAdvice.maxNotes)
    }

    @Test func unknownKeysAreIgnored() {
        let item = #"{"title": "A", "suggestion": "B", "confidence": "high", "extra": {"deep": [1, 2, {"deeper": null}]}}"#
        let extra = #", "confidence": 0.9, "debug": {"tokens": 12}"#
        let advice = parsedAdvice(responseJSON(objective: [item], extra: extra))

        #expect(advice?.objective.map(\.title) == ["A"])
    }
}

/// The fixed vocabulary of the advice: its wire format, its labels, and its icons.
@MainActor
@Suite("Advice vocabulary")
struct AdviceVocabularyTests {

    @Test func rawValuesAreTheWireFormat() {
        // These strings are part of the contract with the AI service and the backend. Change them deliberately.
        #expect(FashionPrinciple.allCases.map(\.rawValue) == [
            "color", "proportion", "fit", "texture_pattern", "formality", "accessories", "layering", "condition",
            "style_match", "occasion", "impression",
            "other",
        ])
        #expect(AdviceImpact.allCases.map(\.rawValue) == ["high", "medium", "low"])
        #expect(GoalAlignment.allCases.map(\.rawValue) == ["on_target", "close", "off_target"])
        #expect(AdviceKind.allCases.map(\.rawValue) == ["subjective", "objective"])
    }

    @Test func everyCaseHasALabelAndAnIcon() {
        for principle in FashionPrinciple.allCases {
            #expect(!principle.displayName.isEmpty, "\(principle.rawValue) needs a label")
            #expect(!principle.icon.isEmpty, "\(principle.rawValue) needs an icon")
        }
        for alignment in GoalAlignment.allCases {
            #expect(!alignment.displayName.isEmpty, "\(alignment.rawValue) needs a label")
            #expect(!alignment.icon.isEmpty, "\(alignment.rawValue) needs an icon")
        }
        for kind in AdviceKind.allCases {
            #expect(!kind.displayName.isEmpty, "\(kind.rawValue) needs a label")
        }
    }

    @Test func labelsAndIconsAreDistinct() {
        let principleNames = FashionPrinciple.allCases.map(\.displayName)
        let principleIcons = FashionPrinciple.allCases.map(\.icon)
        #expect(Set(principleNames).count == principleNames.count, "two principles share a label")
        #expect(Set(principleIcons).count == principleIcons.count, "two principles share an icon")

        let alignmentNames = GoalAlignment.allCases.map(\.displayName)
        let alignmentIcons = GoalAlignment.allCases.map(\.icon)
        #expect(Set(alignmentNames).count == alignmentNames.count, "two alignments share a label")
        #expect(Set(alignmentIcons).count == alignmentIcons.count, "two alignments share an icon")

        let kindNames = AdviceKind.allCases.map(\.displayName)
        #expect(Set(kindNames).count == kindNames.count, "two lenses share a label")
    }

    @Test func impactRanksAreStrictlyOrdered() {
        #expect(AdviceImpact.high.rank < AdviceImpact.medium.rank)
        #expect(AdviceImpact.medium.rank < AdviceImpact.low.rank)
        let ranks = AdviceImpact.allCases.map(\.rank)
        #expect(Set(ranks).count == ranks.count)
    }

    @Test func everySymbolNameExistsOnThisSystem() {
        var names: [String] = FashionPrinciple.allCases.map(\.icon)
        names += GoalAlignment.allCases.map(\.icon)
        // Symbols the Style screens use directly. Keep in step with StyleView, OutfitAdviceResultView and ContentView.
        names += [
            "tshirt", "camera", "photo.on.rectangle", "arrow.triangle.2.circlepath", "trash",
            "camera.viewfinder", "exclamationmark.circle", "checkmark", "info.circle", "chevron.down",
        ]
        for name in names {
            #expect(UIImage(systemName: name) != nil, "\"\(name)\" is not an SF Symbol on this system")
        }
    }

    @Test func itemsForALensComeFromThatLens() {
        let advice = parsedAdvice(fullResponseJSON)
        #expect(advice?.items(for: .subjective) == advice?.subjective)
        #expect(advice?.items(for: .objective) == advice?.objective)
    }

    @Test func theGoalLensLeadsOnlyWhenItHasAdvice() {
        let both = parsedAdvice(fullResponseJSON)
        #expect(both?.defaultKind == .subjective)

        let onlyObjective = parsedAdvice(responseJSON(objective: [itemJSON(title: "A")]))
        #expect(onlyObjective?.defaultKind == .objective)

        let neither = parsedAdvice(#"{"summary": "Nothing to change."}"#)
        #expect(neither?.defaultKind == .objective)
    }

    @Test func errorsDescribeThemselves() {
        #expect(OutfitAdviceError.noOutfitVisible(tip: "Step back.").errorDescription == "Step back.")
        #expect(OutfitAdviceError.noOutfitVisible(tip: nil).errorDescription?.isEmpty == false)
        #expect(OutfitAdviceError.unusableResponse.errorDescription?.isEmpty == false)

        #expect(OutfitAdviceError.noOutfitVisible(tip: "a") != OutfitAdviceError.noOutfitVisible(tip: "b"))
        #expect(OutfitAdviceError.noOutfitVisible(tip: nil) != OutfitAdviceError.unusableResponse)
    }
}
