import Foundation
import XCTest

final class AccessibilityPermissionRegressionTests: XCTestCase {
    func testAutomaticPasteUsesNonPromptingAccessibilityCheck() throws {
        let source = try swiftSource("Sources/MacClipy/Clipboard/PasteController.swift")
        let pasteFunctionStart = try XCTUnwrap(
            source.range(of: "static func pasteIntoPreviousApplication")
        )
        let resolverStart = try XCTUnwrap(
            source.range(
                of: "static func resolvePasteAttempt",
                range: pasteFunctionStart.upperBound ..< source.endIndex
            )
        )
        let pasteFunction = source[pasteFunctionStart.lowerBound ..< resolverStart.lowerBound]

        XCTAssertTrue(
            pasteFunction.contains(
                "accessibilityTrusted: () -> Bool = { PasteController.isAccessibilityTrusted }"
            )
        )
        XCTAssertFalse(pasteFunction.contains("requestAccessibilityPermission"))
    }

    func testPromptingPermissionRequestIsOnlyWiredToOnboarding() throws {
        let pasteSource = try swiftSource("Sources/MacClipy/Clipboard/PasteController.swift")
        let trustCheckStart = try XCTUnwrap(
            pasteSource.range(of: "static var isAccessibilityTrusted")
        )
        let promptRequestStart = try XCTUnwrap(
            pasteSource.range(of: "static func requestAccessibilityPermission")
        )
        let trustCheck = pasteSource[trustCheckStart.lowerBound ..< promptRequestStart.lowerBound]

        XCTAssertTrue(trustCheck.contains("AXIsProcessTrusted()"))
        XCTAssertFalse(trustCheck.contains("AXIsProcessTrustedWithOptions"))

        let appModelSource = try swiftSource("Sources/MacClipy/App/AppModel.swift")
        XCTAssertTrue(
            appModelSource.contains(
                "requestAccessibilityPermission: { PasteController.requestAccessibilityPermission() }"
            )
        )
        XCTAssertEqual(
            try allProductionSwiftSource()
                .components(separatedBy: "PasteController.requestAccessibilityPermission()")
                .count - 1,
            1
        )
    }

    func testLocalBuildUsesDevelopmentBundleIdentifier() throws {
        let reapplyOutput = try makeDryRun(target: "reapply-local")
        let runOutput = try makeDryRun(target: "run")

        XCTAssertTrue(
            reapplyOutput.contains(
                "BUNDLE_ID=\"jp.techguide.macclipy.development\" "
                    + "BUNDLE_DISPLAY_NAME=\"MacClipy Development\" BUILD_CONFIG=\"release\""
            )
        )
        XCTAssertTrue(
            runOutput.contains(
                "BUNDLE_ID=\"jp.techguide.macclipy.development\" "
                    + "BUNDLE_DISPLAY_NAME=\"MacClipy Development\" BUILD_CONFIG=\"debug\""
            )
        )
    }

    func testLocalBuildUsesDistinctDevelopmentDisplayName() throws {
        let output = try makeDryRun(target: "reapply-local")

        XCTAssertTrue(output.contains("BUNDLE_DISPLAY_NAME=\"MacClipy Development\""))
    }

    func testLocalBuildIgnoresConflictingIdentifierOverrides() throws {
        let output = try makeDryRun(
            target: "reapply-local",
            arguments: [
                "BUNDLE_ID=jp.techguide.macclipy",
                "BUNDLE_DISPLAY_NAME=MacClipy",
                "DEVELOPMENT_BUNDLE_ID=com.example.overridden-development",
                "DISTRIBUTION_BUNDLE_ID=com.example.overridden-distribution"
            ]
        )

        XCTAssertTrue(
            output.contains(
                "BUNDLE_ID=\"jp.techguide.macclipy.development\" "
                    + "BUNDLE_DISPLAY_NAME=\"MacClipy Development\""
            )
        )
        XCTAssertTrue(
            output.contains(
                "BUNDLE_ID=\"jp.techguide.macclipy\" scripts/app-lifecycle.swift quit-and-wait"
            )
        )
        XCTAssertFalse(output.contains("com.example.overridden"))
    }

    func testReleasePackagingPinsProductionDisplayName() throws {
        let scriptURL = packageRoot().appendingPathComponent("scripts/package-release.sh")
        let source = try String(contentsOf: scriptURL, encoding: .utf8)

        XCTAssertTrue(source.contains("BUNDLE_DISPLAY_NAME=\"MacClipy\""))
        XCTAssertTrue(source.contains("BUNDLE_DISPLAY_NAME=\"$BUNDLE_DISPLAY_NAME\""))
    }

    func testLocalBuildStopsDistributionAndDevelopmentAppsBeforeLaunching() throws {
        let output = try makeDryRun(target: "reapply-local")

        XCTAssertTrue(
            output.contains(
                "BUNDLE_ID=\"jp.techguide.macclipy\" scripts/app-lifecycle.swift quit-and-wait"
            )
        )
        XCTAssertTrue(
            output.contains(
                "BUNDLE_ID=\"jp.techguide.macclipy.development\" "
                    + "scripts/app-lifecycle.swift quit-and-wait"
            )
        )
    }

    private func makeDryRun(target: String, arguments: [String] = []) throws -> String {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/make")
        process.arguments = ["--dry-run", target] + arguments
        process.currentDirectoryURL = packageRoot()
        process.standardOutput = output
        process.standardError = output

        try process.run()
        process.waitUntilExit()

        let data = output.fileHandleForReading.readDataToEndOfFile()
        let text = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertEqual(process.terminationStatus, 0, text)
        return text
    }

    private func allProductionSwiftSource() throws -> String {
        let sourceRoot = packageRoot().appendingPathComponent("Sources")
        return try FileManager.default
            .subpathsOfDirectory(atPath: sourceRoot.path)
            .filter { $0.hasSuffix(".swift") }
            .sorted()
            .map { path in
                try String(
                    contentsOf: sourceRoot.appendingPathComponent(path),
                    encoding: .utf8
                )
            }
            .joined(separator: "\n")
    }

    private func swiftSource(_ path: String) throws -> String {
        try String(contentsOf: packageRoot().appendingPathComponent(path), encoding: .utf8)
    }

    private func packageRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
