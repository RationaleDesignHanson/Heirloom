import SnapshotTesting
import SwiftUI
import XCTest
@testable import Heirloom

@MainActor
final class FirebaseSignInSnapshotTests: SnapshotTestCase {

    // MARK: - Default State (OAuth buttons)

    func testSignIn_defaultState() {
        let view = FirebaseSignInView()
            .environment(\.firebaseAuth, MockSnapshotAuth.signedOut())

        assertBothDevices(view, named: "signIn_default")
    }

    // MARK: - Authenticating State (spinner)

    func testSignIn_authenticating() {
        let auth = MockSnapshotAuth()
        auth.isAuthenticating = true

        let view = FirebaseSignInView()
            .environment(\.firebaseAuth, auth)

        assertBothDevices(view, named: "signIn_authenticating")
    }

    // MARK: - Error State

    func testSignIn_error() {
        let auth = MockSnapshotAuth()
        auth.authError = NSError(
            domain: "auth",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Sign in failed. Please try again."]
        )

        let view = FirebaseSignInView()
            .environment(\.firebaseAuth, auth)

        assertBothDevices(view, named: "signIn_error")
    }
}
