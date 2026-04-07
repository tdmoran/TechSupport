import Foundation
import UserNotifications
import OSLog

private let logger = Logger(subsystem: "com.techsupport", category: "Notifications")

@Observable
@MainActor
final class NotificationManager {
    var isEnabled: Bool = true

    private var lastCPUAlert: Date?
    private var lastMemoryAlert: Date?
    private var lastDiskAlert: Date?
    private var lastBatteryAlert: Date?

    /// Number of consecutive refreshes where CPU exceeded the threshold.
    private var cpuHighCount: Int = 0

    private let cooldownInterval: TimeInterval = 300 // 5 minutes
    private let cpuThreshold: Double = 90
    private let diskThreshold: Double = 90
    private let batteryThreshold: Double = 15
    /// How many consecutive high-CPU samples before alerting (2s refresh * 15 = 30s).
    private let cpuSustainedCount: Int = 15

    // MARK: - Permission

    func requestPermission() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error {
                logger.error("Notification permission error: \(error.localizedDescription)")
            }
            logger.info("Notification permission granted: \(granted)")
        }
    }

    // MARK: - Threshold evaluation

    func evaluate(_ metrics: SystemMetrics) {
        guard isEnabled else {
            cpuHighCount = 0
            return
        }

        evaluateCPU(metrics.cpuUsage)
        evaluateMemory(metrics.memoryPressure)
        evaluateDisk(metrics.diskUsagePercent)
        evaluateBattery(level: metrics.batteryLevel, isCharging: metrics.batteryIsCharging)
    }

    // MARK: - Individual checks

    private func evaluateCPU(_ usage: Double) {
        if usage > cpuThreshold {
            cpuHighCount += 1
        } else {
            cpuHighCount = 0
        }

        if cpuHighCount >= cpuSustainedCount && canAlert(last: lastCPUAlert) {
            sendNotification(
                title: "High CPU Usage",
                body: String(format: "CPU has been above %.0f%% for 30+ seconds (currently %.0f%%).", cpuThreshold, usage)
            )
            lastCPUAlert = Date()
            cpuHighCount = 0
        }
    }

    private func evaluateMemory(_ pressure: MemoryPressure) {
        guard pressure == .critical, canAlert(last: lastMemoryAlert) else { return }
        sendNotification(
            title: "Critical Memory Pressure",
            body: "System memory pressure has reached a critical level. Consider closing unused apps."
        )
        lastMemoryAlert = Date()
    }

    private func evaluateDisk(_ usagePercent: Double) {
        guard usagePercent > diskThreshold, canAlert(last: lastDiskAlert) else { return }
        sendNotification(
            title: "Disk Space Low",
            body: String(format: "Disk usage is at %.0f%%. Free up space to avoid performance issues.", usagePercent)
        )
        lastDiskAlert = Date()
    }

    private func evaluateBattery(level: Double?, isCharging: Bool?) {
        guard let level, let isCharging, !isCharging else { return }
        guard level < batteryThreshold, canAlert(last: lastBatteryAlert) else { return }
        sendNotification(
            title: "Low Battery",
            body: String(format: "Battery is at %.0f%%. Connect your charger soon.", level)
        )
        lastBatteryAlert = Date()
    }

    // MARK: - Helpers

    private func canAlert(last: Date?) -> Bool {
        guard let last else { return true }
        return Date().timeIntervalSince(last) >= cooldownInterval
    }

    private func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // deliver immediately
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                logger.error("Failed to deliver notification: \(error.localizedDescription)")
            }
        }
        logger.info("Notification sent: \(title)")
    }
}
