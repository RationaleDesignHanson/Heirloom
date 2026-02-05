import Foundation
import SwiftData

// MARK: - Undo Service
/// Service for managing undo functionality for destructive actions
/// Provides temporary storage and restore capabilities for deleted items
@MainActor
class UndoService: ObservableObject {

    /// Default undo window duration (5 seconds)
    nonisolated static let defaultUndoWindow: TimeInterval = 5.0

    // MARK: - Dependencies

    private let analytics: AnalyticsService
    private let backendConfig: BackendConfig
    private let firebaseSync: FirebaseSyncService

    // MARK: - Recipe Undo Data
    /// Captures all recipe data needed for undo restoration
    /// IMPORTANT: After context.delete(), SwiftData objects become invalid,
    /// so we must store all data as simple values before deletion
    struct RecipeUndoData {
        // Identity
        let id: UUID
        let title: String
        let dateAdded: Date
        let lastModified: Date

        // Source Information
        let sourceType: RecipeSourceType?
        let sourceURL: String?
        let sourceBookTitle: String?
        let sourceBookAuthor: String?
        let sourceBookPage: Int?
        let sourcePerson: String?
        let sourceDate: String?
        let sourceStory: String?
        let sourceCookbook: String?
        let sourceImportItemID: UUID?
        let sourceRecipeIndex: Int?

        // Content
        let imageFileName: String?
        let sourceImageURL: String?
        let firebaseImageURL: String?

        // Theme Collections
        let isThemeRecipe: Bool
        let themeRecipeId: String?
        let sourceThemeId: String?
        let unlockDay: Int?
        let blurhash: String?
        let imageVariants: [String: String]?
        let historicalText: String?
        let historicalContext: String?

        // Ingredients (stored as snapshots)
        let ingredientSnapshots: [IngredientUndoData]

        // Recipe Content
        let instructions: [String]
        let servings: String?
        let prepTime: String?
        let cookTime: String?
        let totalTime: String?
        let notes: String?
        let originalSnapshotData: Data?

        // Metadata
        let timesCooked: Int
        let lastCooked: Date?
        let lastViewed: Date?
        let hasBeenViewed: Bool
        let isFavorite: Bool
        let isInShoppingList: Bool
        let contentHash: String?

        // Scaling
        let scalabilityRating: String
        let recipeCategory: String?
        let minimumServings: Int
        let maximumServings: Int?
        let scalingNote: String?

        // Collection IDs (for relationship restoration)
        let collectionIds: [UUID]

        // Social
        let sharedBy: String?
        let sharedDate: Date?
        let passedDownBy: String?
        let passedDownDate: Date?
        let passedDownMessage: String?
        let generationCount: Int

        // AI/Voice
        let aiGenerated: Bool
        let voiceDictated: Bool

        // Public Discovery
        let isPublic: Bool
        let publicRecipeId: String?
        let publicPublishedAt: Date?
        let publicViewCount: Int
        let publicSaveCount: Int
        let cameraOriginConfidence: CameraOriginConfidence
        let sourcePublicRecipeId: String?
        let sourcePublicRecipeCreatorId: String?
        let sourcePublicRecipeCreatorName: String?
        let sourcePublicRecipeLastSynced: Date?
        let sourcePublicRecipeStillAvailable: Bool

        // Provenance
        let provenance: ProvenanceMetadata?

        // Sync Metadata
        let cloudKitRecordID: String?
        let firebaseId: String?
        let lastSyncedAt: Date?
        let modifiedAt: Date
        let createdAt: Date

        // CRDT
        let usesCRDT: Bool
        let lastModifiedByDevice: String?
        let vectorClockData: Data?
        let pendingOperationsData: Data?
        let hasPendingConflicts: Bool
        let showConflictBadge: Bool

        // Multilingual
        let sourceLanguage: String?
        let sourceLanguageConfidence: Double?
        let originalTitle: String?
        let originalInstructions: [String]?
        let translatedTitle: String?
        let translatedInstructions: [String]?
        let detectedUnitSystem: String?
        let preferOriginalLanguage: Bool
        let translationQuality: String?
        let translatedAt: Date?

        // Sharing
        let sharingPermissionRaw: String

