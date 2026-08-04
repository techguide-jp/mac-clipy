import Foundation
@testable import MacClipy
import XCTest

@MainActor
final class AutomaticUpdateInstallerTests: XCTestCase {
    func testInstallImmediatelyInvokesHandlerOnceAndClaimsUpdate() {
        let installer = AutomaticUpdateInstaller()
        var invocationCount = 0

        let handled = installer.installImmediately {
            invocationCount += 1
        }

        XCTAssertTrue(handled)
        XCTAssertEqual(invocationCount, 1)
    }
}
