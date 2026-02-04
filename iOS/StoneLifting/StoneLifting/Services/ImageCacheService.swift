//
//  ImageCacheService.swift
//  StoneAtlas
//
//  Created by Max Rogers on 1/6/26.
//

import UIKit
import SwiftUI
import Observation

// MARK: - Image Cache Service

/// Service for caching downloaded images to reduce network usage and improve performance
@Observable
final class ImageCacheService {
    // MARK: - Properties

    static let shared = ImageCacheService()
    private let logger = AppLogger()

    private let cache = NSCache<NSString, UIImage>()

    // Track ongoing downloads to prevent duplicate requests
    private var ongoingDownloads: [String: Task<UIImage?, Never>] = [:]

    // MARK: - Initialization

    private init() {
        // Configure cache limits
        // Memory limit: 100MB (can hold ~100-150 stone images at 1400px)
        cache.totalCostLimit = 100 * 1024 * 1024 // 100MB
        cache.countLimit = 200

        logger.info("ImageCacheService initialized with 100MB cache limit")
    }

    // MARK: - Public Methods

    /// Get image from cache or download if not cached
    /// - Parameter url: Image URL string
    /// - Returns: UIImage if available, nil otherwise
    func image(for urlString: String) async -> UIImage? {
        // Check memory cache first
        if let cachedImage = cache.object(forKey: urlString as NSString) {
            logger.debug("Image cache hit: \(urlString)")
            return cachedImage
        }

        // Check if already downloading
        let existingTask = await getOngoingDownload(for: urlString)
        if let ongoingTask = existingTask {
            logger.debug("Image download already in progress: \(urlString)")
            return await ongoingTask.value
        }

        // Start new download
        logger.debug("Image cache miss, downloading: \(urlString)")
        let downloadTask = Task<UIImage?, Never> {
            await downloadImage(from: urlString)
        }

        await setOngoingDownload(downloadTask, for: urlString)
        let image = await downloadTask.value
        await removeOngoingDownload(for: urlString)

        return image
    }

    @MainActor
    private func getOngoingDownload(for urlString: String) -> Task<UIImage?, Never>? {
        return ongoingDownloads[urlString]
    }

    @MainActor
    private func setOngoingDownload(_ task: Task<UIImage?, Never>, for urlString: String) {
        ongoingDownloads[urlString] = task
    }

    @MainActor
    private func removeOngoingDownload(for urlString: String) {
        ongoingDownloads.removeValue(forKey: urlString)
    }

    /// Preload images for upcoming content (e.g., next items in scroll)
    /// - Parameter urls: Array of image URL strings to preload
    func preloadImages(_ urlStrings: [String]) {
        Task {
            for urlString in urlStrings {
                // Skip if already cached
                guard cache.object(forKey: urlString as NSString) == nil else { continue }

                // Skip if already downloading
                let isDownloading = await getOngoingDownload(for: urlString) != nil
                guard !isDownloading else { continue }

                // Download in background
                _ = await image(for: urlString)
            }
        }
    }

    func clearCache() {
        cache.removeAllObjects()
        logger.info("Cleared image cache")
    }

    /// Get cache statistics
    func getCacheStats() -> (count: Int, memoryUsage: String) {
        // NSCache doesn't expose current memory usage, but we can estimate
        let count = cache.countLimit // This is not exact, but gives an idea
        return (count, "~\(cache.totalCostLimit / (1024 * 1024))MB limit")
    }

    // MARK: - Private Methods

    private func downloadImage(from urlString: String) async -> UIImage? {
        guard let url = URL(string: urlString) else {
            logger.warning("Invalid image URL: \(urlString)")
            return nil
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                logger.error("Failed to download image: HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")
                return nil
            }

            guard let image = UIImage(data: data) else {
                logger.error("Failed to decode image from data")
                return nil
            }

            // Calculate approximate memory cost (width * height * 4 bytes per pixel)
            let cost = Int(image.size.width * image.size.height * 4)

            // Cache the image
            cache.setObject(image, forKey: urlString as NSString, cost: cost)

            logger.debug("Downloaded and cached image: \(urlString) (\(data.count / 1024)KB)")
            return image

        } catch {
            logger.error("Error downloading image: \(urlString)", error: error)
            return nil
        }
    }
}
