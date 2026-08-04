import Defaults
import Foundation

struct AnalyticsFeatureUsageState: Codable, Defaults.Serializable, Equatable {
    private(set) var countsByDay: [String: [AnalyticsFeature: Int]] = [:]

    mutating func increment(_ feature: AnalyticsFeature, on day: String) {
        var dayCounts = countsByDay[day, default: [:]]
        let currentCount = dayCounts[feature, default: 0]
        guard currentCount < Int.max else {
            return
        }

        dayCounts[feature] = currentCount + 1
        countsByDay[day] = dayCounts
    }

    func count(for feature: AnalyticsFeature, on day: String) -> Int {
        countsByDay[day]?[feature, default: 0] ?? 0
    }

    func entries(before day: String) -> [AnalyticsFeatureUsageEntry] {
        countsByDay
            .filter { $0.key < day }
            .flatMap { usageDay, counts in
                counts.compactMap { feature, count in
                    guard count > 0 else {
                        return nil
                    }
                    return AnalyticsFeatureUsageEntry(day: usageDay, feature: feature, count: count)
                }
            }
            .sorted {
                if $0.day == $1.day {
                    $0.feature.rawValue < $1.feature.rawValue
                } else {
                    $0.day < $1.day
                }
            }
    }

    mutating func removeSentCount(_ sentCount: Int, for feature: AnalyticsFeature, on day: String) {
        guard var dayCounts = countsByDay[day], let currentCount = dayCounts[feature] else {
            return
        }

        let remainingCount = currentCount - min(max(sentCount, 0), currentCount)
        if remainingCount > 0 {
            dayCounts[feature] = remainingCount
        } else {
            dayCounts.removeValue(forKey: feature)
        }

        if dayCounts.isEmpty {
            countsByDay.removeValue(forKey: day)
        } else {
            countsByDay[day] = dayCounts
        }
    }
}

struct AnalyticsFeatureUsageEntry: Equatable {
    let day: String
    let feature: AnalyticsFeature
    let count: Int
}

protocol AnalyticsEventStateStoring: AnyObject {
    var didSendInstall: Bool { get set }
    var lastDailyActiveDay: String? { get set }
    var lastDailyRunningDay: String? { get set }
    var lastDailyEngagedDay: String? { get set }
    var featureUsageState: AnalyticsFeatureUsageState { get set }
}

extension Defaults.Keys {
    static let anonymousAnalyticsEnabled = Key<Bool>("anonymousAnalyticsEnabled", default: true)
    static let didSendAnonymousInstall = Key<Bool>("didSendAnonymousInstall", default: false)
    static let lastAnonymousDailyActiveDay = Key<String>("lastAnonymousDailyActiveDay", default: "")
    static let lastAnonymousDailyRunningDay = Key<String>("lastAnonymousDailyRunningDay", default: "")
    static let lastAnonymousDailyEngagedDay = Key<String>("lastAnonymousDailyEngagedDay", default: "")
    static let anonymousFeatureUsageState = Key<AnalyticsFeatureUsageState>(
        "anonymousFeatureUsageState",
        default: AnalyticsFeatureUsageState()
    )
}

final class DefaultsAnalyticsEventStateStore: AnalyticsEventStateStoring {
    var didSendInstall: Bool {
        get { Defaults[.didSendAnonymousInstall] }
        set { Defaults[.didSendAnonymousInstall] = newValue }
    }

    var lastDailyActiveDay: String? {
        get { optionalDay(for: .lastAnonymousDailyActiveDay) }
        set { Defaults[.lastAnonymousDailyActiveDay] = newValue ?? "" }
    }

    var lastDailyRunningDay: String? {
        get { optionalDay(for: .lastAnonymousDailyRunningDay) }
        set { Defaults[.lastAnonymousDailyRunningDay] = newValue ?? "" }
    }

    var lastDailyEngagedDay: String? {
        get { optionalDay(for: .lastAnonymousDailyEngagedDay) }
        set { Defaults[.lastAnonymousDailyEngagedDay] = newValue ?? "" }
    }

    var featureUsageState: AnalyticsFeatureUsageState {
        get { Defaults[.anonymousFeatureUsageState] }
        set { Defaults[.anonymousFeatureUsageState] = newValue }
    }

    private func optionalDay(for key: Defaults.Key<String>) -> String? {
        let value = Defaults[key]
        return value.isEmpty ? nil : value
    }
}
