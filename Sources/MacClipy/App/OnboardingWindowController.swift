import AppKit
import SwiftUI

@MainActor
final class OnboardingWindowController: NSObject, NSWindowDelegate {
    private let isAccessibilityTrusted: () -> Bool
    private let requestAccessibilityPermission: () -> Bool
    private let onDismiss: () -> Void
    private var window: NSWindow?

    init(
        isAccessibilityTrusted: @escaping () -> Bool,
        requestAccessibilityPermission: @escaping () -> Bool,
        onDismiss: @escaping () -> Void
    ) {
        self.isAccessibilityTrusted = isAccessibilityTrusted
        self.requestAccessibilityPermission = requestAccessibilityPermission
        self.onDismiss = onDismiss
    }

    func show() {
        if let window {
            bringForward(window)
            return
        }

        let onboardingView = OnboardingView(
            isAccessibilityTrusted: isAccessibilityTrusted,
            requestAccessibilityPermission: requestAccessibilityPermission,
            onFinish: { [weak self] in
                self?.window?.performClose(nil)
            }
        )
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 470),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = L10n.tr("onboarding.windowTitle")
        window.contentViewController = NSHostingController(rootView: onboardingView)
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.moveToActiveSpace]
        window.delegate = self
        window.center()
        self.window = window
        bringForward(window)
    }

    func windowWillClose(_: Notification) {
        onDismiss()
        window = nil
    }

    private func bringForward(_ window: NSWindow) {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}
