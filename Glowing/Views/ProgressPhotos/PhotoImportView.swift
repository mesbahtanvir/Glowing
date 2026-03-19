import SwiftUI
import SwiftData
import PhotosUI
import ImageIO

// MARK: - Shared Import Helpers

private struct ImportedPhoto: Identifiable {
    let id = UUID()
    var angle: PhotoAngle
    var imageData: Data
    var image: UIImage
    var exifDate: Date?
}

private func extractExifDate(from data: Data) -> Date? {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
    guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else { return nil }

    if let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any],
       let dateString = exif[kCGImagePropertyExifDateTimeOriginal as String] as? String {
        return parseExifDate(dateString)
    }

    if let tiff = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any],
       let dateString = tiff[kCGImagePropertyTIFFDateTime as String] as? String {
        return parseExifDate(dateString)
    }

    return nil
}

private func parseExifDate(_ string: String) -> Date? {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return formatter.date(from: string)
}

private func downsample(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
    let size = image.size
    let longestSide = max(size.width, size.height)
    guard longestSide > maxDimension else { return image }

    let scale = maxDimension / longestSide
    let newSize = CGSize(width: size.width * scale, height: size.height * scale)

    let renderer = UIGraphicsImageRenderer(size: newSize)
    return renderer.image { _ in
        image.draw(in: CGRect(origin: .zero, size: newSize))
    }
}

// MARK: - Face Photo Import

struct FacePhotoImportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var photos: [ImportedPhoto] = []
    @State private var isLoading = false
    @State private var sessionDate: Date = Date()

    var body: some View {
        NavigationStack {
            Group {
                if photos.isEmpty {
                    emptyState
                } else {
                    reviewContent
                }
            }
            .navigationTitle("Import Face Photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                if !photos.isEmpty {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { saveSession() }
                            .fontWeight(.semibold)
                    }
                }
            }
            .overlay {
                if isLoading {
                    ZStack {
                        Color.black.opacity(0.3).ignoresSafeArea()
                        ProgressView("Loading photos...")
                            .padding(24)
                            .background(.regularMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .onChange(of: pickerItems) { loadPhotos() }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 24) {
            Image(systemName: "face.smiling")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text("Import Face Photos")
                    .font(.title3)
                    .fontWeight(.bold)

                Text("Select up to 3 photos from your library — front, left, and right angles. The date is read from each photo to build your timeline.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
            }

            PhotosPicker(
                selection: $pickerItems,
                maxSelectionCount: 3,
                matching: .images
            ) {
                Label("Choose Photos", systemImage: "photo.badge.plus")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var reviewContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Date
                dateSection

                // Photos
                VStack(alignment: .leading, spacing: 12) {
                    Text("Assign Angles")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)

                    Text("Tap each label to change its angle.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal)

                    ForEach($photos) { $photo in
                        facePhotoRow(photo: $photo)
                    }
                }

                if photos.count < 3 {
                    PhotosPicker(
                        selection: $pickerItems,
                        maxSelectionCount: 3,
                        matching: .images
                    ) {
                        Label("Add More", systemImage: "plus.circle")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .padding(.top, 8)
                }

                Spacer(minLength: 32)
            }
            .padding(.top, 8)
        }
    }

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Session Date")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            DatePicker("Date", selection: $sessionDate, in: ...Date(), displayedComponents: .date)
                .labelsHidden()

            if let earliest = photos.compactMap(\.exifDate).min() {
                Text("Detected from photo: \(earliest.formatted(.dateTime.month(.abbreviated).day().year()))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal)
    }

    private func facePhotoRow(photo: Binding<ImportedPhoto>) -> some View {
        HStack(spacing: 12) {
            Image(uiImage: photo.wrappedValue.image)
                .resizable()
                .scaledToFill()
                .frame(width: 80, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 6) {
                Menu {
                    ForEach(PhotoAngle.faceAngles, id: \.self) { angle in
                        Button {
                            photo.wrappedValue.angle = angle
                        } label: {
                            Label(angle.displayName, systemImage: angle.icon)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: photo.wrappedValue.angle.icon)
                            .font(.caption)
                        Text(photo.wrappedValue.angle.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .tint(.primary)

                if let date = photo.wrappedValue.exifDate {
                    Text("Taken: \(date.formatted(.dateTime.month(.abbreviated).day().year().hour().minute()))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No date info")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Button {
                photos.removeAll { $0.id == photo.wrappedValue.id }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private func loadPhotos() {
        guard !pickerItems.isEmpty else { return }
        isLoading = true

        Task {
            var loaded: [ImportedPhoto] = []
            let defaultAngles: [PhotoAngle] = [.front, .left, .right]

            for (index, item) in pickerItems.enumerated() {
                guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
                let exifDate = extractExifDate(from: data)
                guard let uiImage = UIImage(data: data) else { continue }
                let scaled = downsample(uiImage, maxDimension: 1200)
                guard let jpegData = scaled.jpegData(compressionQuality: 0.8) else { continue }

                let angle = index < defaultAngles.count ? defaultAngles[index] : .front
                loaded.append(ImportedPhoto(angle: angle, imageData: jpegData, image: scaled, exifDate: exifDate))
            }

            await MainActor.run {
                photos = loaded
                if let earliest = loaded.compactMap(\.exifDate).min() {
                    sessionDate = earliest
                }
                isLoading = false
            }
        }
    }

    private func saveSession() {
        let sessionID = UUID()
        var savedPhotos: [ProgressPhoto] = []

        for imported in photos {
            let photo = ProgressPhoto(
                angle: imported.angle,
                imageData: imported.imageData,
                sessionID: sessionID,
                capturedAt: sessionDate
            )
            modelContext.insert(photo)
            savedPhotos.append(photo)
        }

        let faceCount = savedPhotos.count
        let manager = SkinAnalysisManager.shared
        if manager.shouldAutoAnalyze && faceCount >= 3 {
            let sid = sessionID
            let context = modelContext
            Task {
                await manager.analyzeSession(
                    sessionID: sid,
                    photos: savedPhotos,
                    modelContext: context
                )
            }
        }

        dismiss()
    }
}

// BodyPhotoImportView removed — body analysis is no longer supported
