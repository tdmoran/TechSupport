import Foundation
import Darwin

struct NetworkMonitor: Sendable {
    func currentBytes() -> (sent: UInt64, received: UInt64) {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return (0, 0)
        }
        defer { freeifaddrs(ifaddr) }

        var totalSent: UInt64 = 0
        var totalReceived: UInt64 = 0

        var current: UnsafeMutablePointer<ifaddrs>? = firstAddr
        while let addr = current {
            let name = String(cString: addr.pointee.ifa_name)

            // Skip loopback
            if name != "lo0",
               addr.pointee.ifa_addr.pointee.sa_family == UInt8(AF_LINK) {
                addr.pointee.ifa_data.withMemoryRebound(to: if_data.self, capacity: 1) { data in
                    totalSent += UInt64(data.pointee.ifi_obytes)
                    totalReceived += UInt64(data.pointee.ifi_ibytes)
                }
            }

            current = addr.pointee.ifa_next
        }

        return (totalSent, totalReceived)
    }
}
