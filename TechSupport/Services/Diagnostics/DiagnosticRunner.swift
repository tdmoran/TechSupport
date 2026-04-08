import Foundation
import OSLog

private let logger = Logger(subsystem: "com.techsupport", category: "DiagnosticRunner")

actor DiagnosticRunner {
    private let allowedCommands: Set<String>

    /// Hardcoded set of approved binary paths. Only binaries in this set may be executed.
    private static let approvedBinaries: Set<String> = [
        "/usr/sbin/system_profiler",
        "/usr/bin/sw_vers",
        "/usr/bin/uptime",
        "/bin/df",
        "/usr/bin/du",
        "/usr/sbin/networksetup",
        "/sbin/ping",
        "/usr/bin/nslookup",
        "/usr/bin/top",
        "/usr/bin/log",
    ]

    init() {
        allowedCommands = Set(DiagnosticCatalog.allCommands.map(\.id))
    }

    func run(_ command: DiagnosticCommand) async throws -> DiagnosticResult {
        guard allowedCommands.contains(command.id) else {
            throw AppError.diagnosticCommandNotAllowed(command: command.name)
        }

        // Require absolute path to prevent PATH-based injection
        guard command.command.hasPrefix("/") else {
            logger.error("Rejected non-absolute command path: \(command.command)")
            throw AppError.diagnosticCommandNotAllowed(command: command.name)
        }

        // Validate the binary path against the hardcoded allowlist
        guard Self.approvedBinaries.contains(command.command) else {
            logger.error("Rejected unapproved binary: \(command.command)")
            throw AppError.diagnosticCommandNotAllowed(command: command.name)
        }

        let startTime = Date()
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: command.command)
        process.arguments = command.arguments
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
        } catch {
            throw AppError.diagnosticCommandFailed(
                command: command.name,
                detail: error.localizedDescription
            )
        }

        let timeoutTask = Task {
            try await Task.sleep(for: .seconds(command.timeout))
            if process.isRunning {
                process.terminate()
            }
        }

        process.waitUntilExit()
        timeoutTask.cancel()

        let duration = Date().timeIntervalSince(startTime)

        if duration >= command.timeout {
            throw AppError.diagnosticTimeout(command: command.name)
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        var output = String(data: data, encoding: .utf8) ?? ""

        if output.count > AppConstants.maxDiagnosticOutput {
            let truncated = output.prefix(AppConstants.maxDiagnosticOutput)
            output = String(truncated) + "\n... (output truncated)"
        }

        logger.debug("Diagnostic '\(command.name)' completed in \(String(format: "%.1f", duration))s")

        return DiagnosticResult(
            command: command,
            output: output,
            exitCode: process.terminationStatus,
            duration: duration,
            timestamp: Date()
        )
    }
}
