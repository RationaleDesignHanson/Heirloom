import Foundation
import SwiftData
import UIKit

@Model
final class Recipe {
    // MARK: - Identity
    var id: UUID = UUID()
    var title: String = ""
    var dateAdded: Date = Date()
    var lastModified: Date = Date()

    // MARK: - Source Information
    var sourceType: RecipeSourceType?
    var sourceURL: String?
    var sourceBookTitle: String?
    var sourceBookAuthor: String?
    var sourceBookPage: Int?
    var sourcePerson: String?
    var sourceDate: String?
    var sourceStory: String?

    // MARK: - Content
    /// Image stored in file system, not database (per Systems Architect recommendation)
    /// Path relative to ImageStorageService.imagesDirectory
    var imageFileName: String?

    /// Original image URL for potential re-download
    var sourceImageURL: String?

    /// Firebase Storage URL for synced images
    var firebaseImageURL: String?

    // MARK: - Heritage Collections (Cold Start)
    /// Flag indicating this is a heritage recipe from founding collections
    var isHeritageRecipe: Bool = false

    /// ID of the founding heritage collection this recipe belongs to
    var heritageCollectionId: String?

    /// Blurhash for progressive image loading placeholder
    var blurhash: String?

    /// Image variant URLs for different sizes (hero, card, thumbnail, collection-cover)
    /// Keys: "hero", "card", "thumbnail", "collection-cover"
    var imageVariants: [String: String]?

    /// Original historical text for Artifact View (heritage recipes only)
    var historicalText: String?

    /// Historical context and background story (heritage recipes only)
    var historicalContext: String?

    @Relationship(deleteRule: .cascade, inverse: \Ingredient.recipe)
    var ingredients: [Ingredient]?

    var instructions: [String] = []
    var servings: String?
    var prepTime: String?
    var cookTime: String?
    var totalTime: String?
    var notes: String?

    // MARK: - Personalization (Phase 2)
    @Relationship(deleteRule: .cascade, inverse: \RecipeCardStyle.recipe)
    var cardStyle: RecipeCardStyle?

    @Relationship(deleteRule: .cascade, inverse: \RecipeSticker.recipe)
    var stickers: [RecipeSticker]?

    @Relationship(deleteRule: .cascade, inverse: \RecipeAnnotation.recipe)
    var annotations: [RecipeAnnotation]?

    // MARK: - Metadata
    var timesCooked: Int = 0
    var lastCooked: Date?
    var lastViewed: Date?
    var isFavorite: Bool = false
    var isInShoppingList: Bool = false

    // MARK: - Shopping Cart
    var shoppingCartRecipes: [ShoppingCartRecipe]?

    // MARK: - Scaling (Smallify Feature)
    var scalabilityRating: String = "easy" // ScalabilityRating raw value
    var recipeCategory: String? // RecipeCategory raw value
    var minimumServings: Int = 1
    var maximumServings: Int? // nil = no upper limit
    var scalingNote: String?

    // MARK: - Organization
    var tags: [Tag]?
    var collections: [RecipeCollection]?

    // MARK: - Dinner Party Integration
    var dinnerPartyRecipes: [DinnerPartyRecipe]?

    // MARK: - Social (Phase 2)
    var sharedBy: String?
    var sharedDate: Date?
    var passedDownBy: String?
    var passedDownDate: Date?
    var passedDownMessage: String?
    var generationCount: Int = 1

    // MARK: - Provenance Tracking (Phase 2A)
    /// Comprehensive provenance and lineage tracking
    /// Replaces legacy fields above (maintained for backward compatibility)
    var provenance: ProvenanceMetadata?

    // MARK: - Social Features (Comments & Card Back)
    @Relationship(deleteRule: .cascade, inverse: \RecipeComment.recipe)
    var comments: [RecipeComment]?

    @Relationship(deleteRule: .cascade, inverse: \RecipeCardBack.recipe)
    var cardBack: RecipeCardBack?

    // MARK: - Multi-Version Support (Phase 2B - Recipe Sharing)
    /// All versions of this recipe (base + contributor versions)
    @Relationship(deleteRule: .cascade, inverse: \RecipeVersion.recipe)
    var versions: [RecipeVersion]?

    /// Currently selected version ID for cooking/display
    var selectedVersionID: UUID?

