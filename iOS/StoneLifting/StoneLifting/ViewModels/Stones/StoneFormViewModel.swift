//
//  StoneFormViewModel.swift
//  StoneLifting
//
//  Created by Max Rogers on 11/09/25.
//

import Foundation
import Observation

// MARK: - Stone Form View Model

/// ViewModel for both AddStoneView and EditStoneView
/// Manages stone creation and editing with photo upload
@Observable
final class StoneFormViewModel {
    // MARK: - Properties

    private let stoneService = StoneService.shared
    private let imageUploadService = ImageUploadService.shared
    private let logger = AppLogger()

    /// Optional stone ID - if nil, creating new stone; if set, editing existing
    private let stoneId: UUID?

    // UI State
    var isLoading = false
    var stoneError: StoneError?

    // MARK: - Initialization

    /// Initialize for creating a new stone
    init() {
        stoneId = nil
    }

    /// Initialize for editing an existing stone
    /// - Parameter stoneId: ID of the stone to edit
    init(stoneId: UUID) {
        self.stoneId = stoneId
    }

    // MARK: - Computed Properties

    var isEditing: Bool {
        stoneId != nil
    }

    // MARK: - Actions

    /// Save stone (create or update based on stoneId)
    /// - Parameters:
    ///   - request: Stone data request
    ///   - photoData: Optional photo data to upload
    ///   - hasPhotoChanged: Whether photo was modified (only relevant for editing)
    /// - Returns: Created or updated stone if successful, nil otherwise
    @MainActor
    func saveStone(request: CreateStoneRequest, photoData: Data?, hasPhotoChanged: Bool = true) async -> Stone? {
        logger.info("Starting stone save operation (isEditing: \(isEditing))")

        isLoading = true
        stoneError = nil

        // Start text moderation
        async let moderationTask = stoneService.moderateText(
            name: request.name,
            description: request.description
        )

        // Start image upload in a cancellable task
        let imageUploadTask = Task<String?, Never> {
            await uploadPhotoIfNeeded(
                photoData: photoData,
                hasPhotoChanged: hasPhotoChanged
            )
        }

        // Check text moderation first (fail fast)
        let moderation = await moderationTask
        if let moderation = moderation, !moderation.passed {
            logger.warning("Pre-flight moderation failed: \(moderation.reason ?? "Unknown reason")")
            logger.info("Cancelling image upload task to save bandwidth")
            imageUploadTask.cancel()
            stoneError = .moderationFailed(moderation.reason ?? "Content contains inappropriate language")
            isLoading = false
            return nil
        }

        logger.info("Pre-flight moderation passed")

        // Now wait for image upload to complete
        let uploadedImageURL = await imageUploadTask.value

        // Check if photo upload failed when photo was provided
        if photoData != nil, hasPhotoChanged, uploadedImageURL == nil {
            logger.error("Failed to upload image for stone")

            let errorMessage = imageUploadService.uploadError?.localizedDescription
                ?? "We couldn't upload your photo. You can try again or save your stone without a photo for now."

            stoneError = .imageUploadFailed(errorMessage)
            isLoading = false
            return nil
        }

        if uploadedImageURL != nil {
            logger.info("Image uploaded successfully, URL: \(uploadedImageURL ?? "")")
        }

        // Determine final image URL:
        // - If photo changed and uploaded: use new URL
        // - If photo didn't change: preserve original URL
        // - If photo was removed: use nil
        let finalImageURL: String?
        if hasPhotoChanged {
            finalImageURL = uploadedImageURL
        } else {
            finalImageURL = request.imageUrl
        }

        let finalRequest = CreateStoneRequest(
            name: request.name,
            weight: request.weight,
            estimatedWeight: request.estimatedWeight,
            stoneType: request.stoneType,
            description: request.description,
            imageUrl: finalImageURL,
            latitude: request.latitude,
            longitude: request.longitude,
            isPublic: request.isPublic,
            liftingLevel: request.liftingLevel
        )

        // Create or update stone
        let stone: Stone?
        if let stoneId = stoneId {
            // Editing existing stone
            logger.info("Updating stone with ID: \(stoneId)")
            stone = await stoneService.updateStone(id: stoneId, with: finalRequest)
            if stone != nil {
                logger.info("Stone updated successfully with ID: \(stoneId)")
            } else {
                logger.error("Failed to update stone with ID: \(stoneId)")
            }
        } else {
            // Creating new stone
            logger.info("Creating new stone with name: \(finalRequest.name ?? "unnamed"), weight: \(finalRequest.weight)")
            stone = await stoneService.createStone(finalRequest)
            if let stone = stone {
                logger.info("Stone created successfully with ID: \(stone.id?.uuidString ?? "unknown")")
            } else {
                logger.error("Failed to create stone")
            }
        }

        // Set error if operation failed - stoneError has detailed backend error messages
        if stone == nil {
            stoneError = stoneService.stoneError
            logger.error("Stone service error: \(stoneError?.localizedDescription ?? "Unknown error")")
        }

        isLoading = false
        logger.info("Stone save operation completed (success: \(stone != nil))")
        return stone
    }

    // MARK: - Private Methods

    /// Upload photo if needed based on photo data and change status
    /// - Parameters:
    ///   - photoData: Optional photo data
    ///   - hasPhotoChanged: Whether photo was changed
    /// - Returns: Image URL if upload successful, nil if no upload needed or failed
    private func uploadPhotoIfNeeded(photoData: Data?, hasPhotoChanged: Bool) async -> String? {
        // Only upload if photo exists and has changed
        guard hasPhotoChanged, let photoData = photoData else {
            // If photo was removed (hasPhotoChanged but no data), return nil
            if hasPhotoChanged, photoData == nil {
                logger.info("Photo removed by user")
                return nil
            }
            // Otherwise return original image URL from request
            logger.info("Photo unchanged, skipping upload")
            return nil
        }

        logger.info("Uploading \(isEditing ? "new" : "") image for stone (size: \(photoData.count) bytes)")
        let imageURL = await imageUploadService.uploadImage(photoData)

        if imageURL != nil {
            logger.info("Image upload completed successfully")
        } else {
            logger.error("Image upload failed")
        }

        return imageURL
    }

    /// Clear error state
    func clearError() {
        logger.info("Clearing error state")
        stoneError = nil
        stoneService.clearError()
    }
}
