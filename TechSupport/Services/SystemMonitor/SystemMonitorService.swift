import Foundation
import Combine
import OSLog

private let logger = Logger(subsystem: "com.techsupport", category: "SystemMonitor")

@Observable
@MainActor
final class SystemMonitorService {
    private(set) var currentMetrics: SystemMetrics = .empty
    private(set) var metricsHistory: [SystemMetrics] = []
    private(set) var wifiInfo: WiFiInfo?
    private(set) var networkHealth: NetworkHealth = .unknown
    private(set) var peripherals: [PeripheralDevice] = []

    private let cpuMonitor = CPUMonitor()
    private let memoryMonitor = MemoryMonitor()
    private let diskMonitor = DiskMonitor()
    private let networkMonitor = NetworkMonitor()
    private let batteryMonitor = BatteryMonitor()
    private let wifiMonitor = WiFiMonitor()
    private let healthMonitor = NetworkHealthMonitor()
    private var peripheralWatcher: PeripheralWatcher?

    private var timer: Timer?
    private var healthTimer: Timer?
    private let macOSVersion: String
    private let hardwareModel: String

    init() {
        macOSVersion = ProcessInfo.processInfo.operatingSystemVersionString
        hardwareModel = Self.readHardwareModel()
        refresh()
    }

    func start() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(
            withTimeInterval: AppConstants.monitorRefreshInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }

        // Network health check every 10s
        healthTimer?.invalidate()
        healthTimer = Timer.scheduledTimer(
            withTimeInterval: 10.0,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshNetworkHealth()
            }
        }

        // Initial health check
        Task { await refreshNetworkHealth() }

        // Live USB hotplug watcher — updates instantly when devices are plugged/unplugged
        let watcher = PeripheralWatcher()
        peripherals = watcher.devices
        watcher.onChange = { [weak self] in
            self?.peripherals = watcher.devices
        }
        peripheralWatcher = watcher
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        healthTimer?.invalidate()
        healthTimer = nil
    }

    func snapshot() -> SystemMetrics {
        refresh()
        return currentMetrics
    }

    private func refresh() {
        let cpu = cpuMonitor.currentUsage()
        let memory = memoryMonitor.currentUsage()
        let disk = diskMonitor.currentUsage()
        let network = networkMonitor.currentBytes()
        let battery = batteryMonitor.currentInfo()
        let wifi = wifiMonitor.currentInfo()

        wifiInfo = wifi

        let metrics = SystemMetrics(
            cpuUsage: cpu,
            cpuCoreCount: cpuMonitor.coreCount,
            memoryUsed: memory.used,
            memoryTotal: memoryMonitor.totalMemory,
            memoryPressure: memory.pressure,
            diskUsed: disk.used,
            diskTotal: disk.total,
            networkBytesSent: network.sent,
            networkBytesReceived: network.received,
            batteryLevel: battery?.level,
            batteryIsCharging: battery?.isCharging,
            uptimeSeconds: ProcessInfo.processInfo.systemUptime,
            macOSVersion: macOSVersion,
            hardwareModel: hardwareModel,
            timestamp: Date()
        )

        currentMetrics = metrics

        metricsHistory.append(metrics)
        if metricsHistory.count > AppConstants.metricsHistoryCount {
            metricsHistory.removeFirst()
        }
    }

    private func refreshNetworkHealth() async {
        networkHealth = await healthMonitor.check()
    }

    private static func readHardwareModel() -> String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        guard size > 0 else { return "Unknown Mac" }

        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        return String(cString: model)
    }
}
