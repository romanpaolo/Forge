//
//  ProjectDetailView.swift
//  Forge
//
//  Shows project metadata and a placeholder recordings section.
//  Will be expanded in Feature 2 (AVAudioEngine recording).
//

import SwiftUI

struct ProjectDetailView: View {
    let project: Project

    var body: some View {
        List {
            Section("Project Info") {
                LabeledContent("Name", value: project.name)
                if !project.address.isEmpty {
                    LabeledContent("Address", value: project.address)
                }
                LabeledContent(
                    "Created",
                    value: project.createdAt.formatted(date: .abbreviated, time: .shortened)
                )
            }

            Section("Recordings") {
                if project.recordings.isEmpty {
                    Text("No recordings yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(project.recordings) { recording in
                        LabeledContent(
                            recording.capturedAt.formatted(date: .abbreviated, time: .shortened),
                            value: recording.duration > 0
                                ? "\(Int(recording.duration))s"
                                : "—"
                        )
                    }
                }
            }
        }
        .navigationTitle(project.name)
        .navigationBarTitleDisplayMode(.large)
    }
}
