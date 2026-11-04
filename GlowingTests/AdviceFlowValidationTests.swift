import Testing
import Foundation
@testable import Glowing

/// When the view model lets each action happen, and what it does with the user's input on the way.
@MainActor
@Suite("Advice flow validation")
struct AdviceFlowValidationTests {

    private let photo = makeJPEG(width: 64, height: 48)

    private func makeViewModel(_ advisor: any OutfitAdvising, withPhoto: Bool = true) -> OutfitAdviceViewModel {
        let viewModel = OutfitAdviceViewModel(advisor: advisor)
        if withPhoto {
            viewModel.setPhoto(preparedJPEG: photo)
        }
        return viewModel
    }

    // MARK: Preconditions

    @Test func analysisNeedsAReadyPhotoAndTheComposingScreen() async {
        let viewModel = makeViewModel(StubAdvisor(.success(sampleAdvice())), withPhoto: false)
        #expect(!viewModel.canAnalyze, "no photo yet")
        #expect(viewModel.analyze() == nil)

        viewModel.setPhoto(preparedJPEG: photo)
        #expect(viewModel.canAnalyze, "photo ready")

        let ticket = viewModel.beginPhotoLoad()
        #expect(!viewModel.canAnalyze, "a photo is loading")
        #expect(viewModel.analyze() == nil)
        viewModel.finishPhotoLoad(ticket: ticket, preparedJPEG: photo)
        #expect(viewModel.canAnalyze, "the load finished")

        let task = viewModel.analyze()
        #expect(!viewModel.canAnalyze, "analysis is running")
        await task?.value

        guard case .result = viewModel.phase else {
            Issue.record("Expected a result after the analysis")
            return
        }
        #expect(!viewModel.canAnalyze, "a result is showing")

        viewModel.editInputs()
        #expect(viewModel.canAnalyze, "back to editing with the photo kept")

        viewModel.newPhoto()
        #expect(!viewModel.canAnalyze, "the photo was cleared")
    }

    @Test func aResultCannotBeAnalyzedAgainUntilTheUserGoesBack() async {
        let advisor = StubAdvisor(.success(sampleAdvice()))
        let viewModel = makeViewModel(advisor)
        await viewModel.analyze()?.value
        let showing = viewModel.phase

        #expect(viewModel.analyze() == nil)
        #expect(viewModel.phase == showing)
        #expect(advisor.callCount == 1)
    }

    @Test func cancellingDoesNothingUnlessAnalysisIsRunning() async {
        let viewModel = makeViewModel(StubAdvisor(.success(sampleAdvice())))

        viewModel.cancelAnalysis()
        #expect(viewModel.phase == .composing)
        #expect(viewModel.hasPhoto)

        await viewModel.analyze()?.value
        let showing = viewModel.phase
        viewModel.cancelAnalysis()
        #expect(viewModel.phase == showing, "cancelling must not discard a finished result")
    }

    @Test func resettingWhenThereIsNothingToResetIsHarmless() {
        let viewModel = makeViewModel(StubAdvisor(.success(sampleAdvice())), withPhoto: false)

        viewModel.removePhoto()
        viewModel.newPhoto()
        viewModel.editInputs()
        viewModel.cancelAnalysis()

        #expect(viewModel.phase == .composing)
        #expect(!viewModel.hasPhoto)
        #expect(viewModel.notice == nil)
        #expect(!viewModel.isLoadingPhoto)
        #expect(viewModel.goalText.isEmpty)
    }

    // MARK: What the advisor is given

    @Test func theAdvisorOnlyEverSeesACleanGoal() async {
        let cases: [(typed: String, expected: String?)] = [
            ("Job interview", "Job interview"),
            ("  Job \n interview ", "Job interview"),
            ("", nil),
            ("   \n", nil),
            ("\u{200B}", nil),
            ("\u{E0041}", nil),
            (String(repeating: "x", count: 500), String(repeating: "x", count: StyleGoal.maxLength)),
        ]
        for (typed, expected) in cases {
            let advisor = StubAdvisor(.success(sampleAdvice()))
            let viewModel = makeViewModel(advisor)
            viewModel.goalText = typed

            await viewModel.analyze()?.value

            #expect(advisor.callCount == 1, "\(scalars(String(typed.prefix(8)))) should still be analyzed")
            #expect(advisor.lastGoal?.text == expected, "\(scalars(String(typed.prefix(8)))) should reach the advisor as \(expected ?? "no goal")")
        }
    }

