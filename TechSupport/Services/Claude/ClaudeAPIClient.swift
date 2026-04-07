import Foundation
import OSLog

private let logger = Logger(subsystem: "com.techsupport", category: "ClaudeAPI")

struct ClaudeAPIClient: Sendable {
    private let baseURL = URL(string: "https://api.anthropic.com/v1")!
    private let apiVersion = "2023-06-01"
    private let sseClient: SSEClient
    private let httpClient: HTTPClient
    private let apiKeyProvider: @Sendable () async -> String?

    private static let maxRetries = 3
    private static let retryableStatusCodes: Set<Int> = [429, 500, 502, 503, 529]
    private static let retryableURLErrorCodes: Set<URLError.Code> = [
        .notConnectedToInternet,
        .networkConnectionLost,
        .timedOut,
    ]

    init(
        apiKeyProvider: @escaping @Sendable () async -> String?,
        httpClient: HTTPClient = HTTPClient(),
        sseClient: SSEClient = SSEClient()
    ) {
        self.apiKeyProvider = apiKeyProvider
        self.httpClient = httpClient
        self.sseClient = sseClient
    }

    // MARK: - Retry Logic

    /// Returns the delay in seconds before the next retry, or nil if the error is not retryable.
    private static func retryDelay(for error: Error, attempt: Int) -> TimeInterval? {
        guard attempt < maxRetries else { return nil }

        let baseDelay = pow(2.0, Double(attempt)) // 1s, 2s, 4s
        let jitter = Double.random(in: 0.0...0.5)

        if let appError = error as? AppError {
            switch appError {
            case .apiRateLimited(let retryAfterSeconds):
                return max(Double(retryAfterSeconds), baseDelay) + jitter
            case .apiServerError(let statusCode, _):
                return retryableStatusCodes.contains(statusCode) ? baseDelay + jitter : nil
            case .apiNetworkError:
                return baseDelay + jitter
            default:
                return nil
            }
        }

        if let urlError = error as? URLError,
           retryableURLErrorCodes.contains(urlError.code) {
            return baseDelay + jitter
        }

        return nil
    }

