import AppKit
import SwiftUI

@MainActor
final class MonthlyMessageWindowController: NSObject, NSWindowDelegate {
    private let center: MonthlyMessageCenter
    private var window: NSPanel?

    init(center: MonthlyMessageCenter) {
        self.center = center
    }

    func show(automatically: Bool) {
        if let window {
            if !automatically { window.makeKeyAndOrderFront(nil) }
            return
        }
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 350),
            styleMask: [.titled, .closable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.title = L10n.tr("monthly.windowTitle")
        window.contentViewController = NSHostingController(rootView: MonthlyMessageView(center: center) { [weak self] in
            self?.window?.performClose(nil)
        })
        window.isReleasedWhenClosed = false
        window.hidesOnDeactivate = false
        window.collectionBehavior = [.moveToActiveSpace]
        window.delegate = self
        window.center()
        self.window = window
        if automatically {
            // 自動案内で入力中のアプリや貼り付け先のフォーカスを奪わない。
            window.orderFrontRegardless()
        } else {
            window.makeKeyAndOrderFront(nil)
        }
    }

    func windowWillClose(_: Notification) {
        window = nil
    }
}
