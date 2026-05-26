import AppKit

@MainActor
final class AppDelegateBridge: NSObject, NSApplicationDelegate {
    let appModel = AppModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        appModel.applicationDidFinishLaunching()
    }

    func applicationWillTerminate(_ notification: Notification) {
        appModel.applicationWillTerminate()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        appModel.showHistoryPopup()
        return true
    }
}
