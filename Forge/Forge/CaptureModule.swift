//
//  CaptureModule.swift
//  Forge
//
//  Wraps AVAudioEngine to record job-walk audio from the iPhone mic.
//  Writes AAC-encoded .m4a files to the app's Documents/Recordings directory.
//  Feature 2 — iPhone fallback path; Bluetooth glasses path added in Feature 9.
//

import AVFoundation
import Observation

// MARK: - State

enum CaptureState: Equatable {
    case idle
    case recording
    case stopping
}

// MARK: - Errors

enum CaptureError: LocalizedError {
    case permissionDenied
    case notRecording
    case noOutputFile

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            "Microphone access is required. Please enable it in Settings → Privacy → Microphone."
        case .notRecording:
            "No active recording to stop."
        case .noOutputFile:
            "The recording file could not be located."
        }
    }
}

// MARK: - CaptureModule

@Observable
final class CaptureModule {

    // MARK: Published state

    private(set) var captureState: CaptureState = .idle
    private(set) var elapsedSeconds: TimeInterval = 0

    var isRecording: Bool { captureState == .recording }

    // MARK: Private

    private var engine: AVAudioEngine?
    private var currentFileURL: URL?
    private var recordingStart: Date?
    private var elapsedTimer: Timer?

    // MARK: - Permission

    func requestMicrophonePermission() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    // MARK: - Recording

    /// Configures AVAudioSession, installs a tap on the input node, and starts the engine.
    /// Writes audio as AAC into a new .m4a file in Documents/Recordings/.
    func startRecording() async throws {
        guard captureState == .idle else { return }

        // Activate audio session for recording
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .default, options: [])
        try session.setActive(true)

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        // outputFormat on bus 0 is what the input node produces (native hardware PCM)
        let inputFormat = inputNode.outputFormat(forBus: 0)

        let recordingURL = Self.newRecordingURL()

        // Match the hardware sample rate and channel count so AVAudioFile
        // doesn't need to resample; it encodes PCM → AAC on write.
        let fileSettings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: inputFormat.sampleRate,
            AVNumberOfChannelsKey: inputFormat.channelCount,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]

        let audioFile = try AVAudioFile(forWriting: recordingURL, settings: fileSettings)

        // Capture audioFile as a local constant so the tap closure avoids
        // crossing actor isolation boundaries — AVAudioFile.write is thread-safe.
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { buffer, _ in
            try? audioFile.write(from: buffer)
        }

        try engine.start()

        self.engine = engine
        self.currentFileURL = recordingURL
        self.recordingStart = Date()
        captureState = .recording
        startElapsedTimer()
    }

    /// Removes the tap, stops the engine, deactivates the session, and returns
    /// the completed file URL + duration.
    func stopRecording() async throws -> (url: URL, duration: TimeInterval) {
        guard captureState == .recording, let engine else {
            throw CaptureError.notRecording
        }

        captureState = .stopping
        stopElapsedTimer()

        let duration = Date().timeIntervalSince(recordingStart ?? Date())

        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        self.engine = nil

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        guard let url = currentFileURL else {
            captureState = .idle
            throw CaptureError.noOutputFile
        }

        currentFileURL = nil
        recordingStart = nil
        captureState = .idle

        return (url: url, duration: duration)
    }

    // MARK: - Private helpers

    private func startElapsedTimer() {
        elapsedSeconds = 0
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self, let start = self.recordingStart else { return }
                self.elapsedSeconds = Date().timeIntervalSince(start)
            }
        }
    }

    private func stopElapsedTimer() {
        elapsedTimer?.invalidate()
        elapsedTimer = nil
        elapsedSeconds = 0
    }

    private static func newRecordingURL() -> URL {
        let dir = URL.documentsDirectory.appendingPathComponent("Recordings", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("recording-\(UUID().uuidString).m4a")
    }
}
