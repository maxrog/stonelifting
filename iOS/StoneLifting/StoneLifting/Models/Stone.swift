//
//  Stone.swift
//  StoneLifting
//
//  Created by Max Rogers on 7/10/25.
//

import CoreLocation
import Foundation

// MARK: - Stone Type

/// Types of stone with different densities for weight estimation
enum StoneType: String, CaseIterable, Codable {
    case granite
    case limestone
    case sandstone
    case basalt
    case marble

    var displayName: String {
        switch self {
        case .granite: return "Granite"
        case .limestone: return "Limestone"
        case .sandstone: return "Sandstone"
        case .basalt: return "Basalt"
        case .marble: return "Marble"
        }
    }

    /// Density in pounds per cubic foot
    var density: Double {
        switch self {
        case .granite: return 165.0    // ~2650 kg/m³ - Most common
        case .limestone: return 160.0  // ~2560 kg/m³
        case .sandstone: return 145.0  // ~2320 kg/m³ - Lighter
        case .basalt: return 184.0     // ~2950 kg/m³ - Volcanic, very dense
        case .marble: return 170.0     // ~2720 kg/m³
        }
    }

    var icon: String {
        switch self {
        case .granite: return "cube.fill"
        case .limestone: return "cube.fill"
        case .sandstone: return "cube.fill"
        case .basalt: return "cube.fill"
        case .marble: return "cube.fill"
        }
    }

    var description: String {
        switch self {
        case .granite: return "Very common, hard rock"
        case .limestone: return "Sedimentary, medium density"
        case .sandstone: return "Lighter, porous rock"
        case .basalt: return "Volcanic, very dense"
        case .marble: return "Metamorphic, dense rock"
        }
    }
}

// MARK: - Stone Models

/// Represents a stone lifting record
/// Matches the Stone model from the Vapor backend
struct Stone: Codable, Identifiable {
    /// Unique identifier for the stone record
    let id: UUID?

    /// Name of the stone
    var name: String?

    /// Confirmed weight of the stone in pounds/kilograms (optional if estimated weight provided)
    var weight: Double?

    /// AI-estimated weight (optional if confirmed weight provided)
    var estimatedWeight: Double?

    /// Type of stone (for density calculations)
    var stoneType: String?

    /// User's description of the stone or lift
    var description: String?

    /// URL to the stone's image
    var imageUrl: String?

    /// Geographic latitude of the stone's location
    var latitude: Double?

    /// Geographic longitude of the stone's location
    var longitude: Double?

    /// Human-readable location name (e.g., "Central Park")
    var locationName: String?

    /// Whether this stone is visible to other users
    var isPublic: Bool

    /// Level of lifting completion achieved
    var liftingLevel: LiftingLevel

    /// Distance carried in feet (optional)
    var carryDistance: Double?

    /// When this stone record was created
    let createdAt: Date?

    /// Information about the user who logged this stone
    let user: User
}

// MARK: - Stone Request Models

/// Request payload for creating a new stone record
struct CreateStoneRequest: Codable {
    /// Name of the stone
    let name: String?

    /// Confirmed weight of the stone (optional if estimated weight provided)
    let weight: Double?

    /// AI-estimated weight for comparison (optional if confirmed weight provided)
    let estimatedWeight: Double?

    /// Type of stone for density calculations
    let stoneType: String?

    /// Description of the stone or lift experience
    let description: String?

    /// URL to uploaded image
    let imageUrl: String?

    /// Latitude coordinate
    let latitude: Double?

    /// Longitude coordinate
    let longitude: Double?

    /// Human-readable location name
    let locationName: String?

    /// Whether to make this stone visible to other users
    let isPublic: Bool

    /// Level of lifting completion achieved
    let liftingLevel: String

    /// Distance carried in feet (optional)
    let carryDistance: Double?
}

// MARK: - Lifting Level

/// Stone lifting completion levels
enum LiftingLevel: String, Codable, CaseIterable {
    case wind, lap, chest, shoulder, overhead

    /// Display name for the lifting level
    var displayName: String {
        switch self {
        case .wind: return "Getting Wind"
        case .lap: return "Stone to Lap"
        case .chest: return "Stone to Chest"
        case .shoulder: return "Stone to Shoulder"
        case .overhead: return "Stone Overhead"
        }
    }

    /// Short description of the achievement
    var description: String {
        switch self {
        case .wind: return "Lifted stone just off the ground"
        case .lap: return "Lifted stone to lap/thigh level"
        case .chest: return "Lifted stone to chest level"
        case .shoulder: return "Lifted stone to shoulder level"
        case .overhead: return "Pressed stone overhead"
        }
    }

    /// Icon representing the lifting level
    var icon: String {
        switch self {
        case .wind: return "arrow.up.circle"
        case .lap: return "figure.seated.side"
        case .chest: return "figure.arms.open"
        case .shoulder: return "figure.strengthtraining.functional"
        case .overhead: return "figure.strengthtraining.functional"
        }
    }

    /// Color associated with the lifting level
    var color: String {
        switch self {
        case .wind: return "orange"
        case .lap: return "yellow"
        case .chest: return "blue"
        case .shoulder: return "green"
        case .overhead: return "green"
        }
    }

    /// Achievement level (1-4, higher is better)
    var level: Int {
        switch self {
        case .wind: return 1
        case .lap: return 2
        case .chest: return 3
        case .shoulder: return 4
        case .overhead: return 4
        }
    }
}

// MARK: - Stone Computed Properties

extension Stone {
    /// CL coordinate of stone location
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: latitude ?? 0,
            longitude: longitude ?? 0
        )
    }

    /// Returns whether stone has valid location data
    var hasValidLocation: Bool {
        guard let lat = latitude, let lon = longitude else { return false }
        return lat != 0 && lon != 0 && abs(lat) <= 90 && abs(lon) <= 180
    }

    /// Returns a formatted weight string with units
    var formattedWeight: String {
        if let weight = weight {
            return String(format: "%.1f lbs", weight)
        } else if let estimatedWeight = estimatedWeight {
            return String(format: "~%.1f lbs", estimatedWeight)
        } else {
            return "Unknown"
        }
    }

    /// Returns the difference between confirmed and estimated weight
    var estimationAccuracy: Double? {
        guard let weight = weight, let estimated = estimatedWeight else { return nil }
        return abs(weight - estimated)
    }

    /// Returns formatted carry distance
    var formattedCarryDistance: String? {
        guard let distance = carryDistance, distance > 0 else { return nil }
        return String(format: "%.0f ft", distance)
    }

    /// Returns full achievement description
    var achievementDescription: String {
        var description = liftingLevel.displayName
        if let distance = formattedCarryDistance {
            description += " • Carried \(distance)"
        }
        return description
    }
}

// MARK: - Stone Stats

/// Stone lifting statistics
struct StoneStats {
    let stones: [Stone]

    var totalStones: Int {
        stones.count
    }

    var totalWeight: Double {
        stones.reduce(0) { $0 + ($1.weight ?? $1.estimatedWeight ?? 0) }
    }

    var heaviestStone: Double {
        stones.compactMap { $0.weight ?? $0.estimatedWeight }.max() ?? 0
    }

    var averageWeight: Double {
        totalStones > 0 ? totalWeight / Double(totalStones) : 0
    }

    var publicStones: Int {
        stones.filter { $0.isPublic }.count
    }

    var privateStones: Int {
        stones.filter { !$0.isPublic }.count
    }

    var stonesWithLocation: Int {
        stones.filter { $0.hasValidLocation }.count
    }
}