    /// Last viewed version ID (for tracking which version user last saw)
    var lastViewedVersionId: UUID?

    /// Sharing permission level for this recipe
    var sharingPermissionRaw: String = SharingPermissionLevel.regular.rawValue

    // MARK: - CloudKit Sync Metadata
    /// CloudKit record ID for manual sync (hybrid architecture)
    var cloudKitRecordID: String?

    /// Last time this recipe was successfully synced to CloudKit
    var lastSyncedAt: Date?

    /// Modified timestamp for conflict resolution
    var modifiedAt: Date = Date()

    /// Created timestamp
    var createdAt: Date = Date()

    // MARK: - CRDT Support (v2.0+)
    /// Whether this recipe uses CRDT conflict resolution
    var usesCRDT: Bool = true  // Default true for new recipes

    /// Device ID that last modified this recipe
    var lastModifiedByDevice: String?

    /// Vector clock state (serialized as JSON)
    /// Tracks causal relationships for conflict-free merge
    var vectorClockData: Data?

    /// Pending CRDT operations waiting to be uploaded (temporary storage)
    var pendingOperationsData: Data?

    /// Has pending conflicts that need user resolution
    var hasPendingConflicts: Bool = false

    /// Conflict badge should be shown on recipe card
    var showConflictBadge: Bool = false

    // MARK: - Multilingual Support (SchemaV2)
    /// ISO 639-1 language code of the source recipe ("en", "ja", "ko", "es", "fr", "de", "zh")
    /// Defaults to "en" for existing recipes during V1 → V2 migration
    var sourceLanguage: String?

    /// Confidence score of language detection (0.0-1.0)
    /// Defaults to 1.0 for existing English recipes
    var sourceLanguageConfidence: Double?

    /// Original title in source language (preserved for display)
    /// Nil for English recipes, populated for foreign language imports
    var originalTitle: String?

    /// Original instructions in source language (preserved for Artifact View)
    /// Nil for English recipes, populated for foreign language imports
    var originalInstructions: [String]?

    /// Translated title (if recipe was translated from foreign language)
    /// Nil for English recipes or untranslated foreign recipes
    var translatedTitle: String?

    /// Translated instructions (if recipe was translated)
    /// Nil for English recipes or untranslated foreign recipes
    var translatedInstructions: [String]?

    /// Original measurement system detected ("metric", "imperial", or "mixed")
    /// Based on ingredient units (e.g., "grams" → metric, "cups" → imperial)
    /// Auto-detected during migration for existing recipes
    var detectedUnitSystem: String?

    /// User preference: should we show original or translated version?
    /// Default false = show translated version if available
    var preferOriginalLanguage: Bool = false

    /// Translation quality indicator ("excellent", "good", "needs_review", nil)
    /// Used to show quality badges and suggest re-translation
    var translationQuality: String?

    /// When was this recipe translated (for cache invalidation)
    /// Nil for untranslated recipes
    var translatedAt: Date?

    // MARK: - Initialization
    init(
        title: String = "",
        sourceType: RecipeSourceType = .manual,
        sourceURL: String? = nil,
        instructions: [String] = [],
        servings: String? = nil,
        prepTime: String? = nil,
        cookTime: String? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.sourceType = sourceType
        self.sourceURL = sourceURL
        self.dateAdded = Date()
        self.lastModified = Date()
        self.ingredients = []
        self.instructions = instructions
        self.servings = servings
        self.prepTime = prepTime
        self.cookTime = cookTime
        self.timesCooked = 0
        self.isFavorite = false
        self.isInShoppingList = false
        self.generationCount = 1

        // Initialize provenance for new recipes
        let provenanceSourceType: ProvenanceMetadata.SourceType = {
            switch sourceType {
            case .manual: return .userCreated
            case .url: return .imported
            case .cookbook: return .scanned
            case .scan: return .scanned
            case .family: return .userCreated
            case .heritage: return .imported
            case .video: return .video
            }
        }()

        self.provenance = ProvenanceMetadata(
            sourceType: provenanceSourceType,
            sourceURL: sourceURL,
            generation: 0
        )
    }
}

