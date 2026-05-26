import AppKit

@MainActor
final class AppDelegateBridge: NSObject, NSApplicationDelegate {
    let appModel = AppModel()

    func applicationDidFinishLaunching(_: Notification) {
        appModel.applicationDidFinishLaunching()
    }

    func applicationWillTerminate(_: Notification) {
        appModel.applicationWillTerminate()
    }

    func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows _: Bool) -> Bool {
        appModel.showHistoryPopup()
        return true
    }
}
