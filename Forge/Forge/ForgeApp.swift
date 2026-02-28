//
//  ForgeApp.swift
//  Forge
//

import SwiftUI
import SwiftData
import MWDATCore
import OSLog

private let logger = Logger(subsystem: "com.scopesnap", category: "App")

@main
struct ForgeApp: App {

    @State private var wearablesManager = WearablesManager()
    @State private var offlineQueueManager = OfflineQueueManager()

    init() {
        do {
            try Wearables.configure()
        } catch {
            assertionFailure("Failed to configure Wearables SDK: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(wearablesManager)
                .environment(offlineQueueManager)
                .onOpenURL { url in
                    Task {
                        do {
                            _ = try await Wearables.shared.handleUrl(url)
                        } catch {
                            logger.error("Failed to handle wearables URL: \(error, privacy: .public)")
                        }
                    }
                }
        }
        .modelContainer(for: [
            Project.self,
            Recording.self,
            PhotoCapture.self,
            ScopePacket.self,
            TradeTask.self,
        ])
    }
}
