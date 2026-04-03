import Foundation

struct DiskMonitor: Sendable {
    func currentUsage() -> (used: UInt64, total: UInt64) {
        let url = URL(fileURLWithPath: "/")
        guard let values = try? url.resourceValues(forKeys: [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
        ]) else {
            return (0, 0)
        }

        let total = UInt64(values.volumeTotalCapacity ?? 0)
        let available = UInt64(values.volumeAvailableCapacityForImportantUsage ?? 0)
        let used = total > available ? total - available : 0

        return (used, total)
    }
}
