//
//  OfflineSyncService.swift
//  StoneAtlas
//
//  Created by Max Rogers on 1/7/26.
//

import Foundation
import SwiftData

// MARK: - Offline Sync Service

/// Manages offline stone creation and automatic syncing when connectivity returns
@Observable
final class OfflineSyncService {
    // MARK: - Properties

    static let shared = OfflineSyncService()

    private let logger = AppLogger()
    private let stoneService = StoneService.shared
    private let networkMonitor = NetworkMonitor.shared

    /// SwiftData model container
    private var modelContainer: ModelContainer?

    /// Persistent context (reused to avoid context conflicts)
    private var modelContext: ModelContext?

    var pendingStones: [PendingStone] = []
    var isSyncing = false
    var syncError: Error?

    // MARK: - Initialization

    private init() {
        logger.info("OfflineSyncService initialized")
    }

    // MARK: - Setup

    /// Configure with shared model container
    func configure(with container: ModelContainer) {
        self.modelContainer = container
        self.modelContext = ModelContext(container)
        logger.info("OfflineSyncService configured with model container and persistent context")
        loadPendingStones()
    }

    // MARK: - Public Methods

    /// Save a stone locally for offline creation
    /// - Parameters:
    ///   - request: The stone creation request
    ///   - photoData: Optional photo data
    /// - Returns: Success status
    @MainActor
    func saveStoneOffline(request: CreateStoneRequest, photoData: Data?) async -> Bool {
        logger.info("Saving stone offline: \(request.name ?? "unnamed")")

        guard let context = modelContext else {
            logger.error("Model context not configured")
            return false
        }

        do {
            let encoder = JSONEncoder()
            let requestData = try encoder.encode(request)

            let pendingStone = PendingStone(
                requestData: requestData,
                photoData: photoData
            )

            context.insert(pendingStone)

            try context.save()

            loadPendingStones()

            logger.info("Stone saved offline successfully")

            Task {
                await syncPendingStones()
            }

            return true
        } catch {
            logger.error("Failed to save stone offline", error: error)
            return false
        }
    }

    var pendingCount: Int {
        pendingStones.count
    }

    @MainActor
    func syncPendingStones() async {
        guard networkMonitor.isConnected else {
            logger.info("Cannot sync - device is offline")
            return
        }

        guard !isSyncing else {
            logger.info("Sync already in progress, skipping")
            return
        }

        guard !pendingStones.isEmpty else {
            logger.info("No pending stones to sync")
            return
        }

        logger.info("Starting sync of \(pendingStones.count) pending stones")
        isSyncing = true
        syncError = nil

        for pendingStone in pendingStones {
            await syncStone(pendingStone)
        }

        isSyncing = false
        logger.info("Sync completed")
    }

    /// Delete a pending stone (for manual cleanup)
    @MainActor
    func deletePendingStone(_ pendingStone: PendingStone) {
        guard let context = modelContext else {
            logger.error("Persistent context not configured")
            return
        }

        context.delete(pendingStone)

        do {
            try context.save()
            loadPendingStones()
            logger.info("Deleted pending stone")
        } catch {
            logger.error("Failed to delete pending stone", error: error)
        }
    }

    // MARK: - Private Methods

    private func loadPendingStones() {
        guard let context = modelContext else {
            logger.error("Model context not configured")
            return
        }

        let descriptor = FetchDescriptor<PendingStone>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )

        do {
            pendingStones = try context.fetch(descriptor)
            logger.info("Loaded \(pendingStones.count) pending stones")
        } catch {
            logger.error("Failed to load pending stones", error: error)
            pendingStones = []
        }
    }

    @MainActor
    private func syncStone(_ pendingStone: PendingStone) async {
        logger.info("Syncing pending stone \(pendingStone.id)")

        guard let context = modelContext else {
            logger.error("Model context not configured")
            return
        }

        guard !pendingStone.isSyncing else {
            logger.info("Stone already syncing, skipping")
            return
        }

        if pendingStone.hasExceededRetries {
            logger.warning("Stone has exceeded retry attempts (\(pendingStone.syncAttempts)/\(PendingStone.maxRetryAttempts)), deleting")
            deletePendingStone(pendingStone)
            return
        }

        guard let request = pendingStone.stoneRequest else {
            logger.error("Failed to decode stone request")
            deletePendingStone(pendingStone)
            return
        }

        pendingStone.isSyncing = true
        try? context.save()

        let stone = await StoneFormViewModel().saveStone(request: request, photoData: pendingStone.photoData)

        if stone != nil {
            logger.info("Successfully synced stone \(pendingStone.id)")
            deletePendingStone(pendingStone)
        } else {
            pendingStone.isSyncing = false
            pendingStone.syncAttempts += 1
            pendingStone.lastError = "Sync failed"
            logger.warning("Failed to sync stone \(pendingStone.id) (attempt \(pendingStone.syncAttempts)/\(PendingStone.maxRetryAttempts))")

            try? context.save()
            loadPendingStones()
        }
    }
}
