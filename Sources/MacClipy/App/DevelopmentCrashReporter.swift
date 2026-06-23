import Foundation

struct DevelopmentCrashReport: Identifiable, Equatable {
    let id = UUID()
    let previousLaunchDate: Date
    let detectedAt: Date
    let diagnosticReportURL: URL?
    let diagnosticReportText: String
    let logURL: URL?
    let logText: String
    let isLogTruncated: Bool
}

struct DevelopmentCrashReporter {
    struct LaunchState: Codable {
        var launchID: UUID
        var launchDate: Date
        var terminatedCleanly: Bool
        var appVersion: String?
        var buildNumber: String?
        var bundleIdentifier: String?
        var bundlePath: String?
        var executablePath: String?
        var processID: Int32?

        init(
            launchID: UUID,
            launchDate: Date,
            terminatedCleanly: Bool,
            appVersion: String? = nil,
            buildNumber: String? = nil,
            bundleIdentifier: String? = nil,
            bundlePath: String? = nil,
            executablePath: String? = nil,
            processID: Int32? = nil
        ) {
            self.launchID = launchID
            self.launchDate = launchDate
            self.terminatedCleanly = terminatedCleanly
            self.appVersion = appVersion
            self.buildNumber = buildNumber
            self.bundleIdentifier = bundleIdentifier
            self.bundlePath = bundlePath
            self.executablePath = executablePath
            self.processID = processID
        }
    }

    private static let enabledInfoKey = "MacClipyDevelopmentCrashModalEnabled"

    private let isModalEnabled: Bool
    private let isFileOutputEnabled: Bool
    private let stateURL: URL
    private let diagnosticsDirectoryURL: URL
    private let reportDirectoryURL: URL
    private let fileManager: FileManager
    private let appName: String
    private let maximumLogCharacters: Int
    private let now: () -> Date

    init(
        isEnabled: Bool = Self.isEnabledInMainBundle,
        isFileOutputEnabled: Bool = true,
        stateURL: URL = AppPaths.developmentCrashStateURL,
        diagnosticsDirectoryURL: URL = Self.defaultDiagnosticsDirectoryURL,
        reportDirectoryURL: URL? = nil,
        fileManager: FileManager = .default,
        appName: String = AppPaths.applicationName,
        maximumLogCharacters: Int = 60000,
        now: @escaping () -> Date = Date.init
    ) {
        isModalEnabled = isEnabled
        self.isFileOutputEnabled = isFileOutputEnabled
        self.stateURL = stateURL
        self.diagnosticsDirectoryURL = diagnosticsDirectoryURL
        self.reportDirectoryURL = reportDirectoryURL ?? Self.defaultReportDirectoryURL(for: stateURL)
        self.fileManager = fileManager
        self.appName = appName
        self.maximumLogCharacters = maximumLogCharacters
        self.now = now
    }

    func startLaunch() -> DevelopmentCrashReport? {
        guard isTrackingEnabled else {
            return nil
        }

        let previousState = loadState()
        let currentState = makeCurrentLaunchState()
        saveState(currentState)

        guard let previousState, !previousState.terminatedCleanly else {
            return nil
        }

        let report = makeReport(for: previousState, currentState: currentState)
        guard isModalEnabled else {
            return nil
        }

        return report
    }

    func markCleanTermination() {
        guard isTrackingEnabled, var state = loadState() else {
            return
        }

        state.terminatedCleanly = true
        saveState(state)
    }

    static var isEnabledInMainBundle: Bool {
        Bundle.main.object(forInfoDictionaryKey: enabledInfoKey) as? Bool == true
    }

    static var defaultDiagnosticsDirectoryURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/DiagnosticReports", isDirectory: true)
    }

    private static func defaultReportDirectoryURL(for stateURL: URL) -> URL {
        stateURL.deletingLastPathComponent()
            .appendingPathComponent("CrashReports", isDirectory: true)
    }

    private var isTrackingEnabled: Bool {
        isModalEnabled || isFileOutputEnabled
    }

    private func makeReport(for state: LaunchState, currentState: LaunchState) -> DevelopmentCrashReport {
        let detectedAt = now()
        let logURL = latestCrashLogURL(after: state.launchDate)
        let logContent = logURL.flatMap(readLog)
        let diagnosticText = makeDiagnosticText(
            previousState: state,
            currentState: currentState,
            detectedAt: detectedAt,
            logURL: logURL,
            logContent: logContent
        )
        let diagnosticReportURL = writeDiagnosticReport(
            diagnosticText,
            detectedAt: detectedAt,
            previousLaunchID: state.launchID
        )

        return DevelopmentCrashReport(
            previousLaunchDate: state.launchDate,
            detectedAt: detectedAt,
            diagnosticReportURL: diagnosticReportURL,
            diagnosticReportText: diagnosticText,
            logURL: logURL,
            logText: logContent?.text ?? "",
            isLogTruncated: logContent?.isTruncated == true
        )
    }

    private func latestCrashLogURL(after date: Date) -> URL? {
        guard let urls = try? fileManager.contentsOfDirectory(
            at: diagnosticsDirectoryURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        return urls
            .filter(isCrashLogURL)
            .compactMap { url -> (url: URL, modifiedAt: Date)? in
                guard let modifiedAt = try? url.resourceValues(forKeys: [.contentModificationDateKey])
                    .contentModificationDate,
                    modifiedAt >= date.addingTimeInterval(-5)
                else {
                    return nil
                }

                return (url, modifiedAt)
            }
            .max { lhs, rhs in lhs.modifiedAt < rhs.modifiedAt }?
            .url
    }

    private func isCrashLogURL(_ url: URL) -> Bool {
        let fileName = url.lastPathComponent
        let isMacClipyLog = fileName.hasPrefix("\(appName)_") || fileName.hasPrefix("\(appName)-")
        let isCrashExtension = url.pathExtension == "crash" || url.pathExtension == "ips"

        return isMacClipyLog && isCrashExtension
    }

    private func readLog(from url: URL) -> (text: String, isTruncated: Bool)? {
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }

        guard let text = String(data: data, encoding: .utf8) else {
            return nil
        }

        let isTruncated = text.count > maximumLogCharacters
        let clippedText = String(text.prefix(maximumLogCharacters))

        return (clippedText, isTruncated)
    }

    private func makeDiagnosticText(
        previousState: LaunchState,
        currentState: LaunchState,
        detectedAt: Date,
        logURL: URL?,
        logContent: (text: String, isTruncated: Bool)?
    ) -> String {
        var lines: [String] = [
            "MacClipy Unclean Termination Report",
            "",
            "Detected At: \(formatDate(detectedAt))",
            ""
        ]

        appendLaunchState(previousState, title: "Previous Launch", to: &lines)
        lines.append("")
        appendLaunchState(currentState, title: "Current Launch", to: &lines)
        lines.append("")

        if let logURL {
            lines.append("macOS Crash Log: \(logURL.path)")
            lines.append("macOS Crash Log Truncated: \(logContent?.isTruncated == true ? "true" : "false")")
        } else {
            lines.append("macOS Crash Log: Not found")
        }

        lines.append("")
        lines.append("macOS Crash Log Excerpt:")
        lines.append(logContent?.text.isEmpty == false ? logContent?.text ?? "" : "No macOS crash log was found.")

        return lines.joined(separator: "\n")
    }

    private func appendLaunchState(_ state: LaunchState, title: String, to lines: inout [String]) {
        lines.append("\(title):")
        lines.append("  Launch ID: \(state.launchID.uuidString)")
        lines.append("  Started At: \(formatDate(state.launchDate))")
        lines.append("  Terminated Cleanly: \(state.terminatedCleanly ? "true" : "false")")
        appendOptionalField("  Process ID", value: state.processID.map(String.init), to: &lines)
        appendOptionalField("  Bundle ID", value: state.bundleIdentifier, to: &lines)
        appendOptionalField("  App Version", value: state.appVersion, to: &lines)
        appendOptionalField("  Build Number", value: state.buildNumber, to: &lines)
        appendOptionalField("  Bundle Path", value: state.bundlePath, to: &lines)
        appendOptionalField("  Executable Path", value: state.executablePath, to: &lines)
    }

    private func appendOptionalField(_ name: String, value: String?, to lines: inout [String]) {
        guard let value, !value.isEmpty else {
            return
        }

        lines.append("\(name): \(value)")
    }

    private func writeDiagnosticReport(_ text: String, detectedAt: Date, previousLaunchID: UUID) -> URL? {
        guard isFileOutputEnabled else {
            return nil
        }

        do {
            try fileManager.createDirectory(at: reportDirectoryURL, withIntermediateDirectories: true)
            let fileName = "\(appName)-unclean-\(Int(detectedAt.timeIntervalSince1970))-\(previousLaunchID.uuidString).txt"
            let reportURL = reportDirectoryURL.appendingPathComponent(fileName)
            try text.write(to: reportURL, atomically: true, encoding: .utf8)
            return reportURL
        } catch {
            NSLog("MacClipy failed to write diagnostic report: \(error.localizedDescription)")
            return nil
        }
    }

    private func loadState() -> LaunchState? {
        guard let data = try? Data(contentsOf: stateURL) else {
            return nil
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return try? decoder.decode(LaunchState.self, from: data)
    }

    private func saveState(_ state: LaunchState) {
        do {
            try AppPaths.ensureParentDirectory(for: stateURL)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(state)
            try data.write(to: stateURL, options: [.atomic])
        } catch {
            return
        }
    }

    private func makeCurrentLaunchState() -> LaunchState {
        LaunchState(
            launchID: UUID(),
            launchDate: now(),
            terminatedCleanly: false,
            appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
            buildNumber: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String,
            bundleIdentifier: Bundle.main.bundleIdentifier,
            bundlePath: Bundle.main.bundleURL.path,
            executablePath: Bundle.main.executableURL?.path,
            processID: ProcessInfo.processInfo.processIdentifier
        )
    }

    private func formatDate(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }
}
