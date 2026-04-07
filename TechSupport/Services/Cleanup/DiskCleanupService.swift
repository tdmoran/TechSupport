import Foundation
import OSLog

private let logger = Logger(subsystem: "com.techsupport", category: "DiskCleanup")

struct CleanupLocation: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let icon: String
    let size: Int64
    let isDeletable: Bool

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

@Observable
final class DiskCleanupService {
    var locations: [CleanupLocation] = []
    var isScanning = false
    var isCleaning = false
    var lastError: String?

    private let fileManager = FileManager.default

    func scan() {
        guard !isScanning else { return }
        isScanning = true
        lastError = nil

        Task.detached { [weak self] in
            guard let self else { return }
            let scanned = await self.scanLocations()
            await MainActor.run {
                self.locations = scanned
                self.isScanning = false
            }
        }
    }

    func cleanCache() {
        guard !isCleaning else { return }
        isCleaning = true
        lastError = nil

        Task.detached { [weak self] in
            guard let self else { return }
            let cachesPath = NSHomeDirectory() + "/Library/Caches"
            var errors: [String] = []

            do {
                let contents = try self.fileManager.contentsOfDirectory(atPath: cachesPath)
                for item in contents {
                    let itemPath = cachesPath + "/" + item
                    do {
                        try self.fileManager.removeItem(atPath: itemPath)
                    } catch {
                        errors.append(item)
                    }
                }
            } catch {
                errors.append(error.localizedDescription)
            }

            logger.info("Cache cleanup completed with \(errors.count) errors")

            await MainActor.run {
                self.isCleaning = false
                if !errors.isEmpty {
                    self.lastError = "Could not remove \(errors.count) item(s) (in use or protected)"
                }
            }

            self.scan()
        }
    }

    func emptyTrash() {
        guard !isCleaning else { return }
        isCleaning = true
        lastError = nil

        Task.detached { [weak self] in
            guard let self else { return }

            let script = """
            tell application "Finder"
                empty the trash
            end tell
            """

            let appleScript = NSAppleScript(source: script)
            var errorInfo: NSDictionary?
            appleScript?.executeAndReturnError(&errorInfo)

            if let errorInfo {
                let message = errorInfo[NSAppleScript.errorMessage] as? String ?? "Unknown error"
                logger.error("Empty trash failed: \(message)")
                await MainActor.run {
                    self.lastError = "Failed to empty trash: \(message)"
                    self.isCleaning = false
                }
            } else {
                logger.info("Trash emptied successfully")
                await MainActor.run {
                    self.isCleaning = false
                }
            }

            self.scan()
        }
    }

    // MARK: - Private

    private func scanLocations() async -> [CleanupLocation] {
        let home = NSHomeDirectory()
        var results: [CleanupLocation] = []

        let targets: [(String, String, String, Bool)] = [
            ("User Caches", home + "/Library/Caches", "folder.badge.gearshape", true),
            ("Xcode DerivedData", home + "/Library/Developer/Xcode/DerivedData", "hammer", false),
            ("Trash", home + "/.Trash", "trash", true),
            ("Downloads", home + "/Downloads", "arrow.down.circle", false),
            ("System Temp Files", "/private/var/folders", "clock.arrow.circlepath", false),
        ]

        for (name, path, icon, deletable) in targets {
            guard fileManager.fileExists(atPath: path) else { continue }
            let size = directorySize(atPath: path)
            results.append(CleanupLocation(
                name: name,
                path: path,
                icon: icon,
                size: size,
                isDeletable: deletable
            ))
        }

        return results
    }

    private func directorySize(atPath path: String) -> Int64 {
        var totalSize: Int64 = 0

        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles],
            errorHandler: nil
        ) else {
            return 0
        }

        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                  resourceValues.isRegularFile == true,
                  let fileSize = resourceValues.fileSize else {
                continue
            }
            totalSize += Int64(fileSize)
        }

        return totalSize
    }
}
