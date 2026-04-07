import AppKit
import Foundation

/// Metadata extracted from a .app bundle.
struct AppInfo: Identifiable {
    let id = UUID()
    let path: URL
    let bundleID: String
    let displayName: String
    let version: String
    let icon: NSImage

    var formattedPath: String {
        path.path
    }
}

extension AppInfo {
    /// Create AppInfo by reading the .app bundle's Info.plist.
    /// Safe to call from any thread — only touches the filesystem and copies the icon.
    static func from(appURL: URL) throws -> AppInfo {
        let plistURL = appURL
            .appendingPathComponent("Contents")
            .appendingPathComponent("Info.plist")

        guard FileManager.default.fileExists(atPath: plistURL.path) else {
            throw AppInfoError.plistNotFound(plistURL.path)
        }

        let data = try Data(contentsOf: plistURL)
        guard let plist = try PropertyListSerialization.propertyList(
            from: data, format: nil
        ) as? [String: Any] else {
            throw AppInfoError.plistParseError
        }

        guard let bundleID = plist["CFBundleIdentifier"] as? String else {
            throw AppInfoError.noBundleID
        }

        let displayName = (plist["CFBundleDisplayName"] as? String)
            ?? (plist["CFBundleName"] as? String)
            ?? appURL.deletingPathExtension().lastPathComponent

        let version = (plist["CFBundleShortVersionString"] as? String) ?? "Unknown"

        // Copy the icon so we don't mutate the shared NSWorkspace instance
        let systemIcon = NSWorkspace.shared.icon(forFile: appURL.path)
        let icon = systemIcon.copy() as! NSImage
        icon.size = NSSize(width: 128, height: 128)

        return AppInfo(
            path: appURL,
            bundleID: bundleID,
            displayName: displayName,
            version: version,
            icon: icon
        )
    }
}

enum AppInfoError: LocalizedError {
    case plistNotFound(String)
    case plistParseError
    case noBundleID

    var errorDescription: String? {
        switch self {
        case .plistNotFound(let path):
            return "Info.plist not found at \(path)"
        case .plistParseError:
            return "Failed to parse Info.plist"
        case .noBundleID:
            return "No CFBundleIdentifier found in Info.plist"
        }
    }
}