    @Test func theAdvisorGetsExactlyThePreparedPhoto() async {
        let advisor = StubAdvisor(.success(sampleAdvice()))
        let viewModel = makeViewModel(advisor)

        await viewModel.analyze()?.value

        #expect(advisor.lastPhoto == photo)
    }

    @Test func editingTheGoalAfterTappingDoesNotChangeWhatWasSent() async {
        let advisor = GatedAdvisor()
        let viewModel = makeViewModel(advisor)
        viewModel.goalText = "slow"

        let task = viewModel.analyze()
        viewModel.goalText = "something else entirely"
        advisor.release()
        await task?.value

        guard case .result(let advice) = viewModel.phase else {
            Issue.record("Expected a result")
            return
        }
        #expect(advice.summary == "answer for slow", "the goal is captured when the analysis starts")
    }

    // MARK: Notices

    @Test func aNoticeLastsUntilTheUserMovesOn() async {
        let advisor = StubAdvisor(.failure(OutfitAdviceError.unusableResponse))
        let viewModel = makeViewModel(advisor)

        await viewModel.analyze()?.value
        #expect(viewModel.notice?.message == OutfitAdviceViewModel.unusableAdviceMessage)
        #expect(viewModel.canAnalyze, "a failure leaves retrying one tap away")

        // Retrying clears the notice, and a success then shows the result.
        advisor.outcome = .success(sampleAdvice())
        await viewModel.analyze()?.value
        #expect(viewModel.notice == nil)
        guard case .result = viewModel.phase else {
            Issue.record("Expected a result after the retry")
            return
        }
    }

    @Test func aNoticeIsClearedByChoosingANewPhoto() async {
        let viewModel = makeViewModel(StubAdvisor(.failure(OutfitAdviceError.unusableResponse)))
        await viewModel.analyze()?.value
        #expect(viewModel.notice != nil)

        viewModel.setPhoto(preparedJPEG: photo)
        #expect(viewModel.notice == nil)
    }

    @Test func aNoticeIsClearedByRemovingThePhoto() async {
        let viewModel = makeViewModel(StubAdvisor(.failure(OutfitAdviceError.unusableResponse)))
        await viewModel.analyze()?.value
        #expect(viewModel.notice != nil)

        viewModel.removePhoto()
        #expect(viewModel.notice == nil)
    }

    // MARK: Races

    @Test func anAdvisorThatIgnoresCancellationCannotOverrideTheUsersChoice() async {
        let advisor = StubAdvisor(.success(sampleAdvice(summary: "late")))
        let viewModel = makeViewModel(advisor)

        let task = viewModel.analyze()
        viewModel.cancelAnalysis()   // before the task has even started
        await task?.value

        #expect(advisor.callCount == 1, "the advisor was reached and answered anyway")
        #expect(viewModel.phase == .composing, "but its answer must be dropped")
        #expect(viewModel.notice == nil)
    }

    @Test func aSupersededAnalysisCannotOverwriteANewerOneThatFinishedFirst() async {
        let advisor = GatedAdvisor()
        let viewModel = makeViewModel(advisor)

        viewModel.goalText = "slow"
        let first = viewModel.analyze()
        viewModel.cancelAnalysis()

        viewModel.goalText = "fast"
        let second = viewModel.analyze()

        await second?.value     // the newer analysis finishes while the first is still waiting
        advisor.release()       // now the first finishes, late
        await first?.value

        guard case .result(let advice) = viewModel.phase else {
            Issue.record("Expected a result")
            return
        }
        #expect(advice.summary == "answer for fast", "a late answer from a cancelled analysis must not win")
        #expect(advisor.callCount == 2)
    }

    @Test func aLateFailureFromACancelledAnalysisShowsNothing() async {
        let viewModel = makeViewModel(StubAdvisor(.failure(URLError(.timedOut))))

        let task = viewModel.analyze()
        viewModel.cancelAnalysis()
        await task?.value

        #expect(viewModel.phase == .composing)
        #expect(viewModel.notice == nil, "the user backed out, so no error should appear")
    }
}

