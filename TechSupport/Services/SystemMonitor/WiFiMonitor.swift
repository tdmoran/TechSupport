import Foundation
import CoreWLAN

struct WiFiInfo: Sendable {
    let ssid: String?
    let txRate: Double // Mbps
    let rssi: Int // dBm
    let noise: Int // dBm
    let channel: Int
    let band: String // "2.4 GHz", "5 GHz", "6 GHz"
    let phyMode: String // "802.11ax", etc.

    var signalQuality: SignalQuality {
        if rssi >= -50 { return .excellent }
        if rssi >= -60 { return .good }
        if rssi >= -70 { return .fair }
        return .poor
    }

    var snr: Int { rssi - noise }

    var formattedSpeed: String {
        if txRate >= 1000 {
            return String(format: "%.1f Gbps", txRate / 1000)
        }
        return String(format: "%.0f Mbps", txRate)
    }

    var formattedSignal: String {
        "\(rssi) dBm"
    }

    enum SignalQuality: String, Sendable {
        case excellent = "Excellent"
        case good = "Good"
        case fair = "Fair"
        case poor = "Poor"

        var icon: String {
            switch self {
            case .excellent: return "wifi"
            case .good: return "wifi"
            case .fair: return "wifi.exclamationmark"
            case .poor: return "wifi.slash"
            }
        }
    }

    static let unavailable = WiFiInfo(
        ssid: nil, txRate: 0, rssi: 0, noise: 0,
        channel: 0, band: "—", phyMode: "—"
    )
}

struct WiFiMonitor: Sendable {
    func currentInfo() -> WiFiInfo? {
        guard let iface = CWWiFiClient.shared().interface() else { return nil }

        let bandString: String
        if let channel = iface.wlanChannel() {
            switch channel.channelBand {
            case .bandUnknown: bandString = "Unknown"
            case .band2GHz: bandString = "2.4 GHz"
            case .band5GHz: bandString = "5 GHz"
            case .band6GHz: bandString = "6 GHz"
            @unknown default: bandString = "Unknown"
            }
        } else {
            bandString = "—"
        }

        let phyString: String
        switch iface.activePHYMode() {
        case .modeNone: phyString = "—"
        case .mode11a: phyString = "802.11a"
        case .mode11b: phyString = "802.11b"
        case .mode11g: phyString = "802.11g"
        case .mode11n: phyString = "802.11n"
        case .mode11ac: phyString = "802.11ac"
        case .mode11ax: phyString = "Wi-Fi 6"
        @unknown default: phyString = "Unknown"
        }

        return WiFiInfo(
            ssid: iface.ssid(),
            txRate: iface.transmitRate(),
            rssi: iface.rssiValue(),
            noise: iface.noiseMeasurement(),
            channel: iface.wlanChannel()?.channelNumber ?? 0,
            band: bandString,
            phyMode: phyString
        )
    }
}
