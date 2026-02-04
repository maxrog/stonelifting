//
//  DebugSettingsView.swift
//  StoneAtlas
//
//  Debug-only settings for testing
//

#if DEBUG

import SwiftUI

struct DebugSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var stoneCount = 1000
    @State private var isGenerating = false
    @State private var showAlert = false
    @State private var alertMessage = ""

    private let stoneService = StoneService.shared
    private let cacheService = StoneCacheService.shared

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper("Stone Count: \(stoneCount)", value: $stoneCount, in: 100...10_000, step: 100)

                    Button("Generate Test Stones") {
                        generateTestStones()
                    }
                    .disabled(isGenerating)

                    if isGenerating {
                        HStack {
                            ProgressView()
                            Text("Generating stones...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Test Data Generation")
                } footer: {
                    Text("Generates mock stones and caches them. After generating, tap 'Load from Cache' to view them in the app.")
                        .font(.caption)
                }

                Section("Load Test Data") {
                    Button("Load Test Stones from Cache") {
                        loadTestStonesFromCache()
                    }
                }

                Section("Cache Management") {
                    Button("Clear All Cache", role: .destructive) {
                        Task {
                            do {
                                try await cacheService.clearAllCache()
                                alertMessage = "Cache cleared successfully"
                                showAlert = true
                            } catch {
                                alertMessage = "Failed to clear cache: \(error.localizedDescription)"
                                showAlert = true
                            }
                        }
                    }
                }

                Section("Current State") {
                    HStack {
                        Text("User Stones")
                        Spacer()
                        Text("\(stoneService.userStones.count)")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Public Stones")
                        Spacer()
                        Text("\(stoneService.publicStones.count)")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Debug Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Result", isPresented: $showAlert) {
                Button("OK") {}
            } message: {
                Text(alertMessage)
            }
        }
    }

    private func generateTestStones() {
        isGenerating = true

        Task {
            // Generate mock stones
            let mockStones = TestDataGenerator.generateStones(count: stoneCount)

            // Split between user and public stones
            let splitIndex = mockStones.count / 2
            let userStones = Array(mockStones[0..<splitIndex])
            let publicStones = Array(mockStones[splitIndex..<mockStones.count])

            // Cache them in SwiftData
            do {
                try await cacheService.cacheStonesInBatch([
                    (userStones, .userStones),
                    (publicStones, .publicStones)
                ])

                await MainActor.run {
                    alertMessage = """
                    Generated \(stoneCount) test stones (\(userStones.count) user, \(publicStones.count) public)

                    Tap 'Load Test Stones from Cache' to view them!
                    """
                    showAlert = true
                    isGenerating = false
                }
            } catch {
                await MainActor.run {
                    alertMessage = "Failed to cache stones: \(error.localizedDescription)"
                    showAlert = true
                    isGenerating = false
                }
            }
        }
    }

    private func loadTestStonesFromCache() {
        Task {
            let success = await stoneService.loadFromCache()

            await MainActor.run {
                if success {
                    alertMessage = """
                    Loaded test stones from cache!

                    \(stoneService.userStones.count) user stones
                    \(stoneService.publicStones.count) public stones

                    """
                } else {
                    alertMessage = "Failed to load from cache. Generate test stones first."
                }
                showAlert = true
            }
        }
    }
}

#Preview {
    DebugSettingsView()
}

#endif