    /// Executes an async operation with automatic retry on transient failures.
    private func withRetry<T>(
        operation: @Sendable () async throws -> T
    ) async throws -> T {
        for attempt in 0...Self.maxRetries {
            do {
                return try await operation()
            } catch {
                if Task.isCancelled { throw error }

                guard let delay = Self.retryDelay(for: error, attempt: attempt) else {
                    throw error
                }

                logger.warning(
                    "Retryable error (attempt \(attempt + 1)/\(Self.maxRetries)): \(error.localizedDescription). Retrying in \(String(format: "%.1f", delay))s"
                )

                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }

        // Unreachable — the last attempt either returns or throws without retry
        fatalError("withRetry exceeded loop bounds")
    }

    // MARK: - Non-Streaming

    func complete(
        model: ClaudeModel,
        system: String,
        messages: [ClaudeMessage],
        maxTokens: Int = 4096
    ) async throws -> ClaudeResponse {
        let apiKey = try await requireAPIKey()
        let sanitized = Self.sanitizeMessages(messages)

        let request = ClaudeMessagesRequest(
            model: model.rawValue,
            maxTokens: maxTokens,
            system: system.isEmpty ? "You are a helpful assistant." : system,
            messages: sanitized,
            stream: false
        )

        return try await withRetry {
            try await httpClient.request(
                url: baseURL.appendingPathComponent("messages"),
                method: .post,
                headers: authHeaders(apiKey: apiKey),
                body: request,
                responseType: ClaudeResponse.self
            )
        }
    }

    // MARK: - Streaming

    func stream(
        model: ClaudeModel,
        system: String,
        messages: [ClaudeMessage],
        maxTokens: Int = 4096
    ) -> AsyncThrowingStream<ClaudeStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let apiKey = try await requireAPIKey()
                    let sanitized = Self.sanitizeMessages(messages)

                    let request = ClaudeMessagesRequest(
                        model: model.rawValue,
                        maxTokens: maxTokens,
                        system: system.isEmpty ? "You are a helpful assistant." : system,
                        messages: sanitized,
                        stream: true
                    )

                    let body = try JSONEncoder().encode(request)
                    logger.debug("Streaming request to model: \(model.rawValue)")

                    // Retry the initial SSE connection on transient failures.
                    // Once connected and streaming, mid-stream failures are not retried.
                    let events = try await withRetry { () -> AsyncThrowingStream<SSEEvent, Error> in
                        let stream = sseClient.stream(
                            url: baseURL.appendingPathComponent("messages"),
                            method: "POST",
                            headers: authHeaders(apiKey: apiKey),
                            body: body
                        )
                        // Attempt to read the first event to verify the connection succeeds.
                        // If the connection fails (e.g. 429, 503), the error surfaces here
                        // so the retry loop can catch it.
                        var iterator = stream.makeAsyncIterator()
                        let firstEvent = try await iterator.next()

                        // Rebuild the stream: yield the first event, then the rest
                        return AsyncThrowingStream { innerContinuation in
                            Task {
                                do {
                                    if let first = firstEvent {
                                        innerContinuation.yield(first)
                                    }
                                    while let event = try await iterator.next() {
                                        if Task.isCancelled { break }
                                        innerContinuation.yield(event)
                                    }
                                    innerContinuation.finish()
                                } catch {
                                    innerContinuation.finish(throwing: error)
                                }
                            }
                        }
                    }

                    for try await event in events {
                        if Task.isCancelled { break }
                        guard let parsed = parseStreamEvent(event) else { continue }
                        continuation.yield(parsed)
                    }

                    continuation.finish()
                } catch {
                    logger.error("Stream error: \(error)")
                    if !Task.isCancelled {
                        continuation.finish(throwing: error)
                    }
                }
            }

            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Helpers

    private static func sanitizeMessages(_ messages: [ClaudeMessage]) -> [ClaudeMessage] {
        messages.map { message in
            let filtered = message.content.compactMap { block -> ClaudeMessage.ContentBlock? in
                if case .text(let text) = block {
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed.isEmpty { return nil }
                    return .text(trimmed)
                }
                return block
            }
            let safeContent = filtered.isEmpty ? [ClaudeMessage.ContentBlock.text("(no content)")] : filtered
            return ClaudeMessage(role: message.role, content: safeContent)
        }
    }

    private func requireAPIKey() async throws -> String {
        guard let key = await apiKeyProvider() else {
            throw AppError.apiKeyMissing
        }
        return key
    }

    private func authHeaders(apiKey: String) -> [String: String] {
        [
            "x-api-key": apiKey,
            "anthropic-version": apiVersion,
            "content-type": "application/json",
        ]
    }

    private func parseStreamEvent(_ event: SSEEvent) -> ClaudeStreamEvent? {
        guard let data = event.data.data(using: .utf8) else { return nil }

        switch event.event {
        case "content_block_delta":
            struct Delta: Decodable {
                let delta: DeltaContent
                struct DeltaContent: Decodable {
                    let type: String
                    let text: String?
                }
            }
            guard let delta = try? JSONDecoder().decode(Delta.self, from: data),
                  delta.delta.type == "text_delta",
                  let text = delta.delta.text else { return nil }
            return .textDelta(text)

        case "message_delta":
            struct MessageDelta: Decodable {
                let usage: Usage?
                struct Usage: Decodable {
                    let outputTokens: Int
                    enum CodingKeys: String, CodingKey {
                        case outputTokens = "output_tokens"
                    }
                }
            }
            guard let parsed = try? JSONDecoder().decode(MessageDelta.self, from: data),
                  let usage = parsed.usage else { return nil }
            return .messageComplete(ClaudeStreamUsage(
                inputTokens: 0,
                outputTokens: usage.outputTokens
            ))

        case "error":
            struct ErrorEvent: Decodable {
                let error: ErrorDetail
                struct ErrorDetail: Decodable {
                    let message: String
                }
            }
            if let parsed = try? JSONDecoder().decode(ErrorEvent.self, from: data) {
                return .error(parsed.error.message)
            }
            return .error("Unknown streaming error")

        default:
            return nil
        }
    }
}
