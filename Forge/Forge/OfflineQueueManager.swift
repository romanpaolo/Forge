//
//  OfflineQueueManager.swift
//  Forge
//
//  Phase 4: Monitors network connectivity so the app can queue transcription
//  requests while offline and replay them automatically when connectivity returns.
//

import Network
import Observation
import Foundation

/// Monitors the device's network path and exposes a simple `isOnline` flag.
/// Inject via `.environment(offlineQueueManager)` from `ForgeApp`.
@Observable @MainActor final class OfflineQueueManager {

    /// `true` when the device has a usable network path (Wi-Fi or cellular).
    private(set) var isOnline: Bool = true

    private let monitor = NWPathMonitor()

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                self?.isOnline = path.status == .satisfied
            }
        }
        monitor.start(queue: DispatchQueue(label: "com.scopesnap.network", qos: .utility))
    }

    deinit {
        monitor.cancel()
    }
}
