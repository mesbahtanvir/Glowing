import Testing
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import Glowing

// MARK: - StyleGoal

@MainActor
@Suite("StyleGoal")
struct StyleGoalTests {

    @Test func trimsAndCollapsesWhitespace() {
        #expect(StyleGoal("  Job \n\n  interview\t ")?.text == "Job interview")
    }

    @Test func emptyOrBlankInputHasNoGoal() {
        #expect(StyleGoal("") == nil)
        #expect(StyleGoal("   \n\t ") == nil)
    }

    @Test func dropsControlCharacters() {
        #expect(StyleGoal("Date\u{0007} night")?.text == "Date night")
    }

    @Test func capsLength() {
        let long = String(repeating: "a", count: StyleGoal.maxLength * 3)
        #expect(StyleGoal(long)?.text.count == StyleGoal.maxLength)
    }

    @Test func neverSplitsAnEmojiWhenCapping() {
        let long = String(repeating: "👗", count: StyleGoal.maxLength * 2)
        let text = StyleGoal(long)?.text ?? ""
        #expect(text.count == StyleGoal.maxLength)
        #expect(text.allSatisfy { $0 == "👗" })
    }

    @Test func keepsTheJoinersThatEmojiAndScriptsDependOn() {
        // A family emoji is three emoji joined by U+200D.
        let family = "\u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467}"
        #expect(StyleGoal("Family \(family) brunch")?.text == "Family \(family) brunch")

        // Persian writes some words with U+200C (zero-width non-joiner).
        let persian = "\u{0645}\u{06CC}\u{200C}\u{062E}\u{0648}\u{0627}\u{0647}\u{0645}"
        #expect(StyleGoal(persian)?.text == persian)
    }

    @Test func removesInvisibleTagCharacters() {
        // U+E0041 and U+E0042 are invisible "tag" letters. Pasted into a goal, they could carry hidden text.
        #expect(StyleGoal("Date\u{E0041}\u{E0042} night")?.text == "Date night")
    }

    @Test func suggestionsAreValidGoalsAndUnique() {
        #expect(!StyleGoal.suggestions.isEmpty)
        #expect(Set(StyleGoal.suggestions).count == StyleGoal.suggestions.count)
        for suggestion in StyleGoal.suggestions {
            // A chip that changed when sanitised would never show as selected.
            #expect(StyleGoal(suggestion)?.text == suggestion, "\(suggestion) should be a valid, unchanged goal")
        }
    }
}

// MARK: - Parsing

@MainActor
@Suite("OutfitAdvice parsing")
struct OutfitAdviceParsingTests {

    @Test func parsesAFullResponse() throws {
        let advice = try OutfitAdvice.parse(object(fullResponseJSON))

        #expect(advice.detectedStyle == "smart casual")
        #expect(advice.summary == "A relaxed look. Swap the hoodie for a collared layer.")
        #expect(advice.goalAlignment == .close)
        #expect(advice.strengths == ["Clean navy chinos", "Matching brown belt and shoes"])
        #expect(advice.limitations == ["Shoes are cropped out of the photo."])
        #expect(advice.photoTip == nil)

        #expect(advice.subjective.count == 1)
        #expect(advice.subjective[0].kind == .subjective)
        #expect(advice.subjective[0].principle == .occasion)
        #expect(advice.subjective[0].title == "Swap the hoodie")
        #expect(advice.subjective[0].suggestion == "Try a knit polo.")
        #expect(advice.objective.count == 2)
        #expect(advice.objective.allSatisfy { $0.kind == .objective })
    }

    @Test func putsTheBiggestImpactFirst() throws {
        let advice = try OutfitAdvice.parse(object(fullResponseJSON))
        // The fixture lists color (low) before proportion (high).
        #expect(advice.objective.map(\.principle) == [.proportion, .color])
    }

    @Test func keepsTheModelsOrderWithinTheSameImpact() throws {
        let json = """
        {"summary": "ok", "objective": [\(itemJSON(title: "A")), \(itemJSON(title: "B")), \(itemJSON(title: "C"))]}
        """
        let advice = try OutfitAdvice.parse(object(json))
        #expect(advice.objective.map(\.title) == ["A", "B", "C"])
    }

