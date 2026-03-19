import Foundation
import SwiftUI
import SwiftData

@MainActor
@Observable
final class SkinAnalysisManager {
    static let shared = SkinAnalysisManager()

    var isAnalyzing = false
    var lastError: String?

    private init() {}

    // MARK: - Settings

    var shouldAutoAnalyze: Bool {
        AuthManager.shared.isSignedIn
    }

    // MARK: - Analyze Face Session (via Backend)

    func analyzeSession(
        sessionID: UUID,
        photos: [ProgressPhoto],
        modelContext: ModelContext
    ) async {
        isAnalyzing = true
        lastError = nil
        defer { isAnalyzing = false }

        do {
            let sortedPhotos = photos.sorted { a, b in
                let order: [PhotoAngle] = [.front, .left, .right]
                let aIdx = order.firstIndex(of: a.angle) ?? 0
                let bIdx = order.firstIndex(of: b.angle) ?? 0
                return aIdx < bIdx
            }

            var images: [AnalysisImage] = []
            for photo in sortedPhotos {
                guard let data = photo.imageData else { continue }
                images.append(AnalysisImage(
                    angle: photo.angle.displayName,
                    base64Data: data.base64EncodedString()
                ))
            }

            guard images.count >= 3 else {
                lastError = "Need 3 face photos for analysis."
                return
            }

            let result = try await BackendAPIClient.shared.analyzeSkin(
                sessionID: sessionID,
                images: images
            )

            // Parse response into SkinAnalysis
            let analysis = parseSkinAnalysis(sessionID: sessionID, result: result)

            // Delete existing analysis for this session (re-analyze case)
            deleteExistingAnalysis(sessionID: sessionID, modelContext: modelContext)

            modelContext.insert(analysis)

        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Parse Skin Analysis from JSON

    func parseSkinAnalysis(sessionID: UUID, result: [String: Any], rawJSON: String? = nil) -> SkinAnalysis {
        let overallScore = result["overallScore"] as? Int ?? 0
        let summary = result["summary"] as? String ?? ""

        func extract(_ key: String) -> (Int, String) {
            guard let cat = result[key] as? [String: Any] else { return (0, "") }
            return (cat["score"] as? Int ?? 0, cat["note"] as? String ?? "")
        }

        let (skinToneS, skinToneN) = extract("skinTone")
        let (acneS, acneN) = extract("acne")
        let (pigS, pigN) = extract("pigmentation")
        let (scarsS, scarsN) = extract("scars")
        let (textureS, textureN) = extract("texture")
        let (darkS, darkN) = extract("darkCircles")
        let (poresS, poresN) = extract("pores")
        let (redS, redN) = extract("redness")
        let (symS, symN) = extract("symmetry")
        let (jawS, jawN) = extract("jawline")
        let (hydS, hydN) = extract("hydration")
        let (wrnS, wrnN) = extract("wrinkles")
        let (beardS, beardN) = extract("beard")
        let (eyebrowsS, eyebrowsN) = extract("eyebrows")
        let (lipsS, lipsN) = extract("lips")

        let (hairOverallS, hairOverallN) = extract("hairOverall")
        let (hairlineS, hairlineN) = extract("hairline")
        let (hairThicknessS, hairThicknessN) = extract("hairThickness")
        let (hairConditionS, hairConditionN) = extract("hairCondition")
        let (scalpHealthS, scalpHealthN) = extract("scalpHealth")
        let hairTypeVal = result["hairType"] as? String ?? ""

        let skinTypeVal = result["skinType"] as? String ?? ""
        let faceShapeVal = result["faceShape"] as? String ?? ""
        let leftNote = result["leftSideNote"] as? String ?? ""
        let rightNote = result["rightSideNote"] as? String ?? ""
        let recs = result["recommendations"] as? String ?? ""

        let jsonString: String? = rawJSON ?? {
            if let data = try? JSONSerialization.data(withJSONObject: result),
               let str = String(data: data, encoding: .utf8) {
                return str
            }
            return nil
        }()

        return SkinAnalysis(
            sessionID: sessionID,
            overallScore: overallScore,
            summary: summary,
            skinToneScore: skinToneS, skinToneNote: skinToneN,
            acneScore: acneS, acneNote: acneN,
            pigmentationScore: pigS, pigmentationNote: pigN,
            scarsScore: scarsS, scarsNote: scarsN,
            textureScore: textureS, textureNote: textureN,
            darkCirclesScore: darkS, darkCirclesNote: darkN,
            poresScore: poresS, poresNote: poresN,
            rednessScore: redS, rednessNote: redN,
            symmetryScore: symS, symmetryNote: symN,
            jawlineScore: jawS, jawlineNote: jawN,
            hydrationScore: hydS, hydrationNote: hydN,
            wrinklesScore: wrnS, wrinklesNote: wrnN,
            beardScore: beardS, beardNote: beardN,
            eyebrowsScore: eyebrowsS, eyebrowsNote: eyebrowsN,
            lipsScore: lipsS, lipsNote: lipsN,
            hairOverallScore: hairOverallS, hairOverallNote: hairOverallN,
            hairlineScore: hairlineS, hairlineNote: hairlineN,
            hairThicknessScore: hairThicknessS, hairThicknessNote: hairThicknessN,
            hairConditionScore: hairConditionS, hairConditionNote: hairConditionN,
            scalpHealthScore: scalpHealthS, scalpHealthNote: scalpHealthN,
            hairType: hairTypeVal,
            skinType: skinTypeVal,
            faceShape: faceShapeVal,
            leftSideNote: leftNote,
            rightSideNote: rightNote,
            recommendations: recs,
            rawJSON: jsonString
        )
    }

    // MARK: - Helpers

    private func deleteExistingAnalysis(sessionID: UUID, modelContext: ModelContext) {
        let sid = sessionID
        let existing = try? modelContext.fetch(
            FetchDescriptor<SkinAnalysis>(
                predicate: #Predicate { $0.sessionID == sid }
            )
        )
        for old in existing ?? [] {
            modelContext.delete(old)
        }
    }
}
