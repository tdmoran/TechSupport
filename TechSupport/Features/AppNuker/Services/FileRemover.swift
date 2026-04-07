import Foundation

/// Result of attempting to remove a file or directory.
struct RemovalResult: Identifiable {
    let id = UUID()
    let path: URL
    let success: Bool
    let freedBytes: Int64
    let error: String?
}

/// Handles removing app-related files from disk.
/// Uses Trash by default (reversible). Falls back to direct removal for sudo items.
struct FileRemover {

    /// Move a single file or directory to Trash, or sudo-remove if elevated permissions needed.
    static func remove(_ file: FoundFile) -> RemovalResult {
        let fm = FileManager.default
        let path = file.path
        let size = file.sizeBytes

        guard fm.fileExists(atPath: path.path) else {
            return RemovalResult(path: path, success: true, freedBytes: 0, error: nil)
        }

        if file.requiresSudo {
            return sudoRemove(path: path, freedBytes: size)
        }

        return trashItem(path: path, freedBytes: size)
    }

    /// Move to Trash (reversible). Preferred for user-level files.
    private static func trashItem(path: URL, freedBytes: Int64) -> RemovalResult {
        do {
            try FileManager.default.trashItem(at: path, resultingItemURL: nil)
            return RemovalResult(path: path, success: true, freedBytes: freedBytes, error: nil)
        } catch {
            return RemovalResult(path: path, success: false, freedBytes: 0, error: error.localizedDescription)
        }
    }

    /// Remove using elevated permissions via AppleScript.
    /// Uses proper escaping to prevent injection through filenames containing quotes.
    private static func sudoRemove(path: URL, freedBytes: Int64) -> RemovalResult {
        // Escape for the shell layer (single-quote wrapping)
        let shellSafe = path.path.shellEscaped
        // Escape for the AppleScript string layer (backslash double-quotes)
        let appleScriptSafe = shellSafe.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let script = "do shell script \"rm -rf \(appleScriptSafe)\" with administrator privileges"

        guard let appleScript = NSAppleScript(source: script) else {
            return RemovalResult(path: path, success: false, freedBytes: 0, error: "Failed to create AppleScript")
        }

        var errorInfo: NSDictionary?
        appleScript.executeAndReturnError(&errorInfo)

        if let error = errorInfo {
            let message = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"
            return RemovalResult(path: path, success: false, freedBytes: 0, error: message)
        }

        return RemovalResult(path: path, success: true, freedBytes: freedBytes, error: nil)
    }

    /// Remove all selected files, returning results for each.
    static func removeAll(_ files: [FoundFile]) -> [RemovalResult] {
        files.map { remove($0) }
    }
}

private extension String {
    /// Escape a string for safe use in a shell command (single-quote wrapping).
    var shellEscaped: String {
        "'" + replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
