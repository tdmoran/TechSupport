import Foundation
import Darwin

struct CPUMonitor: Sendable {
    private let processorCount: Int

    init() {
        processorCount = ProcessInfo.processInfo.processorCount
    }

    var coreCount: Int { processorCount }

    func currentUsage() -> Double {
        var cpuInfo: processor_info_array_t?
        var numCPUInfo: mach_msg_type_number_t = 0
        var numCPUs: natural_t = 0

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &numCPUs,
            &cpuInfo,
            &numCPUInfo
        )

        guard result == KERN_SUCCESS, let info = cpuInfo else {
            return 0
        }

        defer {
            let size = vm_size_t(numCPUInfo) * vm_size_t(MemoryLayout<integer_t>.stride)
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), size)
        }

        var totalUser: Double = 0
        var totalSystem: Double = 0
        var totalIdle: Double = 0

        for i in 0..<Int(numCPUs) {
            let offset = Int(CPU_STATE_MAX) * i
            let user = Double(info[offset + Int(CPU_STATE_USER)])
            let system = Double(info[offset + Int(CPU_STATE_SYSTEM)])
            let idle = Double(info[offset + Int(CPU_STATE_IDLE)])
            let nice = Double(info[offset + Int(CPU_STATE_NICE)])

            totalUser += user + nice
            totalSystem += system
            totalIdle += idle
        }

        let totalTicks = totalUser + totalSystem + totalIdle
        guard totalTicks > 0 else { return 0 }

        let usage = ((totalUser + totalSystem) / totalTicks) * 100
        return min(max(usage, 0), 100)
    }
}
