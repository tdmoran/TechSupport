import SwiftUI
import UniformTypeIdentifiers

/// Beautiful drag-and-drop landing zone with animated visual feedback.
struct DropZoneView: View {
    @ObservedObject var viewModel: AppnukerViewModel
    @State private var isTargeted = false
    @State private var appeared = false
    @State private var iconBounce = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                // Glow ring
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.accentColor.opacity(0.15), .clear],
                            center: .center,
                            startRadius: 40,
                            endRadius: 120
                        )
                    )
                    .frame(width: 240, height: 240)
                    .scaleEffect(isTargeted ? 1.2 : 1.0)
                    .opacity(isTargeted ? 1 : 0.5)

                // Drop zone container
                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(
                        isTargeted
                            ? Color.accentColor
                            : Color.secondary.opacity(0.3),
                        style: StrokeStyle(
                            lineWidth: isTargeted ? 3 : 2,
                            dash: isTargeted ? [] : [12, 6]
                        )
                    )
                    .frame(width: 280, height: 200)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(.ultraThinMaterial)
                            .shadow(
                                color: isTargeted ? Color.accentColor.opacity(0.2) : .clear,
                                radius: 20
                            )
                    )

                VStack(spacing: 14) {
                    Image(systemName: isTargeted ? "arrow.down.circle.fill" : "app.badge.checkmark")
                        .font(.system(size: 44, weight: .light))
                        .foregroundStyle(isTargeted ? Color.accentColor : Color.secondary)
                        .symbolEffect(.bounce, value: iconBounce)
                        .offset(y: appeared ? 0 : -10)
                        .opacity(appeared ? 1 : 0)

                    Text(isTargeted ? "Release to Scan" : "Drop an App Here")
                        .font(.title3)
                        .fontWeight(.medium)

                    Text("Find and remove leftover files")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isTargeted)

            // Divider
            HStack {
                Rectangle()
                    .fill(.secondary.opacity(0.2))
                    .frame(width: 60, height: 1)
                Text("or")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Rectangle()
                    .fill(.secondary.opacity(0.2))
                    .frame(width: 60, height: 1)
            }

            // Browse button
            Button(action: browseForApp) {
                Label("Browse Applications", systemImage: "folder")
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 10)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            viewModel.handleDrop(providers: providers)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.1)) {
                appeared = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                iconBounce.toggle()
            }
        }
    }

    private func browseForApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.message = "Select an application to clean"
        panel.prompt = "Scan"

        if panel.runModal() == .OK, let url = panel.url {
            viewModel.loadApp(at: url)
        }
    }
}
