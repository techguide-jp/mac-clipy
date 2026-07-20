import Defaults
import Foundation

enum AnalyticsEventName: String, Codable, Hashable {
    case install
    case dailyActive = "daily_active"
}

struct AnalyticsEventPayload: Codable, Equatable {
    let schemaVersion: Int
    let installationID: UUID
    let eventName: AnalyticsEventName
    let appVersion: String
    let buildNumber: String
    let macOSMajorVersion: Int
    let architecture: String
    let occurredAt: Date

    static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case installationID = "installation_id"
        case eventName = "event_name"
        case appVersion = "app_version"
        case buildNumber = "build_number"
        case macOSMajorVersion = "macos_major_version"
        case architecture
        case occurredAt = "occurred_at"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(installationID.uuidString.lowercased(), forKey: .installationID)
        try container.encode(eventName, forKey: .eventName)
        try container.encode(appVersion, forKey: .appVersion)
        try container.encode(buildNumber, forKey: .buildNumber)
        try container.encode(macOSMajorVersion, forKey: .macOSMajorVersion)
        try container.encode(architecture, forKey: .architecture)
        try container.encode(occurredAt, forKey: .occurredAt)
    }
}

struct AnalyticsAppMetadata: Equatable {
    let appVersion: String
    let buildNumber: String
    let macOSMajorVersion: Int
    let architecture: String

    static func current(bundle: Bundle = .main) -> AnalyticsAppMetadata {
        AnalyticsAppMetadata(
            appVersion: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
                ?? "unknown",
            buildNumber: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String
                ?? "unknown",
            macOSMajorVersion: ProcessInfo.processInfo.operatingSystemVersion.majorVersion,
            architecture: currentArchitecture
        )
    }

    private static var currentArchitecture: String {
        #if arch(arm64)
            "arm64"
        #elseif arch(x86_64)
            "x86_64"
        #else
            "unknown"
        #endif
    }
}

protocol AnalyticsEventStateStoring: AnyObject {
    var didSendInstall: Bool { get set }
    var lastDailyActiveDay: String? { get set }
}

@MainActor
protocol AnalyticsEventSending: AnyObject {
    func send(_ payload: AnalyticsEventPayload) async throws
}

enum AnalyticsSendingError: Error {
    case unsuccessfulStatusCode(Int)
}

extension Defaults.Keys {
    static let anonymousAnalyticsEnabled = Key<Bool>("anonymousAnalyticsEnabled", default: true)
    static let didSendAnonymousInstall = Key<Bool>("didSendAnonymousInstall", default: false)
    static let lastAnonymousDailyActiveDay = Key<String>("lastAnonymousDailyActiveDay", default: "")
}

final class DefaultsAnalyticsEventStateStore: AnalyticsEventStateStoring {
    var didSendInstall: Bool {
        get { Defaults[.didSendAnonymousInstall] }
        set { Defaults[.didSendAnonymousInstall] = newValue }
    }

    var lastDailyActiveDay: String? {
        get {
            let value = Defaults[.lastAnonymousDailyActiveDay]
            return value.isEmpty ? nil : value
        }
        set {
            Defaults[.lastAnonymousDailyActiveDay] = newValue ?? ""
        }
    }
}

@MainActor
final class AnonymousAnalyticsRecorder {
    private let installationIdentifierProvider: any InstallationIdentifierProviding
    private let eventStateStore: any AnalyticsEventStateStoring
    private let sender: any AnalyticsEventSending
    private let metadata: AnalyticsAppMetadata
    private let calendar: Calendar
    private let isEnabled: @MainActor () -> Bool
    private let runtimeAllowsCollection: Bool

    init(
        installationIdentifierProvider: any InstallationIdentifierProviding,
        eventStateStore: any AnalyticsEventStateStoring,
        sender: any AnalyticsEventSending,
        metadata: AnalyticsAppMetadata,
        calendar: Calendar = .current,
        isEnabled: @escaping @MainActor () -> Bool,
        runtimeAllowsCollection: Bool
    ) {
        self.installationIdentifierProvider = installationIdentifierProvider
        self.eventStateStore = eventStateStore
        self.sender = sender
        self.metadata = metadata
        self.calendar = calendar
        self.isEnabled = isEnabled
        self.runtimeAllowsCollection = runtimeAllowsCollection
    }

    func recordLaunch(at date: Date = Date()) async {
        guard runtimeAllowsCollection, isEnabled(), !Task.isCancelled else {
            return
        }
        guard let installationID = try? installationIdentifierProvider.installationIdentifier() else {
            return
        }

        let day = dayIdentifier(for: date)
        var pendingEvents: [AnalyticsEventName] = []
        if !eventStateStore.didSendInstall {
            pendingEvents.append(.install)
        }
        if eventStateStore.lastDailyActiveDay != day {
            pendingEvents.append(.dailyActive)
        }

        for eventName in pendingEvents {
            guard isEnabled(), !Task.isCancelled else {
                return
            }

            let payload = AnalyticsEventPayload(
                schemaVersion: 1,
                installationID: installationID,
                eventName: eventName,
                appVersion: metadata.appVersion,
                buildNumber: metadata.buildNumber,
                macOSMajorVersion: metadata.macOSMajorVersion,
                architecture: metadata.architecture,
                occurredAt: date
            )

            do {
                try await sender.send(payload)
                markSent(eventName, day: day)
            } catch {
                continue
            }
        }
    }

    private func markSent(_ eventName: AnalyticsEventName, day: String) {
        switch eventName {
        case .install:
            eventStateStore.didSendInstall = true
        case .dailyActive:
            eventStateStore.lastDailyActiveDay = day
        }
    }

    private func dayIdentifier(for date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }
}
