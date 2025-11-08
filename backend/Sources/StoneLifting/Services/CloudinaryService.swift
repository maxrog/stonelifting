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
            "folder": folder
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
        return cloudinaryResponse.secureUrl
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

    enum CodingKeys: String, CodingKey {
        case secureUrl = "secure_url"
        case publicId = "public_id"
        case format
        case width
        case height
        case bytes
    }
}

// MARK: - Errors

enum CloudinaryError: Error, LocalizedError {
    case uploadFailed(String)
    case invalidConfiguration

    var errorDescription: String? {
        switch self {
        case .uploadFailed(let message):
            return "Cloudinary upload failed: \(message)"
        case .invalidConfiguration:
            return "Cloudinary configuration is invalid or missing"
        }
    }
}
