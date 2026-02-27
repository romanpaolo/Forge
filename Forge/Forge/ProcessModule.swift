//
//  ProcessModule.swift
//  Forge
//
//  Sends audio recordings to Claude and returns transcripts.
//  Feature 3: transcription only (audio → raw text).
//  Feature 4 will extend this with structured scope + task parsing.
//
//  Uses URLSession directly — no extra SPM dependency needed.
//  API reference: https://docs.anthropic.com/en/api/messages
//

import Foundation

// MARK: - ProcessModule

enum ProcessModule {

    private static let messagesURL = URL(string: "https://api.anthropic.com/v1/messages")!
    private static let model = "claude-sonnet-4-5"
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
        Transcribe this job-walk recording verbatim. \
        Return only the spoken words with no commentary, preamble, or formatting. \
        If no intelligible speech is present, return exactly: [No speech detected]
        """
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
        }
    }
}
