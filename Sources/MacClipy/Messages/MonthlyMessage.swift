import Foundation

struct MonthlyMessage: Codable, Equatable {
    let month: String
    let title: String
    let message: String
    let surveyURL: URL

    func isValid(for month: String) -> Bool {
        self.month == month && !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            title.count <= 120 && !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            message.count <= 6000 && surveyURL.absoluteString == "https://techguide.jp/macclipy/survey/\(month)/"
    }
}

enum MonthlyMessageCalendar {
    static func month(at date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? TimeZone(secondsFromGMT: 0) ?? .current
        let components = calendar.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", components.year ?? 0, components.month ?? 0)
    }
}

@MainActor
enum MonthlyMessageHTTPClient {
    static func fetch() async throws -> MonthlyMessage {
        guard let url = URL(string: "https://techguide.jp/api/macclipy/monthly/") else {
            throw URLError(.badURL)
        }
        // 公式配信先以外に遷移させず、通信失敗を「当月のカスタムなし」と扱わない。
        let session = AnalyticsURLSessionFactory.make()
        defer { session.invalidateAndCancel() }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse, response.statusCode == 200, data.count <= 32000 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(MonthlyMessage.self, from: data)
    }
}
