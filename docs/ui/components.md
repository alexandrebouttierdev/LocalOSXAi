# Components

Shared components live in `App/Shared/Components/`. Components used by only one feature live
in that feature's `Components/` or `Views/` folder.

| Component | Purpose | Notes |
|---|---|---|
| `SectionHeader` | Sidebar and inspector section titles, with an optional trailing accessory | Header trait for VoiceOver |
| `ShortcutBadge` | Discreet keycap (“⌘K”) | Hidden from VoiceOver; the control exposes the shortcut |
| `StatusBadge` | Status as text + tone, with an icon or a small dot; never wraps | Never color alone: the text carries the meaning |
| `FlowLayout` | Wraps chips to the next row instead of squeezing them (inspector capabilities) | Reading order is preserved |
| `EmptyStateView` | Empty or not-yet-available content | One icon, a title, a sentence, and at most a couple of actions |
| `ContextMeterView` | “38.4K / 100K context” with a gauge | Spoken value for VoiceOver; “Over budget” in text |
| `SubtleButtonStyle` (`.subtle`) | Default low-emphasis button | Hover background |
| `PrimaryButtonStyle` (`.primary`) | Fallback for prominent glass buttons before macOS 26 | Accent fill; dimmed when disabled |
| `appGlass(in:)`, `appGlassButton(prominent:)`, `AppGlassContainer`, `appGlassID` | Glass surfaces and buttons | Liquid Glass on macOS 26, material fallback |
| `ProjectBadge` | Colored initial identifying a project | Stable hue from the name |
| `AgentAvatar` | The agent's mark | Sparkles animate while working |
| `MarkdownText`, `CodeBlockView` | Model answers | Paragraphs, headings, lists, fenced code with a Copy button. Parsed only once a message is complete |

Feature views worth knowing:

| View | Feature | Notes |
|---|---|---|
| `CommandPaletteView` | CommandPalette | Overlay with keyboard handling. Performs no actions |
| `AgentMessageView`, `ToolCallView`, `ComposerView`, `ApprovalBanner` | Agent | User bubbles, Markdown answers, human-readable tool rows (`ToolCallPresentation`), floating glass composer |
| `ModelPickerView` | Models | Menu grouped by provider, plus capability badges |
| `SidebarView`, `MainContentView`, `InspectorView`, `WelcomeView` | Workspace | Window shell |

## Adding a component

1. Check that an existing component cannot be extended instead.
2. Use tokens only.
3. Provide accessibility labels and traits, and make sure state is not conveyed by color alone.
4. Keep it free of business logic: it takes values and closures.
