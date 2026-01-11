//
//  LocationService.swift
//  StoneLifting
//
//  Created by Max Rogers on 7/16/25.
//

import CoreLocation
import Foundation
import Observation

// MARK: - Location Service

/// Service responsible for location-related operations
/// Handles GPS coordinates, location permissions, and nearby stone searches
@Observable
final class LocationService: NSObject {
    // MARK: - Properties

    static let shared = LocationService()
    private let logger = AppLogger()

    private let locationManager = CLLocationManager()
    private let continuationManager = LocationContinuationManager()

    private(set) var currentLocation: CLLocation?
    private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    private(set) var isLocationEnabled = false
    private(set) var locationError: LocationError?
    var showSettingsAlert = false

    // MARK: - Initialization

    override init() {
        super.init()
        logger.info("LocationService initialized")
        setupLocationManager()
    }

    // MARK: - Setup

    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10 // Update every 10 meters

        Task { @MainActor in
            authorizationStatus = locationManager.authorizationStatus
            isLocationEnabled = authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
        }
    }

    // MARK: - Permission Management

    func requestLocationPermission() {
        logger.info("Requesting location permission")

        switch authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            logger.warning("Location permission denied - directing user to settings")
            locationError = .notAuthorized
            showSettingsAlert = true
        case .authorizedWhenInUse, .authorizedAlways:
            logger.info("Location permission already granted")
            startLocationUpdates()
        @unknown default:
            logger.error("Unknown location authorization status")
        }
    }

    // MARK: - Location Updates

    private func startLocationUpdates() {
        guard isLocationEnabled, authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            logger.warning("Cannot start location updates - not authorized or disabled")
            return
        }

        logger.info("Starting location updates")
        locationManager.startUpdatingLocation()
    }

    private func stopLocationUpdates() {
        logger.info("Stopping location updates")
        locationManager.stopUpdatingLocation()
    }

    /// Gets current location asynchronously with timeout protection
    /// Uses actor-based continuation management to prevent leaks and race conditions
    /// - Returns: Current CLLocation or nil if unavailable/timeout
    func getCurrentLocation(showAlertOnFailure: Bool = false) async -> CLLocation? {
        logger.info("Getting current location")

        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            logger.warning("Cannot get location - not authorized")
            locationError = .notAuthorized
            if showAlertOnFailure {
                await MainActor.run {
                    showSettingsAlert = true
                }
            }
            return nil
        }

        guard isLocationEnabled else {
            logger.warning("Cannot get location - services disabled")
            locationError = .servicesDisabled
            if showAlertOnFailure {
                await MainActor.run {
                    showSettingsAlert = true
                }
            }
            return nil
        }

        // Check for recent cached location (within 30 seconds)
        if let current = currentLocation,
           current.timestamp.timeIntervalSinceNow > -30 {
            logger.debug("Returning cached location")
            return current
        }

        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                Task {
                    await continuationManager.setContinuation(continuation)

                    await MainActor.run { [weak self] in
                        self?.locationManager.requestLocation()
                    }

                    // Timeout after 10 seconds with automatic cleanup
                    Task { [weak self] in
                        do {
                            try await Task.sleep(nanoseconds: 10_000_000_000)
                        } catch is CancellationError {
                            return
                        }

                        guard let self else { return }

                        // Safely resume with cached location if available
                        let cachedLocation = await MainActor.run { self.currentLocation }
                        await self.continuationManager.resumeIfNeeded(with: cachedLocation)

                        await MainActor.run {
                            self.logger.warning("Location request timed out")
                        }
                    }
                }
            }
        } onCancel: {
            Task {
                await continuationManager.resumeIfNeeded(with: nil)
            }
        }
    }

    // MARK: - Utility Methods

    /// Clear current location error
    func clearError() {
        logger.debug("Clearing location error")
        locationError = nil
    }

    func clearCachedLocation() {
        logger.debug("Clearing cached location")
        currentLocation = nil
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {
    func locationManager(_: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        currentLocation = location
        logger.info("Location updated: \(location.coordinate.latitude), \(location.coordinate.longitude)")

        // Clear any previous errors
        locationError = nil

        // Safely resume continuation if one is pending
        Task {
            await continuationManager.resumeIfNeeded(with: location)
        }

        // Stop updates after getting location (for one-time requests)
        stopLocationUpdates()
    }

    func locationManager(_: CLLocationManager, didFailWithError error: Error) {
        logger.error("Location manager failed", error: error)

        // Safely resume continuation with current location or nil
        Task { [weak self] in
            guard let self else { return }
            let currentLoc = await MainActor.run { self.currentLocation }
            await self.continuationManager.resumeIfNeeded(with: currentLoc)
        }

        if let clError = error as? CLError {
            switch clError.code {
            case .denied:
                locationError = .notAuthorized
            case .locationUnknown:
                locationError = .locationUnavailable
            case .network:
                locationError = .networkError
            default:
                locationError = .unknownError(error.localizedDescription)
            }
        } else {
            locationError = .unknownError(error.localizedDescription)
        }
    }

    func locationManager(_: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        logger.info("Location authorization changed: \(status.description)")

        authorizationStatus = status

        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            startLocationUpdates()
            isLocationEnabled = true
        case .denied, .restricted:
            stopLocationUpdates()
            locationError = .notAuthorized
            isLocationEnabled = false
            // Clear cached location when permissions are revoked
            currentLocation = nil
            logger.info("Cleared cached location due to denied/restricted authorization")
        case .notDetermined:
            isLocationEnabled = false
            // Clear cached location when status is reset
            currentLocation = nil
        @unknown default:
            isLocationEnabled = false
            currentLocation = nil
            logger.error("Unknown authorization status: \(status.rawValue)")
        }
    }
}

// MARK: - Location Continuation Manager

/// Actor for thread-safe continuation management
/// Prevents race conditions between location updates and timeouts
actor LocationContinuationManager {
    private var continuation: CheckedContinuation<CLLocation?, Never>?
    private var hasResumed = false

    /// Sets a new continuation for location request
    func setContinuation(_ cont: CheckedContinuation<CLLocation?, Never>) {
        // Resume any existing continuation before overwriting
        if !hasResumed, let existingCont = continuation {
            existingCont.resume(returning: nil)
        }

        continuation = cont
        hasResumed = false
    }

    /// Safely resumes continuation if not already resumed
    /// - Parameter location: Location to return (or nil)
    func resumeIfNeeded(with location: CLLocation?) {
        guard !hasResumed, let cont = continuation else { return }
        hasResumed = true
        continuation = nil
        cont.resume(returning: location)
    }

    /// Clears continuation state
    func clear() {
        continuation = nil
        hasResumed = false
    }
}

// MARK: - Supporting Types

/// Location service error types
enum LocationError: Error, LocalizedError {
    case notAuthorized
    case servicesDisabled
    case locationUnavailable
    case networkError
    case unknownError(String)

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Location access denied. Please enable location services in Settings."
        case .servicesDisabled:
            return "Location services are disabled. Please enable them in Settings."
        case .locationUnavailable:
            return "Unable to determine your location. Please try again."
        case .networkError:
            return "Network error while getting location. Please check your connection."
        case let .unknownError(message):
            return message
        }
    }
}

// MARK: - Extensions

extension CLAuthorizationStatus {
    var description: String {
        switch self {
        case .notDetermined: return "notDetermined"
        case .restricted: return "restricted"
        case .denied: return "denied"
        case .authorizedAlways: return "authorizedAlways"
        case .authorizedWhenInUse: return "authorizedWhenInUse"
        @unknown default: return "unknown"
        }
    }
}
