import SwiftUI

/// Root view that switches between states with smooth transitions.
struct AppNukerTabView: View {
    @StateObject private var viewModel = AppnukerViewModel()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Color(nsColor: .windowBackgroundColor).opacity(0.95)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            Group {
                switch viewModel.state {
                case .idle:
                    DropZoneView(viewModel: viewModel)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.95)),
                            removal: .opacity.combined(with: .scale(scale: 1.05))
                        ))

                case .scanning:
                    AppNukerScanningView(appInfo: viewModel.appInfo)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))

                case .results:
                    ResultsView(viewModel: viewModel)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .opacity
                        ))

                case .removing:
                    AppNukerRemovingView()
                        .transition(.opacity)

                case .done:
                    DoneView(viewModel: viewModel)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))

                case .error(let message):
                    AppNukerErrorView(message: message) {
                        viewModel.reset()
                    }
                    .transition(.opacity)
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: viewModel.state)
        }
        
        
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            viewModel.handleDrop(providers: providers)
        }
        .keyboardShortcut("r", modifiers: .command, action: {
            viewModel.reset()
        })
    }
}

// MARK: - Scanning View

struct AppNukerScanningView: View {
    let appInfo: AppInfo?
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            if let info = appInfo {
                Image(nsImage: info.icon)
                    .resizable()
                    .frame(width: 80, height: 80)
                    .shadow(color: .blue.opacity(0.3), radius: pulse ? 20 : 10)
                    .scaleEffect(pulse ? 1.05 : 1.0)
                    .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulse)
            }

            VStack(spacing: 8) {
                Text("Scanning for related files...")
                    .font(.title3)
                    .fontWeight(.medium)

                if let info = appInfo {
                    Text(info.displayName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            ProgressView()
                .scaleEffect(1.2)
                .padding(.top, 4)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { pulse = true }
    }
}

// MARK: - Removing View

struct AppNukerRemovingView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "trash.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.red)
                .symbolEffect(.pulse)

            Text("Moving files to Trash...")
                .font(.title3)
                .fontWeight(.medium)

            ProgressView()
                .scaleEffect(1.2)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Error View

struct AppNukerErrorView: View {
    let message: String
    let onRetry: () -> Void

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.orange)
                .scaleEffect(appeared ? 1.0 : 0.5)
                .animation(.spring(response: 0.5, dampingFraction: 0.6), value: appeared)

            Text("Something went wrong")
                .font(.title2)
                .fontWeight(.semibold)

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)

            Button("Try Again") {
                onRetry()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { appeared = true }
    }
}

// MARK: - Keyboard Shortcut Extension

extension View {
    func keyboardShortcut(_ key: KeyEquivalent, modifiers: EventModifiers, action: @escaping () -> Void) -> some View {
        self.background(
            Button(action: action) { EmptyView() }
                .keyboardShortcut(key, modifiers: modifiers)
                .frame(width: 0, height: 0)
                .opacity(0)
        )
    }
}
