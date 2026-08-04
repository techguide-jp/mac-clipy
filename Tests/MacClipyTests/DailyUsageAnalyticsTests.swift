import Defaults
import Foundation
@testable import MacClipy
import XCTest

@MainActor
final class DailyUsageAnalyticsTests: XCTestCase {
    private let installationID = UUID(uuidString: "B62E5EE9-E144-497E-A4FA-8F02A40F15CD") ?? UUID()

    override func tearDown() {
        Defaults.Keys.lastAnonymousDailyRunningDay.reset()
        Defaults.Keys.lastAnonymousDailyEngagedDay.reset()
        Defaults.Keys.anonymousFeatureUsageState.reset()
        super.tearDown()
    }

    func testDefaultsStorePersistsDailySentStateAndFeatureCounters() {
        let firstStore = DefaultsAnalyticsEventStateStore()
        var featureUsageState = AnalyticsFeatureUsageState()
        featureUsageState.increment(.historyPanel, on: "2025-07-20")
        featureUsageState.increment(.historyPanel, on: "2025-07-20")

        firstStore.lastDailyRunningDay = "2025-07-21"
        firstStore.lastDailyEngagedDay = "2025-07-20"
        firstStore.featureUsageState = featureUsageState

        let reloadedStore = DefaultsAnalyticsEventStateStore()
        XCTAssertEqual(reloadedStore.lastDailyRunningDay, "2025-07-21")
        XCTAssertEqual(reloadedStore.lastDailyEngagedDay, "2025-07-20")
        XCTAssertEqual(reloadedStore.featureUsageState.count(for: .historyPanel, on: "2025-07-20"), 2)
    }

    func testLegacyDailyActiveDayMigratesWithoutDuplicateRunningEvent() async {
        let state = DailyAnalyticsStateStore()
        state.lastDailyActiveDay = "2025-07-20"
        let sender = DailyAnalyticsSender()
        let recorder = makeRecorder(sender: sender, state: state)

        await recorder.recordRunning(at: date(year: 2025, month: 7, day: 20))

        XCTAssertTrue(sender.successfulPayloads.isEmpty)
        XCTAssertEqual(state.lastDailyRunningDay, "2025-07-20")
    }

    func testExistingRunningDayWinsOverLegacyDailyActiveDay() async {
        let state = DailyAnalyticsStateStore()
        state.lastDailyActiveDay = "2025-07-19"
        state.lastDailyRunningDay = "2025-07-20"
        let sender = DailyAnalyticsSender()
        let recorder = makeRecorder(sender: sender, state: state)

        await recorder.recordRunning(at: date(year: 2025, month: 7, day: 20))

        XCTAssertTrue(sender.successfulPayloads.isEmpty)
        XCTAssertEqual(state.lastDailyRunningDay, "2025-07-20")
    }

    func testRunningSendsOncePerLocalDayAndRetriesAfterFailure() async {
        let state = DailyAnalyticsStateStore()
        let sender = DailyAnalyticsSender(failureCounts: [.dailyRunning: 1])
        let recorder = makeRecorder(sender: sender, state: state)
        let firstDay = date(year: 2025, month: 7, day: 20)

        await recorder.recordRunning(at: firstDay)
        await recorder.recordRunning(at: firstDay.addingTimeInterval(60))
        await recorder.recordRunning(at: firstDay.addingTimeInterval(120))

        XCTAssertEqual(sender.attemptedEventNames, [.dailyRunning, .dailyRunning])
        XCTAssertEqual(sender.successfulPayloads.map(\.eventName), [.dailyRunning])
        XCTAssertEqual(state.lastDailyRunningDay, "2025-07-20")
    }

    func testEngagedSendsOncePerLocalDayAndRetriesOnNextOperation() async {
        let state = DailyAnalyticsStateStore()
        let sender = DailyAnalyticsSender(failureCounts: [.dailyEngaged: 1])
        let recorder = makeRecorder(sender: sender, state: state)
        let firstDay = date(year: 2025, month: 7, day: 20)

        await recorder.recordEngagement(at: firstDay)
        await recorder.recordEngagement(at: firstDay.addingTimeInterval(60))
        await recorder.recordEngagement(at: firstDay.addingTimeInterval(120))

        XCTAssertEqual(sender.attemptedEventNames, [.dailyEngaged, .dailyEngaged])
        XCTAssertEqual(sender.successfulPayloads.map(\.eventName), [.dailyEngaged])
        XCTAssertEqual(state.lastDailyEngagedDay, "2025-07-20")
    }

