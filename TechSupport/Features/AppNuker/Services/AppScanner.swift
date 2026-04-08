import Foundation

/// Scans macOS filesystem for files related to a given app bundle.
struct AppScanner {

    /// All locations to search for app-related files.
    private static func scanLocations(home: URL) -> [(base: URL, category: FileCategory)] {
        [
            (home.appendingPathComponent("Library/Application Support"), .applicationSupport),
            (home.appendingPathComponent("Library/Preferences"), .preferences),
            (home.appendingPathComponent("Library/Caches"), .caches),
            (home.appendingPathComponent("Library/Containers"), .containers),
            (home.appendingPathComponent("Library/Group Containers"), .groupContainers),
            (home.appendingPathComponent("Library/Logs"), .logs),
            (home.appendingPathComponent("Library/Saved Application State"), .savedState),
            (home.appendingPathComponent("Library/WebKit"), .webkitData),
            (home.appendingPathComponent("Library/HTTPStorages"), .httpStorage),
            (home.appendingPathComponent("Library/Cookies"), .cookies),
            (home.appendingPathComponent("Library/Application Scripts"), .applicationScripts),
            (home.appendingPathComponent("Library/SyncedPreferences"), .syncedPreferences),
            (home.appendingPathComponent("Library/LaunchAgents"), .userLaunchAgents),
            (home.appendingPathComponent("Library/Receipts"), .receipts),
            (home.appendingPathComponent("Library/Developer"), .developer),
            (home.appendingPathComponent("Library/Frameworks"), .frameworks),
            (home.appendingPathComponent("Library/Internet Plug-Ins"), .internetPlugins),
            (home.appendingPathComponent("Library/PreferencePanes"), .preferencePanes),
            (home.appendingPathComponent("Library/PrivilegedHelperTools"), .privilegedHelpers),
            (home.appendingPathComponent("Library/Services"), .services),
            (home.appendingPathComponent("Library/InputMethods"), .inputMethods),
            (URL(fileURLWithPath: "/Library/LaunchAgents"), .systemLaunchAgents),
            (URL(fileURLWithPath: "/Library/LaunchDaemons"), .systemLaunchDaemons),
            (URL(fileURLWithPath: "/Library/Application Support"), .systemApplicationSupport),
            (URL(fileURLWithPath: "/Library/Preferences"), .systemPreferences),
            (URL(fileURLWithPath: "/Library/Receipts"), .systemReceipts),
            (URL(fileURLWithPath: "/Library/Frameworks"), .systemFrameworks),
            (URL(fileURLWithPath: "/Library/Internet Plug-Ins"), .systemInternetPlugins),
            (URL(fileURLWithPath: "/Library/PreferencePanes"), .systemPreferencePanes),
            (URL(fileURLWithPath: "/Library/PrivilegedHelperTools"), .systemPrivilegedHelpers),
            (URL(fileURLWithPath: "/Library/Services"), .systemServices),
        ]
    }

    /// Prefixes that indicate Apple/OS-owned files — never delete these.
    private static let protectedPrefixes = [
        "com.apple.", "com.apple-", "group.com.apple.",
    ]

    /// Returns true if the file is an Apple/OS system component that should never be removed.
    private static func isProtectedSystemFile(_ name: String) -> Bool {
        let lower = name.lowercased()
        return protectedPrefixes.contains { lower.hasPrefix($0) }
    }

    /// Check whether a filename matches the bundle ID or app name with a conservative policy.
    ///
    /// This intentionally avoids vendor-level component matching because AppNuker
    /// is destructive and false positives are worse than false negatives.
    private static func matches(name: String, bundleID: String, appName: String) -> Bool {
        let nameLower = name.lowercased()
        let bidLower = bundleID.lowercased()

        // Full bundle ID match — highest confidence
        if nameLower.contains(bidLower) {
            return true
        }

        // Match the display name only when it appears as a complete normalized phrase.
        let normalizedName = normalizedForPhraseMatch(nameLower)
        let normalizedAppName = normalizedForPhraseMatch(appName.lowercased())
        if normalizedAppName.count >= 4 && normalizedName.contains(normalizedAppName) {
            return true
        }

        return false
    }

    private static func normalizedForPhraseMatch(_ value: String) -> String {
        let separators = CharacterSet.alphanumerics.inverted
        let tokens = value
            .components(separatedBy: separators)
            .filter { !$0.isEmpty }
        return " " + tokens.joined(separator: " ") + " "
    }

    /// Scan the filesystem for all files related to the given app.
    /// This is a potentially slow operation — call from a background thread.
    static func scan(bundleID: String, appName: String, appPath: URL) -> [FoundFile] {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        var results: [FoundFile] = []

        // Include the .app bundle itself
        if fm.fileExists(atPath: appPath.path) {
            results.append(FoundFile(
                path: appPath,
                category: .applicationBundle,
                requiresSudo: !fm.isWritableFile(atPath: appPath.path),
                sizeBytes: FoundFile.computeSize(at: appPath)
            ))
        }

        for location in scanLocations(home: home) {
            guard fm.fileExists(atPath: location.base.path) else { continue }

            guard let entries = try? fm.contentsOfDirectory(
                at: location.base,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else { continue }

            for entry in entries {
                let entryName = entry.lastPathComponent
                // Never touch Apple/OS system files
                if isProtectedSystemFile(entryName) { continue }
                if matches(name: entryName, bundleID: bundleID, appName: appName) {
                    results.append(FoundFile(
                        path: entry,
                        category: location.category,
                        requiresSudo: location.category.requiresSudo,
                        sizeBytes: FoundFile.computeSize(at: entry)
                    ))
                }
            }
        }

        // Sort: app bundle first, then by category, then path
        results.sort { a, b in
            if a.category == .applicationBundle && b.category != .applicationBundle { return true }
            if a.category != .applicationBundle && b.category == .applicationBundle { return false }
            if a.category.rawValue != b.category.rawValue {
                return a.category.rawValue < b.category.rawValue
            }
            return a.path.path < b.path.path
        }

        return results
    }
}
