import Foundation

enum DiagnosticCategory: String, CaseIterable, Identifiable, Sendable {
    case system = "System"
    case storage = "Storage"
    case network = "Network"
    case processes = "Processes"
    case logs = "Logs"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .system: return "desktopcomputer"
        case .storage: return "internaldrive"
        case .network: return "network"
        case .processes: return "cpu"
        case .logs: return "doc.text.magnifyingglass"
        }
    }
}

enum DiagnosticCatalog {
    static func commands(for category: DiagnosticCategory) -> [DiagnosticCommand] {
        switch category {
        case .system: return systemCommands
        case .storage: return storageCommands
        case .network: return networkCommands
        case .processes: return processCommands
        case .logs: return logCommands
        }
    }

    static var allCommands: [DiagnosticCommand] {
        DiagnosticCategory.allCases.flatMap { commands(for: $0) }
    }

    static let systemCommands: [DiagnosticCommand] = [
        DiagnosticCommand(
            id: "sys_hardware",
            name: "Hardware Info",
            description: "System hardware overview",
            command: "/usr/sbin/system_profiler",
            arguments: ["SPHardwareDataType"]
        ),
        DiagnosticCommand(
            id: "sys_version",
            name: "macOS Version",
            description: "Operating system version details",
            command: "/usr/bin/sw_vers"
        ),
        DiagnosticCommand(
            id: "sys_uptime",
            name: "System Uptime",
            description: "How long the system has been running",
            command: "/usr/bin/uptime"
        ),
    ]

    static let storageCommands: [DiagnosticCommand] = [
        DiagnosticCommand(
            id: "disk_usage",
            name: "Disk Usage",
            description: "Disk space usage across volumes",
            command: "/bin/df",
            arguments: ["-h"]
        ),
        DiagnosticCommand(
            id: "cache_size",
            name: "Cache Size",
            description: "Size of user cache directories",
            command: "/usr/bin/du",
            arguments: ["-sh", NSHomeDirectory() + "/Library/Caches"]
        ),
    ]

    static let networkCommands: [DiagnosticCommand] = [
        DiagnosticCommand(
            id: "net_interfaces",
            name: "Network Interfaces",
            description: "List all network hardware ports",
            command: "/usr/sbin/networksetup",
            arguments: ["-listallhardwareports"]
        ),
        DiagnosticCommand(
            id: "net_ping",
            name: "Internet Connectivity",
            description: "Ping test to check internet access",
            command: "/sbin/ping",
            arguments: ["-c", "3", "8.8.8.8"],
            timeout: 15
        ),
        DiagnosticCommand(
            id: "net_dns",
            name: "DNS Lookup",
            description: "Test DNS resolution",
            command: "/usr/bin/nslookup",
            arguments: ["apple.com"]
        ),
    ]

    static let processCommands: [DiagnosticCommand] = [
        DiagnosticCommand(
            id: "proc_top",
            name: "Top Processes",
            description: "Top 10 processes by CPU usage",
            command: "/usr/bin/top",
            arguments: ["-l", "1", "-n", "10", "-stats", "pid,command,cpu,mem"]
        ),
    ]

    static let logCommands: [DiagnosticCommand] = [
        DiagnosticCommand(
            id: "log_errors",
            name: "Recent Errors",
            description: "System errors from the last 5 minutes",
            command: "/usr/bin/log",
            arguments: [
                "show",
                "--predicate", "eventMessage contains \"error\"",
                "--last", "5m",
                "--style", "compact",
            ],
            timeout: 15
        ),
    ]
}
