//
//  StoneCacheService.swift
//  StoneLifting
//
//  Created by Max Rogers on 1/8/26.
//

import Foundation
import SwiftData

// MARK: - Stone Cache Service

/// Manages local caching of stones for offline viewing
///
/// Caching Strategy:
/// - Cache is updated on:
///   1. App launch (ensures fresh offline data)
///   2. Pull-to-refresh (keeps cache synchronized)
///   3. Background → foreground (if > 5 min and online)
///   4. After creating/editing/deleting stones (keeps cache in sync)
///   5. Viewing nearby stones (accumulates visited areas)
/// - Cache is NOT updated on:
///   - View loads/tab switching (uses in-memory data)
///
/// Cache Patterns:
/// - ALL categories use upsert pattern (update existing, insert new, delete stale)
/// - userStones/publicStones: Full replacement (delete stale entries)
/// - nearbyStones: Accumulation (keep all, no deletions)
///
// MARK: - Cache Errors

enum StoneCacheError: Error, LocalizedError {
    case notConfigured
    case fetchFailed(Error)
    case saveFailed(Error)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Cache service not properly configured"
        case .fetchFailed(let error):
            return "Failed to fetch cached stones: \(error.localizedDescription)"
        case .saveFailed(let error):
            return "Failed to save to cache: \(error.localizedDescription)"
        }
    }
}

@Observable
final class StoneCacheService {
    // MARK: - Properties

    static let shared = StoneCacheService()
    private let logger = AppLogger()
    private var cacheActor: StoneCacheActor?

    // MARK: - Initialization

    private init() {
        logger.info("StoneCacheService initialized")
    }

    func configure(with container: ModelContainer) {
        self.cacheActor = StoneCacheActor(modelContainer: container)
        logger.info("StoneCacheService configured with background actor")
    }

    // MARK: - Cache Operations

    /// Cache multiple stone categories in a single batch operation
    /// Runs in background thread for performance
    /// - Parameter batches: Array of (stones, category) tuples to cache
    /// - Throws: StoneCacheError if operation fails
    func cacheStonesInBatch(_ batches: [([Stone], CacheCategory)]) async throws {
        guard let actor = cacheActor else {
            logger.error("Cache actor not configured")
            throw StoneCacheError.notConfigured
        }

        do {
            try await actor.cacheStonesInBatch(batches)
        } catch {
            logger.error("Failed to batch cache stones", error: error)
            throw StoneCacheError.saveFailed(error)
        }
    }

    /// Cache stones for a single category
    /// Runs in background thread for performance
    /// - Parameters:
    ///   - stones: Stones to cache
    ///   - category: Cache category
    /// - Throws: StoneCacheError if operation fails
    func cacheStones(_ stones: [Stone], category: CacheCategory) async throws {
        guard let actor = cacheActor else {
            logger.error("Cache actor not configured")
            throw StoneCacheError.notConfigured
        }

        do {
            try await actor.cacheStones(stones, category: category)
        } catch {
            logger.error("Failed to cache stones", error: error)
            throw StoneCacheError.saveFailed(error)
        }
    }

    /// Fetch cached stones for a category
    /// Runs in background thread for performance
    /// - Parameter category: Cache category to fetch
    /// - Returns: Cached stones
    /// - Throws: StoneCacheError if operation fails
    func fetchCachedStones(category: CacheCategory) async throws -> [Stone] {
        guard let actor = cacheActor else {
            logger.error("Cache actor not configured")
            throw StoneCacheError.notConfigured
        }

        do {
            return try await actor.fetchCachedStones(category: category)
        } catch {
            logger.error("Failed to fetch cached stones", error: error)
            throw StoneCacheError.fetchFailed(error)
        }
    }

    /// Clear cache for a specific category
    /// Runs in background thread for performance
    /// - Parameter category: Category to clear
    /// - Throws: StoneCacheError if operation fails
    func clearCache(for category: CacheCategory) async throws {
        guard let actor = cacheActor else {
            logger.error("Cache actor not configured")
            throw StoneCacheError.notConfigured
        }

        do {
            try await actor.clearCache(for: category)
        } catch {
            logger.error("Failed to clear cache", error: error)
            throw StoneCacheError.saveFailed(error)
        }
    }
}

// MARK: - Stone Cache Actor

