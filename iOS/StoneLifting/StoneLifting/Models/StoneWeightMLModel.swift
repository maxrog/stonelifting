//
//  StoneWeightMLModel.swift
//  StoneLifting
//
//  Created by Max Rogers on 11/15/25.
//

// MARK: - ML Model Roadmap
//
// CURRENT STATUS: Infrastructure in place, predictions DISABLED
//
// This ML model infrastructure is ready but not currently in use.
// Enable by setting `useMLPredictions = true` in CameraWeightViewModel.swift
//
// To activate:
// 1. Collect real training data from users (actual weights vs estimates)
// 2. Export training data: StoneWeightMLModel.shared.exportTrainingData()
// 3. Train CoreML model with Create ML or Python
// 4. Add the .mlmodel file to the app bundle
// 5. Enable predictions with the feature flag
// 6. Consider re-adding Apple Intelligence branding if model performs well
//
// Benefits when implemented:
// - Learn from user corrections over time
// - Improve accuracy beyond geometric calculations
// - Personalization based on user patterns
// - Could justify premium branding 

import Foundation
import CoreML
import Vision
import UIKit

// MARK: - Stone Weight ML Model Manager

/// Manages CoreML model for stone weight prediction with on-device training capability
final class StoneWeightMLModel {
    // MARK: - Properties

    static let shared = StoneWeightMLModel()
    private let logger = AppLogger()

    // Model configuration
    private let modelName = "StoneWeightEstimator"
    private var model: MLModel?
    private var isModelLoaded = false

    // Training data storage
    private let trainingDataKey = "stone_weight_training_data"
    private var trainingDataset: [TrainingExample] = []

    // MARK: - Training Data Structure

    struct TrainingExample: Codable {
        let features: StoneFeatures
        let actualWeight: Double
        let timestamp: Date
        let userId: String?

        struct StoneFeatures: Codable {
            // Visual features
            let boundingBoxArea: Double
            let aspectRatio: Double
            let estimatedVolume: Double
            let imageQuality: Double

            // Color/texture features
            let averageBrightness: Double
            let colorVariance: Double
            let textureComplexity: Double

            // Dimensional features
            let estimatedLength: Double
            let estimatedWidth: Double
            let estimatedHeight: Double

            // Context features
            let distanceToCamera: Double
            let lightingCondition: Double
        }
    }

    // MARK: - Initialization

    private init() {
        loadModel()
        loadTrainingData()
    }

    // MARK: - Model Loading

    /// Load the CoreML model (or create baseline if doesn't exist)
    private func loadModel() {
        // Try to load custom trained model
        if let modelURL = getModelURL(),
           FileManager.default.fileExists(atPath: modelURL.path) {
            do {
                let compiledURL = try MLModel.compileModel(at: modelURL)
                model = try MLModel(contentsOf: compiledURL)
                isModelLoaded = true
                logger.info("Loaded trained CoreML model")
                return
            } catch {
                logger.error("Failed to load trained model", error: error)
            }
        }

        // Use baseline model (Vision-based estimates)
        logger.info("Using baseline Vision-based model")
        isModelLoaded = false
    }

    /// Get URL for storing custom model
    private func getModelURL() -> URL? {
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return documentsURL.appendingPathComponent("\(modelName).mlmodel")
    }

    // MARK: - Prediction

    /// Predict stone weight using ML model
    /// - Parameters:
    ///   - image: Stone image
    ///   - boundingBox: Detected bounding box
    ///   - dimensions: Estimated dimensions
    /// - Returns: Predicted weight and confidence
    func predictWeight(
        image: CGImage,
        boundingBox: CGRect,
        dimensions: CameraWeightViewModel.StoneDimensions
    ) async -> (weight: Double, confidence: Double)? {
        // Extract features from image
        guard let features = await extractFeatures(
            from: image,
            boundingBox: boundingBox,
            dimensions: dimensions
        ) else {
            return nil
        }

        // Use ML model if available, otherwise use baseline calculation
        if isModelLoaded, let model = model {
            return await predictWithMLModel(model: model, features: features)
        } else {
            return predictWithBaseline(features: features)
        }
    }

