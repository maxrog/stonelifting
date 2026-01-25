//
//  MapViewModel.swift
//  StoneLifting
//
//  Created by Max Rogers on 11/12/25.
//

import MapKit
import SwiftUI
import Observation

// MARK: - Map View Model

/// ViewModel for MapView
/// Manages map state, stone clustering, and location tracking
@Observable
final class MapViewModel {
    // MARK: - Properties

    private let stoneService = StoneService.shared
    private let locationService = LocationService.shared
    private let clusteringSystem = StoneClusteringSystem()
    private let logger = AppLogger()

    // Map configuration constants
    private let initialLoadSpan = MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)
    private let locationButtonSpan = MKCoordinateSpan(latitudeDelta: 0.12, longitudeDelta: 0.12)
    private let minLatitudeDelta: CLLocationDegrees = 0.01
    private let maxLatitudeDelta: CLLocationDegrees = 180
    private let minLongitudeDelta: CLLocationDegrees = 0.01
    private let maxLongitudeDelta: CLLocationDegrees = 360
    private let zoomScaleFactor: Double = 0.6
    private let minPaddingFactor: Double = 1.2

    // Exposed state
    var mapRegion: MKCoordinateRegion?
    var selectedStone: Stone?
    var selectedCluster: StoneClusterItem?
    var showingFilters = false
    var mapFilter: MapFilter = .all
    var currentZoomLevel: Double = 0
    var isTrackingUser = false
    var hasRequestedLocation = false
    var userLocation: CLLocation?
    var showUserLocation = false

    var isLoading: Bool { stoneService.isLoadingUserStones || stoneService.isLoadingPublicStones }
    var stoneError: StoneError? { stoneService.stoneError }

    // MARK: - Computed Properties

    /// All stones (user + public) with valid locations
    var allStones: [Stone] {
        let userStones = stoneService.userStones.filter { $0.hasValidLocation }
        let publicStones = stoneService.publicStones.filter { $0.hasValidLocation }
        var combined = userStones
        for stone in publicStones where !combined.contains(where: { $0.id == stone.id }) {
            combined.append(stone)
        }
        return combined
    }

    /// Stones filtered by current filter selection
    var filteredStones: [Stone] {
        allStones.filter { stone in
            switch mapFilter {
            case .all: return true
            case .myStones: return stoneService.userStones.contains(where: { $0.id == stone.id })
            case .publicStones: return stone.isPublic && !stoneService.userStones.contains(where: { $0.id == stone.id })
            }
        }
    }

    /// Clustered stones for current map region
    var clusteredStones: [StoneClusterItem] {
        if let mapRegion {
            return clusteringSystem.generateClusters(from: filteredStones, in: mapRegion)
        } else {
            return []
        }
    }

    // MARK: - Setup Actions

    /// Initial setup for map view
    func setupMapView() async {
        logger.info("Setting up MapView for filter \(mapFilter)")
        await MainActor.run {
            guard mapRegion == nil else { return }
            Task { await centerOnUserLocation(zoomSpan: initialLoadSpan) }
        }

        await requestLocationPermission()
    }

    /// Request location permission if not already requested
    func requestLocationPermission() async {
        guard !hasRequestedLocation else { return }
        hasRequestedLocation = true

        if await locationService.authorizationStatus == .notDetermined {
            await locationService.requestLocationPermission()
        }

        if await [.authorizedWhenInUse, .authorizedAlways].contains(locationService.authorizationStatus) {
            isTrackingUser = true
            await centerOnUserLocation(zoomSpan: initialLoadSpan)
        }
    }

    // MARK: - Map Actions

    /// Update map region and calculate zoom level
    /// - Parameter region: New map region from camera change
    func updateMapRegion(_ region: MKCoordinateRegion) {
        let newZoom = calculateZoomLevel(from: region)

        // Only update if zoom changed significantly (prevents micro-updates)
        if abs(newZoom - currentZoomLevel) > 0.5 {
            currentZoomLevel = newZoom
        }

        self.mapRegion = region
    }

    /// Center map on user's current location
    /// - Parameters:
    ///   - zoomSpan: The span to use for zooming
    ///   - userInitiated: Whether this was triggered by user action (shows alert on failure)
    func centerOnUserLocation(zoomSpan: MKCoordinateSpan, userInitiated: Bool = false) async {
        if let location = await locationService.getCurrentLocation(showAlertOnFailure: userInitiated) {
            await MainActor.run {
                userLocation = location
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

    /// Adjust map to show all filtered stones
    func adjustMapToShowStones() {
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

    /// Zoom in on the map
    func zoomIn() {
        guard let mapRegion else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            let newLat = max(minLatitudeDelta, mapRegion.span.latitudeDelta * zoomScaleFactor)
            let newLon = max(minLongitudeDelta, mapRegion.span.longitudeDelta * zoomScaleFactor)

            self.mapRegion?.span = MKCoordinateSpan(
                latitudeDelta: newLat,
                longitudeDelta: newLon
            )
        }
    }

    /// Zoom out on the map
    func zoomOut() {
        guard let mapRegion else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            let newLat = min(maxLatitudeDelta, mapRegion.span.latitudeDelta / zoomScaleFactor)
            let newLon = min(maxLongitudeDelta, mapRegion.span.longitudeDelta / zoomScaleFactor)

            self.mapRegion?.span = MKCoordinateSpan(
                latitudeDelta: newLat,
                longitudeDelta: newLon
            )
        }
    }

    /// Handle selection of a cluster item (either stone or cluster)
    /// - Parameter clusterItem: The cluster item that was tapped
    func selectClusterItem(_ clusterItem: StoneClusterItem) {
        if clusterItem.isCluster {
            selectedCluster = clusterItem
        } else {
            selectedStone = clusterItem.stones.first
        }
    }

    /// Clear any error
    func clearError() {
        stoneService.clearError()
    }

    // MARK: - Helper Methods

    /// Calculate zoom level from map region
    /// - Parameter region: The map region
    /// - Returns: Zoom level value
    private func calculateZoomLevel(from region: MKCoordinateRegion) -> Double {
        let span = max(region.span.latitudeDelta, region.span.longitudeDelta)
        return max(0, 20 - log2(span * 111_000))
    }

    /// Compute dynamic animation based on distance and zoom difference
    /// - Parameters:
    ///   - current: Current map region
    ///   - target: Target map region
    /// - Returns: Animation configuration
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
