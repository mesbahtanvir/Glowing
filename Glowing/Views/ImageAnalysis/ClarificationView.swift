import SwiftUI

struct ClarificationView: View {
    let question: ClarificationQuestion
    let currentIndex: Int
    let totalCount: Int
    let onAnswer: (String) -> Void
    let onSkip: () -> Void

    @State private var selectedValue: String?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Progress
            HStack(spacing: 4) {
                ForEach(0..<totalCount, id: \.self) { i in
                    Capsule()
                        .fill(i <= currentIndex ? .white : .white.opacity(0.2))
                        .frame(height: 3)
                }
            }
            .padding(.horizontal, 40)

            // Category badge
            HStack(spacing: 6) {
                Image(systemName: question.category.defaultIcon)
                Text(question.category.displayName)
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(question.category.accentColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(question.category.accentColor.opacity(0.15))
            .clipShape(Capsule())

            // Question
            Text(question.question)
                .font(.title3.bold())
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            // Options
            VStack(spacing: 12) {
                ForEach(question.options) { option in
                    optionButton(option)
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            // Skip
            if currentIndex < totalCount - 1 {
                Button {
                    onSkip()
                } label: {
                    Text("Skip remaining questions")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 16)
            }
        }
    }

    private func optionButton(_ option: ClarificationOption) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedValue = option.value
            }
            // Brief delay so user sees selection before advancing
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                onAnswer(option.value)
            }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(option.label)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(option.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                if selectedValue == option.value {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .transition(.scale)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                selectedValue == option.value
                    ? Color.white.opacity(0.15)
                    : Color.white.opacity(0.06)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        selectedValue == option.value ? .white.opacity(0.3) : .clear,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
