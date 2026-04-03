import Foundation

struct DiagnosticCommand: Identifiable, Sendable {
    let id: String
    let name: String
    let description: String
    let command: String
    let arguments: [String]
    let timeout: TimeInterval

    init(
        id: String,
        name: String,
        description: String,
        command: String,
        arguments: [String] = [],
        timeout: TimeInterval = AppConstants.diagnosticTimeout
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.command = command
        self.arguments = arguments
        self.timeout = timeout
    }
}

struct DiagnosticResult: Sendable {
    let command: DiagnosticCommand
    let output: String
    let exitCode: Int32
    let duration: TimeInterval
    let timestamp: Date
}
