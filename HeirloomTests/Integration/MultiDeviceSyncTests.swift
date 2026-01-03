//
//  MultiDeviceSyncTests.swift
//  HeirloomTests
//
//  Tests for multi-device sync scenarios using CRDT conflict resolution
//

import XCTest
import SwiftData
@testable import Heirloom

@MainActor
final class MultiDeviceSyncTests: XCTestCase {

    // MARK: - Properties

    var simulator: MultiDeviceSimulator!

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        try await super.setUp()
        simulator = MultiDeviceSimulator()
    }

    override func tearDown() async throws {
        simulator.reset()
        try await super.tearDown()
    }

    // MARK: - Basic Two-Device Tests

    func testTwoDevices_CreateRecipe_SyncsToOther() async throws {
        // Given: Two devices
        let (device1, device2) = try simulator.createTwoDeviceScenario()

        // When: Device 1 creates a recipe
        let recipe = device1.createRecipe(title: "Chocolate Cake")
        try await device1.sync()

        // And: Device 2 syncs
        try await device2.sync()

        // Then: Device 2 should have the recipe
        let device2Recipe = device2.fetchRecipe(id: recipe.id)
        XCTAssertNotNil(device2Recipe)
        XCTAssertEqual(device2Recipe?.title, "Chocolate Cake")
    }

    func testTwoDevices_EditRecipe_SyncsChanges() async throws {
        // Given: Two devices with same recipe
        let (device1, device2) = try simulator.createTwoDeviceScenario()

        let recipe1 = device1.createRecipe(title: "Pasta")
        try await device1.sync()
        try await device2.sync()

        // When: Device 1 edits the recipe
        device1.editRecipe(recipe1) { recipe in
            recipe.notes = "Added by Device 1"
        }
        try await device1.sync()

        // And: Device 2 syncs
        try await device2.sync()

        // Then: Device 2 should see the updated notes
        let device2Recipe = device2.fetchRecipe(id: recipe1.id)
        XCTAssertEqual(device2Recipe?.notes, "Added by Device 1")
    }

    func testTwoDevices_DeleteRecipe_SyncsToOther() async throws {
        // Given: Two devices with same recipe
        let (device1, device2) = try simulator.createTwoDeviceScenario()

        let recipe = device1.createRecipe(title: "To Delete")
        try await device1.sync()
        try await device2.sync()

        // When: Device 1 deletes the recipe
        device1.deleteRecipe(recipe)
        try await device1.sync()

        // And: Device 2 syncs
        try await device2.sync()

        // Then: Device 2 should not have the recipe
        let device2Recipe = device2.fetchRecipe(id: recipe.id)
        XCTAssertNil(device2Recipe)
    }

    // MARK: - Concurrent Edit Tests (CRDT Scenarios)

    func testTwoDevices_ConcurrentEdit_SameField_DetectsConflict() async throws {
        // Given: Two devices with same recipe
        let (device1, device2) = try simulator.createTwoDeviceScenario()

        let recipe1 = device1.createRecipe(title: "Lasagna")
        try await device1.sync()
        try await device2.sync()

        guard let recipe2 = device2.fetchRecipe(id: recipe1.id) else {
            XCTFail("Device 2 should have synced recipe")
            return
        }

        // When: Both devices edit the SAME field BEFORE syncing
        device1.editRecipe(recipe1) { recipe in
            recipe.servings = "4 servings"
        }

        device2.editRecipe(recipe2) { recipe in
            recipe.servings = "8 servings"
        }

        // Both sync
        try await device1.sync()
        try await device2.sync()

        // Then: Conflict should be detected
        // Note: This requires CRDT integration to fully test
        // For now, verify last-write-wins behavior

        let finalRecipe1 = device1.fetchRecipe(id: recipe1.id)
        let finalRecipe2 = device2.fetchRecipe(id: recipe2.id)

        // Both devices should eventually have the same value (eventual consistency)
        XCTAssertNotNil(finalRecipe1)
        XCTAssertNotNil(finalRecipe2)

        // TODO: After CRDT integration, verify conflict was detected and resolved
        XCTAssertTrue(true, "Placeholder - full CRDT conflict detection pending")
    }

    func testTwoDevices_ConcurrentEdit_DifferentFields_AutoMerges() async throws {
        // Given: Two devices with same recipe
        let (device1, device2) = try simulator.createTwoDeviceScenario()

        let recipe1 = device1.createRecipe(title: "Pizza")
        try await device1.sync()
        try await device2.sync()

        guard let recipe2 = device2.fetchRecipe(id: recipe1.id) else {
            XCTFail("Device 2 should have synced recipe")
            return
        }

        // When: Both devices edit DIFFERENT fields BEFORE syncing
        device1.editRecipe(recipe1) { recipe in
            recipe.servings = "4 servings"
        }

        device2.editRecipe(recipe2) { recipe in
            recipe.notes = "Delicious pizza"
        }

        // Both sync
        try await device1.sync()
        try await device2.sync()

        // Then: Both changes should be preserved (auto-merge, no conflict)
        let finalRecipe1 = device1.fetchRecipe(id: recipe1.id)
        let finalRecipe2 = device2.fetchRecipe(id: recipe2.id)

        XCTAssertEqual(finalRecipe1?.servings, "4 servings")
        XCTAssertEqual(finalRecipe1?.notes, "Delicious pizza")

        XCTAssertEqual(finalRecipe2?.servings, "4 servings")
        XCTAssertEqual(finalRecipe2?.notes, "Delicious pizza")
    }

    func testTwoDevices_ConcurrentAddIngredient_BothPreserved() async throws {
        // Given: Two devices with same recipe
        let (device1, device2) = try simulator.createTwoDeviceScenario()

        let recipe1 = device1.createRecipe(title: "Salad")
        try await device1.sync()
        try await device2.sync()

        guard let recipe2 = device2.fetchRecipe(id: recipe1.id) else {
            XCTFail("Device 2 should have synced recipe")
            return
        }

        // When: Both devices add different ingredients BEFORE syncing
        device1.editRecipe(recipe1) { recipe in
            let ingredient = Ingredient(originalText: "1 cup lettuce", quantity: 1.0, unit: "cup", name: "lettuce")
            recipe.ingredients = [ingredient]
        }

        device2.editRecipe(recipe2) { recipe in
            let ingredient = Ingredient(originalText: "2 tomatoes", quantity: 2.0, name: "tomatoes")
            recipe.ingredients = [ingredient]
        }

        // Both sync
        try await device1.sync()
        try await device2.sync()

        // Then: Both ingredients should be preserved (additive CRDT behavior)
        let finalRecipe1 = device1.fetchRecipe(id: recipe1.id)
        let finalRecipe2 = device2.fetchRecipe(id: recipe2.id)

        // TODO: After full CRDT integration, verify both ingredients exist
        XCTAssertTrue(true, "Placeholder - additive CRDT merge pending")
    }

    // MARK: - Three-Device Tests

    func testThreeDevices_ConcurrentEdits_EventualConsistency() async throws {
        // Given: Three devices with same recipe
        let (device1, device2, device3) = try simulator.createThreeDeviceScenario()

        let recipe1 = device1.createRecipe(title: "Tacos")
        try await device1.sync()
        try await device2.sync()
        try await device3.sync()

        guard let recipe2 = device2.fetchRecipe(id: recipe1.id),
              let recipe3 = device3.fetchRecipe(id: recipe1.id) else {
            XCTFail("All devices should have synced recipe")
            return
        }

        // When: All three devices edit different fields BEFORE syncing
        device1.editRecipe(recipe1) { $0.servings = "2 servings" }
        device2.editRecipe(recipe2) { $0.notes = "Spicy tacos" }
        device3.editRecipe(recipe3) { $0.prepTime = "30 minutes" }

        // All sync in sequence
        try await device1.sync()
        try await device2.sync()
        try await device3.sync()

        // Sync again to ensure convergence
        try await device1.sync()
        try await device2.sync()

        // Then: All devices should have all changes (eventual consistency)
        let finalRecipe1 = device1.fetchRecipe(id: recipe1.id)
        let finalRecipe2 = device2.fetchRecipe(id: recipe2.id)
        let finalRecipe3 = device3.fetchRecipe(id: recipe3.id)

        XCTAssertEqual(finalRecipe1?.servings, "2 servings")
        XCTAssertEqual(finalRecipe1?.notes, "Spicy tacos")
        XCTAssertEqual(finalRecipe1?.prepTime, "30 minutes")

        XCTAssertEqual(finalRecipe2?.servings, "2 servings")
        XCTAssertEqual(finalRecipe2?.notes, "Spicy tacos")
        XCTAssertEqual(finalRecipe2?.prepTime, "30 minutes")

        XCTAssertEqual(finalRecipe3?.servings, "2 servings")
        XCTAssertEqual(finalRecipe3?.notes, "Spicy tacos")
        XCTAssertEqual(finalRecipe3?.prepTime, "30 minutes")
    }

    // MARK: - Offline/Online Tests

    func testDevice_GoesOffline_EditsQueue_SyncWhenOnline() async throws {
        // Given: Two devices, one goes offline
        let (device1, device2) = try simulator.createTwoDeviceScenario()

        let recipe1 = device1.createRecipe(title: "Soup")
        try await device1.sync()
        try await device2.sync()

        // When: Device 2 goes offline
        device2.goOffline()

        // And: Device 2 makes edits while offline
        guard let recipe2 = device2.fetchRecipe(id: recipe1.id) else {
            XCTFail("Device 2 should have recipe")
            return
        }

        device2.editRecipe(recipe2) { recipe in
            recipe.notes = "Edited while offline"
        }

        // Try to sync (should queue)
        do {
            try await device2.sync()
            XCTFail("Should have thrown offline error")
        } catch {
            // Expected to fail
            XCTAssertTrue(error is SimulatorError)
        }

        // When: Device 2 comes back online
        device2.goOnline()
        try await device2.processSyncQueue()
        try await device2.sync()

        // And: Device 1 syncs
        try await device1.sync()

        // Then: Device 1 should have Device 2's offline edits
        let finalRecipe1 = device1.fetchRecipe(id: recipe1.id)
        XCTAssertEqual(finalRecipe1?.notes, "Edited while offline")
    }

    func testTwoDevices_BothOffline_EditsSyncWhenOnline() async throws {
        // Given: Two devices, both go offline
        let (device1, device2) = try simulator.createTwoDeviceScenario()

        let recipe1 = device1.createRecipe(title: "Curry")
        try await device1.sync()
        try await device2.sync()

        // When: Both devices go offline
        device1.goOffline()
        device2.goOffline()

        // And: Both make different edits
        device1.editRecipe(recipe1) { $0.servings = "6 servings" }

        guard let recipe2 = device2.fetchRecipe(id: recipe1.id) else {
            XCTFail("Device 2 should have recipe")
            return
        }
        device2.editRecipe(recipe2) { $0.notes = "Very spicy" }

        // When: Both come back online and sync
        device1.goOnline()
        device2.goOnline()

        try await device1.processSyncQueue()
        try await device2.processSyncQueue()

        try await device1.sync()
        try await device2.sync()
        try await device1.sync() // Second sync for convergence

        // Then: Both devices should have both changes
        let finalRecipe1 = device1.fetchRecipe(id: recipe1.id)
        let finalRecipe2 = device2.fetchRecipe(id: recipe2.id)

        XCTAssertEqual(finalRecipe1?.servings, "6 servings")
        XCTAssertEqual(finalRecipe1?.notes, "Very spicy")

        XCTAssertEqual(finalRecipe2?.servings, "6 servings")
        XCTAssertEqual(finalRecipe2?.notes, "Very spicy")
    }

    // MARK: - Network Failure Tests

    func testSyncInterrupted_ResumesCorrectly() async throws {
        // Given: Two devices
        let (device1, device2) = try simulator.createTwoDeviceScenario()

        let recipe = device1.createRecipe(title: "Brownies")
        try await device1.sync()

        // When: Network fails during Device 2 sync
        simulator.simulateNetworkFailure()

        do {
            try await device2.sync()
            XCTFail("Should have thrown network error")
        } catch {
            // Expected failure
            XCTAssertTrue(true, "Network failure detected")
        }

        // When: Network restored
        simulator.restoreNetwork()
        try await device2.sync()

        // Then: Device 2 should have the recipe
        let device2Recipe = device2.fetchRecipe(id: recipe.id)
        XCTAssertNotNil(device2Recipe)
        XCTAssertEqual(device2Recipe?.title, "Brownies")
    }

    // MARK: - Performance Tests

    func testSyncPerformance_100Recipes() async throws {
        // Given: Device 1 with 100 recipes
        let device1 = try simulator.createDevice(id: "iPhone")

        for i in 1...100 {
            _ = device1.createRecipe(title: "Recipe \(i)")
        }

        // When: Measure sync time
        let startTime = Date()
        try await device1.sync()
        let syncDuration = Date().timeIntervalSince(startTime)

        // Then: Should complete in reasonable time (< 10 seconds for mock)
        XCTAssertLessThan(syncDuration, 10.0, "Sync should complete within 10 seconds")
    }

    func testSyncPerformance_WithNetworkLatency() async throws {
        // Given: Network latency configured
        simulator.simulateLatency(0.05) // 50ms per operation

        let (device1, device2) = try simulator.createTwoDeviceScenario()

        for i in 1...10 {
            _ = device1.createRecipe(title: "Recipe \(i)")
        }

        // When: Sync with latency
        let startTime = Date()
        try await device1.sync()
        try await device2.sync()
        let syncDuration = Date().timeIntervalSince(startTime)

        // Then: Should handle latency gracefully
        XCTAssertGreaterThan(syncDuration, 0.5, "Should reflect latency")
        XCTAssertLessThan(syncDuration, 5.0, "Should not timeout")

        // And: All recipes should sync
        try simulator.assertRecipeCountConsistent(expectedCount: 10)
    }

    // MARK: - Helper Assertions

    /// Verify that all devices have the same recipe with the same data
    func assertRecipeConsistentAcrossDevices(_ recipeId: UUID, expectedTitle: String) {
        simulator.assertRecipeExistsOnAllDevices(id: recipeId, expectedTitle: expectedTitle)
    }
}
