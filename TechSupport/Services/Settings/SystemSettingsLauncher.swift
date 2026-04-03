import AppKit

enum SettingsPane: String, CaseIterable, Identifiable, Sendable {
    case general = "com.apple.settings.General"
    case storage = "com.apple.settings.Storage"
    case network = "com.apple.settings.Network"
    case wifi = "com.apple.settings.wifi"
    case bluetooth = "com.apple.settings.Bluetooth"
    case battery = "com.apple.settings.Battery"
    case security = "com.apple.settings.PrivacySecurity"
    case notifications = "com.apple.settings.Notifications"
    case displays = "com.apple.settings.Displays"
    case sound = "com.apple.settings.Sound"
    case keyboard = "com.apple.settings.Keyboard"
    case softwareUpdate = "com.apple.settings.SoftwareUpdate"
    case timeMachine = "com.apple.settings.TimeMachine"
    case accessibility = "com.apple.settings.Accessibility"
    case loginItems = "com.apple.settings.LoginItems"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .general: return "General"
        case .storage: return "Storage"
        case .network: return "Network"
        case .wifi: return "Wi-Fi"
        case .bluetooth: return "Bluetooth"
        case .battery: return "Battery"
        case .security: return "Privacy & Security"
        case .notifications: return "Notifications"
        case .displays: return "Displays"
        case .sound: return "Sound"
        case .keyboard: return "Keyboard"
        case .softwareUpdate: return "Software Update"
        case .timeMachine: return "Time Machine"
        case .accessibility: return "Accessibility"
        case .loginItems: return "Login Items"
        }
    }

    var icon: String {
        switch self {
        case .general: return "gear"
        case .storage: return "internaldrive"
        case .network: return "network"
        case .wifi: return "wifi"
        case .bluetooth: return "dot.radiowaves.left.and.right"
        case .battery: return "battery.100"
        case .security: return "hand.raised"
        case .notifications: return "bell"
        case .displays: return "display"
        case .sound: return "speaker.wave.3"
        case .keyboard: return "keyboard"
        case .softwareUpdate: return "arrow.triangle.2.circlepath"
        case .timeMachine: return "clock.arrow.circlepath"
        case .accessibility: return "accessibility"
        case .loginItems: return "person.crop.circle"
        }
    }
}

enum SystemSettingsLauncher {
    static func open(_ pane: SettingsPane) {
        let urlString = "x-apple.systempreferences:\(pane.rawValue)"
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }
}
