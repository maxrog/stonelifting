//
//  ReverseGeocodingService.swift
//  StoneLifting
//
//  Created by Claude Code on 1/18/26.
//

import CoreLocation
import Foundation
import Observation

// MARK: - Reverse Geocoding Service

/// Service for converting GPS coordinates to human-readable location names
/// Uses a queue to serialize requests since CLGeocoder can only handle one at a time
@Observable
@MainActor
final class ReverseGeocodingService {
    static let shared = ReverseGeocodingService()

    private let logger = AppLogger()

    /// Cache of location names keyed by rounded coordinates (4 decimal places = ~11m precision)
    private var cache: [String: String] = [:]

    /// Pending requests waiting for results (supports multiple callers for same coordinates)
    private var pendingRequests: [String: [CheckedContinuation<String?, Never>]] = [:]

    /// Request queue (CLGeocoder can only handle one request at a time)
    private var requestQueue: [(key: String, lat: Double, lon: Double)] = []
    private var isProcessingQueue = false

    private init() {
        logger.info("ReverseGeocodingService initialized")
    }

    // MARK: - Public Methods

    /// Get location name for coordinates
    func locationName(for latitude: Double, longitude: Double) async -> String? {
        let cacheKey = makeCacheKey(latitude: latitude, longitude: longitude)

        if let cached = cache[cacheKey] {
            return cached
        }

        // Queue this request (multiple callers for same coordinates share the result)
        return await withCheckedContinuation { continuation in
            if pendingRequests[cacheKey] != nil {
                // Join existing request
                logger.debug("Joining existing geocoding request for \(cacheKey)")
                pendingRequests[cacheKey]?.append(continuation)
            } else {
                // Queue new request
                logger.debug("Queueing new geocoding request for \(cacheKey)")
                pendingRequests[cacheKey] = [continuation]
                requestQueue.append((key: cacheKey, lat: latitude, lon: longitude))

                if !isProcessingQueue {
                    Task {
                        await processQueue()
                    }
                }
            }
        }
    }

    private func processQueue() async {
        guard !isProcessingQueue else { return }
        isProcessingQueue = true

        logger.info("Starting geocoding queue processing (\(requestQueue.count) requests)")

        while !requestQueue.isEmpty {
            let request = requestQueue.removeFirst()
            let cacheKey = request.key

            guard let continuations = pendingRequests[cacheKey] else {
                logger.warning("No continuations found for \(cacheKey)")
                continue
            }

            logger.debug("Processing geocoding request for \(cacheKey) (\(continuations.count) waiters)")

            // Perform geocoding and return result to all waiters
            let result = await performGeocode(latitude: request.lat, longitude: request.lon, cacheKey: cacheKey)
            for continuation in continuations {
                continuation.resume(returning: result)
            }

            pendingRequests.removeValue(forKey: cacheKey)

            // Respect rate limits
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
        }

        isProcessingQueue = false
        logger.info("Geocoding queue processing complete")
    }

    private func performGeocode(latitude: Double, longitude: Double, cacheKey: String) async -> String? {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        let geocoder = CLGeocoder()

        do {
            let result = try await withThrowingTaskGroup(of: [CLPlacemark]?.self) { group in
                group.addTask {
                    try await geocoder.reverseGeocodeLocation(location)
                }

                // Timeout task (10 seconds)
                group.addTask {
                    try await Task.sleep(nanoseconds: 10_000_000_000)
                    throw GeocodingError.timeout
                }

                // Return first result
                guard let placemarks = try await group.next() else {
                    throw GeocodingError.timeout
                }
                group.cancelAll()
                return placemarks
            }

            guard let placemark = result?.first else {
                logger.warning("No placemark found for \(cacheKey)")
                return nil
            }

            let locationName = formatLocationName(from: placemark)
            cache[cacheKey] = locationName

            logger.info("Geocoded location: \(locationName) for \(cacheKey)")
            return locationName

        } catch is CancellationError {
            logger.warning("Geocoding cancelled for \(cacheKey)")
            return nil
        } catch let error as GeocodingError where error == .timeout {
            logger.error("Geocoding timed out for \(cacheKey)")
            return nil
        } catch {
            logger.error("Geocoding failed for \(cacheKey)", error: error)
            return nil
        }
    }

    func clearCache() {
        logger.info("Clearing geocoding cache (\(cache.count) entries, \(pendingRequests.count) pending)")
        cache.removeAll()

        // Resume all pending continuations with nil
        for (_, continuations) in pendingRequests {
            for continuation in continuations {
                continuation.resume(returning: nil)
            }
        }
        pendingRequests.removeAll()
        requestQueue.removeAll()
        isProcessingQueue = false
    }

    // MARK: - Private Methods

    /// Round coordinates to 4 decimal places (~11m precision) for cache key
    private func makeCacheKey(latitude: Double, longitude: Double) -> String {
        let roundedLat = round(latitude * 10000) / 10000
        let roundedLon = round(longitude * 10000) / 10000
        return "\(roundedLat),\(roundedLon)"
    }

    /// Format placemark into concise location string
    /// Priority: Park/Area → City, State → Neighborhood → State, Country
    private func formatLocationName(from placemark: CLPlacemark) -> String {
        // Parks, trails, beaches, etc.
        if let area = placemark.areasOfInterest?.first {
            if let state = placemark.administrativeArea {
                return "\(area), \(state)"
            } else if let country = placemark.country {
                return "\(area), \(country)"
            }
            return area
        }

        // City, State (US) or City, Country (international)
        if let locality = placemark.locality {
            if let state = placemark.administrativeArea {
                return "\(locality), \(state)"
            } else if let country = placemark.country {
                return "\(locality), \(country)"
            }
            return locality
        }

        // Neighborhood/sub-locality
        if let subLocality = placemark.subLocality {
            if let state = placemark.administrativeArea {
                return "\(subLocality), \(state)"
            }
            return subLocality
        }

        // State, Country (rural areas)
        if let state = placemark.administrativeArea, let country = placemark.country {
            return "\(state), \(country)"
        }

        return placemark.country ?? "Unknown Location"
    }
}

// MARK: - Geocoding Error

enum GeocodingError: Error, Equatable {
    case timeout
}
