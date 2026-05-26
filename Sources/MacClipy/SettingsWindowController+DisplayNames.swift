import AppKit

extension SettingsWindowController {
    func displayName(for bundleIdentifier: String) -> String {
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier),
           let bundle = Bundle(url: appURL) {
            return appDisplayName(from: bundle, fallbackURL: appURL)
        }

        if bundleIdentifier.caseInsensitiveCompare(Bundle.main.bundleIdentifier ?? "") == .orderedSame {
            return "MacClipy"
        }

        if let localizationKey = Self.knownAppNameKeys[bundleIdentifier.lowercased()] {
            return L10n.tr(localizationKey)
        }

        return bundleIdentifier
    }

    func appDisplayName(from bundle: Bundle, fallbackURL: URL) -> String {
        if let displayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String,
           !displayName.isEmpty {
            return displayName
        }

        if let bundleName = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String,
           !bundleName.isEmpty {
            return bundleName
        }

        return fallbackURL.deletingPathExtension().lastPathComponent
    }

    static let knownAppNameKeys = [
        "com.1password.1password": "appName.1password",
        "com.agilebits.onepassword7": "appName.1password7",
        "com.bitwarden.desktop": "appName.bitwarden",
        "org.keepassxc.keepassxc": "appName.keepassxc",
        "com.apple.keychainaccess": "appName.keychainAccess",
        "com.local.macclipy": "appName.macclipy"
    ]
}
