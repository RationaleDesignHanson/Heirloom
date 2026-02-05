//
//  PublicRecipeService.swift
//  Heirloom
//
//  Service for publishing and unpublishing recipes to public discovery
//  Phase 3: PublicRecipeService with camera-only validation
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage

// MARK: - Protocol

/// Service for managing public recipe publishing
@MainActor
protocol PublicRecipeServiceProtocol {
    /// Publish a recipe to public discovery
    func publishRecipe(_ recipe: Recipe) async throws -> String

    /// Unpublish a recipe from public discovery
    func unpublishRecipe(_ recipe: Recipe) async throws

    /// Check if a recipe can be published (with detailed reason if not)
    func validatePublishing(_ recipe: Recipe) -> (canPublish: Bool, reason: String?)
}

// MARK: - Errors

enum PublishError: LocalizedError {
    case notAuthenticated
    case notEligible(reason: String)
    case missingImage
    case imageUploadFailed
    case firestoreError(Error)
    case recipeNotPublished

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be signed in to publish recipes."
        case .notEligible(let reason):
            return reason
        case .missingImage:
            return "Recipes must have a photo to be shared publicly."
        case .imageUploadFailed:
            return "Failed to upload recipe image. Please try again."
        case .firestoreError(let error):
            return "Failed to publish recipe: \(error.localizedDescription)"
        case .recipeNotPublished:
            return "This recipe is not currently published."
        }
    }
}

// MARK: - Implementation

/// Firebase implementation of public recipe service
@MainActor
class FirebasePublicRecipeService: PublicRecipeServiceProtocol {

    // MARK: - Dependencies

    private let db: Firestore
    private let auth: Auth
    private let storage: Storage
    private let profileService: ProfileServiceProtocol
    private let imageService: ImageStorageService

    // MARK: - Initialization

    init(
        firestore: Firestore = Firestore.firestore(),
        auth: Auth = Auth.auth(),
        storage: Storage = Storage.storage(),
        profileService: ProfileServiceProtocol,
        imageService: ImageStorageService
    ) {
        self.db = firestore
        self.auth = auth
        self.storage = storage
        self.profileService = profileService
        self.imageService = imageService
    }

    // MARK: - Public Methods

    /// Publish a recipe to public discovery
    /// - Parameter recipe: The recipe to publish
    /// - Returns: The publicRecipeId (Firestore document ID)
    /// - Throws: PublishError if validation fails or upload errors occur
    func publishRecipe(_ recipe: Recipe) async throws -> String {
        // Check authentication
        guard let userId = auth.currentUser?.uid else {
            Log.error("Publish failed: Not authenticated", category: .social)
            throw PublishError.notAuthenticated
        }

        // Validate eligibility
        let (canPublish, reason) = validatePublishing(recipe)
        guard canPublish else {
            Log.warning("Publish blocked", category: .social, metadata: [
                "recipeId": recipe.id.uuidString,
                "reason": reason ?? "unknown"
            ])
            throw PublishError.notEligible(reason: reason ?? "This recipe cannot be shared publicly.")
        }

        // Check for image
        guard let imageFileName = recipe.imageFileName else {
            Log.error("Publish failed: Missing image", category: .social, metadata: [
                "recipeId": recipe.id.uuidString
            ])
            throw PublishError.missingImage
        }

        // Upload image to Firebase Storage
        let imageURL: String
        do {
            imageURL = try await uploadRecipeImage(recipeId: recipe.id.uuidString, fileName: imageFileName)
        } catch {
            Log.error("Image upload failed", category: .social, metadata: [
                "recipeId": recipe.id.uuidString,
                "error": error.localizedDescription
            ])
            throw PublishError.imageUploadFailed
        }

        // Fetch user profile for creator info
        let profile = try await profileService.fetchCurrentUserProfile()

        // Create PublicRecipe document
        let publicRecipeId = UUID().uuidString
        let publicRecipe = createPublicRecipe(
            from: recipe,
            publicRecipeId: publicRecipeId,
            ownerId: userId,
            imageURL: imageURL,
            creatorProfile: profile
        )

        // Save to Firestore
        do {
            let data = publicRecipe.toFirestoreData()
            try await db.collection("publicRecipes").document(publicRecipeId).setData(data)

            Log.info("Recipe published successfully", category: .social, metadata: [
                "recipeId": recipe.id.uuidString,
                "publicRecipeId": publicRecipeId,
                "title": recipe.title
            ])

            // Track analytics
            DiscoveryAnalytics.trackRecipePublished(
                recipeId: recipe.id.uuidString,
                publicRecipeId: publicRecipeId,
                sourceType: recipe.sourceType?.rawValue ?? "unknown",
                cameraConfidence: recipe.cameraOriginConfidence.rawValue
            )

            return publicRecipeId

        } catch {
            Log.error("Firestore publish failed", category: .social, metadata: [
                "recipeId": recipe.id.uuidString,
                "error": error.localizedDescription
            ])
            throw PublishError.firestoreError(error)
        }
    }

