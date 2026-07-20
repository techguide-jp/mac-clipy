import Defaults
import Foundation
@testable import MacClipy
import XCTest

@MainActor
final class AnonymousAnalyticsTests: XCTestCase {
    private let installationID = UUID(uuidString: "A4B69D19-9B90-4DAD-B034-F4A3FC912FA1") ?? UUID()
    private let fixedDate = Date(timeIntervalSince1970: 1_753_004_096)

    override func tearDown() {
        Defaults.Keys.anonymousAnalyticsEnabled.reset()
        Defaults.Keys.didSendAnonymousInstall.reset()
        Defaults.Keys.lastAnonymousDailyActiveDay.reset()
        super.tearDown()
    }

    func testInstallationIdentifierIsCreatedOnceAndReused() throws {
        let store = InMemoryInstallationIdentifierStore()
        let provider = InstallationIdentifierProvider(store: store)

        let first = try provider.installationIdentifier()
        let second = try provider.installationIdentifier()

        XCTAssertEqual(first, second)
        XCTAssertEqual(store.savedValues, [first.uuidString.lowercased()])
    }

    func testInvalidStoredInstallationIdentifierIsReplaced() throws {
        let store = InMemoryInstallationIdentifierStore(storedValue: "not-a-uuid")
        let provider = InstallationIdentifierProvider(store: store)

        let identifier = try provider.installationIdentifier()

        XCTAssertEqual(store.savedValues, [identifier.uuidString.lowercased()])
    }

    func testFirstLaunchSendsInstallAndDailyActive() async {
        let sender = RecordingAnalyticsSender()
        let state = InMemoryAnalyticsEventStateStore()
        let recorder = makeRecorder(sender: sender, state: state)

        await recorder.recordLaunch(at: fixedDate)

        XCTAssertEqual(sender.successfulPayloads.map(\.eventName), [.install, .dailyActive])
        XCTAssertTrue(state.didSendInstall)
        XCTAssertNotNil(state.lastDailyActiveDay)
    }

    func testSameDayLaunchDoesNotSendAgainAndNextDaySendsDailyActive() async {
        let sender = RecordingAnalyticsSender()
        let state = InMemoryAnalyticsEventStateStore()
        let recorder = makeRecorder(sender: sender, state: state)

        await recorder.recordLaunch(at: fixedDate)
        await recorder.recordLaunch(at: fixedDate.addingTimeInterval(3600))
        await recorder.recordLaunch(at: fixedDate.addingTimeInterval(86400))

        XCTAssertEqual(
            sender.successfulPayloads.map(\.eventName),
            [.install, .dailyActive, .dailyActive]
        )
    }

    func testFailedInstallIsRetriedWithoutRepeatingSuccessfulDailyActive() async {
        let sender = RecordingAnalyticsSender(failOnceFor: [.install])
        let state = InMemoryAnalyticsEventStateStore()
        let recorder = makeRecorder(sender: sender, state: state)

        await recorder.recordLaunch(at: fixedDate)
        await recorder.recordLaunch(at: fixedDate.addingTimeInterval(3600))

        XCTAssertEqual(sender.attemptedEventNames, [.install, .dailyActive, .install])
        XCTAssertEqual(sender.successfulPayloads.map(\.eventName), [.dailyActive, .install])
        XCTAssertTrue(state.didSendInstall)
    }

    func testDisabledAndRuntimeGuardedRecordersDoNotCreateIDOrSend() async {
        let disabledSender = RecordingAnalyticsSender()
        let disabledProvider = RecordingInstallationIdentifierProvider(identifier: installationID)
        let disabledRecorder = makeRecorder(
            sender: disabledSender,
            identifierProvider: disabledProvider,
            isEnabled: { false }
        )

        let developmentSender = RecordingAnalyticsSender()
        let developmentProvider = RecordingInstallationIdentifierProvider(identifier: installationID)
        let developmentRecorder = makeRecorder(
            sender: developmentSender,
            identifierProvider: developmentProvider,
            runtimeAllowsCollection: false
        )

        await disabledRecorder.recordLaunch(at: fixedDate)
        await developmentRecorder.recordLaunch(at: fixedDate)

        XCTAssertTrue(disabledSender.attemptedEventNames.isEmpty)
        XCTAssertEqual(disabledProvider.loadCount, 0)
        XCTAssertTrue(developmentSender.attemptedEventNames.isEmpty)
        XCTAssertEqual(developmentProvider.loadCount, 0)
    }

