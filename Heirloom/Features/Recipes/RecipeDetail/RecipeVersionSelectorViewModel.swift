import SwiftUI
import SwiftData
import FirebaseFirestore
import FirebaseAuth

@MainActor
class RecipeVersionSelectorViewModel: ObservableObject {
    @Published var versions: [RecipeLineageVersion] = []
    @Published var selectedVersion: RecipeLineageVersion?
    @Published var isLoading = false
    @Published var error: String?

    private lazy var db: Firestore = {
        // Use shared Firestore instance (configured by FirebaseSyncService)
        Firestore.firestore()
    }()

    /// Load all versions of a recipe (original + all descendant modifications)
    func loadVersions(for recipe: Recipe, context: ModelContext) async {
        print("🔍 [VersionSelector] loadVersions() called for: \(recipe.title)")
        isLoading = true
        error = nil

        do {
            // 1. Check if this recipe has lineage tracking
            guard let lineage = try? await fetchLineage(for: recipe.id) else {
                // No lineage tracking - this is a standalone recipe
                print("⚠️ [VersionSelector] No lineage found - standalone recipe")
                let currentVersion = RecipeLineageVersion(
                    recipe: recipe,
                    generation: 0,
                    modifiedBy: nil,
                    modifiedByName: nil,
                    modifiedAt: recipe.lastModified,
                    isCurrent: true
                )
                versions = [currentVersion]
                selectedVersion = currentVersion
                isLoading = false
                return
            }

            // 2. This recipe has lineage - fetch all versions in the family tree
            var allVersions: [RecipeLineageVersion] = []

            // Add current local version
            let currentVersion = RecipeLineageVersion(
                recipe: recipe,
                generation: lineage.generation,
                modifiedBy: lineage.ownerId,
                modifiedByName: lineage.sharedByName,
                modifiedAt: recipe.lastModified,
                isCurrent: true
            )
            allVersions.append(currentVersion)

            // 3. Fetch all other versions from the lineage tree
            let otherVersions = try await fetchOtherVersions(
                rootRecipeId: lineage.rootRecipeId,
                currentRecipeId: recipe.id
            )
            allVersions.append(contentsOf: otherVersions)

            // 4. Sort by generation (root first, then descendants)
            allVersions.sort { $0.generation < $1.generation }

            versions = allVersions

            // 5. Set selected version based on last viewed, or default to current
            if let lastViewedId = recipe.lastViewedVersionId,
               let lastViewed = allVersions.first(where: { $0.recipe?.id == lastViewedId }) {
                selectedVersion = lastViewed
                print("✅ [VersionSelector] Restored last viewed version: \(lastViewed.displayName)")
            } else {
                selectedVersion = currentVersion
                print("✅ [VersionSelector] Defaulting to current version")
            }

        } catch {
            self.error = "Failed to load versions: \(error.localizedDescription)"
            print("❌ [Versions] Error loading versions: \(error)")
        }

        isLoading = false
    }

    // MARK: - Private Helpers

    private func fetchLineage(for recipeId: UUID) async throws -> RecipeLineage? {
        guard Auth.auth().currentUser?.uid != nil else { return nil }

        print("🔍 [VersionSelector] Fetching lineage for recipe: \(recipeId)")

        // Query Firebase for lineage
        let snapshot = try await db.collection("lineages")
            .whereField("currentRecipeId", isEqualTo: recipeId.uuidString)
            .limit(to: 1)
            .getDocuments()

        guard let doc = snapshot.documents.first else {
            print("⚠️ [VersionSelector] No lineage document found in Firebase")
            return nil
        }

        let data = doc.data()
        print("✅ [VersionSelector] Found lineage: generation \(data["generation"] ?? 0)")

        // Create RecipeLineage from Firebase data
        let lineage = RecipeLineage(
            rootRecipeId: UUID(uuidString: data["rootRecipeId"] as? String ?? "") ?? recipeId,
            currentRecipeId: recipeId,
            ownerId: data["ownerId"] as? String ?? "",
            rootOwnerId: data["rootOwnerId"] as? String ?? "",
            generation: data["generation"] as? Int ?? 0
        )
        lineage.firebaseId = doc.documentID
        lineage.sharedByName = data["sharedByName"] as? String

        return lineage
    }

