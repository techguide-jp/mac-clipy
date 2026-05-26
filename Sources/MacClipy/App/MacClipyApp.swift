import SwiftUI

@main
struct MacClipyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegateBridge.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(appModel: appDelegate.appModel)
        }
    }
}
