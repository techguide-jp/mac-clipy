import Foundation
import Sparkle

@MainActor
final class AutomaticUpdateInstaller: NSObject, SPUUpdaterDelegate {
    func installImmediately(using installationHandler: () -> Void) -> Bool {
        installationHandler()
        return true
    }

    func updater(
        _: SPUUpdater,
        willInstallUpdateOnQuit _: SUAppcastItem,
        immediateInstallationBlock immediateInstallHandler: @escaping () -> Void
    ) -> Bool {
        installImmediately(using: immediateInstallHandler)
    }
}
