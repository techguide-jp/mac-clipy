import Foundation

struct DevelopmentCrashReport: Identifiable, Equatable {
    let id = UUID()
    let previousLaunchDate: Date
    let detectedAt: Date
    let logURL: URL?
    let logText: String
    let isLogTruncated: Bool
}

struct DevelopmentCrashReporter {
    struct LaunchState: Codable {
        var launchID: UUID
        var launchDate: Date
        var terminatedCleanly: Bool
    }

    private static let enabledInfoKey = "MacClipyDevelopmentCrashModalEnabled"

    private let isEnabled: Bool
    private let stateURL: URL
    private let diagnosticsDirectoryURL: URL
    private let fileManager: FileManager
    private let appName: String
    private let maximumLogCharacters: Int
    private let now: () -> Date

    init(
        isEnabled: Bool = Self.isEnabledInMainBundle,
        stateURL: URL = AppPaths.developmentCrashStateURL,
        diagnosticsDirectoryURL: URL = Self.defaultDiagnosticsDirectoryURL,
        fileManager: FileManager = .default,
        appName: String = AppPaths.applicationName,
        maximumLogCharacters: Int = 60000,
        now: @escaping () -> Date = Date.init
    ) {
        self.isEnabled = isEnabled
        self.stateURL = stateURL
        self.diagnosticsDirectoryURL = diagnosticsDirectoryURL
        self.fileManager = fileManager
        self.appName = appName
        self.maximumLogCharacters = maximumLogCharacters
        self.now = now
    }

    func startLaunch() -> DevelopmentCrashReport? {
        guard isEnabled else {
            return nil
        }

        let previousState = loadState()
        saveState(
            LaunchState(
                launchID: UUID(),
                launchDate: now(),
                terminatedCleanly: false
            )
        )

        guard let previousState, !previousState.terminatedCleanly else {
            return nil
        }

        return makeReport(for: previousState)
    }

    func markCleanTermination() {
        guard isEnabled, var state = loadState() else {
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

    private func makeReport(for state: LaunchState) -> DevelopmentCrashReport {
        let logURL = latestCrashLogURL(after: state.launchDate)
        let logContent = logURL.flatMap(readLog)

        return DevelopmentCrashReport(
            previousLaunchDate: state.launchDate,
            detectedAt: now(),
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
}
