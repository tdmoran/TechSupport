import Foundation
import IOKit

struct BatteryInfo: Sendable {
    let level: Double
    let isCharging: Bool
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

        return BatteryInfo(level: level, isCharging: isCharging)
    }
}