        /// Create from a Recipe object (call BEFORE delete)
        static func from(_ recipe: Recipe) -> RecipeUndoData {
            RecipeUndoData(
                id: recipe.id,
                title: recipe.title,
                dateAdded: recipe.dateAdded,
                lastModified: recipe.lastModified,
                sourceType: recipe.sourceType,
                sourceURL: recipe.sourceURL,
                sourceBookTitle: recipe.sourceBookTitle,
                sourceBookAuthor: recipe.sourceBookAuthor,
                sourceBookPage: recipe.sourceBookPage,
                sourcePerson: recipe.sourcePerson,
                sourceDate: recipe.sourceDate,
                sourceStory: recipe.sourceStory,
                sourceCookbook: recipe.sourceCookbook,
                sourceImportItemID: recipe.sourceImportItemID,
                sourceRecipeIndex: recipe.sourceRecipeIndex,
                imageFileName: recipe.imageFileName,
                sourceImageURL: recipe.sourceImageURL,
                firebaseImageURL: recipe.firebaseImageURL,
                isThemeRecipe: recipe.isThemeRecipe,
                themeRecipeId: recipe.themeRecipeId,
                sourceThemeId: recipe.sourceThemeId,
                unlockDay: recipe.unlockDay,
                blurhash: recipe.blurhash,
                imageVariants: recipe.imageVariants,
                historicalText: recipe.historicalText,
                historicalContext: recipe.historicalContext,
                ingredientSnapshots: (recipe.ingredients ?? []).map { IngredientUndoData.from($0) },
                instructions: recipe.instructions,
                servings: recipe.servings,
                prepTime: recipe.prepTime,
                cookTime: recipe.cookTime,
                totalTime: recipe.totalTime,
                notes: recipe.notes,
                originalSnapshotData: recipe.originalSnapshotData,
                timesCooked: recipe.timesCooked,
                lastCooked: recipe.lastCooked,
                lastViewed: recipe.lastViewed,
                hasBeenViewed: recipe.hasBeenViewed,
                isFavorite: recipe.isFavorite,
                isInShoppingList: recipe.isInShoppingList,
                contentHash: recipe.contentHash,
                scalabilityRating: recipe.scalabilityRating,
                recipeCategory: recipe.recipeCategory,
                minimumServings: recipe.minimumServings,
                maximumServings: recipe.maximumServings,
                scalingNote: recipe.scalingNote,
                collectionIds: (recipe.collections ?? []).map { $0.id },
                sharedBy: recipe.sharedBy,
                sharedDate: recipe.sharedDate,
                passedDownBy: recipe.passedDownBy,
                passedDownDate: recipe.passedDownDate,
                passedDownMessage: recipe.passedDownMessage,
                generationCount: recipe.generationCount,
                aiGenerated: recipe.aiGenerated,
                voiceDictated: recipe.voiceDictated,
                isPublic: recipe.isPublic,
                publicRecipeId: recipe.publicRecipeId,
                publicPublishedAt: recipe.publicPublishedAt,
                publicViewCount: recipe.publicViewCount,
                publicSaveCount: recipe.publicSaveCount,
                cameraOriginConfidence: recipe.cameraOriginConfidence,
                sourcePublicRecipeId: recipe.sourcePublicRecipeId,
                sourcePublicRecipeCreatorId: recipe.sourcePublicRecipeCreatorId,
                sourcePublicRecipeCreatorName: recipe.sourcePublicRecipeCreatorName,
                sourcePublicRecipeLastSynced: recipe.sourcePublicRecipeLastSynced,
                sourcePublicRecipeStillAvailable: recipe.sourcePublicRecipeStillAvailable,
                provenance: recipe.provenance,
                cloudKitRecordID: recipe.cloudKitRecordID,
                firebaseId: recipe.firebaseId,
                lastSyncedAt: recipe.lastSyncedAt,
                modifiedAt: recipe.modifiedAt,
                createdAt: recipe.createdAt,
                usesCRDT: recipe.usesCRDT,
                lastModifiedByDevice: recipe.lastModifiedByDevice,
                vectorClockData: recipe.vectorClockData,
                pendingOperationsData: recipe.pendingOperationsData,
                hasPendingConflicts: recipe.hasPendingConflicts,
                showConflictBadge: recipe.showConflictBadge,
                sourceLanguage: recipe.sourceLanguage,
                sourceLanguageConfidence: recipe.sourceLanguageConfidence,
                originalTitle: recipe.originalTitle,
                originalInstructions: recipe.originalInstructions,
                translatedTitle: recipe.translatedTitle,
                translatedInstructions: recipe.translatedInstructions,
                detectedUnitSystem: recipe.detectedUnitSystem,
                preferOriginalLanguage: recipe.preferOriginalLanguage,
                translationQuality: recipe.translationQuality,
                translatedAt: recipe.translatedAt,
                sharingPermissionRaw: recipe.sharingPermissionRaw
            )
        }
    }

    // MARK: - Ingredient Undo Data
    struct IngredientUndoData {
        let id: UUID
        let originalText: String
        let name: String
        let quantity: Double?
        let quantityMax: Double?
        let unit: String?
        let normalizedUnit: String?
        let preparation: String?
        let size: String?
        let category: GroceryCategory?
        let orderIndex: Int
        let isSelected: Bool
        let isCheckedOff: Bool
        let isOptional: Bool

        // Multilingual support
        let originalLanguageName: String?
        let translatedName: String?
        let originalLanguageUnit: String?
        let convertedQuantity: Double?
        let convertedUnit: String?
        let conversionNote: String?
        let wasConverted: Bool

        static func from(_ ingredient: Ingredient) -> IngredientUndoData {
            IngredientUndoData(
                id: ingredient.id,
                originalText: ingredient.originalText,
                name: ingredient.name,
                quantity: ingredient.quantity,
                quantityMax: ingredient.quantityMax,
                unit: ingredient.unit,
                normalizedUnit: ingredient.normalizedUnit,
                preparation: ingredient.preparation,
                size: ingredient.size,
                category: ingredient.category,
                orderIndex: ingredient.orderIndex,
                isSelected: ingredient.isSelected,
                isCheckedOff: ingredient.isCheckedOff,
                isOptional: ingredient.isOptional,
                originalLanguageName: ingredient.originalLanguageName,
                translatedName: ingredient.translatedName,
                originalLanguageUnit: ingredient.originalLanguageUnit,
                convertedQuantity: ingredient.convertedQuantity,
                convertedUnit: ingredient.convertedUnit,
                conversionNote: ingredient.conversionNote,
                wasConverted: ingredient.wasConverted
            )
        }
    }

    // MARK: - Recipe Undo Item
    struct UndoItem: Identifiable {
        let id = UUID()
        let recipeData: RecipeUndoData
        let expirationDate: Date
        let description: String

        var isExpired: Bool {
            Date() > expirationDate
        }

        /// Recipe ID for pending check
        var recipeId: UUID { recipeData.id }
    }

    // MARK: - Collection Undo Data
    /// Captures all collection data needed for undo restoration
    struct CollectionUndoData {
        let id: UUID
        let name: String
        let desc: String?
        let iconName: String
        let color: String
        let isSystemCollection: Bool
        let isAllRecipes: Bool
        let type: CollectionType
        let createdDate: Date
        let lastViewedDate: Date?
        let sourceThemeId: String?
        let sourceCookbook: String?
        let sourceAuthor: String?
        let sourceURL: String?
        let customBackgroundImagePath: String?
        let generatedBackgroundImagePath: String?
        let cookbookCoverImagePath: String?
        let useCustomBackground: Bool
        let lastImageGenerationDate: Date?
        let lastRecipeCountAtGeneration: Int

