import Foundation
import OSLog

private let logger = Logger(subsystem: "com.techsupport", category: "DiagnosticExporter")

actor DiagnosticExporter {
    private let runner = DiagnosticRunner()

    func generateReport(metrics: SystemMetrics) async -> String {
        var sections: [String] = []

        // Header
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        dateFormatter.timeStyle = .long
        let header = """
            ========================================
            TechSupport Diagnostic Report
            ========================================
            Date:     \(dateFormatter.string(from: Date()))
            Machine:  \(metrics.hardwareModel)
            macOS:    \(metrics.macOSVersion)
            Uptime:   \(metrics.formattedUptime)
            ========================================
            """
        sections.append(header)

        // System Metrics
        var metricsLines = """
            ----------------------------------------
            SYSTEM METRICS
            ----------------------------------------
            CPU Usage:          \(String(format: "%.1f%%", metrics.cpuUsage)) (\(metrics.cpuCoreCount) cores)
            Memory:             \(metrics.formattedMemoryUsed) / \(metrics.formattedMemoryTotal) (\(String(format: "%.1f%%", metrics.memoryUsagePercent)))
            Memory Pressure:    \(metrics.memoryPressure.displayName)
            Disk:               \(metrics.formattedDiskUsed) / \(metrics.formattedDiskTotal) (\(String(format: "%.1f%%", metrics.diskUsagePercent)))
            Network Sent:       \(metrics.formattedNetworkSent)
            Network Received:   \(metrics.formattedNetworkReceived)
            """

        if let battery = metrics.batteryLevel {
            let charging = metrics.batteryIsCharging == true ? " (Charging)" : ""
            metricsLines += "\nBattery:            \(String(format: "%.0f%%", battery))\(charging)"
        }
        sections.append(metricsLines)

        // Diagnostic Results
        let commands = DiagnosticCatalog.allCommands
        var diagnosticLines = """
            ----------------------------------------
            DIAGNOSTIC RESULTS
            ----------------------------------------
            """

        for command in commands {
            diagnosticLines += "\n\n--- \(command.name) ---"
            diagnosticLines += "\n\(command.description)"
            diagnosticLines += "\n"

            do {
                let result = try await runner.run(command)
                if result.exitCode == 0 {
                    diagnosticLines += result.output.trimmingCharacters(in: .whitespacesAndNewlines)
                } else {
                    diagnosticLines += "[exit code \(result.exitCode)]\n\(result.output.trimmingCharacters(in: .whitespacesAndNewlines))"
                }
                diagnosticLines += "\n(completed in \(String(format: "%.1fs", result.duration)))"
            } catch {
                diagnosticLines += "[error] \(error.localizedDescription)"
                logger.warning("Diagnostic '\(command.name)' failed: \(error.localizedDescription)")
            }
        }
        sections.append(diagnosticLines)

        // Footer
        sections.append("""
            ----------------------------------------
            End of Report
            ----------------------------------------
            """)

        let report = sections.joined(separator: "\n\n")
        return sanitize(report)
    }

    // MARK: - Sanitization

    private func sanitize(_ text: String) -> String {
        var result = text

        // Replace current user's home directory with ~/
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        result = result.replacingOccurrences(of: homeDir, with: "~")

        // Replace current username with [user]
        let username = NSUserName()
        if !username.isEmpty {
            result = result.replacingOccurrences(of: username, with: "[user]")
        }

        // Redact hardware serial numbers (10-17 uppercase alphanumeric, typical Apple serial format)
        if let serialRegex = try? NSRegularExpression(
            pattern: "\\b[A-Z0-9]{10,17}\\b",
            options: []
        ) {
            let range = NSRange(result.startIndex..., in: result)
            result = serialRegex.stringByReplacingMatches(
                in: result,
                options: [],
                range: range,
                withTemplate: "[SERIAL REDACTED]"
            )
        }

        return result
    }
}
