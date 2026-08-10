import Foundation
@testable import MacClipy
import XCTest

@MainActor
final class AppAnalyticsIntegrationTests: XCTestCase {
    func testDayChangedNotificationCanArriveFromBackgroundQueue() async {
        let recorder = AppAnalyticsRecorderSpy()
        let runningRecorded = expectation(description: "running recorded")
        recorder.onRunning = {
            runningRecorded.fulfill()
        }
        let appDelegate = AppDelegateBridge(appModel: makeAppModel(recorder: recorder))
        let selector = NSSelectorFromString("applicationDidConfirmRunning:")
        let notificationPosted = expectation(description: "day changed notification posted")
        NotificationCenter.default.addObserver(
            appDelegate,
            selector: selector,
            name: .NSCalendarDayChanged,
            object: nil
        )
        defer {
            NotificationCenter.default.removeObserver(appDelegate)
        }

        XCTAssertTrue(appDelegate.responds(to: selector))

        DispatchQueue.global(qos: .userInitiated).async {
            NotificationCenter.default.post(name: .NSCalendarDayChanged, object: nil)
            notificationPosted.fulfill()
        }

        await fulfillment(of: [notificationPosted, runningRecorded], timeout: 1)
        XCTAssertEqual(recorder.runningDates.count, 1)
    }

    func testLifecycleRunningTriggerUsesAnalyticsRecorder() async {
        let recorder = AppAnalyticsRecorderSpy()
        let appModel = makeAppModel(recorder: recorder)
        let date = Date(timeIntervalSince1970: 1_753_004_096)

        await appModel.applicationDidConfirmRunning(at: date)

        XCTAssertEqual(recorder.runningDates, [date])
        XCTAssertTrue(recorder.launchDates.isEmpty)
    }

    func testPopupInteractionsMapToApprovedFeatureEnums() throws {
        let recorder = AppAnalyticsRecorderSpy()
        let appModel = makeAppModel(recorder: recorder)
        let historyItem = try XCTUnwrap(
            try appModel.historyModel.store.add(content: "private clipboard text", sourceBundleID: "com.example.Editor")
        )
        let favorite = try appModel.favoritesModel.store.addFavorite(for: historyItem, displayTitle: "private favorite name")
        appModel.historyModel.refreshFromStore()
        appModel.favoritesModel.refreshFromStore()

        appModel.historyPopupModel.prepare(initialMode: .all)
        appModel.historyPopupModel.query = "private search term"
        appModel.historyPopupModel.chooseSelectedItem()
        appModel.historyPopupModel.prepare(initialMode: .favorites)
        appModel.historyPopupModel.chooseSelectedItem()
        appModel.useHistoryItemFromMenu(historyItem)
        appModel.favoritesModel.selectFavorite(favorite)
        appModel.favoritesModel.removeSelectedFavorite()

        XCTAssertEqual(
            recorder.features,
            [
                .historyPanel,
                .searchSession,
                .historyItemUse,
                .favoritesPanel,
                .favoriteItemUse,
                .historyItemUse,
                .favoriteManagement
            ]
        )
    }

    func testPanelOpenAndMenuDirectSelectionAreEngagedOperations() async throws {
        let recorder = AppAnalyticsRecorderSpy()
        let engagementExpectation = expectation(description: "engagement events")
        engagementExpectation.expectedFulfillmentCount = 2
        recorder.onEngagement = {
            engagementExpectation.fulfill()
        }
        let appModel = makeAppModel(recorder: recorder)
        let historyItem = try XCTUnwrap(
            try appModel.historyModel.store.add(content: "private clipboard text", sourceBundleID: nil)
        )

        appModel.historyPopupModel.prepare(initialMode: .all)
        appModel.useHistoryItemFromMenu(historyItem)

        await fulfillment(of: [engagementExpectation], timeout: 1)
        XCTAssertEqual(recorder.engagementDates.count, 2)
    }

    func testSettingsFavoriteRemovalRecordsEngagement() async throws {
        let recorder = AppAnalyticsRecorderSpy()
        let appModel = makeAppModel(recorder: recorder)
        let historyItem = try XCTUnwrap(
            try appModel.historyModel.store.add(content: "private clipboard text", sourceBundleID: nil)
        )
        let favorite = try appModel.favoritesModel.store.addFavorite(for: historyItem)
        appModel.favoritesModel.refreshFromStore()
        appModel.favoritesModel.selectFavorite(favorite)

        appModel.favoritesModel.removeSelectedFavorite()

        for _ in 0 ..< 10 {
            guard recorder.engagementDates.isEmpty else {
                break
            }
            await Task.yield()
        }
        XCTAssertEqual(recorder.engagementDates.count, 1)
    }

    private func makeAppModel(recorder: AppAnalyticsRecorderSpy) -> AppModel {
        let testDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MacClipyTests-\(UUID().uuidString)", isDirectory: true)
        return AppModel(
            anonymousAnalyticsRecorder: recorder,
            historyModel: ClipboardHistoryModel(
                store: ClipboardStore(historyURL: testDirectory.appendingPathComponent("history.json"))
            ),
            favoritesModel: FavoritesModel(
                store: FavoriteStore(favoritesURL: testDirectory.appendingPathComponent("favorites.json"))
            ),
            appUpdater: AppUpdater(startingUpdater: false)
        )
    }
}

@MainActor
private final class AppAnalyticsRecorderSpy: AnonymousAnalyticsRecording {
    private(set) var launchDates: [Date] = []
    private(set) var runningDates: [Date] = []
    private(set) var engagementDates: [Date] = []
    private(set) var features: [AnalyticsFeature] = []
    var onRunning: (() -> Void)?
    var onEngagement: (() -> Void)?

    func recordLaunch(at date: Date) async {
        launchDates.append(date)
    }

    func recordRunning(at date: Date) async {
        runningDates.append(date)
        onRunning?()
    }

    func recordEngagement(at date: Date) async {
        engagementDates.append(date)
        onEngagement?()
    }

    func recordFeatureUsage(_ feature: AnalyticsFeature, at _: Date) {
        features.append(feature)
    }
}
