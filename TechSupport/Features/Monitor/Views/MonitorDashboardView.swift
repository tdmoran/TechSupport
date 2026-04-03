import SwiftUI

struct MonitorDashboardView: View {
    @Bindable var viewModel: MonitorViewModel
    @State private var showKillApps = false

    private let columns = [
        GridItem(.flexible(), spacing: Theme.Spacing.medium),
        GridItem(.flexible(), spacing: Theme.Spacing.medium),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.xlarge) {
                systemInfoHeader
                killAppsButton
                metricsGrid
                peripheralsCard
                quickSettings
            }
            .padding(Theme.Spacing.large)
            .padding(.bottom, Theme.Spacing.xlarge)
        }
        .scrollIndicators(.hidden)
        .sheet(isPresented: $showKillApps) {
            KillAppsView()
                .frame(width: 420, height: 500)
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
                    statusColor: viewModel.cpuStatusColor
                )

                MetricCardView(
                    icon: "memorychip",
                    title: "Memory",
                    value: viewModel.metrics.formattedMemoryUsed,
                    unit: nil,
                    subtitle: "of \(viewModel.metrics.formattedMemoryTotal)",
                    progress: viewModel.metrics.memoryUsagePercent / 100,
                    statusColor: viewModel.memoryStatusColor
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

                // Running Apps — compact list in a metric-sized card
                runningAppsCard
            }
        }
    }

    // MARK: - Running Apps Card

    private var runningAppsCard: some View {
        let apps = viewModel.runningAppNames
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

            // Compact scrollable list of app names
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xxsmall) {
                    ForEach(apps, id: \.self) { name in
                        Text(name)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .lineLimit(1)
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

    // MARK: - Quick Settings

    private var quickSettings: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
            sectionHeader("Quick Settings", icon: "gear")

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 85))], spacing: Theme.Spacing.medium) {
                // Activity Monitor first
                Button {
                    NSWorkspace.shared.open(
                        URL(fileURLWithPath: "/System/Library/CoreServices/Applications/Activity Monitor.app")
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