    /// Extract features from stone image for ML prediction
    func extractFeatures(
        from cgImage: CGImage,
        boundingBox: CGRect,
        dimensions: CameraWeightViewModel.StoneDimensions
    ) async -> TrainingExample.StoneFeatures? {
        // Calculate visual features
        let area = boundingBox.width * boundingBox.height
        let aspectRatio = boundingBox.width / max(boundingBox.height, 0.001)

        // Extract color and texture features
        let (brightness, variance) = await analyzeImageColors(cgImage, in: boundingBox)
        let textureComplexity = await analyzeTexture(cgImage, in: boundingBox)

        // Calculate distance estimate based on bounding box size
        let distanceToCamera = estimateDistance(from: boundingBox, imageSize: CGSize(width: cgImage.width, height: cgImage.height))

        // Estimate lighting conditions
        let lightingCondition = brightness / 255.0

        // Image quality score (sharpness/focus)
        let imageQuality = await estimateImageQuality(cgImage)

        return TrainingExample.StoneFeatures(
            boundingBoxArea: area,
            aspectRatio: aspectRatio,
            estimatedVolume: dimensions.volume,
            imageQuality: imageQuality,
            averageBrightness: brightness,
            colorVariance: variance,
            textureComplexity: textureComplexity,
            estimatedLength: dimensions.length,
            estimatedWidth: dimensions.width,
            estimatedHeight: dimensions.height,
            distanceToCamera: distanceToCamera,
            lightingCondition: lightingCondition
        )
    }

    /// Predict weight using CoreML model
    private func predictWithMLModel(
        model: MLModel,
        features: TrainingExample.StoneFeatures
    ) async -> (weight: Double, confidence: Double)? {
        // Create MLFeatureProvider from features
        // Note: TODO This would need to match your actual CoreML model's input schema
        do {
            let prediction = try await model.prediction(from: createFeatureProvider(features))

            if let weightValue = prediction.featureValue(for: "weight")?.doubleValue,
               let confidenceValue = prediction.featureValue(for: "confidence")?.doubleValue {
                return (weight: weightValue, confidence: confidenceValue)
            }
        } catch {
            logger.error("ML prediction failed", error: error)
        }

        return nil
    }

    /// Baseline prediction using simple calculations
    private func predictWithBaseline(features: TrainingExample.StoneFeatures) -> (weight: Double, confidence: Double) {
        // Use volume-based calculation with density
        let volumeCubicFeet = features.estimatedVolume / 1728.0
        let rockDensity = 165.0 // lbs per cubic foot // TODO this will change based on stone type
        let baseWeight = volumeCubicFeet * rockDensity

        // Adjust based on texture complexity (rough stones may be denser)
        let textureAdjustment = 1.0 + (features.textureComplexity - 0.5) * 0.2

        let weight = baseWeight * textureAdjustment

        // Calculate confidence based on multiple factors
        var confidence = features.imageQuality * 0.4
        confidence += (features.lightingCondition > 0.3 && features.lightingCondition < 0.8) ? 0.2 : 0.1
        confidence += (features.aspectRatio > 0.5 && features.aspectRatio < 2.5) ? 0.2 : 0.1
        confidence += (features.distanceToCamera > 1.5 && features.distanceToCamera < 4.0) ? 0.2 : 0.1

        return (weight: weight, confidence: min(1.0, confidence))
    }

    // MARK: - Training Data Management

    /// Add a training example when user confirms actual weight
    /// - Parameters:
    ///   - features: Extracted features from the image
    ///   - actualWeight: User-confirmed actual weight
    ///   - userId: Optional user ID for personalization
    func addTrainingExample(
        features: TrainingExample.StoneFeatures,
        actualWeight: Double,
        userId: String? = nil
    ) {
        let example = TrainingExample(
            features: features,
            actualWeight: actualWeight,
            timestamp: Date(),
            userId: userId
        )

        trainingDataset.append(example)
        saveTrainingData()

        logger.info("Added training example: predicted volume=\(features.estimatedVolume), actual weight=\(actualWeight)")

        // Check if we should trigger retraining
        if trainingDataset.count % 50 == 0 {
            logger.info("Reached \(trainingDataset.count) training examples - consider retraining model")
            // Could trigger background model update here
        }
    }

