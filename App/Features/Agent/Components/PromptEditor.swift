import AppKit
import SwiftUI

/// The composer's text field: an AppKit text view.
///
/// SwiftUI's vertical `TextField` lays out all of its text again on every
/// change and hangs on a long pasted prompt; `NSTextView` handles large text
/// natively. It pastes plain text only, grows with its content up to
/// `maxLines`, then scrolls. ↩ submits; ⌥↩ and ⇧↩ insert a new line.
struct PromptEditor: NSViewRepresentable {
    @Binding var text: String
    /// The height the content needs, for the SwiftUI frame.
    @Binding var height: CGFloat
    var maxLines = 10
    let onSubmit: () -> Void

    /// `AppTypography.body`, as AppKit needs it.
    @MainActor static let font = NSFont(name: AppTypography.family, size: AppTypography.bodySize)
        ?? .systemFont(ofSize: AppTypography.bodySize)
    @MainActor static let lineHeight = NSLayoutManager().defaultLineHeight(for: font)

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        // TextKit 1: its layout manager gives the used height directly.
        let textView = NSTextView(usingTextLayoutManager: false)
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.font = Self.font
        textView.textColor = NSColor(AppColors.textPrimary)
        textView.insertionPointColor = NSColor(AppColors.accent)
        textView.textContainerInset = .zero
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        // Prompts are often code: never “fix” quotes, dashes or spelling.
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.setAccessibilityLabel("Message")
        // Dropped files are attached by the conversation, not inserted as paths.
        textView.unregisterDraggedTypes()
        textView.registerForDraggedTypes([.string])
        textView.string = text

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        let coordinator = context.coordinator
        Task { @MainActor in
            textView.window?.makeFirstResponder(textView)
            coordinator.updateHeight(of: textView)
        }
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = scrollView.documentView as? NSTextView, textView.string != text else { return }
        // Set from outside (sent, suggestion chosen): replace, and measure
        // after this update, since state cannot change during one.
        textView.string = text
        let coordinator = context.coordinator
        Task { @MainActor in coordinator.updateHeight(of: textView) }
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: PromptEditor

        init(_ parent: PromptEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            updateHeight(of: textView)
        }

        func textView(_ textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            // ⌥↩ sends `insertNewlineIgnoringFieldEditor:`, which inserts a line by default.
            guard selector == #selector(NSResponder.insertNewline(_:)) else { return false }
            if NSApp.currentEvent?.modifierFlags.contains(.shift) == true {
                textView.insertNewlineIgnoringFieldEditor(nil)
            } else {
                parent.onSubmit()
            }
            return true
        }

        func updateHeight(of textView: NSTextView) {
            guard let layoutManager = textView.layoutManager, let container = textView.textContainer else { return }
            layoutManager.ensureLayout(for: container)
            let used = layoutManager.usedRect(for: container).height
            let height = min(max(used, PromptEditor.lineHeight), PromptEditor.lineHeight * CGFloat(parent.maxLines))
            if abs(parent.height - height) > 0.5 { parent.height = height }
        }
    }
}
