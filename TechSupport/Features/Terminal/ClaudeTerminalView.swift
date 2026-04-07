import SwiftUI
import SwiftTerm

struct ClaudeTerminalView: View {
    @State private var coordinator = TerminalCoordinator()
    @State private var claudeStatus = ClaudeAuthStatus.checking
    @State private var isInstalledOnSystem = false

    var body: some View {
        VStack(spacing: 0) {
            // Header bar
            HStack(spacing: Theme.Spacing.medium) {
                HStack(spacing: Theme.Spacing.xsmall) {
                    Circle()
                        .fill(claudeStatus.isLoggedIn ? Theme.Colors.statusGreen : Theme.Colors.statusRed)
                        .frame(width: 7, height: 7)
                    Text("Claude Code")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.Colors.textPrimary)
                }

                if case .loggedIn(let email) = claudeStatus {
                    Text(email)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(Theme.Colors.textTertiary)
                }

                Spacer()

                if !isInstalledOnSystem {
                    Link(destination: URL(string: "https://docs.anthropic.com/en/docs/claude-code/getting-started")!) {
                        HStack(spacing: Theme.Spacing.xsmall) {
                            Image(systemName: "arrow.down.circle")
                                .font(.system(size: 10, weight: .semibold))
                            Text("Install Claude Code")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundStyle(Theme.Colors.accent)
                    }
                } else if claudeStatus == .notLoggedIn {
                    Button {
                        coordinator.sendLoginCommand()
                    } label: {
                        HStack(spacing: Theme.Spacing.xsmall) {
                            Image(systemName: "person.badge.key")
                                .font(.system(size: 10, weight: .semibold))
                            Text("Sign In")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundStyle(Theme.Colors.accent)
                        .padding(.horizontal, Theme.Spacing.medium)
                        .padding(.vertical, Theme.Spacing.xsmall)
                        .background(
                            Theme.Colors.accentSubtle,
                            in: RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.Spacing.large)
            .padding(.vertical, Theme.Spacing.medium)
            .background(Theme.Colors.surface)
            .overlay(alignment: .bottom) {
                Theme.Colors.divider.frame(height: 1)
            }

            // Terminal — contained in upper portion
            TerminalContainer(coordinator: coordinator)
                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                        .strokeBorder(Theme.Colors.surfaceBorder, lineWidth: 1)
                )
                .padding(.horizontal, Theme.Spacing.large)
                .padding(.top, Theme.Spacing.medium)

            // Bottom panel with action button
            VStack(spacing: Theme.Spacing.medium) {
                Button {
                    coordinator.sendAnalysePrompt()
                } label: {
                    HStack(spacing: Theme.Spacing.small) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Analyse this machine and see how it can be optimised")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.medium)
                    .background(
                        Theme.Colors.accentSubtle,
                        in: RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                            .strokeBorder(Theme.Colors.accent.opacity(0.25), lineWidth: 1)
                    )
                    .foregroundStyle(Theme.Colors.accent)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Theme.Spacing.large)
            .padding(.vertical, Theme.Spacing.medium)
        }
        .onAppear {
            checkClaudeStatus()
        }
    }

    private func checkClaudeStatus() {
        let path = TerminalCoordinator.claudePath
        isInstalledOnSystem = FileManager.default.isExecutableFile(atPath: path) || path == "claude"

        // Check if claude is actually reachable
        if !isInstalledOnSystem {
            // Try which claude
            let whichProcess = Process()
            let whichPipe = Pipe()
            whichProcess.executableURL = URL(fileURLWithPath: "/bin/zsh")
            whichProcess.arguments = ["-l", "-c", "which claude 2>/dev/null"]
            whichProcess.standardOutput = whichPipe
            whichProcess.standardError = whichPipe
            try? whichProcess.run()
            whichProcess.waitUntilExit()
            let whichData = whichPipe.fileHandleForReading.readDataToEndOfFile()
            let whichResult = String(data: whichData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            isInstalledOnSystem = !whichResult.isEmpty && whichProcess.terminationStatus == 0
        }

        guard isInstalledOnSystem else {
            claudeStatus = .notInstalled
            return
        }

        Task.detached {
            let process = Process()
            let pipe = Pipe()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-l", "-c", "\(TerminalCoordinator.claudePath) auth status 2>&1"]
            process.standardOutput = pipe
            process.standardError = pipe
            try? process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""

            await MainActor.run {
                if output.contains("\"loggedIn\": true") || output.contains("\"loggedIn\":true") {
                    // Extract email
                    if let emailRange = output.range(of: "\"email\": \""),
                       let endRange = output[emailRange.upperBound...].range(of: "\"") {
                        let email = String(output[emailRange.upperBound..<endRange.lowerBound])
                        claudeStatus = .loggedIn(email: email)
                    } else {
                        claudeStatus = .loggedIn(email: "")
                    }
                } else {
                    claudeStatus = .notLoggedIn
                }
            }
        }
    }
}

// MARK: - Auth Status

enum ClaudeAuthStatus: Equatable {
    case checking
    case notInstalled
    case notLoggedIn
    case loggedIn(email: String)

    var isLoggedIn: Bool {
        if case .loggedIn = self { return true }
        return false
    }
}

// MARK: - Shared Coordinator

class TerminalCoordinator: NSObject, LocalProcessTerminalViewDelegate {
    static let analysePrompt = "Analyse this machine and see how it can be optimised"

    /// Finds the claude binary by checking common install locations
    static var claudePath: String {
        let candidates = [
            "\(NSHomeDirectory())/.local/bin/claude",
            "/usr/local/bin/claude",
            "\(NSHomeDirectory())/.claude/local/claude",
            "/opt/homebrew/bin/claude",
        ]
        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        // Fall back to letting the shell find it via PATH
        return "claude"
    }

    weak var terminalView: LocalProcessTerminalView?

    func sendAnalysePrompt() {
        guard let tv = terminalView else { return }
        tv.send(txt: Self.analysePrompt)
        tv.send(txt: "\r")
    }

    func sendLoginCommand() {
        guard let tv = terminalView else { return }
        // Send Ctrl+C first to interrupt any running process, then login
        tv.send(txt: "\u{0003}")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            tv.send(txt: "/login\r")
        }
    }

    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}
    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {}
    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}

    func processTerminated(source: TerminalView, exitCode: Int32?) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            guard let processView = source as? LocalProcessTerminalView else { return }

            let envArray = Self.buildEnvironment()
            let cmd = Self.buildLaunchCommand()

            processView.startProcess(
                executable: "/bin/zsh",
                args: ["-l", "-c", cmd],
                environment: envArray,
                execName: "claude"
            )

            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                processView.send(txt: "\u{000C}")
            }
        }
    }

    static func buildLaunchCommand() -> String {
        let allowed = [
            "Bash(*)", "Read(*)", "Glob(*)",
            "Grep(*)", "Write(*)", "Edit(*)",
        ].joined(separator: "' --allowedTools '")
        let path = claudePath
        // If we found an absolute path use it, otherwise let the shell resolve via PATH
        if path.hasPrefix("/") {
            return "\(path) --allowedTools '\(allowed)'"
        }
        return "claude --allowedTools '\(allowed)'"
    }

    static func buildEnvironment() -> [String] {
        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "xterm-256color"
        env["LANG"] = "en_US.UTF-8"
        env["COLORTERM"] = "truecolor"
        return env.map { "\($0.key)=\($0.value)" }
    }
}

