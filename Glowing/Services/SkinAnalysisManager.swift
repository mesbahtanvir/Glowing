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

    // MARK: - Category Registry

    /// All known category groups and their keys/labels/confidence defaults
    private static let categoryRegistry: [(group: String, key: String, label: String, confidence: String)] = [
        // Skin (16)
        ("skin", "active_acne", "Active acne", "high"),
        ("skin", "acne_scars_pih", "Acne scars / PIH", "high"),
        ("skin", "redness_erythema", "Redness / erythema", "high"),
        ("skin", "oiliness_shine", "Oiliness / shine", "medium"),
        ("skin", "pore_visibility", "Pore visibility", "medium"),
        ("skin", "skin_texture", "Skin texture", "medium"),
        ("skin", "hyperpigmentation", "Hyperpigmentation", "high"),
        ("skin", "skin_tone_evenness", "Skin tone evenness", "high"),
        ("skin", "dryness_flakiness", "Dryness / flakiness", "medium"),
        ("skin", "wrinkles_fine_lines", "Wrinkles / fine lines", "high"),
        ("skin", "skin_firmness_sagging", "Skin firmness / sagging", "medium"),
        ("skin", "sun_damage", "Sun damage signs", "medium"),
        ("skin", "skin_type_estimate", "Skin type estimate", "low"),
        ("skin", "inflammation_zones", "Inflammation zones", "high"),
        ("skin", "skin_radiance", "Skin radiance / glow", "medium"),
        ("skin", "moles_lesions", "Moles / lesions", "medium"),
        // Hair (10)
        ("hair", "frizz_level", "Frizz level", "high"),
        ("hair", "shine_lustre", "Shine / lustre", "medium"),
        ("hair", "density_thinning", "Density / thinning", "high"),
        ("hair", "dryness_brittleness", "Dryness / brittleness", "medium"),
        ("hair", "scalp_condition", "Scalp condition", "low"),
        ("hair", "hair_damage", "Hair damage", "medium"),
        ("hair", "volume_body", "Volume / body", "high"),
        ("hair", "curl_wave_pattern", "Curl / wave pattern", "high"),
        ("hair", "graying_pattern", "Graying pattern", "high"),
        ("hair", "styling_grooming", "Styling / grooming", "high"),
        // Lips (7)
        ("lips", "dryness_chapping", "Dryness / chapping", "high"),
        ("lips", "colour_pigmentation", "Colour & pigmentation", "high"),
        ("lips", "angular_cheilitis", "Angular cheilitis", "high"),
        ("lips", "lip_texture_smoothness", "Lip texture / smoothness", "medium"),
        ("lips", "vermilion_border_definition", "Vermilion border", "high"),
        ("lips", "swelling_inflammation", "Swelling / inflammation", "medium"),
        ("lips", "hydration_level", "Hydration level", "medium"),
        // Under-eye (4)
        ("under_eye", "dark_circles", "Dark circles", "high"),
        ("under_eye", "puffiness_eye_bags", "Puffiness / eye bags", "high"),
        ("under_eye", "crows_feet_wrinkles", "Crow's feet / wrinkles", "high"),
        ("under_eye", "tear_trough_depth", "Tear trough depth", "medium"),
        // Facial hair (2)
        ("facial_hair", "pseudofolliculitis_barbae", "Razor bumps / ingrowns", "high"),
        ("facial_hair", "beard_stubble_condition", "Beard / stubble condition", "high"),
        // Eyebrows (1)
        ("eyebrows", "eyebrow_grooming", "Eyebrow grooming", "high"),
        // Eye Area (4)
        ("eye_area", "upper_eyelid_exposure", "Upper eyelid exposure", "medium"),
        ("eye_area", "canthal_tilt", "Canthal tilt", "medium"),
        ("eye_area", "orbital_hollowness", "Orbital hollowness", "medium"),
        ("eye_area", "brow_position", "Brow position", "medium"),
        // Teeth / Smile (4)
        ("teeth", "teeth_alignment", "Teeth alignment", "high"),
        ("teeth", "teeth_whiteness", "Teeth whiteness", "high"),
        ("teeth", "smile_symmetry", "Smile symmetry", "high"),
        ("teeth", "gum_tooth_ratio", "Gum-to-tooth ratio", "medium"),
        // Nose (2)
        ("nose", "nose_skin_quality", "Nose skin quality", "high"),
        ("nose", "nose_proportion", "Nose proportion", "medium"),
        // Facial Structure (7)
        ("facial_structure", "jawline_definition", "Jawline definition", "high"),
        ("facial_structure", "cheekbone_prominence", "Cheekbone prominence", "medium"),
        ("facial_structure", "facial_symmetry", "Facial symmetry", "medium"),
        ("facial_structure", "facial_fat_bloating", "Facial fat / bloating", "medium"),
        ("facial_structure", "chin_projection", "Chin projection", "medium"),
        ("facial_structure", "facial_thirds_balance", "Facial thirds balance", "low"),
        ("facial_structure", "facial_width_ratio", "Facial width ratio", "low"),
        // Neck / Posture (3)
        ("neck_posture", "forward_head_posture", "Forward head posture", "medium"),
        ("neck_posture", "neck_definition", "Neck definition", "medium"),
        ("neck_posture", "neck_skin_quality", "Neck skin quality", "medium"),
        // Overall Impression (3)
        ("overall_impression", "perceived_age", "Perceived age", "medium"),
        ("overall_impression", "overall_grooming", "Overall grooming", "high"),
        ("overall_impression", "facial_hydration", "Facial hydration", "medium"),
    ]

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
                let order: [PhotoAngle] = [.front, .left, .right, .smile]
                let aIdx = order.firstIndex(of: a.angle) ?? 0
                let bIdx = order.firstIndex(of: b.angle) ?? 0
                return aIdx < bIdx
            }

            var images: [AnalysisImage] = []
            for photo in sortedPhotos {
                guard let data = photo.imageData else { continue }
                let croppedData = FaceCropper.cropToFace(jpegData: data)
                images.append(AnalysisImage(
                    angle: photo.angle.displayName,
                    base64Data: croppedData.base64EncodedString()
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

            let analysis = parseSkinAnalysis(sessionID: sessionID, result: result)

            // Delete existing analysis for this session (re-analyze case)
            deleteExistingAnalysis(sessionID: sessionID, modelContext: modelContext)

            modelContext.insert(analysis)

        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Parse Skin Analysis from Grouped JSON

    func parseSkinAnalysis(sessionID: UUID, result: [String: Any], rawJSON: String? = nil) -> SkinAnalysis {
        let overallScore = result["overallScore"] as? Int ?? 0
        let summary = result["summary"] as? String ?? ""
        let skinTypeVal = result["skinType"] as? String ?? ""
        let faceShapeVal = result["faceShape"] as? String ?? ""
        let hairTypeVal = result["hairType"] as? String ?? ""
        let leftNote = result["leftSideNote"] as? String ?? ""
        let rightNote = result["rightSideNote"] as? String ?? ""
        let recs = result["recommendations"] as? String ?? ""

        // Parse grouped categories
        var entries: [CategoryEntry] = []

        for reg in Self.categoryRegistry {
            // Look in the group dict first: result["skin"]["active_acne"]
            if let groupDict = result[reg.group] as? [String: Any],
               let catDict = groupDict[reg.key] as? [String: Any] {
                let score = catDict["score"] as? Int ?? 0
                let note = catDict["note"] as? String ?? ""
                let confidence = catDict["confidence"] as? String ?? reg.confidence
                entries.append(CategoryEntry(
                    id: reg.key,
                    group: reg.group,
                    label: reg.label,
                    score: score,
                    note: note,
                    confidence: confidence
                ))
            }
            // Fallback: flat key at top level (legacy format)
            else if let catDict = result[reg.key] as? [String: Any] {
                let score = catDict["score"] as? Int ?? 0
                let note = catDict["note"] as? String ?? ""
                let confidence = catDict["confidence"] as? String ?? reg.confidence
                entries.append(CategoryEntry(
                    id: reg.key,
                    group: reg.group,
                    label: reg.label,
                    score: score,
                    note: note,
                    confidence: confidence
                ))
            }
        }

        let categoriesJSONString: String = {
            guard let data = try? JSONEncoder().encode(entries),
                  let str = String(data: data, encoding: .utf8) else { return "[]" }
            return str
        }()

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
            categoriesJSON: categoriesJSONString,
            skinType: skinTypeVal,
            faceShape: faceShapeVal,
            hairType: hairTypeVal,
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
