//
//  CameraWeightViewModel.swift
//  StoneLifting
//
//  Created by Max Rogers on 11/15/25.
//

// TODO resolve
// swiftlint:disable type_body_length

import Foundation
import CoreML
import UIKit
import AVFoundation
import Observation
import simd

// MARK: - Camera Weight Estimation View Model

/// ViewModel for camera-based stone weight estimation with live camera
/// Uses Vision framework for object detection and geometric calculations
@Observable
final class CameraWeightViewModel {
    // MARK: - Constants

    private enum FeedbackMessage {
        static let scanning = "Move camera around object to scan"
        static let surfaceLocked = "Surface locked - Tap first edge (LENGTH)"
        static let keepScanning = "Keep moving camera to scan surface..."
        static let tapOppositeLengthEdge = "Tap opposite edge (LENGTH)"
        static let tapOppositeWidthEdge = "Tap opposite edge (WIDTH)"
        static let tapOppositeHeightEdge = "Tap opposite edge (HEIGHT)"
        static let allDimensionsMeasured = "All dimensions measured - Hold steady"

        static func lengthMeasured(_ length: Double) -> String {
            "Length: \(String(format: "%.1f", length))\" - Now measure WIDTH"
        }

        static func widthMeasured(_ width: Double) -> String {
            "Width: \(String(format: "%.1f", width))\" - Now measure HEIGHT"
        }
    }

    // MARK: - Properties

    private let logger = AppLogger()
    private let mlModel = StoneWeightMLModel.shared
    private let stoneType: StoneType

    // ML Model Feature Flag
    // TODO: Enable when trained model is available - see StoneWeightMLModel.swift roadmap
    private let useMLPredictions = false

    // Exposed state
    var isAnalyzing = false
    var currentEstimate: Double?
    var confidenceLevel: Double = 0.0
    var errorMessage: String?
    var detectedBoundingBox: CGRect?
    var isStoneDetected = false
    var feedbackMessage: String = FeedbackMessage.scanning
    var currentDistance: Float? // Distance to target in meters

    // Edge measurement state - measuring 3 dimensions (length, width, height)
    // Dimension 1 (Length)
    private var dimension1Point1: simd_float3?
    private var dimension1Point2: simd_float3?
    var measuredLength: Double?  // Public for UI display

    // Dimension 2 (Width)
    private var dimension2Point1: simd_float3?
    private var dimension2Point2: simd_float3?
    var measuredWidth: Double?  // Public for UI display

    // Dimension 3 (Height)
    private var dimension3Point1: simd_float3?
    private var dimension3Point2: simd_float3?
    var measuredHeight: Double?  // Public for UI display

    var isMeasurementMode = true  // Start in measurement mode

    // Manual adjustment state
    var isEditingMeasurements = false  // Toggle for edit mode
    private var originalLength: Double?  // Store originals for reset
    private var originalWidth: Double?
    private var originalHeight: Double?

    // Track which dimension we're currently measuring (1, 2, or 3)
    private var currentDimension: Int {
        if dimension1Point2 == nil { return 1 }
        if dimension2Point2 == nil { return 2 }
        if dimension3Point2 == nil { return 3 }
        return 0
    }

    // Analysis history for smoothing
    private var recentEstimates: [Double] = []
    private let maxEstimateHistory = 10

    // Distance tracking for stability
    private var lastDistance: Float?
    private var stableEstimateCount: Int = 0
    private let minStableFrames = 5 // Need 5 stable frames before updating

    // Store last analysis for training
    private var lastAnalysisFeatures: StoneWeightMLModel.TrainingExample.StoneFeatures?
    private var lastAnalysisImage: CGImage?

    // MARK: - Initialization

    init(stoneType: StoneType = .granite) {
        self.stoneType = stoneType
        logger.info("Initialized with stone type: \(stoneType.displayName) (density: \(stoneType.density) lbs/ft³)")
    }

