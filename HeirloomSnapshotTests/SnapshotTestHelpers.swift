import SnapshotTesting
import SwiftUI
import SwiftData
import XCTest
import Combine
import FirebaseAuth
@testable import Heirloom

// MARK: - Device Configurations

extension ViewImageConfig {
    /// iPhone 16 (393×852 @3x, Dynamic Island safe area)
    static let iPhone16 = ViewImageConfig(
        safeArea: UIEdgeInsets(top: 59, left: 0, bottom: 34, right: 0),
        size: CGSize(width: 393, height: 852),
        traits: UITraitCollection(traitsFrom: [
            .init(userInterfaceStyle: .light),
            .init(displayScale: 3),
            .init(userInterfaceIdiom: .phone),
        ])
    )

    /// iPhone SE 3rd gen (375×667 @2x, classic status bar)
    static let iPhoneSE3 = ViewImageConfig(
        safeArea: UIEdgeInsets(top: 20, left: 0, bottom: 0, right: 0),
        size: CGSize(width: 375, height: 667),
        traits: UITraitCollection(traitsFrom: [
            .init(userInterfaceStyle: .light),
            .init(displayScale: 2),
            .init(userInterfaceIdiom: .phone),
        ])
    )
}

// MARK: - Mock Auth Service

@MainActor
final class MockSnapshotAuth: FirebaseAuthServiceProtocol {
    nonisolated(unsafe) let objectWillChange = ObservableObjectPublisher()

    var isAuthenticated: Bool = false
    var currentUser: User? = nil
    var currentUserId: String? = nil
    var currentUserEmail: String? = nil
    var isAuthenticating: Bool = false
    var authError: Error? = nil
    var isEmailUser: Bool = false
    var isEmailVerified: Bool = false

    func signInWithApple() async throws {}
    func signInWithGoogle() async throws {}
    func signInWithEmail(email: String, password: String) async throws {}
    func createAccountWithEmail(email: String, password: String) async throws {}
    func sendPasswordReset(email: String) async throws {}
    func signOut() throws {}
    func deleteAccount() async throws {}
    func resendVerificationEmail() async throws {}
    func refreshEmailVerificationStatus() async {}

    static func signedOut() -> MockSnapshotAuth { MockSnapshotAuth() }

    static func authenticated() -> MockSnapshotAuth {
        let mock = MockSnapshotAuth()
        mock.isAuthenticated = true
        mock.currentUserId = "snapshot-user-id"
        mock.currentUserEmail = "test@example.com"
        return mock
    }
}

// MARK: - Mock Sync Service
// NOTE: FirebaseSyncServiceProtocol has many methods. Stubs below cover
// the known protocol surface. If compilation fails with "does not conform",
// add the missing method stubs here.

@MainActor
final class MockSnapshotSync: FirebaseSyncServiceProtocol {
    nonisolated(unsafe) let objectWillChange = ObservableObjectPublisher()

    func configure(modelContext: ModelContext) {}
    func uploadRecipe(_ recipe: Recipe) async throws {}
    func uploadRecipeTransactional(_ recipe: Recipe) async throws {}
    func downloadRecipe(id: String, context: ModelContext) async throws -> Recipe {
        fatalError("Not implemented for snapshot tests")
    }
    func downloadAllRecipes(context: ModelContext) async throws -> [Recipe] { [] }
    func syncChanges() async throws {}
    func syncChangesWithCRDT() async throws {}
    func deleteRecipe(_ recipeId: UUID) async throws {}
    func startAutomaticSync() {}
    func stopAutomaticSync() {}
    func convertFromFirestoreData(_ data: [String: Any], id: String, context: ModelContext) -> Recipe {
        fatalError("Not implemented for snapshot tests")
    }
    func convertIngredientFromFirestoreData(_ data: [String: Any], id: String) -> Ingredient {
        fatalError("Not implemented for snapshot tests")
    }
    func convertCommentFromFirestoreData(_ data: [String: Any], id: String) -> RecipeComment {
        fatalError("Not implemented for snapshot tests")
    }
    func convertCardBackFromFirestoreData(_ data: [String: Any]) -> RecipeCardBack {
        fatalError("Not implemented for snapshot tests")
    }
    func uploadImage(for recipe: Recipe) async throws -> String? { nil }
    func deleteImage(for recipeId: UUID) async throws {}
    func downloadImage(for recipe: Recipe) async throws {}
    func uploadTag(_ tag: Tag) async throws {}
    func deleteTag(_ tagId: UUID) async throws {}
    func uploadCollection(_ collection: RecipeCollection) async throws {}
    func deleteCollection(_ collectionId: UUID) async throws {}
    func uploadDinnerParty(_ party: DinnerParty) async throws {}
    func deleteDinnerParty(_ partyId: UUID) async throws {}
    func uploadCardBack(_ cardBack: RecipeCardBack, recipeId: UUID) async throws {}
}

// MARK: - Mock Lineage Service

@MainActor
final class MockSnapshotLineage: FirebaseLineageServiceProtocol {
    nonisolated(unsafe) let objectWillChange = ObservableObjectPublisher()