        static func from(_ collection: RecipeCollection) -> CollectionUndoData {
            CollectionUndoData(
                id: collection.id,
                name: collection.name,
                desc: collection.desc,
                iconName: collection.iconName,
                color: collection.color,
                isSystemCollection: collection.isSystemCollection,
                isAllRecipes: collection.isAllRecipes,
                type: collection.type,
                createdDate: collection.createdDate,
                lastViewedDate: collection.lastViewedDate,
                sourceThemeId: collection.sourceThemeId,
                sourceCookbook: collection.sourceCookbook,
                sourceAuthor: collection.sourceAuthor,
                sourceURL: collection.sourceURL,
                customBackgroundImagePath: collection.customBackgroundImagePath,
                generatedBackgroundImagePath: collection.generatedBackgroundImagePath,
                cookbookCoverImagePath: collection.cookbookCoverImagePath,
                useCustomBackground: collection.useCustomBackground,
                lastImageGenerationDate: collection.lastImageGenerationDate,
                lastRecipeCountAtGeneration: collection.lastRecipeCountAtGeneration
            )
        }
    }

    // MARK: - Collection Undo Item
    struct CollectionUndoItem: Identifiable {
        let id = UUID()
        let collectionData: CollectionUndoData
        let expirationDate: Date
        let description: String

        /// Recipe IDs that were in this collection (for relationship restoration)
        let recipeIds: [UUID]

        /// If "delete with recipes" was chosen, store the deleted recipe data
        let deletedRecipeData: [RecipeUndoData]

        /// Whether recipes were deleted along with the collection
        var recipesWereDeleted: Bool {
            !deletedRecipeData.isEmpty
        }

        var isExpired: Bool {
            Date() > expirationDate
        }

        var recipeCount: Int {
            recipesWereDeleted ? deletedRecipeData.count : recipeIds.count
        }

        /// Collection ID for pending check
        var collectionId: UUID { collectionData.id }
    }

    // MARK: - Published State
    @Published private(set) var pendingUndos: [UndoItem] = []
    @Published private(set) var pendingCollectionUndos: [CollectionUndoItem] = []

    // Store model context reference
    private var modelContext: ModelContext?

    init(analytics: AnalyticsService, backendConfig: BackendConfig, firebaseSync: FirebaseSyncService) {
        self.analytics = analytics
        self.backendConfig = backendConfig
        self.firebaseSync = firebaseSync
    }

    // MARK: - Configuration
    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Delete with Undo
    /// Soft-delete a recipe with undo capability
    /// - Parameters:
    ///   - recipe: The recipe to delete
    ///   - context: The SwiftData model context
    ///   - undoWindow: Duration for undo window (default: 5 seconds)
    func deleteRecipe(
        _ recipe: Recipe,
        context: ModelContext,
        undoWindow: TimeInterval = defaultUndoWindow
    ) {
        // IMPORTANT: Capture all recipe data BEFORE delete!
        // After context.delete(), the SwiftData object becomes invalid
        let recipeData = RecipeUndoData.from(recipe)

        // Store recipe data for potential undo
        let undoItem = UndoItem(
            recipeData: recipeData,
            expirationDate: Date().addingTimeInterval(undoWindow),
            description: recipe.title
        )

        // Remove from SwiftData
        context.delete(recipe)
        try? context.save()

        // Add to pending undos
        pendingUndos.append(undoItem)

        // Schedule permanent deletion after undo window expires
        Task {
            try? await Task.sleep(nanoseconds: UInt64(undoWindow * 1_000_000_000))
            self.expireUndoItem(undoItem)
        }

        // Analytics
        analytics.track(event: .recipeDeleted, properties: [
            "Recipe Title": recipeData.title,
            "Undo Available": true
        ])

        Log.info("Recipe deleted with undo", category: .database, metadata: ["title": recipeData.title])
    }

