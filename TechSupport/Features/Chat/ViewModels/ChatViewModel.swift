import Foundation
import OSLog

private let logger = Logger(subsystem: "com.techsupport", category: "ChatViewModel")

@Observable
@MainActor
final class ChatViewModel {
    private(set) var session = ChatSession()
    var inputText = ""
    private(set) var isStreaming = false
    private(set) var error: AppError?
    var selectedModel: ClaudeModel

    private let claudeClient: ClaudeAPIClient
    private let monitorService: SystemMonitorService
    private let promptBuilder = SystemPromptBuilder()
    private let diagnosticRunner = DiagnosticRunner()
    let historyStore = ChatHistoryStore()
    private(set) var diagnosticResults: [DiagnosticResult] = []
    private let userSettings: UserSettings?
    private var streamingTask: Task<Void, Never>?

    init(claudeClient: ClaudeAPIClient, monitorService: SystemMonitorService, settings: UserSettings? = nil) {
        self.claudeClient = claudeClient
        self.monitorService = monitorService
        self.userSettings = settings
        self.selectedModel = settings?.preferredModel ?? AppConstants.defaultModel

        if let lastSession = historyStore.loadMostRecent() {
            session = lastSession
        }
    }

    func send() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isStreaming else { return }

        inputText = ""
        error = nil

        let metrics = monitorService.snapshot()
        let userMessage = ChatMessage(role: .user, content: text, systemContext: metrics)
        session = session.appending(userMessage)

        let systemPrompt = promptBuilder.buildPrompt(
            metrics: metrics,
            diagnosticResults: diagnosticResults.isEmpty ? nil : diagnosticResults
        )

        let maxHistory = userSettings?.historySize ?? AppConstants.maxChatHistory
        let truncated = session.truncatedToLast(maxHistory)
        let claudeMessages = truncated.claudeMessages

        isStreaming = true
        var assistantText = ""
        let placeholderMessage = ChatMessage(role: .assistant, content: "...")
        session = session.appending(placeholderMessage)

        streamingTask = Task { @MainActor [weak self] in
            guard let self else { return }

            defer {
                if assistantText.isEmpty {
                    let withoutPlaceholder = Array(self.session.messages.dropLast())
                    self.session = ChatSession(id: self.session.id, messages: withoutPlaceholder, createdAt: self.session.createdAt)
                }

                self.isStreaming = false
                self.streamingTask = nil
                self.historyStore.save(self.session)
            }

            do {
                let stream = self.claudeClient.stream(
                    model: self.selectedModel,
                    system: systemPrompt,
                    messages: claudeMessages,
                    maxTokens: 4096
                )

                for try await event in stream {
                    switch event {
                    case .textDelta(let delta):
                        assistantText += delta
                        let updated = ChatMessage(
                            id: placeholderMessage.id,
                            role: .assistant,
                            content: assistantText
                        )
                        self.session = self.session.replacingLast(with: updated)

                    case .messageComplete:
                        logger.debug("Message complete")

                    case .error(let message):
                        logger.error("Stream error: \(message)")
                        self.error = .apiResponseInvalid(detail: message)
                    }
                }
            } catch is CancellationError {
                logger.debug("Chat stream cancelled")
            } catch let appError as AppError {
                self.error = appError
                logger.error("Chat error: \(appError.localizedDescription)")
            } catch {
                self.error = .apiNetworkError(error.localizedDescription)
                logger.error("Chat error: \(error.localizedDescription)")
            }
        }

        await streamingTask?.value
    }

    func stopStreaming() {
        streamingTask?.cancel()
    }

    func runDiagnostics(category: DiagnosticCategory) async {
        let commands = DiagnosticCatalog.commands(for: category)
        for command in commands {
            do {
                let result = try await diagnosticRunner.run(command)
                diagnosticResults.append(result)
            } catch {
                logger.error("Diagnostic failed: \(error.localizedDescription)")
            }
        }
    }

    func clearSession() {
        session = ChatSession()
        diagnosticResults = []
        error = nil
    }

    func newSession() {
        session = ChatSession()
        diagnosticResults = []
        error = nil
    }

    func loadSession(id: UUID) {
        guard let loaded = historyStore.load(id: id) else { return }
        session = loaded
        diagnosticResults = []
        error = nil
    }

    func deleteSession(id: UUID) {
        historyStore.delete(id: id)
        if session.id == id {
            newSession()
        }
    }

    func clearError() {
        error = nil
    }
}
