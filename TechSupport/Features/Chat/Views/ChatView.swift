import SwiftUI

struct ChatView: View {
    @Bindable var viewModel: ChatViewModel
    @State private var showDiagnosticPicker = false
    @State private var showHistory = false

    var body: some View {
        VStack(spacing: 0) {
            chatHeader
            Divider()
            messagesArea
            Divider()
            inputArea
        }
    }

    private var chatHeader: some View {
        HStack {
            Picker("Model", selection: $viewModel.selectedModel) {
                ForEach(ClaudeModel.allCases) { model in
                    Text(model.displayName).tag(model)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 140)

            Spacer()

            Button {
                showHistory = true
            } label: {
                Image(systemName: "clock.arrow.circlepath")
            }
            .help("Chat History")
            .popover(isPresented: $showHistory) {
                historyPopover
            }

            Button {
                showDiagnosticPicker = true
            } label: {
                Image(systemName: "stethoscope")
            }
            .help("Run Diagnostics")
            .popover(isPresented: $showDiagnosticPicker) {
                diagnosticPicker
            }

            Button {
                viewModel.newSession()
            } label: {
                Image(systemName: "square.and.pencil")
            }
            .help("New Chat")

            Button {
                viewModel.clearSession()
            } label: {
                Image(systemName: "trash")
            }
            .help("Clear Chat")
        }
        .padding(.horizontal, Theme.Spacing.large)
        .padding(.vertical, Theme.Spacing.medium)
    }

    private var messagesArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if viewModel.session.messages.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: Theme.Spacing.medium) {
                        ForEach(viewModel.session.messages) { message in
                            MessageBubbleView(message: message)
                                .id(message.id)
                        }
                    }
                    .padding(Theme.Spacing.large)
                }
            }
            .onChange(of: viewModel.session.messages.count) {
                if let lastID = viewModel.session.messages.last?.id {
                    withAnimation {
                        proxy.scrollTo(lastID, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.large) {
            Spacer()
            Image(systemName: "wrench.and.screwdriver")
                .font(.system(size: 48))
                .foregroundStyle(Theme.Colors.textSecondary)

            Text("TechSupport")
                .font(Theme.Fonts.title)
                .foregroundStyle(Theme.Colors.textPrimary)

            Text("Ask me about any Mac issue. I can see your system stats in real time.")
                .font(Theme.Fonts.body)
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.xlarge)

            VStack(spacing: Theme.Spacing.medium) {
                suggestedPrompt("Why is my Mac running slow?")
                suggestedPrompt("Check my disk space")
                suggestedPrompt("Diagnose network issues")
                suggestedPrompt("How do I free up memory?")
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func suggestedPrompt(_ text: String) -> some View {
        Button {
            viewModel.inputText = text
            Task { await viewModel.send() }
        } label: {
            Text(text)
                .font(Theme.Fonts.body)
                .padding(.horizontal, Theme.Spacing.large)
                .padding(.vertical, Theme.Spacing.medium)
                .glassBackground()
        }
        .buttonStyle(.plain)
    }

    private var inputArea: some View {
        VStack(spacing: Theme.Spacing.small) {
            if let error = viewModel.error {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                    Text(error.localizedDescription)
                    Spacer()
                    Button("Dismiss") { viewModel.clearError() }
                        .buttonStyle(.borderless)
                }
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.statusRed)
                .padding(.horizontal, Theme.Spacing.large)
                .padding(.top, Theme.Spacing.small)
            }

            HStack(spacing: Theme.Spacing.medium) {
                TextField("Describe your issue...", text: $viewModel.inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...5)
                    .onSubmit {
                        Task { await viewModel.send() }
                    }

                Button {
                    if viewModel.isStreaming {
                        viewModel.stopStreaming()
                    } else {
                        Task { await viewModel.send() }
                    }
                } label: {
                    Image(systemName: viewModel.isStreaming ? "stop.circle.fill" : "arrow.up.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(
                            viewModel.inputText.isEmpty && !viewModel.isStreaming
                                ? Theme.Colors.textSecondary
                                : Theme.Colors.accent
                        )
                }
                .buttonStyle(.plain)
                .disabled(viewModel.inputText.isEmpty && !viewModel.isStreaming)
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding(Theme.Spacing.large)
        }
    }

    private var historyPopover: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
            Text("Chat History")
                .font(Theme.Fonts.title)
                .padding(.bottom, Theme.Spacing.small)

            if viewModel.historyStore.sessionList.isEmpty {
                Text("No past sessions")
                    .font(Theme.Fonts.body)
                    .foregroundStyle(Theme.Colors.textSecondary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xsmall) {
                        ForEach(viewModel.historyStore.sessionList) { summary in
                            HStack {
                                Button {
                                    viewModel.loadSession(id: summary.id)
                                    showHistory = false
                                } label: {
                                    VStack(alignment: .leading, spacing: Theme.Spacing.xxsmall) {
                                        Text(summary.title)
                                            .font(Theme.Fonts.body)
                                            .foregroundStyle(
                                                summary.id == viewModel.session.id
                                                    ? Theme.Colors.accent
                                                    : Theme.Colors.textPrimary
                                            )
                                            .lineLimit(1)
                                        Text("\(summary.messageCount) messages - \(summary.lastModified.formatted(.relative(presentation: .named)))")
                                            .font(Theme.Fonts.caption)
                                            .foregroundStyle(Theme.Colors.textSecondary)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)

                                Button {
                                    viewModel.deleteSession(id: summary.id)
                                } label: {
                                    Image(systemName: "xmark.circle")
                                        .foregroundStyle(Theme.Colors.textTertiary)
                                }
                                .buttonStyle(.plain)
                                .help("Delete")
                            }
                            .padding(.vertical, Theme.Spacing.xsmall)
                            .padding(.horizontal, Theme.Spacing.small)
                            .background(
                                summary.id == viewModel.session.id
                                    ? Theme.Colors.accentSubtle
                                    : Color.clear,
                                in: RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                            )
                        }
                    }
                }
                .frame(maxHeight: 300)
            }
        }
        .padding(Theme.Spacing.large)
        .frame(width: 280)
    }

    private var diagnosticPicker: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
            Text("Run Diagnostics")
                .font(Theme.Fonts.title)
                .padding(.bottom, Theme.Spacing.small)

            ForEach(DiagnosticCategory.allCases) { category in
                Button {
                    showDiagnosticPicker = false
                    Task { await viewModel.runDiagnostics(category: category) }
                } label: {
                    Label(category.rawValue, systemImage: category.icon)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Theme.Spacing.large)
    }
}