    // MARK: - Weight Analysis Result

    struct WeightAnalysisResult {
        let estimatedWeight: Double
        let confidence: Double
        let dimensions: StoneDimensions?
        let distance: Float  // Distance from camera in meters
        let hitPosition: simd_float3?  // 3D world position
    }

    struct StoneDimensions {
        let length: Double // in inches
        let width: Double
        let height: Double
        let volume: Double // cubic inches
    }

    // MARK: - Public Methods

    /// Analyze a camera frame for stone weight estimation using hit-test
    /// - Parameters:
    ///   - hitResult: ARKit raycast hit result from center of screen
    /// - Returns: Analysis result with weight estimate
    func analyzeFrame(hitResult: ARPlaneDetectionManager.HitTestResult?) async -> WeightAnalysisResult? {
        // Skip analysis if still in measurement mode (waiting for edge taps)
        guard !isMeasurementMode else {
            return nil
        }

        guard let hit = hitResult else {
            await MainActor.run {
                isStoneDetected = false
                feedbackMessage = "Point camera at stone"
                detectedBoundingBox = nil
                currentDistance = nil
            }
            return nil
        }

        // Need all 3 dimensions to calculate weight
        guard let length = measuredLength,
              let width = measuredWidth,
              let height = measuredHeight else {
            return nil
        }

        return await performRealtimeAnalysis(
            hitResult: hit,
            length: length,
            width: width,
            height: height
        )
    }

    func updateFeedback(_ message: String) {
        feedbackMessage = message
    }

    func surfaceReady() {
        if isMeasurementMode && dimension1Point1 == nil {
            feedbackMessage = FeedbackMessage.surfaceLocked
        }
    }

    func surfaceLost() {
        if isMeasurementMode && dimension1Point1 == nil {
            feedbackMessage = FeedbackMessage.scanning
        }
    }

    /// Round measurement to nearest half inch
    private func roundToNearestHalfInch(_ value: Double) -> Double {
        return round(value * 2.0) / 2.0
    }

    /// Handle a tap on the screen for edge measurement with 3D world position
    /// - Parameter worldPosition: 3D world position from RealityKit raycast
    /// Measures 3 dimensions sequentially: length, width, height
    func handleEdgeTap(worldPosition: simd_float3) {
        switch currentDimension {
        case 1:
            // Measuring dimension 1 (Length)
            if dimension1Point1 == nil {
                dimension1Point1 = worldPosition
                feedbackMessage = FeedbackMessage.tapOppositeLengthEdge
                logger.info("Dimension 1 (Length) - Point 1 marked at: \(worldPosition)")
            } else {
                dimension1Point2 = worldPosition
                let distance = simd_distance(dimension1Point1!, dimension1Point2!)
                let distanceInches = Double(distance) * 39.3701
                let roundedInches = roundToNearestHalfInch(distanceInches)
                measuredLength = roundedInches
                feedbackMessage = FeedbackMessage.lengthMeasured(roundedInches)
                logger.info("Dimension 1 (Length) - Point 2 marked. Distance: \(String(format: "%.1f", distanceInches))\" (rounded to \(String(format: "%.1f", roundedInches))\")")
            }

        case 2:
            // Measuring dimension 2 (Width)
            if dimension2Point1 == nil {
                dimension2Point1 = worldPosition
                feedbackMessage = FeedbackMessage.tapOppositeWidthEdge
                logger.info("Dimension 2 (Width) - Point 1 marked at: \(worldPosition)")
            } else {
                dimension2Point2 = worldPosition
                let distance = simd_distance(dimension2Point1!, dimension2Point2!)
                let distanceInches = Double(distance) * 39.3701
                let roundedInches = roundToNearestHalfInch(distanceInches)
                measuredWidth = roundedInches
                feedbackMessage = FeedbackMessage.widthMeasured(roundedInches)
                logger.info("Dimension 2 (Width) - Point 2 marked. Distance: \(String(format: "%.1f", distanceInches))\" (rounded to \(String(format: "%.1f", roundedInches))\")")
            }

        case 3:
            // Measuring dimension 3 (Height)
            if dimension3Point1 == nil {
                dimension3Point1 = worldPosition
                feedbackMessage = FeedbackMessage.tapOppositeHeightEdge
                logger.info("Dimension 3 (Height) - Point 1 marked at: \(worldPosition)")
            } else {
                dimension3Point2 = worldPosition
                let distance = simd_distance(dimension3Point1!, dimension3Point2!)
                let distanceInches = Double(distance) * 39.3701
                let roundedInches = roundToNearestHalfInch(distanceInches)
                measuredHeight = roundedInches
                isMeasurementMode = false

                // Save originals for manual adjustment feature
                saveOriginalMeasurements()

                feedbackMessage = FeedbackMessage.allDimensionsMeasured
                logger.info("""
Dimension 3 (Height) - Point 2 marked. Distance: \(String(format: "%.1f", distanceInches))\" (rounded to \(String(format: "%.1f", roundedInches))\")
All measurements complete:
  Length: \(String(format: "%.1f", measuredLength!))\"
  Width:  \(String(format: "%.1f", measuredWidth!))\"
  Height: \(String(format: "%.1f", roundedInches))\"
""")
            }

        default:
            logger.warning("handleEdgeTap called but all dimensions already measured")
        }
    }