    @Test func idsAreUniqueAcrossBothLenses() throws {
        let advice = try OutfitAdvice.parse(object(fullResponseJSON))
        let ids = (advice.subjective + advice.objective).map(\.id)
        #expect(Set(ids).count == ids.count)
        // Ids follow the model's original position, so the high-impact item that came second keeps "-1".
        #expect(advice.objective.first?.id == "objective-1")
    }

    @Test func unknownPrincipleBecomesOther() throws {
        let json = """
        {"summary": "ok", "objective": [\(itemJSON(principle: "vibes", title: "A"))]}
        """
        let advice = try OutfitAdvice.parse(object(json))
        #expect(advice.objective.first?.principle == .other)
    }

    @Test func principleFormattingIsForgiving() throws {
        let json = """
        {"summary": "ok",
         "objective": [\(itemJSON(principle: "Texture Pattern", title: "A"))],
         "subjective": [\(itemJSON(principle: "style-match", title: "B"))]}
        """
        let advice = try OutfitAdvice.parse(object(json))
        #expect(advice.objective.first?.principle == .texturePattern)
        #expect(advice.subjective.first?.principle == .styleMatch)
    }

    @Test func missingOrUnknownImpactBecomesMedium() throws {
        let json = """
        {"summary": "ok", "objective": [
          {"principle": "fit", "title": "A", "suggestion": "Try this."},
          {"principle": "fit", "impact": "enormous", "title": "B", "suggestion": "Try that."}
        ]}
        """
        let advice = try OutfitAdvice.parse(object(json))
        #expect(advice.objective.map(\.impact) == [.medium, .medium])
    }

    @Test func dropsItemsWithoutATitleOrSuggestion() throws {
        let json = """
        {"summary": "ok", "objective": [
          {"principle": "fit", "suggestion": "No title here."},
          {"principle": "fit", "title": "No suggestion here"},
          {"principle": "fit", "title": "   ", "suggestion": "Blank title."},
          \(itemJSON(title: "Keeper"))
        ]}
        """
        let advice = try OutfitAdvice.parse(object(json))
        #expect(advice.objective.map(\.title) == ["Keeper"])
    }

    @Test func capsItemsPerLens() throws {
        let items = (0..<7).map { itemJSON(title: "Item \($0)") }.joined(separator: ",")
        let advice = try OutfitAdvice.parse(object("{\"summary\": \"ok\", \"objective\": [\(items)], \"subjective\": [\(items)]}"))
        #expect(advice.objective.count == OutfitAdvice.maxItemsPerKind)
        #expect(advice.subjective.count == OutfitAdvice.maxItemsPerKind)
    }

    @Test func capsAndCleansNotes() throws {
        let json = """
        {"summary": "ok",
         "strengths": ["One", "Two", "Three", "Four", "Five"],
         "limitations": ["  Shoes hidden  ", "", 42, "Coat covers layers"]}
        """
        let advice = try OutfitAdvice.parse(object(json))
        #expect(advice.strengths == ["One", "Two", "Three"])
        #expect(advice.limitations == ["Shoes hidden", "Coat covers layers"])
    }

