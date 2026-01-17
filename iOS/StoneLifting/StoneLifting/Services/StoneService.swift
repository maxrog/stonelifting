//
//  StoneService.swift
//  StoneLifting
//
//  Created by Max Rogers on 7/15/25.
//

import Foundation
import UIKit
import Observation

// MARK: - Stone Service

/// Service responsible for stone-related operations
/// Handles creating, fetching, updating, and deleting stone records
@Observable
final class StoneService {
    // MARK: - Properties

    static let shared = StoneService()
    private let logger = AppLogger()

    private let apiService = APIService.shared
    private let cacheService = StoneCacheService.shared
    private let networkMonitor = NetworkMonitor.shared

    private(set) var userStones: [Stone] = []
    private(set) var publicStones: [Stone] = []

    private(set) var isLoadingUserStones = false
    private(set) var isLoadingPublicStones = false

    /// Current error
    private(set) var stoneError: StoneError?

    /// Last fetch timestamp for throttling background refreshes
    private var lastFetch: Date?

    /// Minimum time between background refreshes (5 minutes)
    private let refreshThrottle: TimeInterval = 5 * 60

    // MARK: - Initialization

    private init() {}

    // MARK: - Stone Creation

    /// Create a new stone record
    /// - Parameter request: Stone creation data
    /// - Returns: Created stone or nil if failed
    @MainActor
    func createStone(_ request: CreateStoneRequest) async -> Stone? {
        logger.info("Creating stone with weight: \(request.weight), public: \(request.isPublic)")
        stoneError = nil

        do {
            let stone: Stone = try await apiService.post(
                endpoint: APIConfig.Endpoints.stones,
                body: request,
                requiresAuth: true,
                responseType: Stone.self
            )

            logger.info("Successfully created stone with ID: \(stone.id?.uuidString ?? "unknown")")

            userStones.insert(stone, at: 0)
            logger.debug("Added stone to user stones list. Total user stones: \(userStones.count)")

            if stone.isPublic {
                publicStones.insert(stone, at: 0)
                logger.debug("Added stone to public stones list. Total public stones: \(publicStones.count)")
            }

            // Update cache after creating stone
            try? await cacheService.cacheStones(userStones, category: .userStones)
            if stone.isPublic {
                try? await cacheService.cacheStones(publicStones, category: .publicStones)
            }

            return stone

        } catch {
            logger.error("Failed to create stone", error: error)
            handleStoneError(error)
            return nil
        }
    }

    // MARK: - Moderation

    /// Pre-flight text moderation check
    /// - Parameters:
    ///   - name: Stone name
    ///   - description: Stone description
    ///   - locationName: Location name
    /// - Returns: Moderation response
    @MainActor
    func moderateText(name: String?, description: String?, locationName: String?) async -> TextModerationResponse? {
        logger.info("Running pre-flight text moderation")

        let request = TextModerationRequest(
            name: name,
            description: description,
            locationName: locationName
        )

        do {
            let response: TextModerationResponse = try await apiService.post(
                endpoint: APIConfig.Endpoints.moderateText,
                body: request,
                requiresAuth: true,
                responseType: TextModerationResponse.self
            )

            logger.info("Pre-flight moderation result: passed=\(response.passed)")
            return response

        } catch {
            logger.error("Pre-flight moderation failed", error: error)
            return TextModerationResponse(passed: true, reason: nil)
        }
    }

    // MARK: - Stone Fetching

