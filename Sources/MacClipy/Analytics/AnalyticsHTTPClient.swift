import Foundation

struct AnalyticsRuntimeConfiguration: Equatable {
    private static let officialEndpoint = "https://techguide.jp/api/macclipy/analytics"

    let allowsCollection: Bool
    let endpoint: URL?

    init(bundle: Bundle = .main) {
        self.init(infoDictionary: bundle.infoDictionary ?? [:])
    }

    init(infoDictionary: [String: Any]) {
        guard infoDictionary["MacClipyAnalyticsEnabled"] as? Bool == true,
              let endpointValue = infoDictionary["MacClipyAnalyticsEndpoint"] as? String,
              let endpoint = URL(string: endpointValue),
              endpoint.absoluteString == Self.officialEndpoint
        else {
            allowsCollection = false
            endpoint = nil
            return
        }

        allowsCollection = true
        self.endpoint = endpoint
    }
}

@MainActor
final class AnalyticsHTTPSender: AnalyticsEventSending {
    typealias RequestExecutor = @MainActor (URLRequest) async throws -> (Data, URLResponse)

    private let endpoint: URL
    private let executeRequest: RequestExecutor

    init(endpoint: URL, executeRequest: @escaping RequestExecutor) {
        self.endpoint = endpoint
        self.executeRequest = executeRequest
    }

    convenience init(endpoint: URL) {
        self.init(endpoint: endpoint) { request in
            try await URLSession.shared.data(for: request)
        }
    }

    func send(_ payload: AnalyticsEventPayload) async throws {
        var request = URLRequest(url: endpoint, timeoutInterval: 3)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try AnalyticsEventPayload.encoder.encode(payload)

        let (_, response) = try await executeRequest(request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200 ..< 300).contains(httpResponse.statusCode)
        else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw AnalyticsSendingError.unsuccessfulStatusCode(statusCode)
        }
    }
}

@MainActor
enum AnonymousAnalyticsFactory {
    static func make(
        settingsModel: SettingsModel,
        bundle: Bundle = .main
    ) -> AnonymousAnalyticsRecorder? {
        let configuration = AnalyticsRuntimeConfiguration(bundle: bundle)
        guard configuration.allowsCollection, let endpoint = configuration.endpoint else {
            return nil
        }

        return AnonymousAnalyticsRecorder(
            installationIdentifierProvider: InstallationIdentifierProvider(
                store: KeychainInstallationIdentifierStore()
            ),
            eventStateStore: DefaultsAnalyticsEventStateStore(),
            sender: AnalyticsHTTPSender(endpoint: endpoint),
            metadata: AnalyticsAppMetadata.current(bundle: bundle),
            isEnabled: { [weak settingsModel] in
                settingsModel?.isAnonymousAnalyticsEnabled == true
            },
            runtimeAllowsCollection: true
        )
    }
}
