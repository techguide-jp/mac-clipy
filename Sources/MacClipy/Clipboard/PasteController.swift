import AppKit
import ApplicationServices

@MainActor
enum PasteController {
    static let previousApplicationActivationOptions: NSApplication.ActivationOptions = [
        .activateAllWindows
    ]

    static func pasteIntoPreviousApplication(_ application: NSRunningApplication?) -> Bool {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary

        guard AXIsProcessTrustedWithOptions(options) else {
            return false
        }

        guard let application else {
            return false
        }

        // MacClipy owns focus while the popup is open; yield it back before posting Command+V.
        NSApp.yieldActivation(to: application)
        guard application.activate(from: .current, options: previousApplicationActivationOptions) else {
            return false
        }

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
