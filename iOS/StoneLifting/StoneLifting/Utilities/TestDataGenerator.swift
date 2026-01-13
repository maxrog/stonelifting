//
//  TestDataGenerator.swift
//  StoneLifting
//
//  Created for testing and debugging purposes only
//

import Foundation
import CoreLocation

#if DEBUG

/// Generates mock stone data for testing app performance at scale
/// Only available in DEBUG builds
enum TestDataGenerator {

    /// Generate a large number of mock stones
    /// - Parameters:
    ///   - count: Number of stones to generate
    ///   - centerLat: Center latitude for stone distribution
    ///   - centerLon: Center longitude for stone distribution
    ///   - radiusKm: Radius in kilometers to spread stones
    /// - Returns: Array of mock Stone objects
    static func generateStones(
        count: Int,
        centerLat: Double = 40.7128,  // Default: NYC
        centerLon: Double = -74.0060,
        radiusKm: Double = 50.0
    ) -> [Stone] {
        var stones: [Stone] = []

        let stoneNames = [
            "Boulder", "Rock", "Stone", "Granite Slab", "Limestone",
            "Sandstone", "River Rock", "Fieldstone", "Atlas Stone",
            "Dinnie Stone", "McGlashen Stone", "Husafell Stone"
        ]

        let descriptions = [
            "Found in a field",
            "Natural stone from the river",
            "Classic lifting stone",
            "Heavy and challenging",
            "Great for training",
            "Local gym stone",
            "Competition stone",
            nil, nil  // Some stones have no description
        ]

        for i in 0..<count {
            let id = UUID()

            // Random location within radius
            let (lat, lon) = randomCoordinate(
                centerLat: centerLat,
                centerLon: centerLon,
                radiusKm: radiusKm
            )

            // Random weight between 50-400 lbs
            let weight = Double.random(in: 50...400)

            // 30% chance of having estimated weight instead
            let hasEstimatedWeight = Double.random(in: 0...1) < 0.3

            // Random lifting level based on weight
            let liftingLevel = determineLiftingLevel(weight: weight)

            // 70% chance of being public
            let isPublic = Double.random(in: 0...1) < 0.7

            let mockUser = User(
                id: UUID(),
                username: "TestUser\(i + 1)",
                email: "test\(i + 1)@example.com",
                createdAt: Date()
            )

            let stone = Stone(
                id: id,
                name: "\(stoneNames.randomElement()!) #\(i + 1)",
                weight: hasEstimatedWeight ? nil : weight,
                estimatedWeight: hasEstimatedWeight ? weight : nil,
                stoneType: nil,
                description: descriptions.randomElement() ?? nil,
                imageUrl: nil,
                latitude: lat,
                longitude: lon,
                locationName: "Test Location \(i + 1)",
                isPublic: isPublic,
                liftingLevel: liftingLevel,
                createdAt: Date().addingTimeInterval(-Double.random(in: 0...2_592_000)), // Random date within last 30 days
                user: mockUser
            )

            stones.append(stone)
        }

        return stones
    }

    /// Generate random coordinate within radius of center point
    private static func randomCoordinate(
        centerLat: Double,
        centerLon: Double,
        radiusKm: Double
    ) -> (Double, Double) {
        // Convert radius to degrees (rough approximation)
        let radiusInDegrees = radiusKm / 111.0

        // Random angle
        let angle = Double.random(in: 0...(2 * .pi))

        // Random distance within radius
        let distance = Double.random(in: 0...radiusInDegrees)

        // Calculate new coordinates
        let lat = centerLat + (distance * sin(angle))
        let lon = centerLon + (distance * cos(angle))

        return (lat, lon)
    }

    private static func determineLiftingLevel(weight: Double) -> LiftingLevel {
        switch weight {
        case 0..<100: return .wind
        case 100..<150: return .lap
        case 150..<220: return .lap
        case 220..<300: return .chest
        default: return .overhead
        }
    }
}

#endif
