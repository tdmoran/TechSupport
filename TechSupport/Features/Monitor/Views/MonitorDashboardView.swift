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
            metricsGrid
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: Theme.Spacing.medium, leading: Theme.Spacing.large, bottom: 0, trailing: Theme.Spacing.large))
                .listRowBackground(Color.clear)
            if viewModel.metrics.batteryLevel != nil {
                HStack(alignment: .top, spacing: Theme.Spacing.medium) {
                    runningAppsCard
                    peripheralsCard
                }
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: Theme.Spacing.medium, leading: Theme.Spacing.large, bottom: 0, trailing: Theme.Spacing.large))
                .listRowBackground(Color.clear)
            }
            networkCard
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: Theme.Spacing.medium, leading: Theme.Spacing.large, bottom: 0, trailing: Theme.Spacing.large))
                .listRowBackground(Color.clear)
            if viewModel.metrics.batteryLevel == nil {
                peripheralsCard
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: Theme.Spacing.medium, leading: Theme.Spacing.large, bottom: 0, trailing: Theme.Spacing.large))
                    .listRowBackground(Color.clear)
            }
            exportReportButton
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: Theme.Spacing.medium, leading: Theme.Spacing.large, bottom: 0, trailing: Theme.Spacing.large))
                .listRowBackground(Color.clear)
            quickSettings
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: Theme.Spacing.medium, leading: Theme.Spacing.large, bottom: 0, trailing: Theme.Spacing.large))
                .listRowBackground(Color.clear)
            systemInfoHeader
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: Theme.Spacing.medium, leading: Theme.Spacing.large, bottom: 0, trailing: Theme.Spacing.large))
                .listRowBackground(Color.clear)
            killAppsButton
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
                    statusColor: viewModel.diskStatusColor,
                    sparklineData: viewModel.history.map(\.diskUsagePercent)
                )

                // Battery (if available) or placeholder
                if let level = viewModel.metrics.batteryLevel {
                    batteryCard(level: level)
                } else {
                    // Running Apps in 4th slot when no battery
                    runningAppsCard
                }
            }
        }
    }

    // MARK: - Battery Card

    private func batteryCard(level: Double) -> some View {
        let info = viewModel.metrics.batteryInfo
        return VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
            // Header
            HStack(spacing: Theme.Spacing.xsmall) {
                Image(systemName: info?.isCharging == true ? "battery.100.bolt" : "battery.100")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(batteryColor.opacity(0.8))
                Text("BATTERY")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .tracking(0.5)
                Spacer()
            }

            // Level
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(Int(level))")
                    .font(Theme.Fonts.metricValue)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text("%")
                    .font(Theme.Fonts.metricUnit)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            // Charge status
            if let info {
                Text(info.chargingStatus)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(info.isCharging ? Theme.Colors.statusGreen : Theme.Colors.textSecondary)

                Text(info.isCharging ? "Full in \(info.formattedTimeRemaining)" : "\(info.formattedTimeRemaining) remaining")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.Colors.textTertiary)

                HStack(spacing: Theme.Spacing.medium) {
                    Text("Health: \(Int(info.healthPercent))%")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(Theme.Colors.textTertiary)
                    Text("Cycles: \(info.cycleCount)")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Theme.Colors.surfaceBorder)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                colors: [batteryColor.opacity(0.7), batteryColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * min(level / 100, 1.0))
                }
            }
            .frame(height: 4)
        }
        .cardStyle()
    }

    private var batteryColor: Color {
        switch viewModel.batteryStatusColor {
        case .green: return Theme.Colors.statusGreen
        case .yellow: return Theme.Colors.statusYellow
        case .red: return Theme.Colors.statusRed
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
        VStack(alignment: .leading, spacing: Theme.Spacing.small) {
            HStack(spacing: Theme.Spacing.xsmall) {
                Image(systemName: "cable.connector")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.Colors.accent.opacity(0.8))
                Text("DEVICES")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .tracking(0.5)
                Spacer()
                Text("\(viewModel.peripherals.count)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Colors.textPrimary)
            }

            if viewModel.peripherals.isEmpty {
                Text("No external devices")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.Colors.textTertiary)
            } else {
                VStack(alignment: .leading, spacing: Theme.Spacing.xxsmall) {
                    ForEach(viewModel.peripherals) { device in
                        HStack(spacing: Theme.Spacing.xsmall) {
                            Image(systemName: device.type.icon)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(Theme.Colors.accent)
                                .frame(width: 14)
                            Text(device.displayName)
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(Theme.Colors.textSecondary)
                                .lineLimit(1)
                            Spacer()
                            Text(device.type.rawValue)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(Theme.Colors.textTertiary)
                        }
                    }
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Combined Network Card

    private var networkCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
            sectionHeader("Network", icon: "network")

            HStack(alignment: .top, spacing: Theme.Spacing.medium) {
                // Wi-Fi column
                VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                    HStack(spacing: Theme.Spacing.xsmall) {
                        Image(systemName: viewModel.wifiInfo?.signalQuality.icon ?? "wifi.slash")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.Colors.accent.opacity(0.8))
                        Text("WI-FI")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .tracking(0.5)
                    }

                    if let wifi = viewModel.wifiInfo {
                        Text(wifi.formattedSpeed)
                            .font(Theme.Fonts.metricValue)
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Text("\(wifi.phyMode) · \(wifi.band)")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(Theme.Colors.textSecondary)
                        Text("Signal: \(wifi.formattedSignal)")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(Theme.Colors.textTertiary)
                    } else {
                        Text("Off")
                            .font(Theme.Fonts.metricValue)
                            .foregroundStyle(Theme.Colors.textTertiary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Divider
                Theme.Colors.divider.frame(width: 1)

                // Health column
                VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                    HStack(spacing: Theme.Spacing.xsmall) {
                        Image(systemName: viewModel.networkHealth.overallStatus.icon)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.Colors.accent.opacity(0.8))
                        Text("HEALTH")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .tracking(0.5)
                    }

                    Text(viewModel.networkHealth.statusLabel)
                        .font(Theme.Fonts.metricValue)
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text("Ping: \(viewModel.networkHealth.formattedLatency)")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(Theme.Colors.textSecondary)
                    Text(viewModel.networkHealth.dnsResolved ? "DNS OK" : "DNS fail")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(viewModel.networkHealth.dnsResolved ? Theme.Colors.statusGreen : Theme.Colors.statusRed)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Divider
                Theme.Colors.divider.frame(width: 1)

                // Speed Test column
                VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                    HStack(spacing: Theme.Spacing.xsmall) {
                        Image(systemName: "speedometer")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.Colors.accent.opacity(0.8))
                        Text("SPEED")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .tracking(0.5)
                    }

                    if viewModel.isRunningSpeedTest {
                        ProgressView()
                            .controlSize(.small)
                            .tint(Theme.Colors.accent)
                        Text("Testing...")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(Theme.Colors.textSecondary)
                    } else if let result = viewModel.speedTestResult {
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(result.formattedDownload)
                                .font(Theme.Fonts.metricValue)
                                .foregroundStyle(Theme.Colors.textPrimary)
                            Text("Mbps")
                                .font(Theme.Fonts.metricUnit)
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }
                        Text("Latency: \(result.formattedLatency)")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(Theme.Colors.textTertiary)

                        Button {
                            viewModel.startSpeedTest()
                        } label: {
                            Text("Run Again")
                                .font(.system(size: 9, weight: .semibold, design: .rounded))
                                .foregroundStyle(Theme.Colors.accent)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button {
                            viewModel.startSpeedTest()
                        } label: {
                            HStack(spacing: Theme.Spacing.xsmall) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 9))
                                Text("Run Test")
                                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                            }
                            .foregroundStyle(Theme.Colors.accent)
                            .padding(.horizontal, Theme.Spacing.medium)
                            .padding(.vertical, Theme.Spacing.small)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                                    .fill(Theme.Colors.accentSubtle)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .cardStyle()
        }
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

