//
//  PendingStone.swift
//  StoneLifting
//
//  Created by Max Rogers on 1/7/26.
//

import Foundation
import SwiftData

// MARK: - Pending Stone Model

/// Local persistence model for stones that haven't been synced to the server yet
/// Used for offline stone creation - stones are saved locally and synced when connectivity returns
@Model
final class PendingStone {
    @Attribute(.unique) var id: UUID
    var requestData: Data
    var photoData: Data?
    var createdAt: Date
    var syncAttempts: Int
    var lastError: String?
    var isSyncing: Bool

    init(
        id: UUID = UUID(),
        requestData: Data,
        photoData: Data? = nil,
        createdAt: Date = Date(),
        syncAttempts: Int = 0,
        lastError: String? = nil,
        isSyncing: Bool = false
    ) {
        self.id = id
        self.requestData = requestData
        self.photoData = photoData
        self.createdAt = createdAt
        self.syncAttempts = syncAttempts
        self.lastError = lastError
        self.isSyncing = isSyncing
    }

    var stoneRequest: CreateStoneRequest? {
        try? JSONDecoder().decode(CreateStoneRequest.self, from: requestData)
    }
}

extension PendingStone {
    static let maxRetryAttempts = 3
    var hasExceededRetries: Bool {
        syncAttempts >= Self.maxRetryAttempts
    }

    var statusDescription: String {
        if isSyncing {
            return "Syncing..."
        } else if let error = lastError {
            return "Failed: \(error)"
        } else if syncAttempts > 0 {
            return "Retrying (\(syncAttempts)/\(Self.maxRetryAttempts))"
        } else {
            return "Waiting to sync"
        }
    }
}
