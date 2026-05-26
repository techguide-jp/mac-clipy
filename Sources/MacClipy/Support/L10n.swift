import Foundation

public enum L10n {
    private static let tableName = "Localizable"
    private static let fallbackLocalization = "ja"

    public static func tr(_ key: String, _ arguments: CVarArg...) -> String {
        let format = localizedString(forKey: key)
        guard !arguments.isEmpty else {
            return format
        }

        return String(format: format, locale: Locale.current, arguments: arguments)
    }

    public static func localizedString(forKey key: String) -> String {
        let mainValue = Bundle.main.localizedString(forKey: key, value: nil, table: tableName)
        if mainValue != key {
            return mainValue
        }

        #if SWIFT_PACKAGE
        let moduleValue = Bundle.module.localizedString(forKey: key, value: nil, table: tableName)
        if moduleValue != key {
            return moduleValue
        }

        if let fallbackValue = localizedString(forKey: key, localization: fallbackLocalization, in: Bundle.module) {
            return fallbackValue
        }
        #endif

        if let fallbackValue = localizedString(forKey: key, localization: fallbackLocalization, in: Bundle.main) {
            return fallbackValue
        }

        return key
    }

    private static func localizedString(forKey key: String, localization: String, in bundle: Bundle) -> String? {
        guard let path = bundle.path(forResource: localization, ofType: "lproj"),
              let localizedBundle = Bundle(path: path) else {
            return nil
        }

        let value = localizedBundle.localizedString(forKey: key, value: nil, table: tableName)
        return value == key ? nil : value
    }
}
