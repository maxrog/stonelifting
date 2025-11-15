//
//  CameraWeightView.swift
//  StoneLifting
//
//  Created by Max Rogers on 11/15/25.
//

import SwiftUI
import AVFoundation

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
    @State private var cameraManager = CameraManager()
    @Environment(\.dismiss) private var dismiss

    init(stoneType: StoneType = .granite, onConfirm: @escaping (Double) -> Void) {
        self.stoneType = stoneType
        self.onConfirm = onConfirm
        _viewModel = State(initialValue: CameraWeightViewModel(stoneType: stoneType))
    }

    var body: some View {
        ZStack {
            CameraPreviewView(cameraManager: cameraManager)
                .ignoresSafeArea()

            if viewModel.isStoneDetected, let boundingBox = viewModel.detectedBoundingBox {
                GeometryReader { geometry in
                    StoneDetectionOverlay(
                        boundingBox: boundingBox,
                        confidence: viewModel.confidenceLevel,
                        frameSize: geometry.size
                    )
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
            cameraManager.startSession()
            startAnalysis()
        }
        .onDisappear {
            cameraManager.stopSession()
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
            }
            .padding()

            // Feedback message
            HStack(spacing: 8) {
                Image(systemName: "camera.viewfinder")
                    .foregroundColor(.cyan)

                Text(viewModel.feedbackMessage)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .cornerRadius(20)
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
        VStack(spacing: 20) {
            if let estimate = viewModel.currentEstimate, viewModel.isStoneDetected {
                VStack(spacing: 8) {
                    Text("Estimated Weight")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))

                    Text("\(Int(estimate)) lbs")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.white)

                    HStack(spacing: 8) {
                        Text("Confidence:")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))

                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.white.opacity(0.3))
                                    .frame(height: 8)

                                RoundedRectangle(cornerRadius: 4)
                                    .fill(confidenceColor(viewModel.confidenceLevel))
                                    .frame(width: geometry.size.width * viewModel.confidenceLevel, height: 8)
                            }
                        }
                        .frame(width: 100, height: 8)

                        Text("\(Int(viewModel.confidenceLevel * 100))%")
                            .font(.caption)
                            .foregroundColor(.white)
                            .frame(width: 40, alignment: .trailing)
                    }
                }
                .padding(.vertical, 20)
                .padding(.horizontal, 32)
                .background(.ultraThinMaterial)
                .cornerRadius(20)
            }

            // Confirm button (only show when confidence is good)
            if viewModel.confidenceLevel > 0.6, let estimate = viewModel.currentEstimate {
                Button(action: {
                    onConfirm(estimate)
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark")
                            .font(.title3)
                            .fontWeight(.semibold)

                        Text("Use \(Int(estimate)) lbs")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        LinearGradient(
                            colors: [.blue, .cyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(16)
                    .shadow(color: .blue.opacity(0.3), radius: 10, y: 5)
                }
                .padding(.horizontal, 32)
            }

            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    tipItem(icon: "arrow.up.left.and.arrow.down.right", text: "Fill frame with stone")
                    tipItem(icon: "light.max", text: "Use good lighting")
                }
                .padding(.horizontal, 32)
            }
            .padding(.bottom, 32)
        }
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

    private func startAnalysis() {
        Task {
            // Analyze frames continuously
            while !Task.isCancelled {
                if let sampleBuffer = await cameraManager.getCurrentFrame() {
                    _ = await viewModel.analyzeFrame(sampleBuffer)
                }

                // Wait a bit before next frame (30 FPS analysis)
                try? await Task.sleep(nanoseconds: 33_000_000)
            }
        }
    }
}

// MARK: - Stone Detection Overlay

/// Visual overlay showing detected stone boundary
struct StoneDetectionOverlay: View {
    let boundingBox: CGRect
    let confidence: Double
    let frameSize: CGSize

    var body: some View {
        let rect = convertedRect

        ZStack {
            // Corner brackets
            Path { path in
                let cornerLength: CGFloat = 30

                // Top-left
                path.move(to: CGPoint(x: rect.minX, y: rect.minY + cornerLength))
                path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.minX + cornerLength, y: rect.minY))

                // Top-right
                path.move(to: CGPoint(x: rect.maxX - cornerLength, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + cornerLength))

                // Bottom-right
                path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - cornerLength))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
                path.addLine(to: CGPoint(x: rect.maxX - cornerLength, y: rect.maxY))

                // Bottom-left
                path.move(to: CGPoint(x: rect.minX + cornerLength, y: rect.maxY))
                path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
                path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - cornerLength))
            }
            .stroke(overlayColor, lineWidth: 4)

            Rectangle()
                .fill(overlayColor.opacity(0.1))
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
        }
    }

    private var convertedRect: CGRect {
        // Vision returns normalized coordinates (0-1) with origin at bottom-left
        // Convert to SwiftUI coordinates with origin at top-left
        CGRect(
            x: boundingBox.minX * frameSize.width,
            y: (1 - boundingBox.maxY) * frameSize.height,
            width: boundingBox.width * frameSize.width,
            height: boundingBox.height * frameSize.height
        )
    }

    private var overlayColor: Color {
        confidence > 0.75 ? .green : confidence > 0.6 ? .yellow : .orange
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

// MARK: - Camera Preview View

/// SwiftUI wrapper for AVCaptureVideoPreviewLayer
struct CameraPreviewView: UIViewRepresentable {
    let cameraManager: CameraManager

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black

        let previewLayer = AVCaptureVideoPreviewLayer(session: cameraManager.session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)

        context.coordinator.previewLayer = previewLayer

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewLayer = context.coordinator.previewLayer {
            DispatchQueue.main.async {
                previewLayer.frame = uiView.bounds
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var previewLayer: AVCaptureVideoPreviewLayer?
    }
}

// MARK: - Preview

#Preview {
    WeightEstimationButton(stoneType: .granite) { weight in
        print("Estimated weight: \(weight)")
    }
}