    func undoLastTap() {
        // Undo in reverse order of how they were added
        if dimension3Point2 != nil {
            dimension3Point2 = nil
            measuredHeight = nil
            isMeasurementMode = true  // Re-enable measurement mode
            feedbackMessage = FeedbackMessage.tapOppositeHeightEdge
            logger.info("Undid dimension 3 point 2")
        } else if dimension3Point1 != nil {
            dimension3Point1 = nil
            isMeasurementMode = true
            feedbackMessage = FeedbackMessage.widthMeasured(measuredWidth!)
            logger.info("Undid dimension 3 point 1")
        } else if dimension2Point2 != nil {
            dimension2Point2 = nil
            measuredWidth = nil
            feedbackMessage = FeedbackMessage.tapOppositeWidthEdge
            logger.info("Undid dimension 2 point 2")
        } else if dimension2Point1 != nil {
            dimension2Point1 = nil
            feedbackMessage = FeedbackMessage.lengthMeasured(measuredLength!)
            logger.info("Undid dimension 2 point 1")
        } else if dimension1Point2 != nil {
            dimension1Point2 = nil
            measuredLength = nil
            feedbackMessage = FeedbackMessage.tapOppositeLengthEdge
            logger.info("Undid dimension 1 point 2")
        } else if dimension1Point1 != nil {
            dimension1Point1 = nil
            feedbackMessage = FeedbackMessage.surfaceLocked
            logger.info("Undid dimension 1 point 1")
        } else {
            logger.warning("No points to undo")
        }
    }

    /// Reset edge measurement to start over
    func resetMeasurement() {
        dimension1Point1 = nil
        dimension1Point2 = nil
        measuredLength = nil

        dimension2Point1 = nil
        dimension2Point2 = nil
        measuredWidth = nil

        dimension3Point1 = nil
        dimension3Point2 = nil
        measuredHeight = nil

        isMeasurementMode = true
        isEditingMeasurements = false
        originalLength = nil
        originalWidth = nil
        originalHeight = nil
        feedbackMessage = FeedbackMessage.scanning
        logger.info("Measurement reset")
    }

    // MARK: - Manual Adjustment Methods

    private func saveOriginalMeasurements() {
        if originalLength == nil, let length = measuredLength {
            originalLength = length
        }
        if originalWidth == nil, let width = measuredWidth {
            originalWidth = width
        }
        if originalHeight == nil, let height = measuredHeight {
            originalHeight = height
        }
    }

