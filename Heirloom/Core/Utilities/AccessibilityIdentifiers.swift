import Foundation

/// Centralized accessibility identifiers for UI testing
/// Usage: .accessibilityIdentifier(AccessibilityIdentifiers.RecipeList.addButton)
enum AccessibilityIdentifiers {

    // MARK: - Recipe List
    enum RecipeList {
        static let view = "recipeListView"
        static let addButton = "recipeListAddButton"
        static let searchBar = "recipeListSearchBar"
        static let filterButton = "recipeListFilterButton"
        static let sortButton = "recipeListSortButton"
        static let recipeCell = "recipeListCell"
        static let recipeCellTitle = "recipeListCellTitle"
        static let recipeCellImage = "recipeListCellImage"
        static let recipeCellServings = "recipeListCellServings"
        static let emptyState = "recipeListEmptyState"
    }

    // MARK: - Recipe Detail
    enum RecipeDetail {
        static let view = "recipeDetailView"
        static let scrollView = "recipeDetailScrollView"
        static let heroImage = "recipeDetailHeroImage"
        static let title = "recipeDetailTitle"
        static let servingsLabel = "recipeDetailServingsLabel"
        static let prepTimeLabel = "recipeDetailPrepTimeLabel"
        static let cookTimeLabel = "recipeDetailCookTimeLabel"
        static let totalTimeLabel = "recipeDetailTotalTimeLabel"

        // Card flip
        static let flipCard = "recipeDetailFlipCard"
        static let flipButton = "recipeDetailFlipButton"
        static let flipHint = "recipeDetailFlipHint"
        static let cardFront = "recipeDetailCardFront"
        static let cardBack = "recipeDetailCardBack"

        // Ingredients
        static let ingredientsSection = "recipeDetailIngredientsSection"
        static let ingredientRow = "recipeDetailIngredientRow"
        static let ingredientCheckbox = "recipeDetailIngredientCheckbox"
        static let ingredientText = "recipeDetailIngredientText"

        // Instructions
        static let instructionsSection = "recipeDetailInstructionsSection"
        static let instructionRow = "recipeDetailInstructionRow"
        static let instructionNumber = "recipeDetailInstructionNumber"
        static let instructionText = "recipeDetailInstructionText"

        // Actions
        static let shareButton = "recipeDetailShareButton"
        static let editButton = "recipeDetailEditButton"
        static let deleteButton = "recipeDetailDeleteButton"
        static let personalizeButton = "recipeDetailPersonalizeButton"
        static let addToShoppingListButton = "recipeDetailAddToShoppingListButton"
        static let scaleButton = "recipeDetailScaleButton"
    }

    // MARK: - Recipe Import
    enum RecipeImport {
        static let view = "recipeImportView"
        static let urlField = "recipeImportURLField"
        static let pasteButton = "recipeImportPasteButton"
        static let importButton = "recipeImportImportButton"
        static let scanButton = "recipeImportScanButton"
        static let photoPickerButton = "recipeImportPhotoPickerButton"
        static let manualEntryButton = "recipeImportManualEntryButton"
        static let cancelButton = "recipeImportCancelButton"

        // Multi-recipe flow
        static let multiRecipeSheet = "recipeImportMultiRecipeSheet"
        static let recipePreviewCard = "recipeImportPreviewCard"
        static let recipePreviewTitle = "recipeImportPreviewTitle"
        static let selectRecipeButton = "recipeImportSelectRecipeButton"
        static let importSelectedButton = "recipeImportSelectedButton"

        // Progress
        static let progressView = "recipeImportProgressView"
        static let progressLabel = "recipeImportProgressLabel"
        static let errorAlert = "recipeImportErrorAlert"
    }

    // MARK: - Shopping List
    enum ShoppingList {
        static let view = "shoppingListView"
        static let addRecipeButton = "shoppingListAddRecipeButton"
        static let clearAllButton = "shoppingListClearAllButton"
        static let shareButton = "shoppingListShareButton"
        static let exportRemindersButton = "shoppingListExportRemindersButton"

        // Categories
        static let categorySection = "shoppingListCategorySection"
        static let categoryHeader = "shoppingListCategoryHeader"

        // Items
        static let itemRow = "shoppingListItemRow"
        static let itemCheckbox = "shoppingListItemCheckbox"
        static let itemText = "shoppingListItemText"
        static let itemQuantity = "shoppingListItemQuantity"

        // Recipe selection
        static let recipeSelectionSheet = "shoppingListRecipeSelectionSheet"
        static let recipeRow = "shoppingListRecipeRow"
        static let recipeCheckbox = "shoppingListRecipeCheckbox"
        static let servingsField = "shoppingListServingsField"
        static let addRecipesToListButton = "shoppingListAddRecipesToListButton"

        // Empty state
        static let emptyState = "shoppingListEmptyState"
        static let emptyStateAddButton = "shoppingListEmptyStateAddButton"
    }

    // MARK: - Card Personalization
    enum CardPersonalization {
        static let view = "cardPersonalizationView"
        static let previewCard = "cardPersonalizationPreviewCard"
        static let doneButton = "cardPersonalizationDoneButton"
        static let cancelButton = "cardPersonalizationCancelButton"