// MARK: - Terminal Container (NSViewRepresentable)

private struct TerminalContainer: NSViewRepresentable {
    let coordinator: TerminalCoordinator

    func makeNSView(context: Context) -> NSView {
        let container = NSView(frame: .zero)
        container.wantsLayer = true
        container.layer?.backgroundColor = Theme.Colors.terminalBG.cgColor
        container.layer?.masksToBounds = true

        let terminalView = LocalProcessTerminalView(frame: .zero)
        terminalView.translatesAutoresizingMaskIntoConstraints = false

        terminalView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        terminalView.nativeBackgroundColor = Theme.Colors.terminalBG
        terminalView.nativeForegroundColor = NSColor(white: 0.92, alpha: 1)
        terminalView.optionAsMetaKey = true

        container.addSubview(terminalView)

        let inset: CGFloat = 12
        NSLayoutConstraint.activate([
            terminalView.topAnchor.constraint(equalTo: container.topAnchor, constant: inset),
            terminalView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: inset),
            terminalView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -inset),
            terminalView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -inset),
        ])

        // Gradient cover over the top to hide the Claude Code startup banner.
        // Uses the terminal background color so it works in any appearance.
        // Passes all mouse events through (hitTest returns nil).
        let coverHeight: CGFloat = 90
        let cover = PassthroughGradientView(frame: .zero)
        cover.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(cover)
        NSLayoutConstraint.activate([
            cover.topAnchor.constraint(equalTo: container.topAnchor),
            cover.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            cover.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            cover.heightAnchor.constraint(equalToConstant: coverHeight),
        ])

        // Store reference so the button can send text
        coordinator.terminalView = terminalView
        terminalView.processDelegate = coordinator

        let cmd = TerminalCoordinator.buildLaunchCommand()
        let env = TerminalCoordinator.buildEnvironment()

        terminalView.startProcess(
            executable: "/bin/zsh",
            args: ["-l", "-c", cmd],
            environment: env,
            execName: "claude"
        )

        // Clear banner after startup
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            terminalView.send(txt: "\u{000C}")
        }

        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    func makeCoordinator() -> TerminalCoordinator {
        coordinator
    }
}

// MARK: - Gradient cover that passes all clicks through to the terminal beneath

private final class PassthroughGradientView: NSView {
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
    }

    override func updateLayer() {
        let gradient = CAGradientLayer()
        gradient.frame = bounds
        let bg = Theme.Colors.terminalBG
        gradient.colors = [
            bg.cgColor,
            bg.cgColor,
            bg.withAlphaComponent(0.85).cgColor,
            bg.withAlphaComponent(0).cgColor,
        ]
        gradient.locations = [0, 0.4, 0.7, 1.0]
        gradient.startPoint = CGPoint(x: 0.5, y: 0)
        gradient.endPoint = CGPoint(x: 0.5, y: 1)
        layer?.sublayers?.removeAll()
        layer?.addSublayer(gradient)
    }

    // Pass all mouse events through to the terminal underneath
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
