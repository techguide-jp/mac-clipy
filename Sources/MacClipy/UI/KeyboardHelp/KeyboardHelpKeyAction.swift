import AppKit
import Carbon

enum KeyboardHelpKeyAction {
    static func isHelpEvent(_ event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard !modifiers.contains(.option),
              !modifiers.contains(.control)
        else {
            return false
        }

        let isQuestionMark = event.characters == "?"
        let isSlashKey = event.keyCode == UInt16(kVK_ANSI_Slash)
        guard isQuestionMark || isSlashKey else {
            return false
        }

        if modifiers.contains(.command) {
            return modifiers.subtracting([.command, .shift]).isEmpty
        }

        return modifiers == .shift || isQuestionMark
    }
}
