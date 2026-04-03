import Foundation
import AppKit

struct AppProcessInfo: Identifiable, Sendable {
    let id: pid_t
    let name: String
    let isResponding: Bool
    let cpuUsage: Double
    let memoryMB: Double
    let icon: NSImage?

    var statusLabel: String {
        if !isResponding { return "Not Responding" }
        if cpuUsage > 90 { return "High CPU" }
        return "Running"
    }

    var isTrouble: Bool {
        !isResponding || cpuUsage > 90
    }
}

@Observable
@MainActor
final class ProcessListService {
    private(set) var processes: [AppProcessInfo] = []
    private(set) var isRefreshing = false

    func refresh() {
        isRefreshing = true
        let apps = NSWorkspace.shared.runningApplications

        var results: [AppProcessInfo] = []

        for app in apps {
            guard app.activationPolicy == .regular,
                  let name = app.localizedName,
                  !name.isEmpty
            else { continue }

            let pid = app.processIdentifier
            let responding = app.isFinishedLaunching && !app.isTerminated
            let (cpu, mem) = Self.getProcessStats(pid: pid)

            results.append(AppProcessInfo(
                id: pid,
                name: name,
                isResponding: responding,
                cpuUsage: cpu,
                memoryMB: mem,
                icon: app.icon
            ))
        }

        // Frozen/unresponsive apps first, then high CPU, then alphabetical
        processes = results.sorted { lhs, rhs in
            if lhs.isResponding != rhs.isResponding { return !lhs.isResponding }
            if lhs.cpuUsage != rhs.cpuUsage { return lhs.cpuUsage > rhs.cpuUsage }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }

        isRefreshing = false
    }

    func forceQuit(pid: pid_t) -> Bool {
        kill(pid, SIGKILL) == 0
    }

    private static func getProcessStats(pid: pid_t) -> (cpu: Double, memoryMB: Double) {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-p", "\(pid)", "-o", "%cpu=,rss="]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return (0, 0)
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !output.isEmpty
        else { return (0, 0) }

        let parts = output.split(separator: " ", omittingEmptySubsequences: true)
        let cpu = parts.first.flatMap { Double($0) } ?? 0
        let rssKB = parts.count > 1 ? (Double(parts[1]) ?? 0) : 0
        let memMB = rssKB / 1024.0

        return (cpu, memMB)
    }
}
