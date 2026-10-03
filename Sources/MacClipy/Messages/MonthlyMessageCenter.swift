import Defaults
import Foundation
import Observation

extension Defaults.Keys {
    static let monthlyMessagesEnabled = Key<Bool>("monthlyMessagesEnabled", default: true)
    static let monthlyMessageShownMonth = Key<String>("monthlyMessageShownMonth", default: "")
}

@MainActor
@Observable
final class MonthlyMessageCenter {
    typealias Fetch = @MainActor () async throws -> MonthlyMessage
    var message: MonthlyMessage?
    var isLoading = false
    var errorMessage = ""
    var isAutomaticMessagesEnabled: Bool {
        didSet { Defaults[.monthlyMessagesEnabled] = isAutomaticMessagesEnabled }
    }

    let allowsFetching: Bool
    @ObservationIgnored var onAutomaticPresentation: (() -> Bool)?
    @ObservationIgnored private let fetch: Fetch
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private var lastSuccessfulFetch: Date?
    @ObservationIgnored private var lastAttempt: Date?
    @ObservationIgnored private var requestedMonth = ""

    init(
        allowsFetching: Bool = Bundle.main.object(forInfoDictionaryKey: "MacClipyMonthlyMessagesEnabled") as? Bool == true,
        fetch: @escaping Fetch = MonthlyMessageHTTPClient.fetch,
        now: @escaping () -> Date = Date.init
    ) {
        self.allowsFetching = allowsFetching
        self.fetch = fetch
        self.now = now
        isAutomaticMessagesEnabled = Defaults[.monthlyMessagesEnabled]
    }

    var hasUnreadMessage: Bool {
        guard let message, message.month == MonthlyMessageCalendar.month(at: now()) else { return false }
        return Defaults[.monthlyMessageShownMonth] != message.month
    }

    func refresh(automatically: Bool = true, force: Bool = false) async {
        guard allowsFetching, !isLoading else { return }
        guard !automatically || isAutomaticMessagesEnabled else { return }
        let date = now()
        let month = MonthlyMessageCalendar.month(at: date)
        if requestedMonth != month {
            requestedMonth = month
            message = nil
            lastSuccessfulFetch = nil
            lastAttempt = nil
        }
        if !force, let lastSuccessfulFetch, date.timeIntervalSince(lastSuccessfulFetch) < 6 * 3600 {
            if automatically {
                presentAutomaticallyIfNeeded()
            }
            return
        }
        if !force, let lastAttempt, date.timeIntervalSince(lastAttempt) < 60 {
            return
        }
        lastAttempt = date
        isLoading = true
        errorMessage = ""
        defer { isLoading = false }
        do {
            let received = try await fetch()
            // 取得途中の月替わりや不正なURLでは表示済み状態を進めない。
            guard received.isValid(for: month), MonthlyMessageCalendar.month(at: now()) == month else {
                throw URLError(.badServerResponse)
            }
            message = received
            lastSuccessfulFetch = date
            if automatically {
                presentAutomaticallyIfNeeded()
            }
        } catch {
            errorMessage = L10n.tr("monthly.fetchFailed")
        }
    }

    func markPresented() {
        guard let message, message.month == MonthlyMessageCalendar.month(at: now()) else { return }
        Defaults[.monthlyMessageShownMonth] = message.month
    }

    private func presentAutomaticallyIfNeeded() {
        guard isAutomaticMessagesEnabled, hasUnreadMessage, onAutomaticPresentation?() == true else { return }
        markPresented()
    }
}
