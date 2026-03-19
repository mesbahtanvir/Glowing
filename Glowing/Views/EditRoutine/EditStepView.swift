import SwiftUI
import PhotosUI

struct EditableDayVariant: Identifiable, Equatable {
    let id: UUID
    var weekday: Int  // 1=Sun, 2=Mon, ... 7=Sat
    var productName: String
    var notes: String
    var skip: Bool

    init(id: UUID = UUID(), weekday: Int, productName: String = "", notes: String = "", skip: Bool = false) {
        self.id = id
        self.weekday = weekday
        self.productName = productName
        self.notes = notes
        self.skip = skip
    }
}

struct EditableStep: Identifiable, Equatable {
    let id: UUID
    var title: String
    var productName: String
    var notes: String
    var imageData: Data?
    var timerDuration: Int?
    var dayVariants: [EditableDayVariant]

    var hasTimer: Bool {
        get { timerDuration != nil }
        set { timerDuration = newValue ? 60 : nil }
    }

    var hasDayVariants: Bool {
        get { !dayVariants.isEmpty }
        set {
            if newValue && dayVariants.isEmpty {
                // Add all 7 days with empty defaults
                dayVariants = (1...7).map { EditableDayVariant(weekday: $0) }
            } else if !newValue {
                dayVariants = []
            }
        }
    }

    init(id: UUID = UUID(), title: String = "", productName: String = "", notes: String = "", imageData: Data? = nil, timerDuration: Int? = nil, dayVariants: [EditableDayVariant] = []) {
        self.id = id
        self.title = title
        self.productName = productName
        self.notes = notes
        self.imageData = imageData
        self.timerDuration = timerDuration
        self.dayVariants = dayVariants
    }
}

struct EditStepView: View {
    @Binding var step: EditableStep
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPhoto: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            Form {
                Section("Step Details") {
                    TextField("Step Title", text: $step.title)

                    TextField("Product Name", text: $step.productName, prompt: Text("e.g. CeraVe Foaming Cleanser"))

                    VStack(alignment: .leading) {
                        Text("Notes")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextEditor(text: $step.notes)
                            .frame(minHeight: 80)
                    }
                }

                Section {
                    Toggle("Varies by Day", isOn: $step.hasDayVariants)

                    if step.hasDayVariants {
                        ForEach($step.dayVariants) { $variant in
                            DayVariantRow(variant: $variant, defaultProductName: step.productName)
                        }
                    }
                } header: {
                    Text("Day-Specific Overrides")
                } footer: {
                    if step.hasDayVariants {
                        Text("Override the product or notes for specific days. Toggle skip to hide this step on that day.")
                    }
                }

                Section("Photo") {
                    if let imageData = step.imageData,
                       let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        Button("Remove Photo", role: .destructive) {
                            step.imageData = nil
                            selectedPhoto = nil
                        }
                    }

                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label(step.imageData == nil ? "Add Photo" : "Change Photo", systemImage: "photo")
                    }
                }

                Section("Timer") {
                    Toggle("Wait Timer", isOn: $step.hasTimer)

                    if let duration = step.timerDuration {
                        HStack {
                            Text("Duration")
                            Spacer()
                            Text(formatDuration(duration))
                                .foregroundStyle(.secondary)
                        }

                        Stepper(
                            "Minutes: \(duration / 60)",
                            value: Binding(
                                get: { duration / 60 },
                                set: { step.timerDuration = $0 * 60 + (duration % 60) }
                            ),
                            in: 0...30
                        )

                        Stepper(
                            "Seconds: \(duration % 60)",
                            value: Binding(
                                get: { duration % 60 },
                                set: { step.timerDuration = (duration / 60) * 60 + $0 }
                            ),
                            in: 0...59,
                            step: 5
                        )
                    }
                }
            }
            .navigationTitle("Edit Step")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onChange(of: selectedPhoto) { _, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self) {
                        step.imageData = data
                    }
                }
            }
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        if mins > 0 && secs > 0 {
            return "\(mins) min \(secs)s"
        } else if mins > 0 {
            return "\(mins) min"
        } else {
            return "\(secs)s"
        }
    }
}

// MARK: - Day Variant Row

private struct DayVariantRow: View {
    @Binding var variant: EditableDayVariant
    let defaultProductName: String

    var body: some View {
        DisclosureGroup {
            if !variant.skip {
                TextField(
                    "Product Name",
                    text: $variant.productName,
                    prompt: Text(defaultProductName.isEmpty ? "Same as default" : defaultProductName)
                )

                TextField(
                    "Notes",
                    text: $variant.notes,
                    prompt: Text("Override notes for this day")
                )
            }

            Toggle("Skip this day", isOn: $variant.skip)
        } label: {
            HStack {
                Text(StepDayVariant.weekdayName(for: variant.weekday))
                    .fontWeight(.medium)
                    .frame(width: 36, alignment: .leading)

                if variant.skip {
                    Text("Skip")
                        .font(.caption)
                        .foregroundStyle(.red)
                } else if !variant.productName.isEmpty {
                    Text(variant.productName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }
}