    func testFeatureUsageAggregatesWithoutImmediateNetworkRequest() {
        let state = DailyAnalyticsStateStore()
        let sender = DailyAnalyticsSender()
        let recorder = makeRecorder(sender: sender, state: state)
        let firstDay = date(year: 2025, month: 7, day: 20)

        recorder.recordFeatureUsage(.historyPanel, at: firstDay)
        recorder.recordFeatureUsage(.historyPanel, at: firstDay)
        recorder.recordFeatureUsage(.searchSession, at: firstDay)

        XCTAssertTrue(sender.attemptedEventNames.isEmpty)
        XCTAssertEqual(state.featureUsageState.count(for: .historyPanel, on: "2025-07-20"), 2)
        XCTAssertEqual(state.featureUsageState.count(for: .searchSession, on: "2025-07-20"), 1)
    }

    func testRunningFlushesOnlyCompletedDaysWithApprovedFeaturePayload() async throws {
        let state = DailyAnalyticsStateStore()
        let sender = DailyAnalyticsSender()
        let recorder = makeRecorder(sender: sender, state: state)
        let firstDay = date(year: 2025, month: 7, day: 20)
        let nextDay = date(year: 2025, month: 7, day: 21)

        recorder.recordFeatureUsage(.historyPanel, at: firstDay)
        recorder.recordFeatureUsage(.historyPanel, at: firstDay)
        recorder.recordFeatureUsage(.favoritesPanel, at: nextDay)

        await recorder.recordRunning(at: nextDay)

        let featurePayload = try XCTUnwrap(
            sender.successfulPayloads.first { $0.eventName == .featureUsage }
        )
        XCTAssertEqual(featurePayload.feature, .historyPanel)
        XCTAssertEqual(featurePayload.usageCount, 2)
        XCTAssertEqual(featurePayload.usageDate, "2025-07-20")
        XCTAssertEqual(state.featureUsageState.count(for: .historyPanel, on: "2025-07-20"), 0)
        XCTAssertEqual(state.featureUsageState.count(for: .favoritesPanel, on: "2025-07-21"), 1)

        let object = try encodedObject(featurePayload)
        XCTAssertEqual(
            Set(object.keys),
            [
                "schema_version",
                "installation_id",
                "event_name",
                "app_version",
                "build_number",
                "macos_major_version",
                "architecture",
                "occurred_at",
                "feature",
                "usage_count",
                "usage_date"
            ]
        )
    }

    func testFailedFeatureUsageRemainsPendingAndRetries() async {
        let state = DailyAnalyticsStateStore()
        let sender = DailyAnalyticsSender(failureCounts: [.featureUsage: 1])
        let recorder = makeRecorder(sender: sender, state: state)
        let firstDay = date(year: 2025, month: 7, day: 20)
        let nextDay = date(year: 2025, month: 7, day: 21)

        recorder.recordFeatureUsage(.favoriteManagement, at: firstDay)

        await recorder.recordRunning(at: nextDay)
        XCTAssertEqual(state.featureUsageState.count(for: .favoriteManagement, on: "2025-07-20"), 1)

        await recorder.recordRunning(at: nextDay)
        XCTAssertEqual(state.featureUsageState.count(for: .favoriteManagement, on: "2025-07-20"), 0)
        XCTAssertEqual(
            sender.attemptedEventNames.count(where: { $0 == .featureUsage }),
            2
        )
    }

    func testConcurrentRunningTriggersStillFlushFeatureUsageSequentially() async {
        let state = DailyAnalyticsStateStore()
        let sender = SuspendingFeatureAnalyticsSender()
        let recorder = makeRecorder(sender: sender, state: state)
        let firstDay = date(year: 2025, month: 7, day: 20)
        let nextDay = date(year: 2025, month: 7, day: 21)
        recorder.recordFeatureUsage(.historyPanel, at: firstDay)
        recorder.recordFeatureUsage(.favoritesPanel, at: firstDay)

        let firstTrigger = Task {
            await recorder.recordRunning(at: nextDay)
        }
        await sender.waitUntilFirstFeatureSendStarts()
        let secondTrigger = Task {
            await recorder.recordRunning(at: nextDay)
        }
        await Task.yield()
        sender.resumeFirstFeatureSend()
        await firstTrigger.value
        await secondTrigger.value

        XCTAssertEqual(sender.maximumConcurrentFeatureSends, 1)
        XCTAssertEqual(sender.successfulFeaturePayloads.count, 2)
    }

    func testDisabledAndRuntimeGuardedRecordersDoNotPersistOrSendNewMetrics() async {
        let disabledState = DailyAnalyticsStateStore()
        let disabledSender = DailyAnalyticsSender()
        let disabledRecorder = makeRecorder(
            sender: disabledSender,
            state: disabledState,
            isEnabled: { false }
        )
        let developmentState = DailyAnalyticsStateStore()
        let developmentSender = DailyAnalyticsSender()
        let developmentRecorder = makeRecorder(
            sender: developmentSender,
            state: developmentState,
            runtimeAllowsCollection: false
        )
        let firstDay = date(year: 2025, month: 7, day: 20)

        disabledRecorder.recordFeatureUsage(.historyItemUse, at: firstDay)
        await disabledRecorder.recordEngagement(at: firstDay)
        developmentRecorder.recordFeatureUsage(.favoriteItemUse, at: firstDay)
        await developmentRecorder.recordRunning(at: firstDay)

        XCTAssertTrue(disabledState.featureUsageState.countsByDay.isEmpty)
        XCTAssertTrue(disabledSender.attemptedEventNames.isEmpty)
        XCTAssertTrue(developmentState.featureUsageState.countsByDay.isEmpty)
        XCTAssertTrue(developmentSender.attemptedEventNames.isEmpty)
    }

