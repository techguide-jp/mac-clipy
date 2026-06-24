@preconcurrency import AppKit
import Carbon
import SwiftUI

@MainActor
struct KeyboardEventBridge: NSViewRepresentable {
    let onEvent: @MainActor (NSEvent, Bool) -> Bool

    func makeNSView(context: Context) -> KeyBridgeView {
        let view = KeyBridgeView()
        context.coordinator.install(for: view, onEvent: onEvent)
        return view
    }

    func updateNSView(_: KeyBridgeView, context: Context) {
        context.coordinator.onEvent = onEvent
    }

    static func dismantleNSView(_: KeyBridgeView, coordinator: Coordinator) {
        coordinator.removeMonitor()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class KeyBridgeView: NSView {}

    final class Coordinator {
        var onEvent: (@MainActor (NSEvent, Bool) -> Bool)?
        private weak var view: KeyBridgeView?
        private var monitor: Any?

        func install(for view: KeyBridgeView, onEvent: @escaping @MainActor (NSEvent, Bool) -> Bool) {
            self.view = view
            self.onEvent = onEvent
            removeMonitor()

            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                nonisolated(unsafe) let unsafeSelf = self
                nonisolated(unsafe) let unsafeEvent = event
                let shouldConsume = MainActor.assumeIsolated {
                    guard let unsafeSelf,
                          let view = unsafeSelf.view,
                          unsafeEvent.window === view.window,
                          let onEvent = unsafeSelf.onEvent
                    else {
                        return false
                    }

                    let isTextEditing = unsafeEvent.window?.firstResponder is NSTextView
                    return onEvent(unsafeEvent, isTextEditing)
                }
                return shouldConsume ? nil : event
            }
        }

        func removeMonitor() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
        }

        deinit {
            removeMonitor()
        }
    }
}

enum HistoryPopupKeyAction {
    @MainActor
    static func handle(event: NSEvent, isTextEditing: Bool, model: HistoryPopupModel) -> Bool {
        if KeyboardHelpKeyAction.isHelpEvent(event) {
            model.requestHelp()
            return true
        }

        if handleCommand(event: event, model: model) {
            return true
        }

        if let keyActionHandled = handleKeyAction(event: event, isTextEditing: isTextEditing, model: model) {
            return keyActionHandled
        }

        guard !isTextEditing,
              shouldAppendToSearch(event),
              let text = event.charactersIgnoringModifiers
        else {
            return false
        }

        model.appendSearchText(text)
        return true
    }

    @MainActor
    private static func handleKeyAction(
        event: NSEvent,
        isTextEditing: Bool,
        model: HistoryPopupModel
    ) -> Bool? {
        switch event.keyCode {
        case UInt16(kVK_Return):
            model.chooseSelectedItem()
            return true
        case UInt16(kVK_Escape):
            model.close()
            return true
        case UInt16(kVK_DownArrow):
            model.moveSelection(by: 1)
            return true
        case UInt16(kVK_UpArrow):
            model.moveSelection(by: -1)
            return true
        case UInt16(kVK_Delete):
            guard !isTextEditing else {
                return false
            }
            return model.deleteLastSearchCharacter()
        case UInt16(kVK_LeftArrow):
            guard model.query.isEmpty else {
                return false
            }
            model.selectMode(.all)
            return true
        case UInt16(kVK_RightArrow):
            guard model.query.isEmpty else {
                return false
            }
            model.selectMode(.favorites)
            return true
        default:
            return nil
        }
    }

    @MainActor
    private static func handleCommand(event: NSEvent, model: HistoryPopupModel) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard modifiers.contains(.command),
              !modifiers.contains(.option),
              !modifiers.contains(.control),
              let key = event.charactersIgnoringModifiers?.lowercased()
        else {
            return false
        }

        if key == "d", !modifiers.contains(.shift) {
            model.toggleFavoriteForSelectedItem()
            return true
        }

        if key == "f", modifiers.contains(.shift) {
            model.toggleMode()
            return true
        }

        if !modifiers.contains(.shift),
           let index = Int(key),
           (AppConstants.Keyboard.firstFolderShortcutIndex ... AppConstants.Keyboard.lastFolderShortcutIndex)
           .contains(index) {
            model.selectFolderByShortcut(index)
            return true
        }

        return false
    }

    private static func shouldAppendToSearch(_ event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard !modifiers.contains(.command),
              !modifiers.contains(.option),
              !modifiers.contains(.control),
              let text = event.charactersIgnoringModifiers,
              text.count == 1
        else {
            return false
        }

        return text.unicodeScalars.allSatisfy { scalar in
            !CharacterSet.controlCharacters.contains(scalar)
                && !CharacterSet.newlines.contains(scalar)
        }
    }
}
