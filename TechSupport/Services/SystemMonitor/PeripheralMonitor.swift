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

// MARK: - Live peripheral watcher using IOKit notifications (USB, Bluetooth, Thunderbolt)

@MainActor
final class PeripheralWatcher {
    private(set) var devices: [PeripheralDevice] = []
    var onChange: (() -> Void)?

    private var notifyPort: IONotificationPortRef?
    private var usbAddedIterator: io_iterator_t = 0
    private var usbRemovedIterator: io_iterator_t = 0
    private var bluetoothAddedIterator: io_iterator_t = 0
    private var bluetoothRemovedIterator: io_iterator_t = 0
    private var thunderboltAddedIterator: io_iterator_t = 0
    private var thunderboltRemovedIterator: io_iterator_t = 0

    init() {
        devices = Self.scanAllDevices()
        startWatching()
    }

    deinit {
        if usbAddedIterator != 0 { IOObjectRelease(usbAddedIterator) }
        if usbRemovedIterator != 0 { IOObjectRelease(usbRemovedIterator) }
        if bluetoothAddedIterator != 0 { IOObjectRelease(bluetoothAddedIterator) }
        if bluetoothRemovedIterator != 0 { IOObjectRelease(bluetoothRemovedIterator) }
        if thunderboltAddedIterator != 0 { IOObjectRelease(thunderboltAddedIterator) }
        if thunderboltRemovedIterator != 0 { IOObjectRelease(thunderboltRemovedIterator) }
        if let port = notifyPort { IONotificationPortDestroy(port) }
    }

    func refresh() {
        devices = Self.scanAllDevices()
        onChange?()
    }

    // MARK: - Aggregate scan

    private static func scanAllDevices() -> [PeripheralDevice] {
        var devices: [PeripheralDevice] = []
        devices.append(contentsOf: scanUSBDevices())
        devices.append(contentsOf: scanBluetoothDevices())
        devices.append(contentsOf: scanThunderboltDevices())
        return devices
    }

    // MARK: - IOKit hotplug notifications

    private func startWatching() {
        notifyPort = IONotificationPortCreate(kIOMainPortDefault)
        guard let notifyPort else { return }

        let runLoopSource = IONotificationPortGetRunLoopSource(notifyPort).takeUnretainedValue()
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .defaultMode)

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        let callback: IOServiceMatchingCallback = { refcon, iterator in
            guard let refcon else { return }
            let watcher = Unmanaged<PeripheralWatcher>.fromOpaque(refcon).takeUnretainedValue()
            while case let device = IOIteratorNext(iterator), device != 0 {
                IOObjectRelease(device)
            }
            DispatchQueue.main.async { watcher.refresh() }
        }

        // USB notifications
        registerNotifications(
            port: notifyPort,
            className: kIOUSBDeviceClassName,
            context: selfPtr,
            callback: callback,
            addedIterator: &usbAddedIterator,
            removedIterator: &usbRemovedIterator
        )

        // Bluetooth notifications
        registerNotifications(
            port: notifyPort,
            className: "IOBluetoothDevice",
            context: selfPtr,
            callback: callback,
            addedIterator: &bluetoothAddedIterator,
            removedIterator: &bluetoothRemovedIterator
        )

