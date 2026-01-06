//
//  RemoteImage.swift
//  StoneLifting
//
//  Created by Max Rogers on 1/6/26.
//

import SwiftUI

// MARK: - Remote Image

/// Remote image loader with automatic caching
/// Currently provides memory caching via ImageCacheService
/// Future capabilities: retry logic, progress tracking, image transforms, etc.
struct RemoteImage<Content: View, Placeholder: View>: View {
    let url: URL?
    @ViewBuilder let content: (Image) -> Content
    @ViewBuilder let placeholder: () -> Placeholder

    @State private var loadedImage: UIImage?
    @State private var isLoading = false

    private let imageCache = ImageCacheService.shared

    var body: some View {
        Group {
            if let uiImage = loadedImage {
                content(Image(uiImage: uiImage))
            } else {
                placeholder()
                    .task {
                        await loadImage()
                    }
            }
        }
    }

    private func loadImage() async {
        guard let url = url else { return }
        guard !isLoading else { return }

        isLoading = true
        let image = await imageCache.image(for: url.absoluteString)
        loadedImage = image
        isLoading = false
    }
}

// MARK: - Convenience Initializers

extension RemoteImage where Placeholder == Color {
    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content
    ) {
        self.url = url
        self.content = content
        self.placeholder = { Color.gray.opacity(0.2) }
    }
}

extension RemoteImage where Content == Image, Placeholder == Color {
    init(url: URL?) {
        self.url = url
        self.content = { $0 }
        self.placeholder = { Color.gray.opacity(0.2) }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        // Basic usage
        RemoteImage(url: URL(string: "https://via.placeholder.com/300")) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }

        // With custom placeholder
        RemoteImage(url: URL(string: "https://via.placeholder.com/300")) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
        } placeholder: {
            ProgressView()
        }
        .frame(width: 100, height: 100)
    }
    .padding()
}