    /// Adjust a specific dimension and recalculate weight
    func adjustDimension(_ dimension: Dimension, newValue: Double) {
        let clampedValue = max(0.1, min(newValue, 100.0)) // Clamp between 0.1" and 100"

        switch dimension {
        case .length:
            measuredLength = clampedValue
        case .width:
            measuredWidth = clampedValue
        case .height:
            measuredHeight = clampedValue
        }

        logger.debug("Adjusted \(dimension): \(String(format: "%.1f", clampedValue))\"")
        // Weight will recalculate automatically in the next analysis frame
    }

    func incrementDimension(_ dimension: Dimension, by step: Double = 0.1) {
        let currentValue: Double
        switch dimension {
        case .length: currentValue = measuredLength ?? 0
        case .width: currentValue = measuredWidth ?? 0
        case .height: currentValue = measuredHeight ?? 0
        }
        adjustDimension(dimension, newValue: currentValue + step)
    }

    func decrementDimension(_ dimension: Dimension, by step: Double = 0.1) {
        let currentValue: Double
        switch dimension {
        case .length: currentValue = measuredLength ?? 0
        case .width: currentValue = measuredWidth ?? 0
        case .height: currentValue = measuredHeight ?? 0
        }
        adjustDimension(dimension, newValue: currentValue - step)
    }

    func resetToOriginalMeasurements() {
        if let original = originalLength {
            measuredLength = original
        }
        if let original = originalWidth {
            measuredWidth = original
        }
        if let original = originalHeight {
            measuredHeight = original
        }
        logger.info("Reset to original measurements")
    }

    var hasAdjustedMeasurements: Bool {
        if let original = originalLength, let current = measuredLength, abs(original - current) > 0.01 {
            return true
        }
        if let original = originalWidth, let current = measuredWidth, abs(original - current) > 0.01 {
            return true
        }
        if let original = originalHeight, let current = measuredHeight, abs(original - current) > 0.01 {
            return true
        }
        return false
    }

    enum Dimension {
        case length, width, height
    }

    /// Confirm and finalize the current weight estimate
    /// - Returns: Final estimated weight with confidence
    func confirmEstimate() -> (weight: Double, confidence: Double)? {
        guard let estimate = currentEstimate, confidenceLevel > 0.4 else {
            logger.debug("Cannot confirm estimate - estimate: \(currentEstimate ?? 0), confidence: \(confidenceLevel)")
            return nil
        }

        logger.info("Estimate confirmed: \(Int(estimate)) lbs with \(Int(confidenceLevel * 100))% confidence")
        return (weight: estimate, confidence: confidenceLevel)
    }

    /// Add training data when user confirms actual weight
    /// - Parameter actualWeight: The user-confirmed actual weight
    func addTrainingData(actualWeight: Double) {
        guard let features = lastAnalysisFeatures else {
            logger.warning("No features available for training")
            return
        }

        mlModel.addTrainingExample(
            features: features,
            actualWeight: actualWeight,
            userId: nil // Could add user ID for personalization
        )

        logger.info("Added training example: estimated=\(currentEstimate ?? 0), actual=\(actualWeight)")
    }

    /// Get training statistics
    func getTrainingStats() -> StoneWeightMLModel.TrainingStats {
        return mlModel.getTrainingStats()
    }

    /// Reset analysis state
    func reset() {
        logger.debug("Resetting analysis state")
        currentEstimate = nil
        confidenceLevel = 0.0
        currentDistance = nil
        detectedBoundingBox = nil
        isStoneDetected = false
        recentEstimates.removeAll()
        lastDistance = nil
        stableEstimateCount = 0

        dimension1Point1 = nil
        dimension1Point2 = nil
        measuredLength = nil
        dimension2Point1 = nil
        dimension2Point2 = nil
        measuredWidth = nil
        dimension3Point1 = nil
        dimension3Point2 = nil
        measuredHeight = nil
        isMeasurementMode = true
        feedbackMessage = FeedbackMessage.scanning
    }

