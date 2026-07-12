import Defaults
@testable import MacClipy
import XCTest

final class OnboardingStateTests: XCTestCase {
    override func setUp() {
        super.setUp()
        resetDefaults()
    }

    override func tearDown() {
        resetDefaults()
        super.tearDown()
    }

    func testNewInstallationPresentsOnboardingUntilCompleted() {
        XCTAssertTrue(OnboardingState.shouldPresentAtLaunch(wasKnownInstallation: false))

        XCTAssertTrue(OnboardingState.shouldPresentAtLaunch(wasKnownInstallation: true))

        OnboardingState.markCompleted()

        XCTAssertFalse(OnboardingState.shouldPresentAtLaunch(wasKnownInstallation: true))
    }

    func testExistingInstallationDoesNotPresentOnboarding() {
        XCTAssertFalse(OnboardingState.shouldPresentAtLaunch(wasKnownInstallation: true))
        XCTAssertTrue(Defaults[.didEvaluateOnboardingEligibility])
        XCTAssertFalse(Defaults[.isOnboardingPending])
    }

    func testEligibilityIsOnlyEvaluatedOnce() {
        XCTAssertFalse(OnboardingState.shouldPresentAtLaunch(wasKnownInstallation: true))

        XCTAssertFalse(OnboardingState.shouldPresentAtLaunch(wasKnownInstallation: false))
    }

    private func resetDefaults() {
        Defaults.Keys.didEvaluateOnboardingEligibility.reset()
        Defaults.Keys.isOnboardingPending.reset()
    }
}