/// Thread-safe actor for performing cache operations in background
/// Uses ModelActor pattern for safe concurrent access to SwiftData
@ModelActor
actor StoneCacheActor {
    private let logger = AppLogger()

    // MARK: - Cache Operations

    /// Cache multiple stone categories in a single batch operation
    /// Uses upsert pattern: updates existing, inserts new, deletes stale
    /// Runs in background thread, returns when complete
    func cacheStonesInBatch(_ batches: [([Stone], CacheCategory)]) throws {
        logger.info("Background: Batch caching \(batches.count) categories")

        let context = modelContext
        context.autosaveEnabled = false

        var totalInserted = 0
        var totalUpdated = 0
        var totalDeleted = 0

        // Process each category
        for (stones, category) in batches {
            // Fetch existing cached stones for this category
            let categoryRawValue = category.rawValue
            let descriptor = FetchDescriptor<CachedStone>(
                predicate: #Predicate { cached in
                    cached.categoryRawValue == categoryRawValue
                }
            )

            let existingCached = try context.fetch(descriptor)

            // Build lookup dictionaries
            var existingById: [UUID: CachedStone] = [:]
            for cached in existingCached {
                existingById[cached.id] = cached
            }

            var serverIds = Set<UUID>()

            // Upsert each stone
            for stone in stones {
                guard let stoneId = stone.id else { continue }
                guard let stoneData = try? JSONEncoder().encode(stone) else { continue }

                serverIds.insert(stoneId)

                if let existing = existingById[stoneId] {
                    // Update existing
                    existing.stoneData = stoneData
                    existing.cachedAt = Date()
                    totalUpdated += 1
                } else {
                    // Insert new
                    let cached = CachedStone(
                        id: stoneId,
                        stoneData: stoneData,
                        category: category,
                        cachedAt: Date()
                    )
                    context.insert(cached)
                    totalInserted += 1
                }
            }

            // Delete stale entries (full replacement for userStones/publicStones)
            // For nearbyStones, we want to keep accumulating, so we skip deletion
            if category != .nearbyStones {
                for (id, cached) in existingById {
                    if !serverIds.contains(id) {
                        context.delete(cached)
                        totalDeleted += 1
                    }
                }
            }
        }

        // Save everything in one transaction
        try context.save()
        logger.info("Background: Batch cache complete - \(totalInserted) new, \(totalUpdated) updated, \(totalDeleted) deleted")
    }

    /// Cache stones for a single category
    /// Uses upsert pattern: updates existing, inserts new, deletes stale (except nearbyStones)
    func cacheStones(_ stones: [Stone], category: CacheCategory) throws {
        logger.info("Background: Caching \(stones.count) stones for \(category.rawValue)")

        let context = modelContext
        context.autosaveEnabled = false

        // Fetch existing cached stones for this category
        let categoryRawValue = category.rawValue
        let descriptor = FetchDescriptor<CachedStone>(
            predicate: #Predicate { cached in
                cached.categoryRawValue == categoryRawValue
            }
        )

        let existingCached = try context.fetch(descriptor)

        // Build lookup dictionaries
        var existingById: [UUID: CachedStone] = [:]
        for cached in existingCached {
            existingById[cached.id] = cached
        }

        var serverIds = Set<UUID>()
        var insertedCount = 0
        var updatedCount = 0

        // Upsert each stone
        for stone in stones {
            guard let stoneId = stone.id else { continue }
            guard let stoneData = try? JSONEncoder().encode(stone) else { continue }

            serverIds.insert(stoneId)

            if let existing = existingById[stoneId] {
                // Update existing
                existing.stoneData = stoneData
                existing.cachedAt = Date()
                updatedCount += 1
            } else {
                // Insert new
                let cached = CachedStone(
                    id: stoneId,
                    stoneData: stoneData,
                    category: category,
                    cachedAt: Date()
                )
                context.insert(cached)
                insertedCount += 1
            }
        }

        // Delete stale entries (full replacement for userStones/publicStones)
        // For nearbyStones, we want to keep accumulating, so we skip deletion
        var deletedCount = 0
        if category != .nearbyStones {
            for (id, cached) in existingById {
                if !serverIds.contains(id) {
                    context.delete(cached)
                    deletedCount += 1
                }
            }
        }

        // Save changes
        try context.save()
        logger.info("Background: Cache complete - \(insertedCount) new, \(updatedCount) updated, \(deletedCount) deleted")
    }

    /// Fetch cached stones for a category
    func fetchCachedStones(category: CacheCategory) throws -> [Stone] {
        let context = modelContext

        let categoryRawValue = category.rawValue
        let descriptor = FetchDescriptor<CachedStone>(
            predicate: #Predicate { cached in
                cached.categoryRawValue == categoryRawValue
            },
            sortBy: [SortDescriptor(\.cachedAt, order: .reverse)]
        )

        let cached = try context.fetch(descriptor)
        let stones = cached.compactMap { $0.stone }

        logger.info("Background: Fetched \(stones.count) cached stones for \(category.rawValue)")
        return stones
    }

    /// Clear cache for a specific category
    func clearCache(for category: CacheCategory) throws {
        let context = modelContext

        let categoryRawValue = category.rawValue
        let descriptor = FetchDescriptor<CachedStone>(
            predicate: #Predicate { cached in
                cached.categoryRawValue == categoryRawValue
            }
        )

        let toDelete = try context.fetch(descriptor)
        toDelete.forEach { context.delete($0) }

        try context.save()
        logger.info("Background: Cleared cache for category: \(category.rawValue)")
    }
}
