//
//  ImageUploadService.swift
//  StoneLifting
//
//  Created by Max Rogers on 9/16/25.
//

import Foundation
import UIKit

// MARK: - Image Upload Service

/// Service for handling image uploads to the backend
@MainActor
final class ImageUploadService: ObservableObject {

    // MARK: - Properties

    static let shared = ImageUploadService()

    private let apiService = APIService.shared
    private let logger = AppLogger()

    @Published var isUploading = false
    @Published var uploadProgress: Double = 0.0
    @Published var uploadError: Error?

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
            // Compress image if needed
            let compressedData = await compressImageData(imageData)

            // Convert to base64 for JSON transport
            let base64Image = compressedData.base64EncodedString()

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

            await MainActor.run {
                self.isUploading = false
                self.uploadProgress = 1.0
            }

            logger.info("Image uploaded successfully: \(response.imageUrl)")
            return response.imageUrl

        } catch {
            await MainActor.run {
                self.isUploading = false
                self.uploadError = error
            }

            logger.error("Image upload failed", error: error)
            return nil
        }
    }

    /// Clear any upload error
    func clearError() {
        uploadError = nil
    }

    // MARK: - Private Methods

    /// Compress image data for upload
    /// - Parameter imageData: Original image data
    /// - Returns: Compressed image data
    private func compressImageData(_ imageData: Data) async -> Data {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                guard let image = UIImage(data: imageData) else {
                    continuation.resume(returning: imageData)
                    return
                }

                // TODO check if reasonable for deployment
                let maxDimension: CGFloat = 1200
                let originalSize = image.size
                let aspectRatio = originalSize.width / originalSize.height

                var targetSize: CGSize
                if originalSize.width > originalSize.height {
                    targetSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
                } else {
                    targetSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
                }

                // resize if the image is larger than target
                let finalImage: UIImage
                if originalSize.width > maxDimension || originalSize.height > maxDimension {
                    finalImage = self.resizeImage(image, to: targetSize)
                } else {
                    finalImage = image
                }

                // TODO check if reasonable for deployment
                var compressionQuality: CGFloat = 0.6
                var compressedData = finalImage.jpegData(compressionQuality: compressionQuality)

                // TODO check if reasonable for deployment
                // Reduce quality if file is still too large (> 1MB)
                while let data = compressedData, data.count > 1_000_000 && compressionQuality > 0.3 {
                    compressionQuality -= 0.1
                    compressedData = finalImage.jpegData(compressionQuality: compressionQuality)
                }

                continuation.resume(returning: compressedData ?? imageData)
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

    var errorDescription: String? {
        switch self {
        case .invalidImageData:
            return "Invalid image data"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .serverError(let message):
            return "Server error: \(message)"
        case .fileTooLarge:
            return "Image file is too large"
        }
    }
}
