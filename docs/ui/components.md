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
| `ContextMeterView` | Progress ring, “2.2K / 32.8K” and the percentage over a 24-segment bar (`MeterSegments`). Segments fill left to right in a wave and empty right to left; the ring and numbers roll; the leading segment breathes while a run is in progress; accent, then warning, then danger near the limit | Spoken value for VoiceOver; “Over budget” in text; still with Reduce Motion |
| `SubtleButtonStyle` (`.subtle`) | Default low-emphasis button | Hover background |
| `PrimaryButtonStyle` (`.primary`) | The one main action of an area | Indigo fill, faint inner edge; dimmed when disabled |
| `SecondaryButtonStyle` (`.secondary`) | Other actions (Deny, Retry, Revert) | Raised neutral fill, hairline border that strengthens on hover |
| `IconButtonStyle` (`.icon(prominent:)`) | Square symbol buttons (send, stop) | 28 pt, primary or secondary look |
| `appFloating(in:interactive:elevated:)`, `appButton(prominent:)` | Opaque raised surfaces and the primary/secondary choice | `surfaceRaised`, border, optional hover and shadow ([ADR 0023](../decisions/0023-opaque-linear-surfaces.md)) |
| `ProjectBadge` | Colored initial identifying a project | Stable hue from the name |
| `AgentAvatar` | The agent's mark | Sparkles animate while working |
| `MarkdownText`, `CodeBlockView` | Model answers | Paragraphs, headings, lists, fenced code with a Copy button. Parsed only once a message is complete |

Feature views worth knowing:

| View | Feature | Notes |
|---|---|---|
| `CommandPaletteView` | CommandPalette | Overlay with keyboard handling. Performs no actions |
| `AgentMessageView`, `ToolCallView`, `ComposerView`, `ApprovalBanner` | Agent | User bubbles, Markdown answers, human-readable tool rows (`ToolCallPresentation`), floating composer (paperclip, drop target) |
| `PromptEditor` | Agent | The composer's text field: an `NSTextView`, because SwiftUI's vertical `TextField` hangs on long pasted text. Plain text, grows to 10 lines then scrolls; ↩ sends, ⌥↩/⇧↩ new line. The composer is its own view (`AgentComposer`), so typing never re-renders the transcript |
| `DiffView`, `DiffStatView` | Shared | Diffs like Linear's, in the approval card and the Changes tab: file header (icon, name, folder, “New file”, “+12 −3”), one row per line with its number, a thin red or green bar and faint tint on changed lines, syntax colors (`SyntaxHighlighter`: keywords orange, strings green, numbers yellow, types and tags blue, attributes purple, comments dim). Rows span the full width; long lines scroll. Two layouts: unified, or split (old left, new right; a run of removed lines faces the added lines that replace them, `FileDiff.Hunk.splitRows`; long lines are clipped per side). “+”/“−” signs keep changes readable without color |
| `ChangesView` | Changes | Linear's review screen: “Pending review N” list of two-line rows (name and “+12 −3”; status mark, status and folder), ↑/↓ to move; the selected file under a breadcrumb header with Unified/Split pills (remembered), Revert and Accept, its diff in a bordered card |
| `PillPicker` | Shared | Linear's view switcher: pill buttons, the selected one on a raised fill |
| `AttachmentChip` | Agent | An attached file: icon, name, size, remove button in the composer; path in the tooltip |
| `ActivityIndicator` | Shared | Loader for work without visible output: pulsing symbol, title with a moving highlight, elapsed time (`DurationFormatter`: “12 s”, “2:05 min”, “1:05 h”, used by every timer), optional hint. Used by the agent for `StreamingActivity` (waiting for the model, thinking, next step). Still with Reduce Motion |
| `AgentView` transcript | Agent | Opens at the bottom and follows a streaming answer while the user is at the bottom. Sending or retrying a message always jumps to the bottom (`AgentViewModel.latestPromptID`), even after scrolling up; the agent's own messages never move a user who scrolled up. It renders the latest 30 messages (`AgentViewModel.messagePageSize`); scrolling up to “Show N earlier messages” (or clicking it) loads the previous page, and the view keeps its place. Rows are in a `VStack`, not a `LazyVStack`: lazy rows are placed with estimated heights, and with the bottom anchor a very tall message (a long prompt, a whole file in a tool call) left the view on a blank area below the conversation. Rows are equatable, so a streaming answer does not re-render the others |
| `ModelPropertiesView` | Models | Inspector › Model rows: model menu grouped by provider (with its logo), context, temperature, reasoning, abilities |
| `PropertyRow`, `PropertyValue`, `PropertyLabel` | Shared | Linear's property rows: a quiet 84 pt label column; values with a tinted icon (`AppColors.Hue`: context teal, temperature blue → orange → red, reasoning and branch purple, instructions green), highlighted on hover when they open a menu (`propertyMenuStyle()`); labels as a colored dot and a word on a hairline pill (abilities: tools orange, reasoning purple, vision blue) |
| `ProviderLogo` | Shared | A provider's logo as a template image, or `server.rack` |
| `SidebarView`, `MainContentView`, `InspectorView`, `WelcomeView` | Workspace | Window shell |
| `SidebarRows` (`SidebarIcon`, `SessionRowLabel`, `RunningIcon`, `StatusDot`) | Workspace | Sidebar marks: view icons in their hue (Files blue, Changes orange with its count, Terminal teal); a running session shows a turning accent arc and a light sweeping its title (`SweepingText`), one awaiting approval an orange hand; the footer's server status has a green dot when a server answered, red otherwise, always with words |

## Adding a component

1. Check that an existing component cannot be extended instead.
2. Use tokens only.
3. Provide accessibility labels and traits, and make sure state is not conveyed by color alone.
4. Keep it free of business logic: it takes values and closures.
