import Vapor

/// Service for moderating user-generated text using OpenAI Moderation API
struct ModerationService {

    private let apiKey: String

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    /// Moderates text content using OpenAI Moderation API with retry logic for rate limits
    /// - Parameters:
    ///   - text: The text content to moderate
    ///   - client: Vapor HTTP client
    ///   - attempt: Current retry attempt (for internal use)
    /// - Returns: Result indicating if content is appropriate
    /// - Throws: Error if API request fails after retries
    func moderateText(_ text: String?, on client: any Client, attempt: Int = 1) async throws -> ModerationResult {

        guard let text, !text.isEmpty else {
            return ModerationResult(flagged: false, categories: [:])
        }

        do {
            let response = try await client.post("https://api.openai.com/v1/moderations") { req in
                req.headers.bearerAuthorization = .init(token: apiKey)
                req.headers.contentType = .json
                try req.content.encode(
                    ModerationRequest(
                        model: "omni-moderation-latest",
                        input: text
                    )
                )
            }

            if response.status == .tooManyRequests {
                if attempt < 3 {
                    try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt)) * 1_000_000_000))
                    return try await moderateText(text, on: client, attempt: attempt + 1)
                }

                throw Abort(
                    .serviceUnavailable,
                    reason: "Content moderation is temporarily unavailable. Please try again shortly."
                )
            }

            guard response.status == .ok else {
                let error = try response.content.decode(OpenAIErrorResponse.self)
                throw Abort(.serviceUnavailable, reason: error.error.message)
            }

            let moderation = try response.content.decode(ModerationResponse.self)

            guard let result = moderation.results.first else {
                throw Abort(.internalServerError, reason: "Empty moderation response")
            }

            return ModerationResult(flagged: result.flagged, categories: result.categories)

        } catch {
            throw Abort(
                .serviceUnavailable,
                reason: "Content moderation is temporarily unavailable. Please try again shortly."
            )
        }
    }

    /// Moderates multiple text fields at once by combining them into a single API call
    /// - Parameters:
    ///   - fields: Dictionary of field names to text content
    ///   - client: Vapor HTTP client
    /// - Returns: Result with flagged fields
    /// - Throws: Error if moderation fails
    func moderateFields(_ fields: [String: String?], on client: any Client) async throws -> MultiFieldModerationResult {
        // Combine all non-empty fields into a single text for efficient API usage
        let nonEmptyFields = fields.filter { _, value in
            guard let value = value, !value.isEmpty else { return false }
            return true
        }

        // If no fields to moderate, return clean result
        guard !nonEmptyFields.isEmpty else {
            return MultiFieldModerationResult(
                flagged: false,
                flaggedFields: [],
                categories: [:]
            )
        }

        // Combine all text with field labels to identify which field is problematic
        let combinedText = nonEmptyFields.map { fieldName, text in
            "\(fieldName): \(text ?? "")"
        }.joined(separator: "\n")

        // Make single API call with combined text
        let result = try await moderateText(combinedText, on: client)

        // If flagged, we can't determine which specific field, so mark all as potentially problematic
        if result.flagged {
            return MultiFieldModerationResult(
                flagged: true,
                flaggedFields: Array(nonEmptyFields.keys),
                categories: result.categories
            )
        }

        return MultiFieldModerationResult(
            flagged: false,
            flaggedFields: [],
            categories: [:]
        )
    }
}

// MARK: - Request/Response Models

struct ModerationRequest: Content {
    let model: String
    let input: String
}

struct ModerationResponse: Content {
    let id: String
    let model: String
    let results: [ModerationResultDetail]
}

struct OpenAIErrorResponse: Content {
    let error: OpenAIError

    struct OpenAIError: Content {
        let message: String
        let type: String?
        let code: String?
    }
}

struct ModerationResultDetail: Content {
    let flagged: Bool
    let categories: [String: Bool]
    let categoryScores: [String: Double]

    enum CodingKeys: String, CodingKey {
        case flagged
        case categories
        case categoryScores = "category_scores"
    }
}

// MARK: - Result Models

struct ModerationResult {
    let flagged: Bool
    let categories: [String: Bool]

    var flaggedCategoriesDescription: String {
        let flaggedCategories = categories.filter { $0.value }.keys
        if flaggedCategories.isEmpty {
            return ""
        }
        return flaggedCategories.joined(separator: ", ")
    }
}

struct MultiFieldModerationResult {
    let flagged: Bool
    let flaggedFields: [String]
    let categories: [String: Bool]

    var errorMessage: String {
        if !flagged {
            return ""
        }

        let fieldsList = flaggedFields.joined(separator: ", ")
        return "Your \(fieldsList) contains inappropriate content. Please revise and try again."
    }
}
