//
//  ProjectDetailView.swift
//  Forge
//
//  Shows project info, recording controls, and the list of saved recordings.
//

import SwiftUI
import SwiftData

struct ProjectDetailView: View {
    let project: Project

    @Environment(\.modelContext) private var modelContext
    @State private var captureModule = CaptureModule()
    @State private var errorMessage: String?
    @State private var showingError = false

    var body: some View {
        List {
            recordingControlSection
            projectInfoSection
            recordingsSection
        }
        .navigationTitle(project.name)
        .navigationBarTitleDisplayMode(.large)
        .alert("Recording Error", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "An unknown error occurred.")
        }
    }

    // MARK: - Sections

    private var recordingControlSection: some View {
        Section {
            if captureModule.isRecording {
                VStack(spacing: 16) {
                    // Live elapsed time
                    Text(formattedDuration(captureModule.elapsedSeconds))
                        .font(.system(.largeTitle, design: .monospaced).weight(.semibold))
                        .foregroundStyle(.red)
                        .contentTransition(.numericText())
                        .animation(.default, value: captureModule.elapsedSeconds)

                    Button {
                        Task { await stopRecording() }
                    } label: {
                        Label("Stop Recording", systemImage: "stop.circle.fill")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, 8)
            } else {
                Button {
                    Task { await startRecording() }
                } label: {
                    Label("Start Recording", systemImage: "mic.circle.fill")
                        .font(.title2.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .disabled(captureModule.captureState == .stopping)
            }
        }
    }

    private var projectInfoSection: some View {
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
    }

    private var recordingsSection: some View {
        Section("Recordings") {
            if project.recordings.isEmpty {
                Text("No recordings yet — tap Start Recording above.")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            } else {
                ForEach(project.recordings) { recording in
                    RecordingRow(recording: recording)
                }
                .onDelete(perform: deleteRecordings)
            }
        }
    }

    // MARK: - Actions

    private func startRecording() async {
        let granted = await captureModule.requestMicrophonePermission()
        guard granted else {
            errorMessage = CaptureError.permissionDenied.localizedDescription
            showingError = true
            return
        }
        do {
            try await captureModule.startRecording()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }

    private func stopRecording() async {
        do {
            let (url, duration) = try await captureModule.stopRecording()
            let recording = Recording(audioFileURL: url, duration: duration)
            modelContext.insert(recording)
            project.recordings.append(recording)
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }

    private func deleteRecordings(at offsets: IndexSet) {
        for index in offsets {
            let recording = project.recordings[index]
            try? FileManager.default.removeItem(at: recording.audioFileURL)
            modelContext.delete(recording)
        }
        project.recordings.remove(atOffsets: offsets)
    }

    // MARK: - Helpers

    private func formattedDuration(_ seconds: TimeInterval) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - RecordingRow

private struct RecordingRow: View {
    let recording: Recording

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(recording.capturedAt.formatted(date: .abbreviated, time: .shortened))
                .font(.subheadline.weight(.medium))
            HStack {
                Label(formattedDuration(recording.duration), systemImage: "waveform")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if recording.transcript != nil {
                    Spacer()
                    Label("Transcribed", systemImage: "text.quote")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func formattedDuration(_ seconds: TimeInterval) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return m > 0 ? "\(m)m \(s)s" : "\(s)s"
    }
}
