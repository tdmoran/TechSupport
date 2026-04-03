import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

struct MetricsEntry: TimelineEntry {
    let date: Date
    let metrics: WidgetMetrics
}

struct MetricsProvider: TimelineProvider {
    func placeholder(in context: Context) -> MetricsEntry {
        MetricsEntry(date: .now, metrics: .fetch())
    }

    func getSnapshot(in context: Context, completion: @escaping (MetricsEntry) -> Void) {
        completion(MetricsEntry(date: .now, metrics: .fetch()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MetricsEntry>) -> Void) {
        let entry = MetricsEntry(date: .now, metrics: .fetch())
        // Refresh every 30 seconds
        let next = Calendar.current.date(byAdding: .second, value: 30, to: .now)!
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - Small Widget View

struct SmallWidgetView: View {
    let metrics: WidgetMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header
            HStack(spacing: 4) {
                Image(systemName: "wrench.and.screwdriver")
                    .font(.system(size: 10, weight: .semibold))
                Text("TechSupport")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            // CPU
            metricRow(
                icon: "cpu",
                label: "CPU",
                value: String(format: "%.0f%%", metrics.cpuUsage),
                progress: metrics.cpuUsage / 100,
                color: metrics.cpuUsage > 80 ? .red : metrics.cpuUsage > 50 ? .yellow : .green
            )

            // Memory
            metricRow(
                icon: "memorychip",
                label: "RAM",
                value: metrics.formattedMemory,
                progress: metrics.memoryPercent / 100,
                color: metrics.memoryPercent > 85 ? .red : metrics.memoryPercent > 70 ? .yellow : .green
            )

            // Disk
            metricRow(
                icon: "internaldrive",
                label: "Disk",
                value: metrics.formattedDisk,
                progress: metrics.diskPercent / 100,
                color: metrics.diskPercent > 90 ? .red : metrics.diskPercent > 75 ? .yellow : .green
            )
        }
        .padding(2)
    }

    private func metricRow(icon: String, label: String, value: String, progress: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(color)
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(value)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.quaternary)
                    Capsule()
                        .fill(color.gradient)
                        .frame(width: geo.size.width * min(progress, 1.0))
                }
            }
            .frame(height: 3)
        }
    }
}

// MARK: - Medium Widget View

struct MediumWidgetView: View {
    let metrics: WidgetMetrics

    var body: some View {
        HStack(spacing: 12) {
            // Left side — main metrics
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "wrench.and.screwdriver")
                        .font(.system(size: 11, weight: .semibold))
                    Text("TechSupport")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(.secondary)

                Spacer(minLength: 0)

                HStack(spacing: 16) {
                    gauge(label: "CPU", value: metrics.cpuUsage / 100,
                          text: String(format: "%.0f%%", metrics.cpuUsage),
                          color: metrics.cpuUsage > 80 ? .red : .green)

                    gauge(label: "RAM", value: metrics.memoryPercent / 100,
                          text: String(format: "%.0f%%", metrics.memoryPercent),
                          color: metrics.memoryPercent > 85 ? .red : .green)

                    gauge(label: "Disk", value: metrics.diskPercent / 100,
                          text: String(format: "%.0f%%", metrics.diskPercent),
                          color: metrics.diskPercent > 90 ? .red : .green)
                }
            }

            // Right side — additional info
            VStack(alignment: .leading, spacing: 6) {
                Spacer(minLength: 0)

                infoRow(icon: "wifi", label: "Wi-Fi", value: metrics.formattedWifi)
                infoRow(icon: "memorychip", label: "Memory", value: metrics.formattedMemory)
                infoRow(icon: "internaldrive", label: "Disk", value: metrics.formattedDisk)
                infoRow(icon: "cpu", label: "Cores", value: "\(metrics.cpuCores)")
            }
        }
        .padding(2)
    }

    private func gauge(label: String, value: Double, text: String, color: Color) -> some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(.quaternary, lineWidth: 3)
                Circle()
                    .trim(from: 0, to: min(value, 1))
                    .stroke(color.gradient, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(text)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
            }
            .frame(width: 38, height: 38)

            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 14)
            Text(value)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .lineLimit(1)
        }
    }
}

// MARK: - Widget Definition

struct TechSupportWidget: Widget {
    let kind = "TechSupportWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MetricsProvider()) { entry in
            Group {
                switch entry.metrics.cpuUsage {
                default:
                    // WidgetKit picks the right view based on family
                    WidgetFamilyView(metrics: entry.metrics)
                }
            }
            .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("System Monitor")
        .description("Live CPU, memory, and disk usage at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct WidgetFamilyView: View {
    @Environment(\.widgetFamily) var family
    let metrics: WidgetMetrics

    var body: some View {
        switch family {
        case .systemMedium:
            MediumWidgetView(metrics: metrics)
        default:
            SmallWidgetView(metrics: metrics)
        }
    }
}