    // MARK: - Undo
    /// Restore a deleted recipe
    /// - Parameter undoItem: The undo item to restore
    func undoDelete(_ undoItem: UndoItem) {
        guard let context = modelContext else {
            Log.warning("UndoService: No model context configured", category: .database)
            return
        }

        let data = undoItem.recipeData

        Log.info("Starting recipe undo", category: .database, metadata: [
            "title": data.title,
            "id": data.id.uuidString
        ])

        // Remove from pending undos
        pendingUndos.removeAll { $0.id == undoItem.id }

        // IMPORTANT: Create a NEW Recipe object with all the captured data
        // We cannot re-insert the deleted object because SwiftData invalidates it
        let restoredRecipe = Recipe(
            title: data.title,
            sourceType: data.sourceType ?? .manual,
            sourceURL: data.sourceURL,
            instructions: data.instructions,
            servings: data.servings,
            prepTime: data.prepTime,
            cookTime: data.cookTime
        )

        // Preserve original ID and dates
        restoredRecipe.id = data.id
        restoredRecipe.dateAdded = data.dateAdded
        restoredRecipe.lastModified = data.lastModified

        // Source Information
        restoredRecipe.sourceBookTitle = data.sourceBookTitle
        restoredRecipe.sourceBookAuthor = data.sourceBookAuthor
        restoredRecipe.sourceBookPage = data.sourceBookPage
        restoredRecipe.sourcePerson = data.sourcePerson
        restoredRecipe.sourceDate = data.sourceDate
        restoredRecipe.sourceStory = data.sourceStory
        restoredRecipe.sourceCookbook = data.sourceCookbook
        restoredRecipe.sourceImportItemID = data.sourceImportItemID
        restoredRecipe.sourceRecipeIndex = data.sourceRecipeIndex

        // Content
        restoredRecipe.imageFileName = data.imageFileName
        restoredRecipe.sourceImageURL = data.sourceImageURL
        restoredRecipe.firebaseImageURL = data.firebaseImageURL

        // Theme Collections
        restoredRecipe.isThemeRecipe = data.isThemeRecipe
        restoredRecipe.themeRecipeId = data.themeRecipeId
        restoredRecipe.sourceThemeId = data.sourceThemeId
        restoredRecipe.unlockDay = data.unlockDay
        restoredRecipe.blurhash = data.blurhash
        restoredRecipe.imageVariants = data.imageVariants
        restoredRecipe.historicalText = data.historicalText
        restoredRecipe.historicalContext = data.historicalContext

        // Recipe Content
        restoredRecipe.totalTime = data.totalTime
        restoredRecipe.notes = data.notes
        restoredRecipe.originalSnapshotData = data.originalSnapshotData

        // Metadata
        restoredRecipe.timesCooked = data.timesCooked
        restoredRecipe.lastCooked = data.lastCooked
        restoredRecipe.lastViewed = data.lastViewed
        restoredRecipe.hasBeenViewed = data.hasBeenViewed
        restoredRecipe.isFavorite = data.isFavorite
        restoredRecipe.isInShoppingList = data.isInShoppingList
        restoredRecipe.contentHash = data.contentHash

        // Scaling
        restoredRecipe.scalabilityRating = data.scalabilityRating
        restoredRecipe.recipeCategory = data.recipeCategory
        restoredRecipe.minimumServings = data.minimumServings
        restoredRecipe.maximumServings = data.maximumServings
        restoredRecipe.scalingNote = data.scalingNote

        // Social
        restoredRecipe.sharedBy = data.sharedBy
        restoredRecipe.sharedDate = data.sharedDate
        restoredRecipe.passedDownBy = data.passedDownBy
        restoredRecipe.passedDownDate = data.passedDownDate
        restoredRecipe.passedDownMessage = data.passedDownMessage
        restoredRecipe.generationCount = data.generationCount

        // AI/Voice
        restoredRecipe.aiGenerated = data.aiGenerated
        restoredRecipe.voiceDictated = data.voiceDictated

        // Public Discovery
        restoredRecipe.isPublic = data.isPublic
        restoredRecipe.publicRecipeId = data.publicRecipeId
        restoredRecipe.publicPublishedAt = data.publicPublishedAt
        restoredRecipe.publicViewCount = data.publicViewCount
        restoredRecipe.publicSaveCount = data.publicSaveCount
        restoredRecipe.cameraOriginConfidence = data.cameraOriginConfidence
        restoredRecipe.sourcePublicRecipeId = data.sourcePublicRecipeId
        restoredRecipe.sourcePublicRecipeCreatorId = data.sourcePublicRecipeCreatorId
        restoredRecipe.sourcePublicRecipeCreatorName = data.sourcePublicRecipeCreatorName
        restoredRecipe.sourcePublicRecipeLastSynced = data.sourcePublicRecipeLastSynced
        restoredRecipe.sourcePublicRecipeStillAvailable = data.sourcePublicRecipeStillAvailable

        // Provenance
        restoredRecipe.provenance = data.provenance

        // Sync Metadata
        restoredRecipe.cloudKitRecordID = data.cloudKitRecordID
        restoredRecipe.firebaseId = data.firebaseId
        restoredRecipe.lastSyncedAt = data.lastSyncedAt
        restoredRecipe.modifiedAt = data.modifiedAt
        restoredRecipe.createdAt = data.createdAt

        // CRDT
        restoredRecipe.usesCRDT = data.usesCRDT
        restoredRecipe.lastModifiedByDevice = data.lastModifiedByDevice
        restoredRecipe.vectorClockData = data.vectorClockData
        restoredRecipe.pendingOperationsData = data.pendingOperationsData
        restoredRecipe.hasPendingConflicts = data.hasPendingConflicts
        restoredRecipe.showConflictBadge = data.showConflictBadge

        // Multilingual
        restoredRecipe.sourceLanguage = data.sourceLanguage
        restoredRecipe.sourceLanguageConfidence = data.sourceLanguageConfidence
        restoredRecipe.originalTitle = data.originalTitle
        restoredRecipe.originalInstructions = data.originalInstructions
        restoredRecipe.translatedTitle = data.translatedTitle
        restoredRecipe.translatedInstructions = data.translatedInstructions
        restoredRecipe.detectedUnitSystem = data.detectedUnitSystem
        restoredRecipe.preferOriginalLanguage = data.preferOriginalLanguage
        restoredRecipe.translationQuality = data.translationQuality
        restoredRecipe.translatedAt = data.translatedAt

        // Sharing
        restoredRecipe.sharingPermissionRaw = data.sharingPermissionRaw

        // Insert the recipe first
        context.insert(restoredRecipe)

        // Recreate ingredients
        var restoredIngredients: [Ingredient] = []
        for ingredientData in data.ingredientSnapshots {
            let ingredient = Ingredient(
                originalText: ingredientData.originalText,
                name: ingredientData.name,
                quantity: ingredientData.quantity,
                unit: ingredientData.unit,
                category: ingredientData.category ?? .other,
                orderIndex: ingredientData.orderIndex
            )
            ingredient.id = ingredientData.id
            ingredient.quantityMax = ingredientData.quantityMax
            ingredient.normalizedUnit = ingredientData.normalizedUnit
            ingredient.preparation = ingredientData.preparation
            ingredient.size = ingredientData.size
            ingredient.isSelected = ingredientData.isSelected
            ingredient.isCheckedOff = ingredientData.isCheckedOff
            ingredient.isOptional = ingredientData.isOptional
            ingredient.originalLanguageName = ingredientData.originalLanguageName
            ingredient.translatedName = ingredientData.translatedName
            ingredient.originalLanguageUnit = ingredientData.originalLanguageUnit
            ingredient.convertedQuantity = ingredientData.convertedQuantity
            ingredient.convertedUnit = ingredientData.convertedUnit
            ingredient.conversionNote = ingredientData.conversionNote
            ingredient.wasConverted = ingredientData.wasConverted
            ingredient.recipe = restoredRecipe
            restoredIngredients.append(ingredient)
        }
        restoredRecipe.ingredients = restoredIngredients

        // Restore collection relationships
        for collectionId in data.collectionIds {
            let descriptor = FetchDescriptor<RecipeCollection>(
                predicate: #Predicate<RecipeCollection> { collection in
                    collection.id == collectionId
                }
            )
            if let collection = try? context.fetch(descriptor).first {
                if restoredRecipe.collections == nil {
                    restoredRecipe.collections = []
                }
                if !restoredRecipe.collections!.contains(where: { $0.id == collection.id }) {
                    restoredRecipe.collections!.append(collection)
                }
            }
        }

