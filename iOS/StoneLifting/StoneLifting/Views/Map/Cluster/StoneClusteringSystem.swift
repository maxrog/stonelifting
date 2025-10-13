//
//  StoneClusteringSystem.swift
//  StoneLifting
//
//  Created by Max Rogers on 10/4/25.
//

import Foundation
import MapKit

/// Handles clustering of stones based on map zoom level and proximity
class StoneClusteringSystem {

    // MARK: - Properties

    /// Minimum distance between pins before clustering (in meters)
    private let clusterDistance: CLLocationDistance

    /// Zoom level thresholds for clustering behavior
    private let zoomThresholds: ZoomThresholds

    // MARK: - Initialization

    init(clusterDistance: CLLocationDistance = 1000) { // 1km default
        self.clusterDistance = clusterDistance
        self.zoomThresholds = ZoomThresholds()
    }

    // MARK: - Public Methods

    /// Generate clusters from stones based on current map region
    /// - Parameters:
    ///   - stones: Array of stones to cluster
    ///   - region: Current map region (determines zoom level)
    /// - Returns: Array of clusters or individual stones
    func generateClusters(from stones: [Stone], in region: MKCoordinateRegion) -> [StoneClusterItem] {
        // Determine if we should cluster based on zoom level
        let currentZoom = calculateZoomLevel(from: region)
        let shouldCluster = currentZoom < zoomThresholds.individualPinThreshold

        guard shouldCluster && stones.count > 1 else {
            // Show individual pins
            return stones.compactMap { stone in
                guard stone.hasValidLocation else { return nil }
                return StoneClusterItem.individual(stone)
            }
        }

        // Perform clustering
        return performClustering(stones: stones, region: region)
    }

    // MARK: - Private Methods

    /// Perform the actual clustering algorithm
    private func performClustering(stones: [Stone], region: MKCoordinateRegion) -> [StoneClusterItem] {
        var clusters: [StoneClusterItem] = []
        var processedStones: Set<UUID> = []

        let validStones = stones.filter { $0.hasValidLocation }

        for stone in validStones {
            guard let stoneId = stone.id, !processedStones.contains(stoneId) else { continue }

            // Find nearby stones
            let nearbyStones = findNearbyStones(to: stone, in: validStones, excluding: processedStones)

            if nearbyStones.count > 1 {
                // Create cluster
                let center = calculateCenterCoordinate(for: nearbyStones)
                let cluster = StoneClusterItem.cluster(
                    id: UUID(),
                    coordinate: center,
                    stones: nearbyStones,
                    count: nearbyStones.count
                )
                clusters.append(cluster)

                // Mark stones as processed
                for nearbyStone in nearbyStones {
                    if let id = nearbyStone.id {
                        processedStones.insert(id)
                    }
                }
            } else {
                // Individual stone
                let individual = StoneClusterItem.individual(stone)
                clusters.append(individual)
                processedStones.insert(stoneId)
            }
        }

        return clusters
    }

    /// Find stones within clustering distance
    private func findNearbyStones(to targetStone: Stone, in allStones: [Stone], excluding processed: Set<UUID>) -> [Stone] {
        let targetLocation = CLLocation(
            latitude: targetStone.latitude!,
            longitude: targetStone.longitude!
        )

        var nearbyStones: [Stone] = [targetStone]

        for stone in allStones {
            guard let stoneId = stone.id,
                  stone.id != targetStone.id,
                  !processed.contains(stoneId),
                  let lat = stone.latitude,
                  let lon = stone.longitude else { continue }

            let stoneLocation = CLLocation(latitude: lat, longitude: lon)
            let distance = targetLocation.distance(from: stoneLocation)

            if distance <= clusterDistance {
                nearbyStones.append(stone)
            }
        }

        return nearbyStones
    }

    /// Calculate center coordinate for a group of stones
    private func calculateCenterCoordinate(for stones: [Stone]) -> CLLocationCoordinate2D {
        guard !stones.isEmpty else { return CLLocationCoordinate2D() }

        let latitudes = stones.compactMap { $0.latitude }
        let longitudes = stones.compactMap { $0.longitude }

        let centerLat = latitudes.reduce(0, +) / Double(latitudes.count)
        let centerLon = longitudes.reduce(0, +) / Double(longitudes.count)

        return CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon)
    }

    /// Calculate zoom level from map region span
    private func calculateZoomLevel(from region: MKCoordinateRegion) -> Double {
        // Rough approximation of zoom level based on span
        // Lower span = higher zoom level
        let span = max(region.span.latitudeDelta, region.span.longitudeDelta)
        return max(0, 20 - log2(span * 111000)) // Convert degrees to meters roughly
    }
}

// MARK: - Supporting Types

/// Represents either a single stone or a cluster of stones
enum StoneClusterItem: Identifiable {
    case individual(Stone)
    case cluster(id: UUID, coordinate: CLLocationCoordinate2D, stones: [Stone], count: Int)

    var id: UUID {
        switch self {
        case .individual(let stone):
            return stone.id ?? UUID()
        case .cluster(let id, _, _, _):
            return id
        }
    }

    var coordinate: CLLocationCoordinate2D {
        switch self {
        case .individual(let stone):
            return stone.coordinate
        case .cluster(_, let coordinate, _, _):
            return coordinate
        }
    }

    var isCluster: Bool {
        switch self {
        case .individual:
            return false
        case .cluster:
            return true
        }
    }

    var stones: [Stone] {
        switch self {
        case .individual(let stone):
            return [stone]
        case .cluster(_, _, let stones, _):
            return stones
        }
    }

    var count: Int {
        switch self {
        case .individual:
            return 1
        case .cluster(_, _, _, let count):
            return count
        }
    }
}

/// Configuration for zoom level thresholds
struct ZoomThresholds {
    /// Below this zoom level, show individual pins instead of clusters
    let individualPinThreshold: Double = 15

    /// Above this zoom level, always show clusters regardless of distance
    let forceClusterThreshold: Double = 8
}
