import SwiftUI

extension CommandShortcut {
    /// SwiftUI representation used to register the shortcut on menu items.
    var keyboardShortcut: KeyboardShortcut {
        var eventModifiers: EventModifiers = []
        if modifiers.contains(.command) { eventModifiers.insert(.command) }
        if modifiers.contains(.shift) { eventModifiers.insert(.shift) }
        if modifiers.contains(.option) { eventModifiers.insert(.option) }
        if modifiers.contains(.control) { eventModifiers.insert(.control) }
        return KeyboardShortcut(KeyEquivalent(key), modifiers: eventModifiers)
    }
}
