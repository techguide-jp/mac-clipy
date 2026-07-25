import AppKit
@testable import MacClipy
import XCTest

@MainActor
final class PasteDestinationTests: XCTestCase {
    func testTracksOnlyActiveRegularApplications() {
        let currentProcessIdentifier = ProcessInfo.processInfo.processIdentifier

        XCTAssertTrue(AppModel.shouldRememberPasteDestination(
            processIdentifier: currentProcessIdentifier + 1,
            activationPolicy: .regular,
            isTerminated: false,
            currentProcessIdentifier: currentProcessIdentifier
        ))
        XCTAssertFalse(AppModel.shouldRememberPasteDestination(
            processIdentifier: currentProcessIdentifier,
            activationPolicy: .regular,
            isTerminated: false,
            currentProcessIdentifier: currentProcessIdentifier
        ))
        XCTAssertFalse(AppModel.shouldRememberPasteDestination(
            processIdentifier: currentProcessIdentifier + 1,
            activationPolicy: .accessory,
            isTerminated: false,
            currentProcessIdentifier: currentProcessIdentifier
        ))
        XCTAssertFalse(AppModel.shouldRememberPasteDestination(
            processIdentifier: currentProcessIdentifier + 1,
            activationPolicy: .regular,
            isTerminated: true,
            currentProcessIdentifier: currentProcessIdentifier
        ))
    }

    func testReportsMissingDestination() {
        XCTAssertEqual(
            PasteController.pasteIntoPreviousApplication(nil),
            .destinationUnavailable
        )
    }

    func testReportsPermissionAndActivationFailures() {
        XCTAssertEqual(
            PasteController.resolvePasteAttempt(
                destinationAvailable: true,
                accessibilityTrusted: { false },
                activate: {
                    XCTFail("Activation must not run without permission")
                    return false
                }
            ),
            .permissionRequired
        )
        XCTAssertEqual(
            PasteController.resolvePasteAttempt(
                destinationAvailable: true,
                accessibilityTrusted: { true },
                activate: { false }
            ),
            .activationFailed
        )
        XCTAssertEqual(
            PasteController.resolvePasteAttempt(
                destinationAvailable: true,
                accessibilityTrusted: { true },
                activate: { true }
            ),
            .scheduled
        )
    }

    func testPermissionRequestOpensAccessibilitySettingsWhenPermissionIsStillMissing() {
        var openedURL: URL?

        XCTAssertFalse(
            PasteController.requestAccessibilityPermission(
                prompt: { false },
                openSettings: { url in
                    openedURL = url
                    return true
                }
            )
        )
        XCTAssertEqual(
            openedURL?.absoluteString,
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        )
    }

    func testPermissionRequestDoesNotOpenSettingsWhenPermissionIsAlreadyGranted() {
        var didOpenSettings = false

        XCTAssertTrue(
            PasteController.requestAccessibilityPermission(
                prompt: { true },
                openSettings: { _ in
                    didOpenSettings = true
                    return true
                }
            )
        )
        XCTAssertFalse(didOpenSettings)
    }
}