// MARK: - Computed Properties
extension Recipe {
    var sourceDisplayName: String {
        switch sourceType ?? .manual {
        case .url:
            if let urlString = sourceURL,
               let url = URL(string: urlString),
               let host = url.host() {
                return host.replacingOccurrences(of: "www.", with: "")
            }
            return "Website"
        case .cookbook:
            if let title = sourceBookTitle {
                if let page = sourceBookPage {
                    return "\(title), p. \(page)"
                }
                return title
            }
            return "Cookbook"
        case .family:
            if let person = sourcePerson {
                if let date = sourceDate {
                    return "\(person), \(date)"
                }
                return person
            }
            return "Family Recipe"
        case .scan:
            return "Scanned Recipe"
        case .manual:
            return "My Recipe"
        case .heritage:
            // For heritage recipes, show the collection name if available
            if let collectionId = heritageCollectionId,
               let collection = collections?.first(where: { $0.heritageCollectionId == collectionId }) {
                return collection.name
            }
            return "Heritage Collection"
        case .video:
            // For video imports, extract creator name from sourceAttribution
            if let attribution = provenance?.sourceAttribution,
               !attribution.isEmpty {
                // Extract creator name (format: "creatorName - videoTitle" or just "creatorName")
                let parts = attribution.components(separatedBy: " - ")
                if let creatorName = parts.first?.trimmingCharacters(in: .whitespaces),
                   !creatorName.isEmpty,
                   creatorName != "Unknown" {
                    return "@\(creatorName)"
                }
            }
            return "Video Recipe"
        }
    }

    /// Get creator profile URL for video-imported recipes
    var creatorProfileURL: URL? {
        guard sourceType == .video else { return nil }

        // Extract creator name from sourceAttribution
        guard let attribution = provenance?.sourceAttribution,
              !attribution.isEmpty else {
            return nil
        }

        let parts = attribution.components(separatedBy: " - ")
        guard let creatorName = parts.first?.trimmingCharacters(in: .whitespaces),
              !creatorName.isEmpty,
              creatorName != "Unknown" else {
            return nil
        }

        // Try to construct platform-specific URL
        // Check sourceURL for platform hints or construct generic search
        if let sourceURL = provenance?.sourceURL, !sourceURL.isEmpty {
            if sourceURL.contains("tiktok.com") {
                return URL(string: "https://www.tiktok.com/@\(creatorName)")
            } else if sourceURL.contains("youtube.com") || sourceURL.contains("youtu.be") {
                return URL(string: "https://www.youtube.com/@\(creatorName)")
            } else if sourceURL.contains("instagram.com") {
                return URL(string: "https://www.instagram.com/\(creatorName)")
            }
        }

        // Default: TikTok format (most common for cooking videos)
        return URL(string: "https://www.tiktok.com/@\(creatorName)")
    }

    var shouldShowLoveMarks: Bool {
        timesCooked >= 5
    }

    var loveMarkIntensity: Double {
        min(Double(timesCooked) / 20.0, 1.0)
    }

    /// Parse prep time string to minutes
    var parsedPrepTime: Int {
        guard let prepTime = prepTime else { return 0 }
        return parseTimeString(prepTime)
    }

    /// Parse cook time string to minutes
    var parsedCookTime: Int {
        guard let cookTime = cookTime else { return 0 }
        return parseTimeString(cookTime)
    }

    /// Helper to parse time strings like "30 min", "1 hr 30 min", "2 hours"
    private func parseTimeString(_ timeString: String) -> Int {
        let lowercased = timeString.lowercased()
        var totalMinutes = 0

        // Extract hours
        if let hoursMatch = lowercased.range(of: #"(\d+)\s*(hr|hour|hours)"#, options: .regularExpression) {
            let hoursText = String(lowercased[hoursMatch])
            if let hours = Int(hoursText.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()) {
                totalMinutes += hours * 60
            }
        }

        // Extract minutes
        if let minutesMatch = lowercased.range(of: #"(\d+)\s*(min|minute|minutes)"#, options: .regularExpression) {
            let minutesText = String(lowercased[minutesMatch])
            if let minutes = Int(minutesText.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()) {
                totalMinutes += minutes
            }
        }

        // If no time units found, try to parse as plain number (assume minutes)
        if totalMinutes == 0, let number = Int(lowercased.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()), number > 0 {
            totalMinutes = number
        }

        return totalMinutes
    }

