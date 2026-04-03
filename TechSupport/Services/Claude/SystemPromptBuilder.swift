import Foundation

struct SystemPromptBuilder {
    func buildPrompt(
        metrics: SystemMetrics,
        diagnosticResults: [DiagnosticResult]? = nil
    ) -> String {
        var parts: [String] = []

        parts.append("""
        You are TechSupport, an expert macOS troubleshooting assistant. You have real-time \
        access to the user's system state. Provide specific, actionable solutions.

        ## Current System State
        - macOS: \(metrics.macOSVersion)
        - Hardware: \(metrics.hardwareModel)
        - CPU: \(String(format: "%.1f", metrics.cpuUsage))% (\(metrics.cpuCoreCount) cores)
        - Memory: \(metrics.formattedMemoryUsed)/\(metrics.formattedMemoryTotal) (\(metrics.memoryPressure.displayName))
        - Disk: \(metrics.formattedDiskUsed)/\(metrics.formattedDiskTotal) (\(String(format: "%.0f", metrics.diskUsagePercent))% full)
        - Network: \(metrics.formattedNetworkSent) sent / \(metrics.formattedNetworkReceived) received
        """)

        if let level = metrics.batteryLevel {
            let charging = metrics.batteryIsCharging == true ? " (charging)" : ""
            parts.append("- Battery: \(String(format: "%.0f", level))%\(charging)")
        }

        parts.append("- Uptime: \(metrics.formattedUptime)")

        if let results = diagnosticResults, !results.isEmpty {
            parts.append("\n## Recent Diagnostic Results")
            for result in results {
                parts.append("""
                ### \(result.command.name)
                ```
                \(result.output.prefix(2000))
                ```
                Exit code: \(result.exitCode)
                """)
            }
        }

        parts.append("""

        ## Guidelines
        - Provide specific, actionable steps for macOS troubleshooting
        - Reference macOS settings paths precisely (e.g., System Settings > General > Storage)
        - Suggest built-in macOS tools when applicable (Activity Monitor, Disk Utility, Console, etc.)
        - Warn before suggesting anything that could cause data loss
        - If you need more information, suggest specific diagnostic commands
        - Consider the current system metrics when diagnosing issues
        - For high CPU/memory usage, identify likely causes based on the metrics
        """)

        return parts.joined(separator: "\n")
    }
}
