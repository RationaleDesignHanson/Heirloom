//
//  MultiDeviceSimulator.swift
//  HeirloomTests
//
//  Framework for simulating multiple devices in sync tests
//

import Foundation
import SwiftData
import XCTest
@testable import Heirloom

/// Simulates multiple devices for testing multi-device sync scenarios
@MainActor
class MultiDeviceSimulator {

    // MARK: - Device Simulation

    private var devices: [String: SimulatedDevice] = [:]
    private let schema = Schema([
        Recipe.self,
        Ingredient.self,
        RecipeComment.self,
        RecipeCardBack.self,
        RecipeCRDT.self,
        OperationLog.self,
        RecipeLineage.self,
        VectorClock.self
    ])

    // Shared mock Firebase (simulates cloud backend)
    let sharedFirestore: MockFirestore
    let sharedAuth: MockAuth
    let sharedStorage: MockStorage

    init() {
        self.sharedFirestore = MockFirestore()
        self.sharedAuth = MockAuth()
        self.sharedStorage = MockStorage()
    }

    /// Create a new simulated device
    func createDevice(id: String, userId: String = "test-user") throws -> SimulatedDevice {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)

        let device = SimulatedDevice(
            id: id,
            userId: userId,
            modelContext: context,
            firestore: sharedFirestore,
            auth: sharedAuth,
            storage: sharedStorage
        )

        devices[id] = device

        // Simulate authentication
        sharedAuth.simulateSignIn(uid: userId, email: "\(userId)@test.com")

        return device
    }

    /// Get a device by ID
    func device(_ id: String) -> SimulatedDevice? {
        return devices[id]
    }

    /// Get all devices
    func allDevices() -> [SimulatedDevice] {
        return Array(devices.values)
    }

    /// Sync all devices with shared Firebase backend
    func syncAllDevices() async throws {
        for device in devices.values {
            try await device.sync()
        }
    }

    /// Sync specific devices
    func syncDevices(_ deviceIds: String...) async throws {
        for deviceId in deviceIds {
            guard let device = devices[deviceId] else {
                throw SimulatorError.deviceNotFound(deviceId)
            }
            try await device.sync()
        }
    }

    /// Reset all devices and shared backend
    func reset() {
        for device in devices.values {
            device.reset()
        }
        devices.removeAll()
        sharedFirestore.reset()
        sharedAuth.reset()
        sharedStorage.reset()
    }

    /// Simulate network failure for all devices
    func simulateNetworkFailure() {
        sharedFirestore.shouldFailOperations = true
        sharedStorage.shouldFailOperations = true
    }

    /// Restore network connectivity
    func restoreNetwork() {
        sharedFirestore.shouldFailOperations = false
        sharedStorage.shouldFailOperations = false
    }

    /// Simulate network latency
    func simulateLatency(_ seconds: TimeInterval) {
        sharedFirestore.operationDelay = seconds
        sharedStorage.storageDelay = seconds
    }
}

/// Simulated device with its own local database and sync state
@MainActor
class SimulatedDevice {
    let id: String
    let userId: String
    let modelContext: ModelContext
    let firestore: MockFirestore
    let auth: MockAuth
    let storage: MockStorage

    // Device state
    var isOnline = true
    var syncQueue: [SyncOperation] = []

    init(
        id: String,
        userId: String,
        modelContext: ModelContext,
        firestore: MockFirestore,
        auth: MockAuth,
        storage: MockStorage
    ) {
        self.id = id
        self.userId = userId
        self.modelContext = modelContext
        self.firestore = firestore
        self.auth = auth
        self.storage = storage
    }

    // MARK: - Recipe Operations

    /// Create a new recipe on this device
    func createRecipe(title: String, sourceType: RecipeSourceType = .manual) -> Recipe {
        let recipe = Recipe(title: title, sourceType: sourceType)
        modelContext.insert(recipe)
        try? modelContext.save()
        return recipe
    }

    /// Fetch a recipe by ID from local database
    func fetchRecipe(id: UUID) -> Recipe? {
        let descriptor = FetchDescriptor<Recipe>(
            predicate: #Predicate { $0.id == id }
        )
        return try? modelContext.fetch(descriptor).first
    }

    /// Edit a recipe (modifies local copy)
    func editRecipe(_ recipe: Recipe, changes: (Recipe) -> Void) {
        changes(recipe)
        recipe.lastModified = Date()
        // recipe.needsSync = true // REMOVED: Property no longer exists
        try? modelContext.save()
    }

    /// Delete a recipe from local database
    func deleteRecipe(_ recipe: Recipe) {
        modelContext.delete(recipe)
        try? modelContext.save()
    }

    // MARK: - Sync Operations

    /// Sync with Firebase backend (upload local changes, download remote changes)
    func sync() async throws {
        guard isOnline else {
            throw SimulatorError.deviceOffline(id)
        }

        // TODO: Implement actual sync logic using FirebaseSyncService
        // For now, this is a placeholder for the sync operation

        // 1. Upload local changes (recipes with needsSync = true)
        let unsyncedRecipes = try fetchUnsyncedRecipes()
        for recipe in unsyncedRecipes {
            try await uploadRecipe(recipe)
        }

        // 2. Download remote changes
        try await downloadRemoteChanges()
    }

    /// Fetch recipes that need syncing
    private func fetchUnsyncedRecipes() throws -> [Recipe] {
        let descriptor = FetchDescriptor<Recipe>()
        let all = try modelContext.fetch(descriptor)
        // Filter recipes that haven't been synced or have been modified since last sync
        return all.filter { recipe in
            recipe.lastSyncedAt == nil || recipe.lastModified > (recipe.lastSyncedAt ?? Date.distantPast)
        }
    }

