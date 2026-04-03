import Foundation
import OSLog
import Network

private let logger = Logger(subsystem: "com.techsupport", category: "NetworkHealth")

struct NetworkHealth: Sendable {
    let isConnected: Bool
    let latencyMs: Double? // ping to 8.8.8.8
    let dnsResolved: Bool
    let gatewayReachable: Bool

    var overallStatus: Status {
        if !isConnected { return .offline }
        if let latency = latencyMs {
            if !dnsResolved { return .degraded }
            if latency > 200 { return .slow }
            if latency > 100 { return .fair }
            return .healthy
        }
        return .degraded
    }

    var statusLabel: String {
        overallStatus.label
    }

    var formattedLatency: String {
        guard let ms = latencyMs else { return "—" }
        if ms < 1 { return "<1 ms" }
        return String(format: "%.0f ms", ms)
    }

    enum Status: Sendable {
        case healthy, fair, slow, degraded, offline

        var label: String {
            switch self {
            case .healthy: return "Healthy"
            case .fair: return "Fair"
            case .slow: return "Slow"
            case .degraded: return "Degraded"
            case .offline: return "Offline"
            }
        }

        var icon: String {
            switch self {
            case .healthy: return "checkmark.circle.fill"
            case .fair: return "minus.circle.fill"
            case .slow: return "tortoise.fill"
            case .degraded: return "exclamationmark.triangle.fill"
            case .offline: return "xmark.circle.fill"
            }
        }
    }

    static let unknown = NetworkHealth(
        isConnected: false, latencyMs: nil,
        dnsResolved: false, gatewayReachable: false
    )
}

actor NetworkHealthMonitor {
    func check() async -> NetworkHealth {
        let connected = checkConnectivity()
        guard connected else {
            return NetworkHealth(
                isConnected: false, latencyMs: nil,
                dnsResolved: false, gatewayReachable: false
            )
        }

        async let latency = measureLatency()
        async let dns = checkDNS()

        let lat = await latency
        let dnsOk = await dns

        return NetworkHealth(
            isConnected: true,
            latencyMs: lat,
            dnsResolved: dnsOk,
            gatewayReachable: lat != nil
        )
    }

    private func checkConnectivity() -> Bool {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/sbin/ifconfig")
        process.arguments = ["en0"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        // Also check en1 (Wi-Fi on some Macs)
        if output.contains("status: active") { return true }

        let process2 = Process()
        let pipe2 = Pipe()
        process2.executableURL = URL(fileURLWithPath: "/sbin/ifconfig")
        process2.arguments = ["en1"]
        process2.standardOutput = pipe2
        process2.standardError = FileHandle.nullDevice
        try? process2.run()
        process2.waitUntilExit()
        let data2 = pipe2.fileHandleForReading.readDataToEndOfFile()
        let output2 = String(data: data2, encoding: .utf8) ?? ""
        return output2.contains("status: active")
    }

    private func measureLatency() async -> Double? {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/sbin/ping")
        process.arguments = ["-c", "1", "-t", "5", "8.8.8.8"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return nil }

        // Parse "time=12.345 ms"
        guard let range = output.range(of: "time=") else { return nil }
        let afterTime = output[range.upperBound...]
        guard let msRange = afterTime.range(of: " ms") else { return nil }
        let msString = afterTime[..<msRange.lowerBound]
        return Double(msString)
    }

    private func checkDNS() async -> Bool {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/host")
        process.arguments = ["-W", "3", "apple.com"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return false
        }

        return process.terminationStatus == 0
    }
}
