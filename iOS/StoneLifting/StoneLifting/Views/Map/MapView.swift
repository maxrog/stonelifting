//
//  MapView.swift
//  StoneLifting
//
//  Created by Max Rogers on 8/13/25.
//

import SwiftUI
import MapKit

// MARK: - Map View

/// Interactive map displaying stone locations with filtering and detail views
/// Shows both user's stones and public stones with different markers
struct MapView: View {

    // MARK: - Properties

    private let stoneService = StoneService.shared
    private let locationService = LocationService.shared
    private let clusteringSystem = StoneClusteringSystem()

    private let logger = AppLogger()

    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), // Default to SF
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )

    @State private var selectedStone: Stone?
    @State private var showingStoneDetail = false
    @State private var selectedCluster: StoneClusterItem?
    @State private var showingClusterDetail = false
    @State private var showingFilters = false
    @State private var mapFilter: MapFilter = .all

    @State private var isTrackingUser = false
    @State private var hasRequestedLocation = false

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
                    Button("Filter") {
                        showingFilters = true
                    }
                }

                ToolbarItem(placement: .navigationBarLeading) {
                    Button("My Location") {
                        centerOnUserLocation()
                    }
                    .font(.caption)
                }
            }
            .onAppear {
                setupMapView()
            }
            .sheet(isPresented: $showingFilters) {
                MapFilterView(selectedFilter: $mapFilter)
            }
            .sheet(item: $selectedStone) { stone in
                StoneDetailView(stone: stone)
            }
            .sheet(item: $selectedCluster) { cluster in
                ClusterDetailSheet(clusterItem: cluster) { selectedStone in
                    self.selectedStone = selectedStone
                }
            }
        }
    }

    // MARK: - View Components

    @ViewBuilder
    private var mapContent: some View {
        Map(position: .constant(.region(mapRegion))) {
            ForEach(clusteredStones, id: \.id) { clusterItem in
                Annotation(
                    clusterItem.isCluster ? "\(clusterItem.count) stones" : (clusterItem.stones.first?.name ?? "Stone"),
                    coordinate: clusterItem.coordinate,
                    anchor: .bottom
                ) {
                    ClusterMapPin(clusterItem: clusterItem) {
                        if clusterItem.isCluster {
                            selectedCluster = clusterItem
                        } else {
                            selectedStone = clusterItem.stones.first
                        }
                    }
                }
            }
        }
        .mapStyle(.standard)
        .onMapCameraChange { context in
            mapRegion = context.region
        }
    }

    @ViewBuilder
    private var mapControls: some View {
        VStack(alignment: .trailing, spacing: 12) {
            if mapFilter != .all {
                Button(action: {
                    showingFilters = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: mapFilter.icon)
                        Text(mapFilter.title)
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
                Button(action: zoomIn) {
                    Image(systemName: "plus")
                        .font(.title2)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial)
                        .cornerRadius(22)
                }

                Button(action: zoomOut) {
                    Image(systemName: "minus")
                        .font(.title2)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial)
                        .cornerRadius(22)
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var allStones: [Stone] {
        let userStones = stoneService.userStones.filter { $0.hasValidLocation }
        let publicStones = stoneService.publicStones.filter { $0.hasValidLocation }

        // Avoid duplication
        var combined = userStones
        for publicStone in publicStones {
            if !combined.contains(where: { $0.id == publicStone.id }) {
                combined.append(publicStone)
            }
        }

        return combined
    }

    private var filteredStones: [Stone] {
        allStones.filter { stone in
            switch mapFilter {
            case .all:
                return true
            case .myStones:
                return stoneService.userStones.contains(where: { $0.id == stone.id })
            case .publicStones:
                return stone.isPublic && !stoneService.userStones.contains(where: { $0.id == stone.id })
            }
        }
    }

    /// Clustered stones based on current map region and zoom level
    private var clusteredStones: [StoneClusterItem] {
        clusteringSystem.generateClusters(from: filteredStones, in: mapRegion)
    }

    // MARK: - Actions

    private func setupMapView() {
        logger.info("Setting up MapView")

        // Load stones if not already loaded
        Task {
            await stoneService.fetchUserStones()
            await stoneService.fetchPublicStones()

            await MainActor.run {
                adjustMapToShowStones()
            }
        }

        // Request location permission and center on user if available
        requestLocationPermission()
    }

    private func requestLocationPermission() {
        guard !hasRequestedLocation else { return }
        hasRequestedLocation = true

        if locationService.authorizationStatus == .notDetermined {
            locationService.requestLocationPermission()
        }

        if locationService.authorizationStatus == .authorizedWhenInUse ||
           locationService.authorizationStatus == .authorizedAlways {
            isTrackingUser = true
            centerOnUserLocation()
        }
    }

    private func adjustMapToShowStones() {
        let stones = filteredStones
        guard !stones.isEmpty else { return }

        // Calculate bounding box for all stones
        let coordinates = stones.map { $0.coordinate }
        let minLat = coordinates.map { $0.latitude }.min() ?? 0
        let maxLat = coordinates.map { $0.latitude }.max() ?? 0
        let minLon = coordinates.map { $0.longitude }.min() ?? 0
        let maxLon = coordinates.map { $0.longitude }.max() ?? 0

        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)

        // 20% padding
        let span = MKCoordinateSpan(latitudeDelta: max(0.01, (maxLat - minLat) * 1.2), longitudeDelta: max(0.01, (maxLon - minLon) * 1.2))

        withAnimation(.easeInOut(duration: 1.0)) {
            mapRegion = MKCoordinateRegion(center: center, span: span)
        }
    }

    private func centerOnUserLocation() {
        Task {
            if let location = await locationService.getCurrentLocation() {
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.8)) {
                        mapRegion.center = location.coordinate
                        mapRegion.span = MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                    }
                }
            }
        }
    }

    private func zoomIn() {
        withAnimation(.easeInOut(duration: 0.3)) {
            mapRegion.span = MKCoordinateSpan(
                latitudeDelta: mapRegion.span.latitudeDelta * 0.5,
                longitudeDelta: mapRegion.span.longitudeDelta * 0.5
            )
        }
    }

    private func zoomOut() {
        withAnimation(.easeInOut(duration: 0.3)) {
            mapRegion.span = MKCoordinateSpan(
                latitudeDelta: min(180, mapRegion.span.latitudeDelta * 2),
                longitudeDelta: min(360, mapRegion.span.longitudeDelta * 2)
            )
        }
    }
}

// MARK: - Stone Map Pin

struct StoneMapPin: View {
    let stone: Stone
    let onTap: () -> Void

    private var pinColor: Color {
        let isCurrentUser = stone.user.id == AuthService.shared.currentUser?.id
        return .blue.opacity(isCurrentUser ? 1.0 : 0.75)
    }

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onTap) {
                VStack(spacing: 4) {
                    Text(stone.formattedWeight)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(pinColor)
                        .cornerRadius(8)

                    Circle()
                        .fill(pinColor)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Image(systemName: stone.liftingLevel.icon)
                                .font(.caption)
                                .foregroundColor(.white)
                        )
                        .overlay(
                            Circle()
                                .stroke(.white, lineWidth: 2)
                        )
                }
            }
            .buttonStyle(.plain)

            Triangle()
                .fill(pinColor)
                .frame(width: 8, height: 6)
                .offset(y: -1)
        }
        .scaleEffect(selectedStone?.id == stone.id ? 1.2 : 1.0)
        .animation(.spring(response: 0.3), value: selectedStone?.id == stone.id)
    }

    @State private var selectedStone: Stone?
}

/// Custom triangle shape for map pin point
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
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
