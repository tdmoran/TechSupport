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

    /// Allowed root directories for removal. Paths outside these are rejected.
    private static let allowedRoots: [String] = [
        NSHomeDirectory(),
        "/Library"
    ]

    /// Validate that a path is safe for removal:
    /// - Must not contain path traversal components (..)
    /// - Must resolve (via realpath) to a location under an allowed root
    /// - Must not be a symbolic link (TOCTOU mitigation)
    private static func validatePath(_ url: URL) -> String? {
        let rawPath = url.path

        // Reject paths with traversal components
        let components = (rawPath as NSString).pathComponents
        if components.contains("..") {
            return "Path contains directory traversal (..)"
        }

        // Resolve symlinks to get the canonical path
        let resolved = (rawPath as NSString).resolvingSymlinksInPath

        // Ensure the resolved path is under an allowed root
        let isUnderAllowedRoot = allowedRoots.contains { root in
            resolved.hasPrefix(root + "/") || resolved == root
        }
        guard isUnderAllowedRoot else {
            return "Path resolves outside allowed directories: \(resolved)"
        }

        // Check that the item is not a symbolic link (TOCTOU mitigation)
        let fm = FileManager.default
        do {
            let attrs = try fm.attributesOfItem(atPath: rawPath)
            if let fileType = attrs[.type] as? FileAttributeType, fileType == .typeSymbolicLink {
                return "Refusing to remove symbolic link: \(rawPath)"
            }
        } catch {
            // If we can't stat the item, it may have been removed already
            return "Cannot verify file attributes: \(error.localizedDescription)"
        }

        return nil
    }

    /// Move a single file or directory to Trash, or sudo-remove if elevated permissions needed.
    static func remove(_ file: FoundFile) -> RemovalResult {
        let fm = FileManager.default
        let path = file.path
        let size = file.sizeBytes

        guard fm.fileExists(atPath: path.path) else {
            return RemovalResult(path: path, success: true, freedBytes: 0, error: nil)
        }

        // Validate the path is safe before any removal
        if let validationError = validatePath(path) {
            return RemovalResult(path: path, success: false, freedBytes: 0, error: validationError)
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
        // Re-validate immediately before removal (TOCTOU mitigation)
        if let validationError = validatePath(path) {
            return RemovalResult(path: path, success: false, freedBytes: 0, error: validationError)
        }

        // Escape for the shell layer (single-quote wrapping)
        let shellSafe = path.path.shellEscaped
        // Escape for the AppleScript string layer:
        // IMPORTANT: Escape double-quotes FIRST, then backslashes, to prevent
        // crafted filenames (e.g. foo\"bar) from breaking out of quoting.
        let appleScriptSafe = shellSafe.replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\\", with: "\\\\")

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
