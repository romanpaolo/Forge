//
//  ContentView.swift
//  Forge
//
//  Thin coordinator — delegates to ProjectListView.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        ProjectListView()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Project.self, inMemory: true)
}