/// The message a person sees for each way the request can go wrong.
@MainActor
@Suite("Error message validation")
struct ErrorMessageValidationTests {

    private struct NoticeCase {
        let name: String
        let error: Error
        let kind: OutfitAdviceViewModel.Notice.Kind
        let message: String
    }

    private var noticeCases: [NoticeCase] {
        let unusable = OutfitAdviceViewModel.unusableAdviceMessage
        var list: [NoticeCase] = [
            NoticeCase(name: "no outfit, with a tip", error: OutfitAdviceError.noOutfitVisible(tip: "Step back."), kind: .photoTip, message: "Step back."),
            NoticeCase(name: "no outfit, no tip", error: OutfitAdviceError.noOutfitVisible(tip: nil), kind: .photoTip, message: OutfitAdviceViewModel.noOutfitMessage),
            NoticeCase(name: "nothing usable in the answer", error: OutfitAdviceError.unusableResponse, kind: .error, message: unusable),
            NoticeCase(name: "an unreadable answer from the service", error: BackendAPIClient.APIError.invalidResponse, kind: .error, message: unusable),
            NoticeCase(name: "a missing API key", error: BackendAPIClient.APIError.noAPIKey, kind: .error, message: BackendAPIClient.APIError.noAPIKey.localizedDescription),
            NoticeCase(name: "an HTTP error", error: BackendAPIClient.APIError.httpError(503), kind: .error, message: "API error (HTTP 503)."),
            NoticeCase(name: "a message from the service", error: BackendAPIClient.APIError.serverError("Rate limit reached"), kind: .error, message: "Rate limit reached"),
        ]

        let offline: [URLError.Code] = [.notConnectedToInternet, .networkConnectionLost, .dataNotAllowed]
        for code in offline {
            list.append(NoticeCase(name: "offline (\(code.rawValue))", error: URLError(code), kind: .error, message: OutfitAdviceViewModel.offlineMessage))
        }
        list.append(NoticeCase(name: "a timeout", error: URLError(.timedOut), kind: .error, message: OutfitAdviceViewModel.timedOutMessage))

        // Other network failures say what the system says.
        let other: [URLError.Code] = [.cannotFindHost, .cannotConnectToHost, .badServerResponse, .secureConnectionFailed, .cancelled]
        for code in other {
            list.append(NoticeCase(name: "network error \(code.rawValue)", error: URLError(code), kind: .error, message: URLError(code).localizedDescription))
        }

        let generic = NSError(domain: "FashionTests", code: 7, userInfo: [NSLocalizedDescriptionKey: "Something specific broke."])
        list.append(NoticeCase(name: "any other error", error: generic, kind: .error, message: "Something specific broke."))
        return list
    }

    @Test func everyFailureHasTheRightKindAndMessage() {
        for noticeCase in noticeCases {
            let notice = OutfitAdviceViewModel.makeNotice(for: noticeCase.error)
            #expect(notice.kind == noticeCase.kind, "\(noticeCase.name): wrong kind")
            #expect(notice.message == noticeCase.message, "\(noticeCase.name): wrong message")
        }
    }

    @Test func noMessageIsEverBlank() {
        for noticeCase in noticeCases {
            let message = OutfitAdviceViewModel.makeNotice(for: noticeCase.error).message
            #expect(!message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "\(noticeCase.name) produced a blank message")
        }
    }

    @Test func noMessageLeaksDeveloperLanguage() {
        // Failures a person can hit in normal use must not read like a stack trace.
        let userFacing: [Error] = [
            OutfitAdviceError.unusableResponse,
            OutfitAdviceError.noOutfitVisible(tip: nil),
            BackendAPIClient.APIError.invalidResponse,
            URLError(.notConnectedToInternet),
            URLError(.timedOut),
        ]
        for error in userFacing {
            let message = OutfitAdviceViewModel.makeNotice(for: error).message
            for word in ["parse", "JSON", "HTTP", "nil", "error code"] {
                #expect(!message.contains(word), "\"\(message)\" contains the developer term \"\(word)\"")
            }
        }
    }

    @Test func theOfflineMessageReassuresThatNothingWasLost() {
        let message = OutfitAdviceViewModel.makeNotice(for: URLError(.notConnectedToInternet)).message
        #expect(message.contains("still here"))
    }
}
