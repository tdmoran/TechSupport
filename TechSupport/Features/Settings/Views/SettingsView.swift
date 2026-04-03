import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Settings")
                    .font(Theme.Fonts.title)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .frame(width: 24, height: 24)
                        .background(
                            Theme.Colors.surface,
                            in: RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                                .strokeBorder(Theme.Colors.surfaceBorder, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])
            }
            .padding(Theme.Spacing.large)
            .overlay(alignment: .bottom) {
                Theme.Colors.divider.frame(height: 1)
            }

            // Content
            VStack(spacing: Theme.Spacing.large) {
                settingsRow(label: "Refresh Interval", value: "\(Int(AppConstants.monitorRefreshInterval))s")
                settingsRow(label: "History", value: "\(AppConstants.metricsHistoryCount) readings")

                Theme.Colors.divider.frame(height: 1)

                settingsRow(label: "Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                settingsRow(label: "macOS", value: ProcessInfo.processInfo.operatingSystemVersionString)
                settingsRow(label: "Claude Code", value: claudeVersion)
            }
            .padding(Theme.Spacing.large)

            Spacer()
        }
        .background(Theme.Colors.background)
    }

    private func settingsRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(Theme.Fonts.body)
                .foregroundStyle(Theme.Colors.textSecondary)
            Spacer()
            Text(value)
                .font(Theme.Fonts.captionMono)
                .foregroundStyle(Theme.Colors.textPrimary)
                .padding(.horizontal, Theme.Spacing.medium)
                .padding(.vertical, Theme.Spacing.xsmall)
                .background(
                    Theme.Colors.surface,
                    in: RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                )
        }
    }

    private var claudeVersion: String {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-c", "claude --version 2>/dev/null || echo 'not found'"]
        process.standardOutput = pipe
        process.standardError = pipe
        try? process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown"
    }
}
