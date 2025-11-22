//
//  CameraWeightView.swift
//  StoneLifting
//
//  Created by Max Rogers on 11/15/25.
//
// TODO resolve this
// swiftlint:disable file_length type_body_length

// TODO break up this file - plane detection can be it's own file

import SwiftUI
import AVFoundation
import ARKit
import RealityKit
import CoreMedia

// MARK: - Weight Estimation Button

/// Camera-style button for real-time weight estimation
struct WeightEstimationButton: View {
    let stoneType: StoneType
    let onEstimate: (Double) -> Void

    @State private var showingCamera = false

    init(stoneType: StoneType = .granite, onEstimate: @escaping (Double) -> Void) {
        self.stoneType = stoneType
        self.onEstimate = onEstimate
    }

    var body: some View {
        Button(action: {
            showingCamera = true
        }) {
            HStack(spacing: 8) {
                Image(systemName: "camera.viewfinder")
                    .foregroundColor(.blue)
                    .font(.system(size: 16, weight: .semibold))

                Text("Estimate Weight")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
        .fullScreenCover(isPresented: $showingCamera) {
            CameraWeightView(stoneType: stoneType) { weight in
                onEstimate(weight)
                showingCamera = false
            }
        }
    }
}

// MARK: - Camera Weight View

// TODO option for user to capture the photo as upload photo

/// Real-time camera view for weight estimation with overlay guidance
struct CameraWeightView: View {
    let stoneType: StoneType
    let onConfirm: (Double) -> Void

    @State private var viewModel: CameraWeightViewModel
    @State private var arManager = ARPlaneDetectionManager()
    @State private var analysisTask: Task<Void, Never>?
    @State private var allowTappingFallback = false  // Fallback if plane detection struggles
    @State private var showTips = true  // Show tips initially, fade out after a few seconds
    @Environment(\.dismiss) private var dismiss

    init(stoneType: StoneType = .granite, onConfirm: @escaping (Double) -> Void) {
        self.stoneType = stoneType
        self.onConfirm = onConfirm
        _viewModel = State(initialValue: CameraWeightViewModel(stoneType: stoneType))
    }

    var body: some View {
        ZStack {
            GeometryReader { geometry in
                ARCameraView(arManager: arManager)
                    .ignoresSafeArea()
                    .onTapGesture { location in
                        // Only handle taps in measurement mode AND when surface is locked (or fallback timeout)
                        if viewModel.isMeasurementMode {
                            // Require stable plane detection before allowing measurements for accuracy
                            // Allow fallback after 3s timeout if detection struggles
                            guard (arManager.isPlaneDetected && arManager.hasStableDetection) || allowTappingFallback else {
                                // Provide feedback if user taps too early - tell them to keep moving
                                viewModel.updateFeedback("Keep moving camera to scan surface...")
                                return
                            }
                            handleTap(at: location, in: geometry.size)
                        }
                    }
            }

            // Top overlay with instructions
            VStack(spacing: 0) {
                topOverlay
                Spacer()
                bottomOverlay
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .onAppear {
            arManager.startSession()
            analysisTask = startAnalysis()

            // Fallback timeout if plane detection struggles (bad lighting, featureless surfaces, etc.)
            // All ARKit devices support plane detection, but some conditions make it difficult
            // LiDAR devices: typically lock in 0.5-1s
            // Non-LiDAR devices: typically lock in 1-2s
            // Fallback at 3s allows measurement even if surface detection fails
            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                if !arManager.hasStableDetection {
                    allowTappingFallback = true
                    viewModel.updateFeedback("Surface locked - Tap first edge (LENGTH)")
                }
            }

            // Fade out tips after 5 seconds
            Task {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                withAnimation(.easeOut(duration: 0.5)) {
                    showTips = false
                }
            }
        }
        .onChange(of: arManager.hasStableDetection) { _, isStable in
            // When surface locks, update feedback to start measurement
            if isStable && viewModel.isMeasurementMode {
                viewModel.surfaceReady()
            } else if !isStable && viewModel.isMeasurementMode {
                viewModel.surfaceLost()
            }
        }
        .onDisappear {
            // Cancel analysis task first
            analysisTask?.cancel()
            analysisTask = nil

            // Stop AR session
            arManager.stopSession()

            // Reset viewModel state
            viewModel.reset()
        }
    }

    @ViewBuilder
    private var topOverlay: some View {
        VStack(spacing: 12) {
            HStack {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.title3)
                        .foregroundColor(.white)
                        .padding(12)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Circle())
                }

                Spacer()

                // Undo last tap button
                if !arManager.tapAnchors.isEmpty && !viewModel.isEditingMeasurements {
                    Button(action: {
                        // First undo in AR manager (removes anchor and line)
                        let _ = arManager.undoLastTap()
                        // Then undo in view model (updates measurement state)
                        viewModel.undoLastTap()
                    }) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.title3)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                }
            }
            .padding()

            // Feedback message - single condensed status
            HStack(spacing: 8) {
                Image(systemName: arManager.isPlaneDetected ? "checkmark.circle.fill" : "circle.dotted")
                    .foregroundColor(arManager.isPlaneDetected ? .green : .orange)
                    .font(.subheadline)

                Text(viewModel.feedbackMessage)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .cornerRadius(16)

            // Measurement summary box
            if viewModel.measuredLength != nil || viewModel.measuredWidth != nil || viewModel.measuredHeight != nil {
                HStack {
                    if viewModel.isEditingMeasurements {
                        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                            if let length = viewModel.measuredLength {
                                editableDimensionGridRow(label: "L", value: length, color: .cyan, dimension: .length)
                            }

                            if let width = viewModel.measuredWidth {
                                editableDimensionGridRow(label: "W", value: width, color: .green, dimension: .width)
                            }

                            if let height = viewModel.measuredHeight {
                                editableDimensionGridRow(label: "H", value: height, color: .orange, dimension: .height)
                            }

                            // Reset button
                            if viewModel.hasAdjustedMeasurements {
                                GridRow {
                                    Button(action: {
                                        viewModel.resetToOriginalMeasurements()
                                    }) {
                                        HStack(spacing: 3) {
                                            Image(systemName: "arrow.counterclockwise")
                                                .font(.caption2)
                                            Text("Reset")
                                                .font(.caption2)
                                        }
                                        .foregroundColor(.white.opacity(0.8))
                                        .padding(.vertical, 4)
                                        .padding(.horizontal, 8)
                                        .background(Color.white.opacity(0.15))
                                        .cornerRadius(6)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial)
                        .cornerRadius(10)
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            if let length = viewModel.measuredLength {
                                dimensionLabel(label: "L", value: length, color: .cyan)
                            }

                            if let width = viewModel.measuredWidth {
                                dimensionLabel(label: "W", value: width, color: .green)
                            }

                            if let height = viewModel.measuredHeight {
                                dimensionLabel(label: "H", value: height, color: .orange)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial)
                        .cornerRadius(10)
                    }

                    // Edit/Done button (only show when all measurements complete)
                    if !viewModel.isMeasurementMode {
                        Button(action: {
                            viewModel.isEditingMeasurements.toggle()
                        }) {
                            Image(systemName: viewModel.isEditingMeasurements ? "checkmark.circle.fill" : "pencil.circle")
                                .font(.title3)
                                .foregroundColor(.blue)
                                .padding(8)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                    }

                    Spacer()
                }
            }
        }
        .background(
            LinearGradient(
                colors: [.black.opacity(0.5), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    @ViewBuilder
    private var bottomOverlay: some View {
        VStack(spacing: 16) {
            if let estimate = viewModel.currentEstimate, viewModel.isStoneDetected {
                VStack(spacing: 4) {
                    Text("\(Int(estimate)) lbs")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)

                    Text("\(Int(viewModel.confidenceLevel * 100))% confidence")
                        .font(.caption)
                        .foregroundColor(confidenceColor(viewModel.confidenceLevel))
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 24)
                .background(.ultraThinMaterial)
                .cornerRadius(16)
            }

            // Confirm button (only show when confidence is good AND plane detection is stable)
            if viewModel.confidenceLevel > 0.6,
               let estimate = viewModel.currentEstimate,
               !arManager.isPlaneDetected || arManager.hasStableDetection {
                Button(action: {
                    onConfirm(estimate)
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark")
                            .font(.body)
                            .fontWeight(.semibold)

                        Text("Use \(Int(estimate)) lbs (\(Int(viewModel.confidenceLevel * 100))%)")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [.blue, .cyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(14)
                    .shadow(color: .blue.opacity(0.3), radius: 8, y: 4)
                }
                .padding(.horizontal, 24)
            }

            // Tips - fade out after 5 seconds
            if showTips {
                HStack(spacing: 12) {
                    tipItem(icon: "hand.raised.fill", text: "Hold camera steady")
                    tipItem(icon: "light.max", text: "Use good lighting")
                }
                .padding(.horizontal, 24)
                .opacity(showTips ? 1.0 : 0.0)
                .animation(.easeOut(duration: 0.5), value: showTips)
            }
        }
        .padding(.bottom, 24)
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    @ViewBuilder
    private func tipItem(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(.caption2)
        }
        .foregroundColor(.white.opacity(0.7))
    }

    private func confidenceColor(_ confidence: Double) -> Color {
        switch confidence {
        case 0.75...: return .green
        case 0.6..<0.75: return .yellow
        default: return .orange
        }
    }

    // MARK: - Dimension Label Helper (compact view)

    @ViewBuilder
    private func dimensionLabel(label: String, value: Double, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text("\(label): \(String(format: "%.1f", value))\"")
                .font(.subheadline)
                .foregroundColor(.white)
                .monospacedDigit()
        }
    }

    // MARK: - Editable Dimension Grid Row (aligned steppers using Grid)

    @ViewBuilder
    private func editableDimensionGridRow(label: String, value: Double, color: Color, dimension: CameraWeightViewModel.Dimension) -> some View {
        GridRow {
            // Column 1: Circle indicator
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            // Column 2: Label and value
            Text("\(label): \(String(format: "%.1f", value))\"")
                .font(.body)
                .foregroundColor(.white)
                .monospacedDigit()

            // Column 3: Minus button
            Button(action: {
                viewModel.decrementDimension(dimension, by: 0.5)
            }) {
                Image(systemName: "minus.circle.fill")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)

            // Column 4: Plus button
            Button(action: {
                viewModel.incrementDimension(dimension, by: 0.5)
            }) {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
        }
    }

    private func startAnalysis() -> Task<Void, Never> {
        Task {
            // Analyze frames continuously
            while !Task.isCancelled {
                // Perform raycast from center of screen to get hit test result
                let hitResult = await arManager.performCenterRaycast()

                // Analyze using hit test result (uses measured width or falls back to 8")
                _ = await viewModel.analyzeFrame(hitResult: hitResult)

                // Wait a bit before next frame (30 FPS analysis)
                try? await Task.sleep(nanoseconds: 33_000_000)
            }
        }
    }

    /// Handle tap gesture for edge measurement using RealityKit
    private func handleTap(at location: CGPoint, in size: CGSize) {
        AppLogger().debug("Tap detected at \(location) in view size \(size)")

        // Limit to 6 taps for 3 dimensions (2 points per dimension)
        guard arManager.tapAnchors.count < 6 else {
            AppLogger().debug("Already have 6 tap anchors (3 dimensions measured), ignoring tap")
            return
        }

        // Perform raycast using RealityKit
        guard let result = arManager.performTapRaycast(at: location) else {
            AppLogger().debug("Raycast failed for tap at \(location)")
            return
        }

        // Determine marker color based on which dimension we're measuring
        // Dimension 1 (Length): cyan/blue
        // Dimension 2 (Width): green/lime
        // Dimension 3 (Height): orange/red
        let color: UIColor
        switch arManager.tapAnchors.count {
        case 0: color = .cyan        // Dimension 1, point 1
        case 1: color = .systemBlue  // Dimension 1, point 2
        case 2: color = .green       // Dimension 2, point 1
        case 3: color = .systemGreen // Dimension 2, point 2
        case 4: color = .orange      // Dimension 3, point 1
        case 5: color = .red         // Dimension 3, point 2
        default: color = .white      // Shouldn't happen
        }

        // Add 3D sphere marker at the hit location
        arManager.addSphereMarker(at: result.worldTransform, color: color)

        // Extract world position from transform matrix
        let worldPosition = simd_float3(
            result.worldTransform.columns.3.x,
            result.worldTransform.columns.3.y,
            result.worldTransform.columns.3.z
        )

        // Draw line connecting pairs of points (after every 2nd tap)
        if arManager.tapAnchors.count % 2 == 0 {
            // Get the previous point's position (count - 2 because we just added the current point at count - 1)
            let previousAnchor = arManager.tapAnchors[arManager.tapAnchors.count - 2]
            let previousPosition = previousAnchor.position(relativeTo: nil)

            // Draw line from previous point to current point
            // Use different colors for each dimension
            let lineColor: UIColor
            switch arManager.tapAnchors.count {
            case 2: lineColor = .cyan          // Length line
            case 4: lineColor = .green         // Width line
            case 6: lineColor = .orange        // Height line
            default: lineColor = .yellow
            }

            arManager.drawLine(from: previousPosition, to: worldPosition, color: lineColor)
        }

        // Update view model with 3D world position
        viewModel.handleEdgeTap(worldPosition: worldPosition)
    }
}

// MARK: - Camera Manager

/// Manages AVFoundation camera session for real-time analysis
@Observable
final class CameraManager: NSObject {
    fileprivate let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private var currentSampleBuffer: CMSampleBuffer?

    var previewLayer: AVCaptureVideoPreviewLayer?

    override init() {
        super.init()
        setupCamera()
    }

    private func setupCamera() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            self.session.beginConfiguration()
            self.session.sessionPreset = .high

            // Add video input
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: device) else {
                return
            }

            if self.session.canAddInput(input) {
                self.session.addInput(input)
            }

            // Add video output
            self.videoOutput.setSampleBufferDelegate(self, queue: self.sessionQueue)
            self.videoOutput.alwaysDiscardsLateVideoFrames = true

            if self.session.canAddOutput(self.videoOutput) {
                self.session.addOutput(self.videoOutput)
            }

            self.session.commitConfiguration()
        }
    }

    func startSession() {
        sessionQueue.async { [weak self] in
            self?.session.startRunning()
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            self?.session.stopRunning()
            self?.currentSampleBuffer = nil
        }
    }

    func getCurrentFrame() async -> CMSampleBuffer? {
        return await withCheckedContinuation { continuation in
            sessionQueue.async {
                continuation.resume(returning: self.currentSampleBuffer)
            }
        }
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        currentSampleBuffer = sampleBuffer
    }
}

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

// MARK: - AR Camera View

/// AR camera view that shows camera feed (plane detection runs in background, no visual overlays)
struct ARCameraView: UIViewRepresentable {
    let arManager: ARPlaneDetectionManager

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        arView.session = arManager.session

        arView.environment.sceneUnderstanding.options = []
        arView.environment.sceneUnderstanding.options.insert(.occlusion)

        arView.renderOptions = [.disablePersonOcclusion, .disableDepthOfField, .disableMotionBlur]

        arManager.arView = arView

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        // No updates needed
    }
}

// MARK: - Preview

#Preview {
    WeightEstimationButton(stoneType: .granite) { weight in
        print("Estimated weight: \(weight)")
    }
}
