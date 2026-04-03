import Foundation
import Darwin

struct MemoryMonitor: Sendable {
    let totalMemory: UInt64

    init() {
        totalMemory = ProcessInfo.processInfo.physicalMemory
    }

    func currentUsage() -> (used: UInt64, pressure: MemoryPressure) {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &stats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, intPtr, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return (0, .nominal)
        }

        let pageSize = UInt64(vm_page_size)
        let active = UInt64(stats.active_count) * pageSize
        let wired = UInt64(stats.wire_count) * pageSize
        let compressed = UInt64(stats.compressor_page_count) * pageSize
        let used = active + wired + compressed

        let usageRatio = Double(used) / Double(totalMemory)
        let pressure: MemoryPressure
        if usageRatio > 0.9 {
            pressure = .critical
        } else if usageRatio > 0.75 {
            pressure = .warning
        } else {
            pressure = .nominal
        }

        return (used, pressure)
    }
}
