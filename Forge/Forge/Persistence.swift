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
