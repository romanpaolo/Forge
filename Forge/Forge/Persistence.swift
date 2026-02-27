//
//  Persistence.swift
//  Forge
//
//  Migrated from CoreData to SwiftData.
//  All five @Model types + PacketStatus enum live here.
//

import SwiftData
import Foundation

// MARK: - Supporting Types

enum PacketStatus: String, Codable {
    case draft
    case approved
    case exported
}

// MARK: - SwiftData Models

@Model
final class Project {
    var name: String
    var address: String
    var createdAt: Date
    @Relationship(deleteRule: .cascade) var recordings: [Recording]
    @Relationship(deleteRule: .cascade) var packets: [ScopePacket]

    init(name: String, address: String) {
        self.name = name
        self.address = address
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

    init(audioFileURL: URL, duration: TimeInterval = 0) {
        self.audioFileURL = audioFileURL
        self.photos = []
        self.transcript = nil
        self.duration = duration
        self.capturedAt = Date()
    }
}

@Model
final class PhotoCapture {
    var imageData: Data
    var voiceTag: String?
    var timestamp: TimeInterval

    init(imageData: Data, voiceTag: String? = nil, timestamp: TimeInterval) {
        self.imageData = imageData
        self.voiceTag = voiceTag
        self.timestamp = timestamp
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
