import Foundation
@testable import MacClipy
import XCTest

final class DevelopmentCrashReporterTests: XCTestCase {
    func testDisabledReporterDoesNotCreateState() throws {
        let rootURL = try temporaryDirectory()
        let stateURL = rootURL.appendingPathComponent("state.json")
        let diagnosticsURL = rootURL.appendingPathComponent("DiagnosticReports", isDirectory: true)
        let reporter = DevelopmentCrashReporter(
            isEnabled: false,
            isFileOutputEnabled: false,
            stateURL: stateURL,
            diagnosticsDirectoryURL: diagnosticsURL
        )

        XCTAssertNil(reporter.startLaunch())
        XCTAssertFalse(FileManager.default.fileExists(atPath: stateURL.path))
    }

    func testFileReporterCreatesStateWhenModalIsDisabled() throws {
        let rootURL = try temporaryDirectory()
        let stateURL = rootURL.appendingPathComponent("state.json")
        let diagnosticsURL = rootURL.appendingPathComponent("DiagnosticReports", isDirectory: true)
        let reporter = DevelopmentCrashReporter(
            isEnabled: false,
            stateURL: stateURL,
            diagnosticsDirectoryURL: diagnosticsURL
        )

        XCTAssertNil(reporter.startLaunch())
        XCTAssertTrue(FileManager.default.fileExists(atPath: stateURL.path))
    }

    func testPreviousUncleanLaunchReportsLatestCrashLog() throws {
        let rootURL = try temporaryDirectory()
        let stateURL = rootURL.appendingPathComponent("state.json")
        let diagnosticsURL = rootURL.appendingPathComponent("DiagnosticReports", isDirectory: true)
        try FileManager.default.createDirectory(at: diagnosticsURL, withIntermediateDirectories: true)

        let previousLaunchDate = Date(timeIntervalSince1970: 1000)
        try writeState(
            to: stateURL,
            launchDate: previousLaunchDate,
            terminatedCleanly: false
        )

        let staleURL = diagnosticsURL.appendingPathComponent("MacClipy_stale.crash")
        try writeLog("stale log", to: staleURL, modifiedAt: previousLaunchDate.addingTimeInterval(-60))

        let latestURL = diagnosticsURL.appendingPathComponent("MacClipy_latest.crash")
        try writeLog("latest log", to: latestURL, modifiedAt: previousLaunchDate.addingTimeInterval(20))

        let unrelatedURL = diagnosticsURL.appendingPathComponent("Other_latest.crash")
        try writeLog("other log", to: unrelatedURL, modifiedAt: previousLaunchDate.addingTimeInterval(40))

        let reporter = DevelopmentCrashReporter(
            isEnabled: true,
            stateURL: stateURL,
            diagnosticsDirectoryURL: diagnosticsURL,
            now: { Date(timeIntervalSince1970: 2000) }
        )
        let report = try XCTUnwrap(reporter.startLaunch())

        XCTAssertEqual(report.previousLaunchDate, previousLaunchDate)
        XCTAssertEqual(report.logURL?.resolvingSymlinksInPath(), latestURL.resolvingSymlinksInPath())
        XCTAssertEqual(report.logText, "latest log")
        XCTAssertFalse(report.isLogTruncated)
        XCTAssertTrue(report.diagnosticReportText.contains("MacClipy Unclean Termination Report"))
        XCTAssertTrue(report.diagnosticReportText.contains(latestURL.lastPathComponent))
        XCTAssertEqual(
            report.diagnosticReportURL?.deletingLastPathComponent().resolvingSymlinksInPath(),
            rootURL.appendingPathComponent("CrashReports", isDirectory: true).resolvingSymlinksInPath()
        )
        XCTAssertEqual(try report.diagnosticReportURL.map { try String(contentsOf: $0, encoding: .utf8) }, report.diagnosticReportText)
    }

