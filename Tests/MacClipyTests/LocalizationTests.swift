import Foundation
import XCTest

final class LocalizationTests: XCTestCase {
    func testJapaneseAndEnglishKeysMatch() throws {
        let japanese = try loadTranslations(for: "ja")
        let english = try loadTranslations(for: "en")

        XCTAssertEqual(Set(japanese.keys), Set(english.keys))
    }

    func testTranslationsAreNotEmpty() throws {
        for localization in ["ja", "en"] {
            let translations = try loadTranslations(for: localization)

            for (key, value) in translations {
                let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
                XCTAssertFalse(trimmedValue.isEmpty, "\(localization):\(key)")
            }
        }
    }

    func testRepresentativeFormatStringsRender() throws {
        for localization in ["ja", "en"] {
            let translations = try loadTranslations(for: localization)

            let hotKeyTitle = try XCTUnwrap(translations["menu.hotKey"])
            let resultCount = try XCTUnwrap(translations["historyPanel.resultCount"])
            let saveFailed = try XCTUnwrap(translations["settings.status.saveFailed"])

            XCTAssertFalse(String(format: hotKeyTitle, "⇧⌘V").contains("%@"))
            XCTAssertFalse(String(format: resultCount, 3).contains("%d"))
            XCTAssertFalse(String(format: saveFailed, "disk full").contains("%@"))
        }
    }

    func testSourceLocalizationKeysExistInResourceFiles() throws {
        let japanese = try loadTranslations(for: "ja")
        let sourceKeys = try sourceLocalizationKeys()
        let missingKeys = sourceKeys.subtracting(japanese.keys).sorted()

        XCTAssertTrue(missingKeys.isEmpty, "Missing localization keys: \(missingKeys)")
    }

    private func loadTranslations(for localization: String) throws -> [String: String] {
        let url = packageRoot()
            .appendingPathComponent("Sources/MacClipy/Resources")
            .appendingPathComponent("\(localization).lproj")
            .appendingPathComponent("Localizable.strings")
        let data = try Data(contentsOf: url)
        var format = PropertyListSerialization.PropertyListFormat.openStep
        let object = try PropertyListSerialization.propertyList(from: data, options: [], format: &format)

        return try XCTUnwrap(object as? [String: String])
    }

    private func sourceLocalizationKeys() throws -> Set<String> {
        let sourceRoot = packageRoot().appendingPathComponent("Sources/MacClipy")
        let sourcePaths = try FileManager.default.subpathsOfDirectory(atPath: sourceRoot.path)
            .filter { $0.hasSuffix(".swift") }
        let regex = try NSRegularExpression(pattern: #"L10n\.tr\(\s*"([^"]+)""#)
        var keys = Set<String>()

        for sourcePath in sourcePaths {
            let sourceURL = sourceRoot.appendingPathComponent(sourcePath)
            let source = try String(contentsOf: sourceURL, encoding: .utf8)
            let matches = regex.matches(in: source, range: NSRange(source.startIndex..., in: source))

            for match in matches {
                guard let range = Range(match.range(at: 1), in: source) else {
                    continue
                }
                keys.insert(String(source[range]))
            }
        }

        return keys
    }

    private func packageRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