    /// Lightweight DTO for list views (per iOS Engineer recommendation)
    var listItem: RecipeListItem {
        RecipeListItem(
            id: id,
            title: title,
            imageFileName: imageFileName,
            sourceType: sourceType ?? .manual,
            sourceDisplayName: sourceDisplayName,
            isFavorite: isFavorite,
            timesCooked: timesCooked,
            dateAdded: dateAdded
        )
    }

    /// Consolidates duplicate ingredients (e.g., "2 cups flour" in step 1 + "1 cup flour" in step 3 = "3 cups flour")
    /// Groups by normalized name and sums quantities when units match
    var consolidatedIngredients: [Ingredient] {
        guard let ingredients = ingredients, !ingredients.isEmpty else {
            return []
        }

        // Group ingredients by normalized name (lowercase, trimmed)
        var consolidated: [String: [Ingredient]] = [:]

        for ingredient in ingredients {
            let key = ingredient.name.lowercased().trimmingCharacters(in: .whitespaces)
            if consolidated[key] == nil {
                consolidated[key] = []
            }
            consolidated[key]?.append(ingredient)
        }

        // Consolidate each group
        var result: [Ingredient] = []

        for (_, group) in consolidated {
            if group.count == 1 {
                // No duplicates, use as-is
                result.append(group[0])
            } else {
                // Multiple ingredients with same name - try to consolidate
                let firstIngredient = group[0]

                // Group by unit (normalized)
                let sameUnit = group.allSatisfy { ing in
                    (ing.normalizedUnit ?? ing.unit)?.lowercased() ==
                    (firstIngredient.normalizedUnit ?? firstIngredient.unit)?.lowercased()
                }

                if sameUnit, let unit = firstIngredient.unit {
                    // Same unit - sum quantities
                    let totalQuantity = group.compactMap { $0.quantity }.reduce(0.0, +)

                    // Create consolidated ingredient
                    let consolidatedIng = Ingredient(
                        originalText: "\(totalQuantity) \(unit) \(firstIngredient.name)",
                        name: firstIngredient.name,
                        quantity: totalQuantity,
                        unit: unit,
                        category: firstIngredient.category ?? .other,
                        orderIndex: firstIngredient.orderIndex
                    )
                    result.append(consolidatedIng)
                } else {
                    // Different units or no quantities - keep separate
                    result.append(contentsOf: group)
                }
            }
        }

        // Sort by original order index
        return result.sorted { $0.orderIndex < $1.orderIndex }
    }

    // MARK: - Scaling Helpers

    /// Computed property for scalability rating enum
    var scalability: ScalabilityRating {
        get { ScalabilityRating(rawValue: scalabilityRating) ?? .easy }
        set { scalabilityRating = newValue.rawValue }
    }

    /// Computed property for recipe category enum
    var category: RecipeCategory? {
        get {
            guard let rawValue = recipeCategory else { return nil }
            return RecipeCategory(rawValue: rawValue)
        }
        set { recipeCategory = newValue?.rawValue }
    }

    /// Whether this recipe can be scaled
    var isScalingAllowed: Bool {
        scalability != .locked
    }

    /// The allowed serving range for this recipe
    var allowedServingRange: ClosedRange<Int>? {
        guard isScalingAllowed else { return nil }
        let max = maximumServings ?? 16 // Default max of 4x typical batch
        return minimumServings...max
    }

    /// Parse servings string to extract base serving count
    /// Examples: "6 servings" → 6, "Makes 12 cookies" → 12, "4-6 servings" → 4
    var parsedServingCount: Int {
        guard let servings = servings else { return 4 } // Default assumption

        // Try to extract first number from servings string
        let numbers = servings.components(separatedBy: CharacterSet.decimalDigits.inverted)
            .compactMap { Int($0) }
            .filter { $0 > 0 } // Filter out zeros

        return numbers.first ?? 4
    }

    /// Display string for locked recipes
    var scalingDisplayString: String {
        if isScalingAllowed {
            return servings ?? "\(parsedServingCount) servings"
        } else {
            return "\(parsedServingCount) servings (fixed)"
        }
    }

    /// Available serving size presets for dropdown
    /// Returns category-based presets filtered by allowed range, always including original
    var availableServingSizes: [Int] {
        guard let category = category else {
            // No category: use default presets
            let defaults = [2, 4, 6, 8, 12]
            return filterServingSizes(defaults)
        }

        // Locked recipes return only original serving size
        if !isScalingAllowed {
            return [parsedServingCount]
        }

        // Get category presets and filter by range
        let presets = category.presetServingSizes
        return filterServingSizes(presets)
    }

