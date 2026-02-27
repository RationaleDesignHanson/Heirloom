import SnapshotTesting
import SwiftUI
import XCTest
@testable import Heirloom

@MainActor
final class OnboardingWelcomeSnapshotTests: SnapshotTestCase {

    // MARK: - Welcome Screen

    func testWelcome_defaultState() {
        let view = OnboardingWelcomeScreen(
            onContinue: {},
            onRestoreFromBackup: {}
        )
        .environment(\.firebaseAuth, MockSnapshotAuth.signedOut())

        assertBothDevices(view, named: "welcome_default")
    }
}

@MainActor
final class OnboardingSubscriptionSnapshotTests: SnapshotTestCase {

    // MARK: - Subscription Screen

    func testSubscription_defaultState() throws {
        let logger: LoggingService = HeirloomLogger()
        let analytics = AnalyticsService()
        let storeManager = StoreManager(logger: logger, analytics: analytics)
        let subscriptionManager = SubscriptionManager(
            storeManager: storeManager, logger: logger, analytics: analytics
        )
        let paywallManager = PaywallManager(
            subscriptionManager: subscriptionManager, logger: logger, analytics: analytics
        )

        let view = OnboardingSubscriptionScreen(onStartTrial: {})
            .environment(subscriptionManager)
            .environment(storeManager)
            .environment(paywallManager)
            .environment(\.firebaseAuth, MockSnapshotAuth.signedOut())

        assertBothDevices(view, named: "subscription_default")
    }
}
