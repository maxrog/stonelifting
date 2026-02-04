//
//  WeightEstimationButton.swift
//  StoneAtlas
//
//  Created by Max Rogers on 11/15/25.
//  Extracted from CameraWeightView.swift
//

import SwiftUI

// MARK: - Weight Estimation Button

/// Camera-style button for real-time weight estimation
struct WeightEstimationButton: View {
    let stoneType: StoneType
    @Binding var capturedPhoto: Data?
    let onEstimate: (Double) -> Void

    @State private var showingCamera = false

    init(stoneType: StoneType = .granite, capturedPhoto: Binding<Data?>, onEstimate: @escaping (Double) -> Void) {
        self.stoneType = stoneType
        self._capturedPhoto = capturedPhoto
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
            CameraWeightView(stoneType: stoneType, capturedPhoto: $capturedPhoto) { weight in
                onEstimate(weight)
                showingCamera = false
            }
        }
    }
}