    /// Fetch user's stones
    /// - Parameter shouldCache: Whether to update cache (default: false)
    /// - Returns: Success status
    @MainActor
    func fetchUserStones(shouldCache: Bool = false) async -> Bool {
        logger.info("Fetching user stones (cache: \(shouldCache))")
        isLoadingUserStones = true
        stoneError = nil

        if !networkMonitor.isConnected {
            logger.info("Device is OFFLINE - attempting to load user stones from cache")
            do {
                let cachedStones = try await cacheService.fetchCachedStones(category: .userStones)
                logger.info("Cache returned \(cachedStones.count) stones")
                if !cachedStones.isEmpty {
                    userStones = cachedStones
                    logger.info("Successfully loaded \(cachedStones.count) user stones from cache")
                    isLoadingUserStones = false
                    return true
                } else {
                    logger.warning("Cache is empty - no user stones available offline")
                    isLoadingUserStones = false
                    return false
                }
            } catch {
                logger.error("Failed to fetch from cache", error: error)
                isLoadingUserStones = false
                return false
            }
        } else {
            logger.info("Device is ONLINE - will fetch from API")
        }

        do {
            let stones: [Stone] = try await apiService.get(
                endpoint: APIConfig.Endpoints.stones,
                requiresAuth: true,
                type: [Stone].self
            )
            userStones = stones
            logger.info("Successfully fetched \(stones.count) user stones")

            if shouldCache {
                try? await cacheService.cacheStones(stones, category: .userStones)
            }

            isLoadingUserStones = false
            return true

        } catch {
            logger.error("Failed to fetch user stones", error: error)
            do {
                let cachedStones = try await cacheService.fetchCachedStones(category: .userStones)
                if !cachedStones.isEmpty {
                    userStones = cachedStones
                    logger.info("Using \(cachedStones.count) cached user stones as fallback")
                    isLoadingUserStones = false
                    return true
                }
            } catch {
                logger.error("Cache fallback also failed", error: error)
            }
            handleStoneError(error)
            isLoadingUserStones = false
            return false
        }
    }

    /// Fetch public stones feed
    /// - Parameter shouldCache: Whether to update cache (default: false)
    /// - Returns: Success status
    @MainActor
    func fetchPublicStones(shouldCache: Bool = false) async -> Bool {
        logger.info("Fetching public stones (cache: \(shouldCache))")
        isLoadingPublicStones = true
        stoneError = nil

        if !networkMonitor.isConnected {
            logger.info("Device is OFFLINE - attempting to load public stones from cache")
            do {
                let cachedStones = try await cacheService.fetchCachedStones(category: .publicStones)
                if !cachedStones.isEmpty {
                    publicStones = cachedStones
                    logger.info("Loaded \(cachedStones.count) public stones from cache")
                    isLoadingPublicStones = false
                    return true
                } else {
                    logger.warning("No cached public stones available")
                    isLoadingPublicStones = false
                    return false
                }
            } catch {
                logger.error("Failed to fetch from cache", error: error)
                isLoadingPublicStones = false
                return false
            }
        }

        do {
            let stones: [Stone] = try await apiService.get(
                endpoint: APIConfig.Endpoints.publicStones,
                requiresAuth: false,
                type: [Stone].self
            )

            publicStones = stones
            logger.info("Successfully fetched \(stones.count) public stones")

            if shouldCache {
                try? await cacheService.cacheStones(stones, category: .publicStones)
            }

            isLoadingPublicStones = false
            return true

        } catch {
            logger.error("Failed to fetch public stones", error: error)

            do {
                let cachedStones = try await cacheService.fetchCachedStones(category: .publicStones)
                if !cachedStones.isEmpty {
                    publicStones = cachedStones
                    logger.info("Using \(cachedStones.count) cached public stones as fallback")
                    isLoadingPublicStones = false
                    return true
                }
            } catch {
                logger.error("Cache fallback also failed", error: error)
            }

            handleStoneError(error)
            isLoadingPublicStones = false
            return false
        }
    }

