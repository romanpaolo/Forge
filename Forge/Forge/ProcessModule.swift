//
//  ProcessModule.swift
//  Forge
//
//  Feature 3: transcribe(recording:) — audio → raw transcript.
//  Feature 4: structure(transcript:) — transcript → StructuredScope (scope summary + trade tasks).
//
//  Uses URLSession directly — no extra SPM dependency needed.
//  API reference: https://docs.anthropic.com/en/api/messages
//

import Foundation

// MARK: - ProcessModule

enum ProcessModule {

    private static let messagesURL = URL(string: "https://api.anthropic.com/v1/messages")!
    private static let model = "claude-sonnet-4-6"
    private static let anthropicVersion = "2023-06-01"

    // MARK: - Public API

    /// Sends `recording.audioFileURL` to Claude as base64 and returns the verbatim transcript.
    /// Saves nothing — callers are responsible for persisting `recording.transcript`.
    static func transcribe(recording: Recording) async throws -> String {
        guard let apiKey = KeychainHelper.loadAPIKey(), !apiKey.isEmpty else {
            throw ProcessError.noAPIKey
        }
        guard FileManager.default.fileExists(atPath: recording.audioFileURL.path(percentEncoded: false)) else {
            throw ProcessError.audioFileNotFound
        }

        let audioData = try Data(contentsOf: recording.audioFileURL)
        let audioBase64 = audioData.base64EncodedString()

        let body = AnthropicRequest(
            model: model,
            maxTokens: 2048,
            messages: [
                AnthropicMessage(role: "user", content: [
                    AnthropicContent(text: transcriptionPrompt),
                    AnthropicContent(audioBase64: audioBase64, mediaType: "audio/mp4"),
                ])
            ]
        )

        let urlRequest = try makeURLRequest(apiKey: apiKey, body: body)
        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let http = response as? HTTPURLResponse else {
            throw ProcessError.invalidResponse
        }
        guard http.statusCode == 200 else {
            let detail = String(data: data, encoding: .utf8) ?? "no body"
            throw ProcessError.apiError(http.statusCode, detail)
        }

        let decoded = try JSONDecoder().decode(AnthropicResponse.self, from: data)
        guard let text = decoded.content.first(where: { $0.type == "text" })?.text,
              !text.isEmpty else {
            throw ProcessError.emptyResponse
        }

        return text
    }

    // MARK: - Private helpers

    private static func makeURLRequest<T: Encodable>(apiKey: String, body: T) throws -> URLRequest {
        var req = URLRequest(url: messagesURL)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue(anthropicVersion, forHTTPHeaderField: "anthropic-version")
        req.httpBody = try JSONEncoder().encode(body)
        return req
    }

    private static let transcriptionPrompt = """
        Transcribe this job-walk recording verbatim. Return only the spoken words — \
        no commentary, preamble, summary, or formatting. Preserve filler words and \
        natural speech patterns. Transcribe construction terms, trade names, material \
        specs, and measurements exactly as spoken. \
        If no intelligible speech is present, return exactly: [No speech detected]
        """

    // MARK: - Structuring

    /// Sends a completed transcript to Claude and returns a parsed StructuredScope
    /// containing a prose scope summary and a flat list of trade tasks.
    /// Callers are responsible for persisting the result as SwiftData models.
    static func structure(transcript: String, projectType: ProjectType = .general) async throws -> StructuredScope {
        guard let apiKey = KeychainHelper.loadAPIKey(), !apiKey.isEmpty else {
            throw ProcessError.noAPIKey
        }
        guard !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ProcessError.emptyResponse
        }

        let body = AnthropicRequest(
            model: model,
            maxTokens: 4096,
            messages: [
                AnthropicMessage(role: "user", content: [
                    AnthropicContent(text: structuringPrompt(for: transcript, projectType: projectType)),
                ])
            ]
        )

        let urlRequest = try makeURLRequest(apiKey: apiKey, body: body)
        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let http = response as? HTTPURLResponse else {
            throw ProcessError.invalidResponse
        }
        guard http.statusCode == 200 else {
            let detail = String(data: data, encoding: .utf8) ?? "no body"
            throw ProcessError.apiError(http.statusCode, detail)
        }

        let decoded = try JSONDecoder().decode(AnthropicResponse.self, from: data)
        guard let text = decoded.content.first(where: { $0.type == "text" })?.text,
              !text.isEmpty else {
            throw ProcessError.emptyResponse
        }

