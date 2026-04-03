import Foundation

enum AppConstants {
    static let bundleID = "com.techsupport.app"
    static let keychainService = "com.techsupport.app"
    static let defaultModel = ClaudeModel.sonnet
    static let monitorRefreshInterval: TimeInterval = 2.0
    static let maxChatHistory = 50
    static let maxDiagnosticOutput = 10_000
    static let diagnosticTimeout: TimeInterval = 30.0
    static let metricsHistoryCount = 60
}
