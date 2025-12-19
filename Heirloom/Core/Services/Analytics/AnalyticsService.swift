import Foundation

// MARK: - Analytics Service Protocol
@MainActor
protocol AnalyticsServiceProtocol {
    func initialize()
    func track(event: AnalyticsEvent, properties: [String: Any]?)
    func trackRecipeViewed(recipe: Recipe)
    func trackRecipeCreated(recipe: Recipe)
    func trackRecipeEdited(recipe: Recipe)
    func trackRecipeDeleted(recipeTitle: String)
    func trackRecipeFavorited(recipe: Recipe, isFavorite: Bool)
    func trackShoppingListToggle(recipe: Recipe, isInList: Bool)
    func trackSearch(query: String, resultCount: Int)
    func updateUserProperties(totalRecipes: Int, favoriteRecipes: Int)
}

// MARK: - Analytics Events
enum AnalyticsEvent: String {
    // App Lifecycle
    case appLaunched = "App Launched"
    case appBackgrounded = "App Backgrounded"
    case appForegrounded = "App Foregrounded"

    // Recipe Actions
    case recipeViewed = "Recipe Viewed"
    case recipeCreated = "Recipe Created"
    case recipeEdited = "Recipe Edited"
    case recipeDeleted = "Recipe Deleted"
    case recipeFavorited = "Recipe Favorited"
    case recipeUnfavorited = "Recipe Unfavorited"

    // Shopping List
    case addedToShoppingList = "Added to Shopping List"
    case removedFromShoppingList = "Removed from Shopping List"

    // Recipe Scaling (Smallify)
    case recipeScaled = "Recipe Scaled"
    case scalingExplanationViewed = "Scaling Explanation Viewed"
    case scaledRecipeAddedToCart = "Scaled Recipe Added to Cart"

    // Search & Discovery
    case searchPerformed = "Search Performed"
    case filterApplied = "Filter Applied"

    // Import & Export
    case recipeImported = "Recipe Imported"
    case recipeScanned = "Recipe Scanned"
    case recipeExported = "Recipe Exported"
    case recipeShared = "Recipe Shared"

    // Cooking
    case cookingStarted = "Cooking Started"
    case cookingCompleted = "Cooking Completed"
    case timerStarted = "Timer Started"
    case timerCompleted = "Timer Completed"

    // Settings
    case settingChanged = "Setting Changed"
    case dataCleared = "Data Cleared"

    // AI Services
    case aiTokensUsed = "AI Tokens Used"
    case aiIngredientParseSuccess = "AI Ingredient Parse Success"
    case aiIngredientParseFailed = "AI Ingredient Parse Failed"
    case aiCategoryDetectionSuccess = "AI Category Detection Success"
    case aiCategoryDetectionFailed = "AI Category Detection Failed"
    case aiEnhancementSuccess = "AI Enhancement Success"
    case aiEnhancementFailed = "AI Enhancement Failed"

    // Engagement Tracking (Phase 2D - Prompt 11)
    case recipeEngaged = "Recipe Engaged"
    case recipeSaved = "Recipe Saved"
    case recipeUnsaved = "Recipe Unsaved"
    case recipeTimeSpent = "Recipe Time Spent"
    case discoveryFeedViewed = "Discovery Feed Viewed"
    case trendingRecipeViewed = "Trending Recipe Viewed"
    case lineageViewed = "Lineage Viewed"
    case featureUsed = "Feature Used"
}

// MARK: - Console-Only Analytics (Fallback)
@MainActor
class ConsoleAnalyticsService: AnalyticsServiceProtocol {
    static let shared = ConsoleAnalyticsService()
    private init() {}

    func initialize() {
        print("📊 Console Analytics initialized (Mixpanel not configured)")
    }

    func track(event: AnalyticsEvent, properties: [String: Any]?) {
        print("📊 Analytics: \(event.rawValue)")
        if let props = properties {
            print("   Properties: \(props)")
        }
    }

    func trackRecipeViewed(recipe: Recipe) {
        track(event: .recipeViewed, properties: [
            "Recipe Title": recipe.title,
            "Source Type": recipe.sourceType?.rawValue ?? "unknown"
        ])
    }

    func trackRecipeCreated(recipe: Recipe) {
        track(event: .recipeCreated, properties: [
            "Recipe Title": recipe.title,
            "Ingredient Count": recipe.ingredients?.count ?? 0
        ])
    }

    func trackRecipeEdited(recipe: Recipe) {
        track(event: .recipeEdited, properties: [
            "Recipe Title": recipe.title
        ])
    }

    func trackRecipeDeleted(recipeTitle: String) {
        track(event: .recipeDeleted, properties: [
            "Recipe Title": recipeTitle
        ])
    }

    func trackRecipeFavorited(recipe: Recipe, isFavorite: Bool) {
        track(event: isFavorite ? .recipeFavorited : .recipeUnfavorited, properties: [
            "Recipe Title": recipe.title
        ])
    }

    func trackShoppingListToggle(recipe: Recipe, isInList: Bool) {
        track(event: isInList ? .addedToShoppingList : .removedFromShoppingList, properties: [
            "Recipe Title": recipe.title
        ])
    }

    func trackSearch(query: String, resultCount: Int) {
        track(event: .searchPerformed, properties: [
            "Query": query,
            "Result Count": resultCount
        ])
    }

    func updateUserProperties(totalRecipes: Int, favoriteRecipes: Int) {
        print("📊 User Properties Updated: \(totalRecipes) recipes, \(favoriteRecipes) favorites")
    }
}

// MARK: - Analytics Facade
@MainActor
class AnalyticsService {
    static let shared = AnalyticsService()
    private var service: AnalyticsServiceProtocol

    private init() {
        // Try to use Mixpanel if available, otherwise fall back to console logging
        #if canImport(Mixpanel)
        self.service = MixpanelService.shared
        #else
        self.service = ConsoleAnalyticsService.shared
        #endif
    }

    func initialize() {
        service.initialize()
    }

    func track(event: AnalyticsEvent, properties: [String: Any]? = nil) {
        service.track(event: event, properties: properties)
    }

    func trackRecipeViewed(recipe: Recipe) {
        service.trackRecipeViewed(recipe: recipe)
    }

    func trackRecipeCreated(recipe: Recipe) {
        service.trackRecipeCreated(recipe: recipe)
    }

    func trackRecipeEdited(recipe: Recipe) {
        service.trackRecipeEdited(recipe: recipe)
    }

    func trackRecipeDeleted(recipeTitle: String) {
        service.trackRecipeDeleted(recipeTitle: recipeTitle)
    }

    func trackRecipeFavorited(recipe: Recipe, isFavorite: Bool) {
        service.trackRecipeFavorited(recipe: recipe, isFavorite: isFavorite)
    }

    func trackShoppingListToggle(recipe: Recipe, isInList: Bool) {
        service.trackShoppingListToggle(recipe: recipe, isInList: isInList)
    }

    func trackSearch(query: String, resultCount: Int) {
        service.trackSearch(query: query, resultCount: resultCount)
    }

    func updateUserProperties(totalRecipes: Int, favoriteRecipes: Int) {
        service.updateUserProperties(totalRecipes: totalRecipes, favoriteRecipes: favoriteRecipes)
    }
}
