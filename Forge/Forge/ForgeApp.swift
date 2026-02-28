//
//  ForgeApp.swift
//  Forge
//

import SwiftUI
import SwiftData
import MWDATCore

@main
struct ForgeApp: App {

    @State private var wearablesManager = WearablesManager()

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
                .onOpenURL { url in
                    Task {
                        do {
                            _ = try await Wearables.shared.handleUrl(url)
                        } catch {
                            print("Failed to handle wearables URL: \(error)")
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
