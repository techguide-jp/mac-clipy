import SwiftUI

@main
struct MacClipyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegateBridge.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(appModel: appDelegate.appModel)
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button(L10n.tr("menu.settings")) {
                    appDelegate.appModel.showSettings()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}
