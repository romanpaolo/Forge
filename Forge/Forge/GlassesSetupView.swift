//
//  GlassesSetupView.swift
//  Forge
//
//  Phase 2, Feature 7: Onboarding and status sheet for Ray-Ban Meta glasses.
//  Handles registration, camera permission, and connected device display.
//

import SwiftUI
import MWDATCore

struct GlassesSetupView: View {
    @Environment(WearablesManager.self) private var manager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                registrationSection
                if manager.isRegistered {
                    cameraPermissionSection
                    devicesSection
                }
            }
            .navigationTitle("Ray-Ban Meta Glasses")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Error", isPresented: .constant(manager.lastError != nil)) {
                Button("OK") {}
            } message: {
                Text(manager.lastError ?? "")
            }
        }
        .task {
            await manager.checkCameraPermission()
        }
    }

    // MARK: - Sections

    private var registrationSection: some View {
        Section {
            switch manager.registrationState {
            case .unavailable:
                Label("Meta AI app not installed", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                Text("Install the Meta AI app and pair your Ray-Ban Meta glasses, then return here to connect.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

            case .available:
                VStack(alignment: .leading, spacing: 8) {
                    Label("Ready to connect", systemImage: "glasses")
                        .foregroundStyle(.secondary)
                    Button("Connect Glasses") {
                        Task { await manager.startRegistration() }
                    }
                    .buttonStyle(.borderedProminent)
                }

            case .registering:
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Connecting to Meta AI app…")
                        .foregroundStyle(.secondary)
                }

            case .registered:
                Label("Connected", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        } header: {
            Text("Registration")
        } footer: {
            if manager.registrationState == .available {
                Text("You'll be redirected to the Meta AI app to authorize ScopeSnap.")
            }
        }
    }

    private var cameraPermissionSection: some View {
        Section("Camera Access") {
            switch manager.cameraPermission {
            case .granted:
                Label("Camera access granted", systemImage: "camera.fill")
                    .foregroundStyle(.green)

            case .denied:
                VStack(alignment: .leading, spacing: 8) {
                    Label("Camera access required", systemImage: "camera.badge.exclamationmark")
                        .foregroundStyle(.orange)
                    Button("Allow Camera Access") {
                        Task { await manager.requestCameraPermission() }
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private var devicesSection: some View {
        Section("Paired Devices") {
            if manager.connectedDevices.isEmpty {
                Text("No glasses detected nearby.")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            } else {
                ForEach(manager.connectedDevices, id: \.self) { deviceId in
                    Label(deviceId, systemImage: "glasses")
                        .font(.subheadline)
                }
            }
        }
    }
}
