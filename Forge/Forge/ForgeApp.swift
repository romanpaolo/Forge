//
//  ForgeApp.swift
//  Forge
//
//  Created by Roman Pascua on 2/26/26.
//

import SwiftUI
import CoreData
import MWDATCore

@main
struct ForgeApp: App {
    let persistenceController = PersistenceController.shared

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
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
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
    }
}
