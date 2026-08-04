import AppKit

@MainActor
final class AppDelegateBridge: NSObject, NSApplicationDelegate {
    let appModel = AppModel()

    func applicationDidFinishLaunching(_: Notification) {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(workspaceDidActivateApplication(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(applicationDidConfirmRunning(_:)),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidConfirmRunning(_:)),
            name: .NSCalendarDayChanged,
            object: nil
        )
        appModel.applicationDidFinishLaunching()
    }

    func applicationWillTerminate(_: Notification) {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        appModel.applicationWillTerminate()
    }

    func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows _: Bool) -> Bool {
        appModel.showHistoryPopup()
        return true
    }

    @objc private func workspaceDidActivateApplication(_ notification: Notification) {
        guard let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }

        appModel.applicationDidActivate(application)
    }

    @objc private func applicationDidConfirmRunning(_: Notification) {
        Task { [weak self] in
            await self?.appModel.applicationDidConfirmRunning()
        }
    }
}
