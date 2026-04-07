import Foundation

enum MemoryPressure: String, Sendable, Codable {
    case nominal
    case warning
    case critical

    var displayName: String {
        switch self {
        case .nominal: return "Normal"
        case .warning: return "Warning"
        case .critical: return "Critical"
        }
    }
}

struct SystemMetrics: Sendable, Identifiable, Codable {
    let id: UUID
    let cpuUsage: Double
    let cpuCoreCount: Int
    let memoryUsed: UInt64
    let memoryTotal: UInt64
    let memoryPressure: MemoryPressure
    let diskUsed: UInt64
    let diskTotal: UInt64
    let networkBytesSent: UInt64
    let networkBytesReceived: UInt64
    let batteryLevel: Double?
    let batteryIsCharging: Bool?
    let uptimeSeconds: TimeInterval
    let macOSVersion: String
    let hardwareModel: String
    let timestamp: Date

    init(
        id: UUID = UUID(),
        cpuUsage: Double,
        cpuCoreCount: Int,
        memoryUsed: UInt64,
        memoryTotal: UInt64,
        memoryPressure: MemoryPressure,
        diskUsed: UInt64,
        diskTotal: UInt64,
        networkBytesSent: UInt64,
        networkBytesReceived: UInt64,
        batteryLevel: Double?,
        batteryIsCharging: Bool?,
        uptimeSeconds: TimeInterval,
        macOSVersion: String,
        hardwareModel: String,
        timestamp: Date
    ) {
        self.id = id
        self.cpuUsage = cpuUsage
        self.cpuCoreCount = cpuCoreCount
        self.memoryUsed = memoryUsed
        self.memoryTotal = memoryTotal
        self.memoryPressure = memoryPressure
        self.diskUsed = diskUsed
        self.diskTotal = diskTotal
        self.networkBytesSent = networkBytesSent
        self.networkBytesReceived = networkBytesReceived
        self.batteryLevel = batteryLevel
        self.batteryIsCharging = batteryIsCharging
        self.uptimeSeconds = uptimeSeconds
        self.macOSVersion = macOSVersion
        self.hardwareModel = hardwareModel
        self.timestamp = timestamp
    }

    var memoryUsagePercent: Double {
        guard memoryTotal > 0 else { return 0 }
        return Double(memoryUsed) / Double(memoryTotal) * 100
    }

    var diskUsagePercent: Double {
        guard diskTotal > 0 else { return 0 }
        return Double(diskUsed) / Double(diskTotal) * 100
    }

    var formattedMemoryUsed: String { formatBytes(memoryUsed) }
    var formattedMemoryTotal: String { formatBytes(memoryTotal) }
    var formattedDiskUsed: String { formatBytes(diskUsed) }
    var formattedDiskTotal: String { formatBytes(diskTotal) }
    var formattedNetworkSent: String { formatBytes(networkBytesSent) }
    var formattedNetworkReceived: String { formatBytes(networkBytesReceived) }

    var formattedUptime: String {
        let hours = Int(uptimeSeconds) / 3600
        let minutes = (Int(uptimeSeconds) % 3600) / 60
        if hours > 24 {
            let days = hours / 24
            let remainingHours = hours % 24
            return "\(days)d \(remainingHours)h \(minutes)m"
        }
        return "\(hours)h \(minutes)m"
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 1.0 {
            return String(format: "%.1f GB", gb)
        }
        let mb = Double(bytes) / 1_048_576
        return String(format: "%.0f MB", mb)
    }

    static let empty = SystemMetrics(
        cpuUsage: 0,
        cpuCoreCount: 0,
        memoryUsed: 0,
        memoryTotal: 0,
        memoryPressure: .nominal,
        diskUsed: 0,
        diskTotal: 0,
        networkBytesSent: 0,
        networkBytesReceived: 0,
        batteryLevel: nil,
        batteryIsCharging: nil,
        uptimeSeconds: 0,
        macOSVersion: "Unknown",
        hardwareModel: "Unknown",
        timestamp: Date()
    )
}