        do {
            try context.save()
            Log.info("Successfully saved restored recipe", category: .database, metadata: ["title": data.title])
        } catch {
            Log.error("Failed to save restored recipe", category: .database, metadata: [
                "title": data.title,
                "error": error.localizedDescription
            ])
        }

        // Re-upload to Firebase if active
        if backendConfig.isFirebaseActive {
            Task {
                do {
                    try await firebaseSync.uploadRecipe(restoredRecipe)
                    Log.info("Recipe restored to Firebase", category: .firebase, metadata: ["title": data.title])
                } catch {
                    Log.warning("Failed to restore recipe to Firebase", category: .firebase, metadata: ["error": error.localizedDescription])
                }
            }
        }

        // Analytics
        analytics.track(event: .featureUsed, properties: [
            "feature": "undo_delete",
            "recipe_title": data.title
        ])

        Log.info("Recipe restored locally", category: .database, metadata: ["title": data.title])
    }

    // MARK: - Expiration
    /// Remove expired undo item (permanent deletion from local and Firebase)
    private func expireUndoItem(_ undoItem: UndoItem) {
        // Only remove if still pending and expired
        if let index = pendingUndos.firstIndex(where: { $0.id == undoItem.id }),
           pendingUndos[index].isExpired {
            let recipeId = undoItem.recipeId
            pendingUndos.remove(at: index)

            // Also delete from Firebase to prevent re-sync
            if backendConfig.isFirebaseActive {
                Task {
                    do {
                        try await firebaseSync.deleteRecipe(recipeId)
                        Log.info("Permanently deleted recipe from Firebase", category: .firebase, metadata: ["recipeId": recipeId.uuidString])
                    } catch {
                        Log.warning("Failed to delete recipe from Firebase", category: .firebase, metadata: [
                            "recipeId": recipeId.uuidString,
                            "error": error.localizedDescription
                        ])
                    }
                }
            }

            Log.info("Permanently deleted expired recipe", category: .database, metadata: ["description": undoItem.description])
        }
    }

    // MARK: - Clear All
    /// Clear all pending undos (useful for cleanup)
    func clearAll() {
        pendingUndos.removeAll()
        pendingCollectionUndos.removeAll()
    }

    // MARK: - Has Pending Undos
    var hasPendingUndos: Bool {
        !pendingUndos.isEmpty
    }

    var hasPendingCollectionUndos: Bool {
        !pendingCollectionUndos.isEmpty
    }

    /// Recipe IDs that are pending undo (should not be re-downloaded from Firebase)
    var pendingRecipeIds: Set<UUID> {
        Set(pendingUndos.map { $0.recipeId })
    }

    /// Collection IDs that are pending undo (should not be re-downloaded from Firebase)
    var pendingCollectionIds: Set<UUID> {
        Set(pendingCollectionUndos.map { $0.collectionId })
    }

    /// Check if a recipe ID is pending undo
    func isRecipePendingUndo(_ recipeId: UUID) -> Bool {
        pendingRecipeIds.contains(recipeId)
    }

    /// Check if a collection ID is pending undo
    func isCollectionPendingUndo(_ collectionId: UUID) -> Bool {
        pendingCollectionIds.contains(collectionId)
    }

    // MARK: - Collection Delete with Undo

    /// Soft-delete a collection (keeping recipes) with undo capability
    /// - Parameters:
    ///   - collection: The collection to delete
    ///   - context: The SwiftData model context
    ///   - undoWindow: Duration for undo window (default: 5 seconds)
    func deleteCollectionKeepingRecipes(
        _ collection: RecipeCollection,
        context: ModelContext,
        undoWindow: TimeInterval = defaultUndoWindow
    ) {
        // IMPORTANT: Capture all collection data BEFORE delete!
        // After context.delete(), the SwiftData object becomes invalid
        let collectionData = CollectionUndoData.from(collection)

        // Capture recipe IDs before deleting (for relationship restoration on undo)
        let recipeIds = collection.recipes?.map { $0.id } ?? []

        // Store collection data for potential undo
        let undoItem = CollectionUndoItem(
            collectionData: collectionData,
            expirationDate: Date().addingTimeInterval(undoWindow),
            description: collection.name,
            recipeIds: recipeIds,
            deletedRecipeData: []
        )

        // Remove collection-recipe relationships
        if let recipes = collection.recipes {
            for recipe in recipes {
                recipe.collections?.removeAll { $0.id == collection.id }
            }
        }

        // Create tombstone BEFORE deleting (so we remember this was deleted)
        let tombstone = DeletedCollectionRecord(collectionId: collection.id)
        context.insert(tombstone)

        // Remove from SwiftData
        context.delete(collection)
        try? context.save()

        // Add to pending undos
        pendingCollectionUndos.append(undoItem)

        // Schedule permanent deletion after undo window expires
        Task {
            try? await Task.sleep(nanoseconds: UInt64(undoWindow * 1_000_000_000))
            self.expireCollectionUndoItem(undoItem)
        }

        // Analytics
        analytics.track(event: .collectionDeleted, properties: [
            "Collection Name": collectionData.name,
            "Recipe Count": recipeIds.count,
            "Deleted With Recipes": false,
            "Undo Available": true
        ])

        Log.info("Collection deleted with undo", category: .collections, metadata: [
            "name": collectionData.name,
            "recipeCount": recipeIds.count
        ])
    }

    /// Soft-delete a collection AND its recipes with undo capability
    /// - Parameters:
    ///   - collection: The collection to delete
    ///   - context: The SwiftData model context
    ///   - undoWindow: Duration for undo window (default: 5 seconds)
    func deleteCollectionAndRecipes(
        _ collection: RecipeCollection,
        context: ModelContext,
        undoWindow: TimeInterval = defaultUndoWindow
    ) {
        // IMPORTANT: Capture all collection and recipe data BEFORE delete!
        // After context.delete(), the SwiftData objects become invalid
        let collectionData = CollectionUndoData.from(collection)

        // Capture recipes before deleting (for full restoration on undo)
        let recipesToDelete = Array(collection.recipes ?? [])
        let recipeIds = recipesToDelete.map { $0.id }
        let recipeDataList = recipesToDelete.map { RecipeUndoData.from($0) }

        // Store collection data for potential undo
        let undoItem = CollectionUndoItem(
            collectionData: collectionData,
            expirationDate: Date().addingTimeInterval(undoWindow),
            description: collection.name,
            recipeIds: recipeIds,
            deletedRecipeData: recipeDataList
        )

        // Delete recipes from SwiftData
        for recipe in recipesToDelete {
            context.delete(recipe)
        }

        // Remove from SwiftData (no tombstone needed since recipes are also deleted)
        context.delete(collection)
        try? context.save()

        // Add to pending undos
        pendingCollectionUndos.append(undoItem)

        // Schedule permanent deletion after undo window expires
        Task {
            try? await Task.sleep(nanoseconds: UInt64(undoWindow * 1_000_000_000))
            self.expireCollectionUndoItem(undoItem)
        }

        // Analytics
        analytics.track(event: .collectionDeleted, properties: [
            "Collection Name": collectionData.name,
            "Recipe Count": recipesToDelete.count,
            "Deleted With Recipes": true,
            "Undo Available": true
        ])

        Log.info("Collection and recipes deleted with undo", category: .collections, metadata: [
            "name": collectionData.name,
            "recipeCount": recipesToDelete.count
        ])
    }

    // MARK: - Collection Undo

    /// Restore a deleted collection
    /// - Parameter undoItem: The undo item to restore
    func undoCollectionDelete(_ undoItem: CollectionUndoItem) {
        guard let context = modelContext else {
            Log.warning("UndoService: No model context configured", category: .database)
            return
        }

        let data = undoItem.collectionData

        Log.info("Starting collection undo", category: .collections, metadata: [
            "collectionName": data.name,
            "recipeCount": undoItem.recipeCount,
            "recipesWereDeleted": undoItem.recipesWereDeleted
        ])

        // Remove from pending undos
        pendingCollectionUndos.removeAll { $0.id == undoItem.id }

        // IMPORTANT: Create a NEW collection object with all the captured data
        // We cannot re-insert the deleted object because SwiftData invalidates it
        let restoredCollection = RecipeCollection(
            name: data.name,
            description: data.desc,
            iconName: data.iconName,
            color: data.color,
            isSystemCollection: data.isSystemCollection,
            isAllRecipes: data.isAllRecipes,
            collectionType: data.type
        )
        // Preserve the original ID and all properties
        restoredCollection.id = data.id
        restoredCollection.createdDate = data.createdDate
        restoredCollection.lastViewedDate = data.lastViewedDate
        restoredCollection.sourceThemeId = data.sourceThemeId
        restoredCollection.sourceCookbook = data.sourceCookbook
        restoredCollection.sourceAuthor = data.sourceAuthor
        restoredCollection.sourceURL = data.sourceURL
        restoredCollection.customBackgroundImagePath = data.customBackgroundImagePath
        restoredCollection.generatedBackgroundImagePath = data.generatedBackgroundImagePath
        restoredCollection.cookbookCoverImagePath = data.cookbookCoverImagePath
        restoredCollection.useCustomBackground = data.useCustomBackground
        restoredCollection.lastImageGenerationDate = data.lastImageGenerationDate
        restoredCollection.lastRecipeCountAtGeneration = data.lastRecipeCountAtGeneration

        context.insert(restoredCollection)
        Log.info("Created new collection object for restoration", category: .collections, metadata: [
            "id": restoredCollection.id.uuidString
        ])

        if undoItem.recipesWereDeleted {
            // Recreate deleted recipes from captured data
            var restoredRecipes: [Recipe] = []
            for recipeData in undoItem.deletedRecipeData {
                let restoredRecipe = recreateRecipeFromData(recipeData, context: context)
                restoredRecipe.collections = [restoredCollection]
                restoredRecipes.append(restoredRecipe)
            }
            restoredCollection.recipes = restoredRecipes
            Log.info("Recreated deleted recipes", category: .collections, metadata: [
                "count": restoredRecipes.count
            ])
        } else {
            // Restore recipe-collection relationships
            for recipeId in undoItem.recipeIds {
                let descriptor = FetchDescriptor<Recipe>(
                    predicate: #Predicate<Recipe> { recipe in
                        recipe.id == recipeId
                    }
                )
                if let recipe = try? context.fetch(descriptor).first {
                    if recipe.collections == nil {
                        recipe.collections = []
                    }
                    if !recipe.collections!.contains(where: { $0.id == restoredCollection.id }) {
                        recipe.collections!.append(restoredCollection)
                    }
                }
            }
        }

        // Remove tombstone record (allows Firebase to sync this collection again)
        let collectionId = data.id
        let tombstoneDescriptor = FetchDescriptor<DeletedCollectionRecord>(
            predicate: #Predicate<DeletedCollectionRecord> { record in
                record.collectionId == collectionId
            }
        )
        if let tombstone = try? context.fetch(tombstoneDescriptor).first {
            context.delete(tombstone)
            Log.info("Removed tombstone record", category: .collections)
        }

        do {
            try context.save()
            Log.info("Successfully saved restored collection", category: .collections)
        } catch {
            Log.error("Failed to save restored collection", category: .collections, metadata: [
                "error": error.localizedDescription
            ])
        }

        // Re-upload to Firebase if active
        if backendConfig.isFirebaseActive {
            Task {
                do {
                    // Upload restored collection
                    try await firebaseSync.uploadCollection(restoredCollection)
                    Log.info("Collection restored to Firebase", category: .firebase, metadata: ["name": restoredCollection.name])

                    // If recipes were deleted, re-upload them too
                    if undoItem.recipesWereDeleted {
                        for recipe in restoredCollection.recipes ?? [] {
                            try await firebaseSync.uploadRecipe(recipe)
                        }
                        Log.info("Recipes restored to Firebase", category: .firebase, metadata: ["count": undoItem.deletedRecipeData.count])
                    }
                } catch {
                    Log.warning("Failed to restore collection to Firebase", category: .firebase, metadata: ["error": error.localizedDescription])
                }
            }
        }

        // Analytics
        analytics.track(event: .featureUsed, properties: [
            "feature": "undo_collection_delete",
            "collection_name": restoredCollection.name,
            "recipes_restored": undoItem.recipesWereDeleted ? undoItem.deletedRecipeData.count : 0
        ])

        Log.info("Collection restored locally", category: .collections, metadata: [
            "name": restoredCollection.name,
            "recipesRestored": undoItem.recipesWereDeleted
        ])
    }

    // MARK: - Recipe Recreation Helper

    /// Recreate a Recipe from captured undo data
    private func recreateRecipeFromData(_ data: RecipeUndoData, context: ModelContext) -> Recipe {
        let recipe = Recipe(
            title: data.title,
            sourceType: data.sourceType ?? .manual,
            sourceURL: data.sourceURL,
            instructions: data.instructions,
            servings: data.servings,
            prepTime: data.prepTime,
            cookTime: data.cookTime
        )

        // Preserve original ID and dates
        recipe.id = data.id
        recipe.dateAdded = data.dateAdded
        recipe.lastModified = data.lastModified

        // Source Information
        recipe.sourceBookTitle = data.sourceBookTitle
        recipe.sourceBookAuthor = data.sourceBookAuthor
        recipe.sourceBookPage = data.sourceBookPage
        recipe.sourcePerson = data.sourcePerson
        recipe.sourceDate = data.sourceDate
        recipe.sourceStory = data.sourceStory
        recipe.sourceCookbook = data.sourceCookbook
        recipe.sourceImportItemID = data.sourceImportItemID
        recipe.sourceRecipeIndex = data.sourceRecipeIndex

        // Content
        recipe.imageFileName = data.imageFileName
        recipe.sourceImageURL = data.sourceImageURL
        recipe.firebaseImageURL = data.firebaseImageURL

        // Theme
        recipe.isThemeRecipe = data.isThemeRecipe
        recipe.themeRecipeId = data.themeRecipeId
        recipe.sourceThemeId = data.sourceThemeId
        recipe.unlockDay = data.unlockDay
        recipe.blurhash = data.blurhash
        recipe.imageVariants = data.imageVariants
        recipe.historicalText = data.historicalText
        recipe.historicalContext = data.historicalContext

        // Recipe Content
        recipe.totalTime = data.totalTime
        recipe.notes = data.notes
        recipe.originalSnapshotData = data.originalSnapshotData

        // Metadata
        recipe.timesCooked = data.timesCooked
        recipe.lastCooked = data.lastCooked
        recipe.lastViewed = data.lastViewed
        recipe.hasBeenViewed = data.hasBeenViewed
        recipe.isFavorite = data.isFavorite
        recipe.isInShoppingList = data.isInShoppingList
        recipe.contentHash = data.contentHash

        // Scaling
        recipe.scalabilityRating = data.scalabilityRating
        recipe.recipeCategory = data.recipeCategory
        recipe.minimumServings = data.minimumServings
        recipe.maximumServings = data.maximumServings
        recipe.scalingNote = data.scalingNote

        // Social
        recipe.sharedBy = data.sharedBy
        recipe.sharedDate = data.sharedDate
        recipe.passedDownBy = data.passedDownBy
        recipe.passedDownDate = data.passedDownDate
        recipe.passedDownMessage = data.passedDownMessage
        recipe.generationCount = data.generationCount

        // AI/Voice
        recipe.aiGenerated = data.aiGenerated
        recipe.voiceDictated = data.voiceDictated

        // Public Discovery
        recipe.isPublic = data.isPublic
        recipe.publicRecipeId = data.publicRecipeId
        recipe.publicPublishedAt = data.publicPublishedAt
        recipe.publicViewCount = data.publicViewCount
        recipe.publicSaveCount = data.publicSaveCount
        recipe.cameraOriginConfidence = data.cameraOriginConfidence
        recipe.sourcePublicRecipeId = data.sourcePublicRecipeId
        recipe.sourcePublicRecipeCreatorId = data.sourcePublicRecipeCreatorId
        recipe.sourcePublicRecipeCreatorName = data.sourcePublicRecipeCreatorName
        recipe.sourcePublicRecipeLastSynced = data.sourcePublicRecipeLastSynced
        recipe.sourcePublicRecipeStillAvailable = data.sourcePublicRecipeStillAvailable

        // Provenance
        recipe.provenance = data.provenance

        // Sync Metadata
        recipe.cloudKitRecordID = data.cloudKitRecordID
        recipe.firebaseId = data.firebaseId
        recipe.lastSyncedAt = data.lastSyncedAt
        recipe.modifiedAt = data.modifiedAt
        recipe.createdAt = data.createdAt

        // CRDT
        recipe.usesCRDT = data.usesCRDT
        recipe.lastModifiedByDevice = data.lastModifiedByDevice
        recipe.vectorClockData = data.vectorClockData
        recipe.pendingOperationsData = data.pendingOperationsData
        recipe.hasPendingConflicts = data.hasPendingConflicts
        recipe.showConflictBadge = data.showConflictBadge

        // Multilingual
        recipe.sourceLanguage = data.sourceLanguage
        recipe.sourceLanguageConfidence = data.sourceLanguageConfidence
        recipe.originalTitle = data.originalTitle
        recipe.originalInstructions = data.originalInstructions
        recipe.translatedTitle = data.translatedTitle
        recipe.translatedInstructions = data.translatedInstructions
        recipe.detectedUnitSystem = data.detectedUnitSystem
        recipe.preferOriginalLanguage = data.preferOriginalLanguage
        recipe.translationQuality = data.translationQuality
        recipe.translatedAt = data.translatedAt

        // Sharing
        recipe.sharingPermissionRaw = data.sharingPermissionRaw

        // Insert the recipe
        context.insert(recipe)

        // Recreate ingredients
        var restoredIngredients: [Ingredient] = []
        for ingredientData in data.ingredientSnapshots {
            let ingredient = Ingredient(
                originalText: ingredientData.originalText,
                name: ingredientData.name,
                quantity: ingredientData.quantity,
                unit: ingredientData.unit,
                category: ingredientData.category ?? .other,
                orderIndex: ingredientData.orderIndex
            )
            ingredient.id = ingredientData.id
            ingredient.quantityMax = ingredientData.quantityMax
            ingredient.normalizedUnit = ingredientData.normalizedUnit
            ingredient.preparation = ingredientData.preparation
            ingredient.size = ingredientData.size
            ingredient.isSelected = ingredientData.isSelected
            ingredient.isCheckedOff = ingredientData.isCheckedOff
            ingredient.isOptional = ingredientData.isOptional
            ingredient.originalLanguageName = ingredientData.originalLanguageName
            ingredient.translatedName = ingredientData.translatedName
            ingredient.originalLanguageUnit = ingredientData.originalLanguageUnit
            ingredient.convertedQuantity = ingredientData.convertedQuantity
            ingredient.convertedUnit = ingredientData.convertedUnit
            ingredient.conversionNote = ingredientData.conversionNote
            ingredient.wasConverted = ingredientData.wasConverted
            ingredient.recipe = recipe
            restoredIngredients.append(ingredient)
        }
        recipe.ingredients = restoredIngredients

        return recipe
    }

    // MARK: - Collection Expiration

    /// Handle collection undo item expiration (permanent deletion from Firebase)
    private func expireCollectionUndoItem(_ undoItem: CollectionUndoItem) {
        // Only remove if still pending and expired
        guard let index = pendingCollectionUndos.firstIndex(where: { $0.id == undoItem.id }),
              pendingCollectionUndos[index].isExpired else {
            return
        }

        let collectionId = undoItem.collectionId
        pendingCollectionUndos.remove(at: index)

        // Delete from Firebase
        if backendConfig.isFirebaseActive {
            Task {
                do {
                    // Delete collection from Firebase
                    try await firebaseSync.deleteCollection(collectionId)
                    Log.info("Permanently deleted collection from Firebase", category: .firebase, metadata: [
                        "collectionId": collectionId.uuidString
                    ])

                    // If recipes were deleted, delete them from Firebase too
                    if undoItem.recipesWereDeleted {
                        for recipeData in undoItem.deletedRecipeData {
                            try await firebaseSync.deleteRecipe(recipeData.id)
                        }
                        Log.info("Permanently deleted recipes from Firebase", category: .firebase, metadata: [
                            "count": undoItem.deletedRecipeData.count
                        ])
                    }

                    // Mark tombstone as synced (if it exists)
                    if let context = modelContext {
                        let tombstoneDescriptor = FetchDescriptor<DeletedCollectionRecord>(
                            predicate: #Predicate<DeletedCollectionRecord> { record in
                                record.collectionId == collectionId
                            }
                        )
                        if let tombstone = try? context.fetch(tombstoneDescriptor).first {
                            tombstone.syncedToFirebase = true
                            try? context.save()
                        }
                    }
                } catch {
                    Log.warning("Failed to delete collection from Firebase", category: .firebase, metadata: [
                        "collectionId": collectionId.uuidString,
                        "error": error.localizedDescription
                    ])
                }
            }
        }

        Log.info("Permanently deleted expired collection", category: .collections, metadata: [
            "description": undoItem.description,
            "recipesDeleted": undoItem.recipesWereDeleted ? undoItem.deletedRecipeData.count : 0
        ])
    }
}

