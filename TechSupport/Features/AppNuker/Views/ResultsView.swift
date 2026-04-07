import SwiftUI

/// Main results view with file list, detail pane, and action toolbar.
struct ResultsView: View {
    @ObservedObject var viewModel: AppnukerViewModel
    @State private var showConfirmation = false
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            if let info = viewModel.appInfo {
                appHeader(info)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : -10)
            }

            Divider()

            HSplitView {
                FileListView(viewModel: viewModel)
                    .frame(minWidth: 320, idealWidth: 420)

                DetailPaneView(
                    file: viewModel.selectedFile,
                    appInfo: viewModel.appInfo
                )
                .frame(minWidth: 260, idealWidth: 320)
            }

            Divider()

            toolbar
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 10)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                appeared = true
            }
        }
    }

    private func appHeader(_ info: AppInfo) -> some View {
        HStack(spacing: 14) {
            Image(nsImage: info.icon)
                .resizable()
                .frame(width: 44, height: 44)
                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(info.displayName)
                    .font(.headline)
                HStack(spacing: 6) {
                    Text(info.bundleID)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("v\(info.version)")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(.fill.tertiary, in: Capsule())
                }
            }

            Spacer()

            HStack(spacing: 12) {
                StatBadge(
                    label: "Items",
                    value: "\(viewModel.foundFiles.count)",
                    icon: "doc.on.doc"
                )
                StatBadge(
                    label: "Total",
                    value: viewModel.formattedTotalSize,
                    icon: "internaldrive"
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.bar)
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            Menu {
                Button("Select All") { viewModel.selectAll() }
                Button("Deselect All") { viewModel.deselectAll() }
                Divider()
                Button("Select User Files Only") {
                    viewModel.selectUserFilesOnly()
                }
            } label: {
                Label("Selection", systemImage: "checklist")
            }
            .menuStyle(.borderlessButton)
            .frame(width: 100)

            Spacer()

            if viewModel.hasSelection {
                Text("\(viewModel.selectedCount) selected — \(viewModel.formattedSelectedSize)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Spacer()

            Button(action: { viewModel.reset() }) {
                Label("New App", systemImage: "plus.app")
            }
            .buttonStyle(.bordered)
            .keyboardShortcut("n", modifiers: .command)

            Button(action: { showConfirmation = true }) {
                Label("Move to Trash", systemImage: "trash")
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(!viewModel.hasSelection)
            .keyboardShortcut(.delete, modifiers: .command)
            .alert("Move \(viewModel.selectedCount) items to Trash?", isPresented: $showConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Move to Trash", role: .destructive) {
                    viewModel.removeSelected()
                }
            } message: {
                Text("This will move \(viewModel.formattedSelectedSize) of data to the Trash. System-level files will be permanently deleted (requires admin password).")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }
}

// MARK: - Stat Badge

struct StatBadge: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .monospacedDigit()
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.fill.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }
}
