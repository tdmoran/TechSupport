import AppKit
import Foundation

/// Sort order for the file list.
enum SortOrder: String, CaseIterable, Identifiable {
    case category = "Category"
    case sizeDesc = "Size (Largest First)"
    case sizeAsc = "Size (Smallest First)"
    case name = "Name"

    var id: String { rawValue }
}

/// Main view model driving the Appnuker UI.
@MainActor
final class AppnukerViewModel: ObservableObject {

    enum State: Equatable {
        case idle
        case scanning
        case results
        case removing
        case done
        case error(String)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var appInfo: AppInfo?
    @Published private(set) var foundFiles: [FoundFile] = []
    @Published private(set) var selectedFileIDs: Set<UUID> = []
    @Published private(set) var removalResults: [RemovalResult] = []
    @Published private(set) var selectedFile: FoundFile?
    @Published var searchText: String = ""
    @Published var sortOrder: SortOrder = .category

    /// Window title derived from current state.
    var windowTitle: String {
        switch state {
        case .idle:
            return "Appnuker"
        case .scanning:
            return appInfo.map { "Scanning \($0.displayName)..." } ?? "Scanning..."
        case .results:
            return appInfo.map { "\($0.displayName) — \(foundFiles.count) items" } ?? "Appnuker"
        case .removing:
            return "Removing..."
        case .done:
            return "Cleanup Complete"
        case .error:
            return "Appnuker"
        }
    }

    /// Files filtered by search text, then sorted.
    var displayFiles: [FoundFile] {
        let filtered: [FoundFile]
        if searchText.isEmpty {
            filtered = foundFiles
        } else {
            let query = searchText.lowercased()
            filtered = foundFiles.filter { file in
                file.name.lowercased().contains(query)
                || file.category.rawValue.lowercased().contains(query)
                || file.path.path.lowercased().contains(query)
            }
        }

        switch sortOrder {
        case .category:
            return filtered.sorted { a, b in
                if a.category == .applicationBundle && b.category != .applicationBundle { return true }
                if a.category != .applicationBundle && b.category == .applicationBundle { return false }
                if a.category.rawValue != b.category.rawValue {
                    return a.category.rawValue < b.category.rawValue
                }
                return a.path.path < b.path.path
            }
        case .sizeDesc:
            return filtered.sorted { $0.sizeBytes > $1.sizeBytes }
        case .sizeAsc:
            return filtered.sorted { $0.sizeBytes < $1.sizeBytes }
        case .name:
            return filtered.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }

    var totalSize: Int64 {
        foundFiles.reduce(0) { $0 + $1.sizeBytes }
    }

    var selectedSize: Int64 {
        foundFiles
            .filter { selectedFileIDs.contains($0.id) }
            .reduce(0) { $0 + $1.sizeBytes }
    }

    var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }

    var formattedSelectedSize: String {
        ByteCountFormatter.string(fromByteCount: selectedSize, countStyle: .file)
    }

    var selectedCount: Int {
        selectedFileIDs.count
    }

    var hasSelection: Bool {
        !selectedFileIDs.isEmpty
    }

    var totalFreedBytes: Int64 {
        removalResults.filter(\.success).reduce(0) { $0 + $1.freedBytes }
    }

    var formattedFreedSize: String {
        ByteCountFormatter.string(fromByteCount: totalFreedBytes, countStyle: .file)
    }

    // MARK: - Actions

    func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        if provider.canLoadObject(ofClass: URL.self) {
            _ = provider.loadObject(ofClass: URL.self) { [weak self] url, error in
                guard let url, error == nil else { return }
                Task { @MainActor in
                    self?.loadApp(at: url)
                }
            }
            return true
        }

        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { [weak self] data, _ in
            guard let data = data as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
            Task { @MainActor in
                self?.loadApp(at: url)
            }
        }
        return true
    }

    func loadApp(at url: URL) {
        guard url.pathExtension == "app" else {
            state = .error("Please drop a .app bundle")
            return
        }

        state = .scanning
        foundFiles = []
        selectedFileIDs = []
        removalResults = []
        selectedFile = nil
        searchText = ""
        sortOrder = .category

        Task.detached {
            do {
                let info = try AppInfo.from(appURL: url)
                let files = AppScanner.scan(
                    bundleID: info.bundleID,
                    appName: info.displayName,
                    appPath: info.path
                )
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.appInfo = info
                    self.foundFiles = files
                    self.selectedFileIDs = Set(
                        files
                            .filter { !$0.requiresSudo || $0.category == .applicationBundle }
                            .map(\.id)
                    )
                    self.state = .results
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.state = .error(error.localizedDescription)
                }
            }
        }
    }

    func selectFile(_ file: FoundFile) {
        selectedFile = file
    }

    func toggleFile(_ file: FoundFile) {
        if selectedFileIDs.contains(file.id) {
            selectedFileIDs.remove(file.id)
        } else {
            selectedFileIDs.insert(file.id)
        }
    }

    func selectAll() {
        selectedFileIDs = Set(foundFiles.map(\.id))
    }

    func deselectAll() {
        selectedFileIDs = []
    }

    func selectUserFilesOnly() {
        selectedFileIDs = Set(
            foundFiles.filter { !$0.requiresSudo }.map(\.id)
        )
    }

    func removeSelected() {
        let filesToRemove = foundFiles.filter { selectedFileIDs.contains($0.id) }
        guard !filesToRemove.isEmpty else { return }

        state = .removing

        Task.detached { [filesToRemove] in
            let results = FileRemover.removeAll(filesToRemove)
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.removalResults = results
                let removedPaths = Set(
                    results.filter(\.success).map(\.path.path)
                )
                self.foundFiles = self.foundFiles.filter { !removedPaths.contains($0.path.path) }
                self.selectedFileIDs = self.selectedFileIDs.intersection(Set(self.foundFiles.map(\.id)))
                self.state = .done
            }
        }
    }

    func reset() {
        state = .idle
        appInfo = nil
        foundFiles = []
        selectedFileIDs = []
        removalResults = []
        selectedFile = nil
        searchText = ""
        sortOrder = .category
    }
}
