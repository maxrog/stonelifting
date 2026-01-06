//
//  CameraWeightView.swift
//  StoneLifting
//
//  Created by Max Rogers on 11/15/25.
//

import SwiftUI
import AVFoundation
import ARKit
import RealityKit
import CoreMedia

// MARK: - Camera Weight View

/// Real-time camera view for weight estimation with AR measurements and photo capture
struct CameraWeightView: View {
    private let logger = AppLogger()

    let stoneType: StoneType
    let onConfirm: (Double) -> Void
    @Binding var capturedPhoto: Data?

    @State private var viewModel: CameraWeightViewModel
    @State private var arManager = ARPlaneDetectionManager()
    @State private var analysisTask: Task<Void, Never>?
    @State private var allowTappingFallback = false  // Fallback if plane detection struggles
    @State private var showTips = true  // Show tips initially, fade out after a few seconds
    @State private var showingCaptureConfirmation = false
    @State private var photoCapturedThisSession = false
    @Environment(\.dismiss) private var dismiss

    init(stoneType: StoneType = .granite, capturedPhoto: Binding<Data?>, onConfirm: @escaping (Double) -> Void) {
        self.stoneType = stoneType
        self._capturedPhoto = capturedPhoto
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

            // Photo capture confirmation flash
            if showingCaptureConfirmation {
                Color.white
                    .opacity(0.3)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
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

            // Reset photo capture indicator
            photoCapturedThisSession = false
        }
    }

    @ViewBuilder
    private var measurementSummaryBox: some View {
        HStack {
            if viewModel.isEditingMeasurements {
                VStack(alignment: .leading, spacing: 8) {
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
                    }

                    if viewModel.hasAdjustedMeasurements {
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
                        _ = arManager.undoLastTap()
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
                    dismiss()
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

            // Bottom controls row
            HStack(alignment: .bottom, spacing: 0) {
                // Measurement box on left (if present)
                if viewModel.measuredLength != nil || viewModel.measuredWidth != nil || viewModel.measuredHeight != nil {
                    measurementSummaryBox
                        .padding(.leading, 16)
                }

                // Camera button - centered in remaining space
                Spacer()
                Button(action: {
                    capturePhoto()
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.6))
                            .frame(width: 70, height: 70)

                        Circle()
                            .stroke(Color.white, lineWidth: 4)
                            .frame(width: 70, height: 70)

                        if photoCapturedThisSession {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title)
                                .foregroundColor(.green)
                        } else {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 56, height: 56)
                        }
                    }
                }
                Spacer()
            }
            .padding(.trailing, 16)
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
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .fixedSize()

            // Column 4: Plus button
            Button(action: {
                viewModel.incrementDimension(dimension, by: 0.5)
            }) {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.8))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .fixedSize()
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

    /// Capture current AR frame as photo
    private func capturePhoto() {
        Task {
            guard let frame = await arManager.getCurrentFrame() else {
                logger.error("Failed to get AR frame for photo capture")
                return
            }

            let pixelBuffer = frame.capturedImage
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            let context = CIContext()

            guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
                logger.error("Failed to create CGImage from AR frame")
                return
            }

            let uiImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: .right)

            // Optimize and compress
            let maxSize: CGFloat = 1920
            let size = uiImage.size
            let ratio = min(maxSize / size.width, maxSize / size.height)

            let optimizedImage: UIImage
            if ratio < 1.0 {
                let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
                let renderer = UIGraphicsImageRenderer(size: newSize)
                optimizedImage = renderer.image { _ in
                    uiImage.draw(in: CGRect(origin: .zero, size: newSize))
                }
            } else {
                optimizedImage = uiImage
            }

            if let photoData = optimizedImage.jpegData(compressionQuality: 0.8) {
                await MainActor.run {
                    self.capturedPhoto = photoData  // Save immediately to parent
                    self.photoCapturedThisSession = true
                    withAnimation(.easeInOut(duration: 0.2)) {
                        self.showingCaptureConfirmation = true
                    }
                }
                logger.info("Photo captured successfully - Size: \(photoData.count) bytes")

                // Hide confirmation after brief delay
                try? await Task.sleep(nanoseconds: 300_000_000)  // 0.3 seconds
                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.2)) {
                        self.showingCaptureConfirmation = false
                    }
                }
            }
        }
    }

    /// Handle tap gesture for edge measurement using RealityKit
    private func handleTap(at location: CGPoint, in size: CGSize) {
        logger.debug("Tap detected at \(location) in view size \(size)")

        // Limit to 6 taps for 3 dimensions (2 points per dimension)
        guard arManager.tapAnchors.count < 6 else {
            logger.debug("Already have 6 tap anchors (3 dimensions measured), ignoring tap")
            return
        }

        // Perform raycast using RealityKit
        guard let result = arManager.performTapRaycast(at: location) else {
            logger.debug("Raycast failed for tap at \(location)")
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
    @Previewable @State var photoData: Data?
    @Previewable @State var stoneType: StoneType = .granite

    CameraWeightView(stoneType: stoneType, capturedPhoto: $photoData) { weight in
        print("Estimated weight: \(weight) lbs")
    }
}