    /// Helper to filter serving sizes by allowed range and ensure original is included
    private func filterServingSizes(_ presets: [Int]) -> [Int] {
        let original = parsedServingCount
        var sizes = Set<Int>()

        // Always include original
        sizes.insert(original)

        // Add presets that fall within allowed range
        if let range = allowedServingRange {
            for preset in presets {
                if range.contains(preset) {
                    sizes.insert(preset)
                }
            }
        } else {
            // No range restrictions, add all presets
            sizes.formUnion(presets)
        }

        // Return sorted array
        return Array(sizes).sorted()
    }
}

// MARK: - Multi-Version Support
extension Recipe {
    /// Sharing permission level enum
    enum SharingPermissionLevel: String, Codable {
        case regular = "regular"       // View-only sharing
        case heirloom = "heirloom"     // Edit + lineage tracking
    }

    /// Computed property for sharing permission
    var sharingPermission: SharingPermissionLevel {
        get { SharingPermissionLevel(rawValue: sharingPermissionRaw) ?? .regular }
        set { sharingPermissionRaw = newValue.rawValue }
    }

    /// The base version (original recipe data)
    var baseVersion: RecipeVersion? {
        versions?.first(where: { $0.isBaseVersion })
    }

    /// Active contributor versions (excluding base)
    var contributorVersions: [RecipeVersion] {
        versions?.filter { !$0.isBaseVersion && $0.isActive } ?? []
    }

    /// Currently selected version, or base if none selected
    var activeVersion: RecipeVersion? {
        if let selectedID = selectedVersionID,
           let selected = versions?.first(where: { $0.id == selectedID }) {
            return selected
        }
        return baseVersion
    }

    /// Total count of active contributors (excluding base)
    var contributorCount: Int {
        contributorVersions.count
    }

    /// Whether this recipe has multiple versions
    var hasMultipleVersions: Bool {
        contributorVersions.count > 0
    }

    /// Generation label for UI (e.g., "Original", "2 Generations", "3 Generations")
    var generationLabel: String {
        let total = (versions?.count ?? 0)
        if total <= 1 {
            return "Original"
        }
        return "\(total) Generations"
    }

    /// All versions sorted by creation date
    var sortedVersions: [RecipeVersion] {
        versions?.sorted { $0.createdAt < $1.createdAt } ?? []
    }
}

// MARK: - Image Helpers
extension Recipe {
    /// Load the recipe image from file system
    func loadImage() async -> UIImage? {
        guard let fileName = imageFileName else { return nil }
        let imageStorageService = await ServiceContainer.shared.resolve(ImageStorageService.self)
        return await imageStorageService.loadImage(fileName: fileName)
    }

    /// Save an image to file system and update the recipe
    @MainActor
    func saveImage(_ image: UIImage) async throws {
        let imageStorageService = ServiceContainer.shared.resolve(ImageStorageService.self)
        let fileName = try await imageStorageService.saveImage(
            image,
            recipeId: id
        )
        self.imageFileName = fileName
        self.lastModified = Date()
    }

    /// Delete the recipe's image from file system
    @MainActor
    func deleteImage() async {
        guard let fileName = imageFileName else { return }
        let imageStorageService = ServiceContainer.shared.resolve(ImageStorageService.self)
        await imageStorageService.deleteImage(fileName: fileName)
        self.imageFileName = nil
        self.lastModified = Date()
    }
}

// MARK: - Provenance Helpers
extension Recipe {
    /// Ensure provenance metadata exists, creating it if needed
    func ensureProvenance() {
        if provenance == nil {
            // Create provenance from existing fields (migration path)
            let sourceTypeEnum: ProvenanceMetadata.SourceType
            switch sourceType {
            case .manual:
                sourceTypeEnum = .userCreated
            case .url:
                sourceTypeEnum = .imported
            case .family:
                sourceTypeEnum = sharedBy != nil ? .shared : .userCreated
            case .cookbook:
                sourceTypeEnum = .scanned
            case .scan:
                sourceTypeEnum = .scanned
            default:
                sourceTypeEnum = .userCreated
            }

            let generation = generationCount > 0 ? generationCount - 1 : 0

            provenance = ProvenanceMetadata(
                sourceType: sourceTypeEnum,
                sourceURL: sourceURL,
                sourceAttribution: sourceAttribution,
                generation: generation,
                sharedByName: sharedBy ?? passedDownBy,
                createdAt: dateAdded
            )
        }
    }

