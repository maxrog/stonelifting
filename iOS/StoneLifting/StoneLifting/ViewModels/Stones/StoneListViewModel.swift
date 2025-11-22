//
//  StoneListViewModel.swift
//  StoneLifting
//
//  Created by Max Rogers on 11/09/25.
//

import Foundation
import Observation

// MARK: - Stone List View Model

/// ViewModel for StoneListView
/// Manages stone list state and data fetching
@Observable
final class StoneListViewModel {
    // MARK: - Properties

    private let stoneService = StoneService.shared
    private let logger = AppLogger()

    // Exposed state
    var userStones: [Stone] { stoneService.userStones }
    var publicStones: [Stone] { stoneService.publicStones }
    var isLoading: Bool { stoneService.isLoadingUserStones || stoneService.isLoadingPublicStones }
    var errorMessage: String? { stoneService.stoneError?.localizedDescription }

    // MARK: - Actions

    /// Fetch user stones
    func fetchUserStones() async {
        _ = await stoneService.fetchUserStones()
    }

    /// Fetch public stones
    func fetchPublicStones() async {
        _ = await stoneService.fetchPublicStones()
    }

    /// Refresh all stones
    func refreshAllStones() async {
        _ = await stoneService.fetchUserStones()
        _ = await stoneService.fetchPublicStones()
    }

    /// Get stone count for a specific filter
    /// - Parameter filter: The filter to count stones for
    /// - Returns: Number of stones matching the filter
    func stoneCount(for filter: StoneFilter) -> Int {
        switch filter {
        case .myStones:
            return userStones.count
        case .publicStones:
            return publicStones.count
        case .heavy:
            return userStones.filter { ($0.weight ?? $0.estimatedWeight ?? 0) >= 100 }.count
        case .recent:
            return min(userStones.count, 10)
        }
    }

    /// Get filtered stones based on filter and search text
    /// - Parameters:
    ///   - filter: The active filter
    ///   - searchText: Search query text
    /// - Returns: Filtered array of stones
    func filteredStones(for filter: StoneFilter, searchText: String) -> [Stone] {
        let stones: [Stone]

        switch filter {
        case .myStones:
            stones = userStones
        case .publicStones:
            stones = publicStones
        case .heavy:
            stones = userStones.filter { ($0.weight ?? $0.estimatedWeight ?? 0) >= 100 }
        case .recent:
            stones = Array(userStones.prefix(10))
        }

        if searchText.isEmpty {
            return stones
        } else {
            return stones.filter { stone in
                stone.name?.localizedCaseInsensitiveContains(searchText) == true ||
                    stone.description?.localizedCaseInsensitiveContains(searchText) == true ||
                    stone.locationName?.localizedCaseInsensitiveContains(searchText) == true
            }
        }
    }

    /// Clear any error
    func clearError() {
        stoneService.clearError()
    }
}