        // Thunderbolt notifications
        registerNotifications(
            port: notifyPort,
            className: "AppleThunderboltNHIType",
            context: selfPtr,
            callback: callback,
            addedIterator: &thunderboltAddedIterator,
            removedIterator: &thunderboltRemovedIterator
        )
    }

    private func registerNotifications(
        port: IONotificationPortRef,
        className: String,
        context: UnsafeMutableRawPointer,
        callback: @escaping IOServiceMatchingCallback,
        addedIterator: inout io_iterator_t,
        removedIterator: inout io_iterator_t
    ) {
        if let matchAdd = IOServiceMatching(className) {
            IOServiceAddMatchingNotification(
                port,
                kIOFirstMatchNotification,
                matchAdd,
                callback,
                context,
                &addedIterator
            )
            // Drain the iterator so notifications start firing
            while case let device = IOIteratorNext(addedIterator), device != 0 {
                IOObjectRelease(device)
            }
        }

        if let matchRemove = IOServiceMatching(className) {
            IOServiceAddMatchingNotification(
                port,
                kIOTerminatedNotification,
                matchRemove,
                callback,
                context,
                &removedIterator
            )
            while case let device = IOIteratorNext(removedIterator), device != 0 {
                IOObjectRelease(device)
            }
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

    // MARK: - Scan Bluetooth devices via IOKit

    static func scanBluetoothDevices() -> [PeripheralDevice] {
        var devices: [PeripheralDevice] = []

        var iterator: io_iterator_t = 0
        guard let matchingDict = IOServiceMatching("IOBluetoothDevice") else { return [] }
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, matchingDict, &iterator)
        guard result == KERN_SUCCESS else { return [] }

        defer { IOObjectRelease(iterator) }

        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }

            let name = property(service, key: "Name")
                ?? ioRegistryName(service)
                ?? ""

            let trimmedName = name.trimmingCharacters(in: .whitespaces)
            guard !trimmedName.isEmpty else { continue }

            let vendor = property(service, key: "Manufacturer") ?? ""
            let trimmedVendor = vendor.trimmingCharacters(in: .whitespaces)

            let device = PeripheralDevice(
                id: "bluetooth-\(trimmedName)-\(trimmedVendor)",
                name: trimmedName,
                vendor: trimmedVendor,
                type: .bluetooth
            )
            if !devices.contains(where: { $0.id == device.id }) {
                devices.append(device)
            }
        }

        return devices
    }

    // MARK: - Scan Thunderbolt devices via IOKit

    static func scanThunderboltDevices() -> [PeripheralDevice] {
        var devices: [PeripheralDevice] = []

        // Scan for Thunderbolt endpoint devices (external peripherals)
        let classNames = ["AppleThunderboltNHIType", "IOThunderboltPort"]
        for className in classNames {
            var iterator: io_iterator_t = 0
            guard let matchingDict = IOServiceMatching(className) else { continue }
            let result = IOServiceGetMatchingServices(kIOMainPortDefault, matchingDict, &iterator)
            guard result == KERN_SUCCESS else { continue }

            defer { IOObjectRelease(iterator) }

            while case let service = IOIteratorNext(iterator), service != 0 {
                defer { IOObjectRelease(service) }

                let name = property(service, key: "Description")
                    ?? property(service, key: "Device Name")
                    ?? ioRegistryName(service)
                    ?? ""

                let trimmedName = name.trimmingCharacters(in: .whitespaces)
                guard !trimmedName.isEmpty else { continue }

                // Skip internal host controller entries
                let lower = trimmedName.lowercased()
                if lower.contains("host controller") || lower.contains("nhi") { continue }

                let vendor = property(service, key: "Vendor Name") ?? ""
                let trimmedVendor = vendor.trimmingCharacters(in: .whitespaces)

                let device = PeripheralDevice(
                    id: "thunderbolt-\(trimmedName)-\(trimmedVendor)",
                    name: trimmedName,
                    vendor: trimmedVendor,
                    type: .thunderbolt
                )
                if !devices.contains(where: { $0.id == device.id }) {
                    devices.append(device)
                }
            }
        }

        return devices
    }

    // MARK: - IOKit helpers

    private static func ioRegistryName(_ service: io_object_t) -> String? {
        var nameBuf = [CChar](repeating: 0, count: 128)
        let kr = IORegistryEntryGetName(service, &nameBuf)
        guard kr == KERN_SUCCESS else { return nil }
        let name = String(cString: nameBuf)
        return name.isEmpty ? nil : name
    }

    private static func property(_ service: io_object_t, key: String) -> String? {
        guard let value = IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?
            .takeRetainedValue() else { return nil }
        return value as? String
    }
}
