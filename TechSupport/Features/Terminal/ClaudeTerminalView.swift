import SwiftUI
import SwiftTerm

struct ClaudeTerminalView: View {
    @State private var coordinator = TerminalCoordinator()

    var body: some View {
        VStack(spacing: 0) {
            // Header bar
            HStack(spacing: Theme.Spacing.medium) {
                HStack(spacing: Theme.Spacing.xsmall) {
                    Circle()
                        .fill(Theme.Colors.statusGreen)
                        .frame(width: 7, height: 7)
                    Text("Claude Code")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.Colors.textPrimary)
                }
                Spacer()
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