    /// Attribution text for display (uses provenance if available, falls back to legacy fields)
    var sourceAttribution: String? {
        provenance?.sourceAttribution ?? sourcePerson ?? sourceBookTitle
    }

    /// Display source for UI (provenance-aware)
    var displaySource: String {
        if let prov = provenance {
            return prov.displaySource
        }
        return sourceDisplayName
    }

    /// Whether this recipe is original (generation 0)
    var isOriginalRecipe: Bool {
        provenance?.isOriginal ?? (generationCount <= 1)
    }

    /// Whether this recipe was shared/received
    var isSharedRecipe: Bool {
        provenance?.isShared ?? (sharedBy != nil || passedDownBy != nil)
    }

    /// Display-friendly generation info
    var generationDisplayText: String? {
        if let prov = provenance, prov.generation > 0 {
            if prov.generation == 1 {
                return "1st Generation"
            } else if prov.generation == 2 {
                return "2nd Generation"
            } else if prov.generation == 3 {
                return "3rd Generation"
            } else {
                return "\(prov.generation)th Generation"
            }
        }

        if generationCount > 1 {
            return "Gen \(generationCount)"
        }

        return nil
    }

    /// Trending status from cached metrics
    var isTrending: Bool {
        provenance?.cachedMetrics.isTrending ?? false
    }

    /// Total shares from metrics
    var totalShares: Int {
        provenance?.cachedMetrics.totalShares ?? 0
    }

    /// Share count display text
    var shareCountDisplay: String {
        provenance?.cachedMetrics.displayShareCount ?? ""
    }
}

// MARK: - RecipeSourceType
enum RecipeSourceType: String, Codable, CaseIterable {
    case url = "url"
    case cookbook = "cookbook"
    case family = "family"
    case manual = "manual"
    case scan = "scan"
    case heritage = "heritage"
    case video = "video"

    var iconName: String {
        switch self {
        case .url: return "globe"
        case .cookbook: return "book.closed.fill"
        case .family: return "heart.fill"
        case .manual: return "square.and.pencil"
        case .scan: return "doc.viewfinder"
        case .heritage: return "book.pages.fill"
        case .video: return "video.circle.fill"
        }
    }

    var displayName: String {
        switch self {
        case .url: return "Website"
        case .cookbook: return "Cookbook"
        case .family: return "Family"
        case .manual: return "My Recipe"
        case .scan: return "Scanned"
        case .heritage: return "Heritage Collection"
        case .video: return "Video Import"
        }
    }
}

// MARK: - Lightweight DTO
/// Lightweight data transfer object for recipe list views
/// Prevents loading all ingredients/instructions when scrolling
struct RecipeListItem: Identifiable {
    let id: UUID
    let title: String
    let imageFileName: String?
    let sourceType: RecipeSourceType
    let sourceDisplayName: String
    let isFavorite: Bool
    let timesCooked: Int
    let dateAdded: Date
}

// MARK: - Sample Data
extension Recipe {
    static var example: Recipe {
        let recipe = Recipe(
            title: "Grandma's Chocolate Chip Cookies",
            sourceType: .family,
            instructions: [
                "Preheat oven to 375°F",
                "Cream together butter and sugars",
                "Beat in eggs and vanilla",
                "Gradually blend in dry ingredients",
                "Stir in chocolate chips",
                "Drop by rounded tablespoon onto ungreased cookie sheets",
                "Bake for 9 to 11 minutes or until golden brown"
            ],
            servings: "48 cookies",
            prepTime: "15 min",
            cookTime: "11 min"
        )
        recipe.sourcePerson = "Grandma Rose"
        recipe.sourceDate = "1987"
        recipe.timesCooked = 12
        recipe.isFavorite = true

        // Scaling metadata
        recipe.category = .cookies
        recipe.scalability = .easy
        recipe.minimumServings = 4
        recipe.maximumServings = 96

        return recipe
    }
}

