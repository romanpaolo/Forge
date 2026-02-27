//
//  ContentView.swift
//  Forge
//
//  Created by Roman Pascua on 2/26/26.
//

import SwiftUI
import CoreData
import MWDATCore
import MWDATCamera

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @State private var registrationState: RegistrationState = .unavailable
    @State private var deviceIdentifiers: [DeviceIdentifier] = []
    @State private var isStreaming = false
    @State private var streamSession: StreamSession?
    @State private var streamState: StreamSessionState = .stopped
    @State private var stateListenerToken: (any AnyListenerToken)?
    @State private var errorMessage: String?

    private var isRegistered: Bool {
        registrationState == .registered
    }

    var body: some View {
        NavigationView {
            List {
                Section("Wearables Status") {
                    HStack {
                        Text("Registration")
                        Spacer()
                        Text(registrationState.description)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Devices")
                        Spacer()
                        Text(deviceIdentifiers.isEmpty ? "None" : "\(deviceIdentifiers.count) found")
                            .foregroundStyle(.secondary)
                    }

                    if isStreaming {
                        HStack {
                            Text("Stream")
                            Spacer()
                            Text("\(streamState)")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Actions") {
                    if !isRegistered {
                        Button("Register with Meta AI") {
                            Task { await register() }
                        }
                    } else {
                        Button("Unregister") {
                            Task { await unregister() }
                        }
                        .foregroundStyle(.red)
                    }

                    if isRegistered && !deviceIdentifiers.isEmpty {
                        Button(isStreaming ? "Stop Streaming" : "Start Streaming") {
                            if isStreaming {
                                Task { await stopStreaming() }
                            } else {
                                startStreaming()
                            }
                        }

                        if isStreaming {
                            Button("Capture Photo") {
                                capturePhoto()
                            }
                        }
                    }
                }

                if !deviceIdentifiers.isEmpty {
                    Section("Connected Devices") {
                        ForEach(deviceIdentifiers, id: \.self) { identifier in
                            let device = Wearables.shared.deviceForIdentifier(identifier)
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(device?.nameOrId() ?? identifier)
                                        .font(.headline)
                                    Text(device?.deviceType().rawValue ?? "Unknown")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Circle()
                                    .fill(device?.linkState == .connected ? .green : .gray)
                                    .frame(width: 10, height: 10)
                            }
                        }
                    }
                }

                if let errorMessage {
                    Section("Error") {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Forge")
        }
        .task {
            for await state in Wearables.shared.registrationStateStream() {
                registrationState = state
            }
        }
        .task {
            for await devices in Wearables.shared.devicesStream() {
                deviceIdentifiers = devices
            }
        }
    }

    private func register() async {
        do {
            try await Wearables.shared.startRegistration()
            errorMessage = nil
        } catch {
            errorMessage = "Registration failed: \(error)"
        }
    }

    private func unregister() async {
        do {
            try await Wearables.shared.startUnregistration()
            await stopStreaming()
            errorMessage = nil
        } catch {
            errorMessage = "Unregistration failed: \(error)"
        }
    }

    private func startStreaming() {
        let deviceSelector = AutoDeviceSelector(wearables: Wearables.shared)
        let config = StreamSessionConfig()
        let session = StreamSession(streamSessionConfig: config, deviceSelector: deviceSelector)
        streamSession = session
        isStreaming = true
        errorMessage = nil

        stateListenerToken = session.statePublisher.listen { state in
            Task { @MainActor in
                streamState = state
            }
        }

        Task {
            await session.start()
        }
    }

    private func stopStreaming() async {
        if let token = stateListenerToken {
            await token.cancel()
            stateListenerToken = nil
        }
        if let session = streamSession {
            await session.stop()
        }
        streamSession = nil
        isStreaming = false
        streamState = .stopped
    }

    private func capturePhoto() {
        streamSession?.capturePhoto(format: .jpeg)
    }
}

#Preview {
    ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
