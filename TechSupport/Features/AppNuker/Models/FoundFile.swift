import Foundation

/// A file or directory discovered during scanning, related to the target app.
struct FoundFile: Identifiable, Hashable {
    let id = UUID()
    let path: URL
    let category: FileCategory
    let requiresSudo: Bool
    /// Pre-computed size in bytes. Calculated once during scanning, not on every access.
    let sizeBytes: Int64

    var name: String {
        path.lastPathComponent
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }

    var icon: String {
        switch category {
        case .applicationBundle: return "app.fill"
        case .applicationSupport: return "folder.fill"
        case .preferences: return "gearshape.fill"
        case .caches: return "archivebox.fill"
        case .containers: return "shippingbox.fill"
        case .groupContainers: return "square.stack.3d.up.fill"
        case .logs: return "doc.text.fill"
        case .savedState: return "bookmark.fill"
        case .webkitData: return "globe"
        case .httpStorage: return "network"
        case .cookies: return "circle.grid.cross.fill"
        case .applicationScripts: return "applescript.fill"
        case .syncedPreferences: return "arrow.triangle.2.circlepath"
        case .userLaunchAgents: return "play.circle.fill"
        case .receipts: return "doc.plaintext.fill"
        case .developer: return "hammer.fill"
        case .frameworks: return "puzzlepiece.fill"
        case .internetPlugins: return "puzzlepiece"
        case .preferencePanes: return "slider.horizontal.3"
        case .privilegedHelpers: return "lock.shield.fill"
        case .services: return "wrench.fill"
        case .inputMethods: return "keyboard.fill"
        case .systemLaunchAgents: return "play.circle"
        case .systemLaunchDaemons: return "bolt.circle.fill"
        case .systemApplicationSupport: return "folder.badge.gearshape"
        case .systemPreferences: return "gearshape.2.fill"
        case .systemReceipts: return "doc.plaintext"
        case .systemFrameworks: return "puzzlepiece.fill"
        case .systemInternetPlugins: return "puzzlepiece"
        case .systemPreferencePanes: return "slider.horizontal.3"
        case .systemPrivilegedHelpers: return "lock.shield"
        case .systemServices: return "wrench"
        }
    }

    /// Compute size of a file or directory. Called once during scanning on a background thread.
    static func computeSize(at url: URL) -> Int64 {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else { return 0 }

        if !isDir.boolValue {
            return (try? fm.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
        }

        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: []  // Don't skip hidden files — they count toward real disk usage
        ) else { return 0 }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                  values.isRegularFile == true,
                  let size = values.fileSize else { continue }
            total += Int64(size)
        }
        return total
    }
}

enum FileCategory: String, CaseIterable, Identifiable {
    case applicationBundle = "Application Bundle"
    case applicationSupport = "Application Support"
    case preferences = "Preferences"
    case caches = "Caches"
    case containers = "Containers"
    case groupContainers = "Group Containers"
    case logs = "Logs"
    case savedState = "Saved Application State"
    case webkitData = "WebKit Data"
    case httpStorage = "HTTP Storage"
    case cookies = "Cookies"
    case applicationScripts = "Application Scripts"
    case syncedPreferences = "Synced Preferences"
    case userLaunchAgents = "User Launch Agents"
    case receipts = "Receipts"
    case developer = "Developer"
    case frameworks = "Frameworks"
    case internetPlugins = "Internet Plug-Ins"
    case preferencePanes = "Preference Panes"
    case privilegedHelpers = "Privileged Helpers"
    case services = "Services"
    case inputMethods = "Input Methods"
    case systemLaunchAgents = "System Launch Agents"
    case systemLaunchDaemons = "System Launch Daemons"
    case systemApplicationSupport = "System Application Support"
    case systemPreferences = "System Preferences"
    case systemReceipts = "System Receipts"
    case systemFrameworks = "System Frameworks"
    case systemInternetPlugins = "System Internet Plug-Ins"
    case systemPreferencePanes = "System Preference Panes"
    case systemPrivilegedHelpers = "System Privileged Helpers"
    case systemServices = "System Services"

    var id: String { rawValue }

    var requiresSudo: Bool {
        switch self {
        case .systemLaunchAgents, .systemLaunchDaemons,
             .systemApplicationSupport, .systemPreferences,
             .systemReceipts, .systemFrameworks, .systemInternetPlugins,
             .systemPreferencePanes, .systemPrivilegedHelpers, .systemServices:
            return true
        default:
            return false
        }
    }
}
