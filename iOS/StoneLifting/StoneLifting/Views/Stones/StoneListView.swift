//
//  StoneListView.swift
//  StoneLifting
//
//  Created by Max Rogers on 7/30/25.
//

import SwiftUI

// MARK: - Stone List View

/// Displays user's stone lifting records in a scrollable list
/// Shows both personal and public stones with filtering options
struct StoneListView: View {

    // MARK: - Properties

    private let stoneService = StoneService.shared
    private let authService = AuthService.shared
    private let logger = AppLogger()

    @State private var selectedFilter: StoneFilter = .myStones
    @State private var searchText = ""

    @State private var showingAddStone = false
    @State private var selectedStone: Stone?
    @State private var showingStoneDetail = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterSection

                if stoneService.isLoadingUserStones || stoneService.isLoadingPublicStones {
                    loadingView
                } else {
                    stoneListContent
                }
            }
            .navigationTitle("Stones")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddStone = true
                    }) {
                        Image(systemName: "plus")
                            .font(.headline)
                    }
                }

                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Refresh") {
                        refreshStones()
                    }
                    .font(.caption)
                }
            }
            .onAppear {
                setupView()
            }
            .searchable(text: $searchText, prompt: "Search stones...")
            .sheet(isPresented: $showingAddStone) {
                AddStoneView()
            }
            .sheet(item: $selectedStone) { stone in
                StoneDetailView(stone: stone)
            }
            .alert("Error", isPresented: .constant(stoneService.stoneError != nil)) {
                Button("OK") {
                    stoneService.clearError()
                }
            } message: {
                Text(stoneService.stoneError?.localizedDescription ?? "")
            }
        }
    }

    // MARK: - View Components

    @ViewBuilder
    private var filterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(StoneFilter.allCases, id: \.self) { filter in
                    FilterChip(title: filter.title,
                        stoneCount: stoneCount(for: filter),
                        isSelected: selectedFilter == filter) {
                        selectedFilter = filter
                        loadStonesForFilter()
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }

    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)

            Text("Loading stones...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var stoneListContent: some View {
        let stones = filteredStones

        if stones.isEmpty {
            emptyStateView
        } else {
            List(stones) { stone in
                StoneRowView(stone: stone) {
                    selectedStone = stone
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .refreshable {
                await refreshStonesAsync()
            }
        }
    }

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: selectedFilter.emptyStateIcon)
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                Text(selectedFilter.emptyStateTitle)
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(selectedFilter.emptyStateMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            if selectedFilter == .myStones {
                Button("Add Your First Stone") {
                    showingAddStone = true
                }
                .buttonStyle(.borderedProminent)
                .font(.headline)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Computed Properties

    /// Filtered stones based on current selection and search
    private var filteredStones: [Stone] {
        let stones: [Stone]

        switch selectedFilter {
        case .myStones:
            stones = stoneService.userStones
        case .publicStones:
            stones = stoneService.publicStones
        case .heavy:
            stones = stoneService.userStones.filter { $0.weight >= 100 }
        case .recent:
            stones = Array(stoneService.userStones.prefix(10))
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

    private func stoneCount(for filter: StoneFilter) -> Int {
        switch filter {
        case .myStones:
            return stoneService.userStones.count
        case .publicStones:
            return stoneService.publicStones.count
        case .heavy:
            return stoneService.userStones.filter { $0.weight >= 100 }.count
        case .recent:
            return min(stoneService.userStones.count, 10)
        }
    }

    // MARK: - Actions

    private func setupView() {
        logger.info("Setting up StoneListView")
        loadStonesForFilter()
    }

    private func loadStonesForFilter() {
        logger.info("Loading stones for filter: \(selectedFilter.title)")

        Task {
            switch selectedFilter {
            case .myStones, .heavy, .recent:
                await stoneService.fetchUserStones()
            case .publicStones:
                await stoneService.fetchPublicStones()
            }
        }
    }

    private func refreshStones() {
        logger.info("Refreshing stones data")
        loadStonesForFilter()
    }

    private func refreshStonesAsync() async {
        await stoneService.fetchUserStones()
        await stoneService.fetchPublicStones()
    }
}

// MARK: - Filter Chip View

struct FilterChip: View {
    let title: String
    let stoneCount: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                if stoneCount > 0 {
                    Text("\(stoneCount)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(isSelected ? .white : .secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(isSelected ? Color.white.opacity(0.3) : Color.secondary.opacity(0.2))
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? Color.blue : Color(.systemGray6))
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Stone Row View

struct StoneRowView: View {
    let stone: Stone
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Stone image or placeholder
                if let imageUrl = stone.imageUrl, !imageUrl.isEmpty {
                    AsyncImage(url: URL(string: imageUrl)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        stoneImagePlaceholder
                    }
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    stoneImagePlaceholder
                        .frame(width: 60, height: 60)
                }

                // Stone details
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(stone.name ?? "Unnamed Stone")
                            .font(.headline)
                            .foregroundColor(.primary)

                        Spacer()

                        Text(stone.formattedWeight)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    }

                    if let description = stone.description, !description.isEmpty {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }

                    HStack {
                        // Location
                        if stone.hasLocation {
                            Label {
                                Text(stone.locationName ?? "Unknown Location")
                            } icon: {
                                Image(systemName: "location.fill")
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }

                        Spacer()

                        // Difficulty and privacy
                        HStack(spacing: 8) {
                            if let difficulty = stone.difficultyRating {
                                HStack(spacing: 2) {
                                    ForEach(1...difficulty, id: \.self) { _ in
                                        Image(systemName: "star.fill")
                                            .font(.caption2)
                                            .foregroundColor(.yellow)
                                    }
                                }
                            }

                            Image(systemName: stone.isPublic ? "globe" : "lock.fill")
                                .font(.caption)
                                .foregroundColor(stone.isPublic ? .green : .orange)
                        }
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }

    /// Stone image placeholder
    @ViewBuilder
    private var stoneImagePlaceholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color(.systemGray5))
            .overlay(
                Image(systemName: "photo")
                    .font(.title2)
                    .foregroundColor(.secondary)
            )
    }
}

// MARK: - Supporting Types

/// Stone filter options
enum StoneFilter: CaseIterable {
    case myStones
    case publicStones
    case heavy
    case recent

    var title: String {
        switch self {
        case .myStones: return "My Stones"
        case .publicStones: return "Public"
        case .heavy: return "Heavy (100+ lbs)"
        case .recent: return "Recent"
        }
    }

    var emptyStateIcon: String {
        switch self {
        case .myStones: return "figure.strengthtraining.traditional"
        case .publicStones: return "globe"
        case .heavy: return "scalemass.fill"
        case .recent: return "clock"
        }
    }

    var emptyStateTitle: String {
        switch self {
        case .myStones: return "No Stones Yet"
        case .publicStones: return "No Public Stones"
        case .heavy: return "No Heavy Stones"
        case .recent: return "No Recent Stones"
        }
    }

    var emptyStateMessage: String {
        switch self {
        case .myStones: return "Start your stone lifting journey by adding your first stone!"
        case .publicStones: return "No public stones available in this area yet."
        case .heavy: return "You haven't lifted any stones over 100 lbs yet. Keep pushing!"
        case .recent: return "No recent stone lifting activity."
        }
    }
}

// MARK: - Preview

#Preview {
    StoneListView()
}
