import XCTest
@testable import TechSupport

final class AppNukerRegressionTests: XCTestCase {
    private var createdURLs: [URL] = []

    override func tearDownWithError() throws {
        let fileManager = FileManager.default
        for url in createdURLs.reversed() {
            try? fileManager.removeItem(at: url)
        }
        createdURLs.removeAll()
    }

    func testScannerPrefersBundleIDAndRejectsVendorOnlyMatches() throws {
        let appURL = try makeTestAppBundle(
            name: "Product.app",
            bundleID: "com.vendor.product",
            displayName: "Product"
        )

        let matchingURL = try makeHomeLibraryItem(
            relativePath: "Library/Caches/com.vendor.product.cache"
        )
        let vendorOnlyURL = try makeHomeLibraryItem(
            relativePath: "Library/Caches/vendor-shared.cache"
        )

        let files = AppScanner.scan(
            bundleID: "com.vendor.product",
            appName: "Product",
            appPath: appURL
        )

        XCTAssertTrue(files.contains { $0.path.path == appURL.path })
        XCTAssertTrue(files.contains { $0.path.path == matchingURL.path })
        XCTAssertFalse(files.contains { $0.path.path == vendorOnlyURL.path })
    }

    @MainActor
    func testLoadAppDoesNotPreselectSudoItems() async throws {
        let viewModel = AppnukerViewModel()
        let appURL = URL(fileURLWithPath: "/System/Applications/Calculator.app")

        viewModel.loadApp(at: appURL)

        let timeout = Date().addingTimeInterval(5)
        while viewModel.state == .scanning && Date() < timeout {
            try await Task.sleep(for: .milliseconds(100))
        }

        guard viewModel.state == .results else {
            XCTFail("Expected scan results, got \(viewModel.state)")
            return
        }

        XCTAssertFalse(viewModel.foundFiles.isEmpty)
        XCTAssertTrue(viewModel.foundFiles.contains(where: \.requiresSudo))
        XCTAssertTrue(viewModel.selectedFileIDs.isDisjoint(with: Set(viewModel.foundFiles.filter(\.requiresSudo).map(\.id))))
    }

    private func makeTestAppBundle(name: String, bundleID: String, displayName: String) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let contentsURL = root
            .appendingPathComponent(name, isDirectory: true)
            .appendingPathComponent("Contents", isDirectory: true)

        try FileManager.default.createDirectory(at: contentsURL, withIntermediateDirectories: true)

        let plistURL = contentsURL.appendingPathComponent("Info.plist")
        let plist: [String: Any] = [
            "CFBundleIdentifier": bundleID,
            "CFBundleDisplayName": displayName,
            "CFBundleName": displayName,
            "CFBundleShortVersionString": "1.0",
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: plistURL)

        createdURLs.append(root)
        return root.appendingPathComponent(name, isDirectory: true)
    }

    private func makeHomeLibraryItem(relativePath: String) throws -> URL {
        let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("test".utf8).write(to: url)
        createdURLs.append(url)
        return url
    }
}
