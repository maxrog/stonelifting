//
//  MapView.swift
//  StoneLifting
//
//  Created by Max Rogers on 8/13/25.
//

import MapKit
import SwiftUI

// MARK: - Map View

/// Interactive map displaying stone locations with filtering and detail views
/// Shows both user's stones and public stones with different markers
struct MapView: View {
    // MARK: - Properties

    @State private var viewModel = MapViewModel()
    @Bindable private var locationService = LocationService.shared
    private let logger = AppLogger()

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                mapContent
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        mapControls
                    }
                    .padding()
                }
            }
            .navigationTitle("Stone Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { viewModel.showingFilters = true } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        Task {
                            await viewModel.centerOnUserLocation(zoomSpan: MKCoordinateSpan(latitudeDelta: 0.12, longitudeDelta: 0.12), userInitiated: true)
                            viewModel.showUserLocation = true
                        }
                    } label: {
                        Image(systemName: "location.viewfinder")
                    }
                }
            }
            .task(id: viewModel.mapFilter) {
                await viewModel.setupMapView()
            }
            .sheet(isPresented: $viewModel.showingFilters) {
                MapFilterView(selectedFilter: $viewModel.mapFilter)
            }
            .sheet(item: $viewModel.selectedStone) { stone in
                StoneDetailView(stone: stone)
            }
            .sheet(item: $viewModel.selectedCluster) { cluster in
                ClusterDetailSheet(clusterItem: cluster) { selectedStone in
                    viewModel.selectedStone = selectedStone
                }
            }
            .alert("Location Access Needed", isPresented: $locationService.showSettingsAlert) {
                Button("Open Settings") {
                    if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsUrl)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Location access is needed to show your position on the map. Please enable location services in Settings.")
            }
        }
    }

    // MARK: - View Components

    @ViewBuilder
    private var mapContent: some View {
        if let mapRegion = viewModel.mapRegion {
            Map(position: .constant(.region(mapRegion))) {
                // User location marker (only when location button pressed)
                if viewModel.showUserLocation, let userLocation = viewModel.userLocation {
                    Annotation("Your Location", coordinate: userLocation.coordinate, anchor: .center) {
                        UserLocationIndicator()
                    }
                }

                // Stone clusters
                ForEach(viewModel.clusteredStones, id: \.id) { clusterItem in
                    Annotation(
                        clusterItem.isCluster ? "\(clusterItem.count) stones" : (clusterItem.stones.first?.name ?? "Stone"),
                        coordinate: clusterItem.coordinate,
                        anchor: .bottom
                    ) {
                        ClusterMapPin(clusterItem: clusterItem) {
                            viewModel.selectClusterItem(clusterItem)
                        }
                        .scaleEffect(1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: clusterItem.count)
                    }
                }
            }
            .mapStyle(.standard)
            .onMapCameraChange { context in
                viewModel.updateMapRegion(context.region)
            }
        } else {
            LoadingView(message: "Loading Map...")
        }
    }

    @ViewBuilder
    private var mapControls: some View {
        VStack(alignment: .trailing, spacing: 12) {
            if viewModel.mapFilter != .all {
                Button { viewModel.showingFilters = true } label: {
                    HStack(spacing: 6) {
                        Image(systemName: viewModel.mapFilter.icon)
                        Text(viewModel.mapFilter.title)
                        Image(systemName: "chevron.down")
                    }
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                }
            }

            VStack(spacing: 4) {
                Button(action: { viewModel.zoomIn() }) {
                    Image(systemName: "plus")
                        .font(.title2)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial)
                        .cornerRadius(22)
                }
                Button(action: { viewModel.zoomOut() }) {
                    Image(systemName: "minus")
                        .font(.title2)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial)
                        .cornerRadius(22)
                }
            }
        }
    }
}

// MARK: - User Location Indicator

/// Animated user location indicator with pulsing effect
struct UserLocationIndicator: View {
    @State private var isPulsing = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: 40, height: 40)
                .scaleEffect(isPulsing ? 1.1 : 1.0)
                .opacity(isPulsing ? 0.5 : 0.8)
                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isPulsing)

            Circle()
                .fill(Color.blue)
                .frame(width: 16, height: 16)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 3)
                )
        }
        .onAppear {
            isPulsing = true
        }
    }
}

// MARK: - Map Filter View

/// Filter sheet for selecting which stones to show on map
struct MapFilterView: View {
    @Binding var selectedFilter: MapFilter
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(MapFilter.allCases, id: \.self) { filter in
                    Button(action: {
                        selectedFilter = filter
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: filter.icon)
                                .foregroundColor(filter.color)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(filter.title)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)

                                Text(filter.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            if selectedFilter == filter {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                                    .fontWeight(.semibold)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Map Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Map Filter Types

enum MapFilter: CaseIterable {
    case all
    case myStones
    case publicStones
    // TODO: Add .nearby filter - fetch stones in visible map region using StoneService.fetchNearbyStones()

    var title: String {
        switch self {
        case .all: return "All Stones"
        case .myStones: return "My Stones"
        case .publicStones: return "Public Stones"
        }
    }

    var description: String {
        switch self {
        case .all: return "Show all stones on the map"
        case .myStones: return "Only stones you've logged"
        case .publicStones: return "Only public stones from others"
        }
    }

    var icon: String {
        switch self {
        case .all: return "map"
        case .myStones: return "person.circle"
        case .publicStones: return "globe"
        }
    }

    var color: Color {
        switch self {
        case .all: return .blue
        case .myStones: return .blue
        case .publicStones: return .green
        }
    }
}

// MARK: - Preview

#Preview {
    MapView()
}
