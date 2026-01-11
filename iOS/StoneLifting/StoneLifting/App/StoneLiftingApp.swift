//
//  StoneLiftingApp.swift
//  StoneLifting
//
//  Created by Max Rogers on 7/10/25.
//

import SwiftUI
import SwiftData

// See ROADMAP.md for feature planning and TODOs

@main
struct StoneLiftingApp: App {
    private let networkMonitor = NetworkMonitor.shared
    private let offlineSyncService = OfflineSyncService.shared

    let sharedContainer: ModelContainer = {
        do {
            let schema = Schema([PendingStone.self, CachedStone.self])
            let configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true
            )
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create model container: \(error)")
        }
    }()

    init() {
        StoneCacheService.shared.configure(with: sharedContainer)
        OfflineSyncService.shared.configure(with: sharedContainer)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(sharedContainer)
    }
}
