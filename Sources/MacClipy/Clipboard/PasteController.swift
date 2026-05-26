import AppKit
import ApplicationServices

@MainActor
enum PasteController {
    static func pasteIntoPreviousApplication(_ application: NSRunningApplication?) -> Bool {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary

        guard AXIsProcessTrustedWithOptions(options) else {
            return false
        }

        guard let application else {
            return false
        }

        application.activate()

        DispatchQueue.main.asyncAfter(deadline: .now() + AppConstants.Paste.delayBeforeSendingCommandV) {
            sendCommandV()
        }

        return true
    }

    private static func sendCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyCodeForV = AppConstants.Paste.commandVKeyCode

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCodeForV, keyDown: true)
        keyDown?.flags = .maskCommand

        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCodeForV, keyDown: false)
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
