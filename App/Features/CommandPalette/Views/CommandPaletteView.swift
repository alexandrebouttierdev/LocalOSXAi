import SwiftUI

/// The ⌘K overlay: a search field above a ranked, keyboard-navigable list.
///
/// Keyboard: ↑/↓ move, ↩ activates, ⎋ closes. The view reports activation and
/// dismissal to its owner and performs no action itself.
struct CommandPaletteView: View {
    @Bindable var viewModel: CommandPaletteViewModel
    let onActivate: (PaletteItem) -> Void
    let onDismiss: () -> Void

    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            searchField
            Divider().overlay(AppColors.border)
            resultsList
        }
        .frame(width: AppLayout.commandPaletteWidth)
        .background(AppColors.surfaceRaised, in: RoundedRectangle(cornerRadius: AppRadius.overlay, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.overlay, style: .continuous)
                .strokeBorder(AppColors.borderStrong, lineWidth: AppBorders.hairline)
        )
        .appShadow(.overlay)
        .onAppear { isSearchFocused = true }
        .onKeyPress(.downArrow) { viewModel.moveSelection(by: 1); return .handled }
        .onKeyPress(.upArrow) { viewModel.moveSelection(by: -1); return .handled }
        .onKeyPress(.escape) { onDismiss(); return .handled }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Command palette")
        .accessibilityAddTraits(.isModal)
    }

    private var searchField: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AppColors.textTertiary)
                .accessibilityHidden(true)
            TextField(viewModel.placeholder, text: $viewModel.query)
                .textFieldStyle(.plain)
                .font(.title3)
                .foregroundStyle(AppColors.textPrimary)
                .focused($isSearchFocused)
                .onSubmit(activate)
                .accessibilityLabel("Search commands")
        }
        .padding(.horizontal, AppSpacing.lg)
        .frame(height: 48)
    }

    @ViewBuilder
    private var resultsList: some View {
        if viewModel.results.isEmpty {
            Text("No results")
                .font(AppTypography.body)
                .foregroundStyle(AppColors.textTertiary)
                .frame(maxWidth: .infinity, minHeight: 80)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(viewModel.results.enumerated()), id: \.element.id) { index, item in
                            if viewModel.showsSections, index == 0 || viewModel.results[index - 1].section != item.section {
                                sectionTitle(item.section)
                            }
                            PaletteRow(item: item, isSelected: index == viewModel.selectedIndex)
                                .id(item.id)
                                .onTapGesture {
                                    viewModel.select(item)
                                    activate()
                                }
                        }
                    }
                    .padding(AppSpacing.xs + AppSpacing.xxs)
                }
                .frame(maxHeight: 360)
                .fixedSize(horizontal: false, vertical: true)
                .onChange(of: viewModel.selectedIndex) {
                    if let id = viewModel.selectedItem?.id { proxy.scrollTo(id) }
                }
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(AppTypography.caption)
            .foregroundStyle(AppColors.textTertiary)
            .padding(.horizontal, AppSpacing.sm + AppSpacing.xxs)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xs)
            .accessibilityAddTraits(.isHeader)
    }

    private func activate() {
        if let item = viewModel.activateSelection() { onActivate(item) }
    }
}

private struct PaletteRow: View {
    let item: PaletteItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: AppSpacing.sm + AppSpacing.xxs) {
            Image(systemName: item.systemImage)
                .frame(width: 16)
                .foregroundStyle(isSelected ? AppColors.textPrimary : AppColors.textSecondary)
                .accessibilityHidden(true)
            Text(item.title)
                .font(AppTypography.body)
                .foregroundStyle(item.isEnabled ? AppColors.textPrimary : AppColors.textTertiary)
            if let detail = item.isEnabled ? item.subtitle : item.disabledReason {
                Text(detail)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textTertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: AppSpacing.sm)
            if let shortcut = item.shortcut {
                ShortcutBadge(shortcut: shortcut)
            }
        }
        .padding(.horizontal, AppSpacing.sm + AppSpacing.xxs)
        .frame(height: 34)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                .fill(isSelected ? AppColors.selection : .clear)
        )
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint(item.isEnabled ? (item.shortcut.map { "Shortcut \($0)" } ?? "") : (item.disabledReason ?? "Unavailable"))
    }
}
