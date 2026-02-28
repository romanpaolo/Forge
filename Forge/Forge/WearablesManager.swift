//
//  WearablesManager.swift
//  Forge
//
//  Phase 2, Feature 7: Manages registration state, device discovery, streaming
//  lifecycle, and photo capture from Ray-Ban Meta glasses.
//
//  Feature 8: Photo capture via StreamSession.capturePhoto(format:)
//

import MWDATCore
import MWDATCamera
import Foundation

@Observable
@MainActor
final class WearablesManager {

    // MARK: - Observed state

    private(set) var registrationState: RegistrationState = .unavailable
    private(set) var streamState: StreamSessionState = .stopped
    private(set) var cameraPermission: PermissionStatus = .denied
    private(set) var connectedDevices: [DeviceIdentifier] = []
    private(set) var lastError: String?

    /// Photos accumulated during the current recording session.
    /// Callers drain this array (via `clearCapturedPhotos()`) when recording stops.
    private(set) var capturedPhotos: [(imageData: Data, timestamp: TimeInterval)] = []

    // MARK: - Private

    private var streamSession: StreamSession?
    private var streamingStart: Date?

    private var registrationToken: (any AnyListenerToken)?
    private var devicesToken: (any AnyListenerToken)?
    private var stateToken: (any AnyListenerToken)?
    private var photoToken: (any AnyListenerToken)?
    private var errorToken: (any AnyListenerToken)?

    // MARK: - Init

    init() {
        let w = Wearables.shared
        registrationState = w.registrationState
        connectedDevices = w.devices

        registrationToken = w.addRegistrationStateListener { state in
            Task { @MainActor [weak self] in
                self?.registrationState = state
            }
        }

        devicesToken = w.addDevicesListener { devices in
            Task { @MainActor [weak self] in
                self?.connectedDevices = devices
            }
        }
    }

    // MARK: - Computed

    var isRegistered: Bool { registrationState == .registered }
    var isStreaming: Bool { streamState == .streaming }
    var hasDevice: Bool { !connectedDevices.isEmpty }
    var hasCameraPermission: Bool { cameraPermission == .granted }

    // MARK: - Registration

    func startRegistration() async {
        lastError = nil
        do {
            try await Wearables.shared.startRegistration()
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Camera permission

    func checkCameraPermission() async {
        do {
            cameraPermission = try await Wearables.shared.checkPermissionStatus(.camera)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func requestCameraPermission() async {
        do {
            cameraPermission = try await Wearables.shared.requestPermission(.camera)
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Streaming

    /// Starts a StreamSession using auto device selection.
    /// Photos received via `photoDataPublisher` are appended to `capturedPhotos`.
    func startStreaming() {
        guard streamSession == nil else { return }
        lastError = nil
        streamingStart = Date()

        let selector = AutoDeviceSelector(wearables: Wearables.shared)
        let session = StreamSession(deviceSelector: selector)

        stateToken = session.statePublisher.listen { state in
            Task { @MainActor [weak self] in
                self?.streamState = state
            }
        }

        photoToken = session.photoDataPublisher.listen { photo in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let elapsed = Date().timeIntervalSince(self.streamingStart ?? Date())
                self.capturedPhotos.append((imageData: photo.data, timestamp: elapsed))
            }
        }

        errorToken = session.errorPublisher.listen { err in
            Task { @MainActor [weak self] in
                self?.lastError = Self.describe(err)
            }
        }

        streamSession = session
        Task { await session.start() }
    }

    /// Stops the StreamSession and cancels all stream-specific listener tokens.
    func stopStreaming() async {
        guard let session = streamSession else { return }
        await session.stop()
        await stateToken?.cancel()
        await photoToken?.cancel()
        await errorToken?.cancel()
        stateToken = nil
        photoToken = nil
        errorToken = nil
        streamSession = nil
        streamingStart = nil
        streamState = .stopped
    }

    // MARK: - Photo capture

    /// Triggers an immediate photo capture from the connected glasses.
    /// The captured photo arrives asynchronously via `capturedPhotos`.
    /// Returns `false` if no stream session is active.
    @discardableResult
    func capturePhoto() -> Bool {
        streamSession?.capturePhoto(format: .jpeg) ?? false
    }

    /// Removes all accumulated photos. Call after draining `capturedPhotos`.
    func clearCapturedPhotos() {
        capturedPhotos.removeAll()
    }

    // MARK: - Private helpers

    private static func describe(_ error: StreamSessionError) -> String {
        switch error {
        case .internalError:                 return "Internal glasses stream error."
        case .deviceNotFound(let id):        return "Device not found: \(id)"
        case .deviceNotConnected(let id):    return "Device disconnected: \(id)"
        case .timeout:                       return "Glasses stream connection timed out."
        case .videoStreamingError:           return "Video stream error."
        case .audioStreamingError:           return "Glasses audio stream error."
        case .permissionDenied:              return "Camera permission denied by glasses."
        case .hingesClosed:                  return "Glasses hinges are closed — open them to stream."
        }
    }
}
