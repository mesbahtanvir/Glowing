import SwiftUI
import PhotosUI
import UIKit

/// The Style tab: add a photo of your outfit, say what you're going for, get advice.
struct StyleView: View {
    @State private var viewModel = OutfitAdviceViewModel()
    @State private var showCamera = false
    @State private var showLibrary = false
    @State private var pickerItem: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Style")
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraCaptureView(
                onCapture: { image in
                    showCamera = false
                    handleCaptured(image)
                },
                onCancel: { showCamera = false }
            )
            .ignoresSafeArea()
        }
        .photosPicker(isPresented: $showLibrary, selection: $pickerItem, matching: .images)
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task { await loadPickedPhoto(item) }
        }
        // A light confirmation when advice arrives, for people who looked away while it loaded.
        .sensoryFeedback(trigger: viewModel.phase) { _, newPhase in
            if case .result = newPhase { return .success }
            return nil
        }
    }

    // MARK: - Phases

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .composing:
            composeContent
        case .analyzing:
            analyzingContent
        case .result(let advice):
            OutfitAdviceResultView(
                advice: advice,
                photo: viewModel.previewImage,
                goal: viewModel.goal,
                onNewPhoto: { viewModel.newPhoto() },
                onEditGoal: { viewModel.editInputs() }
            )
        }
    }

    // MARK: - Compose

    private var composeContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                photoSection
                goalSection

                if let notice = viewModel.notice {
                    noticeView(notice)
                }

                Text("Your photo is sent to our AI service to generate advice, and isn't saved on your device.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            analyzeBar
        }
    }

    @ViewBuilder
    private var photoSection: some View {
        if viewModel.isLoadingPhoto {
            photoLoading
        } else if let image = viewModel.previewImage {
            VStack(spacing: 10) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 420)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .accessibilityLabel("Your outfit photo")

                Menu {
                    if CameraCaptureView.isAvailable {
                        Button {
                            showCamera = true
                        } label: {
                            Label("Take a New Photo", systemImage: "camera")
                        }
                    }
                    Button {
                        showLibrary = true
                    } label: {
                        Label("Choose from Library", systemImage: "photo.on.rectangle")
                    }
                    Button(role: .destructive) {
                        viewModel.removePhoto()
                    } label: {
                        Label("Remove Photo", systemImage: "trash")
                    }
                } label: {
                    Label("Change Photo", systemImage: "arrow.triangle.2.circlepath")
                        .font(.subheadline)
                }
            }
        } else {
            photoPlaceholder
        }
    }

    /// Shown while a photo is fetched, which can take a few seconds for photos stored in iCloud.
    private var photoLoading: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Opening your photo...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 56)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }

    private var photoPlaceholder: some View {
        VStack(spacing: 16) {
            Image(systemName: "tshirt")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.teal)

            VStack(spacing: 6) {
                Text("Add your look")
                    .font(.headline)
                Text("Take or upload a photo of your outfit. Head-to-toe in good light works best.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 12) {
                if CameraCaptureView.isAvailable {
                    Button {
                        showCamera = true
                    } label: {
                        Label("Take Photo", systemImage: "camera")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }

                Button {
                    showLibrary = true
                } label: {
                    Label("Choose Photo", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .tint(.teal)
            .controlSize(.large)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var goalSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("What's your goal for this look?")
                .font(.subheadline.weight(.semibold))

            TextField("e.g. Look polished for a job interview", text: $viewModel.goalText, axis: .vertical)
                .lineLimit(1...3)
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .onChange(of: viewModel.goalText) { _, text in
                    if text.count > StyleGoal.maxLength {
                        viewModel.goalText = String(text.prefix(StyleGoal.maxLength))
                    }
                }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(StyleGoal.suggestions, id: \.self) { suggestion in
                        suggestionChip(suggestion)
                    }
                }
            }

            Text("Optional. Without one, we'll go by the style you seem to be aiming for.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func suggestionChip(_ label: String) -> some View {
        let isSelected = viewModel.goalText == label
        return Button {
            viewModel.goalText = label
        } label: {
            Text(label)
                .font(.footnote.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .foregroundStyle(isSelected ? Color.teal : Color.primary)
                .background(isSelected ? Color.teal.opacity(0.18) : Color(.secondarySystemGroupedBackground))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func noticeView(_ notice: OutfitAdviceViewModel.Notice) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: notice.kind == .photoTip ? "camera.viewfinder" : "exclamationmark.circle")
                .foregroundStyle(notice.kind == .photoTip ? Color.teal : Color.orange)
            Text(notice.message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }

    private var analyzeBar: some View {
        Button {
            _ = viewModel.analyze()
        } label: {
            Text(viewModel.goal == nil ? "Get General Advice" : "Get Advice")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .tint(.teal)
        .controlSize(.large)
        .disabled(!viewModel.canAnalyze)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    // MARK: - Analyzing

    private var analyzingContent: some View {
        VStack(spacing: 24) {
            Spacer()

            GlowingBubbleView(
                message: "Reading your look",
                submessage: viewModel.goal == nil
                    ? "Looking at color, proportion, fit, and the style you're going for."
                    : "Looking at color, proportion, fit, and how it matches your goal.",
                accentColor: .teal
            )

            Spacer()

            Button("Cancel") {
                viewModel.cancelAnalysis()
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    // MARK: - Photo Intake

    private func handleCaptured(_ image: UIImage) {
        Task {
            await viewModel.loadPhoto { image.jpegData(compressionQuality: 0.9) }
        }
    }

    private func loadPickedPhoto(_ item: PhotosPickerItem) async {
        // Clear the selection afterwards so picking the same photo again still registers.
        defer { pickerItem = nil }

        await viewModel.loadPhoto { try? await item.loadTransferable(type: Data.self) }
    }
}

#Preview {
    StyleView()
}