    func testPreviousUncleanLaunchWritesDiagnosticReportWhenModalIsDisabled() throws {
        let rootURL = try temporaryDirectory()
        let stateURL = rootURL.appendingPathComponent("state.json")
        let diagnosticsURL = rootURL.appendingPathComponent("DiagnosticReports", isDirectory: true)
        let previousLaunchDate = Date(timeIntervalSince1970: 1000)
        try writeState(
            to: stateURL,
            launchDate: previousLaunchDate,
            terminatedCleanly: false
        )

        let reporter = DevelopmentCrashReporter(
            isEnabled: false,
            stateURL: stateURL,
            diagnosticsDirectoryURL: diagnosticsURL,
            now: { Date(timeIntervalSince1970: 2000) }
        )

        XCTAssertNil(reporter.startLaunch())

        let reportDirectoryURL = rootURL.appendingPathComponent("CrashReports", isDirectory: true)
        let reportURLs = try FileManager.default.contentsOfDirectory(
            at: reportDirectoryURL,
            includingPropertiesForKeys: nil
        )
        XCTAssertEqual(reportURLs.count, 1)

        let reportText = try String(contentsOf: reportURLs[0], encoding: .utf8)
        XCTAssertTrue(reportText.contains("MacClipy Unclean Termination Report"))
        XCTAssertTrue(reportText.contains("Previous Launch:"))
        XCTAssertTrue(reportText.contains("Started At: 1970-01-01T00:16:40Z"))
        XCTAssertTrue(reportText.contains("macOS Crash Log: Not found"))
    }

    func testPreviousUncleanLaunchReportsMissingLog() throws {
        let rootURL = try temporaryDirectory()
        let stateURL = rootURL.appendingPathComponent("state.json")
        let diagnosticsURL = rootURL.appendingPathComponent("DiagnosticReports", isDirectory: true)
        let previousLaunchDate = Date(timeIntervalSince1970: 1000)
        try writeState(
            to: stateURL,
            launchDate: previousLaunchDate,
            terminatedCleanly: false
        )

        let reporter = DevelopmentCrashReporter(
            isEnabled: true,
            stateURL: stateURL,
            diagnosticsDirectoryURL: diagnosticsURL
        )
        let report = try XCTUnwrap(reporter.startLaunch())

        XCTAssertEqual(report.previousLaunchDate, previousLaunchDate)
        XCTAssertNil(report.logURL)
        XCTAssertEqual(report.logText, "")
    }

    func testCleanTerminationSuppressesNextReport() throws {
        let rootURL = try temporaryDirectory()
        let stateURL = rootURL.appendingPathComponent("state.json")
        let diagnosticsURL = rootURL.appendingPathComponent("DiagnosticReports", isDirectory: true)
        let reporter = DevelopmentCrashReporter(
            isEnabled: true,
            stateURL: stateURL,
            diagnosticsDirectoryURL: diagnosticsURL
        )

        XCTAssertNil(reporter.startLaunch())
        reporter.markCleanTermination()

        let nextReporter = DevelopmentCrashReporter(
            isEnabled: true,
            stateURL: stateURL,
            diagnosticsDirectoryURL: diagnosticsURL
        )
        XCTAssertNil(nextReporter.startLaunch())
    }

    func testCrashLogTextIsTruncated() throws {
        let rootURL = try temporaryDirectory()
        let stateURL = rootURL.appendingPathComponent("state.json")
        let diagnosticsURL = rootURL.appendingPathComponent("DiagnosticReports", isDirectory: true)
        try FileManager.default.createDirectory(at: diagnosticsURL, withIntermediateDirectories: true)

        let previousLaunchDate = Date(timeIntervalSince1970: 1000)
        try writeState(
            to: stateURL,
            launchDate: previousLaunchDate,
            terminatedCleanly: false
        )

        let logURL = diagnosticsURL.appendingPathComponent("MacClipy_latest.ips")
        try writeLog("abcdef", to: logURL, modifiedAt: previousLaunchDate.addingTimeInterval(20))

        let reporter = DevelopmentCrashReporter(
            isEnabled: true,
            stateURL: stateURL,
            diagnosticsDirectoryURL: diagnosticsURL,
            maximumLogCharacters: 3
        )
        let report = try XCTUnwrap(reporter.startLaunch())

        XCTAssertEqual(report.logURL?.resolvingSymlinksInPath(), logURL.resolvingSymlinksInPath())
        XCTAssertEqual(report.logText, "abc")
        XCTAssertTrue(report.isLogTruncated)
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
        }
        return url
    }

    private func writeState(
        to url: URL,
        launchDate: Date,
        terminatedCleanly: Bool
    ) throws {
        let state = DevelopmentCrashReporter.LaunchState(
            launchID: UUID(),
            launchDate: launchDate,
            terminatedCleanly: terminatedCleanly
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(state)
        try AppPaths.ensureParentDirectory(for: url)
        try data.write(to: url)
    }

    private func writeLog(_ text: String, to url: URL, modifiedAt: Date) throws {
        try text.write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.modificationDate: modifiedAt],
            ofItemAtPath: url.path
        )
    }
}