    func testOptOutBetweenEventsStopsRemainingRequests() async {
        var isEnabled = true
        let sender = RecordingAnalyticsSender {
            isEnabled = false
        }
        let recorder = makeRecorder(sender: sender, isEnabled: { isEnabled })

        await recorder.recordLaunch(at: fixedDate)

        XCTAssertEqual(sender.attemptedEventNames, [.install])
    }

    func testPayloadEncodingContainsOnlyApprovedSnakeCaseFields() throws {
        let payload = AnalyticsEventPayload(
            schemaVersion: 1,
            installationID: installationID,
            eventName: .install,
            appVersion: "0.2.0",
            buildNumber: "20",
            macOSMajorVersion: 26,
            architecture: "arm64",
            occurredAt: fixedDate
        )

        let data = try AnalyticsEventPayload.encoder.encode(payload)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

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
                "occurred_at"
            ]
        )
        XCTAssertEqual(object["installation_id"] as? String, installationID.uuidString.lowercased())
        XCTAssertEqual(object["event_name"] as? String, "install")
    }

    func testAnonymousAnalyticsDefaultsToEnabledAndPersistsOptOut() {
        Defaults.Keys.anonymousAnalyticsEnabled.reset()
        let model = SettingsModel()

        XCTAssertTrue(model.isAnonymousAnalyticsEnabled)

        model.setAnonymousAnalyticsEnabled(false)

        XCTAssertFalse(Defaults[.anonymousAnalyticsEnabled])
    }

    func testPrivacyURLPointsToOfficialMacClipyPolicy() {
        XCTAssertEqual(
            AppConstants.Support.privacyURL.absoluteString,
            "https://techguide.jp/macclipy/privacy/"
        )
    }

    func testRuntimeConfigurationFailsClosedWithoutExplicitHTTPSConfiguration() {
        let missing = AnalyticsRuntimeConfiguration(infoDictionary: [:])
        let insecure = AnalyticsRuntimeConfiguration(
            infoDictionary: [
                "MacClipyAnalyticsEnabled": true,
                "MacClipyAnalyticsEndpoint": "http://techguide.jp/api/macclipy/analytics"
            ]
        )
        let unexpectedHost = AnalyticsRuntimeConfiguration(
            infoDictionary: [
                "MacClipyAnalyticsEnabled": true,
                "MacClipyAnalyticsEndpoint": "https://example.com/api/macclipy/analytics"
            ]
        )
        let unexpectedQuery = AnalyticsRuntimeConfiguration(
            infoDictionary: [
                "MacClipyAnalyticsEnabled": true,
                "MacClipyAnalyticsEndpoint":
                    "https://techguide.jp/api/macclipy/analytics?redirect=example.com"
            ]
        )
        let unexpectedPort = AnalyticsRuntimeConfiguration(
            infoDictionary: [
                "MacClipyAnalyticsEnabled": true,
                "MacClipyAnalyticsEndpoint": "https://techguide.jp:444/api/macclipy/analytics"
            ]
        )

        XCTAssertFalse(missing.allowsCollection)
        XCTAssertFalse(insecure.allowsCollection)
        XCTAssertFalse(unexpectedHost.allowsCollection)
        XCTAssertFalse(unexpectedQuery.allowsCollection)
        XCTAssertFalse(unexpectedPort.allowsCollection)
    }

    func testRuntimeConfigurationAcceptsOfficialEndpointWhenExplicitlyEnabled() throws {
        let configuration = AnalyticsRuntimeConfiguration(
            infoDictionary: [
                "MacClipyAnalyticsEnabled": true,
                "MacClipyAnalyticsEndpoint": "https://techguide.jp/api/macclipy/analytics"
            ]
        )

        XCTAssertTrue(configuration.allowsCollection)
        XCTAssertEqual(
            try XCTUnwrap(configuration.endpoint).absoluteString,
            "https://techguide.jp/api/macclipy/analytics"
        )
    }

    func testAnalyticsURLSessionRejectsRedirects() throws {
        let session = AnalyticsURLSessionFactory.make()
        defer { session.invalidateAndCancel() }
        let redirectURL = try XCTUnwrap(URL(string: "https://example.com/collect"))
        let redirectRequest = URLRequest(url: redirectURL)

        XCTAssertTrue(session.delegate is AnalyticsRedirectRejectingDelegate)
        XCTAssertNil(AnalyticsRedirectRejectingDelegate.redirectTarget(for: redirectRequest))
    }

    func testHTTPSenderUsesPostJSONAndShortTimeout() async throws {
        let endpoint = try XCTUnwrap(URL(string: "https://techguide.jp/api/macclipy/analytics"))
        var capturedRequest: URLRequest?
        let sender = AnalyticsHTTPSender(endpoint: endpoint) { request in
            capturedRequest = request
            return try (
                Data(),
                XCTUnwrap(
                    HTTPURLResponse(
                        url: endpoint,
                        statusCode: 202,
                        httpVersion: nil,
                        headerFields: nil
                    )
                )
            )
        }
        let payload = makePayload(eventName: .dailyActive)

        try await sender.send(payload)

        let request = try XCTUnwrap(capturedRequest)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(request.timeoutInterval, 3)
        XCTAssertEqual(request.httpBody, try AnalyticsEventPayload.encoder.encode(payload))
    }

    func testHTTPSenderRejectsNonSuccessStatus() async {
        guard let endpoint = URL(string: "https://techguide.jp/api/macclipy/analytics") else {
            XCTFail("Invalid test endpoint")
            return
        }
        let sender = AnalyticsHTTPSender(endpoint: endpoint) { _ in
            try (
                Data(),
                XCTUnwrap(
                    HTTPURLResponse(
                        url: endpoint,
                        statusCode: 503,
                        httpVersion: nil,
                        headerFields: nil
                    )
                )
            )
        }

        do {
            try await sender.send(makePayload(eventName: .install))
            XCTFail("Expected unsuccessful status code")
        } catch let AnalyticsSendingError.unsuccessfulStatusCode(statusCode) {
            XCTAssertEqual(statusCode, 503)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func makeRecorder(
        sender: RecordingAnalyticsSender,
        state: InMemoryAnalyticsEventStateStore = InMemoryAnalyticsEventStateStore(),
        identifierProvider: RecordingInstallationIdentifierProvider? = nil,
        isEnabled: @escaping @MainActor () -> Bool = { true },
        runtimeAllowsCollection: Bool = true
    ) -> AnonymousAnalyticsRecorder {
        AnonymousAnalyticsRecorder(
            installationIdentifierProvider: identifierProvider
                ?? RecordingInstallationIdentifierProvider(identifier: installationID),
            eventStateStore: state,
            sender: sender,
            metadata: AnalyticsAppMetadata(
                appVersion: "0.2.0",
                buildNumber: "20",
                macOSMajorVersion: 26,
                architecture: "arm64"
            ),
            calendar: utcCalendar,
            isEnabled: isEnabled,
            runtimeAllowsCollection: runtimeAllowsCollection
        )
    }

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    private func makePayload(eventName: AnalyticsEventName) -> AnalyticsEventPayload {
        AnalyticsEventPayload(
            schemaVersion: 1,
            installationID: installationID,
            eventName: eventName,
            appVersion: "0.2.0",
            buildNumber: "20",
            macOSMajorVersion: 26,
            architecture: "arm64",
            occurredAt: fixedDate
        )
    }
}

private final class InMemoryInstallationIdentifierStore: InstallationIdentifierStoring {
    private var storedValue: String?
    private(set) var savedValues: [String] = []

    init(storedValue: String? = nil) {
        self.storedValue = storedValue
    }

    func load() throws -> String? {
        storedValue
    }

    func save(_ value: String) throws {
        storedValue = value
        savedValues.append(value)
    }
}

private final class RecordingInstallationIdentifierProvider: InstallationIdentifierProviding {
    private let identifier: UUID
    private(set) var loadCount = 0

    init(identifier: UUID) {
        self.identifier = identifier
    }

    func installationIdentifier() throws -> UUID {
        loadCount += 1
        return identifier
    }
}

private final class InMemoryAnalyticsEventStateStore: AnalyticsEventStateStoring {
    var didSendInstall = false
    var lastDailyActiveDay: String?
}

@MainActor
private final class RecordingAnalyticsSender: AnalyticsEventSending {
    private var failOnceFor: Set<AnalyticsEventName>
    private let onSuccessfulSend: @MainActor () -> Void
    private(set) var attemptedEventNames: [AnalyticsEventName] = []
    private(set) var successfulPayloads: [AnalyticsEventPayload] = []

    init(
        failOnceFor: Set<AnalyticsEventName> = [],
        onSuccessfulSend: @escaping @MainActor () -> Void = {}
    ) {
        self.failOnceFor = failOnceFor
        self.onSuccessfulSend = onSuccessfulSend
    }

    func send(_ payload: AnalyticsEventPayload) async throws {
        attemptedEventNames.append(payload.eventName)
        if failOnceFor.remove(payload.eventName) != nil {
            throw AnalyticsSendingError.unsuccessfulStatusCode(503)
        }

        successfulPayloads.append(payload)
        onSuccessfulSend()
    }
}
