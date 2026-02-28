//
//  ProjectDetailView.swift
//  Forge
//
//  Shows project info, recording controls, and the list of saved recordings.
//  Feature 3: per-recording Transcribe button → calls ProcessModule.transcribe()
//  Feature 4: Scope Packet section → calls ProcessModule.structure()
//  Phase 2:   Glasses photo capture, Bluetooth audio routing, voice-tag correlation
//

import SwiftUI
import SwiftData

struct ProjectDetailView: View {
    let project: Project

    @Environment(\.modelContext) private var modelContext
    @Environment(WearablesManager.self) private var wearablesManager

    @State private var captureModule = CaptureModule()
    @State private var processingIDs: Set<PersistentIdentifier> = []
    @State private var isStructuring = false
    @State private var errorMessage: String?
    @State private var showingError = false

    // The Recording object being actively recorded — used to attach glasses photos.
    @State private var activeRecording: Recording?

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

                    // Glasses photo capture button (visible only when streaming)
                    if wearablesManager.isStreaming {
                        Button {
                            wearablesManager.capturePhoto()
                        } label: {
                            Label("Capture Photo from Glasses", systemImage: "camera.circle.fill")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.blue)
                                .frame(maxWidth: .infinity)
                        }

                        HStack(spacing: 4) {
                            Image(systemName: "circle.fill")
                                .imageScale(.small)
                                .foregroundStyle(.green)
                            Text("\(wearablesManager.capturedPhotos.count) photo(s) captured")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

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
                    NavigationLink(destination: ScopeReviewView(packet: packet, project: project)) {
                        PacketRow(packet: packet)
                    }
                }
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

            // Start glasses streaming for photo capture (if registered and permitted).
            if wearablesManager.isRegistered && wearablesManager.hasCameraPermission {
                wearablesManager.startStreaming()
            }
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }

    private func stopRecording() async {
        // Stop glasses streaming first; photos are now in wearablesManager.capturedPhotos.
        if wearablesManager.isStreaming {
            await wearablesManager.stopStreaming()
        }

        do {
            let (url, duration) = try await captureModule.stopRecording()
            let recording = Recording(audioFileURL: url, duration: duration)
            modelContext.insert(recording)

            // Drain accumulated glasses photos into the new Recording.
            // Each photo is written to disk; only the URL is persisted in SwiftData.
            let pendingPhotos = wearablesManager.capturedPhotos
            wearablesManager.clearCapturedPhotos()
            for captured in pendingPhotos {
                do {
                    let url = try PhotoCapture.saveImage(captured.imageData)
                    let photo = PhotoCapture(imageFileURL: url, timestamp: captured.timestamp)
                    modelContext.insert(photo)
                    recording.photos.append(photo)
                } catch {
                    // Non-fatal: log and continue so the recording is still saved.
                    print("[PhotoCapture] Failed to save photo to disk: \(error)")
                }
            }

            project.recordings.append(recording)
            activeRecording = nil
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }

    private func deleteRecordings(at offsets: IndexSet) {
        for index in offsets {
            let recording = project.recordings[index]
            try? FileManager.default.removeItem(at: recording.audioFileURL)
            for photo in recording.photos {
                try? FileManager.default.removeItem(at: photo.imageFileURL)
            }
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

            // Feature 11: Correlate any voice-tagged photos to the new transcript.
            if !recording.photos.isEmpty {
                VoiceTagDetector.correlate(transcript: transcript, photos: recording.photos)
            }
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
            let structured = try await ProcessModule.structure(transcript: transcript, projectType: project.projectType)

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

                if !recording.photos.isEmpty {
                    Label("\(recording.photos.count) photo(s)", systemImage: "photo.on.rectangle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

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

            // Transcript preview
            if let transcript = recording.transcript {
                let preview = transcript.prefix(120)
                Text(preview + (transcript.count > 120 ? "…" : ""))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            // Photo thumbnails (glasses captures)
            if !recording.photos.isEmpty {
                photoThumbnailStrip
            }
        }
        .padding(.vertical, 2)
    }

    private var photoThumbnailStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(recording.photos) { photo in
                    photoThumbnail(for: photo)
                }
            }
        }
    }

    private func photoThumbnail(for photo: PhotoCapture) -> some View {
        ZStack(alignment: .bottomLeading) {
            if let uiImage = UIImage(contentsOfFile: photo.imageFileURL.path(percentEncoded: false)) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 64, height: 64)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.tertiary)
                    }
            }

            if let tag = photo.voiceTag {
                Text(tag)
                    .font(.system(size: 8, weight: .medium))
                    .lineLimit(2)
                    .padding(3)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .padding(2)
            }
        }
    }

    private func formattedDuration(_ seconds: TimeInterval) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return m > 0 ? "\(m)m \(s)s" : "\(s)s"
    }
}
