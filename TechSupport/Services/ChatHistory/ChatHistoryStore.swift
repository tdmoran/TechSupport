import Foundation
import CryptoKit
import OSLog

private let logger = Logger(subsystem: "com.techsupport", category: "ChatHistoryStore")

@MainActor
final class ChatHistoryStore {
    private let directory: URL
    private(set) var sessionList: [SessionSummary] = []
    private let encryptionKey: SymmetricKey

    struct SessionSummary: Identifiable {
        let id: UUID
        let title: String
        let lastModified: Date
        let messageCount: Int
    }

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        directory = appSupport.appendingPathComponent("TechSupport/chat_history", isDirectory: true)
        encryptionKey = ChatHistoryStore.loadOrCreateKey()
        ensureDirectory()
        loadSessionList()
    }

    private static func loadOrCreateKey() -> SymmetricKey {
        if let keyData = KeychainService.loadData(key: KeychainService.chatEncryptionKey) {
            return SymmetricKey(data: keyData)
        }
        let newKey = SymmetricKey(size: .bits256)
        let keyData = newKey.withUnsafeBytes { Data($0) }
        _ = KeychainService.saveData(key: KeychainService.chatEncryptionKey, data: keyData)
        return newKey
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
            let encrypted = try encrypt(data)
            try encrypted.write(to: fileURL, options: .atomic)
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
            let encryptedData = try Data(contentsOf: fileURL)
            let data = try decrypt(encryptedData)
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
            guard let encryptedData = try? Data(contentsOf: file),
                  let data = try? decrypt(encryptedData),
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

    // MARK: - Encryption

    private func encrypt(_ data: Data) throws -> Data {
        let sealedBox = try AES.GCM.seal(data, using: encryptionKey)
        guard let combined = sealedBox.combined else {
            throw EncryptionError.sealFailed
        }
        return combined
    }

    private func decrypt(_ data: Data) throws -> Data {
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(sealedBox, using: encryptionKey)
    }

    private enum EncryptionError: Error {
        case sealFailed
    }
}
