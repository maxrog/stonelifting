//
//  NetworkMonitor.swift
//  StoneAtlas
//
//  Created by Max Rogers on 1/7/26.
//

import Foundation
import Network

// MARK: - Network Monitor

/// Monitors network connectivity status
@Observable
final class NetworkMonitor {
    // MARK: - Properties

    static let shared = NetworkMonitor()

    private let logger = AppLogger()
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.marfodub.StoneAtlas.NetworkMonitor")

    var isConnected = false
    var isExpensive = false
    var connectionType: NWInterface.InterfaceType?

    // MARK: - Initialization

    private init() {
        logger.info("NetworkMonitor initialized")
        startMonitoring()
    }

    // MARK: - Public Methods

    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }

            let wasConnected = self.isConnected
            self.isConnected = path.status == .satisfied
            self.isExpensive = path.isExpensive
            self.connectionType = self.getConnectionType(from: path)

            DispatchQueue.main.async {
                if self.isConnected {
                    self.logger.info("Network connected (\(self.connectionType?.description ?? "unknown"))")

                    if !wasConnected {
                        self.logger.info("Network reconnected - triggering pending stone sync")
                        Task {
                            await OfflineSyncService.shared.syncPendingStones()
                        }
                    }
                } else {
                    self.logger.warning("Network disconnected")
                }
            }
        }

        monitor.start(queue: queue)
        logger.info("Network monitoring started")
    }

    func stopMonitoring() {
        monitor.cancel()
        logger.info("Network monitoring stopped")
    }

    // MARK: - Private Methods

    private func getConnectionType(from path: NWPath) -> NWInterface.InterfaceType? {
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .wiredEthernet
        } else {
            return nil
        }
    }
}

extension NWInterface.InterfaceType {
    var description: String {
        switch self {
        case .wifi: return "WiFi"
        case .cellular: return "Cellular"
        case .wiredEthernet: return "Ethernet"
        case .loopback: return "Loopback"
        case .other: return "Other"
        @unknown default: return "Unknown"
        }
    }
}