    /// Fetch nearby stones
    /// - Parameters:
    ///   - latitude: Current latitude
    ///   - longitude: Current longitude
    ///   - radius: Search radius in kilometers
    ///   - shouldCache: Whether to update cache (default: true) accumulate nearby ones
    /// - Returns: Nearby stones
    // TODO: Not currently used - will be integrated when "Nearby" map filter is implemented
    // See ROADMAP.md: "Nearby stones discovery"
    @MainActor
    func fetchNearbyStones(latitude: Double, longitude: Double, radius: Double = 10.0, shouldCache: Bool = true) async -> [Stone] {
        logger.info("Fetching nearby stones at lat: \(latitude), lon: \(longitude), radius: \(radius)km")

        if !networkMonitor.isConnected {
            logger.info("Device is OFFLINE - attempting to load nearby stones from cache")
            do {
                let cachedStones = try await cacheService.fetchCachedStones(category: .nearbyStones)
                logger.info("Loaded \(cachedStones.count) nearby stones from cache")
                return cachedStones
            } catch {
                logger.error("Failed to fetch from cache", error: error)
                return []
            }
        }

        do {
            let endpoint = "\(APIConfig.Endpoints.nearbyStones)?lat=\(latitude)&lon=\(longitude)&radius=\(radius)"

            let stones: [Stone] = try await apiService.get(
                endpoint: endpoint,
                requiresAuth: true,
                type: [Stone].self
            )

            logger.info("Successfully fetched \(stones.count) nearby stones")

            if shouldCache {
                try? await cacheService.cacheStones(stones, category: .nearbyStones)
            }

            return stones

        } catch {
            logger.error("Failed to fetch nearby stones", error: error)

            do {
                let cachedStones = try await cacheService.fetchCachedStones(category: .nearbyStones)
                if !cachedStones.isEmpty {
                    logger.info("Using \(cachedStones.count) cached nearby stones as fallback")
                    return cachedStones
                }
            } catch {
                logger.error("Cache fallback also failed", error: error)
            }

            handleStoneError(error)
            return []
        }
    }

    // MARK: - Stone Management

    /// Update an existing stone
    /// - Parameters:
    ///   - stoneId: ID of stone to update
    ///   - request: Updated stone data
    /// - Returns: Updated stone or nil if failed
    @MainActor
    func updateStone(id stoneId: UUID, with request: CreateStoneRequest) async -> Stone? {
        logger.info("Updating stone with ID: \(stoneId.uuidString)")

        do {
            let stone: Stone = try await apiService.put(
                endpoint: "\(APIConfig.Endpoints.stones)/\(stoneId)",
                body: request,
                requiresAuth: true,
                responseType: Stone.self
            )

            logger.info("Successfully updated stone with ID: \(stoneId.uuidString)")

            if let index = userStones.firstIndex(where: { $0.id == stoneId }) {
                userStones[index] = stone
                logger.debug("Updated stone in user stones list at index: \(index)")
            }

            if let index = publicStones.firstIndex(where: { $0.id == stoneId }) {
                if stone.isPublic {
                    publicStones[index] = stone
                    logger.debug("Updated stone in public stones list at index: \(index)")
                } else {
                    publicStones.remove(at: index)
                    logger.debug("Removed stone from public stones list (now private)")
                }
            } else if stone.isPublic {
                publicStones.insert(stone, at: 0)
                logger.debug("Added updated stone to public stones list")
            }

            // Update cache after editing stone
            try? await cacheService.cacheStones(userStones, category: .userStones)
            try? await cacheService.cacheStones(publicStones, category: .publicStones)

            return stone
        } catch {
            logger.error("Failed to update stone with ID: \(stoneId.uuidString)", error: error)
            handleStoneError(error)
            return nil
        }
    }

