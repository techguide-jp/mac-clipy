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
    static func requestAccessibilityPermission(
        prompt: () -> Bool = {
            let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
            return AXIsProcessTrustedWithOptions(options)
        },
        openSettings: (URL) -> Bool = { NSWorkspace.shared.open($0) }
    ) -> Bool {
        // 通常の履歴選択では呼ばず、ユーザーが権限設定を開くと明示した時だけ要求する。
        let isTrusted = prompt()
        if !isTrusted,
           let settingsURL = URL(
               string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
           ) {
            _ = openSettings(settingsURL)
        }
        return isTrusted
    }

    static func pasteIntoPreviousApplication(
        _ application: NSRunningApplication?,
        // 履歴選択のたびに設定画面を再表示しないため、通常貼り付けは非プロンプト確認だけを行う。
        accessibilityTrusted: () -> Bool = { PasteController.isAccessibilityTrusted },
        activate: (NSRunningApplication) -> Bool = { application in
            NSApp.yieldActivation(to: application)
            return application.activate(from: .current, options: previousApplicationActivationOptions)
        }
    ) -> PasteResult {
        let result = resolvePasteAttempt(
            destinationAvailable: application?.isTerminated == false,
            accessibilityTrusted: accessibilityTrusted,
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
        accessibilityTrusted: () -> Bool,
        activate: () -> Bool
    ) -> PasteResult {
        guard destinationAvailable else {
            return .destinationUnavailable
        }
        guard accessibilityTrusted() else {
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