    private func fetchOtherVersions(
        rootRecipeId: UUID,
        currentRecipeId: UUID
    ) async throws -> [RecipeLineageVersion] {
        guard Auth.auth().currentUser?.uid != nil else { return [] }

        print("🔍 [Versions] Fetching versions for root: \(rootRecipeId)")

        // Query all lineages with this root
        let snapshot = try await db.collection("lineages")
            .whereField("rootRecipeId", isEqualTo: rootRecipeId.uuidString)
            .getDocuments()

        var versions: [RecipeLineageVersion] = []

        for doc in snapshot.documents {
            let data = doc.data()
            let recipeIdString = data["currentRecipeId"] as? String ?? ""

            guard let recipeId = UUID(uuidString: recipeIdString),
                  recipeId != currentRecipeId else { continue }

            let ownerId = data["ownerId"] as? String ?? ""
            let generation = data["generation"] as? Int ?? 0

            // Fetch the actual recipe data from Firebase
            if let recipeData = try? await fetchRecipeFromFirebase(
                ownerId: ownerId,
                recipeId: recipeId
            ) {
                let version = RecipeLineageVersion(
                    recipeData: recipeData,
                    generation: generation,
                    modifiedBy: ownerId,
                    modifiedByName: data["sharedByName"] as? String,
                    modifiedAt: (data["lastModified"] as? Timestamp)?.dateValue() ?? Date(),
                    isCurrent: false
                )
                versions.append(version)
            }
        }

        print("✅ [Versions] Found \(versions.count) other versions")
        return versions
    }

    private func fetchRecipeFromFirebase(
        ownerId: String,
        recipeId: UUID
    ) async throws -> [String: Any] {
        let doc = try await db.collection("users/\(ownerId)/recipes")
            .document(recipeId.uuidString)
            .getDocument()

        guard doc.exists, var data = doc.data() else {
            throw NSError(domain: "RecipeVersions", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "Recipe not found"
            ])
        }

        // Fetch ingredients subcollection
        let ingredientsSnapshot = try await db.collection("users/\(ownerId)/recipes")
            .document(recipeId.uuidString)
            .collection("ingredients")
            .getDocuments()

        let ingredients = ingredientsSnapshot.documents.map { $0.data() }
        if !ingredients.isEmpty {
            data["ingredients"] = ingredients
            print("✅ [Versions] Fetched \(ingredients.count) ingredients for recipe")
        }

        return data
    }
}

// MARK: - RecipeLineageVersion Model

struct RecipeLineageVersion: Identifiable, Hashable {
    let id = UUID()
    let recipe: Recipe?
    let recipeData: [String: Any]?
    let generation: Int
    let modifiedBy: String?
    let modifiedByName: String?
    let modifiedAt: Date
    let isCurrent: Bool

    var title: String {
        recipe?.title ?? recipeData?["title"] as? String ?? "Unknown"
    }

    var displayName: String {
        if generation == 0 {
            return "Original"
        } else if isCurrent {
            return "Your Version (Gen \(generation))"
        } else {
            let name = modifiedByName ?? "Someone"
            return "\(name)'s Version (Gen \(generation))"
        }
    }

    init(recipe: Recipe, generation: Int, modifiedBy: String?, modifiedByName: String?, modifiedAt: Date, isCurrent: Bool) {
        self.recipe = recipe
        self.recipeData = nil
        self.generation = generation
        self.modifiedBy = modifiedBy
        self.modifiedByName = modifiedByName
        self.modifiedAt = modifiedAt
        self.isCurrent = isCurrent
    }

    init(recipeData: [String: Any], generation: Int, modifiedBy: String?, modifiedByName: String?, modifiedAt: Date, isCurrent: Bool) {
        self.recipe = nil
        self.recipeData = recipeData
        self.generation = generation
        self.modifiedBy = modifiedBy
        self.modifiedByName = modifiedByName
        self.modifiedAt = modifiedAt
        self.isCurrent = isCurrent
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: RecipeLineageVersion, rhs: RecipeLineageVersion) -> Bool {
        lhs.id == rhs.id
    }
}
