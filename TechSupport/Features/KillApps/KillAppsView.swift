import SwiftUI

struct KillAppsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var service = ProcessListService()
    @State private var confirmKill: AppProcessInfo?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: Theme.Spacing.xxsmall) {
                    Text("Force Quit Apps")
                        .font(Theme.Fonts.title)
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text("\(service.processes.count) apps running")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }

                Spacer()

                Button {
                    service.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .semibold))
                        .rotationEffect(.degrees(service.isRefreshing ? 360 : 0))
                        .animation(service.isRefreshing ? .linear(duration: 0.6).repeatForever(autoreverses: false) : .default, value: service.isRefreshing)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.Colors.textSecondary)

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .frame(width: 24, height: 24)
                        .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.CornerRadius.small))
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

            // Frozen apps warning
            if service.processes.contains(where: { !$0.isResponding }) {
                HStack(spacing: Theme.Spacing.small) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Theme.Colors.statusRed)
                    Text("Unresponsive apps detected")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.statusRed)
                    Spacer()
                }
                .padding(Theme.Spacing.medium)
                .background(Theme.Colors.statusRed.opacity(0.1), in: RoundedRectangle(cornerRadius: Theme.CornerRadius.small))
                .padding(.horizontal, Theme.Spacing.large)
                .padding(.top, Theme.Spacing.medium)
            }

            // Process list
            ScrollView {
                LazyVStack(spacing: Theme.Spacing.small) {
                    ForEach(service.processes) { process in
                        processRow(process)
                    }
                }
                .padding(Theme.Spacing.large)
            }
        }
        .background(Theme.Colors.background)
        .onAppear {
            service.refresh()
        }
        .alert(
            "Force Quit \"\(confirmKill?.name ?? "")\"?",
            isPresented: Binding(
                get: { confirmKill != nil },
                set: { if !$0 { confirmKill = nil } }
            )
        ) {
            Button("Cancel", role: .cancel) { confirmKill = nil }
            Button("Force Quit", role: .destructive) {
                if let process = confirmKill {
                    let _ = service.forceQuit(pid: process.id)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        service.refresh()
                    }
                }
                confirmKill = nil
            }
        } message: {
            Text("Unsaved changes in this app will be lost.")
        }
    }

    private func processRow(_ process: AppProcessInfo) -> some View {
        HStack(spacing: Theme.Spacing.medium) {
            // App icon
            if let icon = process.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 28, height: 28)
            } else {
                Image(systemName: "app")
                    .font(.system(size: 20))
                    .frame(width: 28, height: 28)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            // Name + status
            VStack(alignment: .leading, spacing: Theme.Spacing.xxsmall) {
                Text(process.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(1)

                HStack(spacing: Theme.Spacing.xsmall) {
                    Circle()
                        .fill(process.isTrouble ? Theme.Colors.statusRed : Theme.Colors.statusGreen)
                        .frame(width: 5, height: 5)
                    Text(process.statusLabel)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(process.isTrouble ? Theme.Colors.statusRed : Theme.Colors.textTertiary)
                }
            }

            Spacer()

            // Stats
            VStack(alignment: .trailing, spacing: Theme.Spacing.xxsmall) {
                Text(String(format: "%.0f%% CPU", process.cpuUsage))
                    .font(Theme.Fonts.captionMono)
                    .foregroundStyle(process.cpuUsage > 50 ? Theme.Colors.statusYellow : Theme.Colors.textTertiary)
                Text(String(format: "%.0f MB", process.memoryMB))
                    .font(Theme.Fonts.captionMono)
                    .foregroundStyle(Theme.Colors.textTertiary)
            }

            // Kill button
            Button {
                confirmKill = process
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(process.isTrouble ? Theme.Colors.statusRed : Theme.Colors.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(Theme.Spacing.medium)
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                .fill(process.isTrouble ? Theme.Colors.statusRed.opacity(0.06) : Theme.Colors.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                .strokeBorder(process.isTrouble ? Theme.Colors.statusRed.opacity(0.15) : Theme.Colors.surfaceBorder, lineWidth: 1)
        )
    }
}
