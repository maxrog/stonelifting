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

    private let stoneService = StoneService.shared
    private let locationService = LocationService.shared
    private let clusteringSystem = StoneClusteringSystem()
    private let logger = AppLogger()

    // Typical spans for initial load / location button
    private let initialLoadSpan = MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)
    private let locationButtonSpan = MKCoordinateSpan(latitudeDelta: 0.12, longitudeDelta: 0.12)

    // MARK: - Zoom limits
    private let minLatitudeDelta: CLLocationDegrees = 0.01
    private let maxLatitudeDelta: CLLocationDegrees = 180
    private let minLongitudeDelta: CLLocationDegrees = 0.01
    private let maxLongitudeDelta: CLLocationDegrees = 360
    private let zoomScaleFactor: Double = 0.6
    private let minPaddingFactor: Double = 1.2
    private let maxPaddingFactor: Double = 2.0

    @State private var mapRegion: MKCoordinateRegion?
    @State private var selectedStone: Stone?
    @State private var showingStoneDetail = false
    @State private var selectedCluster: StoneClusterItem?
    @State private var showingClusterDetail = false
    @State private var showingFilters = false
    @State private var mapFilter: MapFilter = .all
    @State private var currentZoomLevel: Double = 0
    @State private var isTrackingUser = false
    @State private var hasRequestedLocation = false
    
    private var allStones: [Stone] {
        let userStones = stoneService.userStones.filter { $0.hasValidLocation }
        let publicStones = stoneService.publicStones.filter { $0.hasValidLocation }
        var combined = userStones
        for stone in publicStones where !combined.contains(where: { $0.id == stone.id }) {
            combined.append(stone)
        }
        return combined
    }

    private var filteredStones: [Stone] {
        allStones.filter { stone in
            switch mapFilter {
            case .all: return true
            case .myStones: return stoneService.userStones.contains(where: { $0.id == stone.id })
            case .publicStones: return stone.isPublic && !stoneService.userStones.contains(where: { $0.id == stone.id })
            }
        }
    }

    private var clusteredStones: [StoneClusterItem] {
        if let mapRegion { return clusteringSystem.generateClusters(from: filteredStones, in: mapRegion) } else { return [] }
    }

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
                    Button { showingFilters = true } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        Task { await centerOnUserLocation(zoomSpan: locationButtonSpan) }
                    } label: {
                        Image(systemName: "location.viewfinder")
                    }
                }
            }
            .task(id: mapFilter) {
                await setupMapView()
            }
            .sheet(isPresented: $showingFilters) { MapFilterView(selectedFilter: $mapFilter) }
            .sheet(item: $selectedStone) { StoneDetailView(stone: $0) }
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
        if let mapRegion {
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
                let newZoom = calculateZoomLevel(from: context.region)

                // Only update if zoom changed significantly (prevents micro-updates)
                if abs(newZoom - currentZoomLevel) > 0.5 {
                    currentZoomLevel = newZoom
                }

                self.mapRegion = context.region
            }
        } else {
            LoadingView(message: "Loading Map...")
        }
    }

    private func calculateZoomLevel(from region: MKCoordinateRegion) -> Double {
        let span = max(region.span.latitudeDelta, region.span.longitudeDelta)
        return max(0, 20 - log2(span * 111_000))
    }

    @ViewBuilder
    private var mapControls: some View {
        VStack(alignment: .trailing, spacing: 12) {
            if mapFilter != .all {
                Button { showingFilters = true } label: {
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

    // MARK: - Actions

    private func setupMapView() async {
        logger.info("Setting up MapView for filter \(mapFilter)")

        switch mapFilter {
        case .all:
            _ = await stoneService.fetchPublicStones()
            _ = await stoneService.fetchUserStones()
        case .myStones:
            _ = await stoneService.fetchUserStones()
        case .publicStones:
            _ = await stoneService.fetchPublicStones()
        }

        await MainActor.run {
            guard mapRegion == nil else { return }
            Task { await centerOnUserLocation(zoomSpan: initialLoadSpan) }
        }

        await requestLocationPermission()
    }

    private func requestLocationPermission() async {
        guard !hasRequestedLocation else { return }
        hasRequestedLocation = true

        if locationService.authorizationStatus == .notDetermined {
            locationService.requestLocationPermission()
        }

        if [.authorizedWhenInUse, .authorizedAlways].contains(locationService.authorizationStatus) {
            isTrackingUser = true
            await centerOnUserLocation(zoomSpan: initialLoadSpan)
        }
    }

    private func adjustMapToShowStones() {
        let stones = filteredStones
        guard !stones.isEmpty else { return }

        let coords = stones.map { $0.coordinate }
        let minLat = coords.map(\.latitude).min() ?? 0
        let maxLat = coords.map(\.latitude).max() ?? 0
        let minLon = coords.map(\.longitude).min() ?? 0
        let maxLon = coords.map(\.longitude).max() ?? 0

        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
        let latDelta = max(0.01, (maxLat - minLat) * minPaddingFactor)
        let lonDelta = max(0.01, (maxLon - minLon) * minPaddingFactor)

        let targetRegion = MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
        )

        let animation = mapRegion.map { dynamicAnimation(for: $0, target: targetRegion) } ?? .easeInOut(duration: 0.5)
        withAnimation(animation) { mapRegion = targetRegion }
    }

    private func centerOnUserLocation(zoomSpan: MKCoordinateSpan) async {
        if let location = await locationService.getCurrentLocation() {
            await MainActor.run {
                let target = MKCoordinateRegion(center: location.coordinate, span: zoomSpan)
                let animation = mapRegion.map { dynamicAnimation(for: $0, target: target) } ?? .easeInOut(duration: 0.5)
                withAnimation(animation) { mapRegion = target }
            }
        } else {
            await MainActor.run {
                adjustMapToShowStones()
            }
        }
    }

    private func zoomIn() {
        guard let mapRegion else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            // Calculate new span (smaller = zoomed in)
            let newLat = max(minLatitudeDelta, mapRegion.span.latitudeDelta * zoomScaleFactor)
            let newLon = max(minLongitudeDelta, mapRegion.span.longitudeDelta * zoomScaleFactor)

            self.mapRegion?.span = MKCoordinateSpan(
                latitudeDelta: newLat,
                longitudeDelta: newLon
            )
        }
    }

    private func zoomOut() {
        guard let mapRegion else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            // Calculate new span (larger = zoomed out)
            let newLat = min(maxLatitudeDelta, mapRegion.span.latitudeDelta / zoomScaleFactor)
            let newLon = min(maxLongitudeDelta, mapRegion.span.longitudeDelta / zoomScaleFactor)

            self.mapRegion?.span = MKCoordinateSpan(
                latitudeDelta: newLat,
                longitudeDelta: newLon
            )
        }
    }

    /// Computes dynamic animation based on distance and zoom difference
    private func dynamicAnimation(for current: MKCoordinateRegion, target: MKCoordinateRegion) -> Animation {
        let latDiff = abs(current.center.latitude - target.center.latitude)
        let lonDiff = abs(current.center.longitude - target.center.longitude)
        let spanDiff = max(
            abs(current.span.latitudeDelta - target.span.latitudeDelta),
            abs(current.span.longitudeDelta - target.span.longitudeDelta)
        )
        let distanceFactor = latDiff + lonDiff + spanDiff
        let duration = min(0.7, max(0.3, distanceFactor * 5))
        let verticalFactor = min(1.2, max(0.8, latDiff * 10))
        return .easeInOut(duration: duration * verticalFactor)
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
