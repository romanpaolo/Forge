//
//  NewProjectView.swift
//  Forge
//
//  Sheet form for creating a new project (name + address).
//

import SwiftUI
import SwiftData

struct NewProjectView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var address = ""

    private var canCreate: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Project Details") {
                    TextField("Project Name", text: $name)
                        .textContentType(.organizationName)
                    TextField("Address", text: $address)
                        .textContentType(.fullStreetAddress)
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
            address: address.trimmingCharacters(in: .whitespaces)
        )
        modelContext.insert(project)
        dismiss()
    }
}

#Preview {
    NewProjectView()
        .modelContainer(for: Project.self, inMemory: true)
}
