//
//  Persistence.swift
//  Forge
//
//  All SwiftData @Model types + supporting enums.
//  Phase 3: adds ProjectType for trade-specific prompt templates.
//

import SwiftData
import Foundation

// MARK: - PacketStatus

enum PacketStatus: String, Codable {
    case draft
    case approved
    case exported
}

// MARK: - ProjectType

enum ProjectType: String, Codable, CaseIterable {
    case general
    case bath
    case kitchen
    case adu
    case deck
    case addition
    case exterior

    var displayName: String {
        switch self {
        case .general:  return "General"
        case .bath:     return "Bathroom"
        case .kitchen:  return "Kitchen"
        case .adu:      return "ADU"
        case .deck:     return "Deck"
        case .addition: return "Addition"
        case .exterior: return "Exterior"
        }
    }

    var icon: String {
        switch self {
        case .general:  return "house"
        case .bath:     return "shower"
        case .kitchen:  return "fork.knife"
        case .adu:      return "building.2"
        case .deck:     return "square.dashed"
        case .addition: return "plus.app"
        case .exterior: return "paintbrush"
        }
    }

    /// Trade-specific guidance injected into the Claude structuring prompt.
    var promptGuidance: String {
        switch self {
        case .general:
            return "This is a general residential remodel. Cover all trades mentioned."
        case .bath:
            return """
                Bathroom remodel. Focus on: plumbing fixture locations and specs (toilet, \
                shower, tub, vanity sink), tile scope (floors, walls, shower surround), \
                vanity and mirror, lighting, exhaust fan, any structural changes (wall removal, \
                niche, curbless shower), waterproofing method, and permit requirements.
                """
        case .kitchen:
            return """
                Kitchen remodel. Focus on: cabinet layout and brand/style, appliance specs \
                (range type/size, dishwasher, refrigerator, microwave/hood), countertop \
                material and edge, backsplash, sink and faucet, plumbing connections, \
                electrical (circuits, outlets, under-cabinet lighting), any structural changes, \
                and permit requirements.
                """
        case .adu:
            return """
                ADU (accessory dwelling unit). Focus on: permitting and setback implications, \
                utility connections (separate meter vs. shared), foundation type, \
                full kitchen and bath scope, egress windows, fire separation, HVAC, \
                and any deed restriction or HOA considerations mentioned.
                """
        case .deck:
            return """
                Deck project. Focus on: footings and post type (concrete, helical piers), \
                framing and ledger attachment to house, decking material and profile, \
                railing type and code-required height, stairs and landing, any pergola \
                or cover, electrical (lighting, outlets), and permit requirements.
                """
        case .addition:
            return """
                Room addition. Focus on: foundation type and scope, framing and roofline \
                integration, exterior envelope (siding, windows, doors, roofing), \
                insulation and weatherproofing, HVAC extension or new unit, \
                electrical panel capacity and new circuits, plumbing if applicable, \
                and permit/engineering requirements.
                """
        case .exterior:
            return """
                Exterior project. Focus on: siding material and scope (full replace vs. repair), \
                paint scope (prep, primer, coats, surfaces), windows and doors \
                (size, brand, finish), roofing (material, decking condition, flashing), \
                gutters and downspouts, trim and fascia, any landscaping or concrete impact.
                """
        }
    }
}

// MARK: - SwiftData Models

@Model
final class Project {
    var name: String
    var address: String
    var projectType: ProjectType
    var createdAt: Date
    @Relationship(deleteRule: .cascade) var recordings: [Recording]
    @Relationship(deleteRule: .cascade) var packets: [ScopePacket]

    init(name: String, address: String, projectType: ProjectType = .general) {
        self.name = name
        self.address = address
        self.projectType = projectType
        self.createdAt = Date()
        self.recordings = []
        self.packets = []
    }
}

@Model
final class Recording {
    var audioFileURL: URL
    @Relationship(deleteRule: .cascade) var photos: [PhotoCapture]
    var transcript: String?
    var duration: TimeInterval
    var capturedAt: Date
    /// `true` while the device is offline and transcription is pending.
    /// Cleared once transcription succeeds or is cancelled.
    var isTranscriptionQueued: Bool

    init(audioFileURL: URL, duration: TimeInterval = 0) {
        self.audioFileURL = audioFileURL
        self.photos = []
        self.transcript = nil
        self.duration = duration
        self.capturedAt = Date()
        self.isTranscriptionQueued = false
    }
}

@Model
final class PhotoCapture {
    /// Path to the JPEG on disk — stored as a URL so SwiftData doesn't embed
    /// binary blobs in its SQLite store.
    var imageFileURL: URL
    var voiceTag: String?
    /// Seconds elapsed since the recording started when this photo was captured.
    var timestamp: TimeInterval

    init(imageFileURL: URL, voiceTag: String? = nil, timestamp: TimeInterval) {
        self.imageFileURL = imageFileURL
        self.voiceTag = voiceTag
        self.timestamp = timestamp
    }

    /// Writes JPEG data to `Documents/Photos/<UUID>.jpg` and returns the URL.
    static func saveImage(_ data: Data) throws -> URL {
        let dir = URL.documentsDirectory.appendingPathComponent("Photos", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("\(UUID().uuidString).jpg")
        try data.write(to: url, options: .atomic)
        return url
    }
}

@Model
final class ScopePacket {
    var scopeSummary: String
    @Relationship(deleteRule: .cascade) var tasksByTrade: [TradeTask]
    var status: PacketStatus
    var generatedAt: Date

    init(scopeSummary: String) {
        self.scopeSummary = scopeSummary
        self.tasksByTrade = []
        self.status = .draft
        self.generatedAt = Date()
    }
}

@Model
final class TradeTask {
    var trade: String
    var taskDescription: String
    var isQuestion: Bool
    var isApproved: Bool

    init(trade: String, taskDescription: String, isQuestion: Bool = false) {
        self.trade = trade
        self.taskDescription = taskDescription
        self.isQuestion = isQuestion
        self.isApproved = false
    }
}
