import Foundation
import AppKit

@Observable
@MainActor
final class MonitorViewModel {
    let monitorService: SystemMonitorService

    init(monitorService: SystemMonitorService) {
        self.monitorService = monitorService
    }

    var metrics: SystemMetrics { monitorService.currentMetrics }
    var history: [SystemMetrics] { monitorService.metricsHistory }
    var wifiInfo: WiFiInfo? { monitorService.wifiInfo }
    var networkHealth: NetworkHealth { monitorService.networkHealth }
    var peripherals: [PeripheralDevice] { monitorService.peripherals }

    var cpuStatusColor: StatusColor {
        if metrics.cpuUsage > 90 { return .red }
        if metrics.cpuUsage > 70 { return .yellow }
        return .green
    }

    var memoryStatusColor: StatusColor {
        switch metrics.memoryPressure {
        case .critical: return .red
        case .warning: return .yellow
        case .nominal: return .green
        }
    }

    var diskStatusColor: StatusColor {
        if metrics.diskUsagePercent > 90 { return .red }
        if metrics.diskUsagePercent > 75 { return .yellow }
        return .green
    }

    var batteryStatusColor: StatusColor {
        guard let level = metrics.batteryLevel else { return .green }
        if level < 15 { return .red }
        if level < 30 { return .yellow }
        return .green
    }

    var wifiStatusColor: StatusColor {
        guard let wifi = wifiInfo else { return .red }
        switch wifi.signalQuality {
        case .excellent, .good: return .green
        case .fair: return .yellow
        case .poor: return .red
        }
    }

    var networkHealthStatusColor: StatusColor {
        switch networkHealth.overallStatus {
        case .healthy: return .green
        case .fair: return .yellow
        case .slow, .degraded, .offline: return .red
        }
    }

    var runningAppNames: [String] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { $0.localizedName }
            .sorted()
    }

    var backgroundAppNames: [String] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .accessory || $0.activationPolicy == .prohibited }
            .compactMap { $0.localizedName }
            .filter { !$0.isEmpty }
            .sorted()
    }

    func forceQuitApp(named name: String) {
        guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.localizedName == name }) else { return }
        app.forceTerminate()
    }

    enum StatusColor {
        case green, yellow, red
    }
}
