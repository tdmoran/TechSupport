import Foundation
import OSLog

private let logger = Logger(subsystem: "com.techsupport", category: "SpeedTest")

struct SpeedTestResult: Sendable {
    let downloadMbps: Double
    let uploadMbps: Double?
    let latencyMs: Double

    var formattedDownload: String {
        if downloadMbps < 1 {
            return String(format: "%.2f", downloadMbps)
        }
        return String(format: "%.1f", downloadMbps)
    }

    var formattedUpload: String {
        guard let upload = uploadMbps else { return "—" }
        if upload < 1 {
            return String(format: "%.2f", upload)
        }
        return String(format: "%.1f", upload)
    }

    var formattedLatency: String {
        if latencyMs < 1 { return "<1 ms" }
        return String(format: "%.0f ms", latencyMs)
    }
}

actor SpeedTestService {
    /// URLs used for download speed measurement — small, reliable public files.
    private let downloadURLs: [URL] = [
        URL(string: "https://www.apple.com/library/test/success.html")!,
        URL(string: "https://captive.apple.com/hotspot-detect.html")!,
    ]

    /// Runs a lightweight speed test: measures latency then download throughput.
    /// Throws `CancellationError` if the calling task is cancelled.
    func run() async throws -> SpeedTestResult {
        try Task.checkCancellation()

        // 1. Measure latency via a tiny HEAD request
        let latency = await measureLatency()

        try Task.checkCancellation()

        // 2. Measure download speed
        let downloadMbps = try await measureDownload()

        let result = SpeedTestResult(
            downloadMbps: downloadMbps,
            uploadMbps: nil,
            latencyMs: latency
        )

        logger.info("Speed test complete: \(result.formattedDownload) Mbps down, \(result.formattedLatency) latency")
        return result
    }

    // MARK: - Latency

    private func measureLatency() async -> Double {
        let url = URL(string: "https://www.apple.com")!
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.timeoutInterval = 10

        let session = URLSession(configuration: .ephemeral)
        defer { session.invalidateAndCancel() }

        let start = CFAbsoluteTimeGetCurrent()
        do {
            let _ = try await session.data(for: request)
        } catch {
            logger.warning("Latency measurement failed: \(error.localizedDescription)")
            return 0
        }
        let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000
        return elapsed
    }

    // MARK: - Download

    private func measureDownload() async throws -> Double {
        // Download the Apple captive portal page multiple times to get a more reliable measurement.
        // Each response is small (~227 bytes), so we make many requests in parallel.
        let url = downloadURLs[0]
        let iterations = 20

        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 15
        config.httpMaximumConnectionsPerHost = 6
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel() }

        // Warm up — establish connection
        var warmupRequest = URLRequest(url: url)
        warmupRequest.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        let _ = try? await session.data(for: warmupRequest)

        try Task.checkCancellation()

        // Timed download burst
        let start = CFAbsoluteTimeGetCurrent()
        var totalBytes: Int = 0

        try await withThrowingTaskGroup(of: Int.self) { group in
            for _ in 0..<iterations {
                group.addTask {
                    var request = URLRequest(url: url)
                    request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
                    let (data, _) = try await session.data(for: request)
                    return data.count
                }
            }

            for try await bytes in group {
                totalBytes += bytes
            }
        }

        let elapsed = CFAbsoluteTimeGetCurrent() - start
        guard elapsed > 0 else { return 0 }

        // Convert bytes/sec to Mbps (megabits per second)
        let bytesPerSecond = Double(totalBytes) / elapsed
        let mbps = (bytesPerSecond * 8) / 1_000_000

        return mbps
    }

}
