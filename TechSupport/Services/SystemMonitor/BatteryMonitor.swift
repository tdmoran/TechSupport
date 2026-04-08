import Foundation
import IOKit

struct BatteryInfo: Sendable, Codable {
    let level: Double
    let isCharging: Bool
    let amperage: Int          // mA — negative = discharging, positive = charging
    let voltage: Double        // Volts
    let watts: Double          // Current power draw/charge rate
    let timeRemaining: Int?    // Minutes — nil if calculating
    let cycleCount: Int
    let healthPercent: Double  // maxCapacity / designCapacity * 100
    let isPluggedIn: Bool

    var formattedWatts: String {
        String(format: "%.1fW", abs(watts))
    }

    var formattedTimeRemaining: String {
        guard let mins = timeRemaining, mins > 0, mins < 6000 else { return "Calculating…" }
        let h = mins / 60
        let m = mins % 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }

    var chargingStatus: String {
        if isCharging { return "Charging at \(formattedWatts)" }
        if isPluggedIn { return "Plugged in — Full" }
        return "Discharging at \(formattedWatts)"
    }
}

struct BatteryMonitor: Sendable {
    func currentInfo() -> BatteryInfo? {
        let service = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("AppleSmartBattery")
        )

        guard service != IO_OBJECT_NULL else {
            return nil // No battery (desktop Mac)
        }
        defer { IOObjectRelease(service) }

        var properties: Unmanaged<CFMutableDictionary>?
        let result = IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0)

        guard result == kIOReturnSuccess,
              let props = properties?.takeRetainedValue() as? [String: Any]
        else {
            return nil
        }

        guard let currentCapacity = props["CurrentCapacity"] as? Int,
              let maxCapacity = props["MaxCapacity"] as? Int,
              maxCapacity > 0
        else {
            return nil
        }

        let level = Double(currentCapacity) / Double(maxCapacity) * 100
        let isCharging = props["IsCharging"] as? Bool ?? false
        let amperage = props["Amperage"] as? Int ?? 0
        let voltageRaw = props["Voltage"] as? Int ?? 0
        let voltage = Double(voltageRaw) / 1000.0
        let watts = Double(abs(amperage)) * voltage / 1000.0
        let cycleCount = props["CycleCount"] as? Int ?? 0
        let designCapacity = props["DesignCapacity"] as? Int ?? maxCapacity
        let healthPercent = designCapacity > 0 ? Double(maxCapacity) / Double(designCapacity) * 100 : 100
        let isPluggedIn = props["ExternalConnected"] as? Bool ?? false

        let timeKey = isCharging ? "AvgTimeToFull" : "AvgTimeToEmpty"
        let timeRaw = props[timeKey] as? Int
        let timeRemaining = (timeRaw == nil || timeRaw == 65535) ? nil : timeRaw

        return BatteryInfo(
            level: level,
            isCharging: isCharging,
            amperage: amperage,
            voltage: voltage,
            watts: watts,
            timeRemaining: timeRemaining,
            cycleCount: cycleCount,
            healthPercent: healthPercent,
            isPluggedIn: isPluggedIn
        )
    }
}