// MARK: - Heritage Recipe Lifecycle
extension Recipe {
    /// Creates a deep copy of the recipe for user personalization
    /// Used when editing or sharing heritage recipes to create user's own version
    /// - Parameter context: ModelContext to insert the copy into
    /// - Returns: New Recipe instance with copied data
    func createUserCopy(context: ModelContext) -> Recipe {
        let copy = Recipe(
            title: title,
            sourceType: sourceType ?? .manual,
            instructions: instructions,
            servings: servings,
            prepTime: prepTime,
            cookTime: cookTime
        )

        // Copy basic fields
        copy.sourceURL = sourceURL
        copy.sourceBookTitle = sourceBookTitle
        copy.sourceBookAuthor = sourceBookAuthor
        copy.sourceBookPage = sourceBookPage
        copy.sourcePerson = sourcePerson
        copy.sourceDate = sourceDate
        copy.sourceStory = sourceStory
        copy.notes = notes
        copy.totalTime = totalTime

        // Copy image references (not the file itself)
        copy.imageFileName = imageFileName
        copy.sourceImageURL = sourceImageURL
        copy.firebaseImageURL = firebaseImageURL
        copy.blurhash = blurhash
        copy.imageVariants = imageVariants

        // Heritage metadata - preserve but mark as user's copy
        if isHeritageRecipe {
            copy.isHeritageRecipe = false  // User copy is no longer "official" heritage
            copy.heritageCollectionId = heritageCollectionId  // Keep collection reference
            copy.historicalText = historicalText
            copy.historicalContext = historicalContext

            // Update provenance to show it's derived from heritage
            if let originalProvenance = provenance {
                copy.provenance = ProvenanceMetadata(
                    sourceType: .shared,  // Mark as derived from heritage
                    sourceURL: originalProvenance.sourceURL,
                    sourceAttribution: originalProvenance.sourceAttribution,
                    generation: originalProvenance.generation + 1,
                    createdAt: originalProvenance.createdAt
                )
            }
        } else {
            copy.provenance = provenance
        }

        // Copy ingredients
        if let originalIngredients = ingredients {
            var copiedIngredients: [Ingredient] = []
            for (index, ingredient) in originalIngredients.enumerated() {
                let ingredientCopy = Ingredient(
                    originalText: ingredient.originalText,
                    name: ingredient.name,
                    quantity: ingredient.quantity,
                    unit: ingredient.unit,
                    category: ingredient.category ?? .other,
                    orderIndex: index
                )
                ingredientCopy.recipe = copy
                copiedIngredients.append(ingredientCopy)
            }
            copy.ingredients = copiedIngredients
        }

        // Copy collections
        copy.collections = collections

        // Copy tags
        copy.tags = tags

        // Copy scaling metadata
        copy.scalabilityRating = scalabilityRating
        copy.recipeCategory = recipeCategory
        copy.minimumServings = minimumServings
        copy.maximumServings = maximumServings
        copy.scalingNote = scalingNote

        // DON'T copy: usage stats (times cooked, last cooked, favorite status)
        // DON'T copy: personalization (card style, stickers, annotations)
        // DON'T copy: social fields (shared by, passed down, etc.)

        context.insert(copy)

        // Copy card back if it exists (for heritage recipes, preserve heritage sections)
        if let originalCardBack = cardBack {
            let cardBackCopy = RecipeCardBack(recipe: copy)

            // Copy user content
            cardBackCopy.noteToFriends = originalCardBack.noteToFriends
            cardBackCopy.personalTips = originalCardBack.personalTips
            cardBackCopy.userRating = originalCardBack.userRating
            cardBackCopy.userTags = originalCardBack.userTags

            // Copy visual customization
            cardBackCopy.backgroundStyle = originalCardBack.backgroundStyle
            cardBackCopy.textColor = originalCardBack.textColor
            cardBackCopy.showBorder = originalCardBack.showBorder
            cardBackCopy.borderColor = originalCardBack.borderColor
            cardBackCopy.fontSizeMultiplier = originalCardBack.fontSizeMultiplier

            // Copy attribution settings
            cardBackCopy.showAttribution = originalCardBack.showAttribution
            cardBackCopy.customAttributionText = originalCardBack.customAttributionText
            cardBackCopy.attributionPosition = originalCardBack.attributionPosition

            // Copy layout configuration
            cardBackCopy.visibleSections = originalCardBack.visibleSections
            cardBackCopy.layoutStyle = originalCardBack.layoutStyle

            // Copy sharing settings
            cardBackCopy.shareMessage = originalCardBack.shareMessage
            cardBackCopy.includeBackWhenSharing = originalCardBack.includeBackWhenSharing
            cardBackCopy.privacyLevel = originalCardBack.privacyLevel

            // Mark as complete if original was complete
            cardBackCopy.isComplete = originalCardBack.isComplete

            // Set timestamps
            cardBackCopy.lastEditedAt = Date()
            cardBackCopy.lastModified = Date()

            // Insert card back
            context.insert(cardBackCopy)
            copy.cardBack = cardBackCopy

            Log.info("Copied card back to user copy", category: .database, metadata: [
                "hasNote": originalCardBack.noteToFriends != nil,
                "tipsCount": originalCardBack.personalTips.count
            ])
        }

        // Copy customizations (stickers, drawings, text, etc.)
        let originalRecipeId = self.id
        let customizationsFetchDescriptor = FetchDescriptor<Customization>(
            predicate: #Predicate<Customization> { customization in
                customization.recipeId == originalRecipeId && !customization.isDeleted
            }
        )