    /// Save training data to disk
    private func saveTrainingData() {
        guard let data = try? JSONEncoder().encode(trainingDataset) else {
            logger.error("Failed to encode training data")
            return
        }

        UserDefaults.standard.set(data, forKey: trainingDataKey)
        logger.info("Saved \(trainingDataset.count) training examples")
    }

    /// Load training data from disk
    private func loadTrainingData() {
        guard let data = UserDefaults.standard.data(forKey: trainingDataKey),
              let examples = try? JSONDecoder().decode([TrainingExample].self, from: data) else {
            logger.info("No training data found")
            return
        }

        trainingDataset = examples
        logger.info("Loaded \(trainingDataset.count) training examples")
    }

    /// Export training data for model retraining
    /// - Returns: Array of training examples
    func exportTrainingData() -> [TrainingExample] {
        return trainingDataset
    }

    /// Get training dataset statistics
    func getTrainingStats() -> TrainingStats {
        guard !trainingDataset.isEmpty else {
            return TrainingStats(totalExamples: 0, dateRange: nil, averageWeight: 0, weightRange: (0, 0))
        }

        let weights = trainingDataset.map { $0.actualWeight }
        let dates = trainingDataset.map { $0.timestamp }

        return TrainingStats(
            totalExamples: trainingDataset.count,
            dateRange: (dates.min() ?? Date(), dates.max() ?? Date()),
            averageWeight: weights.reduce(0, +) / Double(weights.count),
            weightRange: (weights.min() ?? 0, weights.max() ?? 0)
        )
    }

    struct TrainingStats {
        let totalExamples: Int
        let dateRange: (start: Date, end: Date)?
        let averageWeight: Double
        let weightRange: (min: Double, max: Double)
    }

    // MARK: - Helper Methods

    /// Analyze image colors in bounding box
    private func analyzeImageColors(_ cgImage: CGImage, in boundingBox: CGRect) async -> (brightness: Double, variance: Double) {
        // Simplified color analysis
        // In production, you'd crop to bounding box and analyze pixel data
        return (brightness: 128.0, variance: 0.5)
    }

    /// Analyze texture complexity
    private func analyzeTexture(_ cgImage: CGImage, in boundingBox: CGRect) async -> Double {
        // Simplified texture analysis
        // Could use Vision's VNDetectTextureRequest or edge detection
        return 0.5
    }

    /// Estimate distance to camera based on bounding box size
    private func estimateDistance(from boundingBox: CGRect, imageSize: CGSize) -> Double {
        let normalizedArea = (boundingBox.width * imageSize.width * boundingBox.height * imageSize.height) / (imageSize.width * imageSize.height)

        // Rough estimation: larger box = closer
        // Typical stone at 2.5 feet fills ~30% of frame
        let baseDistance = 2.5
        let estimatedDistance = baseDistance * sqrt(0.3 / max(normalizedArea, 0.01))

        return max(0.5, min(10.0, estimatedDistance))
    }

    /// Estimate image quality (sharpness/focus)
    private func estimateImageQuality(_ cgImage: CGImage) async -> Double {
        // Simplified quality estimation
        // Could use Vision's VNDetectBlurRequest or edge analysis
        return 0.75
    }

    /// Create MLFeatureProvider from features
    private func createFeatureProvider(_ features: TrainingExample.StoneFeatures) throws -> MLFeatureProvider {
        // TODO This is a placeholder - actual implementation would depend on your CoreML model schema
        // You'd create an MLDictionaryFeatureProvider with all the features
        let featureDict: [String: Any] = [
            "boundingBoxArea": features.boundingBoxArea,
            "aspectRatio": features.aspectRatio,
            "estimatedVolume": features.estimatedVolume,
            "imageQuality": features.imageQuality,
            "averageBrightness": features.averageBrightness,
            "colorVariance": features.colorVariance,
            "textureComplexity": features.textureComplexity,
            "estimatedLength": features.estimatedLength,
            "estimatedWidth": features.estimatedWidth,
            "estimatedHeight": features.estimatedHeight,
            "distanceToCamera": features.distanceToCamera,
            "lightingCondition": features.lightingCondition
        ]

        return try MLDictionaryFeatureProvider(dictionary: featureDict)
    }
}
