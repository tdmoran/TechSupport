import Foundation
import Darwin
import IOKit

// Lightweight system metric fetchers for the widget extension process.
// These mirror the main app's monitors but are self-contained.

struct WidgetMetrics {
    let cpuUsage: Double
    let cpuCores: Int
    let memoryUsed: UInt64
    let memoryTotal: UInt64
    let diskUsed: UInt64
    let diskTotal: UInt64
    let wifiSpeed: Double? // Mbps
    let wifiSignal: Int?   // dBm
    let timestamp: Date

    var memoryPercent: Double {
        guard memoryTotal > 0 else { return 0 }
        return Double(memoryUsed) / Double(memoryTotal) * 100
    }

    var diskPercent: Double {
        guard diskTotal > 0 else { return 0 }
        return Double(diskUsed) / Double(diskTotal) * 100
    }

    var formattedMemory: String {
        let usedGB = Double(memoryUsed) / 1_073_741_824
        let totalGB = Double(memoryTotal) / 1_073_741_824
        return String(format: "%.1f/%.0f GB", usedGB, totalGB)
    }

    var formattedDisk: String {
        let usedGB = Double(diskUsed) / 1_073_741_824
        let totalGB = Double(diskTotal) / 1_073_741_824
        return String(format: "%.0f/%.0f GB", usedGB, totalGB)
    }

    var formattedWifi: String {
        guard let speed = wifiSpeed else { return "Off" }
        if speed >= 1000 { return String(format: "%.1f Gbps", speed / 1000) }
        return String(format: "%.0f Mbps", speed)
    }

    static func fetch() -> WidgetMetrics {
        WidgetMetrics(
            cpuUsage: fetchCPU(),
            cpuCores: ProcessInfo.processInfo.processorCount,
            memoryUsed: fetchMemoryUsed(),
            memoryTotal: ProcessInfo.processInfo.physicalMemory,
            diskUsed: fetchDisk().used,
            diskTotal: fetchDisk().total,
            wifiSpeed: fetchWiFiSpeed(),
            wifiSignal: fetchWiFiSignal(),
            timestamp: Date()
        )
    }

    // MARK: - CPU

    private static func fetchCPU() -> Double {
        var cpuInfo: processor_info_array_t?
        var numCPUInfo: mach_msg_type_number_t = 0
        var numCPUs: natural_t = 0

        let result = host_processor_info(
            mach_host_self(), PROCESSOR_CPU_LOAD_INFO,
            &numCPUs, &cpuInfo, &numCPUInfo
        )
        guard result == KERN_SUCCESS, let info = cpuInfo else { return 0 }
        defer {
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info),
                          vm_size_t(numCPUInfo) * vm_size_t(MemoryLayout<integer_t>.stride))
        }

        var user: Double = 0, system: Double = 0, idle: Double = 0
        for i in 0..<Int(numCPUs) {
            let off = Int(CPU_STATE_MAX) * i
            user += Double(info[off + Int(CPU_STATE_USER)]) + Double(info[off + Int(CPU_STATE_NICE)])
            system += Double(info[off + Int(CPU_STATE_SYSTEM)])
            idle += Double(info[off + Int(CPU_STATE_IDLE)])
        }
        let total = user + system + idle
        guard total > 0 else { return 0 }
        return min(((user + system) / total) * 100, 100)
    }

    // MARK: - Memory

    private static func fetchMemoryUsed() -> UInt64 {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, intPtr, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        let page = UInt64(vm_page_size)
        return UInt64(stats.active_count) * page +
               UInt64(stats.wire_count) * page +
               UInt64(stats.compressor_page_count) * page
    }

    // MARK: - Disk

    private static func fetchDisk() -> (used: UInt64, total: UInt64) {
        let url = URL(fileURLWithPath: "/")
        guard let v = try? url.resourceValues(forKeys: [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
        ]) else { return (0, 0) }
        let total = UInt64(v.volumeTotalCapacity ?? 0)
        let avail = UInt64(v.volumeAvailableCapacityForImportantUsage ?? 0)
        return (total > avail ? total - avail : 0, total)
    }

    // MARK: - Wi-Fi (CoreWLAN)

    private static func fetchWiFiSpeed() -> Double? {
        // Use CoreWLAN via dynamic loading to avoid linking issues in extension
        guard let cls = NSClassFromString("CWWiFiClient") as? NSObject.Type,
              let client = cls.perform(Selector(("sharedWiFiClient")))?.takeUnretainedValue(),
              let iface = (client as AnyObject).perform(Selector(("interface")))?.takeUnretainedValue()
        else { return nil }
        let rate = (iface as AnyObject).value(forKey: "transmitRate") as? Double
        return rate
    }

    private static func fetchWiFiSignal() -> Int? {
        guard let cls = NSClassFromString("CWWiFiClient") as? NSObject.Type,
              let client = cls.perform(Selector(("sharedWiFiClient")))?.takeUnretainedValue(),
              let iface = (client as AnyObject).perform(Selector(("interface")))?.takeUnretainedValue()
        else { return nil }
        let rssi = (iface as AnyObject).value(forKey: "rssiValue") as? Int
        return rssi
    }
}
