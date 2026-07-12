import AppKit
import ApplicationServices

@MainActor
enum PasteController {
    enum PasteResult: Equatable {
        case scheduled
        case permissionRequired
        case destinationUnavailable
        case activationFailed
    }

    static let previousApplicationActivationOptions: NSApplication.ActivationOptions = [
        .activateAllWindows
    ]

    static var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

    @discardableResult
    static func requestAccessibilityPermission() -> Bool {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static func pasteIntoPreviousApplication(
        _ application: NSRunningApplication?,
        requestPermission: () -> Bool = { requestAccessibilityPermission() },
        activate: (NSRunningApplication) -> Bool = { application in
            NSApp.yieldActivation(to: application)
            return application.activate(from: .current, options: previousApplicationActivationOptions)
        }
    ) -> PasteResult {
        let result = resolvePasteAttempt(
            destinationAvailable: application?.isTerminated == false,
            requestPermission: requestPermission,
            activate: {
                guard let application else {
                    return false
                }
                return activate(application)
            }
        )
        guard result == .scheduled else {
            return result
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + AppConstants.Paste.delayBeforeSendingCommandV) {
            sendCommandV()
        }

        return .scheduled
    }

    static func resolvePasteAttempt(
        destinationAvailable: Bool,
        requestPermission: () -> Bool,
        activate: () -> Bool
    ) -> PasteResult {
        guard destinationAvailable else {
            return .destinationUnavailable
        }
        guard requestPermission() else {
            return .permissionRequired
        }
        guard activate() else {
            return .activationFailed
        }
        return .scheduled
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
