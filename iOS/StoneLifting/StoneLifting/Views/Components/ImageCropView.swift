//
//  ImageCropView.swift
//  StoneAtlas
//
//  Created by Max Rogers on 11/23/25.
//

import SwiftUI

// MARK: - Image Crop View

/// Interactive image cropping view with drag and pinch-to-zoom
struct ImageCropView: View {
    let image: UIImage
    let onCrop: (Data) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private let cropSize: CGFloat = 300

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black
                    .ignoresSafeArea()

                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                let delta = value / lastScale
                                lastScale = value
                                scale = max(1.0, min(scale * delta, 10.0))
                            }
                            .onEnded { _ in
                                lastScale = 1.0
                            }
                    )
                    .simultaneousGesture(
                        DragGesture()
                            .onChanged { value in
                                offset = CGSize(
                                    width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                )
                            }
                            .onEnded { _ in
                                lastOffset = offset
                            }
                    )

                // Crop overlay
                Rectangle()
                    .fill(Color.black.opacity(0.5))
                    .mask(
                        Rectangle()
                            .fill(Color.white)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .overlay(
                                Rectangle()
                                    .frame(width: cropSize, height: cropSize)
                                    .blendMode(.destinationOut)
                            )
                    )
                    .allowsHitTesting(false)

                // Crop frame border
                Rectangle()
                    .stroke(Color.white, lineWidth: 2)
                    .frame(width: cropSize, height: cropSize)
                    .allowsHitTesting(false)
            }
            .navigationTitle("Crop Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        cropImage()
                    }
                    .foregroundColor(.white)
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func cropImage() {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: cropSize, height: cropSize))

        let croppedImage = renderer.image { _ in
            // Calculate the position to draw the image
            let imageSize = image.size
            let imageAspect = imageSize.width / imageSize.height

            // Calculate fitted size
            var drawSize: CGSize
            if imageAspect > 1 {
                // Landscape
                drawSize = CGSize(width: cropSize * imageAspect, height: cropSize)
            } else {
                // Portrait or square
                drawSize = CGSize(width: cropSize, height: cropSize / imageAspect)
            }

            // Apply scale
            drawSize = CGSize(width: drawSize.width * scale, height: drawSize.height * scale)

            // Calculate position (centered + offset)
            let drawX = (cropSize - drawSize.width) / 2 + offset.width
            let drawY = (cropSize - drawSize.height) / 2 + offset.height

            let drawRect = CGRect(
                x: drawX,
                y: drawY,
                width: drawSize.width,
                height: drawSize.height
            )

            image.draw(in: drawRect)
        }

        // Convert to JPEG data
        if let imageData = croppedImage.jpegData(compressionQuality: 0.8) {
            onCrop(imageData)
        }

        dismiss()
    }
}

// MARK: - Preview

#Preview {
    ImageCropView(
        image: UIImage(systemName: "photo")!,
        onCrop: { _ in }
    )
}
