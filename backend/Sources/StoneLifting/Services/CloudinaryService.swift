import Vapor
import Crypto

/// Service for uploading images to Cloudinary
/// Handles image upload to cloud storage with automatic CDN delivery
struct CloudinaryService {

    private let cloudName: String
    private let apiKey: String
    private let apiSecret: String

    init(cloudName: String, apiKey: String, apiSecret: String) {
        self.cloudName = cloudName
        self.apiKey = apiKey
        self.apiSecret = apiSecret
    }

    /// Upload image data to Cloudinary
    /// - Parameters:
    ///   - imageData: Raw image data (JPEG/PNG)
    ///   - publicId: Optional custom public ID for the image
    ///   - folder: Optional folder path in Cloudinary
    ///   - client: Vapor HTTP client
    /// - Returns: Secure URL of uploaded image
    func uploadImage(
        _ imageData: Data,
        publicId: String? = nil,
        folder: String = "stonelifting",
        on client: any Client
    ) async throws -> String {

        // Cloudinary upload URL
        let uploadURL = URI(string: "https://api.cloudinary.com/v1_1/\(cloudName)/image/upload")

        // Generate timestamp for signature
        let timestamp = String(Int(Date().timeIntervalSince1970))

        // Build parameters for signature
        var params: [String: String] = [
            "timestamp": timestamp,
            "folder": folder,
            "moderation": "aws_rek:explicit,aws_rek:suggestive,aws_rek:violence"
        ]

        if let publicId = publicId {
            params["public_id"] = publicId
        }

        // Generate signature
        let signature = generateSignature(params: params)

        // Create form data
        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()

        // Helper to append form field
        func appendFormField(named name: String, value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }

        // Add text fields
        appendFormField(named: "api_key", value: apiKey)
        appendFormField(named: "timestamp", value: timestamp)
        appendFormField(named: "signature", value: signature)
        appendFormField(named: "folder", value: folder)
        appendFormField(named: "moderation", value: "aws_rek:explicit,aws_rek:suggestive,aws_rek:violence")

        if let publicId = publicId {
            appendFormField(named: "public_id", value: publicId)
        }

        // Add image file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"image.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)

        // Add closing boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        // Create request
        var headers = HTTPHeaders()
        headers.add(name: .contentType, value: "multipart/form-data; boundary=\(boundary)")

        let response = try await client.post(uploadURL, headers: headers) { req in
            req.body = ByteBuffer(data: body)
        }

        // Parse response
        guard response.status == .ok else {
            let errorBody = response.body.map { String(buffer: $0) } ?? "Unknown error"
            throw CloudinaryError.uploadFailed("Upload failed with status: \(response.status), body: \(errorBody)")
        }

        let cloudinaryResponse = try response.content.decode(CloudinaryUploadResponse.self)

        // Check moderation status
        try checkModeration(cloudinaryResponse.moderation)

        return cloudinaryResponse.secureUrl
    }

    /// Check moderation results and throw if image is inappropriate
    private func checkModeration(_ moderation: [CloudinaryModerationResult]?) throws {
        guard let moderationResults = moderation else {
            // If no moderation results, allow the upload (shouldn't happen with moderation enabled)
            return
        }

        for result in moderationResults {
            // AWS Rekognition results
            if result.kind == "aws_rek" {
                if let explicit = result.response?.moderation_labels?.first(where: { $0.name == "Explicit Nudity" }),
                   explicit.confidence > 70 {
                    throw CloudinaryError.moderationFailed("Image contains explicit nudity and cannot be uploaded")
                }

                if let suggestive = result.response?.moderation_labels?.first(where: { $0.name == "Suggestive" }),
                   suggestive.confidence > 85 {
                    throw CloudinaryError.moderationFailed("Image contains suggestive content and cannot be uploaded")
                }

                if let violence = result.response?.moderation_labels?.first(where: { $0.name == "Violence" }),
                   violence.confidence > 80 {
                    throw CloudinaryError.moderationFailed("Image contains violent content and cannot be uploaded")
                }
            }
        }
    }

    /// Generate signature for Cloudinary API authentication
    /// Uses SHA-1 hash as required by Cloudinary
    private func generateSignature(params: [String: String]) -> String {
        // Sort parameters alphabetically and concatenate
        let sortedParams = params.sorted { $0.key < $1.key }
        let paramString = sortedParams
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")

        // Append API secret
        let stringToSign = paramString + apiSecret

        // Generate SHA-1 hash
        let hash = Insecure.SHA1.hash(data: Data(stringToSign.utf8))
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Response Models

struct CloudinaryUploadResponse: Content {
    let secureUrl: String
    let publicId: String
    let format: String
    let width: Int
    let height: Int
    let bytes: Int
    let moderation: [CloudinaryModerationResult]?

    enum CodingKeys: String, CodingKey {
        case secureUrl = "secure_url"
        case publicId = "public_id"
        case format
        case width
        case height
        case bytes
        case moderation
    }
}

struct CloudinaryModerationResult: Content {
    let kind: String
    let status: String
    let response: CloudinaryModerationResponse?
}

struct CloudinaryModerationResponse: Content {
    let moderation_labels: [CloudinaryModerationLabel]?
}

struct CloudinaryModerationLabel: Content {
    let name: String
    let confidence: Double
    let parent_name: String?
}

// MARK: - Errors

enum CloudinaryError: Error, LocalizedError {
    case uploadFailed(String)
    case invalidConfiguration
    case moderationFailed(String)

    var errorDescription: String? {
        switch self {
        case .uploadFailed(let message):
            return "Cloudinary upload failed: \(message)"
        case .invalidConfiguration:
            return "Cloudinary configuration is invalid or missing"
        case .moderationFailed(let message):
            return message
        }
    }
}
