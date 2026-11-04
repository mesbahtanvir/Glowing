import Foundation
import Observation
import UIKit

/// Whatever turns an outfit photo into advice: the real backend, or a direct call to the AI service in debug builds.
/// A protocol so the view model can be tested without a network.
protocol OutfitAdvising {
    func adviseOnOutfit(photoJPEG: Data, goal: StyleGoal?) async throws -> OutfitAdvice
}

/// Drives the Style screen: pick a photo, say what you're going for, get advice.
///
/// Failures never throw the user's input away. The photo and goal stay put, with a short inline notice,
/// so trying again is one tap.
@MainActor
@Observable
final class OutfitAdviceViewModel {

    enum Phase: Equatable {
        /// Choosing a photo and a goal.
        case composing
        /// Waiting on the advice.
        case analyzing
        case result(OutfitAdvice)
    }

    /// A short inline message shown while composing.
    struct Notice: Equatable {
        enum Kind {
            /// Gentle guidance about the photo itself.
            case photoTip
            case error
        }

        let kind: Kind
        let message: String
    }

    private(set) var phase: Phase = .composing
    /// The prepared JPEG that will be sent. Set together with `previewImage`.
    private(set) var photoJPEG: Data?
    /// The same photo, decoded once for display.
    private(set) var previewImage: UIImage?
    private(set) var notice: Notice?

    /// The goal as typed. Bound to the text field.
    var goalText: String = ""

    private let advisor: any OutfitAdvising
    @ObservationIgnored private var analysisTask: Task<Void, Never>?

    init(advisor: any OutfitAdvising = BackendAPIClient.shared) {
        self.advisor = advisor
    }

    // MARK: - Derived

    /// The goal, if the text holds anything meaningful.
    var goal: StyleGoal? { StyleGoal(goalText) }

    var hasPhoto: Bool { photoJPEG != nil }

    var canAnalyze: Bool { hasPhoto && phase == .composing }

    // MARK: - Photo

    /// Accepts a photo that has already been through `OutfitImagePreparer`.
    func setPhoto(preparedJPEG data: Data) {
        guard let image = UIImage(data: data) else {
            notice = Notice(kind: .error, message: Self.unreadablePhotoMessage)
            return
        }
        photoJPEG = data
        previewImage = image
        notice = nil
    }

    /// Accepts a photo straight from the camera or library: shrinks it off the main thread, then sets it.
    func loadPhoto(rawData: Data) async {
        let prepared = await Task.detached(priority: .userInitiated) {
            OutfitImagePreparer.prepareJPEG(from: rawData)
        }.value

        guard let prepared else {
            notice = Notice(kind: .error, message: Self.unreadablePhotoMessage)
            return
        }
        setPhoto(preparedJPEG: prepared)
    }

    /// For when a photo was chosen but couldn't be read at all.
    func reportPhotoFailure() {
        notice = Notice(kind: .error, message: Self.unreadablePhotoMessage)
    }

    func removePhoto() {
        photoJPEG = nil
        previewImage = nil
        notice = nil
    }

    // MARK: - Analysis

    /// Starts the analysis. Returns the running task so callers (tests) can await it; the UI ignores it.
    @discardableResult
    func analyze() -> Task<Void, Never>? {
        guard canAnalyze, let photo = photoJPEG else { return nil }

        notice = nil
        phase = .analyzing

        let goal = self.goal
        let task = Task { await self.runAnalysis(photo: photo, goal: goal) }
        analysisTask = task
        return task
    }

    /// Backs out of an analysis in progress. Photo and goal are kept, and no error is shown.
    func cancelAnalysis() {
        guard phase == .analyzing else { return }
        analysisTask?.cancel()
        analysisTask = nil
        phase = .composing
    }

    private func runAnalysis(photo: Data, goal: StyleGoal?) async {
        do {
            let advice = try await advisor.adviseOnOutfit(photoJPEG: photo, goal: goal)
            // The user may have backed out while we waited; their choice wins.
            guard !Task.isCancelled else { return }
            phase = .result(advice)
        } catch {
            guard !Task.isCancelled else { return }
            phase = .composing
            notice = Self.makeNotice(for: error)
        }
    }

    // MARK: - After a result

    /// "Check another look": clears the photo, keeps the goal (it usually stays the same between attempts).
    func newPhoto() {
        analysisTask?.cancel()
        analysisTask = nil
        phase = .composing
        removePhoto()
    }

    /// "Change goal": back to the inputs with the photo and goal intact.
    func editInputs() {
        phase = .composing
        notice = nil
    }

    // MARK: - Messages

    static let unreadablePhotoMessage = "That photo couldn't be opened. Try a different one."

    /// Turns an error into something calm and actionable.
    static func makeNotice(for error: Error) -> Notice {
        if let adviceError = error as? OutfitAdviceError {
            switch adviceError {
            case .noOutfitVisible(let tip):
                return Notice(
                    kind: .photoTip,
                    message: tip ?? "We couldn't see an outfit in this photo. Try one where your whole look is in frame."
                )
            case .unusableResponse:
                return Notice(kind: .error, message: "We couldn't put together advice this time. Please try again.")
            }
        }

        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
                return Notice(
                    kind: .error,
                    message: "You appear to be offline. Your photo is still here, so you can try again when you're connected."
                )
            case .timedOut:
                return Notice(kind: .error, message: "That took longer than expected. Please try again in a moment.")
            default:
                break
            }
        }

        return Notice(kind: .error, message: error.localizedDescription)
    }
}