        // Background styling
        static let backgroundTab = "cardPersonalizationBackgroundTab"
        static let colorPicker = "cardPersonalizationColorPicker"
        static let gradientPicker = "cardPersonalizationGradientPicker"
        static let patternPicker = "cardPersonalizationPatternPicker"
        static let texturePicker = "cardPersonalizationTexturePicker"

        // Stickers
        static let stickersTab = "cardPersonalizationStickersTab"
        static let stickerPicker = "cardPersonalizationStickerPicker"
        static let stickerButton = "cardPersonalizationStickerButton"
        static let addStickerButton = "cardPersonalizationAddStickerButton"
        static let deleteStickerButton = "cardPersonalizationDeleteStickerButton"

        // Annotations
        static let annotationsTab = "cardPersonalizationAnnotationsTab"
        static let addAnnotationButton = "cardPersonalizationAddAnnotationButton"
        static let annotationTextField = "cardPersonalizationAnnotationTextField"

        // Love marks
        static let loveMarksTab = "cardPersonalizationLoveMarksTab"
        static let coffeeStainToggle = "cardPersonalizationCoffeeStainToggle"
        static let wornEdgesToggle = "cardPersonalizationWornEdgesToggle"

        // Card back
        static let cardBackTab = "cardPersonalizationCardBackTab"
        static let noteToFriendsField = "cardPersonalizationNoteToFriendsField"
        static let ratingPicker = "cardPersonalizationRatingPicker"
        static let tipField = "cardPersonalizationTipField"
    }

    // MARK: - Scaling
    enum Scaling {
        static let sheet = "scalingSheet"
        static let servingsField = "scalingServingsField"
        static let servingsStepper = "scalingServingsStepper"
        static let scaleFactorLabel = "scalingScaleFactorLabel"
        static let warningBanner = "scalingWarningBanner"
        static let equipmentSuggestionsSection = "scalingEquipmentSuggestionsSection"
        static let cookingTimeAdjustmentSection = "scalingCookingTimeAdjustmentSection"
        static let applyButton = "scalingApplyButton"
        static let cancelButton = "scalingCancelButton"
        static let resetButton = "scalingResetButton"
    }

    // MARK: - Settings
    enum Settings {
        static let view = "settingsView"

        // iCloud section
        static let iCloudSection = "settingsiCloudSection"
        static let iCloudStatusLabel = "settingsiCloudStatusLabel"
        static let syncNowButton = "settingsSyncNowButton"

        // User Experience section
        static let userExperienceSection = "settingsUserExperienceSection"
        static let hapticsToggle = "settingsHapticsToggle"
        static let soundToggle = "settingsSoundToggle"

        // Data Management section
        static let dataManagementSection = "settingsDataManagementSection"
        static let exportDataButton = "settingsExportDataButton"
        static let importDataButton = "settingsImportDataButton"
        static let clearCacheButton = "settingsClearCacheButton"

        // About section
        static let aboutSection = "settingsAboutSection"
        static let versionLabel = "settingsVersionLabel"
        static let privacyPolicyButton = "settingsPrivacyPolicyButton"
        static let termsButton = "settingsTermsButton"
        static let contactSupportButton = "settingsContactSupportButton"
    }

    // MARK: - Tab Bar
    enum TabBar {
        static let view = "tabBarView"
        static let recipesTab = "tabBarRecipesTab"
        static let addTab = "tabBarAddTab"
        static let shoppingTab = "tabBarShoppingTab"
        static let partiesTab = "tabBarPartiesTab"
        static let settingsTab = "tabBarSettingsTab"
    }

    // MARK: - Onboarding
    enum Onboarding {
        static let view = "onboardingView"
        static let pageIndicator = "onboardingPageIndicator"
        static let nextButton = "onboardingNextButton"
        static let skipButton = "onboardingSkipButton"
        static let getStartedButton = "onboardingGetStartedButton"
    }

    // MARK: - Common UI Elements
    enum Common {
        static let navigationTitle = "navigationTitle"
        static let navigationBackButton = "navigationBackButton"
        static let navigationCloseButton = "navigationCloseButton"
        static let loadingSpinner = "loadingSpinner"
        static let errorView = "errorView"
        static let retryButton = "retryButton"
        static let confirmationAlert = "confirmationAlert"
        static let confirmButton = "confirmButton"
        static let cancelButton = "cancelButton"
        static let toast = "toast"
    }

    // MARK: - Helper Methods

    /// Generate indexed identifier for lists
    /// Example: AccessibilityIdentifiers.indexed(RecipeList.recipeCell, index: 0) -> "recipeListCell_0"
    static func indexed(_ identifier: String, index: Int) -> String {
        return "\(identifier)_\(index)"
    }

    /// Generate identifier with UUID suffix
    /// Example: AccessibilityIdentifiers.withID(RecipeList.recipeCell, id: uuid) -> "recipeListCell_UUID"
    static func withID(_ identifier: String, id: UUID) -> String {
        return "\(identifier)_\(id.uuidString)"
    }

    /// Generate identifier with string suffix
    /// Example: AccessibilityIdentifiers.with(RecipeList.recipeCell, suffix: "featured") -> "recipeListCell_featured"
    static func with(_ identifier: String, suffix: String) -> String {
        return "\(identifier)_\(suffix)"
    }
}
