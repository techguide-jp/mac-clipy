import AppKit

@main
enum MacClipyMain {
    @MainActor
    static func main() {
        let application = NSApplication.shared
        let appDelegate = AppDelegate()
        application.delegate = appDelegate
        withExtendedLifetime(appDelegate) {
            application.run()
        }
    }
}
