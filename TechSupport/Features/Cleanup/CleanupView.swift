import SwiftUI

struct CleanupView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var service = DiskCleanupService()
    @State private var confirmCleanCaches = false
    @State private var confirmEmptyTrash = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: Theme.Spacing.xxsmall) {
                    Text("Disk Cleanup")
                        .font(Theme.Fonts.title)
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text(service.isScanning ? "Scanning..." : "\(service.locations.count) locations found")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }

                Spacer()

                Button {
                    service.scan()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .semibold))
                        .rotationEffect(.degrees(service.isScanning ? 360 : 0))
                        .animation(service.isScanning ? .linear(duration: 0.6).repeatForever(autoreverses: false) : .default, value: service.isScanning)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.Colors.textSecondary)
                .disabled(service.isScanning)

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

            // Error banner
            if let error = service.lastError {
                HStack(spacing: Theme.Spacing.small) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Theme.Colors.statusYellow)
                    Text(error)
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.statusYellow)
                    Spacer()
                }
                .padding(Theme.Spacing.medium)
                .background(Theme.Colors.statusYellow.opacity(0.1), in: RoundedRectangle(cornerRadius: Theme.CornerRadius.small))
                .padding(.horizontal, Theme.Spacing.large)
                .padding(.top, Theme.Spacing.medium)
            }

            // Total reclaimable
            if !service.locations.isEmpty {
                let reclaimable = service.locations.filter(\.isDeletable).reduce(Int64(0)) { $0 + $1.size }
                HStack(spacing: Theme.Spacing.small) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.Colors.accent)
                    Text("Potential space to reclaim:")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                    Text(ByteCountFormatter.string(fromByteCount: reclaimable, countStyle: .file))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.Colors.accent)
                    Spacer()
                }
                .padding(Theme.Spacing.medium)
                .padding(.horizontal, Theme.Spacing.small)
            }

            // Location list
            ScrollView {
                LazyVStack(spacing: Theme.Spacing.small) {
                    ForEach(service.locations) { location in
                        locationRow(location)
                    }
                }
                .padding(Theme.Spacing.large)
            }

            // Action buttons
            if !service.locations.isEmpty {
                VStack(spacing: Theme.Spacing.small) {
                    Theme.Colors.divider.frame(height: 1)

                    HStack(spacing: Theme.Spacing.medium) {
                        Button {
                            confirmCleanCaches = true
                        } label: {
                            HStack(spacing: Theme.Spacing.small) {
                                Image(systemName: "folder.badge.gearshape")
                                    .font(.system(size: 11, weight: .semibold))
                                Text("Clean Caches")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundStyle(Theme.Colors.accent)
                            .padding(.horizontal, Theme.Spacing.large)
                            .padding(.vertical, Theme.Spacing.medium)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                                    .fill(Theme.Colors.accentSubtle)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                                            .strokeBorder(Theme.Colors.accent.opacity(0.2), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(service.isCleaning)

                        Button {
                            confirmEmptyTrash = true
                        } label: {
                            HStack(spacing: Theme.Spacing.small) {
                                Image(systemName: "trash")
                                    .font(.system(size: 11, weight: .semibold))
                                Text("Empty Trash")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundStyle(Theme.Colors.statusRed)
                            .padding(.horizontal, Theme.Spacing.large)
                            .padding(.vertical, Theme.Spacing.medium)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                                    .fill(Theme.Colors.statusRed.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                                            .strokeBorder(Theme.Colors.statusRed.opacity(0.2), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(service.isCleaning)

                        Spacer()

                        if service.isCleaning {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.large)
                    .padding(.vertical, Theme.Spacing.medium)
                }
            }
        }
        .background(Theme.Colors.background)
        .onAppear {
            service.scan()
        }
        .alert("Clean Caches?", isPresented: $confirmCleanCaches) {
            Button("Cancel", role: .cancel) {}
            Button("Clean", role: .destructive) {
                service.cleanCache()
            }
        } message: {
            Text("This will remove the contents of ~/Library/Caches/. Apps will recreate their caches as needed.")
        }
        .alert("Empty Trash?", isPresented: $confirmEmptyTrash) {
            Button("Cancel", role: .cancel) {}
            Button("Empty Trash", role: .destructive) {
                service.emptyTrash()
            }
        } message: {
            Text("All items in the Trash will be permanently deleted. This cannot be undone.")
        }
    }

    // MARK: - Location Row

    private func locationRow(_ location: CleanupLocation) -> some View {
        HStack(spacing: Theme.Spacing.medium) {
            Image(systemName: location.icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.Colors.accent)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: Theme.Spacing.xxsmall) {
                Text(location.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(1)
                Text(location.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .lineLimit(1)
            }

            Spacer()

            Text(location.formattedSize)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(location.size > 1_000_000_000 ? Theme.Colors.statusYellow : Theme.Colors.textSecondary)
        }
        .padding(Theme.Spacing.medium)
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                .fill(Theme.Colors.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                .strokeBorder(Theme.Colors.surfaceBorder, lineWidth: 1)
        )
    }
}
