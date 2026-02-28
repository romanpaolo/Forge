//
//  NewProjectView.swift
//  Forge
//
//  Sheet form for creating a new project (name + address + project type).
//  Phase 3: adds project type picker for trade-specific prompt templates.
//

import SwiftUI
import SwiftData

struct NewProjectView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var address = ""
    @State private var projectType: ProjectType = .general

    private var canCreate: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Project Details") {
                    TextField("Project Name", text: $name)
                        .textContentType(.organizationName)
                    TextField("Address (optional)", text: $address)
                        .textContentType(.fullStreetAddress)
                }

                Section {
                    Picker("Project Type", selection: $projectType) {
                        ForEach(ProjectType.allCases, id: \.self) { type in
                            Label(type.displayName, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                } header: {
                    Text("Project Type")
                } footer: {
                    Text("Used to customize the AI scope analysis for your specific project.")
                }
            }
            .navigationTitle("New Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { createProject() }
                        .disabled(!canCreate)
                }
            }
        }
    }

    private func createProject() {
        let project = Project(
            name: name.trimmingCharacters(in: .whitespaces),
            address: address.trimmingCharacters(in: .whitespaces),
            projectType: projectType
        )
        modelContext.insert(project)
        dismiss()
    }
}

#Preview {
    NewProjectView()
        .modelContainer(for: Project.self, inMemory: true)
}
