import SwiftUI

/// The ⌘K overlay: a glass panel with a search field, a ranked,
/// keyboard-navigable list and a footer of keyboard hints.
///
/// Keyboard: ↑/↓ move, ↩ activates, ⎋ closes. The view reports activation and
/// dismissal to its owner and performs no action itself.
struct CommandPaletteView: View {
    @Bindable var viewModel: CommandPaletteViewModel
    let onActivate: (PaletteItem) -> Void
    let onDismiss: () -> Void

    @FocusState private var isSearchFocused: Bool
    @Namespace private var selection

    var body: some View {
        VStack(spacing: 0) {
            searchField
            Divider().overlay(AppColors.border)
            resultsList
            Divider().overlay(AppColors.border)
            footer
        }
        .frame(width: AppLayout.commandPaletteWidth)
        .appGlass(in: RoundedRectangle(cornerRadius: AppRadius.overlay, style: .continuous))
        .appShadow(.overlay)
        .defaultFocus($isSearchFocused, true)
        // Also after the first layout pass: focus requested during onAppear
        // alone is sometimes dropped when the overlay is inserted.
        .task { isSearchFocused = true }
        .onKeyPress(.downArrow) { viewModel.moveSelection(by: 1); return .handled }
        .onKeyPress(.upArrow) { viewModel.moveSelection(by: -1); return .handled }
        .onKeyPress(.escape) { onDismiss(); return .handled }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Command palette")
        .accessibilityAddTraits(.isModal)
    }

    private var searchField: some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(AppColors.textTertiary)
                .accessibilityHidden(true)
            TextField(viewModel.placeholder, text: $viewModel.query)
                .textFieldStyle(.plain)
                .font(.system(size: 17))
                .foregroundStyle(AppColors.textPrimary)
                .focused($isSearchFocused)
                .onSubmit(activate)
                .accessibilityLabel("Search commands")
        }
        .padding(.horizontal, AppSpacing.lg)
        .frame(height: 54)
    }

    @ViewBuilder
    private var resultsList: some View {
        if viewModel.results.isEmpty {
            VStack(spacing: AppSpacing.xs) {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 20, weight: .light))
                    .foregroundStyle(AppColors.textTertiary)
                Text("No results for “\(viewModel.query)”")
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.textTertiary)
            }
            .frame(maxWidth: .infinity, minHeight: 96)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(Array(viewModel.results.enumerated()), id: \.element.id) { index, item in
                            if viewModel.showsSections, index == 0 || viewModel.results[index - 1].section != item.section {
                                sectionTitle(item.section)
                            }
                            PaletteRow(item: item, isSelected: index == viewModel.selectedIndex, selection: selection)
                                .id(item.id)
                                .onTapGesture {
                                    viewModel.select(item)
                                    activate()
                                }
                                .onHover { hovering in
                                    if hovering { viewModel.select(item) }
                                }
                        }
                    }
                    .padding(AppSpacing.sm)
                    .appAnimation(AppAnimation.quick, value: viewModel.selectedIndex)
                }
                .frame(maxHeight: 380)
                .fixedSize(horizontal: false, vertical: true)
                .onChange(of: viewModel.selectedIndex) {
                    if let id = viewModel.selectedItem?.id { proxy.scrollTo(id) }
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: AppSpacing.lg) {
            hint("↑↓", "Navigate")
            hint("↩", "Open")
            hint("esc", "Close")
            Spacer()
        }
        .padding(.horizontal, AppSpacing.lg)
        .frame(height: 34)
        .accessibilityHidden(true)
    }

    private func hint(_ keys: String, _ label: String) -> some View {
        HStack(spacing: AppSpacing.xs + AppSpacing.xxs) {
            ShortcutBadge(shortcut: keys)
            Text(label)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textTertiary)
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(AppTypography.caption.weight(.medium))
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
    let selection: Namespace.ID

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: item.systemImage)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isSelected ? AppColors.accentText : AppColors.textSecondary)
                .frame(width: 24, height: 24)
                .background(isSelected ? AppColors.accentSubtle : AppColors.hover,
                            in: RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
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
        .frame(height: 40)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                    .fill(AppColors.selection)
                    .matchedGeometryEffect(id: "selection", in: selection)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint(item.isEnabled ? (item.shortcut.map { "Shortcut \($0)" } ?? "") : (item.disabledReason ?? "Unavailable"))
    }
}
