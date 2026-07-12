import Defaults

enum OnboardingState {
    static func shouldPresentAtLaunch(
        wasKnownInstallation: Bool = Defaults[.didMigrateLegacySettings]
    ) -> Bool {
        if !Defaults[.didEvaluateOnboardingEligibility] {
            // 移行前の状態を一度だけ保存し、アップデートした既存ユーザーには自動表示しない。
            Defaults[.isOnboardingPending] = !wasKnownInstallation
            Defaults[.didEvaluateOnboardingEligibility] = true
        }

        return Defaults[.isOnboardingPending]
    }

    static func markCompleted() {
        Defaults[.isOnboardingPending] = false
    }
}

extension Defaults.Keys {
    static let didEvaluateOnboardingEligibility = Key<Bool>(
        "didEvaluateOnboardingEligibility",
        default: false
    )
    static let isOnboardingPending = Key<Bool>("isOnboardingPending", default: false)
}