    func clearError() {
        errorMessage = nil
    }

    // MARK: - Private Methods

    /// Perform real-time analysis using ARKit hit test results with measured dimensions
    /// - Parameters:
    ///   - hitResult: ARKit raycast result from center of screen
    ///   - length: Measured length in inches
    ///   - width: Measured width in inches
    ///   - height: Measured height in inches
    /// - Returns: Weight analysis result with estimate, confidence, dimensions, and distance
    /// - Note: Uses actual measured dimensions for accurate weight calculation
    // swiftlint:disable:next function_body_length // TODO
    private func performRealtimeAnalysis(
        hitResult: ARPlaneDetectionManager.HitTestResult,
        length: Double,
        width: Double,
        height: Double
    ) async -> WeightAnalysisResult? {
        let distance = hitResult.distance

        logger.debug("Hit test at distance: \(String(format: "%.2f", distance))m (\(String(format: "%.1f", distance * 3.28084)) feet)")

        // Use actual measured dimensions
        let volume = length * width * height
        let dimensions = StoneDimensions(
            length: length,
            width: width,
            height: height,
            volume: volume
        )

        logger.debug("""
Measured dimensions - L: \(String(format: "%.1f", dimensions.length))\"
W: \(String(format: "%.1f", dimensions.width))\"
H: \(String(format: "%.1f", dimensions.height))\"
Vol: \(String(format: "%.1f", dimensions.volume)) in³
""")

        // Calculate weight from dimensions
        let weight = calculateWeightFromDimensions(dimensions)
        let confidence = calculateConfidenceFromDistance(distance: distance, dimensions: dimensions)

        logger.debug("Using geometric calculation: \(String(format: "%.1f", weight)) lbs (confidence: \(String(format: "%.2f", confidence)))")

        // Check if distance is stable (within 20cm of last measurement)
        // Looser threshold to account for natural hand movement and ARKit variance
        let isDistanceStable: Bool
        if let last = lastDistance {
            let distanceChange = abs(distance - last)
            isDistanceStable = distanceChange < 0.2 // Within 20cm (~8 inches)
            lastDistance = distance

            if !isDistanceStable {
                logger.debug("Distance unstable: changed by \(String(format: "%.2f", distanceChange * 100))cm")
            }
        } else {
            isDistanceStable = true
            lastDistance = distance
        }

        // Only update if distance is stable
        if isDistanceStable {
            stableEstimateCount += 1

            // Add to history and smooth
            recentEstimates.append(weight)
            if recentEstimates.count > maxEstimateHistory {
                recentEstimates.removeFirst()
            }

            // Only update UI after enough stable frames
            if stableEstimateCount >= minStableFrames {
                let smoothedWeight = recentEstimates.reduce(0, +) / Double(recentEstimates.count)

                logger.debug("""
Smoothed weight: \(String(format: "%.1f", smoothedWeight)) lbs (\(recentEstimates.count) samples), \
Final confidence: \(String(format: "%.2f", confidence))
""")

                // Update UI state
                await MainActor.run {
                    self.currentEstimate = smoothedWeight
                    self.confidenceLevel = confidence
                    self.currentDistance = distance
                    self.detectedBoundingBox = CGRect(x: 0.45, y: 0.45, width: 0.1, height: 0.1) // Center reticle area
                    self.isStoneDetected = true
                    self.feedbackMessage = getFeedbackMessage(confidence: confidence, distance: distance)
                }

                return WeightAnalysisResult(
                    estimatedWeight: smoothedWeight,
                    confidence: confidence,
                    dimensions: dimensions,
                    distance: distance,
                    hitPosition: hitResult.worldPosition
                )
            } else {
                logger.debug("Stabilizing... (\(stableEstimateCount)/\(minStableFrames) stable frames)")
                await MainActor.run {
                    self.currentDistance = distance
                    self.feedbackMessage = "Hold steady... (\(String(format: "%.1f", distance * 3.28084)) ft)"
                    self.detectedBoundingBox = CGRect(x: 0.45, y: 0.45, width: 0.1, height: 0.1)
                    self.isStoneDetected = true
                }
                return nil
            }
        } else {
            // Distance changed - reset stability counter
            logger.debug("Distance changed, resetting stability counter")
            stableEstimateCount = 0
            recentEstimates.removeAll()
            await MainActor.run {
                self.feedbackMessage = "Hold camera steady"
                self.currentEstimate = nil
            }
            return nil
        }
    }

