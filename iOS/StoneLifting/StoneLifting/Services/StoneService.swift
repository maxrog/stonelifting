//
//  StoneService.swift
//  StoneLifting
//
//  Created by Max Rogers on 7/15/25.
//

import Foundation
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

    private(set) var userStones: [Stone] = []
    private(set) var publicStones: [Stone] = []

    private(set) var isCreatingStone = false
    private(set) var isLoadingUserStones = false
    private(set) var isLoadingPublicStones = false

    /// Current error
    private(set) var stoneError: StoneError?

    // MARK: - Initialization

    private init() {}

    // MARK: - Stone Creation

    /// Create a new stone record
    /// - Parameter request: Stone creation data
    /// - Returns: Created stone or nil if failed
    @MainActor
    func createStone(_ request: CreateStoneRequest) async -> Stone? {
        logger.info("Creating stone with weight: \(request.weight), public: \(request.isPublic)")
        isCreatingStone = true
        stoneError = nil

        do {
            let stone: Stone = try await apiService.post(endpoint: APIConfig.Endpoints.stones,
                                                         body: request,
                                                         requiresAuth: true,
                                                         responseType: Stone.self)

            logger.info("Successfully created stone with ID: \(stone.id?.uuidString ?? "unknown")")

            userStones.insert(stone, at: 0)
            logger.debug("Added stone to user stones list. Total user stones: \(userStones.count)")

            if stone.isPublic {
                publicStones.insert(stone, at: 0)
                logger.debug("Added stone to public stones list. Total public stones: \(publicStones.count)")
            }

            isCreatingStone = false
            return stone

        } catch {
            logger.error("Failed to create stone", error: error)
            await handleStoneError(error)
            isCreatingStone = false
            return nil
        }
    }

    // MARK: - Stone Fetching

    /// Fetch user's stones
    /// - Returns: Success status
    @MainActor
    func fetchUserStones() async -> Bool {
        logger.info("Fetching user stones")
        isLoadingUserStones = true
        stoneError = nil

        do {
            let stones: [Stone] = try await apiService.get(endpoint: APIConfig.Endpoints.stones,
                                                           requiresAuth: true,
                                                           type: [Stone].self)

            userStones = stones
            logger.info("Successfully fetched \(stones.count) user stones")
            isLoadingUserStones = false
            return true

        } catch {
            logger.error("Failed to fetch user stones", error: error)
            await handleStoneError(error)
            isLoadingUserStones = false
            return false
        }
    }

    /// Fetch public stones feed
    /// - Returns: Success status
    @MainActor
    func fetchPublicStones() async -> Bool {
        logger.info("Fetching public stones")
        isLoadingPublicStones = true
        stoneError = nil

        do {
            let stones: [Stone] = try await apiService.get(endpoint: APIConfig.Endpoints.publicStones,
                                                           requiresAuth: false,
                                                           type: [Stone].self)

            publicStones = stones
            logger.info("Successfully fetched \(stones.count) public stones")
            isLoadingPublicStones = false
            return true

        } catch {
            logger.error("Failed to fetch public stones", error: error)
            await handleStoneError(error)
            isLoadingPublicStones = false
            return false
        }
    }

    /// Fetch nearby stones
    /// - Parameters:
    ///   - latitude: Current latitude
    ///   - longitude: Current longitude
    ///   - radius: Search radius in kilometers
    /// - Returns: Nearby stones
    @MainActor
    func fetchNearbyStones(latitude: Double, longitude: Double, radius: Double = 10.0) async -> [Stone] {
        logger.info("Fetching nearby stones at lat: \(latitude), lon: \(longitude), radius: \(radius)km")

        do {
            let endpoint = "\(APIConfig.Endpoints.nearbyStones)?lat=\(latitude)&lon=\(longitude)&radius=\(radius)"

            let stones: [Stone] = try await apiService.get(endpoint: endpoint,
                                                           requiresAuth: true,
                                                           type: [Stone].self)

            logger.info("Successfully fetched \(stones.count) nearby stones")
            return stones

        } catch {
            logger.error("Failed to fetch nearby stones", error: error)
            await handleStoneError(error)
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
            let stone: Stone = try await apiService.put(endpoint: "\(APIConfig.Endpoints.stones)/\(stoneId)",
                                                        body: request,
                                                        requiresAuth: true,
                                                        responseType: Stone.self)

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

            return stone

        } catch {
            logger.error("Failed to update stone with ID: \(stoneId.uuidString)", error: error)
            await handleStoneError(error)
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
            try await apiService.delete(endpoint: "\(APIConfig.Endpoints.stones)/\(stoneId)",
                                        requiresAuth: true)

            logger.info("Successfully deleted stone with ID: \(stoneId.uuidString)")

            let userStonesCountBefore = userStones.count
            userStones.removeAll { $0.id == stoneId }
            logger.debug("Removed stone from user stones. Count: \(userStonesCountBefore) -> \(userStones.count)")

            let publicStonesCountBefore = publicStones.count
            publicStones.removeAll { $0.id == stoneId }
            logger.debug("Removed stone from public stones. Count: \(publicStonesCountBefore) -> \(publicStones.count)")

            return true

        } catch {
            logger.error("Failed to delete stone with ID: \(stoneId.uuidString)", error: error)
            await handleStoneError(error)
            return false
        }
    }

    // MARK: - Error Handling

    /// Clear current error
    func clearError() {
        stoneError = nil
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
    case unknownError(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Please log in to manage stones"
        case .stoneNotFound:
            return "Stone not found"
        case .networkError:
            return "Network error. Please check your connection"
        case .invalidData:
            return "Invalid stone data"
        case .unknownError(let message):
            return message
        }
    }
}
