import SwiftUI

struct MetricCardView: View {
    let icon: String
    let title: String
    let value: String
    let unit: String?
    let subtitle: String
    let progress: Double?
    let statusColor: MonitorViewModel.StatusColor
    var sparklineData: [Double]? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
            // Header row
            HStack(spacing: Theme.Spacing.xsmall) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(colorForStatus.opacity(0.8))
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .tracking(0.5)
                Spacer()
            }

            // Value
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(Theme.Fonts.metricValue)
                    .foregroundStyle(Theme.Colors.textPrimary)
                if let unit {
                    Text(unit)
                        .font(Theme.Fonts.metricUnit)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }

            // Subtitle
            Text(subtitle)
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.textTertiary)

            // Progress bar — custom styled
            if let progress {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Theme.Colors.surfaceBorder)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(
                                LinearGradient(
                                    colors: [colorForStatus.opacity(0.7), colorForStatus],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * min(progress, 1.0))
                    }
                }
                .frame(height: 4)
            }

            // Sparkline
            if let sparklineData, sparklineData.count >= 2 {
                SparklineView(dataPoints: sparklineData)
            }
        }
        .cardStyle()
    }

    private var colorForStatus: Color {
        switch statusColor {
        case .green: return Theme.Colors.statusGreen
        case .yellow: return Theme.Colors.statusYellow
        case .red: return Theme.Colors.statusRed
        }
    }
}
