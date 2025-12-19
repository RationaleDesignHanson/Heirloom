import XCTest
@testable import Heirloom

@MainActor
final class PrivacyConsentServiceTests: XCTestCase {

    var service: PrivacyConsentService!

    override func setUp() async throws {
        try await super.setUp()
        service = PrivacyConsentService.shared
        // Reset to default state
        service.clearAllConsents()
    }

    override func tearDown() async throws {
        service.clearAllConsents()
        try await super.tearDown()
    }

    // MARK: - Initial State Tests

    func test_initialState_noConsents() {
        XCTAssertFalse(service.hasSharingConsent)
        XCTAssertFalse(service.hasAnalyticsConsent)
        XCTAssertFalse(service.hasShownConsentDialog)
    }

    // MARK: - Sharing Consent Tests

    func test_grantSharingConsent_updatesState() {
        service.grantSharingConsent()

        XCTAssertTrue(service.hasSharingConsent)
        XCTAssertFalse(service.hasAnalyticsConsent)
        XCTAssertTrue(service.hasShownConsentDialog)
    }

    func test_revokeSharingConsent_updatesState() {
        service.grantSharingConsent()
        XCTAssertTrue(service.hasSharingConsent)

        service.revokeSharingConsent()
        XCTAssertFalse(service.hasSharingConsent)
    }

    func test_sharingConsent_persistsAcrossInstances() {
        service.grantSharingConsent()
        XCTAssertTrue(service.hasSharingConsent)

        // Create new instance (simulate app restart)
        let newService = PrivacyConsentService()
        XCTAssertTrue(newService.hasSharingConsent)
    }

    // MARK: - Analytics Consent Tests

    func test_grantAnalyticsConsent_updatesState() {
        service.grantAnalyticsConsent()

        XCTAssertTrue(service.hasAnalyticsConsent)
        XCTAssertFalse(service.hasSharingConsent)
        XCTAssertTrue(service.hasShownConsentDialog)
    }

    func test_revokeAnalyticsConsent_updatesState() {
        service.grantAnalyticsConsent()
        XCTAssertTrue(service.hasAnalyticsConsent)

        service.revokeAnalyticsConsent()
        XCTAssertFalse(service.hasAnalyticsConsent)
    }

    func test_analyticsConsent_persistsAcrossInstances() {
        service.grantAnalyticsConsent()
        XCTAssertTrue(service.hasAnalyticsConsent)

        // Create new instance (simulate app restart)
        let newService = PrivacyConsentService()
        XCTAssertTrue(newService.hasAnalyticsConsent)
    }

    // MARK: - Both Consents Tests

    func test_grantBothConsents_updatesState() {
        service.grantSharingConsent()
        service.grantAnalyticsConsent()

        XCTAssertTrue(service.hasSharingConsent)
        XCTAssertTrue(service.hasAnalyticsConsent)
        XCTAssertTrue(service.hasShownConsentDialog)
    }

    func test_revokeAllConsents_clearsState() {
        service.grantSharingConsent()
        service.grantAnalyticsConsent()

        service.clearAllConsents()

        XCTAssertFalse(service.hasSharingConsent)
        XCTAssertFalse(service.hasAnalyticsConsent)
        XCTAssertFalse(service.hasShownConsentDialog)
    }

    // MARK: - Consent Dialog Tests

    func test_needsToShowConsentDialog_initialState() {
        XCTAssertTrue(service.needsToShowConsentDialog)
    }

    func test_needsToShowConsentDialog_afterShowing() {
        service.grantSharingConsent()

        XCTAssertFalse(service.needsToShowConsentDialog)
    }

    func test_needsToShowConsentDialog_afterDeclining() {
        service.markConsentDialogShown()

        XCTAssertFalse(service.needsToShowConsentDialog)
    }

    // MARK: - Independent Consent Tests

    func test_sharingConsent_independentOfAnalytics() {
        service.grantSharingConsent()

        XCTAssertTrue(service.hasSharingConsent)
        XCTAssertFalse(service.hasAnalyticsConsent)
    }

    func test_analyticsConsent_independentOfSharing() {
        service.grantAnalyticsConsent()

        XCTAssertTrue(service.hasAnalyticsConsent)
        XCTAssertFalse(service.hasSharingConsent)
    }

    func test_revokeSharingConsent_doesNotAffectAnalytics() {
        service.grantSharingConsent()
        service.grantAnalyticsConsent()

        service.revokeSharingConsent()

        XCTAssertFalse(service.hasSharingConsent)
        XCTAssertTrue(service.hasAnalyticsConsent)
    }

    func test_revokeAnalyticsConsent_doesNotAffectSharing() {
        service.grantSharingConsent()
        service.grantAnalyticsConsent()

        service.revokeAnalyticsConsent()

        XCTAssertTrue(service.hasSharingConsent)
        XCTAssertFalse(service.hasAnalyticsConsent)
    }

    // MARK: - GDPR Compliance Tests

    func test_canExportConsentData() {
        service.grantSharingConsent()
        service.grantAnalyticsConsent()

        let exportData = [
            "sharing_consent": service.hasSharingConsent,
            "analytics_consent": service.hasAnalyticsConsent
        ]

        XCTAssertTrue(exportData["sharing_consent"] as! Bool)
        XCTAssertTrue(exportData["analytics_consent"] as! Bool)
    }

    func test_canDeleteAllConsentData() {
        service.grantSharingConsent()
        service.grantAnalyticsConsent()

        service.clearAllConsents()

        XCTAssertFalse(service.hasSharingConsent)
        XCTAssertFalse(service.hasAnalyticsConsent)
    }

    // MARK: - Feature Gate Tests

    func test_canShareRecipes_requiresSharingConsent() {
        XCTAssertFalse(service.hasSharingConsent)

        service.grantSharingConsent()

        XCTAssertTrue(service.hasSharingConsent)
    }

    func test_canTrackAnalytics_requiresAnalyticsConsent() {
        XCTAssertFalse(service.hasAnalyticsConsent)

        service.grantAnalyticsConsent()

        XCTAssertTrue(service.hasAnalyticsConsent)
    }
}
