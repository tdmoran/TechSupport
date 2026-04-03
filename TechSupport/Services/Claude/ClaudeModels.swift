import Foundation

enum ClaudeModel: String, CaseIterable, Codable, Identifiable, Sendable {
    case haiku = "claude-haiku-4-5-20251001"
    case sonnet = "claude-sonnet-4-6-20250514"
    case opus = "claude-opus-4-6-20250514"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .haiku: return "Haiku 4.5"
        case .sonnet: return "Sonnet 4.6"
        case .opus: return "Opus 4.6"
        }
    }

    var description: String {
        switch self {
        case .haiku: return "Fast — ideal for quick diagnostics"
        case .sonnet: return "Balanced — recommended for most troubleshooting"
        case .opus: return "Deepest reasoning — complex system issues"
        }
    }

    var costTier: String {
        switch self {
        case .haiku: return "$"
        case .sonnet: return "$$"
        case .opus: return "$$$"
        }
    }
}

// MARK: - API Request/Response Types

struct ClaudeMessagesRequest: Encodable {
    let model: String
    let maxTokens: Int
    let system: String?
    let messages: [ClaudeMessage]
    let stream: Bool

    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case system
        case messages
        case stream
    }
}

struct ClaudeMessage: Codable, Sendable {
    let role: Role
    let content: [ContentBlock]

    enum Role: String, Codable, Sendable {
        case user
        case assistant
    }

    enum ContentBlock: Codable, Sendable {
        case text(String)

        var text: String? {
            if case .text(let t) = self { return t }
            return nil
        }

        enum CodingKeys: String, CodingKey {
            case type, text
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .text(let text):
                try container.encode("text", forKey: .type)
                try container.encode(text, forKey: .text)
            }
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let text = try container.decode(String.self, forKey: .text)
            self = .text(text)
        }
    }
}

struct ClaudeResponse: Decodable {
    let id: String
    let content: [ContentItem]
    let usage: Usage

    struct ContentItem: Decodable {
        let type: String
        let text: String?
    }

    struct Usage: Decodable {
        let inputTokens: Int
        let outputTokens: Int

        enum CodingKeys: String, CodingKey {
            case inputTokens = "input_tokens"
            case outputTokens = "output_tokens"
        }
    }

    var textContent: String {
        content
            .filter { $0.type == "text" }
            .compactMap(\.text)
            .joined()
    }
}

// MARK: - Streaming Event Types

enum ClaudeStreamEvent: Sendable {
    case textDelta(String)
    case messageComplete(ClaudeStreamUsage)
    case error(String)
}

struct ClaudeStreamUsage: Sendable {
    let inputTokens: Int
    let outputTokens: Int
}
