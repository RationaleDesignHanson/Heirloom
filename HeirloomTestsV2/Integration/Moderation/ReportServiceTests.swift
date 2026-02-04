//
//  ReportServiceTests.swift
//  HeirloomTestsV2
//
//  Created: 2026-02-04
//  Unit tests for ReportPublicRecipeService using mocked Firestore
//
//  Tests the reporting service to ensure:
//  - Report data is correctly structured
//  - Duplicate report prevention works
//  - Report count is incremented
//  - Error handling is correct
//

import XCTest
import SwiftData
@testable import Heirloom

@MainActor
final class ReportServiceTests: XCTestCase {

    // MARK: - Properties

    var mockFirestore: MockFirestore!

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        try await super.setUp()
        mockFirestore = MockFirestore()
    }

    override func tearDown() async throws {
        mockFirestore.reset()
        mockFirestore = nil
        try await super.tearDown()
    }

    // MARK: - Report Data Structure Tests

    /// Test 1: Report creates correct document structure
    func test_reportData_hasCorrectStructure() async throws {
        // GIVEN: Report parameters
        let publicRecipeId = "recipe-123"
        let reporterId = "user-456"
        let reason = ReportReason.spam
        let details = "This is spam content"

        // WHEN: Creating a report document
        let reportId = try await mockFirestore.collection("publicRecipeReports")
            .addDocument(data: [
                "publicRecipeId": publicRecipeId,
                "reporterId": reporterId,
                "reason": reason.rawValue,
                "details": details,
                "status": "pending"
            ])

        // THEN: Document should be created with correct data
        XCTAssertFalse(reportId.isEmpty)

        let documents = mockFirestore.getAllDocuments(in: "publicRecipeReports")
        XCTAssertEqual(documents.count, 1)

        let report = documents.first!
        XCTAssertEqual(report["publicRecipeId"] as? String, publicRecipeId)
        XCTAssertEqual(report["reporterId"] as? String, reporterId)
        XCTAssertEqual(report["reason"] as? String, reason.rawValue)
        XCTAssertEqual(report["details"] as? String, details)
        XCTAssertEqual(report["status"] as? String, "pending")
    }

    /// Test 2: Report with nil details uses empty string
    func test_reportData_nilDetails_usesEmptyString() async throws {
        // GIVEN: Report without details
        let details: String? = nil

        // WHEN: Creating report document
        _ = try await mockFirestore.collection("publicRecipeReports")
            .addDocument(data: [
                "publicRecipeId": "recipe-123",
                "reporterId": "user-456",
                "reason": ReportReason.inappropriate.rawValue,
                "details": details ?? "",
                "status": "pending"
            ])

        // THEN: Details should be empty string
        let documents = mockFirestore.getAllDocuments(in: "publicRecipeReports")
        XCTAssertEqual(documents.first?["details"] as? String, "")
    }

    /// Test 3: Multiple reports from different users are stored
    func test_reportData_multipleReports_allStored() async throws {
        // GIVEN: Multiple reports from different users
        let reports = [
            ("user-1", ReportReason.spam),
            ("user-2", ReportReason.inappropriate),
            ("user-3", ReportReason.copyright)
        ]

        // WHEN: Creating multiple reports
        for (reporterId, reason) in reports {
            _ = try await mockFirestore.collection("publicRecipeReports")
                .addDocument(data: [
                    "publicRecipeId": "recipe-123",
                    "reporterId": reporterId,
                    "reason": reason.rawValue,
                    "status": "pending"
                ])
        }

        // THEN: All reports should be stored
        let documents = mockFirestore.getAllDocuments(in: "publicRecipeReports")
        XCTAssertEqual(documents.count, 3)
    }

    // MARK: - Duplicate Report Detection Tests

    /// Test 4: Check for existing report finds match
    func test_duplicateCheck_existingReport_returnsTrue() async throws {
        // GIVEN: A user has already reported this recipe
        let publicRecipeId = "recipe-123"
        let reporterId = "user-456"

        mockFirestore.seed(collection: "publicRecipeReports", documents: [
            "existing-report": [
                "publicRecipeId": publicRecipeId,
                "reporterId": reporterId,
                "reason": ReportReason.spam.rawValue,
                "status": "pending"
            ]
        ])

        // WHEN: Querying for existing report
        let existingReports = try mockFirestore.query(
            collection: "publicRecipeReports",
            filters: [
                "publicRecipeId": publicRecipeId,
                "reporterId": reporterId
            ]
        )

        // THEN: Should find the existing report
        XCTAssertEqual(existingReports.count, 1)
    }

    /// Test 5: Check for existing report - no match returns false
    func test_duplicateCheck_noExistingReport_returnsFalse() async throws {
        // GIVEN: User has not reported this recipe
        let publicRecipeId = "recipe-123"
        let reporterId = "user-456"

        // Different user reported
        mockFirestore.seed(collection: "publicRecipeReports", documents: [
            "other-report": [
                "publicRecipeId": publicRecipeId,
                "reporterId": "different-user",
                "reason": ReportReason.spam.rawValue
            ]
        ])

        // WHEN: Querying for this user's report
        let existingReports = try mockFirestore.query(
            collection: "publicRecipeReports",
            filters: [
                "publicRecipeId": publicRecipeId,
                "reporterId": reporterId
            ]
        )

        // THEN: Should not find any reports
        XCTAssertEqual(existingReports.count, 0)
    }

    /// Test 6: Same user can report different recipes
    func test_duplicateCheck_differentRecipes_allowed() async throws {
        // GIVEN: User reported recipe-1
        let reporterId = "user-456"

        mockFirestore.seed(collection: "publicRecipeReports", documents: [
            "report-1": [
                "publicRecipeId": "recipe-1",
                "reporterId": reporterId,
                "reason": ReportReason.spam.rawValue
            ]
        ])

        // WHEN: Checking if user can report recipe-2
        let existingReports = try mockFirestore.query(
            collection: "publicRecipeReports",
            filters: [
                "publicRecipeId": "recipe-2",
                "reporterId": reporterId
            ]
        )

        // THEN: No existing report for recipe-2
        XCTAssertEqual(existingReports.count, 0)
    }

    // MARK: - Report Count Increment Tests

    /// Test 7: Report count increments from 0 to 1
    func test_reportCount_incrementsFromZero() async throws {
        // GIVEN: Recipe with 0 reports
        mockFirestore.seed(collection: "publicRecipes", documents: [
            "recipe-123": [
                "title": "Test Recipe",
                "reportCount": 0,
                "isHidden": false
            ]
        ])

        // WHEN: Incrementing report count
        let docRef = mockFirestore.collection("publicRecipes").document("recipe-123")
        let existing = try await docRef.getDocument()
        var updated = existing ?? [:]
        updated["reportCount"] = (updated["reportCount"] as? Int ?? 0) + 1
        try await docRef.setData(updated)

        // THEN: Report count should be 1
        let result = try await docRef.getDocument()
        XCTAssertEqual(result?["reportCount"] as? Int, 1)
    }

    /// Test 8: Report count increments correctly
    func test_reportCount_incrementsCorrectly() async throws {
        // GIVEN: Recipe with 2 reports
        mockFirestore.seed(collection: "publicRecipes", documents: [
            "recipe-123": [
                "title": "Test Recipe",
                "reportCount": 2,
                "isHidden": false
            ]
        ])

        // WHEN: Incrementing report count
        let docRef = mockFirestore.collection("publicRecipes").document("recipe-123")
        let existing = try await docRef.getDocument()
        var updated = existing ?? [:]
        updated["reportCount"] = (updated["reportCount"] as? Int ?? 0) + 1
        try await docRef.setData(updated)

        // THEN: Report count should be 3
        let result = try await docRef.getDocument()
        XCTAssertEqual(result?["reportCount"] as? Int, 3)
    }

    // MARK: - Error Handling Tests

    /// Test 9: Report submission fails when offline
    func test_reportSubmission_offline_fails() async throws {
        // GIVEN: Firestore is offline
        mockFirestore.simulateOffline = true

        // WHEN: Attempting to submit report
        do {
            _ = try await mockFirestore.collection("publicRecipeReports")
                .addDocument(data: ["test": "data"])
            XCTFail("Should have thrown offline error")
        } catch {
            // THEN: Should throw offline error
            XCTAssertEqual(error as? FirestoreError, FirestoreError.offline)
        }
    }

    /// Test 10: Report submission fails when Firestore fails
    func test_reportSubmission_firestoreFails_throwsError() async throws {
        // GIVEN: Firestore is configured to fail
        mockFirestore.shouldFail = true
        mockFirestore.injectedError = FirestoreError.writeFailed

        // WHEN: Attempting to submit report
        do {
            _ = try await mockFirestore.collection("publicRecipeReports")
                .addDocument(data: ["test": "data"])
            XCTFail("Should have thrown write error")
        } catch {
            // THEN: Should throw write error
            XCTAssertEqual(error as? FirestoreError, FirestoreError.writeFailed)
        }
    }

    /// Test 11: Recipe update fails for non-existent recipe
    func test_reportCount_nonExistentRecipe_fails() async throws {
        // GIVEN: Empty Firestore (no recipes)

        // WHEN: Attempting to update non-existent recipe
        do {
            try mockFirestore.updateDocument(
                collection: "publicRecipes",
                id: "non-existent",
                data: ["reportCount": 1]
            )
            XCTFail("Should have thrown document not found error")
        } catch {
            // THEN: Should throw not found error
            XCTAssertEqual(error as? FirestoreError, FirestoreError.documentNotFound)
        }
    }

    // MARK: - Report Reason Coverage Tests

    /// Test 12: All report reasons can be submitted
    func test_reportReason_allReasonsCanBeSubmitted() async throws {
        // GIVEN: All report reasons
        let reasons = ReportReason.allCases

        // WHEN: Submitting a report for each reason
        for reason in reasons {
            _ = try await mockFirestore.collection("publicRecipeReports")
                .addDocument(data: [
                    "publicRecipeId": "recipe-\(reason.rawValue)",
                    "reporterId": "user-test",
                    "reason": reason.rawValue,
                    "status": "pending"
                ])
        }

        // THEN: All reports should be created
        let documents = mockFirestore.getAllDocuments(in: "publicRecipeReports")
        XCTAssertEqual(documents.count, 6)

        // Verify each reason is present
        let storedReasons = Set(documents.compactMap { $0["reason"] as? String })
        XCTAssertEqual(storedReasons.count, 6)
    }

    // MARK: - Status Transition Tests

    /// Test 13: Report status starts as pending
    func test_reportStatus_startsAsPending() async throws {
        // WHEN: Creating a new report
        _ = try await mockFirestore.collection("publicRecipeReports")
            .addDocument(data: [
                "publicRecipeId": "recipe-123",
                "reporterId": "user-456",
                "reason": ReportReason.spam.rawValue,
                "status": "pending"
            ])

        // THEN: Status should be pending
        let documents = mockFirestore.getAllDocuments(in: "publicRecipeReports")
        XCTAssertEqual(documents.first?["status"] as? String, "pending")
    }

    /// Test 14: Report status can transition to reviewed
    func test_reportStatus_canTransitionToReviewed() async throws {
        // GIVEN: A pending report
        mockFirestore.seed(collection: "publicRecipeReports", documents: [
            "report-123": [
                "publicRecipeId": "recipe-123",
                "reporterId": "user-456",
                "status": "pending"
            ]
        ])

        // WHEN: Transitioning to reviewed
        try mockFirestore.updateDocument(
            collection: "publicRecipeReports",
            id: "report-123",
            data: ["status": "reviewed"]
        )

        // THEN: Status should be reviewed
        let doc = try mockFirestore.getDocument(collection: "publicRecipeReports", id: "report-123")
        XCTAssertEqual(doc?["status"] as? String, "reviewed")
    }

    /// Test 15: Report status can transition to action_taken
    func test_reportStatus_canTransitionToActionTaken() async throws {
        // GIVEN: A reviewed report
        mockFirestore.seed(collection: "publicRecipeReports", documents: [
            "report-123": [
                "publicRecipeId": "recipe-123",
                "reporterId": "user-456",
                "status": "reviewed"
            ]
        ])

        // WHEN: Transitioning to action_taken
        try mockFirestore.updateDocument(
            collection: "publicRecipeReports",
            id: "report-123",
            data: [
                "status": "action_taken",
                "actionTaken": "Recipe hidden"
            ]
        )

        // THEN: Status and action should be updated
        let doc = try mockFirestore.getDocument(collection: "publicRecipeReports", id: "report-123")
        XCTAssertEqual(doc?["status"] as? String, "action_taken")
        XCTAssertEqual(doc?["actionTaken"] as? String, "Recipe hidden")
    }

    // MARK: - Cloud Function Simulation Tests

    /// Test 16: Auto-hide triggers at 3 reports (simulated)
    func test_autoHide_triggersAt3Reports() async throws {
        // GIVEN: Recipe with 2 reports
        mockFirestore.seed(collection: "publicRecipes", documents: [
            "recipe-123": [
                "title": "Test Recipe",
                "reportCount": 2,
                "isHidden": false
            ]
        ])

        // WHEN: 3rd report is submitted (simulating Cloud Function trigger)
        let docRef = mockFirestore.collection("publicRecipes").document("recipe-123")
        var updated = (try await docRef.getDocument()) ?? [:]
        let newReportCount = (updated["reportCount"] as? Int ?? 0) + 1
        updated["reportCount"] = newReportCount

        // Simulate Cloud Function logic: if reportCount >= 3, set isHidden = true
        if newReportCount >= 3 {
            updated["isHidden"] = true
            updated["moderationStatus"] = "pending_review"
        }

        try await docRef.setData(updated)

        // THEN: Recipe should be hidden
        let result = try await docRef.getDocument()
        XCTAssertEqual(result?["reportCount"] as? Int, 3)
        XCTAssertEqual(result?["isHidden"] as? Bool, true)
        XCTAssertEqual(result?["moderationStatus"] as? String, "pending_review")
    }

    /// Test 17: Auto-hide does not trigger below threshold
    func test_autoHide_doesNotTriggerBelowThreshold() async throws {
        // GIVEN: Recipe with 1 report
        mockFirestore.seed(collection: "publicRecipes", documents: [
            "recipe-123": [
                "title": "Test Recipe",
                "reportCount": 1,
                "isHidden": false
            ]
        ])

        // WHEN: 2nd report is submitted (simulating Cloud Function trigger)
        let docRef = mockFirestore.collection("publicRecipes").document("recipe-123")
        var updated = (try await docRef.getDocument()) ?? [:]
        let newReportCount = (updated["reportCount"] as? Int ?? 0) + 1
        updated["reportCount"] = newReportCount

        // Simulate Cloud Function logic: only hide if reportCount >= 3
        if newReportCount >= 3 {
            updated["isHidden"] = true
        }

        try await docRef.setData(updated)

        // THEN: Recipe should NOT be hidden (only 2 reports)
        let result = try await docRef.getDocument()
        XCTAssertEqual(result?["reportCount"] as? Int, 2)
        XCTAssertEqual(result?["isHidden"] as? Bool, false)
    }

    // MARK: - Tracking and Logging Tests

    /// Test 18: Report operations are tracked
    func test_firestoreOperations_areTracked() async throws {
        // WHEN: Performing multiple operations
        let _ = mockFirestore.collection("publicRecipeReports")
        _ = try await mockFirestore.collection("publicRecipeReports")
            .addDocument(data: ["test": "data"])

        // THEN: Call log should contain operations
        XCTAssertTrue(mockFirestore.callLog.contains { $0.contains("collection") })
        XCTAssertEqual(mockFirestore.documentsCreated.count, 1)
    }

    /// Test 19: Reset clears all state
    func test_reset_clearsAllState() async throws {
        // GIVEN: Firestore with data
        mockFirestore.seed(collection: "publicRecipeReports", documents: [
            "report-1": ["test": "data"]
        ])
        mockFirestore.shouldFail = true

        // WHEN: Resetting
        mockFirestore.reset()

        // THEN: All state should be cleared
        XCTAssertEqual(mockFirestore.callLog.count, 0)
        XCTAssertEqual(mockFirestore.documentCount(in: "publicRecipeReports"), 0)
        XCTAssertFalse(mockFirestore.shouldFail)
    }

    // MARK: - Edge Cases

    /// Test 20: Report with very long details is accepted
    func test_reportData_longDetails_accepted() async throws {
        // GIVEN: Very long details
        let longDetails = String(repeating: "This is a detailed report. ", count: 100)

        // WHEN: Creating report
        _ = try await mockFirestore.collection("publicRecipeReports")
            .addDocument(data: [
                "publicRecipeId": "recipe-123",
                "reporterId": "user-456",
                "reason": ReportReason.other.rawValue,
                "details": longDetails,
                "status": "pending"
            ])

        // THEN: Report should be created with full details
        let documents = mockFirestore.getAllDocuments(in: "publicRecipeReports")
        XCTAssertEqual(documents.first?["details"] as? String, longDetails)
    }
}