    /// Upload a recipe to Firebase
    private func uploadRecipe(_ recipe: Recipe) async throws {
        guard isOnline else {
            // Queue for later
            syncQueue.append(.upload(recipe.id))
            return
        }

        // Convert recipe to Firestore data
        let data = FirebaseSyncService.shared.convertToFirestoreData(recipe)

        // Upload to mock Firestore
        let collection = firestore.collection("users/\(userId)/recipes")
        let docRef = collection.document(recipe.id.uuidString)
        try await docRef.setData(data)

        // Mark as synced
        recipe.lastSyncedAt = Date() // CHANGED: needsSync -> lastSyncedAt
        try? modelContext.save()
    }

    /// Download remote changes from Firebase
    private func downloadRemoteChanges() async throws {
        guard isOnline else { return }

        // Fetch all documents from Firestore
        let collection = firestore.collection("users/\(userId)/recipes")
        let snapshot = try await collection.getDocuments()

        for doc in snapshot.documents {
            let data = doc.data()
            let recipeId = UUID(uuidString: doc.documentID) ?? UUID()

            // Check if recipe exists locally
            if let existingRecipe = fetchRecipe(id: recipeId) {
                // Merge changes (simplified - real implementation uses CRDT)
                mergeRemoteData(data, into: existingRecipe)
            } else {
                // Create new recipe from remote data
                let newRecipe = FirebaseSyncService.shared.convertFromFirestoreData(
                    data,
                    id: doc.documentID,
                    context: modelContext
                )
                modelContext.insert(newRecipe)
            }
        }

        try modelContext.save()
    }

    /// Merge remote data into local recipe (simplified)
    private func mergeRemoteData(_ data: [String: Any], into recipe: Recipe) {
        // In real implementation, this uses CRDT merge engine
        // For testing purposes, we'll just update if remote is newer

        if let remoteModified = data["lastModified"] as? Date {
            if remoteModified > recipe.lastModified {
                // Remote is newer, update local
                if let title = data["title"] as? String {
                    recipe.title = title
                }
                if let notes = data["notes"] as? String {
                    recipe.notes = notes
                }
                recipe.lastModified = remoteModified
            }
        }
    }

    // MARK: - Network Simulation

    /// Simulate device going offline
    func goOffline() {
        isOnline = false
    }

    /// Simulate device coming back online
    func goOnline() {
        isOnline = true
    }

    /// Process queued sync operations (when back online)
    func processSyncQueue() async throws {
        guard isOnline else { return }

        for operation in syncQueue {
            switch operation {
            case .upload(let recipeId):
                if let recipe = fetchRecipe(id: recipeId) {
                    try await uploadRecipe(recipe)
                }
            case .download:
                try await downloadRemoteChanges()
            }
        }

        syncQueue.removeAll()
    }

    // MARK: - Cleanup

    func reset() {
        try? modelContext.delete(model: Recipe.self)
        try? modelContext.save()
        syncQueue.removeAll()
        isOnline = true
    }
}

/// Sync operation types
enum SyncOperation {
    case upload(UUID)  // Recipe ID to upload
    case download      // Download all remote changes
}

/// Simulator errors
enum SimulatorError: Error, LocalizedError {
    case deviceNotFound(String)
    case deviceOffline(String)
    case syncFailed(String)

    var errorDescription: String? {
        switch self {
        case .deviceNotFound(let id):
            return "Device not found: \(id)"
        case .deviceOffline(let id):
            return "Device is offline: \(id)"
        case .syncFailed(let reason):
            return "Sync failed: \(reason)"
        }
    }
}

// MARK: - Test Helpers

extension MultiDeviceSimulator {
    /// Create a standard test scenario with 2 devices
    func createTwoDeviceScenario() throws -> (device1: SimulatedDevice, device2: SimulatedDevice) {
        let device1 = try createDevice(id: "iPhone", userId: "user-1")
        let device2 = try createDevice(id: "iPad", userId: "user-1")
        return (device1, device2)
    }

    /// Create a standard test scenario with 3 devices
    func createThreeDeviceScenario() throws -> (device1: SimulatedDevice, device2: SimulatedDevice, device3: SimulatedDevice) {
        let device1 = try createDevice(id: "iPhone", userId: "user-1")
        let device2 = try createDevice(id: "iPad", userId: "user-1")
        let device3 = try createDevice(id: "Mac", userId: "user-1")
        return (device1, device2, device3)
    }

    /// Verify all devices have the same recipe count
    func assertRecipeCountConsistent(expectedCount: Int, file: StaticString = #filePath, line: UInt = #line) throws {
        for device in devices.values {
            let descriptor = FetchDescriptor<Recipe>()
            let recipes = try device.modelContext.fetch(descriptor)

            if recipes.count != expectedCount {
                XCTFail("Device \(device.id) has \(recipes.count) recipes, expected \(expectedCount)", file: file, line: line)
            }
        }
    }

    /// Verify a recipe exists on all devices with the same title
    func assertRecipeExistsOnAllDevices(id: UUID, expectedTitle: String, file: StaticString = #filePath, line: UInt = #line) {
        for device in devices.values {
            guard let recipe = device.fetchRecipe(id: id) else {
                XCTFail("Device \(device.id) does not have recipe \(id)", file: file, line: line)
                continue
            }

            if recipe.title != expectedTitle {
                XCTFail("Device \(device.id) has recipe title '\(recipe.title)', expected '\(expectedTitle)'", file: file, line: line)
            }
        }
    }
}
