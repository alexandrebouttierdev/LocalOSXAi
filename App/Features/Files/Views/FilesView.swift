import SwiftUI

/// File browser: fuzzy search over paths (⌘P) and a numbered preview.
struct FilesView: View {
    @Bindable var viewModel: FilesViewModel
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "magnifyingglass").foregroundStyle(AppColors.textTertiary).accessibilityHidden(true)
                    TextField("Search files", text: $viewModel.query)
                        .textFieldStyle(.plain)
                        .focused($isSearchFocused)
                        .onSubmit { if let first = viewModel.results.first { Task { await viewModel.select(first) } } }
                        .accessibilityLabel("Search files")
                }
                .font(AppTypography.body)
                .padding(.horizontal, AppSpacing.md)
                .frame(height: 30)
                .appGlass(in: Capsule())
                .padding(AppSpacing.sm)

                List(viewModel.results, id: \.self, selection: Binding(
                    get: { viewModel.selectedPath },
                    set: { path in if let path { Task { await viewModel.select(path) } } }
                )) { path in
                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        Text((path as NSString).lastPathComponent)
                            .lineLimit(1)
                        let folder = (path as NSString).deletingLastPathComponent
                        if !folder.isEmpty {
                            Text(folder)
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.textTertiary)
                                .lineLimit(1)
                                .truncationMode(.head)
                        }
                    }
                    .tag(path)
                }
                .listStyle(.sidebar)
                .overlay {
                    if viewModel.isLoading { ProgressView() }
                }
            }
            .frame(minWidth: 220, idealWidth: 280, maxWidth: 400)

            preview
                .frame(minWidth: 320)
        }
        .task { await viewModel.load() }
        .onAppear { isSearchFocused = true }
        .onChange(of: viewModel.searchFocusRequest) { isSearchFocused = true }
    }

    @ViewBuilder
    private var preview: some View {
        switch viewModel.preview {
        case .none:
            EmptyStateView(systemImage: "doc.text", title: "Files",
                           message: "Search with ⌘P, then select a file to preview it. The agent sees files the same way.")
        case .loading:
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        case .unavailable(let reason):
            EmptyStateView(systemImage: "eye.slash", title: "No preview", message: reason)
        case .text(let text):
            VStack(spacing: 0) {
                HStack {
                    Text(viewModel.selectedPath ?? "")
                        .font(AppTypography.headline)
                        .lineLimit(1)
                        .truncationMode(.head)
                    Spacer()
                }
                .padding(.horizontal, AppSpacing.md)
                .frame(height: 40)
                Divider().overlay(AppColors.border)
                ScrollView([.vertical, .horizontal]) {
                    NumberedCodeView(text: text)
                        .padding(AppSpacing.md)
                }
                .background(AppColors.codeBackground)
            }
        }
    }
}

/// Read-only code with line numbers.
private struct NumberedCodeView: View {
    let lines: [String]

    init(text: String) {
        var lines = text.components(separatedBy: "\n")
        if text.hasSuffix("\n") { lines.removeLast() }
        self.lines = lines
    }

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                HStack(alignment: .firstTextBaseline, spacing: AppSpacing.md) {
                    Text("\(index + 1)")
                        .foregroundStyle(AppColors.textTertiary)
                        .frame(width: 44, alignment: .trailing)
                    Text(line.isEmpty ? " " : line)
                        .foregroundStyle(AppColors.textPrimary)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .font(AppTypography.code)
            }
        }
        .textSelection(.enabled)
    }
}