    /// Delete a stone
    /// - Parameter stoneId: ID of stone to delete
    /// - Returns: Success status
    @MainActor
    func deleteStone(id stoneId: UUID) async -> Bool {
        logger.info("Deleting stone with ID: \(stoneId.uuidString)")

        do {
            try await apiService.delete(
                endpoint: "\(APIConfig.Endpoints.stones)/\(stoneId)",
                requiresAuth: true
            )

            logger.info("Successfully deleted stone with ID: \(stoneId.uuidString)")

            let userStonesCountBefore = userStones.count
            userStones.removeAll { $0.id == stoneId }
            logger.debug("Removed stone from user stones. Count: \(userStonesCountBefore) -> \(userStones.count)")

            let publicStonesCountBefore = publicStones.count
            publicStones.removeAll { $0.id == stoneId }
            logger.debug("Removed stone from public stones. Count: \(publicStonesCountBefore) -> \(publicStones.count)")

            // Update cache after deleting stone
            try? await cacheService.cacheStones(userStones, category: .userStones)
            try? await cacheService.cacheStones(publicStones, category: .publicStones)

            return true

        } catch {
            logger.error("Failed to delete stone with ID: \(stoneId.uuidString)", error: error)
            handleStoneError(error)
            return false
        }
    }

    /// Report a stone for inappropriate content
    /// - Parameter stoneId: ID of stone to report
    /// - Returns: Success status
    @MainActor
    func reportStone(id stoneId: UUID) async -> Bool {
        logger.info("Reporting stone with ID: \(stoneId.uuidString)")

        if hasReportedStone(id: stoneId) {
            logger.warning("Stone \(stoneId.uuidString) already reported by this device")
            return false
        }

        do {
            let _: MessageResponse = try await apiService.post(
                endpoint: "\(APIConfig.Endpoints.stones)/\(stoneId)/report",
                body: EmptyBody(),
                requiresAuth: true,
                responseType: MessageResponse.self
            )

            logger.info("Successfully reported stone with ID: \(stoneId.uuidString)")

            markStoneAsReported(id: stoneId)

            return true

        } catch {
            logger.error("Failed to report stone with ID: \(stoneId.uuidString)", error: error)
            handleStoneError(error)
            return false
        }
    }

    /// Check if this device has already reported a stone
    /// - Parameter stoneId: ID of stone to check
    /// - Returns: True if already reported by this device
    func hasReportedStone(id stoneId: UUID) -> Bool {
        let deviceId = getDeviceIdentifier()
        let reportKey = "\(deviceId)_\(stoneId.uuidString)"
        let reportedStones = UserDefaults.standard.stringArray(forKey: UserDefaultsKeys.reportedStones) ?? []
        return reportedStones.contains(reportKey)
    }

    // MARK: - Device Identification

    /// Get or create a unique device identifier
    /// Uses IDFV (Identifier For Vendor) for device-unique tracking
    private func getDeviceIdentifier() -> String {
        if let storedId = UserDefaults.standard.string(forKey: UserDefaultsKeys.deviceIdentifier) {
            return storedId
        }

        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        UserDefaults.standard.set(deviceId, forKey: UserDefaultsKeys.deviceIdentifier)
        logger.info("Generated new device identifier: \(deviceId)")
        return deviceId
    }

    /// Mark a stone as reported by this device
    private func markStoneAsReported(id stoneId: UUID) {
        let deviceId = getDeviceIdentifier()
        let reportKey = "\(deviceId)_\(stoneId.uuidString)"

        var reportedStones = UserDefaults.standard.stringArray(forKey: UserDefaultsKeys.reportedStones) ?? []
        reportedStones.append(reportKey)
        UserDefaults.standard.set(reportedStones, forKey: UserDefaultsKeys.reportedStones)

        logger.info("Marked stone \(stoneId.uuidString) as reported by device \(deviceId)")
    }

    // MARK: - Error Handling

    /// Clear current error
    func clearError() {
        stoneError = nil
    }

    @MainActor
    func clearAllStones() {
        userStones = []
        publicStones = []
        stoneError = nil
        isLoadingUserStones = false
        isLoadingPublicStones = false
        lastFetch = nil
        logger.info("Cleared all in-memory stone data")
    }

    #if DEBUG
    // MARK: - Debug Methods

