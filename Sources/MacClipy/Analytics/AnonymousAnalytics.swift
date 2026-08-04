import Foundation

private enum AnalyticsRecorderError: Error {
    case collectionDisabled
}

@MainActor
protocol AnonymousAnalyticsRecording: AnyObject {
    func recordLaunch(at date: Date) async
    func recordRunning(at date: Date) async
    func recordEngagement(at date: Date) async
    func recordFeatureUsage(_ feature: AnalyticsFeature, at date: Date)
}

@MainActor
final class AnonymousAnalyticsRecorder: AnonymousAnalyticsRecording {
    private struct InFlightEvent: Hashable {
        let eventName: AnalyticsEventName
        let day: String
        let feature: AnalyticsFeature?
    }

    private let installationIdentifierProvider: any InstallationIdentifierProviding
    private let eventStateStore: any AnalyticsEventStateStoring
    private let sender: any AnalyticsEventSending
    private let metadata: AnalyticsAppMetadata
    private let calendar: Calendar
    private let isEnabled: @MainActor () -> Bool
    private let runtimeAllowsCollection: Bool
    private var inFlightEvents = Set<InFlightEvent>()
    private var isFlushingFeatureUsage = false

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
        guard let installationID = activeInstallationIdentifier() else {
            return
        }

        let day = dayIdentifier(for: date)
        migrateLegacyDailyActiveState()
        await sendInstallIfNeeded(installationID: installationID, day: day, at: date)
        await sendDailyEventIfNeeded(.dailyRunning, installationID: installationID, day: day, at: date)
        await flushCompletedFeatureUsage(installationID: installationID, before: day, at: date)
    }

    func recordRunning(at date: Date = Date()) async {
        guard let installationID = activeInstallationIdentifier() else {
            return
        }

        let day = dayIdentifier(for: date)
        migrateLegacyDailyActiveState()
        await sendDailyEventIfNeeded(.dailyRunning, installationID: installationID, day: day, at: date)
        await flushCompletedFeatureUsage(installationID: installationID, before: day, at: date)
    }

    func recordEngagement(at date: Date = Date()) async {
        guard let installationID = activeInstallationIdentifier() else {
            return
        }

        let day = dayIdentifier(for: date)
        await sendDailyEventIfNeeded(.dailyEngaged, installationID: installationID, day: day, at: date)
    }

    func recordFeatureUsage(_ feature: AnalyticsFeature, at date: Date = Date()) {
        guard collectionIsAllowed else {
            return
        }

        var state = eventStateStore.featureUsageState
        state.increment(feature, on: dayIdentifier(for: date))
        eventStateStore.featureUsageState = state
    }

    private var collectionIsAllowed: Bool {
        runtimeAllowsCollection && isEnabled() && !Task.isCancelled
    }

    private func activeInstallationIdentifier() -> UUID? {
        guard collectionIsAllowed else {
            return nil
        }
        return try? installationIdentifierProvider.installationIdentifier()
    }

    private func migrateLegacyDailyActiveState() {
        guard eventStateStore.lastDailyRunningDay == nil,
              let legacyDay = eventStateStore.lastDailyActiveDay
        else {
            return
        }

        eventStateStore.lastDailyRunningDay = legacyDay
    }

    private func sendInstallIfNeeded(installationID: UUID, day: String, at date: Date) async {
        let inFlightEvent = InFlightEvent(eventName: .install, day: day, feature: nil)
        guard !eventStateStore.didSendInstall, inFlightEvents.insert(inFlightEvent).inserted else {
            return
        }
        defer { inFlightEvents.remove(inFlightEvent) }

        do {
            try await sendPayload(eventName: .install, installationID: installationID, at: date)
            eventStateStore.didSendInstall = true
        } catch {}
    }

    private func sendDailyEventIfNeeded(
        _ eventName: AnalyticsEventName,
        installationID: UUID,
        day: String,
        at date: Date
    ) async {
        let inFlightEvent = InFlightEvent(eventName: eventName, day: day, feature: nil)
        guard lastSentDay(for: eventName) != day,
              inFlightEvents.insert(inFlightEvent).inserted
        else {
            return
        }
        defer { inFlightEvents.remove(inFlightEvent) }

        do {
            try await sendPayload(eventName: eventName, installationID: installationID, at: date)
            setLastSentDay(day, for: eventName)
        } catch {}
    }

    private func flushCompletedFeatureUsage(installationID: UUID, before day: String, at date: Date) async {
        guard !isFlushingFeatureUsage else {
            return
        }
        isFlushingFeatureUsage = true
        defer { isFlushingFeatureUsage = false }

        let pendingEntries = eventStateStore.featureUsageState.entries(before: day)
        for entry in pendingEntries {
            guard collectionIsAllowed else {
                return
            }

            let inFlightEvent = InFlightEvent(eventName: .featureUsage, day: entry.day, feature: entry.feature)
            guard inFlightEvents.insert(inFlightEvent).inserted else {
                continue
            }

            do {
                try await sendPayload(
                    eventName: .featureUsage,
                    installationID: installationID,
                    at: date,
                    feature: entry.feature,
                    usageCount: entry.count,
                    usageDate: entry.day
                )
                var state = eventStateStore.featureUsageState
                state.removeSentCount(entry.count, for: entry.feature, on: entry.day)
                eventStateStore.featureUsageState = state
            } catch {}

            inFlightEvents.remove(inFlightEvent)
        }
    }

    private func sendPayload(
        eventName: AnalyticsEventName,
        installationID: UUID,
        at date: Date,
        feature: AnalyticsFeature? = nil,
        usageCount: Int? = nil,
        usageDate: String? = nil
    ) async throws {
        guard collectionIsAllowed else {
            throw AnalyticsRecorderError.collectionDisabled
        }

        try await sender.send(
            AnalyticsEventPayload(
                schemaVersion: 1,
                installationID: installationID,
                eventName: eventName,
                appVersion: metadata.appVersion,
                buildNumber: metadata.buildNumber,
                macOSMajorVersion: metadata.macOSMajorVersion,
                architecture: metadata.architecture,
                occurredAt: date,
                feature: feature,
                usageCount: usageCount,
                usageDate: usageDate
            )
        )
    }

    private func lastSentDay(for eventName: AnalyticsEventName) -> String? {
        switch eventName {
        case .dailyRunning:
            eventStateStore.lastDailyRunningDay
        case .dailyEngaged:
            eventStateStore.lastDailyEngagedDay
        case .install, .featureUsage:
            nil
        }
    }

    private func setLastSentDay(_ day: String, for eventName: AnalyticsEventName) {
        switch eventName {
        case .dailyRunning:
            eventStateStore.lastDailyRunningDay = day
        case .dailyEngaged:
            eventStateStore.lastDailyEngagedDay = day
        case .install, .featureUsage:
            break
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
