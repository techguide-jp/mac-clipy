import Foundation
import Observation
import Sparkle

@MainActor
@Observable
final class AppUpdater: NSObject {
    @ObservationIgnored private let updaterController: SPUStandardUpdaterController
    private var settingsRevision = 0

    override init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        super.init()
    }

    var canCheckForUpdates: Bool {
        _ = settingsRevision
        return updaterController.updater.canCheckForUpdates
    }

    var automaticallyChecksForUpdates: Bool {
        get {
            _ = settingsRevision
            return updaterController.updater.automaticallyChecksForUpdates
        }
        set {
            updaterController.updater.automaticallyChecksForUpdates = newValue
            settingsRevision &+= 1
        }
    }

    var allowsAutomaticUpdates: Bool {
        _ = settingsRevision
        return updaterController.updater.allowsAutomaticUpdates
    }

    var automaticallyDownloadsUpdates: Bool {
        get {
            _ = settingsRevision
            return updaterController.updater.automaticallyDownloadsUpdates
        }
        set {
            updaterController.updater.automaticallyDownloadsUpdates = newValue
            settingsRevision &+= 1
        }
    }

    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }
}
