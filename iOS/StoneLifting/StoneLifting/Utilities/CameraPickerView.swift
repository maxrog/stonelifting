//
//  CameraPickerView.swift
//  StoneLifting
//
//  Created by Max Rogers on 7/27/25.
//

import SwiftUI
import UIKit

// MARK: - Camera Picker View

/// CameraPicker that uses UIImagePickerController with SwiftUI presentation
struct CameraPickerView: UIViewControllerRepresentable {

    private let logger = AppLogger()

    let onImageCaptured: (Data) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.cameraDevice = .rear
        picker.delegate = context.coordinator

        // TODO This needed?
        // iOS 17+ optimizations
        if #available(iOS 17.0, *) {
            picker.preferredContentSize = CGSize(width: 390, height: 844) // iPhone size
        }

        logger.info("Camera picker initialized")
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) { }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

        let parent: CameraPickerView
        private let logger = AppLogger()

        init(_ parent: CameraPickerView) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            logger.info("Camera image captured")

            if let image = info[.originalImage] as? UIImage {
                let optimizedImage = optimizeImage(image)
                if let imageData = optimizedImage.jpegData(compressionQuality: 0.8) {
                    logger.info("Image optimized and converted to data - Size: \(imageData.count) bytes")
                    parent.onImageCaptured(imageData)
                } else {
                    logger.error("Failed to convert image to JPEG data")
                }
            } else {
                logger.error("Failed to extract image from camera picker")
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            logger.info("Camera picker cancelled")
            parent.dismiss()
        }

        // MARK: - Image Optimization

        /// Optimize image for storage and upload
        /// - Parameter image: Original UIImage
        /// - Returns: Optimized UIImage
        private func optimizeImage(_ image: UIImage) -> UIImage {
            let maxSize: CGFloat = 1920
            let size = image.size

            if size.width <= maxSize && size.height <= maxSize {
                logger.debug("Image size OK - no resize needed")
                return image
            }

            let ratio = min(maxSize / size.width, maxSize / size.height)
            let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)

            logger.debug("Resizing image from \(size) to \(newSize)")

            let renderer = UIGraphicsImageRenderer(size: newSize)
            let resizedImage = renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: newSize))
            }

            return resizedImage
        }
    }
}
