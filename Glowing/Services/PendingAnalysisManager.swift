import Foundation
import SwiftUI
import SwiftData

/// Manages background image analysis so the user isn't blocked during onboarding.
/// Persists captured photos to disk so analysis survives app termination.
/// On next launch, detects saved photos and restarts the analysis automatically.
@MainActor
@Observable
final class PendingAnalysisManager {
    static let shared = PendingAnalysisManager()

    enum State: Equatable {
        case idle
        case analyzing
        case readyForReview
        case complete
    }

    var state: State = .idle
    var imageAnalysisVM: ImageAnalysisViewModel?
    var capturedPhotos: [PhotoAngle: Data] = [:]

    private init() {}

    private var pollTask: Task<Void, Never>?

    // MARK: - Persistence

    private static var pendingDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PendingAnalysis", isDirectory: true)
    }

    /// Save captured photos to disk so they survive app termination.
    private func persistPhotos() {
        let dir = Self.pendingDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for (angle, data) in capturedPhotos {
            let url = dir.appendingPathComponent("\(angle.rawValue).jpg")
            try? data.write(to: url)
        }
    }

    /// Load previously persisted photos from disk.
    private static func loadPersistedPhotos() -> [PhotoAngle: Data]? {
        let dir = pendingDirectory
        guard FileManager.default.fileExists(atPath: dir.path()) else { return nil }

        var photos: [PhotoAngle: Data] = [:]
        for angle in PhotoAngle.allCases {
            let url = dir.appendingPathComponent("\(angle.rawValue).jpg")
            if let data = try? Data(contentsOf: url) {
                photos[angle] = data
            }
        }
        // Need at least front photo to be valid
        guard photos[.front] != nil else { return nil }
        return photos
    }

    /// Remove persisted photos from disk.
    private static func clearPersistedPhotos() {
        try? FileManager.default.removeItem(at: pendingDirectory)
    }

    /// Check if there are persisted photos from a previous session.
    static var hasPendingPhotos: Bool {
        FileManager.default.fileExists(atPath: pendingDirectory.appendingPathComponent("front.jpg").path())
    }

    // MARK: - Hand Off

    /// Hand off an in-progress analysis to the background manager.
    /// Persists photos to disk in case the app is terminated.
    func handOff(vm: ImageAnalysisViewModel, photos: [PhotoAngle: Data]) {
        imageAnalysisVM = vm
        capturedPhotos = photos
        state = .analyzing
        persistPhotos()
        startPolling()
    }

    // MARK: - Resume on Launch

    /// Called on app launch. If photos were persisted from a previous session,
    /// restarts the analysis from scratch.
    func resumeIfNeeded() {
        guard state == .idle,
              let photos = Self.loadPersistedPhotos() else { return }

        capturedPhotos = photos
        let vm = ImageAnalysisViewModel()
        imageAnalysisVM = vm
        state = .analyzing
        vm.startFromExistingPhotos(photos)
        startPolling()
    }

    // MARK: - Polling

    /// Poll the VM's flowState until extraction completes.
    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task {
            while !Task.isCancelled {
                if let vm = imageAnalysisVM {
                    if vm.flowState == .reviewingDetails {
                        state = .readyForReview
                        return
                    } else if vm.error != nil {
                        state = .readyForReview
                        return
                    }
                }
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }

    // MARK: - Completion

    /// Mark analysis as complete and clean up persisted data.
    func markComplete() {
        pollTask?.cancel()
        Self.clearPersistedPhotos()
        state = .complete
        Task {
            try? await Task.sleep(for: .milliseconds(500))
            state = .idle
            imageAnalysisVM = nil
            capturedPhotos = [:]
        }
    }

    /// Reset without completing (e.g., user wants to redo).
    func reset() {
        pollTask?.cancel()
        Self.clearPersistedPhotos()
        state = .idle
        imageAnalysisVM = nil
        capturedPhotos = [:]
    }
}