        if let originalCustomizations = try? context.fetch(customizationsFetchDescriptor) {
            for originalCustomization in originalCustomizations {
                let customizationCopy = Customization(
                    recipeId: copy.id,
                    deviceId: originalCustomization.deviceId,
                    userId: originalCustomization.userId,
                    type: originalCustomization.type,
                    position: CGPoint(
                        x: originalCustomization.positionX,
                        y: originalCustomization.positionY
                    ),
                    size: CGSize(
                        width: originalCustomization.sizeWidth,
                        height: originalCustomization.sizeHeight
                    ),
                    rotation: originalCustomization.rotation,
                    zIndex: originalCustomization.zIndex,
                    content: originalCustomization.content,
                    vectorClock: VectorClock()
                )

                // Reset CRDT metadata for the copy
                customizationCopy.createdAt = Date()
                customizationCopy.modifiedAt = Date()

                context.insert(customizationCopy)
            }

            Log.info("Copied customizations to user copy", category: .database, metadata: [
                "count": originalCustomizations.count
            ])
        }

        Log.info("Created user copy of heritage recipe", category: .database, metadata: [
            "original": title,
            "isHeritageOriginal": isHeritageRecipe
        ])

        return copy
    }

    /// Check if this unmodified heritage recipe should be considered for cleanup
    /// Returns true if the recipe is heritage, unmodified, and has been around long enough
    var shouldConsiderForCleanup: Bool {
        guard isHeritageRecipe else { return false }

        // Never cleanup if user has personalized it
        if timesCooked > 0 || isFavorite || notes != nil && !notes!.isEmpty {
            return false
        }

        // Check if it's been around for at least 30 days
        let daysSinceAdded = Calendar.current.dateComponents([.day], from: dateAdded, to: Date()).day ?? 0
        return daysSinceAdded >= 30
    }
}

// MARK: - Security Helper Methods (Phase 7)

extension Recipe {
    /// Safely set notes with HTML sanitization (SEC-3)
    func setNotes(_ newNotes: String?) {
        guard let newNotes = newNotes else {
            self.notes = nil
            return
        }

        // SECURITY FIX: Sanitize HTML to prevent XSS attacks
        self.notes = HTMLSanitizer.shared.stripAllHTML(newNotes)
        self.modifiedAt = Date()
    }

    /// Safely set sourceURL with validation (SEC-4, SEC-5, SEC-6)
    func setSourceURL(_ urlString: String?) throws {
        guard let urlString = urlString else {
            self.sourceURL = nil
            return
        }

        // SECURITY FIX: Validate URL to prevent injection and SSRF attacks
        let validatedURL = try URLValidator.shared.validateRecipeSourceURL(urlString)

        self.sourceURL = validatedURL?.absoluteString
        self.modifiedAt = Date()
    }

    /// Safely set imageFileName with path validation (SEC-7)
    func setImageFileName(_ fileName: String?) throws {
        guard let fileName = fileName else {
            self.imageFileName = nil
            return
        }

        // SECURITY FIX: Validate file path to prevent path traversal attacks
        let validatedPath = try FilePathValidator.shared.validateImagePath(fileName)

        self.imageFileName = validatedPath
        self.modifiedAt = Date()
    }
}
