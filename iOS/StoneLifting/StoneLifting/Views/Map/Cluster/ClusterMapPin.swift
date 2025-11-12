//
//  ClusterMapPin.swift
//  StoneLifting
//
//  Created by Max Rogers on 10/4/25.
//

import SwiftUI
import MapKit

/// A map annotation view for either an individual stone or a cluster of stones
struct ClusterMapPin: View {
    let clusterItem: StoneClusterItem
    let onTap: () -> Void

    private var pinColor: Color {
        switch clusterItem {
        case .individual(let stone):
            let isCurrentUser = stone.user.id == AuthService.shared.currentUser?.id
            return .blue.opacity(isCurrentUser ? 1.0 : 0.75)
        case .cluster:
            return .green.opacity(0.75)
        }
    }

    private var labelText: String {
        switch clusterItem {
        case .individual(let stone): return stone.formattedWeight
        case .cluster(_, _, _, let count): return "\(count)"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onTap) {
                VStack(spacing: 4) {
                    // Label
                    Text(labelText)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(pinColor)
                        .cornerRadius(8)

                    // Pin circle
                    Circle()
                        .fill(pinColor)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Group {
                                if case let .individual(stone) = clusterItem {
                                    Image(systemName: stone.liftingLevel.icon)
                                        .font(.caption)
                                        .foregroundColor(.white)
                                } else {
                                    // Cluster indicator
                                    Image(systemName: "square.3.layers.3d")
                                        .font(.system(size: 10))
                                        .foregroundColor(.white)
                                }
                            }
                        )
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                }
            }
            .buttonStyle(.plain)

            // Triangle pointer
            Triangle()
                .fill(pinColor)
                .frame(width: 8, height: 6)
                .offset(y: -1)
        }
        .transition(.scale.combined(with: .opacity))
    }
}

/// Custom triangle shape for map pin point
private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
