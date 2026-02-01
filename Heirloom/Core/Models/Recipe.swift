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
    var sourceCookbook: String? // Name of cookbook for PDF imports

    // MARK: - Multi-Recipe Source Tracking
    /// Parent import item ID (for recipes extracted from multi-recipe sources)
    var sourceImportItemID: UUID?

    /// Position in multi-recipe source (1st, 2nd, 3rd recipe from same image/page)
    var sourceRecipeIndex: Int?

    // MARK: - Content
    /// Image stored in file system, not database (per Systems Architect recommendation)
    /// Path relative to ImageStorageService.imagesDirectory
    var imageFileName: String?

    /// Original image URL for potential re-download
    var sourceImageURL: String?

    /// Firebase Storage URL for synced images
    var firebaseImageURL: String?

    // MARK: - Theme Collections (Collections 2.1)
    /// Flag indicating this is a theme recipe from curated collections
    var isThemeRecipe: Bool = false

    /// Unique theme recipe ID from Firebase (e.g., "automat-001", "presidential-002")
    /// Used for progressive unlock tracking to identify individual recipes
    var themeRecipeId: String?

    /// ID of the theme this recipe belongs to
    var sourceThemeId: String?

    /// Day on which this theme recipe unlocks (1-14)
    var unlockDay: Int?

    /// Blurhash for progressive image loading placeholder
    var blurhash: String?

    /// Image variant URLs for different sizes (hero, card, thumbnail, collection-cover)
    /// Keys: "hero", "card", "thumbnail", "collection-cover"
    var imageVariants: [String: String]?

    /// Original historical text for Artifact View (theme recipes only)
    var historicalText: String?

    /// Historical context and background story (theme recipes only)
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

    // MARK: - Duplicate Detection
    /// SHA256 hash of normalized title + ingredients for duplicate detection
    /// Format: SHA256(lowercase(title) + sorted(lowercase(ingredients)))
    var contentHash: String?

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

    // MARK: - Public Discovery (Phase 11)
    /// Whether this recipe is published to public discovery feed
    var isPublic: Bool = false

    /// Firestore document ID in publicRecipes collection (when published)
    var publicRecipeId: String?

    /// When this recipe was first published publicly
    var publicPublishedAt: Date?

    /// Public view count (tracked in Firestore)
    var publicViewCount: Int = 0

    /// Number of times saved from public discovery (tracked in Firestore)
    var publicSaveCount: Int = 0

    // MARK: - Camera Origin Detection (Phase 11 - Path A+)
    /// Confidence level that this recipe's photo came from device camera
    /// Used to enforce camera-only public sharing policy
    var cameraOriginConfidence: CameraOriginConfidence = CameraOriginConfidence.likelyCamera

    // MARK: - Public Discovery Attribution (for saved copies)
    /// Link to original public recipe (if saved from discovery)
    var sourcePublicRecipeId: String?

    /// Original creator's Firebase user ID
    var sourcePublicRecipeCreatorId: String?

    /// Original creator's display name (cached)
    var sourcePublicRecipeCreatorName: String?

    /// When we last synced/checked the original
    var sourcePublicRecipeLastSynced: Date?

    /// Whether original recipe still exists (cached check)
    var sourcePublicRecipeStillAvailable: Bool = true

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

    /// Firebase document ID for theme recipes synced from Firebase
    var firebaseId: String?

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
            // For scanned recipes, show cookbook info if available (from PDF imports)
            if let title = sourceBookTitle {
                if let page = sourceBookPage {
                    return "\(title), p. \(page)"
                }
                return title
            }
            return "Scanned Recipe"
        case .manual:
            return Recipe.currentUserDisplayName()
        case .heritage:
            // For theme recipes, show the collection name if available
            if let themeId = sourceThemeId,
               let collection = collections?.first(where: { $0.sourceTheme?.firebaseId == themeId }) {
                return collection.name
            }
            return "Theme Collection"
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
                // Use TikTok deep link scheme for proper in-app navigation
                // Format: tiktok://user/profile?username=creatorname (without @)
                let cleanUsername = creatorName.replacingOccurrences(of: "@", with: "")
                guard let encodedUsername = cleanUsername.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
                    return nil
                }
                return URL(string: "tiktok://user/profile?username=\(encodedUsername)")
            } else if sourceURL.contains("youtube.com") || sourceURL.contains("youtu.be") {
                return URL(string: "https://www.youtube.com/@\(creatorName)")
            } else if sourceURL.contains("instagram.com") {
                return URL(string: "https://www.instagram.com/\(creatorName)")
            }
        }

        // Default: TikTok format (most common for cooking videos)
        return URL(string: "https://www.tiktok.com/@\(creatorName)")
    }

    /// Get the current user's display name for recipe attribution
    /// Falls back to email prefix or "My Recipe" if display name not available
    static func currentUserDisplayName() -> String {
        // Access FirebaseAuth via ServiceContainer
        // Use MainActor.assumeIsolated since ServiceContainer.shared is @MainActor
        // This is safe because models are typically accessed from SwiftUI views on MainActor
        guard Thread.isMainThread else {
            return "My Recipe"
        }

        return MainActor.assumeIsolated {
            let container = ServiceContainer.shared
            let authService = container.resolve(FirebaseAuthService.self)
            if let displayName = authService.currentUser?.displayName, !displayName.isEmpty {
                return displayName
            }
            if let email = authService.currentUser?.email {
                // Return first part of email (before @) if display name not set
                return email.components(separatedBy: "@").first ?? "My Recipe"
            }
            return "My Recipe"
        }
    }

    /// Name of the heritage/theme collection this recipe belongs to (for card back display)
    var heritageCollection: String? {
        guard isThemeRecipe, let themeId = sourceThemeId else { return nil }

        // Find the theme collection this recipe belongs to
        return collections?.first(where: { $0.sourceTheme?.firebaseId == themeId })?.name
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
        if let parsed = ServingsParser.parse(servings) {
            return parsed
        } else {
            ScalingDiagnostics.shared.logServingsParsingFailure(recipe: self, rawServings: servings)
            return 4
        }
    }

    /// Validates recipe scaling capability and identifies issues
    var scalingValidation: ScalingValidation {
        var issues: [ScalingIssue] = []

        // Check servings
        if servings == nil || parsedServingCount == 4 {
            issues.append(.servingsUnparseable(raw: servings))
        }

        // Check ingredient quantities
        let ingredients = self.ingredients ?? []
        let missingQuantities = ingredients.filter { $0.quantity == nil }
        if !missingQuantities.isEmpty {
            issues.append(.missingQuantities(
                count: missingQuantities.count,
                total: ingredients.count
            ))

            ScalingDiagnostics.shared.logMissingQuantities(
                recipe: self,
                missingCount: missingQuantities.count,
                totalCount: ingredients.count
            )
        }

        return ScalingValidation(
            isFullyScalable: issues.isEmpty,
            issues: issues
        )
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
    enum SharingPermissionLevel: String, Codable, CaseIterable {
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
        case .heritage: return "Theme Collection"
        case .video: return "Video Import"
        }
    }

    /// User-facing explanation for why this source type cannot be shared publicly
    var publicSharingBlockedReason: String? {
        switch self {
        case .scan:
            return nil  // Camera sources eligible (check confidence separately)
        case .url:
            return "Recipes imported from websites can only be shared privately. Public sharing is reserved for your own family recipes captured with your camera."
        case .video:
            return "Recipes converted from videos can only be shared privately. Public sharing is reserved for your own family recipes captured with your camera."
        case .manual:
            return "Manually entered recipes can only be shared privately. To share publicly, photograph the recipe from a printed or handwritten copy."
        case .cookbook:
            return "Cookbook recipes can only be shared privately to respect copyright. Photograph your own family recipe cards or handwritten copies to share publicly."
        case .family, .heritage:
            return "Recipes you've received from others can only be shared privately."
        }
    }
}