    /// Calculate weight from stone dimensions
    /// Uses the selected stone type's density for more accurate estimation
    private func calculateWeightFromDimensions(_ dimensions: StoneDimensions) -> Double {
        let volumeCubicFeet = dimensions.volume / 1728.0 // Convert cubic inches to cubic feet
        let rockDensity = stoneType.density // pounds per cubic foot

        let weight = volumeCubicFeet * rockDensity

        logger.debug("""
Weight calculation - Volume: \(String(format: "%.3f", volumeCubicFeet)) ft³ × \
Density: \(rockDensity) lbs/ft³ (\(stoneType.displayName)) = \(String(format: "%.1f", weight)) lbs
""")

        // Round to nearest 5 lbs for stones over 20 lbs
        let roundedWeight: Double
        if weight > 20 {
            roundedWeight = round(weight / 5.0) * 5.0
        } else {
            roundedWeight = round(weight)
        }

        if roundedWeight != weight {
            logger.debug("Rounded weight from \(String(format: "%.1f", weight)) to \(String(format: "%.1f", roundedWeight)) lbs")
        }

        return roundedWeight
    }

    /// Calculate confidence based on measurement quality
    private func calculateConfidenceFromDistance(distance: Float, dimensions: StoneDimensions) -> Double {
        var confidence = 0.7 // Base confidence for actual measured dimensions (higher than estimated)
        var boosts: [String] = []

        logger.debug("Calculating confidence - Base: \(String(format: "%.2f", confidence)) (measured dimensions)")

        // Boost confidence for optimal distance (0.3m - 1.5m / 1-5 feet)
        if distance >= 0.3 && distance <= 1.5 {
            confidence += 0.3
            boosts.append("optimal distance (\(String(format: "%.2f", distance))m)")
        } else if distance < 0.3 {
            confidence += 0.1
            boosts.append("close distance (\(String(format: "%.2f", distance))m)")
        }

        // Boost confidence for reasonable dimensions
        let aspectRatio = dimensions.length / dimensions.height
        if aspectRatio >= 0.5 && aspectRatio <= 2.5 {
            confidence += 0.1
            boosts.append("good proportions")
        }

        // Boost confidence for stones in good size range (not too small or large)
        if dimensions.volume > 100 && dimensions.volume < 5000 {
            confidence += 0.1
            boosts.append("reasonable volume")
        }

        let finalConfidence = min(1.0, confidence)

        if !boosts.isEmpty {
            logger.debug("Confidence boosts applied: \(boosts.joined(separator: ", ")) → Final: \(String(format: "%.2f", finalConfidence))")
        } else {
            logger.debug("No confidence boosts applied → Final: \(String(format: "%.2f", finalConfidence))")
        }

        return finalConfidence
    }

    /// Generate helpful feedback message based on analysis state
    private func getFeedbackMessage(confidence: Double, distance: Float) -> String {
        let distanceFeet = distance * 3.28084

        if confidence > 0.8 {
            return "Excellent! Hold steady"
        } else if confidence > 0.6 {
            return "Good positioning (\(String(format: "%.1f", distanceFeet)) ft)"
        } else if distance < 0.3 {
            return "Move back - too close"
        } else if distance > 2.0 {
            return "Move closer (\(String(format: "%.1f", distanceFeet)) ft)"
        } else {
            return "Point at center of stone"
        }
    }
}
