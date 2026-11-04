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
    /// True while a photo is being fetched or shrunk. Analysis waits for it, so the photo on screen
    /// is the photo that gets analysed.
    private(set) var isLoadingPhoto = false

    /// The goal as typed. Bound to the text field.
    var goalText: String = ""

    private let advisor: any OutfitAdvising
    @ObservationIgnored private var analysisTask: Task<Void, Never>?
    /// Bumped whenever a photo load starts or is abandoned, so a slow load that has been
    /// superseded can't land late and overwrite newer state.
    @ObservationIgnored private var photoLoadTicket = 0

    init(advisor: any OutfitAdvising = BackendAPIClient.shared) {
        self.advisor = advisor
    }

    // MARK: - Derived

    /// The goal, if the text holds anything meaningful.
    var goal: StyleGoal? { StyleGoal(goalText) }

    var hasPhoto: Bool { photoJPEG != nil }

    var canAnalyze: Bool { hasPhoto && !isLoadingPhoto && phase == .composing }

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

    /// Loads a photo from the camera or library. `fetch` returns the raw image data, or nil if it couldn't be
    /// read, and may be slow (an iCloud download, say). The data is then shrunk off the main thread.
    /// If the current photo can't be replaced, it is kept and a short notice explains.
    func loadPhoto(fetch: () async -> Data?) async {
        let ticket = beginPhotoLoad()

        var prepared: Data?
        if let raw = await fetch() {
            prepared = await Task.detached(priority: .userInitiated) {
                OutfitImagePreparer.prepareJPEG(from: raw)
            }.value
        }

        finishPhotoLoad(ticket: ticket, preparedJPEG: prepared)
    }

    /// Marks the start of a photo load and returns its ticket.
    func beginPhotoLoad() -> Int {
        photoLoadTicket += 1
        isLoadingPhoto = true
        notice = nil
        return photoLoadTicket
    }

    /// Applies the outcome of a photo load, unless something newer has happened since `beginPhotoLoad`:
    /// another load started, the photo was removed, or analysis began. `preparedJPEG` is nil when the
    /// photo couldn't be read.
    func finishPhotoLoad(ticket: Int, preparedJPEG: Data?) {
        guard ticket == photoLoadTicket else { return }
        isLoadingPhoto = false
        // Once analysis has started, the photo being analysed stays put.
        guard phase == .composing else { return }

        guard let preparedJPEG else {
            notice = Notice(kind: .error, message: Self.unreadablePhotoMessage)
            return
        }
        setPhoto(preparedJPEG: preparedJPEG)
    }

    func removePhoto() {
        abandonPhotoLoad()
        photoJPEG = nil
        previewImage = nil
        notice = nil
    }

    /// Makes any load still in flight stale.
    private func abandonPhotoLoad() {
        photoLoadTicket += 1
        isLoadingPhoto = false
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
