//
//  StonePhotoFormView.swift
//  StoneLifting
//
//  Created by Max Rogers on 7/27/25.
//

import PhotosUI
import SwiftUI

// MARK: - Photo Section View

/// Photo selection component for stone creation
struct StonePhotoFormView: View {
    @Binding var photoData: Data?
    @Binding var showingPhotoOptions: Bool

    var body: some View {
        VStack(spacing: 16) {
            Text("Stone Photo")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let photoData = photoData, let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 200)
                    .clipped()
                    .cornerRadius(12)
                    .overlay(
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Button("Change") {
                                    showingPhotoOptions = true
                                }
                                .padding(8)
                                .background(.ultraThinMaterial)
                                .cornerRadius(8)
                                .padding()
                            }
                        }
                    )
            } else {
                Button(action: {
                    showingPhotoOptions = true
                }) {
                    VStack(spacing: 12) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.blue)

                        Text("Add Photo")
                            .font(.headline)

                        Text("Take a photo or choose from library")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(height: 150)
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
