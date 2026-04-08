import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(UserSettings.self) private var settings
    @State private var launchAtLogin = LaunchAtLoginManager.isEnabled
    @State private var claudeVersion: String = "Loading…"
    private var themeManager = ThemeManager.shared

    var body: some View {
        @Bindable var settings = settings

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
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])
            }
            .padding(Theme.Spacing.large)
            .overlay(alignment: .bottom) {
                Theme.Colors.divider.frame(height: 1)
            }

            // Content
            ScrollView {
            VStack(spacing: Theme.Spacing.large) {
                // Theme picker
                HStack {
                    Text("Appearance")
                        .font(Theme.Fonts.body)
                        .foregroundStyle(Theme.Colors.textSecondary)
                    Spacer()
                    Picker("", selection: Bindable(themeManager).mode) {
                        ForEach(ThemeMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                }

                launchAtLoginRow

                Theme.Colors.divider.frame(height: 1)

                // Editable settings
                settingsStepper(
                    label: "Refresh Interval",
                    value: $settings.refreshInterval,
                    range: UserSettings.refreshIntervalRange,
                    unit: "s"
                )

                settingsStepper(
                    label: "History Size",
                    value: $settings.historySize,
                    range: UserSettings.historySizeRange,
                    unit: " readings"
                )

                modelPicker(selection: $settings.preferredModel)

                Theme.Colors.divider.frame(height: 1)

                // Read-only info
                settingsRow(label: "Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                settingsRow(label: "macOS", value: ProcessInfo.processInfo.operatingSystemVersionString)
                settingsRow(label: "Claude Code", value: claudeVersion)

                Theme.Colors.divider.frame(height: 1)

                // Reset button
                HStack {
                    Spacer()
                    Button {
                        settings.resetToDefaults()
                    } label: {
                        Text("Reset to Defaults")
                            .font(Theme.Fonts.caption)
                            .foregroundStyle(Theme.Colors.accent)
                            .padding(.horizontal, Theme.Spacing.medium)
                            .padding(.vertical, Theme.Spacing.small)
                            .background(
                                Theme.Colors.accentSubtle,
                                in: RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                                    .strokeBorder(Theme.Colors.accent.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(Theme.Spacing.large)
            }
        }
        .background(Theme.Colors.background)
        .preferredColorScheme(themeManager.preferredColorScheme)
        .task {
            await loadClaudeVersion()
        }
    }

    // MARK: - Launch at Login

    private var launchAtLoginRow: some View {
        HStack {
            Text("Launch at Login")
                .font(Theme.Fonts.body)
                .foregroundStyle(Theme.Colors.textSecondary)
            Spacer()
            Toggle("", isOn: $launchAtLogin)
                .labelsHidden()
                .toggleStyle(.switch)
                .onChange(of: launchAtLogin) { _, newValue in
                    do {
                        if newValue {
                            try LaunchAtLoginManager.enable()
                        } else {
                            try LaunchAtLoginManager.disable()
                        }
                    } catch {
                        launchAtLogin = LaunchAtLoginManager.isEnabled
                    }
                }
        }
    }

    // MARK: - Editable Controls

    private func settingsStepper(
        label: String,
        value: Binding<Int>,
        range: ClosedRange<Int>,
        unit: String
    ) -> some View {
        HStack {
            Text(label)
                .font(Theme.Fonts.body)
                .foregroundStyle(Theme.Colors.textSecondary)
            Spacer()
            HStack(spacing: Theme.Spacing.small) {
                Button {
                    if value.wrappedValue > range.lowerBound {
                        value.wrappedValue -= stepSize(for: range)
                    }
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(value.wrappedValue > range.lowerBound
                            ? Theme.Colors.textPrimary
                            : Theme.Colors.textTertiary)
                        .frame(width: 22, height: 22)
                        .background(
                            Theme.Colors.surfaceHover,
                            in: RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                        )
                }
                .buttonStyle(.plain)
                .disabled(value.wrappedValue <= range.lowerBound)

                Text("\(value.wrappedValue)\(unit)")
                    .font(Theme.Fonts.captionMono)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .frame(minWidth: 60)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, Theme.Spacing.xsmall)
                    .background(
                        Theme.Colors.surface,
                        in: RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                    )

                Button {
                    if value.wrappedValue < range.upperBound {
                        value.wrappedValue += stepSize(for: range)
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(value.wrappedValue < range.upperBound
                            ? Theme.Colors.textPrimary
                            : Theme.Colors.textTertiary)
                        .frame(width: 22, height: 22)
                        .background(
                            Theme.Colors.surfaceHover,
                            in: RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                        )
                }
                .buttonStyle(.plain)
                .disabled(value.wrappedValue >= range.upperBound)
            }
        }
    }

    private func modelPicker(selection: Binding<ClaudeModel>) -> some View {
        HStack {
            Text("Claude Model")
                .font(Theme.Fonts.body)
                .foregroundStyle(Theme.Colors.textSecondary)
            Spacer()
            Menu {
                ForEach(ClaudeModel.allCases) { model in
                    Button {
                        selection.wrappedValue = model
                    } label: {
                        HStack {
                            Text("\(model.displayName) \(model.costTier)")
                            if model == selection.wrappedValue {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: Theme.Spacing.xsmall) {
                    Text(selection.wrappedValue.displayName)
                        .font(Theme.Fonts.captionMono)
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                .padding(.horizontal, Theme.Spacing.medium)
                .padding(.vertical, Theme.Spacing.xsmall)
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
        }
    }

    // MARK: - Read-only Row

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

    // MARK: - Helpers

    private func stepSize(for range: ClosedRange<Int>) -> Int {
        let span = range.upperBound - range.lowerBound
        if span > 50 { return 10 }
        return 1
    }

    private func loadClaudeVersion() async {
        let version = await Task.detached {
            let path = TerminalCoordinator.claudePath
            guard path.hasPrefix("/"),
                  FileManager.default.isExecutableFile(atPath: path) else {
                return "Not installed"
            }
            let process = Process()
            let pipe = Pipe()
            process.executableURL = URL(fileURLWithPath: path)
            process.arguments = ["--version"]
            process.standardOutput = pipe
            process.standardError = pipe
            do {
                try process.run()
                process.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                return String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown"
            } catch {
                return "Not installed"
            }
        }.value
        claudeVersion = version
    }
}
