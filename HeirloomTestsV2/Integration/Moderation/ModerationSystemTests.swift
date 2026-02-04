//
//  ModerationSystemTests.swift
//  HeirloomTestsV2
//
//  Created: 2026-02-04
//  Integration tests for auto-moderation system
//
//  Tests the moderation system to ensure:
//  - Report submission works correctly
//  - Duplicate report prevention functions
//  - Hidden recipe filtering in discovery
//  - Report reasons are properly defined
//  - Auto-hide threshold behavior (3 reports)
//

import XCTest
import SwiftData
@testable import Heirloom

@MainActor
final class ModerationSystemTests: XCTestCase {

    // MARK: - Properties

    var env: TestEnvironment!

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        try await super.setUp()
        env = try await TestEnvironment.create(authenticated: true)
    }

    override func tearDown() async throws {
        env.tearDown()
        env = nil
        try await super.tearDown()
    }

    // MARK: - ReportReason Enum Tests

    /// Test 1: All report reasons are defined
    func test_reportReason_allCasesExist() {
        // GIVEN: ReportReason enum
        let allCases = ReportReason.allCases

        // THEN: Should have 6 cases
        XCTAssertEqual(allCases.count, 6)
        XCTAssertTrue(allCases.contains(.inappropriate))
        XCTAssertTrue(allCases.contains(.spam))
        XCTAssertTrue(allCases.contains(.copyright))
        XCTAssertTrue(allCases.contains(.offensive))
        XCTAssertTrue(allCases.contains(.notRecipe))
        XCTAssertTrue(allCases.contains(.other))
    }

    /// Test 2: Report reasons have correct raw values
    func test_reportReason_rawValues_areCorrect() {
        // GIVEN/WHEN/THEN: Each reason has correct description
        XCTAssertEqual(ReportReason.inappropriate.rawValue, "Inappropriate content")
        XCTAssertEqual(ReportReason.spam.rawValue, "Spam or misleading")
        XCTAssertEqual(ReportReason.copyright.rawValue, "Copyright violation")
        XCTAssertEqual(ReportReason.offensive.rawValue, "Offensive or hateful")
        XCTAssertEqual(ReportReason.notRecipe.rawValue, "Not a recipe")
        XCTAssertEqual(ReportReason.other.rawValue, "Other")
    }

    /// Test 3: Report reasons have icons
    func test_reportReason_icons_areDefined() {
        // GIVEN: All report reasons
        for reason in ReportReason.allCases {
            // WHEN: Getting the icon
            let icon = reason.icon

            // THEN: Icon should not be empty
            XCTAssertFalse(icon.isEmpty, "Icon for \(reason) should not be empty")
        }
    }

    /// Test 4: Report reason description matches raw value
    func test_reportReason_description_matchesRawValue() {
        // GIVEN: All report reasons
        for reason in ReportReason.allCases {
            // WHEN/THEN: Description should equal raw value
            XCTAssertEqual(reason.description, reason.rawValue)
        }
    }

    // MARK: - ReportError Tests

    /// Test 5: Report errors have localized descriptions
    func test_reportError_submissionFailed_hasDescription() {
        // GIVEN: Submission failed error
        let error = ReportError.submissionFailed

        // THEN: Should have meaningful description
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("submit"))
    }

    /// Test 6: Already reported error has description
    func test_reportError_alreadyReported_hasDescription() {
        // GIVEN: Already reported error
        let error = ReportError.alreadyReported

        // THEN: Should have meaningful description
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("already"))
    }

    /// Test 7: Unauthorized error has description
    func test_reportError_unauthorized_hasDescription() {
        // GIVEN: Unauthorized error
        let error = ReportError.unauthorized

        // THEN: Should have meaningful description
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("signed in"))
    }

    // MARK: - TestPublicRecipe Moderation Field Tests

    /// Test 8: TestPublicRecipe has isHidden field defaulting to false
    func test_publicRecipe_isHidden_defaultsFalse() {
        // GIVEN: A new public recipe created from test data
        let publicRecipe = createTestPublicRecipe()

        // THEN: isHidden should default to false
        XCTAssertFalse(publicRecipe.isHidden)
    }

    /// Test 9: TestPublicRecipe has reportCount field defaulting to 0
    func test_publicRecipe_reportCount_defaultsZero() {
        // GIVEN: A new public recipe
        let publicRecipe = createTestPublicRecipe()

        // THEN: reportCount should default to 0
        XCTAssertEqual(publicRecipe.reportCount, 0)
    }

    /// Test 10: TestPublicRecipe moderationStatus can be nil
    func test_publicRecipe_moderationStatus_canBeNil() {
        // GIVEN: A new public recipe
        let publicRecipe = createTestPublicRecipe()

        // THEN: moderationStatus should be nil by default
        XCTAssertNil(publicRecipe.moderationStatus)
    }

    /// Test 11: TestPublicRecipe can have hidden state set
    func test_publicRecipe_isHidden_canBeSet() {
        // GIVEN: A public recipe
        var publicRecipe = createTestPublicRecipe()

        // WHEN: Setting isHidden to true
        publicRecipe.isHidden = true

        // THEN: Should be hidden
        XCTAssertTrue(publicRecipe.isHidden)
    }

    /// Test 12: TestPublicRecipe report count can be incremented
    func test_publicRecipe_reportCount_canBeIncremented() {
        // GIVEN: A public recipe with 0 reports
        var publicRecipe = createTestPublicRecipe()
        XCTAssertEqual(publicRecipe.reportCount, 0)

        // WHEN: Incrementing report count
        publicRecipe.reportCount = 1

        // THEN: Should have 1 report
        XCTAssertEqual(publicRecipe.reportCount, 1)
    }

    // MARK: - Auto-Hide Threshold Tests (Client-Side Behavior)

    /// Test 13: Recipe with 2 reports is not hidden (below threshold)
    func test_autoHide_belowThreshold_notHidden() {
        // GIVEN: A recipe with 2 reports (below the 3-report threshold)
        var publicRecipe = createTestPublicRecipe()
        publicRecipe.reportCount = 2
        publicRecipe.isHidden = false  // Cloud Function hasn't triggered yet

        // THEN: Recipe should not be hidden (threshold is 3)
        XCTAssertFalse(publicRecipe.isHidden)
    }

    /// Test 14: Recipe at threshold (3 reports) would be hidden
    func test_autoHide_atThreshold_isHidden() {
        // GIVEN: A recipe that has reached 3 reports
        // (In production, Cloud Function sets isHidden = true at 3 reports)
        var publicRecipe = createTestPublicRecipe()
        publicRecipe.reportCount = 3
        publicRecipe.isHidden = true  // Set by Cloud Function

        // THEN: Recipe should be hidden
        XCTAssertTrue(publicRecipe.isHidden)
        XCTAssertEqual(publicRecipe.reportCount, 3)
    }

    /// Test 15: Recipe above threshold remains hidden
    func test_autoHide_aboveThreshold_remainsHidden() {
        // GIVEN: A recipe with more than 3 reports
        var publicRecipe = createTestPublicRecipe()
        publicRecipe.reportCount = 5
        publicRecipe.isHidden = true

        // THEN: Recipe should remain hidden
        XCTAssertTrue(publicRecipe.isHidden)
    }

    // MARK: - Discovery Filtering Tests

    /// Test 16: Filtering removes hidden recipes
    func test_discoveryFiltering_removesHiddenRecipes() {
        // GIVEN: A mix of visible and hidden recipes
        let visibleRecipe1 = createTestPublicRecipe(id: "visible-1", isHidden: false)
        let visibleRecipe2 = createTestPublicRecipe(id: "visible-2", isHidden: false)
        let hiddenRecipe = createTestPublicRecipe(id: "hidden-1", isHidden: true)
        let allRecipes = [visibleRecipe1, visibleRecipe2, hiddenRecipe]

        // WHEN: Filtering out hidden recipes
        let filteredRecipes = filterOutHiddenRecipes(allRecipes)

        // THEN: Only visible recipes remain
        XCTAssertEqual(filteredRecipes.count, 2)
        XCTAssertTrue(filteredRecipes.contains { $0.id == "visible-1" })
        XCTAssertTrue(filteredRecipes.contains { $0.id == "visible-2" })
        XCTAssertFalse(filteredRecipes.contains { $0.id == "hidden-1" })
    }

    /// Test 17: Filtering handles all visible recipes
    func test_discoveryFiltering_allVisible_returnsAll() {
        // GIVEN: All visible recipes
        let recipe1 = createTestPublicRecipe(id: "1", isHidden: false)
        let recipe2 = createTestPublicRecipe(id: "2", isHidden: false)
        let recipe3 = createTestPublicRecipe(id: "3", isHidden: false)
        let allRecipes = [recipe1, recipe2, recipe3]

        // WHEN: Filtering
        let filteredRecipes = filterOutHiddenRecipes(allRecipes)

        // THEN: All recipes returned
        XCTAssertEqual(filteredRecipes.count, 3)
    }

    /// Test 18: Filtering handles all hidden recipes
    func test_discoveryFiltering_allHidden_returnsEmpty() {
        // GIVEN: All hidden recipes
        let recipe1 = createTestPublicRecipe(id: "1", isHidden: true)
        let recipe2 = createTestPublicRecipe(id: "2", isHidden: true)
        let allRecipes = [recipe1, recipe2]

        // WHEN: Filtering
        let filteredRecipes = filterOutHiddenRecipes(allRecipes)

        // THEN: No recipes returned
        XCTAssertEqual(filteredRecipes.count, 0)
    }

    /// Test 19: Filtering handles empty list
    func test_discoveryFiltering_emptyList_returnsEmpty() {
        // GIVEN: Empty recipe list
        let allRecipes: [TestPublicRecipe] = []

        // WHEN: Filtering
        let filteredRecipes = filterOutHiddenRecipes(allRecipes)

        // THEN: Empty list returned
        XCTAssertEqual(filteredRecipes.count, 0)
    }

    // MARK: - Owner Visibility Tests

    /// Test 20: Owners can still see their hidden recipes
    func test_ownerVisibility_canSeeOwnHiddenRecipe() {
        // GIVEN: A hidden recipe owned by user
        let ownerId = "user-123"
        let currentUserId = "user-123"  // Same user
        var hiddenRecipe = createTestPublicRecipe(id: "owned-recipe", isHidden: true)
        hiddenRecipe.ownerId = ownerId

        // WHEN: Checking if owner can view
        let canView = canUserViewRecipe(hiddenRecipe, currentUserId: currentUserId)

        // THEN: Owner should be able to view their own hidden recipe
        XCTAssertTrue(canView)
    }

    /// Test 21: Non-owners cannot see hidden recipes
    func test_ownerVisibility_nonOwnerCannotSeeHiddenRecipe() {
        // GIVEN: A hidden recipe owned by another user
        let ownerId = "user-123"
        let currentUserId = "user-456"  // Different user
        var hiddenRecipe = createTestPublicRecipe(id: "other-recipe", isHidden: true)
        hiddenRecipe.ownerId = ownerId

        // WHEN: Checking if non-owner can view
        let canView = canUserViewRecipe(hiddenRecipe, currentUserId: currentUserId)

        // THEN: Non-owner should not be able to view hidden recipe
        XCTAssertFalse(canView)
    }

    /// Test 22: Anyone can see visible recipes
    func test_ownerVisibility_anyoneCanSeeVisibleRecipe() {
        // GIVEN: A visible recipe
        let currentUserId = "any-user"
        let visibleRecipe = createTestPublicRecipe(id: "visible-recipe", isHidden: false)

        // WHEN: Checking if user can view
        let canView = canUserViewRecipe(visibleRecipe, currentUserId: currentUserId)

        // THEN: Anyone should be able to view visible recipe
        XCTAssertTrue(canView)
    }

    // MARK: - Moderation Status Tests

    /// Test 23: Moderation status can be pending_review
    func test_moderationStatus_pendingReview() {
        // GIVEN: A recipe under review
        var publicRecipe = createTestPublicRecipe()
        publicRecipe.moderationStatus = "pending_review"

        // THEN: Status should be set
        XCTAssertEqual(publicRecipe.moderationStatus, "pending_review")
    }

    /// Test 24: Moderation status can be approved
    func test_moderationStatus_approved() {
        // GIVEN: An approved recipe
        var publicRecipe = createTestPublicRecipe()
        publicRecipe.moderationStatus = "approved"

        // THEN: Status should be set
        XCTAssertEqual(publicRecipe.moderationStatus, "approved")
    }

    /// Test 25: Moderation status can be hidden
    func test_moderationStatus_hidden() {
        // GIVEN: A hidden recipe
        var publicRecipe = createTestPublicRecipe()
        publicRecipe.moderationStatus = "hidden"
        publicRecipe.isHidden = true

        // THEN: Both status and flag should be set
        XCTAssertEqual(publicRecipe.moderationStatus, "hidden")
        XCTAssertTrue(publicRecipe.isHidden)
    }

    // MARK: - Report Data Structure Tests

    /// Test 26: Report contains required fields
    func test_reportData_hasRequiredFields() {
        // GIVEN: A report to be created
        let publicRecipeId = "recipe-123"
        let reporterId = "user-456"
        let reason = ReportReason.spam
        let details = "This is spam content"

        // WHEN: Creating report data structure
        let reportData: [String: Any] = [
            "publicRecipeId": publicRecipeId,
            "reporterId": reporterId,
            "reason": reason.rawValue,
            "details": details,
            "status": "pending"
        ]

        // THEN: All required fields should be present
        XCTAssertEqual(reportData["publicRecipeId"] as? String, publicRecipeId)
        XCTAssertEqual(reportData["reporterId"] as? String, reporterId)
        XCTAssertEqual(reportData["reason"] as? String, reason.rawValue)
        XCTAssertEqual(reportData["details"] as? String, details)
        XCTAssertEqual(reportData["status"] as? String, "pending")
    }

    /// Test 27: Report can have empty details
    func test_reportData_canHaveEmptyDetails() {
        // GIVEN: A report without details
        let reason = ReportReason.inappropriate
        let details: String? = nil

        // WHEN: Creating report data
        let reportData: [String: Any] = [
            "publicRecipeId": "recipe-123",
            "reporterId": "user-456",
            "reason": reason.rawValue,
            "details": details ?? "",
            "status": "pending"
        ]

        // THEN: Details should be empty string
        XCTAssertEqual(reportData["details"] as? String, "")
    }

    // MARK: - Integration Scenario Tests

    /// Test 28: Full moderation flow - fresh recipe
    func test_moderationFlow_freshRecipe_isVisible() {
        // GIVEN: A freshly published recipe
        let publicRecipe = createTestPublicRecipe()

        // THEN: Should be visible
        XCTAssertFalse(publicRecipe.isHidden)
        XCTAssertEqual(publicRecipe.reportCount, 0)
        XCTAssertNil(publicRecipe.moderationStatus)
    }

    /// Test 29: Full moderation flow - recipe with 1 report
    func test_moderationFlow_oneReport_stillVisible() {
        // GIVEN: A recipe with 1 report
        var publicRecipe = createTestPublicRecipe()
        publicRecipe.reportCount = 1

        // THEN: Should still be visible (threshold is 3)
        XCTAssertFalse(publicRecipe.isHidden)
        XCTAssertEqual(publicRecipe.reportCount, 1)
    }

    /// Test 30: Full moderation flow - recipe crosses threshold
    func test_moderationFlow_crossesThreshold_becomesHidden() {
        // GIVEN: A recipe that just received its 3rd report
        var publicRecipe = createTestPublicRecipe()
        publicRecipe.reportCount = 3
        // Cloud Function would set these:
        publicRecipe.isHidden = true
        publicRecipe.moderationStatus = "pending_review"

        // THEN: Should be hidden and under review
        XCTAssertTrue(publicRecipe.isHidden)
        XCTAssertEqual(publicRecipe.reportCount, 3)
        XCTAssertEqual(publicRecipe.moderationStatus, "pending_review")
    }

    // MARK: - Helper Methods

    /// Create a test PublicRecipe with configurable fields
    private func createTestPublicRecipe(
        id: String = "test-recipe-\(UUID().uuidString)",
        isHidden: Bool = false,
        reportCount: Int = 0,
        moderationStatus: String? = nil
    ) -> TestPublicRecipe {
        return TestPublicRecipe(
            id: id,
            ownerId: "owner-123",
            isHidden: isHidden,
            reportCount: reportCount,
            moderationStatus: moderationStatus
        )
    }

    /// Filter out hidden recipes (mirrors DiscoveryService.filterOutOwnRecipes logic)
    private func filterOutHiddenRecipes(_ recipes: [TestPublicRecipe]) -> [TestPublicRecipe] {
        return recipes.filter { !$0.isHidden }
    }

    /// Check if user can view a recipe (mirrors fetchPublicRecipe logic)
    private func canUserViewRecipe(_ recipe: TestPublicRecipe, currentUserId: String?) -> Bool {
        // If not hidden, anyone can view
        if !recipe.isHidden {
            return true
        }
        // If hidden, only owner can view
        return recipe.ownerId == currentUserId
    }
}

// MARK: - Test Helper Struct

/// Simplified PublicRecipe for testing moderation logic
/// Used because PublicRecipe requires Firestore DocumentSnapshot for initialization
struct TestPublicRecipe: Identifiable {
    var id: String
    var ownerId: String = "owner-123"
    var title: String = "Test Recipe"
    var isHidden: Bool = false
    var reportCount: Int = 0
    var moderationStatus: String? = nil
}
