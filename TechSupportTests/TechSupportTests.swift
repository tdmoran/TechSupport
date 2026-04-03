import XCTest
@testable import TechSupport

final class SystemMetricsTests: XCTestCase {
    func testFormattedUptime() {
        let metrics = SystemMetrics(
            cpuUsage: 25.0,
            cpuCoreCount: 8,
            memoryUsed: 8_589_934_592,
            memoryTotal: 17_179_869_184,
            memoryPressure: .nominal,
            diskUsed: 250_000_000_000,
            diskTotal: 500_000_000_000,
            networkBytesSent: 1_048_576,
            networkBytesReceived: 10_485_760,
            batteryLevel: 85.0,
            batteryIsCharging: false,
            uptimeSeconds: 90_000,
            macOSVersion: "macOS 14.0",
            hardwareModel: "MacBookPro18,1",
            timestamp: Date()
        )

        XCTAssertEqual(metrics.formattedUptime, "1d 1h 0m")
        XCTAssertEqual(metrics.formattedMemoryUsed, "8.0 GB")
        XCTAssertEqual(metrics.formattedMemoryTotal, "16.0 GB")
        XCTAssertTrue(metrics.memoryUsagePercent > 49 && metrics.memoryUsagePercent < 51)
        XCTAssertTrue(metrics.diskUsagePercent > 49 && metrics.diskUsagePercent < 51)
    }

    func testEmptyMetrics() {
        let metrics = SystemMetrics.empty
        XCTAssertEqual(metrics.cpuUsage, 0)
        XCTAssertEqual(metrics.memoryUsagePercent, 0)
        XCTAssertEqual(metrics.diskUsagePercent, 0)
    }
}

final class DiagnosticCatalogTests: XCTestCase {
    func testAllCommandsHaveValidProperties() {
        let allCommands = DiagnosticCatalog.allCommands
        XCTAssertFalse(allCommands.isEmpty)

        for command in allCommands {
            XCTAssertFalse(command.id.isEmpty, "Command ID should not be empty")
            XCTAssertFalse(command.name.isEmpty, "Command name should not be empty")
            XCTAssertFalse(command.command.isEmpty, "Command path should not be empty")
            XCTAssertTrue(command.timeout > 0, "Timeout should be positive")
        }
    }

    func testCategoriesHaveCommands() {
        for category in DiagnosticCategory.allCases {
            let commands = DiagnosticCatalog.commands(for: category)
            XCTAssertFalse(commands.isEmpty, "\(category.rawValue) should have commands")
        }
    }
}

final class ChatSessionTests: XCTestCase {
    func testAppendingIsImmutable() {
        let session = ChatSession()
        let message = ChatMessage(role: .user, content: "Hello")
        let updated = session.appending(message)

        XCTAssertEqual(session.messages.count, 0)
        XCTAssertEqual(updated.messages.count, 1)
        XCTAssertEqual(session.id, updated.id)
    }

    func testTruncation() {
        var session = ChatSession()
        for i in 0..<10 {
            session = session.appending(ChatMessage(role: .user, content: "Message \(i)"))
        }

        let truncated = session.truncatedToLast(3)
        XCTAssertEqual(truncated.messages.count, 3)
        XCTAssertEqual(truncated.messages.first?.content, "Message 7")
    }

    func testClaudeMessagesConversion() {
        var session = ChatSession()
        session = session.appending(ChatMessage(role: .user, content: "Hello"))
        session = session.appending(ChatMessage(role: .assistant, content: "Hi"))
        session = session.appending(ChatMessage(role: .system, content: "System message"))

        let claudeMessages = session.claudeMessages
        XCTAssertEqual(claudeMessages.count, 2) // system messages filtered out
    }
}
