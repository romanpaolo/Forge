//
//  ProjectListView.swift
//  Forge
//
//  Shows all saved projects and a button to create a new one.
//

import SwiftUI
import SwiftData

struct ProjectListView: View {
    @Query(sort: \Project.createdAt, order: .reverse) private var projects: [Project]
    @Environment(\.modelContext) private var modelContext
    @State private var showingNewProject = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(projects) { project in
                    NavigationLink(destination: ProjectDetailView(project: project)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(project.name)
                                .font(.headline)
                            if !project.address.isEmpty {
                                Text(project.address)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Text(project.createdAt.formatted(date: .abbreviated, time: .shortened))
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
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingNewProject = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
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
    }

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
