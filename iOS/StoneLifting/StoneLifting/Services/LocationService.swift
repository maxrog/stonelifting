//
//  LocationService.swift
//  StoneLifting
//
//  Created by Max Rogers on 7/16/25.
//

import Foundation
import CoreLocation
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
    private(set) var currentLocation: CLLocation?
    private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    private(set) var isLocationEnabled = false
    private(set) var locationError: LocationError?

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

        authorizationStatus = locationManager.authorizationStatus
        isLocationEnabled = CLLocationManager.locationServicesEnabled()

        logger.debug("Location manager configured - Status: \(authorizationStatus.description), Enabled: \(isLocationEnabled)")
    }

    // MARK: - Permission Management

    func requestLocationPermission() {
        logger.info("Requesting location permission")

        switch authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            logger.warning("Location permission denied - directing user to settings")
            // TODO show alert directing user to settings
        case .authorizedWhenInUse, .authorizedAlways:
            logger.info("Location permission already granted")
            startLocationUpdates()
        @unknown default:
            logger.error("Unknown location authorization status")
        }
    }

    // MARK: - Location Updates

    private func startLocationUpdates() {
        guard isLocationEnabled && (authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways) else {
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

    func getCurrentLocation() async -> CLLocation? {
        logger.info("Getting current location")

        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            logger.warning("Cannot get location - not authorized")
            locationError = .notAuthorized
            return nil
        }

        guard isLocationEnabled else {
            logger.warning("Cannot get location - services disabled")
            locationError = .servicesDisabled
            return nil
        }

        locationManager.requestLocation()

        // TODO Wait for location update (simplified - in production use proper async/await)
        return currentLocation
    }

    // MARK: - Utility Methods

    /// Get human-readable address from coordinates
    /// - Parameters:
    ///   - latitude: Latitude coordinate
    ///   - longitude: Longitude coordinate
    /// - Returns: Formatted address string
    func getAddressFromCoordinates(latitude: Double, longitude: Double) async -> String? {
        logger.debug("Getting address for coordinates: \(latitude), \(longitude)")

        let location = CLLocation(latitude: latitude, longitude: longitude)
        let geocoder = CLGeocoder()

        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)

            if let placemark = placemarks.first {
                let address = formatAddress(from: placemark)
                logger.debug("Address found: \(address)")
                return address
            }
        } catch {
            logger.error("Failed to get address from coordinates", error: error)
        }

        return nil
    }

    /// Format address from placemark
    /// - Parameter placemark: CLPlacemark object
    /// - Returns: Formatted address string
    private func formatAddress(from placemark: CLPlacemark) -> String {
        var components: [String] = []

        if let name = placemark.name {
            components.append(name)
        }

        if let locality = placemark.locality {
            components.append(locality)
        }

        if let administrativeArea = placemark.administrativeArea {
            components.append(administrativeArea)
        }

        return components.joined(separator: ", ")
    }

    /// Clear current location error
    func clearError() {
        logger.debug("Clearing location error")
        locationError = nil
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        currentLocation = location
        logger.info("Location updated: \(location.coordinate.latitude), \(location.coordinate.longitude)")

        // Clear any previous errors
        locationError = nil

        // Stop updates after getting location (for one-time requests)
        // TODO might want to continue updates for tracking
        stopLocationUpdates()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        logger.error("Location manager failed", error: error)

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

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        logger.info("Location authorization changed: \(status.description)")

        authorizationStatus = status

        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            startLocationUpdates()
        case .denied, .restricted:
            stopLocationUpdates()
            locationError = .notAuthorized
        case .notDetermined:
            break
        @unknown default:
            logger.error("Unknown authorization status: \(status.rawValue)")
        }
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
        case .unknownError(let message):
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
