import Foundation
import OSLog

private let logger = Logger(subsystem: "com.techsupport", category: "ChatHistoryStore")

@MainActor
final class ChatHistoryStore {
    private let directory: URL
    private(set) var sessionList: [SessionSummary] = []

    struct SessionSummary: Identifiable {
        let id: UUID
        let title: String
        let lastModified: Date
        let messageCount: Int
    }

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        directory = appSupport.appendingPathComponent("TechSupport/chat_history", isDirectory: true)
        ensureDirectory()
        loadSessionList()
    }

    // MARK: - Public API

    func save(_ session: ChatSession) {
        guard !session.messages.isEmpty else { return }
        let fileURL = fileURL(for: session.id)
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(session)
            try data.write(to: fileURL, options: .atomic)
            loadSessionList()
            logger.debug("Saved session \(session.id)")
        } catch {
            logger.error("Failed to save session: \(error.localizedDescription)")
        }
    }

    func load(id: UUID) -> ChatSession? {
        let fileURL = fileURL(for: id)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(ChatSession.self, from: data)
        } catch {
            logger.error("Failed to load session \(id): \(error.localizedDescription)")
            return nil
        }
    }

    func loadMostRecent() -> ChatSession? {
        guard let first = sessionList.first else { return nil }
        return load(id: first.id)
    }

    func delete(id: UUID) {
        let fileURL = fileURL(for: id)
        do {
            try FileManager.default.removeItem(at: fileURL)
            loadSessionList()
            logger.debug("Deleted session \(id)")
        } catch {
            logger.error("Failed to delete session \(id): \(error.localizedDescription)")
        }
    }

    // MARK: - Private

    private func fileURL(for id: UUID) -> URL {
        directory.appendingPathComponent("\(id.uuidString).json")
    }

    private func ensureDirectory() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: directory.path) {
            do {
                try fm.createDirectory(at: directory, withIntermediateDirectories: true)
            } catch {
                logger.error("Failed to create history directory: \(error.localizedDescription)")
            }
        }
    }

    private func loadSessionList() {
        let fm = FileManager.default
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        var summaries: [SessionSummary] = []

        guard let files = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
            sessionList = []
            return
        }

        for file in files where file.pathExtension == "json" {
            guard let data = try? Data(contentsOf: file),
                  let session = try? decoder.decode(ChatSession.self, from: data) else {
                continue
            }
            summaries.append(SessionSummary(
                id: session.id,
                title: session.title,
                lastModified: session.lastModified,
                messageCount: session.messages.count
            ))
        }

        sessionList = summaries.sorted { $0.lastModified > $1.lastModified }
    }
}
