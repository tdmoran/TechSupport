import SwiftUI

/// Wrapper for a grouped section of files.
struct FileGroup: Identifiable {
    let category: FileCategory
    let files: [FoundFile]
    var id: String { category.rawValue }
}

/// List of found files with search, sort, grouping, and checkboxes.
struct FileListView: View {
    @ObservedObject var viewModel: AppnukerViewModel

    /// When sorting by category, group files into sections.
    private var groups: [FileGroup] {
        let files = viewModel.displayFiles
        let grouped = Dictionary(grouping: files, by: \.category)
        return FileCategory.allCases.compactMap { category in
            guard let catFiles = grouped[category], !catFiles.isEmpty else { return nil }
            return FileGroup(category: category, files: catFiles)
        }
    }

    /// Whether we're in grouped mode (category sort without active search).
    private var useGroupedLayout: Bool {
        viewModel.sortOrder == .category
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search + sort toolbar
            searchBar
            Divider()

            // File list
            if viewModel.displayFiles.isEmpty && !viewModel.searchText.isEmpty {
                emptySearch
            } else if useGroupedLayout {
                groupedList
            } else {
                flatList
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                TextField("Filter files...", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                    .font(.subheadline)
                if !viewModel.searchText.isEmpty {
                    Button(action: { viewModel.searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(.fill.quaternary, in: RoundedRectangle(cornerRadius: 7))

            sortMenu
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private var sortMenu: some View {
        Menu {
            ForEach(SortOrder.allCases) { order in
                Button(action: { viewModel.sortOrder = order }) {
                    HStack {
                        Text(order.rawValue)
                        if viewModel.sortOrder == order {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .menuStyle(.borderlessButton)
        .frame(width: 24)
        .help("Sort files")
    }

    // MARK: - Grouped List (Category sort)

    private var groupedList: some View {
        List {
            ForEach(groups) { group in
                Section {
                    ForEach(group.files) { file in
                        fileRow(file)
                    }
                } header: {
                    sectionHeader(group)
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Flat List (Name/Size sort)

    private var flatList: some View {
        List {
            ForEach(viewModel.displayFiles) { file in
                fileRow(file)
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Empty Search

    private var emptySearch: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28, weight: .thin))
                .foregroundStyle(.quaternary)
            Text("No files match \"\(viewModel.searchText)\"")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Row & Header

    private func fileRow(_ file: FoundFile) -> some View {
        let isChecked = viewModel.selectedFileIDs.contains(file.id)
        let isHighlighted = viewModel.selectedFile?.id == file.id
        return FileRowView(
            file: file,
            isChecked: isChecked,
            isHighlighted: isHighlighted,
            onToggle: { viewModel.toggleFile(file) },
            onSelect: { viewModel.selectFile(file) }
        )
    }

    private func sectionHeader(_ group: FileGroup) -> some View {
        let iconName = group.files.first?.icon ?? "folder"
        return HStack {
            Image(systemName: iconName)
                .foregroundStyle(Color.accentColor)
            Text(group.category.rawValue)
                .font(.subheadline)
                .fontWeight(.semibold)
            Spacer()
            Text("\(group.files.count)")
                .font(.caption2)
                .fontWeight(.medium)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.fill.tertiary, in: Capsule())
        }
    }
}

// MARK: - File Row View

struct FileRowView: View {
    let file: FoundFile
    let isChecked: Bool
    let isHighlighted: Bool
    let onToggle: () -> Void
    let onSelect: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 10) {
            checkboxButton
            fileInfo
            Spacer()
            sizeLabel
            sudoIndicator
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 4)
        .background(rowBackground)
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
        .onHover { isHovering = $0 }
    }

    private var checkboxButton: some View {
        Button(action: onToggle) {
            ZStack {
                Circle()
                    .fill(isChecked ? Color.accentColor : Color.clear)
                    .frame(width: 22, height: 22)
                Circle()
                    .strokeBorder(
                        isChecked ? Color.accentColor : Color.secondary.opacity(0.4),
                        lineWidth: 1.5
                    )
                    .frame(width: 22, height: 22)
                if isChecked {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isChecked)
        }
        .buttonStyle(.plain)
    }

    private var fileInfo: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(file.name)
                .font(.body)
                .fontWeight(isHighlighted ? .medium : .regular)
                .lineLimit(1)
                .truncationMode(.middle)

            Text(file.path.deletingLastPathComponent().path)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .truncationMode(.head)
        }
    }

    private var sizeLabel: some View {
        Text(file.formattedSize)
            .font(.caption)
            .foregroundStyle(.secondary)
            .monospacedDigit()
    }

    @ViewBuilder
    private var sudoIndicator: some View {
        if file.requiresSudo {
            Image(systemName: "lock.shield.fill")
                .font(.caption2)
                .foregroundStyle(.orange)
                .help("Requires administrator privileges to remove")
        }
    }

    private var rowBackground: some View {
        let fillColor: Color = isHighlighted
            ? Color.accentColor.opacity(0.1)
            : (isHovering ? Color.primary.opacity(0.03) : Color.clear)
        return RoundedRectangle(cornerRadius: 6).fill(fillColor)
    }
}