    /// Load stones from cache (for testing purposes only)
    func loadFromCache() async -> Bool {
        do {
            async let userFetch = cacheService.fetchCachedStones(category: .userStones)
            async let publicFetch = cacheService.fetchCachedStones(category: .publicStones)

            let (cachedUser, cachedPublic) = await (try userFetch, try publicFetch)

            userStones = cachedUser
            publicStones = cachedPublic

            logger.info("DEBUG: Loaded \(cachedUser.count) user stones and \(cachedPublic.count) public stones from cache")
            return true
        } catch {
            logger.error("DEBUG: Failed to load from cache", error: error)
            stoneError = .networkError
            return false
        }
    }
    #endif

    // MARK: - Background Refresh

    /// Refresh stones if needed (throttled to 5 minutes minimum)
    /// Called when app returns to foreground
    /// - Returns: Whether a refresh was performed
    @MainActor
    func refreshIfNeeded() async -> Bool {
        logger.info("Checking if background refresh is needed")

        guard networkMonitor.isConnected else {
            logger.info("Skipping background refresh - offline")
            return false
        }

        let now = Date()
        let shouldRefresh = lastFetch.map { now.timeIntervalSince($0) >= refreshThrottle } ?? true

        if shouldRefresh {
            logger.info("Background refresh needed - last fetch > 5 min ago")

            async let userFetch = fetchUserStones(shouldCache: true)
            async let publicFetch = fetchPublicStones(shouldCache: true)

            let (userSuccess, publicSuccess) = await (userFetch, publicFetch)

            if userSuccess || publicSuccess {
                lastFetch = Date()
                logger.info("Background refresh completed successfully")
                return true
            }
        } else {
            logger.info("Skipping background refresh - last fetch < 5 min ago")
        }

        return false
    }

    // MARK: - Statistics

    var userStats: StoneStats {
        let stats = StoneStats(stones: userStones)
        logger.debug("Generated user stats - Total: \(stats.totalStones), Weight: \(stats.totalWeight), Heaviest: \(stats.heaviestStone)")
        return stats
    }
}

// MARK: - Private Methods

private extension StoneService {
    /// Handle stone-related errors
    /// - Parameter error: The error to handle
    @MainActor
    func handleStoneError(_ error: Error) {
        logger.error("Handling stone error", error: error)

        if let apiError = error as? APIError {
            switch apiError {
            case .unauthorized:
                stoneError = .notAuthenticated
                logger.warning("Stone operation failed - user not authenticated")
            case .notFound:
                stoneError = .stoneNotFound
                logger.warning("Stone operation failed - stone not found")
            case .networkError:
                stoneError = .networkError
                logger.warning("Stone operation failed - network error")
            default:
                stoneError = .unknownError(apiError.localizedDescription)
                logger.error("Stone operation failed - unknown API error: \(apiError.localizedDescription)")
            }
        } else {
            stoneError = .unknownError(error.localizedDescription)
            logger.error("Stone operation failed - unknown error: \(error.localizedDescription)")
        }
    }
}

// MARK: - Supporting Types

/// Stone operation error types
enum StoneError: Error, LocalizedError {
    case notAuthenticated
    case stoneNotFound
    case networkError
    case invalidData
    case imageUploadFailed(String)
    case moderationFailed(String)
    case unknownError(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You need to be logged in to manage stones. Please sign in to continue."
        case .stoneNotFound:
            return "We couldn't find that stone. It may have been deleted or is no longer available."
        case .networkError:
            return "We're having trouble connecting to the internet. Please check your connection and try again."
        case .invalidData:
            return "Something went wrong with your stone information. Please check all fields and try again."
        case let .imageUploadFailed(message):
            return message
        case let .moderationFailed(message):
            return message
        case let .unknownError(message):
            return message
        }
    }

    /// Whether this error allows retrying with image upload options
    var isImageUploadError: Bool {
        if case .imageUploadFailed = self {
            return true
        }
        return false
    }
}

struct TextModerationRequest: Codable {
    let name: String?
    let description: String?
    let locationName: String?
}

struct TextModerationResponse: Codable {
    let passed: Bool
    let reason: String?
}
