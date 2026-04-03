import Foundation

struct ChatMessage: Identifiable, Equatable, Sendable {
    let id: UUID
    let role: Role
    let content: String
    let timestamp: Date
    let systemContext: SystemMetrics?

    enum Role: String, Sendable {
        case user
        case assistant
        case system
    }

    init(
        id: UUID = UUID(),
        role: Role,
        content: String,
        timestamp: Date = Date(),
        systemContext: SystemMetrics? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.systemContext = systemContext
    }

    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id && lhs.content == rhs.content
    }
}
