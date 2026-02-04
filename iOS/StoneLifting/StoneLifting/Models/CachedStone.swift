//
//  CachedStone.swift
//  StoneAtlas
//
//  Created by Max Rogers on 1/8/26.
//

import Foundation
import SwiftData

// MARK: - Cached Stone Model

/// Local cache of stone data for offline viewing
/// Stores API responses locally so users can view stones offline
@Model
final class CachedStone {
    /// Identifier (matches server stone ID)
    /// Note: No @Attribute(.unique) - SwiftData's unique constraint conflicts with upsert patterns
    /// Deduplication is handled at application level via dictionary lookups in upsert logic
    var id: UUID
    var stoneData: Data
    var categoryRawValue: String
    var cachedAt: Date

    init(
        id: UUID,
        stoneData: Data,
        category: CacheCategory,
        cachedAt: Date = Date()
    ) {
        self.id = id
        self.stoneData = stoneData
        self.categoryRawValue = category.rawValue
        self.cachedAt = cachedAt
    }

    var category: CacheCategory {
        CacheCategory(rawValue: categoryRawValue) ?? .userStones
    }

    var stone: Stone? {
        try? JSONDecoder().decode(Stone.self, from: stoneData)
    }
}

/// Categories for organizing cached stones
enum CacheCategory: String, Codable {
    case userStones = "user_stones"
    case publicStones = "public_stones"
    case nearbyStones = "nearby_stones"
}

extension CachedStone {
    static func from(stone: Stone, category: CacheCategory) -> CachedStone? {
        guard let id = stone.id else { return nil }
        guard let data = try? JSONEncoder().encode(stone) else { return nil }

        return CachedStone(
            id: id,
            stoneData: data,
            category: category
        )
    }
}
