import SwiftUI

struct MainContentView: View {
    @State private var selectedTab = Tab.monitor
    @State private var showSettings = false

    @State private var userSettings = UserSettings()
    private let monitorService = SystemMonitorService()
    @State private var monitorViewModel: MonitorViewModel?
    @State private var claudeTabVisited = false

    private var themeManager = ThemeManager.shared

    enum Tab: String, CaseIterable {
        case claude = "Claude"
        case monitor = "Monitor"
        case appNuker = "AppNuker"

        var icon: String {
            switch self {
            case .claude: return "terminal"
            case .monitor: return "gauge.medium"
            case .appNuker: return "trash.circle"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            tabContent
        }
        .background(Theme.Colors.background)
        .preferredColorScheme(themeManager.preferredColorScheme)
        .environment(userSettings)
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environment(userSettings)
                .frame(width: 380, height: 500)
        }
        .onAppear {
            monitorService.start(settings: userSettings)
            monitorService.notificationManager.requestPermission()
            monitorViewModel = MonitorViewModel(monitorService: monitorService)
        }
        .onChange(of: userSettings.refreshInterval) {
            monitorService.start(settings: userSettings)
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 0) {
            // App identity
            HStack(spacing: Theme.Spacing.small) {
                Image(systemName: "wrench.and.screwdriver")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.Colors.accent)
                Text("TechSupport")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.Colors.textPrimary)
            }
            .padding(.leading, Theme.Spacing.large)

            Spacer()

            // Tab switcher — pill style
            HStack(spacing: 2) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = tab
                        }
                    } label: {
                        HStack(spacing: Theme.Spacing.xsmall) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 10, weight: .semibold))
                            Text(tab.rawValue)
                                .font(Theme.Fonts.tabLabel)
                        }
                        .padding(.horizontal, Theme.Spacing.medium)
                        .padding(.vertical, Theme.Spacing.small)
                        .background(
                            selectedTab == tab
                                ? Theme.Colors.accentSubtle
                                : Color.clear,
                            in: RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                        )
                        .foregroundStyle(
                            selectedTab == tab
                                ? Theme.Colors.accent
                                : Theme.Colors.textSecondary
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(3)
            .background(
                Theme.Colors.surface,
                in: RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                    .strokeBorder(Theme.Colors.surfaceBorder, lineWidth: 1)
            )

            Spacer()

            // Settings
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gear")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .frame(width: 28, height: 28)
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
            .padding(.trailing, Theme.Spacing.large)
        }
        .frame(height: 44)
        .background(Theme.Colors.background)
        .overlay(alignment: .bottom) {
            Theme.Colors.divider.frame(height: 1)
        }
    }

    // MARK: - Tab Content
    // Both views stay alive in a ZStack so the terminal process survives tab switches.

    private var tabContent: some View {
        ZStack {
            // Only create the terminal once the Claude tab has been visited
            if claudeTabVisited {
                ClaudeTerminalView()
                    .padding(.top, 1)
                    .opacity(selectedTab == .claude ? 1 : 0)
                    .allowsHitTesting(selectedTab == .claude)
            }

            if let monitorVM = monitorViewModel {
                MonitorDashboardView(viewModel: monitorVM)
                    .opacity(selectedTab == .monitor ? 1 : 0)
                    .allowsHitTesting(selectedTab == .monitor)
            }

            AppNukerTabView()
                .opacity(selectedTab == .appNuker ? 1 : 0)
                .allowsHitTesting(selectedTab == .appNuker)
        }
        .onChange(of: selectedTab) {
            if selectedTab == .claude {
                claudeTabVisited = true
            }
        }
    }
}