// MARK: - Toast Manager Extension
extension ToastManager {
    /// Show undo toast for recipe deletion with countdown
    /// - Parameters:
    ///   - undoItem: The undo item
    ///   - onUndo: Closure to execute when undo is tapped
    func showUndoToast(for undoItem: UndoService.UndoItem, onUndo: @escaping () -> Void) {
        let toast = Toast(
            type: .warning,
            title: "Recipe Deleted",
            message: undoItem.description,
            duration: UndoService.defaultUndoWindow,
            undoAction: onUndo
        )
        show(toast)
    }

    /// Show undo toast for collection deletion with countdown
    /// - Parameters:
    ///   - undoItem: The collection undo item
    ///   - onUndo: Closure to execute when undo is tapped
    func showCollectionUndoToast(for undoItem: UndoService.CollectionUndoItem, onUndo: @escaping () -> Void) {
        let title: String
        let message: String

        if undoItem.recipesWereDeleted {
            let count = undoItem.deletedRecipeData.count
            title = "Collection & Recipes Deleted"
            message = "\(undoItem.description) and \(count) recipe\(count == 1 ? "" : "s")"
        } else {
            title = "Collection Deleted"
            message = undoItem.description
        }

        let toast = Toast(
            type: .warning,
            title: title,
            message: message,
            duration: UndoService.defaultUndoWindow,
            undoAction: onUndo
        )
        show(toast)
    }
}
