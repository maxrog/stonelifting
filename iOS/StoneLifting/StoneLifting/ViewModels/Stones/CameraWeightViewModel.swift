//
//  CameraWeightViewModel.swift
//  StoneLifting
//
//  Created by Max Rogers on 11/15/25.
//

import Foundation
import Vision
import CoreML
import UIKit
import AVFoundation
import Observation

// MARK: - Camera Weight Estimation View Model

/// ViewModel for camera-based stone weight estimation with live camera
/// Uses Vision framework for object detection and geometric calculations
@Observable
final class CameraWeightViewModel {
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
    var feedbackMessage: String = "Position stone in frame"

    // Analysis history for smoothing
    private var recentEstimates: [Double] = []
    private let maxEstimateHistory = 5

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
        let boundingBox: CGRect
    }

    struct StoneDimensions {
        let length: Double // in inches
        let width: Double
        let height: Double
        let volume: Double // cubic inches
    }

    // MARK: - Public Methods

    /// Analyze a camera frame for stone weight estimation
    /// - Parameter sampleBuffer: Camera sample buffer
    /// - Returns: Analysis result with weight estimate
    func analyzeFrame(_ sampleBuffer: CMSampleBuffer) async -> WeightAnalysisResult? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            logger.debug("Failed to get pixel buffer from sample buffer")
            return nil
        }

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()

        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            logger.debug("Failed to create CGImage from pixel buffer")
            return nil
        }

        return await performRealtimeAnalysis(cgImage: cgImage)
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
        detectedBoundingBox = nil
        isStoneDetected = false
        recentEstimates.removeAll()
        feedbackMessage = "Position stone in frame"
    }

    /// Clear any error messages
    func clearError() {
        errorMessage = nil
    }

    // MARK: - Private Methods

    /// Perform real-time analysis on camera frame
    private func performRealtimeAnalysis(cgImage: CGImage) async -> WeightAnalysisResult? {
        // Detect stone and get bounding box
        guard let detection = await detectStoneInFrame(cgImage) else {
            await MainActor.run {
                isStoneDetected = false
                feedbackMessage = "Move closer to stone"
                detectedBoundingBox = nil
            }
            return nil
        }

        logger.debug("Stone detected with confidence: \(String(format: "%.2f", detection.confidence))")

        // Calculate dimensions from bounding box
        let dimensions = estimateDimensions(
            from: detection.boundingBox,
            imageSize: CGSize(width: cgImage.width, height: cgImage.height)
        )

        logger.debug("Estimated dimensions - L: \(String(format: "%.1f", dimensions.length))\" W: \(String(format: "%.1f", dimensions.width))\" H: \(String(format: "%.1f", dimensions.height))\" Vol: \(String(format: "%.1f", dimensions.volume)) in³")

        // ML model prediction (disabled until trained model is available)
        let prediction: (weight: Double, confidence: Double)? = useMLPredictions ? await mlModel.predictWeight(
            image: cgImage,
            boundingBox: detection.boundingBox,
            dimensions: dimensions
        ) : nil

        let weight = prediction?.weight ?? calculateWeightFromDimensions(dimensions)
        let mlConfidence = prediction?.confidence ?? calculateConfidence(for: dimensions, detectionConfidence: detection.confidence)

        if let prediction = prediction {
            logger.debug("ML model prediction: \(String(format: "%.1f", prediction.weight)) lbs (confidence: \(String(format: "%.2f", prediction.confidence)))")
        } else {
            logger.debug("Using geometric calculation: \(String(format: "%.1f", weight)) lbs")
        }

        // Store features for future training (infrastructure ready, not currently collecting)
        // TODO: Enable data collection when ready to train ML model
        if useMLPredictions {
            lastAnalysisImage = cgImage
            lastAnalysisFeatures = await StoneWeightMLModel.shared.extractFeatures(
                from: cgImage,
                boundingBox: detection.boundingBox,
                dimensions: dimensions
            )
        }

        // Add to history and smooth
        recentEstimates.append(weight)
        if recentEstimates.count > maxEstimateHistory {
            recentEstimates.removeFirst()
        }

        let smoothedWeight = recentEstimates.reduce(0, +) / Double(recentEstimates.count)
        let confidence = mlConfidence

        logger.debug("Smoothed weight: \(String(format: "%.1f", smoothedWeight)) lbs (\(recentEstimates.count) samples), Final confidence: \(String(format: "%.2f", confidence))")

        // Update UI state
        await MainActor.run {
            self.currentEstimate = smoothedWeight
            self.confidenceLevel = confidence
            self.detectedBoundingBox = detection.boundingBox
            self.isStoneDetected = true
            self.feedbackMessage = getFeedbackMessage(confidence: confidence, dimensions: dimensions)
        }

        return WeightAnalysisResult(
            estimatedWeight: smoothedWeight,
            confidence: confidence,
            dimensions: dimensions,
            boundingBox: detection.boundingBox
        )
    }

    /// Detect stone in camera frame
    private func detectStoneInFrame(_ cgImage: CGImage) async -> (boundingBox: CGRect, confidence: Float)? {
        return await withCheckedContinuation { continuation in
            let request = VNDetectRectanglesRequest { request, error in
                if let error = error {
                    self.logger.error("Vision request failed", error: error)
                    continuation.resume(returning: nil)
                    return
                }

                guard let observations = request.results as? [VNRectangleObservation],
                      let bestObservation = observations.first else {
                    self.logger.debug("No rectangles detected in frame")
                    continuation.resume(returning: nil)
                    return
                }

                // Filter for reasonable stone-like rectangles
                let aspectRatio = bestObservation.boundingBox.width / bestObservation.boundingBox.height
                let area = bestObservation.boundingBox.width * bestObservation.boundingBox.height

                // Stone should take up reasonable portion of frame
                guard area > 0.1, aspectRatio > 0.3, aspectRatio < 3.0 else {
                    self.logger.debug("Rectangle filtered out - area: \(String(format: "%.3f", area)), aspectRatio: \(String(format: "%.2f", aspectRatio))")
                    continuation.resume(returning: nil)
                    return
                }

                self.logger.debug("Rectangle accepted - area: \(String(format: "%.3f", area)), aspectRatio: \(String(format: "%.2f", aspectRatio))")
                continuation.resume(returning: (
                    boundingBox: bestObservation.boundingBox,
                    confidence: bestObservation.confidence
                ))
            }

            request.minimumConfidence = 0.5
            request.maximumObservations = 1
            request.minimumAspectRatio = 0.3
            request.maximumAspectRatio = 3.0
            request.minimumSize = 0.1

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            do {
                try handler.perform([request])
            } catch {
                self.logger.error("Failed to perform Vision request", error: error)
                continuation.resume(returning: nil)
            }
        }
    }

    /// Estimate physical dimensions from bounding box
    private func estimateDimensions(from boundingBox: CGRect, imageSize: CGSize) -> StoneDimensions {
        // Convert normalized coordinates to pixels
        let pixelWidth = boundingBox.width * imageSize.width
        let pixelHeight = boundingBox.height * imageSize.height

        // Estimate real-world size based on typical camera FOV
        // Assumption: Stone fills ~30-50% of frame at ideal distance (~2-3 feet)
        // Average phone camera has ~60° horizontal FOV
        // At 2.5 feet, frame captures ~36 inches width

        let frameWidthInches = 36.0
        let pixelsPerInch = imageSize.width / frameWidthInches

        let estimatedWidth = Double(pixelWidth) / pixelsPerInch
        let estimatedHeight = Double(pixelHeight) / pixelsPerInch

        // Estimate depth as average of width and height (rough approximation)
        let estimatedDepth = (estimatedWidth + estimatedHeight) / 2.3

        let volume = estimatedWidth * estimatedHeight * estimatedDepth

        return StoneDimensions(
            length: estimatedWidth,
            width: estimatedDepth,
            height: estimatedHeight,
            volume: volume
        )
    }

    /// Calculate weight from stone dimensions
    /// Uses the selected stone type's density for more accurate estimation
    private func calculateWeightFromDimensions(_ dimensions: StoneDimensions) -> Double {
        let volumeCubicFeet = dimensions.volume / 1728.0 // Convert cubic inches to cubic feet
        let rockDensity = stoneType.density // pounds per cubic foot

        let weight = volumeCubicFeet * rockDensity

        logger.debug("Weight calculation - Volume: \(String(format: "%.3f", volumeCubicFeet)) ft³ × Density: \(rockDensity) lbs/ft³ (\(stoneType.displayName)) = \(String(format: "%.1f", weight)) lbs")

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

    /// Calculate confidence based on detection quality
    private func calculateConfidence(for dimensions: StoneDimensions, detectionConfidence: Float) -> Double {
        var confidence = Double(detectionConfidence)
        var boosts: [String] = []

        logger.debug("Calculating confidence - Base: \(String(format: "%.2f", confidence))")

        // Boost confidence for reasonable dimensions
        let aspectRatio = dimensions.length / dimensions.height
        if aspectRatio >= 0.5 && aspectRatio <= 2.5 {
            confidence += 0.15
            boosts.append("aspect ratio (\(String(format: "%.2f", aspectRatio)))")
        }

        // Boost confidence for stones in good size range (not too small or large)
        if dimensions.volume > 100 && dimensions.volume < 5000 {
            confidence += 0.1
            boosts.append("volume range (\(String(format: "%.1f", dimensions.volume)) in³)")
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
    private func getFeedbackMessage(confidence: Double, dimensions: StoneDimensions) -> String {
        if confidence > 0.8 {
            return "Great! Tap to confirm"
        } else if confidence > 0.6 {
            return "Hold steady..."
        } else if dimensions.volume < 50 {
            return "Move closer"
        } else if dimensions.volume > 8000 {
            return "Move back slightly"
        } else {
            return "Center stone in frame"
        }
    }
}
