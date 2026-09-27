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
| `AgentMessageView`, `ToolCallView`, `ComposerView`, `ApprovalBanner` | Agent | User bubbles, Markdown answers, human-readable tool rows (`ToolCallPresentation`), floating composer |
| `ActivityIndicator` | Shared | Loader for work without visible output: pulsing symbol, title with a moving highlight, elapsed seconds, optional hint. Used by the agent for `StreamingActivity` (waiting for the model, thinking, next step). Still with Reduce Motion |
| `AgentView` transcript | Agent | Opens at the bottom and follows a streaming answer while the user is at the bottom. Sending or retrying a message always jumps to the bottom (`AgentViewModel.latestPromptID`), even after scrolling up; the agent's own messages never move a user who scrolled up |
| `ModelPickerView` | Models | Menu grouped by provider, provider logo, capability badges |
| `ContextLengthPicker` | Models | Inspector › Context: the model's context length (Automatic or 8K–max), or the fixed size and where it is set |
| `ProviderLogo` | Shared | A provider's logo as a template image, or `server.rack` |
| `SidebarView`, `MainContentView`, `InspectorView`, `WelcomeView` | Workspace | Window shell |

## Adding a component

1. Check that an existing component cannot be extended instead.
2. Use tokens only.
3. Provide accessibility labels and traits, and make sure state is not conveyed by color alone.
4. Keep it free of business logic: it takes values and closures.
