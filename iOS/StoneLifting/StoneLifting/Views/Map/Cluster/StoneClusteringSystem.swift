import Foundation
import MapKit

/// Handles clustering of stones based on map zoom level and proximity
final class StoneClusteringSystem {

    // MARK: - Properties

    /// Zoom level thresholds for clustering behavior
    private let zoomThresholds: ZoomThresholds

    init() {
        self.zoomThresholds = ZoomThresholds()
    }

    /// Generate clusters from stones based on the current map region
    /// - Parameters:
    ///   - stones: Array of stones to cluster
    ///   - region: Current visible map region
    /// - Returns: Array of cluster items (either individual stones or clusters)
    func generateClusters(from stones: [Stone], in region: MKCoordinateRegion) -> [StoneClusterItem] {
        let currentZoom = calculateZoomLevel(from: region)
        let shouldCluster = currentZoom < zoomThresholds.individualPinThreshold

        guard shouldCluster, stones.count > 1 else {
            return stones.compactMap { stone in
                guard stone.hasValidLocation else { return nil }
                return StoneClusterItem.individual(stone)
            }
        }

        let dynamicDistance = calculateClusterDistance(for: region, zoomLevel: currentZoom)

        return performClustering(stones: stones, clusterDistance: dynamicDistance)
    }

    /// Calculate dynamic clustering distance based on map region
    /// At far zoom: cluster stones far apart
    /// At close zoom: only cluster stones very close together
    /// - Parameters:
    ///   - region: Current visible map region
    ///   - zoomLevel: Calculated zoom level
    /// - Returns: Clustering distance in meters
    private func calculateClusterDistance(for region: MKCoordinateRegion, zoomLevel: Double) -> CLLocationDistance {
        // Convert span to approximate meters at the region's center latitude
        let latitudinalMeters = region.span.latitudeDelta * 111_000 // ~111km per degree
        let cosLat = cos(region.center.latitude * .pi / 180)
        let longitudinalMeters = region.span.longitudeDelta * 111_000 * cosLat

        // Use the larger dimension
        let regionSizeMeters = max(latitudinalMeters, longitudinalMeters)

        // TODO adjust this up or down to change cluster behavior
        // Cluster stones that are within 5% of the visible region
        // This means at world view, stones 500km apart will cluster
        // At city view, stones 500m apart will cluster
        let dynamicDistance = regionSizeMeters * 0.05

        // Clamp to reasonable bounds
        let minDistance: CLLocationDistance = 100 // Never cluster below 100m
        let maxDistance: CLLocationDistance = 500_000 // Max 500km clustering

        return max(minDistance, min(maxDistance, dynamicDistance))
    }

    /// Perform clustering algorithm on stones using specified distance threshold
    /// - Parameters:
    ///   - stones: Array of stones to cluster
    ///   - clusterDistance: Maximum distance between stones to form a cluster
    /// - Returns: Array of cluster items
    private func performClustering(stones: [Stone], clusterDistance: CLLocationDistance) -> [StoneClusterItem] {
        var clusters: [StoneClusterItem] = []
        var processed: Set<UUID> = []

        let validStones = stones.filter { $0.hasValidLocation }

        for stone in validStones {
            guard let id = stone.id, !processed.contains(id) else { continue }

            let nearby = findNearbyStones(to: stone, in: validStones, excluding: processed, distance: clusterDistance)
            if nearby.count > 1 {
                let center = calculateCenterCoordinate(for: nearby)

                // Generate stable cluster ID based on stone IDs
                let clusterID = generateStableClusterID(for: nearby)

                let cluster = StoneClusterItem.cluster(
                    id: clusterID,
                    coordinate: center,
                    stones: nearby,
                    count: nearby.count
                )
                clusters.append(cluster)
                nearby.compactMap { $0.id }.forEach { processed.insert($0) }
            } else {
                clusters.append(.individual(stone))
                processed.insert(id)
            }
        }
        return clusters
    }

    /// Find stones within specified distance of target stone
    /// - Parameters:
    ///   - target: Stone to search around
    ///   - all: All stones to search through
    ///   - processed: Set of stone IDs already processed
    ///   - distance: Maximum distance in meters
    /// - Returns: Array of nearby stones including the target
    private func findNearbyStones(to target: Stone, in all: [Stone], excluding processed: Set<UUID>, distance: CLLocationDistance) -> [Stone] {
        guard let targetId = target.id,
              let targetLat = target.latitude,
              let targetLon = target.longitude else { return [] }

        let targetLoc = CLLocation(latitude: targetLat, longitude: targetLon)
        var nearby: [Stone] = [target]

        for stone in all {
            guard let id = stone.id, id != targetId, !processed.contains(id),
                  let lat = stone.latitude, let lon = stone.longitude else { continue }

            let dist = targetLoc.distance(from: CLLocation(latitude: lat, longitude: lon))
            if dist <= distance { nearby.append(stone) }
        }
        return nearby
    }