/// Confidence level that a recipe's photo originated from device camera
/// Used to enforce camera-only public sharing policy (screenshots and downloads blocked)
enum CameraOriginConfidence: String, Codable {
    /// Definite camera photo (Live Photo, HDR, Portrait mode)
    case definitelyCamera

    /// Likely camera photo (regular photo from camera roll, no disqualifying signals)
    case likelyCamera

    /// Definitely not camera (screenshot, cloud shared, iTunes synced, downloaded)
    case definitelyNotCamera

    /// User-facing explanation for why photo failed camera detection
    var publicSharingBlockedReason: String? {
        switch self {
        case .definitelyCamera, .likelyCamera:
            return nil
        case .definitelyNotCamera:
            return "This photo appears to be a screenshot or downloaded image. Public sharing requires photos taken with your device camera."
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

// MARK: - Theme Recipe Lifecycle
extension Recipe {
    /// Creates a deep copy of the recipe for user personalization
    /// Used when editing or sharing theme recipes to create user's own version
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

        // Theme metadata - preserve but mark as user's copy
        if isThemeRecipe {
            copy.isThemeRecipe = false  // User copy is no longer "official" theme recipe
            copy.sourceThemeId = sourceThemeId  // Keep theme reference
            copy.historicalText = historicalText
            copy.historicalContext = historicalContext

            // Update provenance to show it's derived from theme collection
            if let originalProvenance = provenance {
                copy.provenance = ProvenanceMetadata(
                    sourceType: .shared,  // Mark as derived from theme
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

        Log.info("Created user copy of theme recipe", category: .database, metadata: [
            "original": title,
            "isThemeOriginal": isThemeRecipe
        ])

        return copy
    }

    /// Check if this unmodified theme recipe should be considered for cleanup
    /// Returns true if the recipe is a theme recipe, unmodified, and has been around long enough
    var shouldConsiderForCleanup: Bool {
        guard isThemeRecipe else { return false }

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

// MARK: - Sharing Validation

extension Recipe {
    /// Sample recipe titles (onboarding recipes that all users receive)
    private static let sampleRecipeTitles: Set<String> = [
        "Classic Grilled Cheese",
        "Tomato Soup",
        "Perfect Grilled Cheese",
        "Creamy Tomato Soup"
    ]

    /// Check if this is an onboarding sample recipe
    var isSampleRecipe: Bool {
        // Check title match + presence of sourceStory (onboarding recipes have this)
        return Self.sampleRecipeTitles.contains(title) && sourceStory != nil
    }

    /// Check if recipe has been significantly modified from its original form
    /// Used to determine if a modified sample/theme recipe can be shared
    var hasSignificantModifications: Bool {
        // Must be based on sample or theme
        guard isSampleRecipe || isThemeRecipe else {
            return false // Not applicable
        }

        // Track modifications
        var modifications = 0

        // 1. Title changed from original (strongest indicator)
        if isSampleRecipe && !Self.sampleRecipeTitles.contains(title) {
            return true // Title change alone = significant
        }

        // 2. For theme recipes, any title change = significant
        if isThemeRecipe {
            // We don't track original theme titles, but if user created this
            // as a personal copy, provenance will show it
            if let provenance = provenance, provenance.sourceType == .imported {
                // This is the original theme recipe, not a copy
                return false
            }
        }

        // 3. Check ingredient changes (need at least 50% modified)
        // Note: This is approximate since we don't store original ingredients
        if let ingredients = ingredients, !ingredients.isEmpty {
            modifications += 1
        }

        // 4. Check instruction changes
        if !instructions.isEmpty && instructions.count > 3 {
            modifications += 1
        }

        // 5. Has notes added (personal touch)
        if notes != nil && !notes!.isEmpty {
            modifications += 1
        }

        // 6. Has image added/changed
        if imageFileName != nil {
            modifications += 1
        }

        // Require at least 2 modifications beyond just having content
        return modifications >= 2
    }

    // MARK: - Public Discovery Computed Properties

    /// Whether this recipe was saved from public discovery and has upstream link
    var hasPublicUpstream: Bool {
        sourcePublicRecipeId != nil
    }

    /// Whether this recipe can be made public (for publishing)
    /// Enforces camera-only policy: only recipes from camera with verified confidence
    var canMakePublic: Bool {
        // First check basic sharing validation
        let (canShare, _) = canShare()
        guard canShare && !isThemeRecipe && !isSampleRecipe else {
            return false
        }

        // Check source type - only camera/scan sources are eligible
        guard let sourceType = sourceType, sourceType == .scan else {
            return false
        }

        // Check camera origin confidence - must not be screenshot/download
        guard cameraOriginConfidence != .definitelyNotCamera else {
            return false
        }

        return true
    }

    /// Get user-facing reason why this recipe cannot be made public
    /// Returns nil if recipe can be made public
    func publicSharingBlockedReason() -> String? {
        // Check basic sharing first
        let (canShare, reason) = canShare()
        if !canShare {
            return reason
        }

        if isThemeRecipe {
            return "Theme recipes can't be shared - all users receive these automatically through the theme system."
        }

        if isSampleRecipe {
            return "Sample recipes can't be shared - everyone already has this recipe."
        }

        // Check source type
        if let sourceType = sourceType, sourceType != .scan {
            return sourceType.publicSharingBlockedReason
        }

        // Check camera origin confidence
        if cameraOriginConfidence == .definitelyNotCamera {
            return cameraOriginConfidence.publicSharingBlockedReason
        }

        return nil
    }

    /// Determine if this recipe can be shared and provide reason if not
    /// - Returns: (canShare: Bool, reason: String?)
    func canShare() -> (canShare: Bool, reason: String?) {
        // 1. Sample recipes can never be shared - everyone already has them
        if isSampleRecipe {
            return (false, "Sample recipes can't be shared - everyone already has this recipe.")
        }

        // 2. Theme recipes can never be shared - all users receive them automatically
        if isThemeRecipe {
            return (false, "Theme recipes can't be shared - all users receive these automatically through the theme system.")
        }

        // 3. Recipe can be shared
        return (true, nil)
    }
}

// MARK: - Scaling Validation

extension Recipe {
    /// Result of scaling validation check
    struct ScalingValidation {
        let isFullyScalable: Bool
        let issues: [ScalingIssue]
    }

    /// Issues that prevent full scaling capability
    enum ScalingIssue {
        case servingsUnparseable(raw: String?)
        case missingQuantities(count: Int, total: Int)

        /// User-friendly message describing the issue
        var userMessage: String {
            switch self {
            case .servingsUnparseable(let raw):
                return "Could not determine serving count from '\(raw ?? "none")'"
            case .missingQuantities(let count, let total):
                return "\(count) of \(total) ingredients missing quantities"
            }
        }
    }
}
