import AppKit
import Defaults
import Foundation
import Observation

public enum SettingsDefaults {
    public static let currentBundleIdentifier = "jp.techguide.macclipy"
    private static let legacyLocalBundleIdentifier = "com.local.MacClipy"

    public static let defaultExcludedBundleIdentifiers = [
        "com.1password.1password",
        "com.agilebits.onepassword7",
        "com.bitwarden.desktop",
        "org.keepassxc.keepassxc",
        "com.apple.keychainaccess",
        currentBundleIdentifier
    ]

    public static func normalizedBundleIdentifiers(_ identifiers: [String]) -> [String] {
        var seen = Set<String>()
        var normalized: [String] = []

        for identifier in identifiers {
            let trimmed = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                continue
            }

            let canonicalIdentifier = canonicalBundleIdentifier(trimmed)
            let key = canonicalIdentifier.lowercased()
            guard !seen.contains(key) else {
                continue
            }

            seen.insert(key)
            normalized.append(canonicalIdentifier)
        }

        return normalized
    }

    public static func isExcluded(bundleIdentifier: String?, in identifiers: [String]) -> Bool {
        guard let bundleIdentifier else {
            return false
        }

        return identifiers.contains {
            $0.caseInsensitiveCompare(bundleIdentifier) == .orderedSame
        }
    }

    public static func displayName(for bundleIdentifier: String) -> String {
        switch bundleIdentifier {
        case "com.1password.1password":
            L10n.tr("appName.1password")
        case "com.agilebits.onepassword7":
            L10n.tr("appName.1password7")
        case "com.bitwarden.desktop":
            L10n.tr("appName.bitwarden")
        case "org.keepassxc.keepassxc":
            L10n.tr("appName.keepassxc")
        case "com.apple.keychainaccess":
            L10n.tr("appName.keychainAccess")
        case currentBundleIdentifier:
            L10n.tr("appName.macclipy")
        default:
            bundleIdentifier
        }
    }

    private static func canonicalBundleIdentifier(_ identifier: String) -> String {
        if identifier.caseInsensitiveCompare(legacyLocalBundleIdentifier) == .orderedSame {
            return currentBundleIdentifier
        }

        return identifier
    }
}

extension Defaults.Keys {
    static let excludedBundleIdentifiers = Key<[String]>(
        "excludedBundleIdentifiers",
        default: SettingsDefaults.defaultExcludedBundleIdentifiers
    )

    static let didMigrateLegacySettings = Key<Bool>("didMigrateLegacySettings", default: false)
    static let didMigrateBundleID = Key<Bool>(
        "didMigrateBundleID",
        default: false
    )
}

@MainActor
@Observable
final class SettingsModel {
    var excludedBundleIdentifiers: [String]
    var statusMessage = ""

    init() {
        excludedBundleIdentifiers = SettingsDefaults.normalizedBundleIdentifiers(
            Defaults[.excludedBundleIdentifiers]
        )
    }

    func reload() {
        excludedBundleIdentifiers = SettingsDefaults.normalizedBundleIdentifiers(
            Defaults[.excludedBundleIdentifiers]
        )
    }

    func setExcludedBundleIdentifiers(_ identifiers: [String]) {
        let normalized = SettingsDefaults.normalizedBundleIdentifiers(identifiers)
        excludedBundleIdentifiers = normalized
        Defaults[.excludedBundleIdentifiers] = normalized
    }

    func resetExcludedApps() {
        setExcludedBundleIdentifiers(SettingsDefaults.defaultExcludedBundleIdentifiers)
        statusMessage = L10n.tr("settings.status.excludedAppsReset")
    }

    func removeExcludedApp(_ bundleIdentifier: String) {
        setExcludedBundleIdentifiers(
            excludedBundleIdentifiers.filter {
                $0.caseInsensitiveCompare(bundleIdentifier) != .orderedSame
            }
        )
        statusMessage = L10n.tr("settings.status.appCapturedAgain", SettingsDefaults.displayName(for: bundleIdentifier))
    }

    func addExcludedApp(from url: URL) {
        guard let bundle = Bundle(url: url),
              let bundleIdentifier = bundle.bundleIdentifier
        else {
            statusMessage = L10n.tr("settings.status.appReadFailed")
            return
        }

        guard !SettingsDefaults.isExcluded(bundleIdentifier: bundleIdentifier, in: excludedBundleIdentifiers) else {
            statusMessage = L10n.tr(
                "settings.status.appAlreadyAdded",
                SettingsDefaults.displayName(for: bundleIdentifier)
            )
            return
        }

        setExcludedBundleIdentifiers(excludedBundleIdentifiers + [bundleIdentifier])
        statusMessage = L10n.tr("settings.status.appExcluded", SettingsDefaults.displayName(for: bundleIdentifier))
    }

    func chooseExcludedApp() {
        let panel = NSOpenPanel()
        panel.title = L10n.tr("settings.openPanel.title")
        panel.prompt = L10n.tr("settings.openPanel.prompt")
        panel.message = L10n.tr("settings.openPanel.message")
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        panel.allowedContentTypes = [.applicationBundle]

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        addExcludedApp(from: url)
    }
}
