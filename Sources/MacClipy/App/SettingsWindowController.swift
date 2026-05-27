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
            keepWindowVisible(window)
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
        window.center()
        keepWindowVisible(window)
        self.window = window
        bringForward(window)
    }

    func windowWillClose(_: Notification) {
        window = nil
    }

    private func bringForward(_ window: NSWindow) {
        NSApp.activate(ignoringOtherApps: true)
        keepWindowVisible(window)
        window.makeKeyAndOrderFront(nil)
    }

    private func keepWindowVisible(_ window: NSWindow) {
        guard let visibleFrame = targetScreen(for: window)?.visibleFrame else {
            return
        }

        let fittedFrame = Self.frame(window.frame, fittingIn: visibleFrame)
        if window.frame != fittedFrame {
            window.setFrame(fittedFrame, display: true)
        }
    }

    private func targetScreen(for window: NSWindow) -> NSScreen? {
        window.screen
            ?? Self.screen(containing: window.frame.center)
            ?? Self.screen(containing: NSEvent.mouseLocation)
            ?? NSScreen.main
            ?? NSScreen.screens.first
    }

    static func frame(_ frame: NSRect, fittingIn visibleFrame: NSRect) -> NSRect {
        let width = min(frame.width, visibleFrame.width)
        let height = min(frame.height, visibleFrame.height)
        let maxX = visibleFrame.maxX - width
        let maxY = visibleFrame.maxY - height
        let origin = NSPoint(
            x: min(max(frame.minX, visibleFrame.minX), maxX),
            y: min(max(frame.minY, visibleFrame.minY), maxY)
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
