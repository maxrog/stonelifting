//
//  ImageUploadService.swift
//  StoneLifting
//
//  Created by Max Rogers on 9/16/25.
//

import Foundation
import UIKit
import Observation

// MARK: - Image Upload Service

/// Service for handling image uploads to the backend
@Observable
@MainActor
final class ImageUploadService {
    // MARK: - Properties

    static let shared = ImageUploadService()

    private let apiService = APIService.shared
    private let logger = AppLogger()

    private(set) var isUploading = false
    private(set) var uploadProgress: Double = 0.0
    private(set) var uploadError: Error?

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    /// Upload an image and return the URL
    /// - Parameter imageData: The image data to upload
    /// - Returns: The uploaded image URL, or nil if failed
    func uploadImage(_ imageData: Data) async -> String? {
        isUploading = true
        uploadProgress = 0.0
        uploadError = nil

        logger.info("Starting image upload, size: \(imageData.count) bytes")

        do {
            let (compressedData, base64Image) = await compressAndEncodeImage(imageData)

            logger.debug("Image compressed to \(compressedData.count) bytes, base64 encoded")

            // Check if task was cancelled (e.g., text moderation failed)
            if Task.isCancelled {
                logger.info("Image upload cancelled before network request")
                isUploading = false
                return nil
            }

            let request = ImageUploadRequest(
                imageData: base64Image,
                contentType: "image/jpeg"
            )

            // Use your existing API service
            let response = try await apiService.post(
                endpoint: "/upload/image",
                body: request,
                requiresAuth: true,
                responseType: ImageUploadResponse.self
            )

            isUploading = false
            uploadProgress = 1.0

            logger.info("Image uploaded successfully: \(response.imageUrl)")
            return response.imageUrl

        } catch {
            isUploading = false
            uploadError = error

            logger.error("Image upload failed", error: error)
            return nil
        }
    }

    /// Clear any upload error
    func clearError() {
        uploadError = nil
    }

    // MARK: - Private Methods

    /// Compress image data and encode to base64 for upload
    /// - Parameter imageData: Original image data
    /// - Returns: Tuple of (compressed data, base64 encoded string)
    private func compressAndEncodeImage(_ imageData: Data) async -> (Data, String) {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                guard let image = UIImage(data: imageData) else {
                    let base64 = imageData.base64EncodedString()
                    continuation.resume(returning: (imageData, base64))
                    return
                }

                // Max 1400px: Good detail for stone photos without excessive file size
                // Quality 0.7: Balances visual quality with bandwidth usage
                // Max 1.5MB: Reasonable for modern networks, stays under Cloudinary free tier
                // Expected file size: 500KB-1.2MB typical (supports ~15K uploads/month free)
                let maxDimension: CGFloat = 1400
                let originalSize = image.size
                let aspectRatio = originalSize.width / originalSize.height

                var targetSize: CGSize
                if originalSize.width > originalSize.height {
                    targetSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
                } else {
                    targetSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
                }

                // Resize if the image is larger than target
                let finalImage: UIImage
                if originalSize.width > maxDimension || originalSize.height > maxDimension {
                    finalImage = self.resizeImage(image, to: targetSize)
                } else {
                    finalImage = image
                }

                // Start with 0.7 quality (balanced quality/size ratio)
                var compressionQuality: CGFloat = 0.7
                var compressedData = finalImage.jpegData(compressionQuality: compressionQuality)

                // Progressively reduce quality if file exceeds 1.5MB
                // Stop at 0.5 quality minimum to maintain acceptable visual quality
                let maxFileSize = 1_500_000 // 1.5MB
                while let data = compressedData, data.count > maxFileSize && compressionQuality > 0.5 {
                    compressionQuality -= 0.05
                    compressedData = finalImage.jpegData(compressionQuality: compressionQuality)
                }

                let finalData = compressedData ?? imageData
                let base64Encoded = finalData.base64EncodedString()

                continuation.resume(returning: (finalData, base64Encoded))
            }
        }
    }

    /// Resize image to target size
    /// - Parameters:
    ///   - image: Original image
    ///   - targetSize: Target size
    /// - Returns: Resized image
    private func resizeImage(_ image: UIImage, to targetSize: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}

// MARK: - Request/Response Types

struct ImageUploadRequest: Codable {
    let imageData: String // base64 encoded
    let contentType: String
}

struct ImageUploadResponse: Codable {
    let success: Bool
    let imageUrl: String
    let message: String?
}

// MARK: - Image Upload Error

enum ImageUploadError: LocalizedError {
    case invalidImageData
    case networkError(Error)
    case serverError(String)
    case fileTooLarge
    case moderationFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidImageData:
            return "We couldn't process that image. Please try taking or selecting a different photo."
        case let .networkError(error):
            return "We're having trouble uploading your photo. Please check your connection and try again. (\(error.localizedDescription))"
        case let .serverError(message):
            return "We couldn't upload your photo right now. Please try again in a moment. (\(message))"
        case .fileTooLarge:
            return "That photo is too large to upload. Try taking a new photo or selecting a smaller one."
        case let .moderationFailed(message):
            return message
        }
    }
}
