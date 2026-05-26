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

    func testFormatSpecifiersMatchBetweenLanguages() throws {
        let japanese = try loadTranslations(for: "ja")
        let english = try loadTranslations(for: "en")

        for key in japanese.keys {
            let japaneseValue = try XCTUnwrap(japanese[key])
            let englishValue = try XCTUnwrap(english[key])

            XCTAssertEqual(
                formatSpecifiers(in: japaneseValue),
                formatSpecifiers(in: englishValue),
                key
            )
        }
    }

    func testSourceLocalizationKeysExistInResourceFiles() throws {
        let japanese = try loadTranslations(for: "ja")
        let sourceKeys = try sourceLocalizationKeys()
        let missingKeys = sourceKeys.subtracting(japanese.keys).sorted()

        XCTAssertTrue(missingKeys.isEmpty, "Missing localization keys: \(missingKeys)")
    }

    func testSwiftSourceDoesNotContainJapaneseStringLiterals() throws {
        let violations = try japaneseStringLiteralViolations()

        XCTAssertTrue(violations.isEmpty, "Move Japanese UI text to Localizable.strings: \(violations)")
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

    private func japaneseStringLiteralViolations() throws -> [String] {
        let roots = [
            packageRoot().appendingPathComponent("Sources/MacClipy"),
            packageRoot().appendingPathComponent("Tests/MacClipyTests")
        ]
        let regex = try NSRegularExpression(
            pattern: #""(?:\\.|[^"\\])*[\u3040-\u30ff\u3400-\u9fff](?:\\.|[^"\\])*""#
        )
        var violations: [String] = []

        for root in roots {
            let sourcePaths = try FileManager.default.subpathsOfDirectory(atPath: root.path)
                .filter { $0.hasSuffix(".swift") }

            for sourcePath in sourcePaths {
                let sourceURL = root.appendingPathComponent(sourcePath)
                let source = try String(contentsOf: sourceURL, encoding: .utf8)
                let matches = regex.matches(in: source, range: NSRange(source.startIndex..., in: source))

                for match in matches {
                    guard let range = Range(match.range, in: source) else {
                        continue
                    }

                    let line = lineNumber(for: range.lowerBound, in: source)
                    violations.append("\(sourceURL.path):\(line): \(source[range])")
                }
            }
        }

        return violations.sorted()
    }

    private func formatSpecifiers(in value: String) -> [Character] {
        let specifierCharacters = Set("@dDuUxXfFeEgGcCsS")
        var specifiers: [Character] = []
        var index = value.startIndex

        while index < value.endIndex {
            guard value[index] == "%" else {
                index = value.index(after: index)
                continue
            }

            let nextIndex = value.index(after: index)
            guard nextIndex < value.endIndex else {
                break
            }

            if value[nextIndex] == "%" {
                index = value.index(after: nextIndex)
                continue
            }

            var specifierIndex = nextIndex
            while specifierIndex < value.endIndex {
                let character = value[specifierIndex]
                if specifierCharacters.contains(character) {
                    specifiers.append(character)
                    index = value.index(after: specifierIndex)
                    break
                }
                specifierIndex = value.index(after: specifierIndex)
            }

            if specifierIndex == value.endIndex {
                break
            }
        }

        return specifiers
    }

    private func lineNumber(for targetIndex: String.Index, in source: String) -> Int {
        var line = 1
        var index = source.startIndex

        while index < targetIndex {
            if source[index].isNewline {
                line += 1
            }
            index = source.index(after: index)
        }

        return line
    }

    private func packageRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