    /// Calculate geographic center coordinate of multiple stones
    /// - Parameter stones: Stones to calculate center from
    /// - Returns: Center coordinate
    private func calculateCenterCoordinate(for stones: [Stone]) -> CLLocationCoordinate2D {
        let latitudes = stones.compactMap { $0.latitude }
        let longitudes = stones.compactMap { $0.longitude }
        let centerLat = latitudes.reduce(0, +) / Double(latitudes.count)
        let centerLon = longitudes.reduce(0, +) / Double(longitudes.count)
        return CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon)
    }

    /// Calculate zoom level from map region span
    /// - Parameter region: Map region
    /// - Returns: Approximate zoom level (higher = more zoomed in)
    private func calculateZoomLevel(from region: MKCoordinateRegion) -> Double {
        let span = max(region.span.latitudeDelta, region.span.longitudeDelta)
        return max(0, 20 - log2(span * 111_000)) // approximate meters per degree
    }
    
    /// Generate deterministic cluster ID from stone IDs
    /// Uses DJB2 hash algorithm to ensure stable IDs across app launches
    /// - Parameter stones: Stones in the cluster
    /// - Returns: Stable UUID that will be the same for the same set of stones
    private func generateStableClusterID(for stones: [Stone]) -> UUID {
        // Sort stone IDs to ensure consistent ordering
        let sortedIDs = stones.compactMap { $0.id }.sorted { $0.uuidString < $1.uuidString }

        // Create a stable string from the sorted IDs
        let combinedString = sortedIDs.map { $0.uuidString }.joined(separator: "-")

        // Use DJB2 hash algorithm for deterministic hashing
        var hash: UInt64 = 5381
        for char in combinedString.utf8 {
            hash = ((hash << 5) &+ hash) &+ UInt64(char)
        }

        // Create UUID from the hash (split into components)
        let hash1 = UInt32(hash & 0xFFFFFFFF)
        let hash2 = UInt32((hash >> 32) & 0xFFFFFFFF)

        // Generate additional entropy from string length and first/last chars
        let length = UInt16(combinedString.count)
        let firstChar = UInt8(combinedString.first?.asciiValue ?? 0)
        let lastChar = UInt8(combinedString.last?.asciiValue ?? 0)

        // Build deterministic UUID string (Version 5 format)
        let uuidString = String(
            format: "%08X-%04X-5%03X-%04X-%02X%02X%08X",
                                hash1,
                                UInt16((hash >> 16) & 0xFFFF),
                                length & 0xFFF, // 12 bits
                                UInt16((hash >> 48) & 0xFFFF),
                                firstChar,
                                lastChar,
                                hash2
        )

        return UUID(uuidString: uuidString) ?? UUID()
    }
}

// MARK: - Supporting Types

/// Zoom level thresholds for controlling clustering behavior
struct ZoomThresholds {
    /// Below this zoom level, show individual pins instead of clusters
    let individualPinThreshold: Double = 15
    /// Below this zoom level, force clustering
    let forceClusterThreshold: Double = 8
}

/// Represents either a single stone or a cluster of stones
enum StoneClusterItem: Identifiable, Hashable {
    case individual(Stone)
    case cluster(id: UUID, coordinate: CLLocationCoordinate2D, stones: [Stone], count: Int)

    var id: UUID {
        switch self {
        case .individual(let stone): return stone.id ?? UUID()
        case .cluster(let id, _, _, _): return id
        }
    }

    var coordinate: CLLocationCoordinate2D {
        switch self {
        case .individual(let stone): return stone.coordinate
        case .cluster(_, let coord, _, _): return coord
        }
    }

    var stones: [Stone] {
        switch self {
        case .individual(let stone): return [stone]
        case .cluster(_, _, let stones, _): return stones
        }
    }

    var count: Int {
        switch self {
        case .individual: return 1
        case .cluster(_, _, _, let count): return count
        }
    }

    var isCluster: Bool {
        switch self {
        case .individual: return false
        case .cluster: return true
        }
    }

    // MARK: - Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: StoneClusterItem, rhs: StoneClusterItem) -> Bool {
        lhs.id == rhs.id
    }
}
