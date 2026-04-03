import SwiftUI

struct MessageBubbleView: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 40) }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: Theme.Spacing.small) {
                if let context = message.systemContext {
                    SystemContextBadge(metrics: context)
                }

                Text(attributedContent)
                    .font(Theme.Fonts.body)
                    .textSelection(.enabled)
                    .padding(Theme.Spacing.large)
                    .background(bubbleBackground)
                    .foregroundStyle(Theme.Colors.textPrimary)

                Text(message.timestamp, style: .time)
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            if message.role == .assistant { Spacer(minLength: 40) }
        }
    }

    private var attributedContent: AttributedString {
        (try? AttributedString(markdown: message.content)) ?? AttributedString(message.content)
    }

    @ViewBuilder
    private var bubbleBackground: some View {
        if message.role == .user {
            RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                .fill(Theme.Colors.accent.opacity(0.3))
        } else {
            RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                .fill(Theme.Colors.surface)
        }
    }
}

struct SystemContextBadge: View {
    let metrics: SystemMetrics
    @State private var isExpanded = false

    var body: some View {
        Button {
            isExpanded.toggle()
        } label: {
            HStack(spacing: Theme.Spacing.small) {
                Image(systemName: "info.circle")
                Text("System info sent")
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
            }
            .font(Theme.Fonts.caption)
            .foregroundStyle(Theme.Colors.textSecondary)
            .padding(.horizontal, Theme.Spacing.medium)
            .padding(.vertical, Theme.Spacing.small)
            .glassBackground(cornerRadius: Theme.CornerRadius.small)
        }
        .buttonStyle(.plain)

        if isExpanded {
            VStack(alignment: .leading, spacing: 2) {
                Text("CPU: \(String(format: "%.0f", metrics.cpuUsage))%")
                Text("RAM: \(metrics.formattedMemoryUsed)/\(metrics.formattedMemoryTotal)")
                Text("Disk: \(String(format: "%.0f", metrics.diskUsagePercent))% full")
            }
            .font(Theme.Fonts.caption)
            .foregroundStyle(Theme.Colors.textSecondary)
            .padding(.horizontal, Theme.Spacing.medium)
        }
    }
}
