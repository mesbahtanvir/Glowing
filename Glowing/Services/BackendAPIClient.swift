import Foundation

struct AnalysisImage {
    let angle: String
    let base64Data: String
}

struct OnboardingResult {
    let skinAnalysisJSON: [String: Any]
    let suggestedRoutineJSON: [String: Any]?
}

@MainActor
@Observable
final class BackendAPIClient {
    static let shared = BackendAPIClient()

    private init() {}

    // MARK: - Skin Analysis

    func analyzeSkin(sessionID: UUID, images: [AnalysisImage]) async throws -> [String: Any] {
        if APIConfig.useMockBackend {
            return try await analyzeSkinDirect(images: images)
        }

        let url = APIConfig.baseURL.appendingPathComponent("analyze/skin")
        let imagePayload = images.map { ["angle": $0.angle, "data": $0.base64Data] }
        let body: [String: Any] = [
            "sessionId": sessionID.uuidString,
            "images": imagePayload
        ]

        let (data, _) = try await performRequest(url: url, body: body)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.invalidResponse
        }
        return json
    }

    // MARK: - Onboarding Analysis

    func analyzeOnboarding(images: [AnalysisImage]) async throws -> OnboardingResult {
        if APIConfig.useMockBackend {
            let skinResult = try await analyzeOnboardingDirect(images: images)
            return skinResult
        }

        let url = APIConfig.baseURL.appendingPathComponent("analyze/onboarding")
        let imagePayload = images.map { ["angle": $0.angle, "data": $0.base64Data] }
        let body: [String: Any] = [
            "images": imagePayload
        ]

        let (data, _) = try await performRequest(url: url, body: body)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.invalidResponse
        }

        let skinAnalysis = json["skinAnalysis"] as? [String: Any] ?? [:]
        let suggestedRoutine = json["suggestedRoutine"] as? [String: Any]

        return OnboardingResult(skinAnalysisJSON: skinAnalysis, suggestedRoutineJSON: suggestedRoutine)
    }

    // MARK: - Image Detail Extraction (LLM Call 1)

    func extractImageDetails(images: [AnalysisImage]) async throws -> ImageAnalysisProfile {
        if APIConfig.useMockBackend {
            return try await extractImageDetailsDirect(images: images)
        }

        let url = APIConfig.baseURL.appendingPathComponent("analyze/extract-details")
        let imagePayload = images.map { ["angle": $0.angle, "data": $0.base64Data] }
        let body: [String: Any] = ["images": imagePayload]

        let (data, _) = try await performRequest(url: url, body: body)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.invalidResponse
        }
        return ImageAnalysisProfile.fromJSON(json)
    }

    private func extractImageDetailsDirect(images: [AnalysisImage]) async throws -> ImageAnalysisProfile {
        guard let apiKey = KeychainHelper.read(key: "com.glowing.openai-api-key") else {
            throw APIError.noAPIKey
        }

        var userContent: [[String: Any]] = [
            ["type": "text", "text": "Here are 4 face photos (front, left, right, smile) of a man. Extract detailed traits for personalized routine generation."]
        ]

        for image in images {
            userContent.append(["type": "text", "text": "[\(image.angle) view]:"])
            userContent.append([
                "type": "image_url",
                "image_url": ["url": "data:image/jpeg;base64,\(image.base64Data)"]
            ])
        }

        let systemPrompt = """
        You are a dermatologist and trichologist. Analyze the 4 photos and extract structured traits. For each trait, provide a confidence level (high/medium/low) based on how clearly it's visible in the photos.

        Return ONLY this JSON structure:

        {
          "skin": {
            "skinType": "<oily|dry|combination|normal|sensitive>",
            "skinTypeConfidence": "<high|medium|low>",
            "isAcneProne": <true|false>,
            "acneProneConfidence": "<high|medium|low>",
            "hasPigmentation": <true|false>,
            "hasSensitivity": <true|false>,
            "hasDehydration": <true|false>,
            "hasSunDamage": <true|false>
          },
          "hair": {
            "hairPattern": "<straight|wavy|curly|coily>",
            "hairPatternConfidence": "<high|medium|low>",
            "hairThickness": "<fine|medium|coarse>",
            "hairThicknessConfidence": "<high|medium|low>",
            "hairLength": "<short|medium|long>",
            "scalpConcerns": ["<dandruff|oiliness|dryness|thinning>"]  (empty array if none visible)
          },
          "lips": {
            "condition": "<healthy|dry|chapped|cracked|pigmented>",
            "needsCare": <true|false>
          },
          "eyebrows": {
            "condition": "<well_groomed|sparse|overgrown|unibrow|asymmetric>",
            "needsGrooming": <true|false>
          },
          "beard": {
            "status": "<clean_shaven|stubble|short_beard|medium_beard|full_beard|patchy>",
            "statusConfidence": "<high|medium|low>",
            "growthPattern": "<even|patchy_cheeks|patchy_chin|neck_heavy>",
            "growthPatternConfidence": "<high|medium|low>",
            "canGrowFullBeard": <true|false|null>,
            "recommendation": "<Your clinical assessment. Examples: 'Patchy on cheeks — recommend short stubble or clean shave' or 'Even growth with good density — user preference needed for style' or 'Clean shaven, no beard routine needed'>",
            "needsUserPreference": <true|false>  (ONLY true when growth is decent and multiple styles would work. If patchy, set false and recommend trimming. If clean-shaven, set false.)
          },
          "face": {
            "faceShape": "<oval|round|square|oblong|heart|diamond|triangle>"
          }
        }

        IMPORTANT RULES:
        - Be HONEST about confidence. If you can't clearly see something, mark it low.
        - Hair thickness is almost always low confidence from photos unless the hair is very obviously fine or very thick.
        - Beard: If growth is visibly patchy, do NOT set needsUserPreference to true. Recommend short stubble or clean shave directly. Only set needsUserPreference=true when growth is genuinely even and multiple styles would look good.
        - Lips: Check for dryness, cracking, discoloration. Most men neglect lip care.
        - Eyebrows: Check for stray hairs, sparse areas, unibrow, overgrowth.
        - Scalp concerns: Only report what you can actually see. Don't guess.

        Return ONLY valid JSON. No markdown, no explanation.
        """

        let requestBody: [String: Any] = [
            "model": "gpt-4o",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userContent]
            ],
            "max_tokens": 1000,
            "response_format": ["type": "json_object"]
        ]

        let result = try await callOpenAI(apiKey: apiKey, body: requestBody)
        return ImageAnalysisProfile.fromJSON(result)
    }

    // MARK: - Routine Generation (LLM Call 2)

    func generateRoutines(profile: ImageAnalysisProfile) async throws -> [[String: Any]] {
        if APIConfig.useMockBackend {
            return try await generateRoutinesDirect(profile: profile)
        }

        let url = APIConfig.baseURL.appendingPathComponent("generate/routines")
        let body: [String: Any] = ["profile": profile.toPromptDescription()]

        let (data, _) = try await performRequest(url: url, body: body)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let routines = json["routines"] as? [[String: Any]] else {
            throw APIError.invalidResponse
        }
        return routines
    }

    private func generateRoutinesDirect(profile: ImageAnalysisProfile) async throws -> [[String: Any]] {
        guard let apiKey = KeychainHelper.read(key: "com.glowing.openai-api-key") else {
            throw APIError.noAPIKey
        }

        let profileDescription = profile.toPromptDescription()

        let systemPrompt = """
        You are a board-certified dermatologist and licensed trichologist. Based on the patient profile below, generate personalized routines for skincare, hair care, and facial hair/beard care.

        PATIENT PROFILE:
        \(profileDescription)

        Return a JSON object:
        {
          "routines": [
            {
              "name": "<routine name>",
              "category": "<face|hair|stubble>",
              "timeOfDay": "<morning|evening|weekly>",
              "scheduledWeekdays": [<1=Sun..7=Sat, empty array = every day>],
              "icon": "<SF Symbol name>",
              "displayOrder": <int>,
              "steps": [
                {
                  "title": "<step name>",
                  "productName": "<specific product or ingredient>",
                  "notes": "<technique, reasoning, common mistakes>",
                  "timerDuration": <seconds or null>
                }
              ]
            }
          ]
        }

        ROUTINE GUIDELINES:

        FACE routines:
        - Morning (daily): Cleanse (60s), Vitamin C serum (30s absorb), Moisturizer, Sunscreen SPF 30+.
        - Evening (daily): Cleanse, Treatment serum (niacinamide or retinol based on concerns), Moisturizer.
        - Weekly: Chemical exfoliant (AHA/BHA) OR hydrating mask. NEVER exfoliate on shave days.
        - Adjust for skin type: oily → gel cleanser, niacinamide. Dry → cream cleanser, hyaluronic acid. Sensitive → fragrance-free, skip actives initially.
        - If lips need care: add lip balm with SPF in morning, lip treatment in evening.
        - If eyebrows need grooming: add grooming step in weekly routine.

        HAIR routines:
        - Wash (2-3x/week, adjust by type): Shampoo + Conditioner. Oily/fine: more frequent. Dry/curly: less frequent.
        - Scalp care (1x/week): Scalp exfoliation.
        - Deep conditioning (bi-weekly): For damaged/dry hair.
        - If thinning: daily scalp serum routine.

        STUBBLE/BEARD routines:
        - If clean-shaven: Skip stubble category entirely.
        - If stubble: Trim 2-3x/week, neckline cleanup, PFB prevention.
        - If short/medium beard: Beard wash 2-3x/week, daily beard oil, weekly trim.
        - If full beard: Beard wash, oil, balm, weekly shaping.
        - Exfoliation under beard 1x/week for ingrown prevention.

        SCHEDULING:
        - scheduledWeekdays=[] means every day.
        - [2,4,6] = Mon/Wed/Fri. [3,5,7] = Tue/Thu/Sat. [1] = Sunday. [7] = Saturday.
        - 5-8 routines total. Don't overload any single day.

        RULES:
        - 2-5 steps per routine. Simplicity drives adherence.
        - Products: CeraVe, The Ordinary, La Roche-Posay, Neutrogena, Vanicream, Cetaphil, Bulldog, Duke Cannon.
        - SF Symbols: "sun.max.fill", "moon.fill", "drop.fill", "scissors", "comb.fill", "humidity.fill", "leaf.fill", "sparkles".
        - timerDuration: 60 for cleansers, 30 for serums, 120 for masks, 300 for deep conditioners, null for trim/style.
        - Be specific: "salicylic acid 2% cleanser" not "cleanser".

        Return ONLY valid JSON. No markdown.
        """

        let requestBody: [String: Any] = [
            "model": "gpt-4o",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": "Generate personalized routines based on the patient profile in the system prompt."]
            ],
            "max_tokens": 4000,
            "response_format": ["type": "json_object"]
        ]

        let result = try await callOpenAI(apiKey: apiKey, body: requestBody)
        return result["routines"] as? [[String: Any]] ?? []
    }

    // MARK: - Backend HTTP Request

    private func performRequest(url: URL, body: [String: Any]) async throws -> (Data, URLResponse) {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 90

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let httpResponse = response as? HTTPURLResponse
            if let data = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = data["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw APIError.serverError(message)
            }
            throw APIError.httpError(httpResponse?.statusCode ?? 0)
        }
        return (data, response)
    }

    // MARK: - Mock Mode (Direct OpenAI)

    private func analyzeSkinDirect(images: [AnalysisImage]) async throws -> [String: Any] {
        guard let apiKey = KeychainHelper.read(key: "com.glowing.openai-api-key") else {
            throw APIError.noAPIKey
        }

        var userContent: [[String: Any]] = [
            ["type": "text", "text": "Here are 4 face photos (front, left, right, smile). Analyze them together for a comprehensive assessment."]
        ]

        for image in images {
            userContent.append(["type": "text", "text": "[\(image.angle) view]:"])
            userContent.append([
                "type": "image_url",
                "image_url": ["url": "data:image/jpeg;base64,\(image.base64Data)"]
            ])
        }

        let systemPrompt = """
        You are a men's skincare and hair health consultant with dermatology training. Scores reflect this person's own skin health potential — how close each area is to its personal best, not a comparison with others. A 6/10 means there's clear room for improvement with the right routine. An 8/10 means this area is well-maintained.

        Cross-reference all 4 angles (front, left, right, smile) together. Analyze skin, hair, lips, under-eye area, eye area, teeth/smile, nose, facial hair, eyebrows, facial structure, neck/posture, and overall impression.

        The smile photo shows teeth. Use it for teeth alignment, whiteness, smile symmetry, and gum-to-tooth ratio.

        SCORING GUIDANCE:
        - 8-10: This area is well-maintained. Minor refinements at most.
        - 6-7: Healthy baseline with room to improve through consistent care.
        - 4-5: Noticeable room for improvement. A good routine will help.
        - 1-3: This area would benefit most from focused attention.
        - Be SPECIFIC in notes — mention exact locations and what to look for.
        - Frame observations as opportunities, not problems.
        - Include "confidence": "high"|"medium"|"low" for each category based on how clearly visible it is in the photos.

        Return a JSON object with grouped categories:

        {
          "overallScore": <0-100 integer reflecting personal potential>,
          "summary": "<2-3 sentences. Frame as current state and opportunity, not criticism.>",
          "skinType": "<oily|dry|combination|normal|sensitive>",
          "faceShape": "<oval|round|square|oblong|heart|diamond|triangle>",
          "hairType": "<straight|wavy|curly|coily>",
          "leftSideNote": "<1-2 sentences on left profile specifics>",
          "rightSideNote": "<1-2 sentences on right profile specifics>",
          "recommendations": "<3-5 specific product/ingredient suggestions as bullet points separated by newlines>",
          "skin": {
            "active_acne": { "score": <0-10>, "note": "<papules, pustules, cysts, whiteheads, blackheads — type, count, locations>", "confidence": "<high|medium|low>" },
            "acne_scars_pih": { "score": <0-10>, "note": "<PIH, ice-pick, rolling, boxcar scars — location and severity>", "confidence": "<high|medium|low>" },
            "redness_erythema": { "score": <0-10>, "note": "<diffuse redness, broken capillaries, rosacea indicators>", "confidence": "<high|medium|low>" },
            "oiliness_shine": { "score": <0-10>, "note": "<T-zone shine, overall sebum levels>", "confidence": "<high|medium|low>" },
            "pore_visibility": { "score": <0-10>, "note": "<enlarged pores, congestion — nose, cheeks, forehead>", "confidence": "<high|medium|low>" },
            "skin_texture": { "score": <0-10>, "note": "<smoothness, roughness, bumps, KP, milia>", "confidence": "<high|medium|low>" },
            "hyperpigmentation": { "score": <0-10>, "note": "<melasma, sun spots, age spots, dark patches>", "confidence": "<high|medium|low>" },
            "skin_tone_evenness": { "score": <0-10>, "note": "<colour uniformity, blotchiness, discolouration>", "confidence": "<high|medium|low>" },
            "dryness_flakiness": { "score": <0-10>, "note": "<peeling, flaking, dry patches, dehydration lines>", "confidence": "<high|medium|low>" },
            "wrinkles_fine_lines": { "score": <0-10>, "note": "<forehead lines, crow's feet, nasolabial folds — depth>", "confidence": "<high|medium|low>" },
            "skin_firmness_sagging": { "score": <0-10>, "note": "<jowl definition, jawline sharpness, skin laxity>", "confidence": "<high|medium|low>" },
            "sun_damage": { "score": <0-10>, "note": "<photoaging, freckling, leathery texture>", "confidence": "<high|medium|low>" },
            "skin_type_estimate": { "score": <0-10>, "note": "<oily/dry/combo/normal inferred from visible cues>", "confidence": "<high|medium|low>" },
            "inflammation_zones": { "score": <0-10>, "note": "<perioral dermatitis, eczema patches, irritation around nose/mouth>", "confidence": "<high|medium|low>" },
            "skin_radiance": { "score": <0-10>, "note": "<overall luminosity, dullness, healthy glow vs sallow>", "confidence": "<high|medium|low>" },
            "moles_lesions": { "score": <0-10>, "note": "<visible moles — ABCD screening, concerning features>", "confidence": "<high|medium|low>" }
          },
          "hair": {
            "frizz_level": { "score": <0-10>, "note": "<flyaways, halo frizz, smoothness>", "confidence": "<high|medium|low>" },
            "shine_lustre": { "score": <0-10>, "note": "<light reflection, cuticle health indicators>", "confidence": "<high|medium|low>" },
            "density_thinning": { "score": <0-10>, "note": "<scalp visibility, hairline recession, temple thinning>", "confidence": "<high|medium|low>" },
            "dryness_brittleness": { "score": <0-10>, "note": "<split ends, straw-like texture, rough appearance>", "confidence": "<high|medium|low>" },
            "scalp_condition": { "score": <0-10>, "note": "<flaking, dandruff, seborrheic dermatitis, redness at part>", "confidence": "<high|medium|low>" },
            "hair_damage": { "score": <0-10>, "note": "<heat/chemical damage, breakage pattern>", "confidence": "<high|medium|low>" },
            "volume_body": { "score": <0-10>, "note": "<limp/flat vs full/voluminous, root lift>", "confidence": "<high|medium|low>" },
            "curl_wave_pattern": { "score": <0-10>, "note": "<curl type 2A-4C, definition, uniformity>", "confidence": "<high|medium|low>" },
            "graying_pattern": { "score": <0-10>, "note": "<percentage gray, distribution — temples, crown, scattered>", "confidence": "<high|medium|low>" },
            "styling_grooming": { "score": <0-10>, "note": "<overgrown, unstyled, well-maintained, neatness of cut>", "confidence": "<high|medium|low>" }
          },
          "lips": {
            "dryness_chapping": { "score": <0-10>, "note": "<cracking, peeling, dehydration lines>", "confidence": "<high|medium|low>" },
            "colour_pigmentation": { "score": <0-10>, "note": "<natural colour, hyperpigmentation, pallor>", "confidence": "<high|medium|low>" },
            "angular_cheilitis": { "score": <0-10>, "note": "<cracking/redness at mouth corners>", "confidence": "<high|medium|low>" },
            "lip_texture_smoothness": { "score": <0-10>, "note": "<surface quality, roughness, bumps>", "confidence": "<high|medium|low>" },
            "vermilion_border_definition": { "score": <0-10>, "note": "<lip line sharpness, Cupid's bow clarity>", "confidence": "<high|medium|low>" },
            "swelling_inflammation": { "score": <0-10>, "note": "<puffiness, asymmetric swelling>", "confidence": "<high|medium|low>" },
            "hydration_level": { "score": <0-10>, "note": "<plumpness, suppleness>", "confidence": "<high|medium|low>" }
          },
          "under_eye": {
            "dark_circles": { "score": <0-10>, "note": "<colour type (purple/brown/blue), severity, hollowing vs pigmentation>", "confidence": "<high|medium|low>" },
            "puffiness_eye_bags": { "score": <0-10>, "note": "<swelling, fluid retention, fat pad herniation>", "confidence": "<high|medium|low>" },
            "crows_feet_wrinkles": { "score": <0-10>, "note": "<fine lines from outer eye, depth and count>", "confidence": "<high|medium|low>" },
            "tear_trough_depth": { "score": <0-10>, "note": "<hollowing between eyelid and cheek, shadow severity>", "confidence": "<high|medium|low>" }
          },
          "facial_hair": {
            "pseudofolliculitis_barbae": { "score": <0-10>, "note": "<ingrown hairs, razor bumps, irritation in shave zone>", "confidence": "<high|medium|low>" },
            "beard_stubble_condition": { "score": <0-10>, "note": "<patchiness, density, growth uniformity, grooming quality>", "confidence": "<high|medium|low>" }
          },
          "eyebrows": {
            "eyebrow_grooming": { "score": <0-10>, "note": "<shape, fullness, symmetry, stray hairs>", "confidence": "<high|medium|low>" }
          },
          "eye_area": {
            "upper_eyelid_exposure": { "score": <0-10>, "note": "<hooded vs exposed upper lid, lid droop>", "confidence": "<high|medium|low>" },
            "canthal_tilt": { "score": <0-10>, "note": "<positive/neutral/negative eye angle>", "confidence": "<high|medium|low>" },
            "orbital_hollowness": { "score": <0-10>, "note": "<sunken vs full periorbital area>", "confidence": "<high|medium|low>" },
            "brow_position": { "score": <0-10>, "note": "<height, brow ridge prominence>", "confidence": "<high|medium|low>" }
          },
          "teeth": {
            "teeth_alignment": { "score": <0-10>, "note": "<crowding, gaps, crookedness — from smile photo>", "confidence": "<high|medium|low>" },
            "teeth_whiteness": { "score": <0-10>, "note": "<staining, yellowing, brightness — from smile photo>", "confidence": "<high|medium|low>" },
            "smile_symmetry": { "score": <0-10>, "note": "<even vs uneven smile line — from smile photo>", "confidence": "<high|medium|low>" },
            "gum_tooth_ratio": { "score": <0-10>, "note": "<gummy smile assessment — from smile photo>", "confidence": "<high|medium|low>" }
          },
          "nose": {
            "nose_skin_quality": { "score": <0-10>, "note": "<blackheads, enlarged pores, oiliness on nose>", "confidence": "<high|medium|low>" },
            "nose_proportion": { "score": <0-10>, "note": "<width, bridge height, nostril visibility, balance>", "confidence": "<high|medium|low>" }
          },
          "facial_structure": {
            "jawline_definition": { "score": <0-10>, "note": "<sharpness, angle, double chin presence>", "confidence": "<high|medium|low>" },
            "cheekbone_prominence": { "score": <0-10>, "note": "<zygomatic projection, hollowness below>", "confidence": "<high|medium|low>" },
            "facial_symmetry": { "score": <0-10>, "note": "<left/right balance across features>", "confidence": "<high|medium|low>" },
            "facial_fat_bloating": { "score": <0-10>, "note": "<puffiness, water retention, moon face>", "confidence": "<high|medium|low>" },
            "chin_projection": { "score": <0-10>, "note": "<profile position, recessed vs proportional>", "confidence": "<high|medium|low>" },
            "facial_thirds_balance": { "score": <0-10>, "note": "<upper/middle/lower facial proportions>", "confidence": "<high|medium|low>" },
            "facial_width_ratio": { "score": <0-10>, "note": "<FWHR, overall face shape balance>", "confidence": "<high|medium|low>" }
          },
          "neck_posture": {
            "forward_head_posture": { "score": <0-10>, "note": "<head position relative to shoulders — from side photos>", "confidence": "<high|medium|low>" },
            "neck_definition": { "score": <0-10>, "note": "<jaw-to-neck angle, submental fat — from side photos>", "confidence": "<high|medium|low>" },
            "neck_skin_quality": { "score": <0-10>, "note": "<tech neck lines, laxity, creasing>", "confidence": "<high|medium|low>" }
          },
          "overall_impression": {
            "perceived_age": { "score": <0-10>, "note": "<looks older/younger than expected, aging indicators>", "confidence": "<high|medium|low>" },
            "overall_grooming": { "score": <0-10>, "note": "<general put-together-ness, neatness>", "confidence": "<high|medium|low>" },
            "facial_hydration": { "score": <0-10>, "note": "<overall plumpness vs dehydrated, skin turgor>", "confidence": "<high|medium|low>" }
          }
        }

        Return ONLY valid JSON. No markdown, no explanation outside the JSON.
        """

        let requestBody: [String: Any] = [
            "model": "gpt-4o",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userContent]
            ],
            "max_tokens": 5500,
            "response_format": ["type": "json_object"]
        ]

        return try await callOpenAI(apiKey: apiKey, body: requestBody)
    }

    private func analyzeOnboardingDirect(images: [AnalysisImage]) async throws -> OnboardingResult {
        guard let apiKey = KeychainHelper.read(key: "com.glowing.openai-api-key") else {
            throw APIError.noAPIKey
        }

        let introText = "Here are 4 photos (front, left, right, smile) of a man's face and hair. Analyze all visible features comprehensively. The smile photo shows teeth — use it for teeth/smile assessment. Generate personalized routines."

        var userContent: [[String: Any]] = [
            ["type": "text", "text": introText]
        ]

        for image in images {
            userContent.append(["type": "text", "text": "[\(image.angle) view]:"])
            userContent.append([
                "type": "image_url",
                "image_url": ["url": "data:image/jpeg;base64,\(image.base64Data)"]
            ])
        }

        let systemPrompt = """
        You are a board-certified dermatologist and licensed trichologist consulting with a male patient. Scores reflect this person's own skin health potential — how close each area is to its personal best, not a comparison with others. A 6/10 means there's clear room for improvement with the right routine. An 8/10 means this area is well-maintained. Give evidence-based recommendations.

        Cross-reference all 4 angles (front, left, right, smile). Analyze skin, hair, lips, under-eye area, eye area, teeth/smile, nose, facial hair, eyebrows, facial structure, neck/posture, and overall impression.

        The smile photo shows teeth. Use it for teeth alignment, whiteness, smile symmetry, and gum-to-tooth ratio.

        SCORING GUIDANCE:
        - 8-10: This area is well-maintained. Minor refinements at most.
        - 6-7: Healthy baseline with room to improve through consistent care.
        - 4-5: Noticeable room for improvement. A good routine will help.
        - 1-3: This area would benefit most from focused attention.
        - Be SPECIFIC in notes — mention exact locations and what to look for.
        - Frame observations as opportunities, not problems.
        - Include "confidence": "high"|"medium"|"low" for each category based on how clearly visible it is in the photos.

        Return a JSON object with two sections:

        {
          "skinAnalysis": {
            "overallScore": <0-100 integer reflecting personal potential>,
            "summary": "<2-3 sentences. Frame as current state and opportunity, not criticism.>",
            "skinType": "<oily|dry|combination|normal|sensitive>",
            "faceShape": "<oval|round|square|oblong|heart|diamond|triangle>",
            "hairType": "<straight|wavy|curly|coily>",
            "leftSideNote": "<1-2 sentences on left profile specifics>",
            "rightSideNote": "<1-2 sentences on right profile specifics>",
            "recommendations": "<3-5 specific product/ingredient suggestions as bullet points separated by newlines>",
            "skin": {
              "active_acne": { "score": <0-10>, "note": "<papules, pustules, cysts, whiteheads, blackheads — type, count, locations>", "confidence": "<high|medium|low>" },
              "acne_scars_pih": { "score": <0-10>, "note": "<PIH, ice-pick, rolling, boxcar scars — location and severity>", "confidence": "<high|medium|low>" },
              "redness_erythema": { "score": <0-10>, "note": "<diffuse redness, broken capillaries, rosacea indicators>", "confidence": "<high|medium|low>" },
              "oiliness_shine": { "score": <0-10>, "note": "<T-zone shine, overall sebum levels>", "confidence": "<high|medium|low>" },
              "pore_visibility": { "score": <0-10>, "note": "<enlarged pores, congestion — nose, cheeks, forehead>", "confidence": "<high|medium|low>" },
              "skin_texture": { "score": <0-10>, "note": "<smoothness, roughness, bumps, KP, milia>", "confidence": "<high|medium|low>" },
              "hyperpigmentation": { "score": <0-10>, "note": "<melasma, sun spots, age spots, dark patches>", "confidence": "<high|medium|low>" },
              "skin_tone_evenness": { "score": <0-10>, "note": "<colour uniformity, blotchiness, discolouration>", "confidence": "<high|medium|low>" },
              "dryness_flakiness": { "score": <0-10>, "note": "<peeling, flaking, dry patches, dehydration lines>", "confidence": "<high|medium|low>" },
              "wrinkles_fine_lines": { "score": <0-10>, "note": "<forehead lines, crow's feet, nasolabial folds — depth>", "confidence": "<high|medium|low>" },
              "skin_firmness_sagging": { "score": <0-10>, "note": "<jowl definition, jawline sharpness, skin laxity>", "confidence": "<high|medium|low>" },
              "sun_damage": { "score": <0-10>, "note": "<photoaging, freckling, leathery texture>", "confidence": "<high|medium|low>" },
              "skin_type_estimate": { "score": <0-10>, "note": "<oily/dry/combo/normal inferred from visible cues>", "confidence": "<high|medium|low>" },
              "inflammation_zones": { "score": <0-10>, "note": "<perioral dermatitis, eczema patches, irritation around nose/mouth>", "confidence": "<high|medium|low>" },
              "skin_radiance": { "score": <0-10>, "note": "<overall luminosity, dullness, healthy glow vs sallow>", "confidence": "<high|medium|low>" },
              "moles_lesions": { "score": <0-10>, "note": "<visible moles — ABCD screening, concerning features>", "confidence": "<high|medium|low>" }
            },
            "hair": {
              "frizz_level": { "score": <0-10>, "note": "<flyaways, halo frizz, smoothness>", "confidence": "<high|medium|low>" },
              "shine_lustre": { "score": <0-10>, "note": "<light reflection, cuticle health indicators>", "confidence": "<high|medium|low>" },
              "density_thinning": { "score": <0-10>, "note": "<scalp visibility, hairline recession, temple thinning>", "confidence": "<high|medium|low>" },
              "dryness_brittleness": { "score": <0-10>, "note": "<split ends, straw-like texture, rough appearance>", "confidence": "<high|medium|low>" },
              "scalp_condition": { "score": <0-10>, "note": "<flaking, dandruff, seborrheic dermatitis, redness at part>", "confidence": "<high|medium|low>" },
              "hair_damage": { "score": <0-10>, "note": "<heat/chemical damage, breakage pattern>", "confidence": "<high|medium|low>" },
              "volume_body": { "score": <0-10>, "note": "<limp/flat vs full/voluminous, root lift>", "confidence": "<high|medium|low>" },
              "curl_wave_pattern": { "score": <0-10>, "note": "<curl type 2A-4C, definition, uniformity>", "confidence": "<high|medium|low>" },
              "graying_pattern": { "score": <0-10>, "note": "<percentage gray, distribution — temples, crown, scattered>", "confidence": "<high|medium|low>" },
              "styling_grooming": { "score": <0-10>, "note": "<overgrown, unstyled, well-maintained, neatness of cut>", "confidence": "<high|medium|low>" }
            },
            "lips": {
              "dryness_chapping": { "score": <0-10>, "note": "<cracking, peeling, dehydration lines>", "confidence": "<high|medium|low>" },
              "colour_pigmentation": { "score": <0-10>, "note": "<natural colour, hyperpigmentation, pallor>", "confidence": "<high|medium|low>" },
              "angular_cheilitis": { "score": <0-10>, "note": "<cracking/redness at mouth corners>", "confidence": "<high|medium|low>" },
              "lip_texture_smoothness": { "score": <0-10>, "note": "<surface quality, roughness, bumps>", "confidence": "<high|medium|low>" },
              "vermilion_border_definition": { "score": <0-10>, "note": "<lip line sharpness, Cupid's bow clarity>", "confidence": "<high|medium|low>" },
              "swelling_inflammation": { "score": <0-10>, "note": "<puffiness, asymmetric swelling>", "confidence": "<high|medium|low>" },
              "hydration_level": { "score": <0-10>, "note": "<plumpness, suppleness>", "confidence": "<high|medium|low>" }
            },
            "under_eye": {
              "dark_circles": { "score": <0-10>, "note": "<colour type (purple/brown/blue), severity, hollowing vs pigmentation>", "confidence": "<high|medium|low>" },
              "puffiness_eye_bags": { "score": <0-10>, "note": "<swelling, fluid retention, fat pad herniation>", "confidence": "<high|medium|low>" },
              "crows_feet_wrinkles": { "score": <0-10>, "note": "<fine lines from outer eye, depth and count>", "confidence": "<high|medium|low>" },
              "tear_trough_depth": { "score": <0-10>, "note": "<hollowing between eyelid and cheek, shadow severity>", "confidence": "<high|medium|low>" }
            },
            "facial_hair": {
              "pseudofolliculitis_barbae": { "score": <0-10>, "note": "<ingrown hairs, razor bumps, irritation in shave zone>", "confidence": "<high|medium|low>" },
              "beard_stubble_condition": { "score": <0-10>, "note": "<patchiness, density, growth uniformity, grooming quality>", "confidence": "<high|medium|low>" }
            },
            "eyebrows": {
              "eyebrow_grooming": { "score": <0-10>, "note": "<shape, fullness, symmetry, stray hairs>", "confidence": "<high|medium|low>" }
            },
            "eye_area": {
              "upper_eyelid_exposure": { "score": <0-10>, "note": "<hooded vs exposed upper lid, lid droop>", "confidence": "<high|medium|low>" },
              "canthal_tilt": { "score": <0-10>, "note": "<positive/neutral/negative eye angle>", "confidence": "<high|medium|low>" },
              "orbital_hollowness": { "score": <0-10>, "note": "<sunken vs full periorbital area>", "confidence": "<high|medium|low>" },
              "brow_position": { "score": <0-10>, "note": "<height, brow ridge prominence>", "confidence": "<high|medium|low>" }
            },
            "teeth": {
              "teeth_alignment": { "score": <0-10>, "note": "<crowding, gaps, crookedness — from smile photo>", "confidence": "<high|medium|low>" },
              "teeth_whiteness": { "score": <0-10>, "note": "<staining, yellowing, brightness — from smile photo>", "confidence": "<high|medium|low>" },
              "smile_symmetry": { "score": <0-10>, "note": "<even vs uneven smile line — from smile photo>", "confidence": "<high|medium|low>" },
              "gum_tooth_ratio": { "score": <0-10>, "note": "<gummy smile assessment — from smile photo>", "confidence": "<high|medium|low>" }
            },
            "nose": {
              "nose_skin_quality": { "score": <0-10>, "note": "<blackheads, enlarged pores, oiliness on nose>", "confidence": "<high|medium|low>" },
              "nose_proportion": { "score": <0-10>, "note": "<width, bridge height, nostril visibility, balance>", "confidence": "<high|medium|low>" }
            },
            "facial_structure": {
              "jawline_definition": { "score": <0-10>, "note": "<sharpness, angle, double chin presence>", "confidence": "<high|medium|low>" },
              "cheekbone_prominence": { "score": <0-10>, "note": "<zygomatic projection, hollowness below>", "confidence": "<high|medium|low>" },
              "facial_symmetry": { "score": <0-10>, "note": "<left/right balance across features>", "confidence": "<high|medium|low>" },
              "facial_fat_bloating": { "score": <0-10>, "note": "<puffiness, water retention, moon face>", "confidence": "<high|medium|low>" },
              "chin_projection": { "score": <0-10>, "note": "<profile position, recessed vs proportional>", "confidence": "<high|medium|low>" },
              "facial_thirds_balance": { "score": <0-10>, "note": "<upper/middle/lower facial proportions>", "confidence": "<high|medium|low>" },
              "facial_width_ratio": { "score": <0-10>, "note": "<FWHR, overall face shape balance>", "confidence": "<high|medium|low>" }
            },
            "neck_posture": {
              "forward_head_posture": { "score": <0-10>, "note": "<head position relative to shoulders — from side photos>", "confidence": "<high|medium|low>" },
              "neck_definition": { "score": <0-10>, "note": "<jaw-to-neck angle, submental fat — from side photos>", "confidence": "<high|medium|low>" },
              "neck_skin_quality": { "score": <0-10>, "note": "<tech neck lines, laxity, creasing>", "confidence": "<high|medium|low>" }
            },
            "overall_impression": {
              "perceived_age": { "score": <0-10>, "note": "<looks older/younger than expected, aging indicators>", "confidence": "<high|medium|low>" },
              "overall_grooming": { "score": <0-10>, "note": "<general put-together-ness, neatness>", "confidence": "<high|medium|low>" },
              "facial_hydration": { "score": <0-10>, "note": "<overall plumpness vs dehydrated, skin turgor>", "confidence": "<high|medium|low>" }
            }
          },
          "routines": [
            {
              "name": "<routine name>",
              "category": "<face|hair|stubble>",
              "timeOfDay": "<morning|evening|weekly>",
              "scheduledWeekdays": [<1=Sun..7=Sat, empty array = every day>],
              "icon": "<SF Symbol name>",
              "displayOrder": <int, ordering within same category>,
              "steps": [
                {
                  "title": "<step name>",
                  "productName": "<specific product or ingredient to look for>",
                  "notes": "<1-2 sentences: technique, why it matters, common mistakes to avoid>",
                  "timerDuration": <seconds as integer, or null if no timer needed>
                }
              ]
            }
          ]
        }

        DERMATOLOGIST ROUTINE GUIDELINES — mirror how a real clinic would prescribe:

        FACE routines:
        - Morning (daily, scheduledWeekdays=[]): Cleanse (60s massage per the 60-second rule), Vitamin C serum (wait 30s to absorb), Moisturizer, Sunscreen SPF 30+. Sunscreen is NON-NEGOTIABLE even indoors — UV causes 90% of visible aging.
        - Evening (daily, scheduledWeekdays=[]): Cleanse (double-cleanse if sunscreen was worn), Treatment serum (niacinamide or retinol depending on concerns). Retinol: start 2-3x/week only — note this in the step. Moisturizer.
        - Weekly treatment (timeOfDay="weekly", scheduledWeekdays=[1] for Sunday): Chemical exfoliant (AHA/BHA) OR hydrating mask. NEVER exfoliate on shave days. 1x/week for beginners.
        - Adjust for skin type: oily → gel cleanser, lighter moisturizer, niacinamide. Dry → cream cleanser, richer moisturizer, hyaluronic acid. Sensitive → fragrance-free, skip actives initially.
        - Product layering order: thinnest to thickest. Serums before moisturizers. SPF always last in AM.

        HAIR routines:
        - Wash routine (2-3x/week for normal hair, adjust by type): Shampoo + Conditioner (mid-lengths to ends only, never on scalp). Match to hair type — oily/fine: more frequent; dry/curly: less frequent; thinning: every 2-3 days to let natural oils nourish follicles.
        - Scalp care (1x/week, scheduledWeekdays=[7] for Saturday): Scalp exfoliation to remove buildup and dead skin. Critical for hair health.
        - Deep conditioning (bi-weekly, scheduledWeekdays=[1] for Sunday): Hair mask or deep conditioner, especially for damaged/dry/color-treated hair.
        - If thinning is observed: daily lightweight scalp serum as a separate routine.

        STUBBLE/BEARD routines:
        - If facial hair is visible: Beard wash 2-3x/week (NOT regular soap — too harsh). Beard oil daily after shower. Beard balm for medium+ length.
        - Trim routine (2-3x/week for stubble, weekly for short beard): Precision trim + neckline/cheek line definition.
        - Exfoliation under beard (1x/week): Prevents ingrown hairs. Use soft brush or chemical exfoliant. NEVER double-exfoliate on shave days.
        - If clean-shaven: Skip stubble category entirely. Shaving itself is exfoliation — do NOT add a separate exfoliant on shave days.

        SCHEDULING:
        - scheduledWeekdays=[] means EVERY day (daily routines like AM/PM skincare).
        - [2,4,6] = Mon/Wed/Fri. [3,5,7] = Tue/Thu/Sat. [1] = Sunday. [7] = Saturday.
        - Spread routines across the week realistically. Don't stack too many treatments on one day.
        - Most men need 5-8 routines total across all categories with varied frequencies.

        GENERAL RULES:
        - Keep each routine 2-5 steps. Simplicity drives adherence.
        - Suggest affordable, widely available products: CeraVe, The Ordinary, La Roche-Posay, Neutrogena, Vanicream, Cetaphil, Bulldog, Duke Cannon.
        - Use valid SF Symbol names: "sun.max.fill", "moon.fill", "drop.fill", "scissors", "comb.fill", "humidity.fill", "leaf.fill", "sparkles".
        - timerDuration: 60 for cleansers (60-second rule), 30 for serums/actives absorption, 120 for masks, 300 for deep conditioners, null for trim/style steps.
        - In notes: include technique ("massage in circular motions"), reasoning ("removes oxidized SPF and pollution"), and common mistakes ("don't rinse within 5 seconds — a full 60 seconds of massaging makes a real difference").
        - Be specific about product types: "salicylic acid 2% cleanser" not just "cleanser", "broad-spectrum SPF 50 with zinc oxide" not just "sunscreen".

        Return ONLY valid JSON. No markdown.
        """

        let requestBody: [String: Any] = [
            "model": "gpt-4o",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userContent]
            ],
            "max_tokens": 6000,
            "response_format": ["type": "json_object"]
        ]

        let result = try await callOpenAI(apiKey: apiKey, body: requestBody)

        let skinAnalysis = result["skinAnalysis"] as? [String: Any] ?? result
        let suggestedRoutine = result["suggestedRoutine"] as? [String: Any]
            ?? result  // fallback: the whole result contains routines at top level

        return OnboardingResult(skinAnalysisJSON: skinAnalysis, suggestedRoutineJSON: suggestedRoutine)
    }

    // MARK: - OpenAI HTTP Helper

    private func callOpenAI(apiKey: String, body: [String: Any]) async throws -> [String: Any] {
        let jsonData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        request.timeoutInterval = 60

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            if let errorJSON = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorJSON["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw APIError.serverError(message)
            }
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw APIError.httpError(code)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String,
              let contentData = content.data(using: .utf8),
              let result = try JSONSerialization.jsonObject(with: contentData) as? [String: Any] else {
            throw APIError.invalidResponse
        }
        return result
    }

    // MARK: - Errors

    enum APIError: LocalizedError {
        case noAPIKey
        case invalidResponse
        case httpError(Int)
        case serverError(String)

        var errorDescription: String? {
            switch self {
            case .noAPIKey: return "No API key configured. Set one in Settings > Developer."
            case .invalidResponse: return "Could not parse API response."
            case .httpError(let code): return "API error (HTTP \(code))."
            case .serverError(let msg): return msg
            }
        }
    }
}
