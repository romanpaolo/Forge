//
//  ProjectDetailView.swift
//  Forge
//
//  Shows project info, recording controls, and the list of saved recordings.
//  Feature 3: adds per-recording Transcribe button → calls ProcessModule.transcribe().
//

import SwiftUI
import SwiftData

struct ProjectDetailView: View {
    let project: Project

    @Environment(\.modelContext) private var modelContext
    @State private var captureModule = CaptureModule()
    @State private var processingIDs: Set<PersistentIdentifier> = []
    @State private var isStructuring = false
    @State private var errorMessage: String?
    @State private var showingError = false

    var body: some View {
        List {
            recordingControlSection
            recordingsSection
            scopeSection
            projectInfoSection
        }
        .navigationTitle(project.name)
        .navigationBarTitleDisplayMode(.large)
        .alert("Error", isPresented: $showingError) {
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
                    RecordingRow(
                        recording: recording,
                        isProcessing: processingIDs.contains(recording.id),
                        onTranscribe: { Task { await transcribeRecording(recording) } }
                    )
                }
                .onDelete(perform: deleteRecordings)
            }
        }
    }

    private var scopeSection: some View {
        Section("Scope Packet") {
            if isStructuring {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Generating scope…")
                        .foregroundStyle(.secondary)
                }
            } else if project.packets.isEmpty {
                if let transcript = firstAvailableTranscript {
                    Button {
                        Task { await generateScope(from: transcript) }
                    } label: {
                        Label("Generate Scope from Transcript",
                              systemImage: "doc.text.magnifyingglass")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    Text("Transcribe a recording first to generate a scope.")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
            } else {
                ForEach(project.packets) { packet in
                    NavigationLink(destination: ScopeReviewView(packet: packet)) {
                        PacketRow(packet: packet)
                    }
                }
                // Allow re-generating when new recordings are transcribed
                if let transcript = firstAvailableTranscript {
                    Button {
                        Task { await generateScope(from: transcript) }
                    } label: {
                        Label("Regenerate Scope",
                              systemImage: "arrow.clockwise")
                            .font(.caption)
                    }
                }
            }
        }
    }

    /// The transcript from the first recording that has one.
    private var firstAvailableTranscript: String? {
        project.recordings.first(where: { $0.transcript != nil })?.transcript
    }

    // MARK: - Recording actions

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

    // MARK: - Transcription

    private func transcribeRecording(_ recording: Recording) async {
        guard !processingIDs.contains(recording.id) else { return }
        processingIDs.insert(recording.id)
        defer { processingIDs.remove(recording.id) }
        do {
            let transcript = try await ProcessModule.transcribe(recording: recording)
            recording.transcript = transcript
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }

    // MARK: - Structuring

    private func generateScope(from transcript: String) async {
        guard !isStructuring else { return }
        isStructuring = true
        defer { isStructuring = false }
        do {
            let structured = try await ProcessModule.structure(transcript: transcript)

            let packet = ScopePacket(scopeSummary: structured.scopeSummary)
            modelContext.insert(packet)

            for task in structured.tasks {
                let t = TradeTask(
                    trade: task.trade,
                    taskDescription: task.taskDescription,
                    isQuestion: task.isQuestion
                )
                modelContext.insert(t)
                packet.tasksByTrade.append(t)
            }

            project.packets.append(packet)
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }

    // MARK: - Helpers

    private func formattedDuration(_ seconds: TimeInterval) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - PacketRow

private struct PacketRow: View {
    let packet: ScopePacket

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(packet.generatedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline.weight(.medium))
                Spacer()
                statusBadge
            }
            HStack(spacing: 12) {
                let total = packet.tasksByTrade.count
                let questions = packet.tasksByTrade.filter { $0.isQuestion }.count
                Label("\(total) tasks", systemImage: "checklist")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if questions > 0 {
                    Label("\(questions) questions", systemImage: "questionmark.circle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var statusBadge: some View {
        let (label, color): (String, Color) = switch packet.status {
        case .draft:    ("Draft",    .orange)
        case .approved: ("Approved", .green)
        case .exported: ("Exported", .blue)
        }
        return Text(label)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }
}

// MARK: - RecordingRow

private struct RecordingRow: View {
    let recording: Recording
    let isProcessing: Bool
    let onTranscribe: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(recording.capturedAt.formatted(date: .abbreviated, time: .shortened))
                .font(.subheadline.weight(.medium))

            HStack(alignment: .center) {
                Label(formattedDuration(recording.duration), systemImage: "waveform")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if isProcessing {
                    ProgressView()
                        .scaleEffect(0.8)
                } else if recording.transcript != nil {
                    Label("Transcribed", systemImage: "text.quote")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else {
                    Button("Transcribe", action: onTranscribe)
                        .font(.caption)
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                }
            }

            if let transcript = recording.transcript {
                let preview = transcript.prefix(120)
                Text(preview + (transcript.count > 120 ? "…" : ""))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
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
