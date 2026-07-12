import AppKit

enum SettingsTab: Hashable {
    case general
    case favorites
    case excludedApps
}

enum SettingsKeyAction {
    @MainActor
    static func handle(
        event: NSEvent,
        isTextEditing: Bool,
        selectTab: (SettingsTab) -> Void,
        focusFavoritesSearch: () -> Void,
        showHelp: () -> Void
    ) -> Bool {
        guard !isTextEditing else {
            return false
        }

        if KeyboardHelpKeyAction.isHelpEvent(event) {
            showHelp()
            return true
        }

        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard modifiers.contains(.command),
              !modifiers.contains(.shift),
              !modifiers.contains(.option),
              !modifiers.contains(.control),
              let key = event.charactersIgnoringModifiers?.lowercased()
        else {
            return false
        }

        switch key {
        case "1":
            selectTab(.general)
            return true
        case "2":
            selectTab(.favorites)
            return true
        case "3":
            selectTab(.excludedApps)
            return true
        case "f":
            selectTab(.favorites)
            focusFavoritesSearch()
            return true
        default:
            return false
        }
    }
}