        return try parseStructuredScope(from: text)
    }

    // MARK: - Structuring helpers

    private static func structuringPrompt(for transcript: String, projectType: ProjectType) -> String {
        """
        You are an expert construction scope analyst specializing in residential remodeling. \
        Your job is to turn raw job-walk notes into actionable scope documents that PMs and \
        subcontractors can work from immediately.

        PROJECT TYPE: \(projectType.displayName)
        CONTEXT: \(projectType.promptGuidance)

        TRANSCRIPT:
        ---
        \(transcript)
        ---

        Return ONLY a valid JSON object — no markdown fences, no commentary, no extra text:

        {
          "scope_summary": "Detailed prose scope organized by area (e.g. master bath, kitchen, \
        exterior). For each area include: (1) what was decided or confirmed, \
        (2) open questions that must be resolved before work begins, \
        (3) any risks, concerns, or items to verify on site. Use \\n for line breaks.",
          "tasks_by_trade": [
            {"trade": "demo", "description": "Remove existing tile — master bath floor and walls to \
        backer board", "is_question": false},
            {"trade": "plumbing", "description": "Confirm toilet relocation — unclear from walkthrough \
        whether drain can move 12 inches east", "is_question": true}
          ]
        }

        Valid trade values: demo, framing, plumbing, electrical, HVAC, drywall, tile, paint, \
        carpentry, flooring, roofing, windows, doors, other.

        RULES:
        - Never guess or invent details not present in the transcript.
        - If something is unclear or needs confirmation before work begins, set is_question to true.
        - Each task must be specific enough that a subcontractor knows exactly what to bid.
        - scope_summary must be a single JSON string value (use \\n for newlines).
        - Return ONLY the JSON object — nothing before or after it.
        """
    }

    private static func parseStructuredScope(from rawText: String) throws -> StructuredScope {
        let cleaned = strippingMarkdownFences(from: rawText)
        guard let jsonData = cleaned.data(using: .utf8) else {
            throw ProcessError.malformedJSON("Response could not be decoded as UTF-8.")
        }
        do {
            let dto = try JSONDecoder().decode(ClaudeStructuredResponse.self, from: jsonData)
            let tasks = dto.tasksByTrade.map {
                StructuredScope.Task(trade: $0.trade,
                                     taskDescription: $0.description,
                                     isQuestion: $0.isQuestion)
            }
            return StructuredScope(scopeSummary: dto.scopeSummary, tasks: tasks)
        } catch {
            throw ProcessError.malformedJSON(error.localizedDescription)
        }
    }

    /// Strips leading/trailing markdown code fences that Claude sometimes adds.
    private static func strippingMarkdownFences(from text: String) -> String {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("```") {
            // Drop the opening fence line (e.g. "```json\n")
            if let nl = s.firstIndex(of: "\n") {
                s = String(s[s.index(after: nl)...])
            }
        }
        if s.hasSuffix("```") {
            s = String(s.dropLast(3))
        }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - StructuredScope (returned by ProcessModule.structure)

/// Value type produced by ProcessModule.structure(transcript:).
/// Callers convert this into ScopePacket + TradeTask SwiftData objects.
struct StructuredScope {
    let scopeSummary: String
    let tasks: [Task]

    struct Task {
        let trade: String
        let taskDescription: String
        let isQuestion: Bool
    }
}

// MARK: - Claude JSON DTO (file-private)

private struct ClaudeStructuredResponse: Decodable {
    let scopeSummary: String
    let tasksByTrade: [TaskDTO]

    struct TaskDTO: Decodable {
        let trade: String
        let description: String
        let isQuestion: Bool

        enum CodingKeys: String, CodingKey {
            case trade
            case description
            case isQuestion = "is_question"
        }
    }

    enum CodingKeys: String, CodingKey {
        case scopeSummary = "scope_summary"
        case tasksByTrade = "tasks_by_trade"
    }
}

// MARK: - Request types (file-private)

private struct AnthropicRequest: Encodable {
    let model: String
    let maxTokens: Int
    let messages: [AnthropicMessage]

    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case messages
    }
}

private struct AnthropicMessage: Encodable {
    let role: String
    let content: [AnthropicContent]
}

private struct AnthropicContent: Encodable {
    let type: String
    let text: String?
    let source: AnthropicSource?

    /// Text content block.
    init(text: String) {
        self.type = "text"
        self.text = text
        self.source = nil
    }

    /// Audio / document content block.
    init(audioBase64: String, mediaType: String) {
        self.type = "document"
        self.text = nil
        self.source = AnthropicSource(type: "base64", mediaType: mediaType, data: audioBase64)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(type, forKey: .type)
        try c.encodeIfPresent(text, forKey: .text)
        try c.encodeIfPresent(source, forKey: .source)
    }

    enum CodingKeys: String, CodingKey { case type, text, source }
}

private struct AnthropicSource: Encodable {
    let type: String
    let mediaType: String
    let data: String

    enum CodingKeys: String, CodingKey {
        case type
        case mediaType = "media_type"
        case data
    }
}

// MARK: - Response types (file-private)

private struct AnthropicResponse: Decodable {
    let content: [ContentBlock]

    struct ContentBlock: Decodable {
        let type: String
        let text: String?
    }
}

// MARK: - ProcessError

enum ProcessError: LocalizedError {
    case noAPIKey
    case audioFileNotFound
    case invalidResponse
    case apiError(Int, String)
    case emptyResponse
    case malformedJSON(String)

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            "No Anthropic API key found. Tap the gear icon to add your key."
        case .audioFileNotFound:
            "The audio file could not be found on disk."
        case .invalidResponse:
            "Received an invalid response from the Claude API."
        case .apiError(let code, let detail):
            "Claude API error \(code): \(detail)"
        case .emptyResponse:
            "Claude returned an empty response."
        case .malformedJSON(let detail):
            "Could not parse Claude's JSON response: \(detail)"
        }
    }
}
