import Foundation

/// The payloads for outfit advice, built apart from the network code so they can be checked without a network.
enum OutfitAdviceRequest {

    /// Body for the backend that release builds call: `POST analyze/outfit`.
    ///
    /// `goal` is only present when the user gave one. `StyleGoal` has already capped its length.
    static func backendBody(photoJPEG: Data, goal: StyleGoal?) -> [String: Any] {
        var body: [String: Any] = [
            "images": [["angle": "outfit", "data": photoJPEG.base64EncodedString()]]
        ]
        if let goal {
            body["goal"] = goal.text
        }
        return body
    }

    /// Body for the direct chat-completions call that debug builds make.
    static func chatCompletionBody(photoJPEG: Data, goal: StyleGoal?) -> [String: Any] {
        let userContent: [[String: Any]] = [
            ["type": "text", "text": FashionAdvicePrompt.userText(goal: goal)],
            [
                "type": "image_url",
                // "high" detail so shoes, cuffs and accessories stay legible.
                "image_url": [
                    "url": "data:image/jpeg;base64,\(photoJPEG.base64EncodedString())",
                    "detail": "high"
                ]
            ]
        ]

        return [
            "model": "gpt-4o",
            "messages": [
                ["role": "system", "content": FashionAdvicePrompt.systemPrompt],
                ["role": "user", "content": userContent]
            ],
            "max_tokens": 2500,
            "response_format": ["type": "json_object"]
        ]
    }

    /// Reads the backend's response body. Anything that isn't a JSON object, or that holds nothing
    /// to show, becomes an error the user can act on rather than a raw decoding failure.
    static func advice(fromBackendResponse data: Data) throws -> OutfitAdvice {
        guard let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            throw OutfitAdviceError.unusableResponse
        }
        return try OutfitAdvice.parse(json)
    }
}
