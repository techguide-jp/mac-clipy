import AppKit
import SwiftUI

@MainActor
final class FloatingPanelController: NSObject, NSWindowDelegate {
    private let panel: PopupPanel
    private let model: HistoryPopupModel

    init(model: HistoryPopupModel) {
        self.model = model
        self.panel = PopupPanel(
            contentRect: NSRect(origin: .zero, size: NSSize(width: 520, height: 460)),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        super.init()

        panel.delegate = self
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .transient]
        panel.hasShadow = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.contentView = NSHostingView(rootView: HistoryPopupView(model: model))

        model.onClose = { [weak self] in
            self?.panel.orderOut(nil)
        }
    }

    func show(at screenPoint: NSPoint, initialMode: HistoryPopupInitialMode) {
        model.prepare(initialMode: initialMode)
        NSApp.activate(ignoringOtherApps: true)
        panel.setFrameOrigin(origin(for: screenPoint, windowSize: panel.frame.size))
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
    }

    func refresh() {
        model.refresh()
    }

    func windowDidResignKey(_ notification: Notification) {
        guard !model.isShowingFavoriteNamePrompt else {
            return
        }

        panel.orderOut(nil)
    }

    private func origin(for screenPoint: NSPoint, windowSize: NSSize) -> NSPoint {
        let screen = NSScreen.screens.first { $0.visibleFrame.contains(screenPoint) } ?? NSScreen.main
        guard let visibleFrame = screen?.visibleFrame else {
            return screenPoint
        }

        var origin = NSPoint(x: screenPoint.x, y: screenPoint.y - windowSize.height)
        if origin.x + windowSize.width > visibleFrame.maxX {
            origin.x = visibleFrame.maxX - windowSize.width
        }
        if origin.x < visibleFrame.minX {
            origin.x = visibleFrame.minX
        }
        if origin.y < visibleFrame.minY {
            origin.y = min(screenPoint.y, visibleFrame.maxY - windowSize.height)
        }
        if origin.y + windowSize.height > visibleFrame.maxY {
            origin.y = visibleFrame.maxY - windowSize.height
        }

        return origin
    }
}

final class PopupPanel: NSPanel {
    override var canBecomeKey: Bool {
        true
    }

    override func cancelOperation(_ sender: Any?) {
        orderOut(nil)
    }
}
