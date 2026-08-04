import Foundation

enum AnalyticsEventName: String, Codable, Hashable {
    case install
    case dailyRunning = "daily_running"
    case dailyEngaged = "daily_engaged"
    case featureUsage = "feature_usage"
}

enum AnalyticsFeature: String, CaseIterable, Codable, Hashable {
    case historyPanel = "history_panel"
    case favoritesPanel = "favorites_panel"
    case historyItemUse = "history_item_use"
    case favoriteItemUse = "favorite_item_use"
    case searchSession = "search_session"
    case favoriteManagement = "favorite_management"
}

enum AnalyticsItemSource: Equatable {
    case history
    case favorite

    var feature: AnalyticsFeature {
        switch self {
        case .history:
            .historyItemUse
        case .favorite:
            .favoriteItemUse
        }
    }
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
    let feature: AnalyticsFeature?
    let usageCount: Int?
    let usageDate: String?

    init(
        schemaVersion: Int,
        installationID: UUID,
        eventName: AnalyticsEventName,
        appVersion: String,
        buildNumber: String,
        macOSMajorVersion: Int,
        architecture: String,
        occurredAt: Date,
        feature: AnalyticsFeature? = nil,
        usageCount: Int? = nil,
        usageDate: String? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.installationID = installationID
        self.eventName = eventName
        self.appVersion = appVersion
        self.buildNumber = buildNumber
        self.macOSMajorVersion = macOSMajorVersion
        self.architecture = architecture
        self.occurredAt = occurredAt
        self.feature = feature
        self.usageCount = usageCount
        self.usageDate = usageDate
    }

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
        case feature
        case usageCount = "usage_count"
        case usageDate = "usage_date"
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
        try container.encodeIfPresent(feature, forKey: .feature)
        try container.encodeIfPresent(usageCount, forKey: .usageCount)
        try container.encodeIfPresent(usageDate, forKey: .usageDate)
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

@MainActor
protocol AnalyticsEventSending: AnyObject {
    func send(_ payload: AnalyticsEventPayload) async throws
}

enum AnalyticsSendingError: Error {
    case unsuccessfulStatusCode(Int)
}
