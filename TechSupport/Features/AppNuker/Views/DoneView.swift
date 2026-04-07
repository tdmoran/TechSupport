import SwiftUI

/// Animated completion summary showing freed space.
struct DoneView: View {
    @ObservedObject var viewModel: AppnukerViewModel
    @State private var appeared = false
    @State private var checkScale: CGFloat = 0

    private var successes: [RemovalResult] {
        viewModel.removalResults.filter(\.success)
    }

    private var failures: [RemovalResult] {
        viewModel.removalResults.filter { !$0.success }
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            if failures.isEmpty {
                successView
            } else {
                partialView
            }

            Button(action: { viewModel.reset() }) {
                Label("Clean Another App", systemImage: "plus.app")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.return, modifiers: .command)

            Spacer()
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.1)) {
                checkScale = 1
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
                appeared = true
            }
        }
    }

    private var successView: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(.green.opacity(0.1))
                    .frame(width: 120, height: 120)
                    .scaleEffect(appeared ? 1 : 0.5)
                    .opacity(appeared ? 1 : 0)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.green)
                    .scaleEffect(checkScale)
            }

            Text("Cleanup Complete")
                .font(.title)
                .fontWeight(.bold)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 10)

            Text("Removed \(successes.count) item\(successes.count == 1 ? "" : "s") — \(viewModel.formattedFreedSize) freed")
                .font(.body)
                .foregroundStyle(.secondary)
                .opacity(appeared ? 1 : 0)
        }
    }

    private var partialView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.orange)
                .scaleEffect(checkScale)

            Text("Cleanup Finished")
                .font(.title)
                .fontWeight(.bold)

            Text("Removed \(successes.count) (\(viewModel.formattedFreedSize) freed) — Failed \(failures.count)")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(failures) { result in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red)
                            .font(.caption)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(result.path.lastPathComponent)
                                .font(.caption)
                                .fontWeight(.medium)
                            if let error = result.error {
                                Text(error)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: 400, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}
