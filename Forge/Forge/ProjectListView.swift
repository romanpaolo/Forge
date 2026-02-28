//
//  ProjectListView.swift
//  Forge
//
//  Shows all saved projects and a button to create a new one.
//  Phase 2: Glasses status indicator in the toolbar.
//

import SwiftUI
import SwiftData
import MWDATCore

struct ProjectListView: View {
    @Query(sort: \Project.createdAt, order: .reverse) private var projects: [Project]
    @Environment(\.modelContext) private var modelContext
    @Environment(WearablesManager.self) private var wearablesManager

    @State private var showingNewProject = false
    @State private var showingSettings = false
    @State private var showingGlasses = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(projects) { project in
                    NavigationLink(destination: ProjectDetailView(project: project)) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Image(systemName: project.projectType.icon)
                                    .foregroundStyle(.secondary)
                                    .imageScale(.small)
                                Text(project.name)
                                    .font(.headline)
                            }
                            if !project.address.isEmpty {
                                Text(project.address)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            HStack(spacing: 10) {
                                Text(project.createdAt.formatted(date: .abbreviated, time: .omitted))
                                if !project.recordings.isEmpty {
                                    Label("\(project.recordings.count)", systemImage: "waveform")
                                }
                                if !project.packets.isEmpty {
                                    Label("\(project.packets.count)", systemImage: "doc.text")
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 2)
                    }
                }
                .onDelete(perform: deleteProjects)
            }
            .navigationTitle("ScopeSnap")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingGlasses = true
                    } label: {
                        Image(systemName: glassesIcon)
                            .foregroundStyle(glassesColor)
                    }
                    .accessibilityLabel("Glasses connection")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gear")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingNewProject = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .overlay {
                if projects.isEmpty {
                    ContentUnavailableView(
                        "No Projects",
                        systemImage: "folder.badge.plus",
                        description: Text("Tap + to start a new job walk")
                    )
                }
            }
        }
        .sheet(isPresented: $showingNewProject) {
            NewProjectView()
        }
        .sheet(isPresented: $showingSettings) {
            APIKeySettingsView()
        }
        .sheet(isPresented: $showingGlasses) {
            GlassesSetupView()
        }
    }

    // MARK: - Glasses status

    private var glassesIcon: String {
        if wearablesManager.isRegistered && wearablesManager.hasDevice {
            return "glasses"
        } else if wearablesManager.isRegistered {
            return "glasses"
        } else {
            return "glasses"
        }
    }

    private var glassesColor: Color {
        if wearablesManager.isRegistered && wearablesManager.hasDevice {
            return .green
        } else if wearablesManager.isRegistered {
            return .orange
        } else {
            return .secondary
        }
    }

    // MARK: - Actions

    private func deleteProjects(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(projects[index])
        }
    }
}

#Preview {
    ProjectListView()
        .modelContainer(for: Project.self, inMemory: true)
}
