import SwiftUI
import Combine
import UniformTypeIdentifiers

struct MonitorDashboardView: View {
    @Bindable var viewModel: MonitorViewModel
    @State private var showKillApps = false
    @State private var showBackgroundApps = false
    @State private var showDiskCleanup = false
    @State private var isExporting = false

    private let columns = [
        GridItem(.flexible(), spacing: Theme.Spacing.medium),
        GridItem(.flexible(), spacing: Theme.Spacing.medium),
    ]

    var body: some View {
        List {
            systemInfoHeader
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 0, leading: Theme.Spacing.large, bottom: 0, trailing: Theme.Spacing.large))
                .listRowBackground(Color.clear)
            killAppsButton
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: Theme.Spacing.medium, leading: Theme.Spacing.large, bottom: 0, trailing: Theme.Spacing.large))
                .listRowBackground(Color.clear)
            metricsGrid
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: Theme.Spacing.medium, leading: Theme.Spacing.large, bottom: 0, trailing: Theme.Spacing.large))
                .listRowBackground(Color.clear)
            peripheralsCard
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: Theme.Spacing.medium, leading: Theme.Spacing.large, bottom: 0, trailing: Theme.Spacing.large))
                .listRowBackground(Color.clear)
            exportReportButton
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: Theme.Spacing.medium, leading: Theme.Spacing.large, bottom: 0, trailing: Theme.Spacing.large))
                .listRowBackground(Color.clear)
            quickSettings
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: Theme.Spacing.medium, leading: Theme.Spacing.large, bottom: Theme.Spacing.xlarge, trailing: Theme.Spacing.large))
                .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .onAppear { viewModel.refreshAppLists() }
        .onReceive(Timer.publish(every: 5, on: .main, in: .common).autoconnect()) { _ in
            viewModel.refreshAppLists()
        }
        .sheet(isPresented: $showKillApps) {
            KillAppsView()
                .frame(width: 420, height: 500)
        }
        .sheet(isPresented: $showDiskCleanup) {
            CleanupView()
                .frame(width: 440, height: 520)
        }
    }

    // MARK: - System Info

    private var systemInfoHeader: some View {
        HStack(spacing: Theme.Spacing.medium) {
            Image(systemName: "desktopcomputer")
                .font(.system(size: 18))
                .foregroundStyle(Theme.Colors.accent)

            VStack(alignment: .leading, spacing: Theme.Spacing.xxsmall) {
                Text(viewModel.metrics.hardwareModel)
                    .font(Theme.Fonts.title)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text(viewModel.metrics.macOSVersion)
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            Spacer()

            HStack(spacing: Theme.Spacing.xsmall) {
                Circle()
                    .fill(Theme.Colors.statusGreen)
                    .frame(width: 6, height: 6)
                Text("LIVE")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.Colors.statusGreen)
            }
            .padding(.horizontal, Theme.Spacing.medium)
            .padding(.vertical, Theme.Spacing.xsmall)
            .background(
                Theme.Colors.statusGreen.opacity(0.1),
                in: Capsule()
            )
            .overlay(
                Capsule().strokeBorder(Theme.Colors.statusGreen.opacity(0.2), lineWidth: 1)
            )
        }
        .padding(Theme.Spacing.large)
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.large)
                .fill(Theme.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.large)
                        .strokeBorder(Theme.Colors.surfaceBorder, lineWidth: 1)
                )
        )
    }

    // MARK: - Kill Apps Button

    private var killAppsButton: some View {
        Button {
            showKillApps = true
        } label: {
            HStack(spacing: Theme.Spacing.medium) {
                Image(systemName: "xmark.app")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.Colors.statusRed)

                VStack(alignment: .leading, spacing: Theme.Spacing.xxsmall) {
                    Text("Force Quit Apps")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text("Kill frozen or unresponsive applications")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
            .padding(Theme.Spacing.large)
            .background(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                    .fill(Theme.Colors.statusRed.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                            .strokeBorder(Theme.Colors.statusRed.opacity(0.15), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Metrics Grid

    private var metricsGrid: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
            sectionHeader("System Metrics", icon: "chart.bar")

            LazyVGrid(columns: columns, spacing: Theme.Spacing.medium) {
                MetricCardView(
                    icon: "cpu",
                    title: "CPU",
                    value: String(format: "%.0f", viewModel.metrics.cpuUsage),
                    unit: "%",
                    subtitle: "\(viewModel.metrics.cpuCoreCount) cores",
                    progress: viewModel.metrics.cpuUsage / 100,
                    statusColor: viewModel.cpuStatusColor,
                    sparklineData: viewModel.history.map(\.cpuUsage)
                )

                MetricCardView(
                    icon: "memorychip",
                    title: "Memory",
                    value: viewModel.metrics.formattedMemoryUsed,
                    unit: nil,
                    subtitle: "of \(viewModel.metrics.formattedMemoryTotal)",
                    progress: viewModel.metrics.memoryUsagePercent / 100,
                    statusColor: viewModel.memoryStatusColor,
                    sparklineData: viewModel.history.map(\.memoryUsagePercent)
                )

                MetricCardView(
                    icon: "internaldrive",
                    title: "Disk",
                    value: viewModel.metrics.formattedDiskUsed,
                    unit: nil,
                    subtitle: "of \(viewModel.metrics.formattedDiskTotal)",
                    progress: viewModel.metrics.diskUsagePercent / 100,
                    statusColor: viewModel.diskStatusColor
                )

                // Wi-Fi Speed
                if let wifi = viewModel.wifiInfo {
                    MetricCardView(
                        icon: wifi.signalQuality.icon,
                        title: "Wi-Fi",
                        value: wifi.formattedSpeed,
                        unit: nil,
                        subtitle: "\(wifi.phyMode) \(wifi.band) \(wifi.formattedSignal)",
                        progress: min(wifi.txRate / 2400, 1.0),
                        statusColor: viewModel.wifiStatusColor
                    )
                } else {
                    MetricCardView(
                        icon: "wifi.slash",
                        title: "Wi-Fi",
                        value: "Off",
                        unit: nil,
                        subtitle: "No wireless connection",
                        progress: nil,
                        statusColor: .red
                    )
                }

                // Network Health
                MetricCardView(
                    icon: viewModel.networkHealth.overallStatus.icon,
                    title: "Network",
                    value: viewModel.networkHealth.statusLabel,
                    unit: nil,
                    subtitle: "Ping: \(viewModel.networkHealth.formattedLatency) \(viewModel.networkHealth.dnsResolved ? "DNS OK" : "DNS fail")",
                    progress: nil,
                    statusColor: viewModel.networkHealthStatusColor
                )

                // Speed Test
                speedTestCard

                // Running Apps — compact list in a metric-sized card
                runningAppsCard
            }
        }
    }

    // MARK: - Running Apps Card

    private var runningAppsCard: some View {
        let apps = viewModel.runningAppNames
        let backgroundApps = viewModel.backgroundAppNames
        return VStack(alignment: .leading, spacing: Theme.Spacing.small) {
            HStack(spacing: Theme.Spacing.xsmall) {
                Image(systemName: "square.stack.3d.up")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.Colors.accent.opacity(0.8))
                Text("APPS")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .tracking(0.5)
                Spacer()
                Text("\(apps.count)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Colors.textPrimary)
            }

            // Foreground apps list
            VStack(alignment: .leading, spacing: Theme.Spacing.xxsmall) {
                ForEach(apps, id: \.self) { name in
                    HStack {
                        Text(name)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .lineLimit(1)
                        Spacer()
                        Button {
                            viewModel.forceQuitApp(named: name)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(Theme.Colors.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Background apps toggle button
            if !backgroundApps.isEmpty {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showBackgroundApps.toggle()
                    }
                } label: {
                    HStack(spacing: Theme.Spacing.xsmall) {
                        Image(systemName: showBackgroundApps ? "chevron.up" : "chevron.down")
                            .font(.system(size: 8, weight: .semibold))
                        Text("\(showBackgroundApps ? "Hide" : "Show") Background Apps (\(backgroundApps.count))")
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(Theme.Colors.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.small)
                }
                .buttonStyle(.plain)

                if showBackgroundApps {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xxsmall) {
                        ForEach(backgroundApps, id: \.self) { name in
                            HStack {
                                Text(name)
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundStyle(Theme.Colors.textTertiary)
                                    .lineLimit(1)
                                Spacer()
                                Button {
                                    viewModel.forceQuitApp(named: name)
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundStyle(Theme.Colors.textTertiary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Peripherals

    private var peripheralsCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
            sectionHeader("Connected Devices", icon: "cable.connector")

            if viewModel.peripherals.isEmpty {
                HStack(spacing: Theme.Spacing.medium) {
                    Image(systemName: "cable.connector.slash")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.Colors.textTertiary)
                    Text("No external devices detected")
                        .font(Theme.Fonts.body)
                        .foregroundStyle(Theme.Colors.textSecondary)
                    Spacer()
                }
                .padding(Theme.Spacing.large)
                .cardStyle()
            } else {
                VStack(spacing: Theme.Spacing.small) {
                    ForEach(viewModel.peripherals) { device in
                        HStack(spacing: Theme.Spacing.medium) {
                            Image(systemName: device.type.icon)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Theme.Colors.accent)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: Theme.Spacing.xxsmall) {
                                Text(device.displayName)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Theme.Colors.textPrimary)
                                    .lineLimit(1)
                                Text(device.type.rawValue)
                                    .font(Theme.Fonts.caption)
                                    .foregroundStyle(Theme.Colors.textTertiary)
                            }

                            Spacer()
                        }
                        .padding(.vertical, Theme.Spacing.small)
                        .padding(.horizontal, Theme.Spacing.medium)
                    }
                }
                .cardStyle(padding: Theme.Spacing.medium)
            }
        }
    }

    // MARK: - Speed Test Card

    private var speedTestCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
            HStack(spacing: Theme.Spacing.xsmall) {
                Image(systemName: "speedometer")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.Colors.accent.opacity(0.8))
                Text("SPEED TEST")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .tracking(0.5)
                Spacer()
            }

            if viewModel.isRunningSpeedTest {
                VStack(spacing: Theme.Spacing.medium) {
                    ProgressView()
                        .controlSize(.small)
                        .tint(Theme.Colors.accent)
                    Text("Testing...")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.small)
            } else if let result = viewModel.speedTestResult {
                VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.Colors.statusGreen)
                        Text(result.formattedDownload)
                            .font(Theme.Fonts.metricValue)
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Text("Mbps")
                            .font(Theme.Fonts.metricUnit)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }

                    if let _ = result.uploadMbps {
                        HStack(spacing: 2) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(Theme.Colors.accent)
                            Text("\(result.formattedUpload) Mbps up")
                                .font(Theme.Fonts.caption)
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }
                    }

                    Text("Latency: \(result.formattedLatency)")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.textTertiary)
                }

                Button {
                    viewModel.startSpeedTest()
                } label: {
                    Text("Run Again")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.Colors.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.small)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                                .fill(Theme.Colors.accentSubtle)
                        )
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    viewModel.startSpeedTest()
                } label: {
                    HStack(spacing: Theme.Spacing.xsmall) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 10))
                        Text("Run Speed Test")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(Theme.Colors.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.medium)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                            .fill(Theme.Colors.accentSubtle)
                    )
                }
                .buttonStyle(.plain)

                Text("Measure download speed & latency")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
        }
        .cardStyle()
    }

    // MARK: - Export Report

    private var exportReportButton: some View {
        Button {
            exportReport()
        } label: {
            HStack(spacing: Theme.Spacing.medium) {
                if isExporting {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 18, height: 18)
                } else {
                    Image(systemName: "doc.text")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Theme.Colors.accent)
                }

                VStack(alignment: .leading, spacing: Theme.Spacing.xxsmall) {
                    Text("Export Diagnostic Report")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text(isExporting ? "Running diagnostics..." : "Save a full system report to a text file")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }

                Spacer()

                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
            .padding(Theme.Spacing.large)
            .background(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                    .fill(Theme.Colors.accent.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                            .strokeBorder(Theme.Colors.accent.opacity(0.15), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(isExporting)
    }

    private func exportReport() {
        isExporting = true
        let metrics = viewModel.monitorService.snapshot()

        Task.detached {
            let exporter = DiagnosticExporter()
            let report = await exporter.generateReport(metrics: metrics)

            await MainActor.run {
                isExporting = false
                showSavePanel(report: report)
            }
        }
    }

    private func showSavePanel(report: String) {
        let panel = NSSavePanel()
        panel.title = "Save Diagnostic Report"
        panel.nameFieldStringValue = "TechSupport-Report.txt"
        panel.allowedContentTypes = [.plainText]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try report.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            let alert = NSAlert()
            alert.messageText = "Export Failed"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.runModal()
        }
    }

    // MARK: - Quick Settings

    private var quickSettings: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
            sectionHeader("Quick Settings", icon: "gear")

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 85))], spacing: Theme.Spacing.medium) {
                // Activity Monitor first
                Button {
                    NSWorkspace.shared.open(
                        URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app")
                    )
                } label: {
                    VStack(spacing: Theme.Spacing.small) {
                        Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Theme.Colors.accent)
                        Text("Activity Monitor")
                            .font(Theme.Fonts.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.medium)
                    .cardStyle(padding: Theme.Spacing.medium)
                }
                .buttonStyle(.plain)

                // Disk Cleanup
                Button {
                    showDiskCleanup = true
                } label: {
                    VStack(spacing: Theme.Spacing.small) {
                        Image(systemName: "externaldrive.badge.minus")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Theme.Colors.accent)
                        Text("Disk Cleanup")
                            .font(Theme.Fonts.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.medium)
                    .cardStyle(padding: Theme.Spacing.medium)
                }
                .buttonStyle(.plain)

                ForEach([SettingsPane.storage, .network, .battery, .security, .softwareUpdate]) { pane in
                    Button {
                        SystemSettingsLauncher.open(pane)
                    } label: {
                        VStack(spacing: Theme.Spacing.small) {
                            Image(systemName: pane.icon)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Theme.Colors.accent)
                            Text(pane.displayName)
                                .font(Theme.Fonts.caption)
                                .foregroundStyle(Theme.Colors.textSecondary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.medium)
                        .cardStyle(padding: Theme.Spacing.medium)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: Theme.Spacing.small) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.Colors.textTertiary)
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.Colors.textTertiary)
                .tracking(0.8)
        }
    }
}

