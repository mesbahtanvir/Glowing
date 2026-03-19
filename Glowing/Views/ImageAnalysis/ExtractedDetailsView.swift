import SwiftUI

struct ExtractedDetailsView: View {
    let profile: ImageAnalysisProfile
    let hasClarifications: Bool
    let onProceed: () -> Void
    let onOverride: (String, String) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "person.crop.rectangle.stack")
                        .font(.system(size: 40))
                        .foregroundStyle(.white.opacity(0.8))

                    Text("Detected Profile")
                        .font(.title2.bold())
                        .foregroundStyle(.white)

                    Text("Here's what we detected from your photos. Tap any trait to change it.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }
                .padding(.top, 24)

                // Skin Section
                sectionCard(
                    title: "Skin",
                    icon: "face.smiling",
                    color: Category.face.accentColor
                ) {
                    traitRow("Skin Type", value: profile.skinType.displayName, confidence: profile.skinTypeConfidence)
                    traitRow("Acne Prone", value: profile.isAcneProne ? "Yes" : "No", confidence: profile.acneProneConfidence)
                    if profile.hasPigmentation { flagRow("Pigmentation detected") }
                    if profile.hasSensitivity { flagRow("Sensitivity detected") }
                    if profile.hasDehydration { flagRow("Dehydration signs") }
                    if profile.hasSunDamage { flagRow("Sun damage signs") }
                }

                // Hair Section
                sectionCard(
                    title: "Hair",
                    icon: "comb.fill",
                    color: Category.hair.accentColor
                ) {
                    traitRow("Hair Pattern", value: profile.hairPattern.displayName, confidence: profile.hairPatternConfidence)
                    traitRow("Thickness", value: profile.hairThickness.displayName, confidence: profile.hairThicknessConfidence)
                    traitRow("Length", value: profile.hairLength.displayName, confidence: .high)
                    if !profile.scalpConcerns.isEmpty {
                        flagRow("Scalp: \(profile.scalpConcerns.joined(separator: ", "))")
                    }
                }

                // Lips Section
                sectionCard(
                    title: "Lips",
                    icon: "mouth.fill",
                    color: .pink
                ) {
                    traitRow("Condition", value: profile.lipsCondition.displayName, confidence: .high)
                    traitRow("Needs Care", value: profile.needsLipCare ? "Yes" : "No", confidence: .high)
                }

                // Eyebrows Section
                sectionCard(
                    title: "Eyebrows",
                    icon: "eyebrow",
                    color: .brown
                ) {
                    traitRow("Condition", value: profile.eyebrowCondition.displayName, confidence: .high)
                    traitRow("Needs Grooming", value: profile.needsEyebrowGrooming ? "Yes" : "No", confidence: .high)
                }

                // Facial Hair Section
                sectionCard(
                    title: "Facial Hair",
                    icon: "mustache.fill",
                    color: Category.stubble.accentColor
                ) {
                    traitRow("Status", value: profile.facialHairStatus.displayName, confidence: profile.facialHairStatusConfidence)
                    traitRow("Growth Pattern", value: profile.beardGrowthPattern.displayName, confidence: profile.beardGrowthPatternConfidence)
                    if let canGrow = profile.canGrowFullBeard {
                        traitRow("Full Beard Potential", value: canGrow ? "Yes" : "No", confidence: .medium)
                    }
                    if !profile.beardRecommendation.isEmpty {
                        recommendationRow(profile.beardRecommendation)
                    }
                }

                // Face Shape
                sectionCard(
                    title: "Face",
                    icon: "face.dashed",
                    color: .cyan
                ) {
                    traitRow("Face Shape", value: profile.faceShape.capitalized, confidence: .high)
                }

                // Proceed Button
                Button(action: onProceed) {
                    Text(hasClarifications ? "Next: Quick Questions" : "Generate Routines")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.white)
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
        }
    }

    // MARK: - Section Card

    private func sectionCard<Content: View>(
        title: String,
        icon: String,
        color: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
            }

            VStack(spacing: 8) {
                content()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 24)
    }

    // MARK: - Trait Row

    private func traitRow(_ label: String, value: String, confidence: AnalysisConfidence) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            HStack(spacing: 6) {
                Text(value)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                confidenceBadge(confidence)
            }
        }
    }

    private func flagRow(_ text: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(.orange)
                .frame(width: 6, height: 6)
            Text(text)
                .font(.caption)
                .foregroundStyle(.orange)
            Spacer()
        }
    }

    private func recommendationRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "lightbulb.fill")
                .font(.caption)
                .foregroundStyle(.yellow)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 4)
    }

    private func confidenceBadge(_ confidence: AnalysisConfidence) -> some View {
        let (color, icon): (Color, String) = switch confidence {
        case .high: (.green, "checkmark.circle.fill")
        case .medium: (.yellow, "questionmark.circle.fill")
        case .low: (.orange, "exclamationmark.circle.fill")
        }

        return Image(systemName: icon)
            .font(.caption2)
            .foregroundStyle(color)
    }
}
