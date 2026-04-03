import Foundation

struct ChatSession: Identifiable, Sendable {
    let id: UUID
    let messages: [ChatMessage]
    let createdAt: Date

    init(
        id: UUID = UUID(),
        messages: [ChatMessage] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.messages = messages
        self.createdAt = createdAt
    }

    func appending(_ message: ChatMessage) -> ChatSession {
        ChatSession(id: id, messages: messages + [message], createdAt: createdAt)
    }

    func replacingLast(with message: ChatMessage) -> ChatSession {
        guard !messages.isEmpty else {
            return appending(message)
        }
        let updated = Array(messages.dropLast()) + [message]
        return ChatSession(id: id, messages: updated, createdAt: createdAt)
    }

    func truncatedToLast(_ count: Int) -> ChatSession {
        let kept = Array(messages.suffix(count))
        return ChatSession(id: id, messages: kept, createdAt: createdAt)
    }

    var claudeMessages: [ClaudeMessage] {
        messages.compactMap { msg -> ClaudeMessage? in
            switch msg.role {
            case .user:
                return ClaudeMessage(role: .user, content: [.text(msg.content)])
            case .assistant:
                return ClaudeMessage(role: .assistant, content: [.text(msg.content)])
            case .system:
                return nil
            }
        }
    }
}
