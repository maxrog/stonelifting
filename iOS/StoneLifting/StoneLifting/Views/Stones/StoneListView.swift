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

    @State private var viewModel = StoneListViewModel()

    private let offlineSyncService = OfflineSyncService.shared
    private let logger = AppLogger()

    @State private var selectedFilter: StoneFilter = .myStones
    @State private var searchText = ""

    @State private var showingAddStone = false
    @State private var selectedStone: Stone?
    @State private var showingStoneDetail = false

    private var isPresentingSheet: Bool {
        showingAddStone || selectedStone != nil
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterSection

                if offlineSyncService.pendingCount > 0 {
                    pendingSyncBanner
                }

                stoneListContent
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
            }
            .searchable(text: $searchText, prompt: "Search stones...")
            .sheet(isPresented: $showingAddStone) {
                AddStoneView()
            }
            .sheet(item: $selectedStone) { stone in
                StoneDetailView(stone: stone)
            }
            .alert("Error", isPresented: Binding(
                get: { viewModel.stoneError != nil && !isPresentingSheet },
                set: { if !$0 { viewModel.clearError() } }
            )) {
                Button("OK") {
                    viewModel.clearError()
                }
            } message: {
                Text(viewModel.stoneError?.localizedDescription ?? "")
            }
        }
    }

    // MARK: - View Components

    @ViewBuilder
    private var pendingSyncBanner: some View {
        Button(action: {
            Task {
                await offlineSyncService.syncPendingStones()
            }
        }) {
            HStack(spacing: 12) {
                if offlineSyncService.isSyncing {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "arrow.clockwise.circle.fill")
                        .font(.title3)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("^[\(offlineSyncService.pendingCount) stone](inflect: true) waiting to sync")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text(offlineSyncService.isSyncing ? "Syncing..." : "Tap to sync now")
                        .font(.caption)
                        .opacity(0.9)
                }

                Spacer()

                if !offlineSyncService.isSyncing {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
            }
            .foregroundColor(.white)
            .padding(16)
            .background(
                LinearGradient(
                    colors: [.blue, .cyan],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        .disabled(offlineSyncService.isSyncing)
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var filterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(StoneFilter.allCases, id: \.self) { filter in
                    FilterChip(
                        title: filter.title,
                        stoneCount: stoneCount(for: filter),
                        isSelected: selectedFilter == filter
                    ) {
                        selectedFilter = filter
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
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
        viewModel.filteredStones(for: selectedFilter, searchText: searchText)
    }

    private func stoneCount(for filter: StoneFilter) -> Int {
        viewModel.stoneCount(for: filter)
    }

    // MARK: - Actions

    private func refreshStonesAsync() async {
        logger.info("Pull to refresh for filter: \(selectedFilter.title)")

        switch selectedFilter {
            // TODO should heavy use combined user and public probably?
        case .myStones, .heavy, .recent:
            await viewModel.fetchUserStones(shouldCache: true)
        case .publicStones:
            await viewModel.fetchPublicStones(shouldCache: true)
        }
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
                if let imageUrl = stone.imageUrl, !imageUrl.isEmpty {
                    RemoteImage(url: URL(string: imageUrl)) { image in
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

                        HStack(spacing: 4) {
                            // Show icon for weight type
                            if stone.weight != nil {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            } else if stone.estimatedWeight != nil {
                                Image(systemName: "questionmark.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }

                            Text(stone.formattedWeight)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                        }
                    }

                    if let description = stone.description, !description.isEmpty {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }

                    HStack {
                        // Location - show if there are valid coordinates
                        if stone.hasValidLocation, let lat = stone.latitude, let lon = stone.longitude {
                            Label {
                                Text("\(lat, specifier: "%.2f"), \(lon, specifier: "%.2f")")
                            } icon: {
                                Image(systemName: "location.fill")
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }

                        Spacer()

                        // achievement and privacy
                        HStack(spacing: 8) {
                            HStack(spacing: 3) {
                                Image(systemName: stone.liftingLevel.icon)
                                    .font(.caption)
                                    .foregroundColor(stone.liftingLevel.displayColor)

                                Text(stone.liftingLevel.displayName)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
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
        case .heavy: return "Heavy (220+ lbs)"
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
        case .heavy: return "You haven't lifted any stones over 220 lbs yet. Keep pushing!"
        case .recent: return "No recent stone lifting activity."
        }
    }
}

// MARK: - Preview

#Preview {
    StoneListView()
}
