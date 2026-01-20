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

    // Collection Actions (Collections-First Architecture)
    case collectionViewed = "Collection Viewed"
    case collectionCreated = "Collection Created"
    case collectionEdited = "Collection Edited"
    case collectionDeleted = "Collection Deleted"
    case allRecipesViewed = "All Recipes Viewed"
    case recipeBatchSelected = "Recipe Batch Selected"
    case recipesAddedToCollection = "Recipes Added to Collection"

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

    // PDF Import (Phase 7.3)
    case pdfImportStarted = "PDF Import Started"
    case pdfImportCompleted = "PDF Import Completed"
    case pdfImportFailed = "PDF Import Failed"
    case pdfValidationFailed = "PDF Validation Failed"
    case largePDFPaywallShown = "Large PDF Paywall Shown"
    case multiPageRecipeDetected = "Multi-Page Recipe Detected"
    case multiPageAnalysisComplete = "Multi-Page Analysis Complete"
    case pdfPageRendered = "PDF Page Rendered"

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
    case aiSpellCheckSuccess = "AI Spell Check Success"
    case aiSpellCheckFailed = "AI Spell Check Failed"
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

    // Card Personalization
    case cardFlipped = "Card Flipped"

    // Help & Support
    case helpCenterOpened = "Help Center Opened"
    case helpArticleViewed = "Help Article Viewed"
    case helpSectionViewed = "Help Section Viewed"
    case helpSearchPerformed = "Help Search Performed"
    case faqOpened = "FAQ Opened"
    case contactSupportTapped = "Contact Support Tapped"
    case bugReportSubmitted = "Bug Report Submitted"
    case featureRequestSubmitted = "Feature Request Submitted"

    // Store & Subscriptions
    case storeProductsLoaded = "Store Products Loaded"
    case storeLoadFailed = "Store Load Failed"
    case purchaseStarted = "Purchase Started"
    case purchaseSuccess = "Purchase Success"
    case purchaseFailed = "Purchase Failed"
    case purchaseCancelled = "Purchase Cancelled"
    case purchasePending = "Purchase Pending"
    case restoreStarted = "Restore Started"
    case restoreCompleted = "Restore Completed"
    case subscriptionStatusChecked = "Subscription Status Checked"
    case subscriptionStatusChanged = "Subscription Status Changed"
    case trialStarted = "Trial Started"
    case trialAdjusted = "Trial Adjusted"
    case paywallShown = "Paywall Shown"
    case paywallDismissed = "Paywall Dismissed"
    case paywallStrikeRuleActivated = "Paywall Strike Rule Activated"
    case recipesExported = "Recipes Exported"
    case purchasesRestored = "Purchases Restored"
    case manageSubscriptionOpened = "Manage Subscription Opened"
}

// MARK: - Console-Only Analytics (Fallback)
@MainActor
class ConsoleAnalyticsService: AnalyticsServiceProtocol {
    init() {}

    func initialize() {
        Log.info("Console Analytics initialized (Mixpanel not configured)", category: .general)
    }

    func track(event: AnalyticsEvent, properties: [String: Any]?) {
        Log.debug("Analytics event tracked", category: .general, metadata: ["event": event.rawValue])
        if let props = properties {
            Log.debug("Analytics event properties", category: .general, metadata: props)
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
        Log.debug("User properties updated", category: .general, metadata: [
            "totalRecipes": totalRecipes,
            "favoriteRecipes": favoriteRecipes
        ])
    }
}

// MARK: - Analytics Facade
@MainActor
class AnalyticsService: AnalyticsServiceProtocol {
    private var service: AnalyticsServiceProtocol

    init() {
        // Try to use Mixpanel if available, otherwise fall back to console logging
        #if canImport(Mixpanel)
        self.service = MixpanelService()
        #else
        self.service = ConsoleAnalyticsService()
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