    /// Unpublish a recipe from public discovery
    /// - Parameter recipe: The recipe to unpublish
    /// - Throws: PublishError if recipe not published or deletion fails
    func unpublishRecipe(_ recipe: Recipe) async throws {
        guard let publicRecipeId = recipe.publicRecipeId else {
            Log.warning("Unpublish attempted on non-published recipe", category: .social, metadata: [
                "recipeId": recipe.id.uuidString
            ])
            throw PublishError.recipeNotPublished
        }

        guard auth.currentUser?.uid != nil else {
            throw PublishError.notAuthenticated
        }

        // Delete from Firestore
        do {
            try await db.collection("publicRecipes").document(publicRecipeId).delete()

            Log.info("Recipe unpublished successfully", category: .social, metadata: [
                "recipeId": recipe.id.uuidString,
                "publicRecipeId": publicRecipeId
            ])

            // Track analytics
            DiscoveryAnalytics.trackRecipeUnpublished(
                recipeId: recipe.id.uuidString,
                publicRecipeId: publicRecipeId
            )

        } catch {
            Log.error("Firestore unpublish failed", category: .social, metadata: [
                "recipeId": recipe.id.uuidString,
                "publicRecipeId": publicRecipeId,
                "error": error.localizedDescription
            ])
            throw PublishError.firestoreError(error)
        }

        // Note: We keep the image in Storage for now (storage is cheap)
        // Could add cleanup in a scheduled Cloud Function if needed
    }

    /// Validate if a recipe can be published
    /// - Parameter recipe: The recipe to validate
    /// - Returns: Tuple with canPublish boolean and optional reason if blocked
    func validatePublishing(_ recipe: Recipe) -> (canPublish: Bool, reason: String?) {
        // Use recipe's built-in validation
        if !recipe.canMakePublic {
            let reason = recipe.publicSharingBlockedReason() ?? "This recipe cannot be shared publicly."
            return (false, reason)
        }

        // Additional validation: Must have attested to ownership
        if recipe.publisherAttestationAcceptedAt == nil {
            return (false, "Please confirm ownership before publishing.")
        }

        // Additional validation: Must have image
        if recipe.imageFileName == nil {
            return (false, "Recipes must have a photo to be shared publicly.")
        }

        // Additional validation: Must have title
        if recipe.title.trimmingCharacters(in: .whitespaces).isEmpty {
            return (false, "Recipe must have a title to be shared publicly.")
        }

        // Additional validation: Must have at least one ingredient
        if let ingredients = recipe.ingredients, ingredients.isEmpty {
            return (false, "Recipe must have at least one ingredient to be shared publicly.")
        }

        return (true, nil)
    }

    // MARK: - Private Helpers

    /// Upload recipe image to Firebase Storage
    private func uploadRecipeImage(recipeId: String, fileName: String) async throws -> String {
        // Load image from local storage
        guard let image = await imageService.loadImage(fileName: fileName),
              let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw PublishError.missingImage
        }

        // Upload to Firebase Storage
        let storagePath = "publicRecipes/\(recipeId)/image.jpg"
        let storageRef = storage.reference().child(storagePath)

        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        _ = try await storageRef.putDataAsync(imageData, metadata: metadata)

        // Get download URL
        let downloadURL = try await storageRef.downloadURL()
        return downloadURL.absoluteString
    }

    /// Create PublicRecipe from Recipe
    private func createPublicRecipe(
        from recipe: Recipe,
        publicRecipeId: String,
        ownerId: String,
        imageURL: String,
        creatorProfile: UserProfile
    ) -> PublicRecipe {
        // Extract ingredient names with quantities
        let ingredientNames: [String] = recipe.ingredients?.compactMap { ingredient -> String in
            var parts: [String] = []

            // Add quantity if present
            if let quantity = ingredient.quantity, quantity > 0 {
                // Format quantity nicely (remove .0 for whole numbers)
                let quantityStr = quantity.truncatingRemainder(dividingBy: 1) == 0
                    ? String(Int(quantity))
                    : String(quantity)
                parts.append(quantityStr)
            }

            // Add unit if present
            if let unit = ingredient.unit, !unit.isEmpty {
                parts.append(unit)
            }

            // Add name
            parts.append(ingredient.name)

            return parts.joined(separator: " ")
        } ?? []

        // Generate search keywords
        let searchKeywords = PublicRecipe.generateSearchKeywords(
            title: recipe.title,
            ingredients: ingredientNames,
            creatorName: creatorProfile.displayName
        )

        return PublicRecipe(
            id: publicRecipeId,
            sourceRecipeId: recipe.id.uuidString,
            ownerId: ownerId,
            title: recipe.title,
            description: recipe.notes,
            imageURL: imageURL,
            ingredients: ingredientNames,
            category: recipe.recipeCategory,
            tags: recipe.tags?.compactMap { $0.name } ?? [],
            servings: recipe.servings,
            prepTime: recipe.prepTime,
            cookTime: recipe.cookTime,
            creatorName: creatorProfile.displayName,
            creatorPhotoURL: creatorProfile.photoURL,
            creatorProfileSlug: creatorProfile.publicProfileSlug,
            viewCount: 0,
            saveCount: 0,
            searchKeywords: searchKeywords,
            isHidden: false,
            reportCount: 0,
            moderationStatus: nil,
            publishedAt: Date(),
            updatedAt: Date()
        )
    }
}

// MARK: - Analytics

enum DiscoveryAnalytics {
    static func trackRecipePublished(
        recipeId: String,
        publicRecipeId: String,
        sourceType: String,
        cameraConfidence: String
    ) {
        // TODO: Implement analytics tracking
        // Analytics.track("recipe_published", properties: [...])
    }

    static func trackRecipeUnpublished(
        recipeId: String,
        publicRecipeId: String
    ) {
        // TODO: Implement analytics tracking
        // Analytics.track("recipe_unpublished", properties: [...])
    }
}
