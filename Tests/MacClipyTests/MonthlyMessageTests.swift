import Defaults
@testable import MacClipy
import XCTest

final class MonthlyMessageTests: XCTestCase {
    override func setUp() {
        super.setUp()
        Defaults.Keys.monthlyMessageShownMonth.reset()
        Defaults.Keys.monthlyMessagesEnabled.reset()
    }

    override func tearDown() {
        Defaults.Keys.monthlyMessageShownMonth.reset()
        Defaults.Keys.monthlyMessagesEnabled.reset()
        super.tearDown()
    }

    func testMonthBoundaryUsesJapanCalendar() throws {
        let formatter = ISO8601DateFormatter()
        let before = try XCTUnwrap(formatter.date(from: "2026-09-30T14:59:59Z"))
        let after = try XCTUnwrap(formatter.date(from: "2026-09-30T15:00:00Z"))
        XCTAssertEqual(MonthlyMessageCalendar.month(at: before), "2026-09")
        XCTAssertEqual(MonthlyMessageCalendar.month(at: after), "2026-10")
    }

    @MainActor
    func testOnlyOneAutomaticPresentationAcrossRestarts() async throws {
        let message = try fixture()
        var presentations = 0
        let first = MonthlyMessageCenter(allowsFetching: true, fetch: { message })
        first.onAutomaticPresentation = { presentations += 1
            return true
        }
        await first.refresh()
        await first.refresh()
        let second = MonthlyMessageCenter(allowsFetching: true, fetch: { message })
        second.onAutomaticPresentation = { presentations += 1
            return true
        }
        await second.refresh()
        XCTAssertEqual(presentations, 1)
        XCTAssertFalse(second.hasUnreadMessage)
    }

    @MainActor
    func testFailedFetchDoesNotMarkMonthAndCanRetry() async throws {
        let message = try fixture()
        var attempts = 0
        let center = MonthlyMessageCenter(allowsFetching: true, fetch: {
            attempts += 1
            if attempts == 1 { throw URLError(.notConnectedToInternet) }
            return message
        })
        center.onAutomaticPresentation = { true }
        await center.refresh()
        XCTAssertNil(center.message)
        XCTAssertFalse(center.errorMessage.isEmpty)
        XCTAssertEqual(Defaults[.monthlyMessageShownMonth], "")
        await center.refresh()
        XCTAssertEqual(attempts, 1)
        await center.refresh(force: true)
        XCTAssertEqual(Defaults[.monthlyMessageShownMonth], message.month)
    }

    @MainActor
    func testBusyUIKeepsUnreadUntilPresentationSucceeds() async throws {
        let message = try fixture()
        let center = MonthlyMessageCenter(allowsFetching: true, fetch: { message })
        center.onAutomaticPresentation = { false }
        await center.refresh()
        XCTAssertTrue(center.hasUnreadMessage)
        center.onAutomaticPresentation = { true }
        await center.refresh()
        XCTAssertFalse(center.hasUnreadMessage)
    }

    @MainActor
    func testOptOutStillAllowsManualRetrieval() async throws {
        let message = try fixture()
        let center = MonthlyMessageCenter(allowsFetching: true, fetch: { message })
        center.isAutomaticMessagesEnabled = false
        center.onAutomaticPresentation = { XCTFail("Automatic presentation while disabled")
            return true
        }
        await center.refresh(automatically: false)
        XCTAssertEqual(center.message, message)
        XCTAssertTrue(center.hasUnreadMessage)
        center.markPresented()
        XCTAssertFalse(center.hasUnreadMessage)
    }

    @MainActor
    func testDevelopmentBuildDoesNotFetch() async {
        let center = MonthlyMessageCenter(allowsFetching: false, fetch: {
            XCTFail("Unexpected network request")
            throw URLError(.badURL)
        })
        await center.refresh(force: true)
        XCTAssertNil(center.message)
    }

    func testSurveyURLAndMonthAreRestricted() throws {
        let month = MonthlyMessageCalendar.month(at: Date())
        for value in [
            "https://example.com/macclipy/survey/\(month)/",
            "http://techguide.jp/macclipy/survey/\(month)/",
            "https://techguide.jp/macclipy/survey/\(month)/?redirect=example.com"
        ] {
            let url = try XCTUnwrap(URL(string: value))
            XCTAssertFalse(MonthlyMessage(month: month, title: "Monthly", message: "Hello", surveyURL: url).isValid(for: month))
        }
        XCTAssertFalse(try fixture().isValid(for: "2025-01"))
    }

    @MainActor
    func testFetchCrossingMonthBoundaryIsDiscarded() async throws {
        let date = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-09-30T14:59:59Z"))
        let url = try XCTUnwrap(URL(string: "https://techguide.jp/macclipy/survey/2026-09/"))
        var current = date
        let center = MonthlyMessageCenter(allowsFetching: true, fetch: {
            current = date.addingTimeInterval(2)
            return MonthlyMessage(month: "2026-09", title: "Monthly", message: "Hello", surveyURL: url)
        }, now: { current })
        center.onAutomaticPresentation = { XCTFail("Stale message presented")
            return true
        }
        await center.refresh()
        XCTAssertNil(center.message)
        XCTAssertEqual(Defaults[.monthlyMessageShownMonth], "")
    }

    private func fixture() throws -> MonthlyMessage {
        let month = MonthlyMessageCalendar.month(at: Date())
        let url = try XCTUnwrap(URL(string: "https://techguide.jp/macclipy/survey/\(month)/"))
        return MonthlyMessage(month: month, title: "Monthly", message: "Hello", surveyURL: url)
    }
}
