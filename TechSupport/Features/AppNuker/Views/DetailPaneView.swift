import SwiftUI

/// Right-side detail pane with smooth transitions and visual polish.
struct DetailPaneView: View {
    let file: FoundFile?
    let appInfo: AppInfo?

    var body: some View {
        ScrollView {
            if let file {
                fileDetail(file)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                    .id(file.id)
            } else if let appInfo {
                appDetail(appInfo)
            } else {
                placeholder
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background.opacity(0.5))
        .animation(.easeInOut(duration: 0.2), value: file?.id)
    }

    private var placeholder: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 44, weight: .thin))
                .foregroundStyle(.quaternary)
            Text("Select a file to view details")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func appDetail(_ info: AppInfo) -> some View {
        VStack(spacing: 20) {
            // App icon with shadow
            Image(nsImage: info.icon)
                .resizable()
                .frame(width: 88, height: 88)
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)

            VStack(spacing: 4) {
                Text(info.displayName)
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("v\(info.version)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Info card
            VStack(alignment: .leading, spacing: 12) {
                DetailRow(label: "Bundle ID", value: info.bundleID, icon: "tag")
                Divider()
                DetailRow(label: "Version", value: info.version, icon: "number")
                Divider()
                DetailRow(label: "Location", value: info.formattedPath, icon: "folder")
            }
            .padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .padding(20)
    }

    private func fileDetail(_ file: FoundFile) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            // File header
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.accentColor.opacity(0.1))
                        .frame(width: 44, height: 44)
                    Image(systemName: file.icon)
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(file.name)
                        .font(.headline)
                        .lineLimit(2)
                    Text(file.category.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(.fill.tertiary, in: Capsule())
                }
            }

            // Details card
            VStack(alignment: .leading, spacing: 12) {
                DetailRow(label: "Full Path", value: file.path.path, icon: "link")
                Divider()
                DetailRow(label: "Size", value: file.formattedSize, icon: "externaldrive")
                Divider()
                DetailRow(label: "Category", value: file.category.rawValue, icon: "tag")
                if file.requiresSudo {
                    Divider()
                    HStack(spacing: 6) {
                        Image(systemName: "lock.shield.fill")
                            .foregroundStyle(.orange)
                        Text("Requires administrator privileges to remove")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))

            // Actions
            HStack(spacing: 10) {
                Button(action: {
                    NSWorkspace.shared.selectFile(file.path.path, inFileViewerRootedAtPath: "")
                }) {
                    Label("Reveal in Finder", systemImage: "magnifyingglass")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                if file.path.pathExtension == "plist" {
                    Button(action: {
                        NSWorkspace.shared.open(file.path)
                    }) {
                        Label("Quick Look", systemImage: "eye")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding(20)
    }
}

// MARK: - Detail Row

struct DetailRow: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(label.uppercased())
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.tertiary)
                Text(value)
                    .font(.callout)
                    .textSelection(.enabled)
                    .lineLimit(3)
            }
        }
    }
}