    func createRootLineage(recipeId: UUID, context: ModelContext) async throws {}
    func createDescendantLineage(
        rootRecipeId: UUID, parentRecipeId: UUID, currentRecipeId: UUID,
        rootOwnerId: String, generation: Int, sharedByName: String?,
        context: ModelContext
    ) async throws {}
    func recordModification(
        recipeId: UUID, changeType: ModificationRecord.ChangeType,
        changeDescription: String, fieldChanged: String?,
        context: ModelContext
    ) async throws {}
    func fetchLineage(for recipeId: UUID, context: ModelContext) throws -> RecipeLineage? { nil }
    func fetchDescendantModifications(for rootRecipeId: UUID) async throws -> [DescendantModification] { [] }
}

// MARK: - Snapshot Test Base Class

@MainActor
class SnapshotTestCase: XCTestCase {
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var mockAuth: MockSnapshotAuth!
    var mockSync: MockSnapshotSync!
    var mockLineage: MockSnapshotLineage!

    /// Set via SNAPSHOT_RECORD=true environment variable to record golden images
    var isRecording: Bool {
        ProcessInfo.processInfo.environment["SNAPSHOT_RECORD"] == "true"
    }

    override func setUp() async throws {
        try await super.setUp()

        // In-memory SwiftData container with models used by snapshot views.
        // RecipeGenerationJob and SyncJob are excluded due to @Model visibility
        // issues across test target boundaries.
        let schema = Schema([
            Recipe.self,
            RecipeCollection.self,
            Ingredient.self,
            RecipeTheme.self,
            ImportJob.self,
            ImportItem.self,
            VideoProcessingJob.self,
            UserCredits.self,
            RecipeLineage.self,
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [config])
        modelContext = ModelContext(modelContainer)

        mockAuth = MockSnapshotAuth.signedOut()
        mockSync = MockSnapshotSync()
        mockLineage = MockSnapshotLineage()

        // Register commonly needed services in ServiceContainer
        ServiceContainer.shared.register(ToastManager.self, instance: ToastManager())
    }

    override func tearDown() async throws {
        ServiceContainer.shared.reset()
        modelContainer = nil
        modelContext = nil
        mockAuth = nil
        mockSync = nil
        mockLineage = nil
        try await super.tearDown()
    }

    // MARK: - Snapshot Helpers

    /// Wraps a SwiftUI view with common environment dependencies and snapshots at both device sizes.
    func assertBothDevices<V: View>(
        _ view: V,
        named name: String,
        file: StaticString = #file,
        testName: String = #function,
        line: UInt = #line
    ) {
        let wrapped = view
            .modelContainer(modelContainer)
            .environment(\.firebaseAuth, mockAuth)
            .environment(\.firebaseSync, mockSync)
            .environment(\.firebaseLineage, mockLineage)

        let iPhone16VC = UIHostingController(rootView: wrapped)
        assertSnapshot(
            of: iPhone16VC,
            as: .image(on: .iPhone16),
            named: "\(name)_iPhone16",
            record: isRecording,
            file: file,
            testName: testName,
            line: line
        )

        let iPhoneSEVC = UIHostingController(rootView: wrapped)
        assertSnapshot(
            of: iPhoneSEVC,
            as: .image(on: .iPhoneSE3),
            named: "\(name)_iPhoneSE3",
            record: isRecording,
            file: file,
            testName: testName,
            line: line
        )
    }

    // MARK: - Test Data Factories

    func createTestRecipe(
        title: String = "Grandma's Apple Pie",
        servings: String = "8 servings",
        prepTime: String = "30 min",
        cookTime: String = "45 min",
        notes: String? = nil
    ) -> Recipe {
        let recipe = Recipe()
        recipe.title = title
        recipe.servings = servings
        recipe.prepTime = prepTime
        recipe.cookTime = cookTime
        recipe.notes = notes
        recipe.dateAdded = Date()
        modelContext.insert(recipe)
        return recipe
    }

    func createTestTheme(
        firebaseId: String,
        name: String,
        tagline: String = "A culinary journey",
        category: ThemeCategory,
        sortOrder: Int = 0
    ) -> RecipeTheme {
        let theme = RecipeTheme(
            firebaseId: firebaseId,
            name: name,
            tagline: tagline,
            themeDescription: "Test theme description",
            iconName: "fork.knife",
            category: category,
            totalRecipes: 14,
            unlockSchedule: Array(1...14)
        )
        theme.sortOrder = sortOrder
        modelContext.insert(theme)
        return theme
    }

    func createTestImportJob(
        name: String = "Test Import",
        status: ImportJobStatus = .processing,
        itemCount: Int = 3
    ) -> ImportJob {
        let job = ImportJob(jobName: name, continueOnError: true)
        job.status = status
        var items: [ImportItem] = []
        for i in 0..<itemCount {
            let item = ImportItem(urlString: "https://example.com/recipe-\(i)")
            item.status = status == .completed ? .success : .pending
            items.append(item)
        }
        job.items = items
        modelContext.insert(job)
        return job
    }

    func createTestVideoJob(
        status: VideoProcessingStatus = .processing
    ) -> VideoProcessingJob {
        let job = VideoProcessingJob(
            videoURL: "file:///test/video.mp4",
            videoType: .standard
        )
        job.status = status
        modelContext.insert(job)
        return job
    }

    func saveContext() throws {
        try modelContext.save()
    }
}
