//
//  ARPlaneDetectionManager.swift
//  StoneAtlas
//
//  Created by Max Rogers on 11/15/25.
//  Extracted from CameraWeightView.swift
//

import Foundation
import ARKit
import RealityKit
import CoreMedia

// MARK: - AR Plane Detection Manager

/// Manages ARKit session for plane detection and distance calculation with RealityKit
@Observable
final class ARPlaneDetectionManager: NSObject, ARSessionDelegate {
    let session = ARSession()
    private let logger = AppLogger()
    private var detectedPlanes: [ARPlaneAnchor] = []

    // RealityKit ARView reference
    var arView: ARView?

    var isPlaneDetected = false
    var planeDetectionStatus: String = "Scanning for surface..."
    var planeDetectionStartTime: Date?

    // Store tap anchors and lines for measurement
    var tapAnchors: [AnchorEntity] = []
    var measurementLines: [AnchorEntity] = []  // Store line entities connecting points

    /// Check if plane detection has stabilized (at least 2 seconds of detection)
    var hasStableDetection: Bool {
        guard let startTime = planeDetectionStartTime else { return false }
        return Date().timeIntervalSince(startTime) >= 2.0
    }

    override init() {
        super.init()
        session.delegate = self
    }

    func startSession() {
        guard ARWorldTrackingConfiguration.isSupported else {
            logger.error("ARWorldTracking not supported on this device")
            return
        }

        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.isAutoFocusEnabled = true

        // Use scene reconstruction with LiDAR if available
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) {
            configuration.sceneReconstruction = .meshWithClassification
            logger.info("LiDAR available - using mesh reconstruction for accurate measurements")
        } else if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            configuration.sceneReconstruction = .mesh
            logger.info("Using mesh reconstruction (no classification)")
        } else {
            logger.info("No LiDAR - using plane detection only")
        }

        // Use scene depth if available
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            configuration.frameSemantics.insert(.sceneDepth)
            logger.info("Scene depth available")
        }

        logger.info("Starting ARKit session with RealityKit")
        session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        logger.error("AR session failed", error: error)
    }

    func sessionWasInterrupted(_ session: ARSession) {
        logger.warning("AR session was interrupted")
    }

    func sessionInterruptionEnded(_ session: ARSession) {
        logger.info("AR session interruption ended")
        // Restart session
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }

    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        let state = camera.trackingState
        switch state {
        case .normal:
            logger.debug("AR Tracking: Normal")
        case .notAvailable:
            logger.warning("AR Tracking: Not Available")
        case .limited(let reason):
            let reasonStr: String
            switch reason {
            case .initializing:
                reasonStr = "Initializing"
            case .excessiveMotion:
                reasonStr = "Excessive Motion - Move slower"
            case .insufficientFeatures:
                reasonStr = "Insufficient Features - Need more texture/light"
            case .relocalizing:
                reasonStr = "Relocalizing"
            @unknown default:
                reasonStr = "Unknown"
            }
            logger.warning("AR Tracking Limited: \(reasonStr)")
        }
    }

    // MARK: - 3D Tap Markers (RealityKit Anchors)

    /// Add a 3D sphere marker at the given world position
    func addSphereMarker(at worldTransform: simd_float4x4, color: UIColor, radius: Float = 0.01) {
        guard let arView = arView else {
            logger.warning("ARView not available for adding markers")
            return
        }

        let anchor = AnchorEntity(world: worldTransform)
        let sphereMesh = MeshResource.generateSphere(radius: radius)
        let material = SimpleMaterial(color: color, isMetallic: false)
        let sphereEntity = ModelEntity(mesh: sphereMesh, materials: [material])

        // Move sphere up by half its diameter so it sits on the surface
        sphereEntity.position.y = radius

        anchor.addChild(sphereEntity)
        arView.scene.addAnchor(anchor)
        tapAnchors.append(anchor)

        logger.debug("Added sphere marker at world position")
    }

    /// Draw a 3D line between two points
    func drawLine(from start: simd_float3, to end: simd_float3, color: UIColor = .yellow) {
        guard let arView = arView else {
            logger.warning("ARView not available for drawing line")
            return
        }

        let anchor = AnchorEntity()

        // Calculate line direction and length
        let direction = end - start
        let length = simd_length(direction)

        // Create a thin cylinder to represent the line
        let lineMesh = MeshResource.generateBox(width: 0.005, height: length, depth: 0.005)
        let material = SimpleMaterial(color: color, isMetallic: false)
        let lineEntity = ModelEntity(mesh: lineMesh, materials: [material])

        // Position the line at the midpoint
        let midpoint = (start + end) / 2.0
        anchor.position = midpoint

        // Rotate the line to point from start to end
        // Calculate the rotation needed to align the Y-axis (default cylinder direction) with our direction vector
        let up = simd_float3(0, 1, 0)
        let normalizedDirection = simd_normalize(direction)

        // Create rotation from up vector to direction vector
        let rotationAxis = simd_cross(up, normalizedDirection)
        let rotationAngle = acos(simd_dot(up, normalizedDirection))

        if simd_length(rotationAxis) > 0.001 {
            let normalizedAxis = simd_normalize(rotationAxis)
            lineEntity.orientation = simd_quatf(angle: rotationAngle, axis: normalizedAxis)
        }

        anchor.addChild(lineEntity)
        arView.scene.addAnchor(anchor)
        measurementLines.append(anchor)

        logger.debug("Drew measurement line: \(String(format: "%.2f", length * 39.3701))\" (\(String(format: "%.2f", length))m)")
    }

    /// Remove the last tap marker and associated line
    func undoLastTap() -> Bool {
        guard let arView = arView else { return false }

        // Check if we need to remove a line (only if we're undoing the 2nd point of a pair)
        let shouldRemoveLine = tapAnchors.count % 2 == 0

        // Remove last marker
        guard let lastAnchor = tapAnchors.popLast() else {
            logger.debug("No markers to undo")
            return false
        }
        arView.scene.removeAnchor(lastAnchor)

        // Remove last line only if we just completed a pair
        if shouldRemoveLine, let lastLine = measurementLines.popLast() {
            arView.scene.removeAnchor(lastLine)
            logger.debug("Removed last measurement line")
        }

        logger.debug("Undid last tap - \(tapAnchors.count) markers remaining")
        return true
    }

    func clearTapMarkers() {
        guard let arView = arView else { return }

        for anchor in tapAnchors {
            arView.scene.removeAnchor(anchor)
        }
        tapAnchors.removeAll()

        for line in measurementLines {
            arView.scene.removeAnchor(line)
        }
        measurementLines.removeAll()

        logger.debug("Cleared all tap markers and lines")
    }

    /// Perform raycast from screen tap location and return hit result
    func performTapRaycast(at screenPoint: CGPoint) -> ARRaycastResult? {
        guard let arView = arView else {
            logger.warning("ARView not available for raycast")
            return nil
        }

        guard let frame = session.currentFrame else {
            logger.debug("No AR frame available for raycast")
            return nil
        }

        let cameraPosition = simd_make_float3(frame.camera.transform.columns.3)

        // Try raycasting against estimated planes first (more reliable)
        let results = arView.raycast(from: screenPoint, allowing: .estimatedPlane, alignment: .any)
        if let result = results.first {
            let hitPosition = simd_make_float3(result.worldTransform.columns.3)
            let distance = simd_distance(cameraPosition, hitPosition)
            logger.debug("Tap raycast hit estimated plane at \(String(format: "%.2f", distance))m")
            return result
        }

        // Fallback to existing plane geometry
        let existingResults = arView.raycast(from: screenPoint, allowing: .existingPlaneGeometry, alignment: .any)
        if let result = existingResults.first {
            let hitPosition = simd_make_float3(result.worldTransform.columns.3)
            let distance = simd_distance(cameraPosition, hitPosition)
            logger.debug("Tap raycast hit existing plane at \(String(format: "%.2f", distance))m")
            return result
        }

        // For non-LiDAR devices, try infinite planes (extrapolates detected planes)
        let infiniteResults = arView.raycast(from: screenPoint, allowing: .existingPlaneInfinite, alignment: .any)
        if let result = infiniteResults.first {
            let hitPosition = simd_make_float3(result.worldTransform.columns.3)
            let distance = simd_distance(cameraPosition, hitPosition)
            logger.debug("Tap raycast hit infinite plane at \(String(format: "%.2f", distance))m")
            return result
        }

        logger.debug("Tap raycast hit nothing at \(screenPoint)")
        return nil
    }

    func stopSession() {
        logger.info("Stopping ARKit plane detection session")
        session.pause()

        detectedPlanes.removeAll()
        isPlaneDetected = false
        planeDetectionStartTime = nil
        planeDetectionStatus = "Scanning for surface..."

        clearTapMarkers()
    }

    /// Get current AR frame
    func getCurrentFrame() async -> ARFrame? {
        return session.currentFrame
    }

    /// Convert AR frame to CMSampleBuffer for Vision processing
    func convertFrameToSampleBuffer(_ frame: ARFrame) async -> CMSampleBuffer? {
        let pixelBuffer = frame.capturedImage

        var sampleBuffer: CMSampleBuffer?
        var formatDescription: CMFormatDescription?

        let status = CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescriptionOut: &formatDescription
        )

        guard status == noErr, let formatDesc = formatDescription else {
            logger.debug("Failed to create format description")
            return nil
        }

        var timingInfo = CMSampleTimingInfo()
        timingInfo.presentationTimeStamp = CMTime(seconds: frame.timestamp, preferredTimescale: 1000000000)
        timingInfo.duration = CMTime.invalid
        timingInfo.decodeTimeStamp = CMTime.invalid

        // Create sample buffer
        let createStatus = CMSampleBufferCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: formatDesc,
            sampleTiming: &timingInfo,
            sampleBufferOut: &sampleBuffer
        )

        guard createStatus == noErr else {
            logger.debug("Failed to create sample buffer")
            return nil
        }

        return sampleBuffer
    }

    /// Get distance to the nearest detected plane in meters
    /// Calculates the perpendicular distance from camera to the plane surface
    func getDistanceToNearestPlane() async -> Float? {
        guard let frame = session.currentFrame else {
            return nil
        }

        let cameraTransform = frame.camera.transform
        let cameraPosition = simd_make_float3(cameraTransform.columns.3)

        // Find closest plane by calculating perpendicular distance to plane surface
        var closestDistance: Float?

        for plane in detectedPlanes {
            // Get plane's normal vector (perpendicular to plane surface)
            let planeTransform = plane.transform
            let planeNormal = simd_make_float3(planeTransform.columns.1) // Y-axis is normal for horizontal planes
            let planePosition = simd_make_float3(planeTransform.columns.3)

            // Calculate perpendicular distance from camera to plane
            // Distance = dot product of (camera - planePoint) with plane normal
            let vectorToCamera = cameraPosition - planePosition
            let perpendicularDistance = abs(simd_dot(vectorToCamera, simd_normalize(planeNormal)))

            if let current = closestDistance {
                closestDistance = min(current, perpendicularDistance)
            } else {
                closestDistance = perpendicularDistance
            }
        }

        if let distance = closestDistance {
            logger.debug("Nearest plane perpendicular distance: \(String(format: "%.2f", distance))m")
        }

        return closestDistance
    }

    /// Result from a raycast hit test
    struct HitTestResult {
        let worldPosition: simd_float3  // 3D position in world space
        let distance: Float             // Distance from camera in meters
        let normal: simd_float3?        // Surface normal (if hit a plane)
        let anchor: ARAnchor?           // Associated anchor (if any)
    }

    /// Perform a raycast from the center of the screen to detect objects/surfaces
    /// - Returns: Hit test result with distance and position, or nil if nothing hit
    func performCenterRaycast() async -> HitTestResult? {
        guard let frame = session.currentFrame else {
            logger.debug("No AR frame available for raycast")
            return nil
        }

        // Center of camera view in image coordinates
        let imageResolution = frame.camera.imageResolution
        let centerPoint = CGPoint(
            x: 0.5 * imageResolution.width,
            y: 0.5 * imageResolution.height
        )

        return await performRaycastAtImagePoint(centerPoint, frame: frame)
    }

    /// Perform a raycast at a specific image point
    /// - Parameters:
    ///   - point: Point in camera image coordinates
    ///   - frame: Current AR frame
    /// - Returns: Hit test result or nil if no hit
    private func performRaycastAtImagePoint(_ point: CGPoint, frame: ARFrame) async -> HitTestResult? {
        // Create raycast query from point
        // Use .existingPlaneInfinite to be more permissive - allows hitting detected planes
        let query = frame.raycastQuery(
            from: point,
            allowing: .existingPlaneInfinite,
            alignment: .any
        )

        // Perform raycast
        let results = session.raycast(query)

        // If no hit on existing planes, try estimated planes as fallback
        if results.isEmpty {
            let estimatedQuery = frame.raycastQuery(
                from: point,
                allowing: .estimatedPlane,
                alignment: .any
            )
            let estimatedResults = session.raycast(estimatedQuery)
            guard let firstResult = estimatedResults.first else {
                logger.debug("Raycast hit nothing (tried both existing and estimated planes)")
                return nil
            }
            return processRaycastResult(firstResult, frame: frame)
        }

        // Process the first successful result
        return processRaycastResult(results.first!, frame: frame)
    }

    /// Process a raycast result into a HitTestResult
    private func processRaycastResult(_ result: ARRaycastResult, frame: ARFrame) -> HitTestResult {
        // Extract world position from the hit result
        let worldTransform = result.worldTransform
        let worldPosition = simd_make_float3(worldTransform.columns.3)

        // Calculate distance from camera to hit point
        let cameraTransform = frame.camera.transform
        let cameraPosition = simd_make_float3(cameraTransform.columns.3)
        let distance = simd_distance(cameraPosition, worldPosition)

        // Get surface normal if available
        let normal: simd_float3?
        if let anchor = result.anchor as? ARPlaneAnchor {
            let planeTransform = anchor.transform
            normal = simd_make_float3(planeTransform.columns.1)  // Y-axis is normal
        } else {
            // Estimate normal from hit transform
            normal = simd_make_float3(worldTransform.columns.1)
        }

        logger.debug("Raycast hit at distance: \(String(format: "%.2f", distance))m (\(String(format: "%.1f", distance * 3.28084)) feet)")

        return HitTestResult(
            worldPosition: worldPosition,
            distance: distance,
            normal: normal,
            anchor: result.anchor
        )
    }

    // MARK: - ARSessionDelegate

    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        for anchor in anchors {
            if let planeAnchor = anchor as? ARPlaneAnchor {
                detectedPlanes.append(planeAnchor)

                if !isPlaneDetected {
                    planeDetectionStartTime = Date()
                }

                isPlaneDetected = true

                let planeType = planeAnchor.alignment == .horizontal ? "horizontal" : "vertical"
                let extent = planeAnchor.planeExtent
                logger.info("Detected \(planeType) plane - Size: \(String(format: "%.2f", extent.width))m × \(String(format: "%.2f", extent.height))m - ID: \(planeAnchor.identifier)")

                updatePlaneDetectionStatus()
            }
        }
    }

    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        for anchor in anchors {
            if let planeAnchor = anchor as? ARPlaneAnchor,
               let index = detectedPlanes.firstIndex(where: { $0.identifier == planeAnchor.identifier }) {
                detectedPlanes[index] = planeAnchor
                // Update status as planes are refined
                updatePlaneDetectionStatus()
            }
        }
    }

    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        for anchor in anchors {
            if let planeAnchor = anchor as? ARPlaneAnchor {
                detectedPlanes.removeAll { $0.identifier == planeAnchor.identifier }
                logger.warning("Removed plane - ID: \(planeAnchor.identifier) - Remaining planes: \(detectedPlanes.count)")
            }
        }

        isPlaneDetected = !detectedPlanes.isEmpty
        updatePlaneDetectionStatus()
    }

    private func updatePlaneDetectionStatus() {
        if detectedPlanes.isEmpty {
            planeDetectionStatus = "Scanning for surface..."
        } else if !hasStableDetection {
            planeDetectionStatus = "Move camera around object"
        } else if detectedPlanes.count == 1 {
            planeDetectionStatus = "Surface locked"
        } else {
            planeDetectionStatus = "\(detectedPlanes.count) surfaces locked"
        }
    }
}
