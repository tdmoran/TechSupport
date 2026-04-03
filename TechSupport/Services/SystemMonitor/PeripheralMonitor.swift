import Foundation
import IOKit
import IOKit.usb

struct PeripheralDevice: Identifiable, Sendable {
    let id: String
    let name: String
    let vendor: String
    let type: DeviceType

    var displayName: String {
        if !vendor.isEmpty && vendor != name {
            return "\(vendor) \(name)"
        }
        return name
    }

    enum DeviceType: String, Sendable {
        case usb = "USB"
        case thunderbolt = "Thunderbolt"
        case bluetooth = "Bluetooth"

        var icon: String {
            switch self {
            case .usb: return "cable.connector"
            case .thunderbolt: return "bolt.horizontal"
            case .bluetooth: return "dot.radiowaves.left.and.right"
            }
        }
    }
}

// MARK: - Live USB watcher using IOKit notifications

@MainActor
final class PeripheralWatcher {
    private(set) var devices: [PeripheralDevice] = []
    var onChange: (() -> Void)?

    private var notifyPort: IONotificationPortRef?
    private var addedIterator: io_iterator_t = 0
    private var removedIterator: io_iterator_t = 0

    init() {
        devices = Self.scanUSBDevices()
        startWatching()
    }

    deinit {
        if addedIterator != 0 { IOObjectRelease(addedIterator) }
        if removedIterator != 0 { IOObjectRelease(removedIterator) }
        if let port = notifyPort { IONotificationPortDestroy(port) }
    }

    func refresh() {
        devices = Self.scanUSBDevices()
        onChange?()
    }

    // MARK: - IOKit hotplug notifications

    private func startWatching() {
        notifyPort = IONotificationPortCreate(kIOMainPortDefault)
        guard let notifyPort else { return }

        let runLoopSource = IONotificationPortGetRunLoopSource(notifyPort).takeUnretainedValue()
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .defaultMode)

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        // Watch for USB device additions
        guard let matchDict1 = IOServiceMatching(kIOUSBDeviceClassName) else { return }
        IOServiceAddMatchingNotification(
            notifyPort,
            kIOFirstMatchNotification,
            matchDict1,
            { refcon, iterator in
                guard let refcon else { return }
                let watcher = Unmanaged<PeripheralWatcher>.fromOpaque(refcon).takeUnretainedValue()
                while case let device = IOIteratorNext(iterator), device != 0 {
                    IOObjectRelease(device)
                }
                DispatchQueue.main.async { watcher.refresh() }
            },
            selfPtr,
            &addedIterator
        )
        while case let device = IOIteratorNext(addedIterator), device != 0 {
            IOObjectRelease(device)
        }

        // Watch for USB device removals
        guard let matchDict2 = IOServiceMatching(kIOUSBDeviceClassName) else { return }
        IOServiceAddMatchingNotification(
            notifyPort,
            kIOTerminatedNotification,
            matchDict2,
            { refcon, iterator in
                guard let refcon else { return }
                let watcher = Unmanaged<PeripheralWatcher>.fromOpaque(refcon).takeUnretainedValue()
                while case let device = IOIteratorNext(iterator), device != 0 {
                    IOObjectRelease(device)
                }
                DispatchQueue.main.async { watcher.refresh() }
            },
            selfPtr,
            &removedIterator
        )
        while case let device = IOIteratorNext(removedIterator), device != 0 {
            IOObjectRelease(device)
        }
    }

    // MARK: - Scan current USB devices via IOKit (no shell Process)

    static func scanUSBDevices() -> [PeripheralDevice] {
        var devices: [PeripheralDevice] = []

        var iterator: io_iterator_t = 0
        guard let matchingDict = IOServiceMatching(kIOUSBDeviceClassName) else { return [] }
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, matchingDict, &iterator)
        guard result == KERN_SUCCESS else { return [] }

        defer { IOObjectRelease(iterator) }

        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }

            let name = property(service, key: "USB Product Name") ?? property(service, key: kUSBProductString as String) ?? ""
            let vendor = property(service, key: "USB Vendor Name") ?? property(service, key: kUSBVendorString as String) ?? ""

            let trimmedName = name.trimmingCharacters(in: .whitespaces)
            let trimmedVendor = vendor.trimmingCharacters(in: .whitespaces)

            // Skip empty names, internal hubs, and Apple internal devices
            guard !trimmedName.isEmpty else { continue }
            let lower = trimmedName.lowercased()
            if lower.contains("hub") || lower.contains("host controller") { continue }

            let device = PeripheralDevice(
                id: "usb-\(trimmedName)-\(trimmedVendor)",
                name: trimmedName,
                vendor: trimmedVendor,
                type: .usb
            )
            if !devices.contains(where: { $0.id == device.id }) {
                devices.append(device)
            }
        }

        return devices
    }

    private static func property(_ service: io_object_t, key: String) -> String? {
        guard let value = IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?
            .takeRetainedValue() else { return nil }
        return value as? String
    }
}