    func testAllFeatureNamesMatchTheIssueAllowlist() {
        XCTAssertEqual(
            Set(AnalyticsFeature.allCases.map(\.rawValue)),
            [
                "history_panel",
                "favorites_panel",
                "history_item_use",
                "favorite_item_use",
                "search_session",
                "favorite_management"
            ]
        )
    }

    private func makeRecorder(
        sender: any AnalyticsEventSending,
        state: DailyAnalyticsStateStore,
        isEnabled: @escaping @MainActor () -> Bool = { true },
        runtimeAllowsCollection: Bool = true
    ) -> AnonymousAnalyticsRecorder {
        AnonymousAnalyticsRecorder(
            installationIdentifierProvider: DailyInstallationIdentifierProvider(identifier: installationID),
            eventStateStore: state,
            sender: sender,
            metadata: AnalyticsAppMetadata(
                appVersion: "0.2.0",
                buildNumber: "20",
                macOSMajorVersion: 26,
                architecture: "arm64"
            ),
            calendar: calendar,
            isEnabled: isEnabled,
            runtimeAllowsCollection: runtimeAllowsCollection
        )
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 9 * 3600) ?? .current
        return calendar
    }

    private func date(year: Int, month: Int, day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))
            ?? Date(timeIntervalSince1970: 0)
    }

    private func encodedObject(_ payload: AnalyticsEventPayload) throws -> [String: Any] {
        let data = try AnalyticsEventPayload.encoder.encode(payload)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}

private final class DailyInstallationIdentifierProvider: InstallationIdentifierProviding {
    private let identifier: UUID

    init(identifier: UUID) {
        self.identifier = identifier
    }

    func installationIdentifier() throws -> UUID {
        identifier
    }
}

private final class DailyAnalyticsStateStore: AnalyticsEventStateStoring {
    var didSendInstall = true
    var lastDailyActiveDay: String?
    var lastDailyRunningDay: String?
    var lastDailyEngagedDay: String?
    var featureUsageState = AnalyticsFeatureUsageState()
}

@MainActor
private final class DailyAnalyticsSender: AnalyticsEventSending {
    private var failureCounts: [AnalyticsEventName: Int]
    private(set) var attemptedEventNames: [AnalyticsEventName] = []
    private(set) var successfulPayloads: [AnalyticsEventPayload] = []

    init(failureCounts: [AnalyticsEventName: Int] = [:]) {
        self.failureCounts = failureCounts
    }

    func send(_ payload: AnalyticsEventPayload) async throws {
        attemptedEventNames.append(payload.eventName)
        let remainingFailures = failureCounts[payload.eventName, default: 0]
        if remainingFailures > 0 {
            failureCounts[payload.eventName] = remainingFailures - 1
            throw AnalyticsSendingError.unsuccessfulStatusCode(503)
        }

        successfulPayloads.append(payload)
    }
}

@MainActor
private final class SuspendingFeatureAnalyticsSender: AnalyticsEventSending {
    private var featureSendStartedContinuation: CheckedContinuation<Void, Never>?
    private var firstFeatureSendContinuation: CheckedContinuation<Void, Never>?
    private var didStartFeatureSend = false
    private var activeFeatureSends = 0
    private(set) var maximumConcurrentFeatureSends = 0
    private(set) var successfulFeaturePayloads: [AnalyticsEventPayload] = []

    func waitUntilFirstFeatureSendStarts() async {
        guard !didStartFeatureSend else {
            return
        }

        await withCheckedContinuation { continuation in
            featureSendStartedContinuation = continuation
        }
    }

    func resumeFirstFeatureSend() {
        firstFeatureSendContinuation?.resume()
        firstFeatureSendContinuation = nil
    }

    func send(_ payload: AnalyticsEventPayload) async throws {
        guard payload.eventName == .featureUsage else {
            return
        }

        activeFeatureSends += 1
        maximumConcurrentFeatureSends = max(maximumConcurrentFeatureSends, activeFeatureSends)
        if !didStartFeatureSend {
            didStartFeatureSend = true
            featureSendStartedContinuation?.resume()
            featureSendStartedContinuation = nil
            await withCheckedContinuation { continuation in
                firstFeatureSendContinuation = continuation
            }
        }

        successfulFeaturePayloads.append(payload)
        activeFeatureSends -= 1
    }
}
