//
//  ClusterDetailSheet.swift
//  StoneAtlas
//
//  Created by Max Rogers on 10/4/25.
//

import SwiftUI

/// Sheet showing stones within a cluster
struct ClusterDetailSheet: View {
    let clusterItem: StoneClusterItem
    let onStoneSelect: (Stone) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(clusterItem.stones, id: \.id) { stone in
                Button(action: {
                    onStoneSelect(stone)
                    dismiss()
                }) {
                    StoneRowView(stone: stone) {
                        onStoneSelect(stone)
                        dismiss()
                    }
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Stones in Area")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
