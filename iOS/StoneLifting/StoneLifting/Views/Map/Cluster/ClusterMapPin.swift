//
//  ClusterMapPin.swift
//  StoneLifting
//
//  Created by Max Rogers on 10/4/25.
//

import SwiftUI

/// Custom map pin for displaying clusters of stones
struct ClusterMapPin: View {
    let clusterItem: StoneClusterItem
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            if clusterItem.isCluster {
                clusterPinView
            } else {
                individualPinView
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var clusterPinView: some View {
        VStack(spacing: 0) {
            // Bubble
            ZStack {
                Circle()
                    .fill(.blue)
                    .frame(width: pinSize, height: pinSize)
                    .overlay(
                        Circle()
                            .stroke(.white, lineWidth: 3)
                    )

                Text("\(clusterItem.count)")
                    .font(.system(size: fontSize, weight: .bold))
                    .foregroundColor(.white)
            }

            // Pin point
            Triangle()
                .fill(.blue)
                .frame(width: 12, height: 8)
                .offset(y: -2)
        }
        .scaleEffect(1.1) // Slightly larger for clusters
    }

    @ViewBuilder
    private var individualPinView: some View {
        if let stone = clusterItem.stones.first {
            StoneMapPin(stone: stone, onTap: onTap)
        } else {
            EmptyView()
        }
    }

    // Dynamic sizing based on cluster count
    private var pinSize: CGFloat {
        let count = clusterItem.count
        switch count {
        case 2...5: return 35
        case 6...10: return 42
        case 11...20: return 50
        default: return 55
        }
    }

    private var fontSize: CGFloat {
        let count = clusterItem.count
        switch count {
        case 2...9: return 12
        case 10...99: return 10
        default: return 8
        }
    }
}
