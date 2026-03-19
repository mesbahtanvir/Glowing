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
            ["type": "text", "text": "Here are 3 face photos (front, left, right). Analyze them together for a comprehensive skin assessment."]
        ]

        for image in images {
            userContent.append(["type": "text", "text": "[\(image.angle) view]:"])
            userContent.append([
                "type": "image_url",
                "image_url": ["url": "data:image/jpeg;base64,\(image.base64Data)"]
            ])
        }

        let systemPrompt = """
        You are a men's skincare and hair health consultant with dermatology training. You have HIGH STANDARDS. A 7/10 means genuinely good, 8+ is exceptional. Most people should score 4-6.

        Cross-reference all 3 angles (front, left, right) together. Analyze both skin and hair health.

        SCORING RULES:
        - 9-10: Near-flawless. Almost nobody gets this.
        - 7-8: Genuinely good, minor issues only.
        - 5-6: Average. Noticeable issues that need attention.
        - 3-4: Below average. Multiple visible problems.
        - 1-2: Significant issues requiring immediate attention.
        - Be SPECIFIC in notes — say exactly where the issue is.

        Return a JSON object:

        {
          "overallScore": <0-100 integer, most people should be 40-65>,
          "summary": "<2-3 sentences. Be direct. Tell them what stands out and what to fix first.>",
          "acne": { "score": <0-10>, "note": "<exact locations — chin, forehead, left cheek, etc. Note active vs scarred>" },
          "texture": { "score": <0-10>, "note": "<roughness, bumps, flaking — compare T-zone vs cheeks vs sides>" },
          "hydration": { "score": <0-10>, "note": "<oily zones, dry patches, flaking, dehydration lines>" },
          "darkCircles": { "score": <0-10>, "note": "<color (purple, brown, blue), puffiness, hollowness>" },
          "redness": { "score": <0-10>, "note": "<rosacea-like, irritation, razor burn, location>" },
          "skinTone": { "score": <0-10>, "note": "<unevenness, tan lines, sun damage per area>" },
          "skinType": "<one of: oily, dry, combination, normal, sensitive>",
          "faceShape": "<one of: oval, round, square, oblong, heart, diamond, triangle>",
          "leftSideNote": "<1-2 sentences on left profile specifics>",
          "rightSideNote": "<1-2 sentences on right profile specifics>",
          "recommendations": "<3-5 specific product/ingredient suggestions as bullet points separated by newlines>",
          "hairOverall": { "score": <0-10>, "note": "<overall hair health assessment>" },
          "hairline": { "score": <0-10>, "note": "<recession, density at temples>" },
          "hairThickness": { "score": <0-10>, "note": "<thickness, volume assessment>" },
          "hairCondition": { "score": <0-10>, "note": "<damage, split ends, dryness>" },
          "scalpHealth": { "score": <0-10>, "note": "<dandruff, irritation, oiliness>" },
          "hairType": "<straight/wavy/curly/coily>"
        }

        Return ONLY valid JSON. No markdown, no explanation outside the JSON.
        """

        let requestBody: [String: Any] = [
            "model": "gpt-4o",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userContent]
            ],
            "max_tokens": 1500,
            "response_format": ["type": "json_object"]
        ]

        return try await callOpenAI(apiKey: apiKey, body: requestBody)
    }

    private func analyzeOnboardingDirect(images: [AnalysisImage]) async throws -> OnboardingResult {
        guard let apiKey = KeychainHelper.read(key: "com.glowing.openai-api-key") else {
            throw APIError.noAPIKey
        }

        let introText = "Here are 3 photos (front, left, right) of a man's face and hair. Analyze skin, hair, and facial hair health. Generate personalized routines for all three categories."

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
        You are a board-certified dermatologist and licensed trichologist consulting with a male patient. You have HIGH STANDARDS and give evidence-based recommendations. Analyze the photos for skin, hair, and facial hair/stubble health.

        Return a JSON object with two sections:

        {
          "skinAnalysis": {
            "overallScore": <0-100, most people 40-65>,
            "summary": "<2-3 sentences. Be direct and clinical.>",
            "acne": { "score": <0-10>, "note": "<exact locations and severity>" },
            "texture": { "score": <0-10>, "note": "<pore size, roughness, scarring>" },
            "hydration": { "score": <0-10>, "note": "<dehydration signs, barrier health>" },
            "darkCircles": { "score": <0-10>, "note": "<pigmentation vs vascular>" },
            "redness": { "score": <0-10>, "note": "<rosacea indicators, irritation>" },
            "skinTone": { "score": <0-10>, "note": "<evenness, hyperpigmentation>" },
            "skinType": "<oily/dry/combination/normal/sensitive>",
            "faceShape": "<oval/round/square/oblong/heart/diamond/triangle>",
            "hairOverall": { "score": <0-10>, "note": "<overall hair health>" },
            "hairline": { "score": <0-10>, "note": "<recession pattern, density>" },
            "hairThickness": { "score": <0-10>, "note": "<caliber, volume>" },
            "hairCondition": { "score": <0-10>, "note": "<damage, porosity, dryness>" },
            "scalpHealth": { "score": <0-10>, "note": "<flaking, irritation, buildup>" },
            "hairType": "<straight/wavy/curly/coily>",
            "recommendations": "<3-5 bullet points with clinical reasoning>"
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
            "max_tokens": 4000,
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