    @Test func aMissingOutfitThrowsWithTheModelsTip() {
        let json = #"{"isOutfitVisible": false, "photoFeedback": "Step back so your whole look is in frame."}"#
        do {
            _ = try OutfitAdvice.parse(object(json))
            Issue.record("Expected parsing to throw")
        } catch let error as OutfitAdviceError {
            #expect(error == .noOutfitVisible(tip: "Step back so your whole look is in frame."))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func aMissingOutfitWithoutATipStillThrowsTheRightError() {
        // Also covers the flag arriving as a string.
        let json = #"{"isOutfitVisible": "false"}"#
        do {
            _ = try OutfitAdvice.parse(object(json))
            Issue.record("Expected parsing to throw")
        } catch let error as OutfitAdviceError {
            #expect(error == .noOutfitVisible(tip: nil))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func anEmptyResponseIsUnusable() {
        do {
            _ = try OutfitAdvice.parse([:])
            Issue.record("Expected parsing to throw")
        } catch let error as OutfitAdviceError {
            #expect(error == .unusableResponse)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func aSummaryAloneIsEnoughForAnOutfitWithNothingToFix() throws {
        let advice = try OutfitAdvice.parse(object(#"{"isOutfitVisible": true, "summary": "This works as it is."}"#))
        #expect(advice.summary == "This works as it is.")
        #expect(advice.subjective.isEmpty)
        #expect(advice.objective.isEmpty)
    }

    @Test func alignmentIsNilWhenMissingNullOrUnrecognised() throws {
        for fragment in ["", #","goalAlignment": null"#, #","goalAlignment": "fabulous""#] {
            let advice = try OutfitAdvice.parse(object(#"{"summary": "ok"\#(fragment)}"#))
            #expect(advice.goalAlignment == nil)
        }
        let known = try OutfitAdvice.parse(object(#"{"summary": "ok", "goalAlignment": "On Target"}"#))
        #expect(known.goalAlignment == .onTarget)
    }

    @Test func placeholderStringsCountAsMissing() throws {
        let json = #"{"summary": "ok", "photoFeedback": "null", "detectedStyle": "N/A"}"#
        let advice = try OutfitAdvice.parse(object(json))
        #expect(advice.photoTip == nil)
        #expect(advice.detectedStyle == "")
    }

    @Test func keepsAPhotoTipWhenTheOutfitIsStillVisible() throws {
        let json = #"{"isOutfitVisible": true, "summary": "ok", "photoFeedback": "Step back to show your shoes."}"#
        let advice = try OutfitAdvice.parse(object(json))
        #expect(advice.photoTip == "Step back to show your shoes.")
    }

    @Test func wronglyShapedFieldsAreIgnoredNotFatal() throws {
        let json = #"{"summary": "ok", "objective": "none", "subjective": {"a": 1}, "strengths": "x", "limitations": 5}"#
        let advice = try OutfitAdvice.parse(object(json))
        #expect(advice.objective.isEmpty)
        #expect(advice.subjective.isEmpty)
        #expect(advice.strengths.isEmpty)
        #expect(advice.limitations.isEmpty)
    }

    @Test func theGoalLensLeadsWhenItHasAdvice() throws {
        let both = try OutfitAdvice.parse(object(fullResponseJSON))
        #expect(both.defaultKind == .subjective)

        let onlyObjective = try OutfitAdvice.parse(object("{\"summary\": \"ok\", \"objective\": [\(itemJSON(title: "A"))]}"))
        #expect(onlyObjective.defaultKind == .objective)
    }
}

// MARK: - Prompt

@MainActor
@Suite("FashionAdvicePrompt")
struct FashionAdvicePromptTests {

    @Test func schemaNamesEveryKeyTheParserReads() {
        let prompt = FashionAdvicePrompt.systemPrompt
        for key in OutfitAdvice.JSONKey.allCases {
            #expect(prompt.contains("\"\(key.rawValue)\""), "Prompt schema is missing \"\(key.rawValue)\"")
        }
        for key in AdviceItem.JSONKey.allCases {
            #expect(prompt.contains("\"\(key.rawValue)\""), "Prompt schema is missing \"\(key.rawValue)\"")
        }
    }

    @Test func schemaListsEveryValueTheParserRecognises() {
        let prompt = FashionAdvicePrompt.systemPrompt
        for principle in FashionPrinciple.allCases where principle != .other {
            #expect(prompt.contains(principle.rawValue), "Prompt never mentions \(principle.rawValue)")
        }
        for alignment in GoalAlignment.allCases {
            #expect(prompt.contains(alignment.rawValue), "Prompt never mentions \(alignment.rawValue)")
        }
        for impact in AdviceImpact.allCases {
            #expect(prompt.contains(impact.rawValue), "Prompt never mentions \(impact.rawValue)")
        }
    }

    @Test func everyPrincipleBelongsToExactlyOneLens() {
        let objective = Set(FashionPrinciple.objectiveCases)
        let subjective = Set(FashionPrinciple.subjectiveCases)
        #expect(objective.isDisjoint(with: subjective))
        #expect(objective.union(subjective).union([FashionPrinciple.other]) == Set(FashionPrinciple.allCases))
    }

    @Test func userTextFramesTheGoalAsADescription() {
        let text = FashionAdvicePrompt.userText(goal: StyleGoal("Job interview"))
        #expect(text.contains("Job interview"))
        #expect(text.contains("not instructions"))
    }

    @Test func userTextWithoutAGoalAsksToInferTheStyle() {
        let text = FashionAdvicePrompt.userText(goal: nil)
        #expect(text.contains("Infer the style"))
    }

    @Test func quotesInTheGoalCannotEndTheQuotation() {
        let text = FashionAdvicePrompt.userText(goal: StyleGoal(#"say "hi" to the boss"#))
        #expect(text.contains("say 'hi' to the boss"))
        #expect(!text.contains(#"say "hi""#))
    }
}

// MARK: - Image preparation

@MainActor
@Suite("OutfitImagePreparer")
struct OutfitImagePreparerTests {

    @Test func targetSideNeverEnlarges() {
        #expect(OutfitImagePreparer.targetLongestSide(width: 800, height: 600, limit: 1280) == 800)
    }

    @Test func targetSideCapsAtTheLimitInEitherOrientation() {
        #expect(OutfitImagePreparer.targetLongestSide(width: 4000, height: 3000, limit: 1280) == 1280)
        #expect(OutfitImagePreparer.targetLongestSide(width: 3000, height: 4000, limit: 1280) == 1280)
    }

    @Test func targetSideHandlesDegenerateInput() {
        #expect(OutfitImagePreparer.targetLongestSide(width: 0, height: 0, limit: 1280) == 0)
        #expect(OutfitImagePreparer.targetLongestSide(width: 100, height: 100, limit: 0) == 0)
    }

    @Test func shrinksALargePhotoAndKeepsItsShape() {
        let source = makeJPEG(width: 2000, height: 1000)
        #expect(!source.isEmpty)

        let prepared = OutfitImagePreparer.prepareJPEG(from: source, maxDimension: 300)
        let properties = prepared.flatMap(imageProperties(of:))
        let width = properties?[kCGImagePropertyPixelWidth] as? Int ?? 0
        let height = properties?[kCGImagePropertyPixelHeight] as? Int ?? 0

        #expect(max(width, height) <= 300)
        #expect(max(width, height) >= 299)
        #expect(abs(Double(width) / Double(max(height, 1)) - 2.0) < 0.05)
    }

    @Test func doesNotEnlargeASmallPhoto() {
        let source = makeJPEG(width: 200, height: 100)
        let prepared = OutfitImagePreparer.prepareJPEG(from: source, maxDimension: 300)
        let properties = prepared.flatMap(imageProperties(of:))

        #expect(properties?[kCGImagePropertyPixelWidth] as? Int == 200)
        #expect(properties?[kCGImagePropertyPixelHeight] as? Int == 100)
    }

    @Test func stripsLocationMetadata() {
        let source = makeJPEG(width: 400, height: 300, withGPS: true)
        // Guard against passing vacuously: the source really does carry a location.
        #expect(imageProperties(of: source)?[kCGImagePropertyGPSDictionary] != nil)

        let prepared = OutfitImagePreparer.prepareJPEG(from: source)
        #expect(prepared != nil)
        #expect(prepared.flatMap(imageProperties(of:))?[kCGImagePropertyGPSDictionary] == nil)
    }

    @Test func rejectsDataThatIsNotAnImage() {
        #expect(OutfitImagePreparer.prepareJPEG(from: Data("not an image".utf8)) == nil)
        #expect(OutfitImagePreparer.prepareJPEG(from: Data()) == nil)
    }
}

// MARK: - View model

@MainActor
@Suite("OutfitAdviceViewModel")
struct OutfitAdviceViewModelTests {

    private let photo = makeJPEG(width: 64, height: 48)

    private func makeViewModel(_ advisor: any OutfitAdvising) -> OutfitAdviceViewModel {
        let viewModel = OutfitAdviceViewModel(advisor: advisor)
        viewModel.setPhoto(preparedJPEG: photo)
        return viewModel
    }

    @Test func startsEmptyAndCannotAnalyze() {
        let viewModel = OutfitAdviceViewModel(advisor: StubAdvisor(.success(sampleAdvice())))
        #expect(viewModel.phase == .composing)
        #expect(!viewModel.hasPhoto)
        #expect(!viewModel.canAnalyze)
        #expect(viewModel.analyze() == nil)
    }

    @Test func aPhotoEnablesAnalysis() {
        let viewModel = makeViewModel(StubAdvisor(.success(sampleAdvice())))
        #expect(viewModel.hasPhoto)
        #expect(viewModel.previewImage != nil)
        #expect(viewModel.canAnalyze)
    }

    @Test func refusesAPhotoItCannotDecode() {
        let viewModel = OutfitAdviceViewModel(advisor: StubAdvisor(.success(sampleAdvice())))
        viewModel.setPhoto(preparedJPEG: Data([0x01, 0x02, 0x03]))
        #expect(!viewModel.hasPhoto)
        #expect(viewModel.notice?.kind == .error)
    }

    @Test func sendsTheCleanedGoalAndShowsTheResult() async {
        let advice = sampleAdvice(summary: "Nice.")
        let advisor = StubAdvisor(.success(advice))
        let viewModel = makeViewModel(advisor)
        viewModel.goalText = "  Job \n interview "

        await viewModel.analyze()?.value

        #expect(advisor.callCount == 1)
        #expect(advisor.lastGoal?.text == "Job interview")
        #expect(viewModel.phase == .result(advice))
        #expect(viewModel.notice == nil)
    }

    @Test func aBlankGoalIsSentAsNoGoal() async {
        let advisor = StubAdvisor(.success(sampleAdvice()))
        let viewModel = makeViewModel(advisor)
        viewModel.goalText = "   "

        await viewModel.analyze()?.value

        #expect(advisor.callCount == 1)
        #expect(advisor.lastGoal == nil)
    }

    @Test func aFailureKeepsThePhotoAndGoalAndExplainsInline() async {
        let viewModel = makeViewModel(StubAdvisor(.failure(BackendAPIClient.APIError.noAPIKey)))
        viewModel.goalText = "Date night"

        await viewModel.analyze()?.value

        #expect(viewModel.phase == .composing)
        #expect(viewModel.hasPhoto)
        #expect(viewModel.goalText == "Date night")
        #expect(viewModel.notice?.kind == .error)
        #expect(viewModel.notice?.message == BackendAPIClient.APIError.noAPIKey.errorDescription)
        #expect(viewModel.canAnalyze) // one tap to retry
    }

    @Test func aPhotoWithoutAnOutfitGetsAGentleTip() async {
        let error = OutfitAdviceError.noOutfitVisible(tip: "Step back so your whole look is in frame.")
        let viewModel = makeViewModel(StubAdvisor(.failure(error)))

        await viewModel.analyze()?.value

        #expect(viewModel.phase == .composing)
        #expect(viewModel.notice?.kind == .photoTip)
        #expect(viewModel.notice?.message == "Step back so your whole look is in frame.")
    }

    @Test func offlineGetsAFriendlyMessage() async {
        let viewModel = makeViewModel(StubAdvisor(.failure(URLError(.notConnectedToInternet))))

        await viewModel.analyze()?.value

        #expect(viewModel.notice?.message.contains("offline") == true)
        #expect(viewModel.hasPhoto)
    }

    @Test func cancellingReturnsToComposingQuietly() async {
        let viewModel = makeViewModel(SuspendingAdvisor())
        viewModel.goalText = "Streetwear"

        let task = viewModel.analyze()
        #expect(viewModel.phase == .analyzing)

        viewModel.cancelAnalysis()
        await task?.value

        #expect(viewModel.phase == .composing)
        #expect(viewModel.notice == nil)
        #expect(viewModel.hasPhoto)
        #expect(viewModel.goalText == "Streetwear")
    }

    @Test func ignoresASecondTapWhileAnalyzing() async {
        let advisor = StubAdvisor(.success(sampleAdvice()))
        let viewModel = makeViewModel(advisor)

        let first = viewModel.analyze()
        let second = viewModel.analyze()
        await first?.value

        #expect(second == nil)
        #expect(advisor.callCount == 1)
    }

    @Test func anotherLookKeepsTheGoalButClearsThePhoto() async {
        let viewModel = makeViewModel(StubAdvisor(.success(sampleAdvice())))
        viewModel.goalText = "Wedding guest"
        await viewModel.analyze()?.value

        viewModel.newPhoto()

        #expect(viewModel.phase == .composing)
        #expect(!viewModel.hasPhoto)
        #expect(viewModel.previewImage == nil)
        #expect(viewModel.goalText == "Wedding guest")
    }

    @Test func changingTheGoalKeepsThePhoto() async {
        let viewModel = makeViewModel(StubAdvisor(.success(sampleAdvice())))
        viewModel.goalText = "Wedding guest"
        await viewModel.analyze()?.value

        viewModel.editInputs()

        #expect(viewModel.phase == .composing)
        #expect(viewModel.hasPhoto)
        #expect(viewModel.goalText == "Wedding guest")
    }

    @Test func removingThePhotoDisablesAnalysis() {
        let viewModel = makeViewModel(StubAdvisor(.success(sampleAdvice())))
        viewModel.removePhoto()
        #expect(!viewModel.hasPhoto)
        #expect(!viewModel.canAnalyze)
    }

    // MARK: Photo loading

    @Test func loadingAPhotoShrinksItAndShowsIt() async {
        let viewModel = OutfitAdviceViewModel(advisor: StubAdvisor(.success(sampleAdvice())))
        let large = makeJPEG(width: 2000, height: 1000)

        await viewModel.loadPhoto { large }

        #expect(viewModel.hasPhoto)
        #expect(!viewModel.isLoadingPhoto)
        #expect(viewModel.notice == nil)
        let properties = viewModel.photoJPEG.flatMap(imageProperties(of:))
        let width = properties?[kCGImagePropertyPixelWidth] as? Int ?? 0
        #expect(width > 0 && width <= 1280)
    }

    @Test func anUnreadablePhotoKeepsTheCurrentOneAndExplains() async {
        let viewModel = makeViewModel(StubAdvisor(.success(sampleAdvice())))

        await viewModel.loadPhoto { Data("not an image".utf8) }

        #expect(viewModel.photoJPEG == photo)
        #expect(viewModel.notice?.kind == .error)
        #expect(!viewModel.isLoadingPhoto)
    }

    @Test func aPhotoThatCannotBeFetchedIsReported() async {
        let viewModel = OutfitAdviceViewModel(advisor: StubAdvisor(.success(sampleAdvice())))

        await viewModel.loadPhoto { nil }

        #expect(!viewModel.hasPhoto)
        #expect(viewModel.notice?.kind == .error)
        #expect(!viewModel.isLoadingPhoto)
    }

    @Test func analysisWaitsForAPhotoThatIsStillLoading() {
        let viewModel = makeViewModel(StubAdvisor(.success(sampleAdvice())))

        let ticket = viewModel.beginPhotoLoad()
        #expect(viewModel.isLoadingPhoto)
        #expect(!viewModel.canAnalyze)
        #expect(viewModel.analyze() == nil)

        viewModel.finishPhotoLoad(ticket: ticket, preparedJPEG: photo)
        #expect(!viewModel.isLoadingPhoto)
        #expect(viewModel.canAnalyze)
    }

    @Test func aNewerPhotoLoadWinsOverAnOlderOne() {
        let viewModel = OutfitAdviceViewModel(advisor: StubAdvisor(.success(sampleAdvice())))
        let older = viewModel.beginPhotoLoad()
        let newer = viewModel.beginPhotoLoad()

        viewModel.finishPhotoLoad(ticket: newer, preparedJPEG: photo)
        // The slower, older load finishes last and must not overwrite the newer photo.
        viewModel.finishPhotoLoad(ticket: older, preparedJPEG: makeJPEG(width: 32, height: 32))

        #expect(viewModel.photoJPEG == photo)
        #expect(!viewModel.isLoadingPhoto)
    }

    @Test func removingThePhotoAbandonsALoadInFlight() {
        let viewModel = makeViewModel(StubAdvisor(.success(sampleAdvice())))
        let ticket = viewModel.beginPhotoLoad()

        viewModel.removePhoto()
        viewModel.finishPhotoLoad(ticket: ticket, preparedJPEG: makeJPEG(width: 32, height: 32))

        #expect(!viewModel.hasPhoto)
        #expect(!viewModel.isLoadingPhoto)
    }

    @Test func aLateLoadCannotSwapThePhotoBeingAnalyzed() async {
        let viewModel = makeViewModel(SuspendingAdvisor())
        let task = viewModel.analyze()
        #expect(viewModel.phase == .analyzing)

        // The UI can't start a load during analysis, but the guard shouldn't depend on that.
        let ticket = viewModel.beginPhotoLoad()
        viewModel.finishPhotoLoad(ticket: ticket, preparedJPEG: makeJPEG(width: 32, height: 32))
        #expect(viewModel.photoJPEG == photo)

        viewModel.cancelAnalysis()
        await task?.value
    }
}
