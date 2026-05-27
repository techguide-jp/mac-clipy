import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private weak var appModel: AppModel?
    private var window: NSWindow?

    init(appModel: AppModel) {
        self.appModel = appModel
    }

    func show() {
        guard let appModel else {
            return
        }

        if let window {
            centerWindow(window)
            bringForward(window)
            return
        }

        let settingsView = SettingsView(appModel: appModel)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 580),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = L10n.tr("settings.title")
        window.contentViewController = NSHostingController(rootView: settingsView)
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.moveToActiveSpace]
        window.delegate = self
        centerWindow(window)
        self.window = window
        bringForward(window)
    }

    func showKeyboardHelp() {
        show()
        appModel?.isKeyboardHelpPresented = true
    }

    func windowWillClose(_: Notification) {
        window = nil
    }

    private func bringForward(_ window: NSWindow) {
        NSApp.activate(ignoringOtherApps: true)
        centerWindow(window)
        window.makeKeyAndOrderFront(nil)
        centerWindow(window)
    }

    private func centerWindow(_ window: NSWindow) {
        guard let visibleFrame = targetScreen(for: window)?.visibleFrame else {
            return
        }

        let centeredFrame = Self.centeredFrame(for: window.frame.size, in: visibleFrame)
        if window.frame != centeredFrame {
            window.setFrame(centeredFrame, display: true)
        }
    }

    private func targetScreen(for window: NSWindow) -> NSScreen? {
        Self.screen(containing: NSEvent.mouseLocation)
            ?? window.screen
            ?? Self.screen(containing: window.frame.center)
            ?? NSScreen.main
            ?? NSScreen.screens.first
    }

    static func centeredFrame(for size: NSSize, in visibleFrame: NSRect) -> NSRect {
        let width = min(size.width, visibleFrame.width)
        let height = min(size.height, visibleFrame.height)
        let origin = NSPoint(
            x: visibleFrame.minX + ((visibleFrame.width - width) / 2),
            y: visibleFrame.minY + ((visibleFrame.height - height) / 2)
        )

        return NSRect(origin: origin, size: NSSize(width: width, height: height))
    }

    private static func screen(containing point: NSPoint) -> NSScreen? {
        NSScreen.screens.first { screen in
            screen.frame.contains(point)
        }
    }
}

private extension NSRect {
    var center: NSPoint {
        NSPoint(x: midX, y: midY)
    }
}
