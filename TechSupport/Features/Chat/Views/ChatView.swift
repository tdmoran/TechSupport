import SwiftUI

struct ChatView: View {
    @Bindable var viewModel: ChatViewModel
    @State private var showDiagnosticPicker = false

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
                showDiagnosticPicker = true
            } label: {
                Image(systemName: "stethoscope")
            }
            .help("Run Diagnostics")
            .popover(isPresented: $showDiagnosticPicker) {
                diagnosticPicker
            }

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
                    Task { await viewModel.send() }
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
