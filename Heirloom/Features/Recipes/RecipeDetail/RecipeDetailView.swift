import SwiftUI
import SwiftData
import FirebaseFirestore
import FirebaseAuth

struct RecipeDetailView: View {
    let recipe: Recipe

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.firebaseSync) private var firebaseSync
    @Environment(\.firebaseAuth) private var firebaseAuth
    @Environment(\.network) private var networkMonitor
    @State private var isOffline = false  // Local state for instant UI updates
    @State private var showDeleteConfirmation = false
    @State private var showSignInPrompt = false
    @State private var showFirebaseSignIn = false
    @State private var isDeleting = false
    @State private var showEditSheet = false
    @State private var showCookingMode = false
    @State private var showShareSheet = false
    @State private var showTagCollectionPicker = false
    @State private var showCardPersonalization = false
    @State private var showCloudKitShare = false
    @State private var showHeirloomExplanation = false
    @State private var showHeritageEditConfirmation = false
    @State private var recipeToEdit: Recipe?
    @State private var servingMultiplier: Double = 1.0
    @State private var targetServings: Int = 0
    @State private var showScalingExplanation = false
    @State private var showScalingRepair = false
    @State private var showComments = false
    @State private var isCardFlipped = false
    @State private var showCardBackEditor = false
    @State private var cardBackRefreshTrigger = UUID()
    @State private var selectedCollection: RecipeCollection?
    @State private var showVideoAttributionSheet = false

    // Public recipe discovery (Phase 11)
    @State private var showOwnershipVerification = false
    @State private var showPublishSheet = false
    @State private var showUnpublishConfirmation = false
    @State private var selectedPublicRecipeId: String?

    // Version selector
    @StateObject private var versionViewModel = RecipeVersionSelectorViewModel()
    @State private var selectedVersion: RecipeLineageVersion?
    @State private var showLineageView = false

    // Language toggle (for multilingual recipes)
    @State private var showOriginalLanguage = false

    // Coach mark for first-time recipe view
    @State private var showRecipeCoachMark = false

    // Card flip nudge (first-time hint animation)
    @State private var shouldShowFlipNudge = false

    // AI Image generation
    private var recipeImageGenerator: any RecipeImageGeneratorProtocol {
        ServiceContainer.shared.resolve((any RecipeImageGeneratorProtocol).self)
    }

    private var backendConfig: BackendConfig { ServiceContainer.shared.resolve(BackendConfig.self) }
    @State private var isDiffExpanded = false

    // Notification service
    @EnvironmentObject private var notificationService: FirebaseNotificationService

    // Using concrete type for export functionality
    private var exportService: RecipeExportService { ServiceContainer.shared.resolve(RecipeExportService.self) }

    // Using concrete type for toast notifications
    private var toastManager: ToastManager { ServiceContainer.shared.resolve(ToastManager.self) }

    private var analytics: AnalyticsService { ServiceContainer.shared.resolve(AnalyticsService.self) }

    private var commentService: CommentService { ServiceContainer.shared.resolve(CommentService.self) }

    private var lineageService: RecipeLineageService { ServiceContainer.shared.resolve(RecipeLineageService.self) }

    // MARK: - Computed Display Properties

    /// The title to display (from selected version or base recipe)
    private var displayTitle: String {
        // Show original language if toggle is on and original exists
        if showOriginalLanguage, let originalTitle = recipe.originalTitle {
            return originalTitle
        }
        return selectedVersion?.title ?? recipe.title
    }

    /// The ingredients to display (from selected version or local recipe)
    private var displayIngredients: [Ingredient]? {
        // If viewing a non-current version, try to get its ingredients
        if let selected = selectedVersion, !selected.isCurrent {
            // Try local recipe first (for versions that have a full Recipe object)
            if let versionRecipe = selected.recipe {
                return versionRecipe.ingredients
            }
            // Try parsing Firebase data
            if let recipeData = selected.recipeData,
               let ingredientsData = recipeData["ingredients"] as? [[String: Any]] {
                // Convert Firebase ingredient data to Ingredient objects for display
                let ingredients = ingredientsData.compactMap { data -> Ingredient? in
                    guard let originalText = data["originalText"] as? String else { return nil }
                    let ingredient = Ingredient(
                        originalText: originalText,
                        name: data["name"] as? String ?? originalText,
                        quantity: data["quantity"] as? Double,
                        unit: data["unit"] as? String,
                        category: GroceryCategory(rawValue: data["category"] as? String ?? "") ?? .other,
                        orderIndex: data["orderIndex"] as? Int ?? 0  // Use actual orderIndex from Firebase
                    )
                    // Set additional properties
                    ingredient.preparation = data["preparation"] as? String
                    ingredient.size = data["size"] as? String
                    ingredient.quantityMax = data["quantityMax"] as? Double
                    ingredient.normalizedUnit = data["normalizedUnit"] as? String
                    ingredient.isOptional = data["isOptional"] as? Bool ?? false
                    return ingredient
                }
                // Sort by orderIndex to preserve original order
                return ingredients.sorted { $0.orderIndex < $1.orderIndex }
            }
        }
        // Default: show local recipe's ingredients
        return recipe.ingredients
    }

    /// The instructions to display (from selected version or local recipe)
    private var displayInstructions: [String] {
        // If viewing a non-current version, get its instructions
        if let selected = selectedVersion, !selected.isCurrent {
            // Try local recipe first (for versions that have a full Recipe object)
            if let versionRecipe = selected.recipe {
                // Show original language if toggle is on and available
                if showOriginalLanguage, let originalInstructions = versionRecipe.originalInstructions {
                    return originalInstructions
                }
                return versionRecipe.instructions
            }
            // Try Firebase data
            if let recipeData = selected.recipeData,
               let instructions = recipeData["instructions"] as? [String] {
                return instructions
            }
        }
        // Default: show local recipe's instructions
        if showOriginalLanguage, let originalInstructions = recipe.originalInstructions {
            return originalInstructions
        }
        return recipe.instructions
    }

    /// The servings to display (from selected version or local recipe)
    private var displayServings: String? {
        if let selected = selectedVersion, !selected.isCurrent {
            if let versionRecipe = selected.recipe {
                return versionRecipe.servings
            }
            if let recipeData = selected.recipeData {
                return recipeData["servings"] as? String
            }
        }
        return recipe.servings
    }

    /// The prep time to display (from selected version or local recipe)
    private var displayPrepTime: String? {
        if let selected = selectedVersion, !selected.isCurrent {
            if let versionRecipe = selected.recipe {
                return versionRecipe.prepTime
            }
            if let recipeData = selected.recipeData {
                return recipeData["prepTime"] as? String
            }
        }
        return recipe.prepTime
    }

    /// The cook time to display (from selected version or local recipe)
    private var displayCookTime: String? {
        if let selected = selectedVersion, !selected.isCurrent {
            if let versionRecipe = selected.recipe {
                return versionRecipe.cookTime
            }
            if let recipeData = selected.recipeData {
                return recipeData["cookTime"] as? String
            }
        }
        return recipe.cookTime
    }

    /// The notes to display (from selected version or local recipe)
    private var displayNotes: String? {
        if let selected = selectedVersion, !selected.isCurrent {
            if let versionRecipe = selected.recipe {
                return versionRecipe.notes
            }
            if let recipeData = selected.recipeData {
                return recipeData["notes"] as? String
            }
        }
        return recipe.notes
    }

    /// The image filename to display (from selected version or base recipe)
    private var displayImageFileName: String? {
        if let selected = selectedVersion {
            // If viewing current version's recipe, use its image
            if let versionRecipe = selected.recipe {
                Log.debug("Using local recipe image", category: .ui, metadata: [
                    "imageFileName": versionRecipe.imageFileName ?? "nil",
                    "generation": selected.generation
                ])
                return versionRecipe.imageFileName
            }
            // If viewing remote version, try to get image from recipe data
            if let recipeData = selected.recipeData,
               let imageFileName = recipeData["imageFileName"] as? String {
                Log.debug("Using remote recipe image from data", category: .ui, metadata: [
                    "imageFileName": imageFileName,
                    "generation": selected.generation
                ])
                return imageFileName
            }
            Log.warning("No image found in selected version", category: .ui, metadata: [
                "generation": selected.generation,
                "hasRecipe": selected.recipe != nil,
                "hasData": selected.recipeData != nil
            ])
        }
        // Fall back to base recipe's image
        Log.debug("Using base recipe image (fallback)", category: .ui, metadata: [
            "imageFileName": recipe.imageFileName ?? "nil"
        ])
        return recipe.imageFileName
    }

    /// The Firebase image URL to display (from selected version or base recipe)
    private var displayFirebaseImageURL: String? {
        if let selected = selectedVersion {
            // If viewing current version's recipe, use its Firebase URL
            if let versionRecipe = selected.recipe {
                Log.debug("Using local recipe Firebase URL", category: .ui, metadata: [
                    "firebaseImageURL": versionRecipe.firebaseImageURL ?? "nil",
                    "generation": selected.generation
                ])
                return versionRecipe.firebaseImageURL
            }
            // If viewing remote version, try to get Firebase URL from recipe data
            if let recipeData = selected.recipeData,
               let firebaseImageURL = recipeData["firebaseImageURL"] as? String {
                Log.debug("Using remote recipe Firebase URL from data", category: .ui, metadata: [
                    "firebaseImageURL": firebaseImageURL,
                    "generation": selected.generation
                ])
                return firebaseImageURL
            }
            Log.warning("No Firebase URL found in selected version", category: .ui, metadata: [
                "generation": selected.generation,
                "hasRecipe": selected.recipe != nil,
                "hasData": selected.recipeData != nil
            ])
        }
        // Fall back to base recipe's Firebase URL
        Log.debug("Using base recipe Firebase URL (fallback)", category: .ui, metadata: [
            "firebaseImageURL": recipe.firebaseImageURL ?? "nil"
        ])
        return recipe.firebaseImageURL
    }

    /// Badge text for version/generation indicator
    private var versionBadgeText: String? {
        let versionCount = versionViewModel.versions.count

        // If we have multiple versions, show the count
        if versionCount > 1 {
            return "\(versionCount) versions"
        }

        // Check provenance first
        if recipe.provenance.isOriginal {
            return "Original"
        } else if recipe.provenance.generation > 0 {
            return "Gen \(recipe.provenance.generation)"
        }

        // Fallback: Check if we have lineage data from versionViewModel
        // If current version is generation 0, show "Original"
        if let currentVersion = selectedVersion ?? versionViewModel.versions.first(where: { $0.isCurrent }) {
            if currentVersion.generation == 0 {
                return "Original"
            } else if currentVersion.generation > 0 {
                return "Gen \(currentVersion.generation)"
            }
        }

        return nil
    }

    /// Whether the recipe has been translated from another language
    private var hasTranslation: Bool {
        return recipe.sourceLanguage != nil &&
               recipe.sourceLanguage != "en" &&
               recipe.originalTitle != nil
    }

    /// Whether this video recipe needs attribution
    private var needsAttribution: Bool {
        guard recipe.sourceType == .video else { return false }
        // Check if attribution is missing or empty
        let attribution = recipe.provenance.sourceAttribution
        let hasAttribution = attribution != nil && !attribution!.isEmpty
        return !hasAttribution
    }

    /// Summary of what changed (for disclosure header)
    private var changeSummary: String? {
        guard let selected = selectedVersion,
              let original = versionViewModel.versions.first(where: { $0.generation == 0 }),
              selected.generation > 0 else {
            return nil
        }

        var changes: [String] = []

        // Check title
        if selected.title != original.title {
            changes.append("Title changed")
        }

        // Get current ingredients (from recipe or recipeData)
        let currentTexts: [String]
        if let currentRecipe = selected.recipe, let currentIngredients = currentRecipe.ingredients {
            currentTexts = currentIngredients.map { $0.originalText }
        } else if let data = selected.recipeData,
                  let ingredientsData = data["ingredients"] as? [[String: Any]] {
            currentTexts = ingredientsData.compactMap { $0["originalText"] as? String }
        } else {
            currentTexts = []
        }

        // Get original ingredients (from recipe or recipeData)
        let originalTexts: [String]
        if let originalRecipe = original.recipe, let ingredients = originalRecipe.ingredients {
            originalTexts = ingredients.map { $0.originalText }
        } else if let data = original.recipeData,
                  let ingredientsData = data["ingredients"] as? [[String: Any]] {
            originalTexts = ingredientsData.compactMap { $0["originalText"] as? String }
        } else {
            originalTexts = []
        }

        // Compare ingredients
        Log.debug("Comparing ingredients", category: .ui, metadata: [
            "currentCount": currentTexts.count,
            "originalCount": originalTexts.count,
            "current": currentTexts.joined(separator: " | "),
            "original": originalTexts.joined(separator: " | ")
        ])

        if !currentTexts.isEmpty || !originalTexts.isEmpty {
            let addedCount = currentTexts.filter { !originalTexts.contains($0) }.count
            let removedCount = originalTexts.filter { !currentTexts.contains($0) }.count
            let modifiedCount = addedCount + removedCount

            Log.debug("Ingredient diff counts", category: .ui, metadata: [
                "addedCount": addedCount,
                "removedCount": removedCount,
                "modifiedCount": modifiedCount
            ])

            if modifiedCount > 0 {
                changes.append("\(modifiedCount) ingredient\(modifiedCount == 1 ? "" : "s") modified")
            }
        }

        // Get current instructions (from recipe or recipeData)
        let currentInstructions: [String]
        if let currentRecipe = selected.recipe {
            currentInstructions = currentRecipe.instructions
        } else if let data = selected.recipeData,
                  let instructions = data["instructions"] as? [String] {
            currentInstructions = instructions
        } else {
            currentInstructions = []
        }

        // Get original instructions (from recipe or recipeData)
        let originalInstructions: [String]
        if let originalRecipe = original.recipe {
            originalInstructions = originalRecipe.instructions
        } else if let data = original.recipeData,
                  let instructions = data["instructions"] as? [String] {
            originalInstructions = instructions
        } else {
            originalInstructions = []
        }

        // Compare instructions
        if !currentInstructions.isEmpty || !originalInstructions.isEmpty {
            var modifiedCount = 0
            for (index, instruction) in currentInstructions.enumerated() {
                if index >= originalInstructions.count || instruction != originalInstructions[index] {
                    modifiedCount += 1
                }
            }
            if originalInstructions.count > currentInstructions.count {
                modifiedCount += originalInstructions.count - currentInstructions.count
            }

            if modifiedCount > 0 {
                changes.append("\(modifiedCount) instruction\(modifiedCount == 1 ? "" : "s") modified")
            }
        }

        // Check servings
        let currentServings = selected.recipe?.servings ?? selected.recipeData?["servings"] as? String
        let originalServings = original.recipe?.servings ?? original.recipeData?["servings"] as? String
        Log.debug("Comparing servings", category: .ui, metadata: [
            "current": currentServings ?? "nil",
            "original": originalServings ?? "nil",
            "changed": (currentServings != originalServings)
        ])
        if currentServings != originalServings, currentServings != nil || originalServings != nil {
            changes.append("Servings changed")
        }

        // Check prep time
        let currentPrepTime = selected.recipe?.prepTime ?? selected.recipeData?["prepTime"] as? String
        let originalPrepTime = original.recipe?.prepTime ?? original.recipeData?["prepTime"] as? String
        Log.debug("Comparing prep time", category: .ui, metadata: [
            "current": currentPrepTime ?? "nil",
            "original": originalPrepTime ?? "nil",
            "changed": (currentPrepTime != originalPrepTime)
        ])
        if currentPrepTime != originalPrepTime, currentPrepTime != nil || originalPrepTime != nil {
            changes.append("Prep time changed")
        }

        // Check cook time
        let currentCookTime = selected.recipe?.cookTime ?? selected.recipeData?["cookTime"] as? String
        let originalCookTime = original.recipe?.cookTime ?? original.recipeData?["cookTime"] as? String
        Log.debug("Comparing cook time", category: .ui, metadata: [
            "current": currentCookTime ?? "nil",
            "original": originalCookTime ?? "nil",
            "changed": (currentCookTime != originalCookTime)
        ])
        if currentCookTime != originalCookTime, currentCookTime != nil || originalCookTime != nil {
            changes.append("Cook time changed")
        }

        // Check notes
        let currentNotes = selected.recipe?.notes ?? selected.recipeData?["notes"] as? String
        let originalNotes = original.recipe?.notes ?? original.recipeData?["notes"] as? String
        Log.debug("Comparing notes", category: .ui, metadata: [
            "current": currentNotes ?? "nil",
            "original": originalNotes ?? "nil",
            "changed": (currentNotes != originalNotes)
        ])
        if currentNotes != originalNotes, currentNotes != nil || originalNotes != nil {
            changes.append("Notes changed")
        }

        return changes.isEmpty ? nil : changes.joined(separator: ", ")
    }

    var body: some View {
        contentView
            .modifier(RecipeDetailModifiers(
                recipe: recipe,
                modelContext: modelContext,
                analytics: analytics,
                versionViewModel: versionViewModel,
                notificationService: notificationService,
                showDeleteConfirmation: $showDeleteConfirmation,
                showEditSheet: $showEditSheet,
                recipeToEdit: $recipeToEdit,
                showHeritageEditConfirmation: $showHeritageEditConfirmation,
                showTagCollectionPicker: $showTagCollectionPicker,
                showCardPersonalization: $showCardPersonalization,
                showCloudKitShare: $showCloudKitShare,
                showComments: $showComments,
                showScalingRepair: $showScalingRepair,
                isCardFlipped: $isCardFlipped,
                showCardBackEditor: $showCardBackEditor,
                cardBackRefreshTrigger: $cardBackRefreshTrigger,
                showVideoAttributionSheet: $showVideoAttributionSheet,
                showHeirloomExplanation: $showHeirloomExplanation,
                showSignInPrompt: $showSignInPrompt,
                showFirebaseSignIn: $showFirebaseSignIn,
                showCookingMode: $showCookingMode,
                showRecipeCoachMark: $showRecipeCoachMark,
                selectedVersion: $selectedVersion,
                showLineageView: $showLineageView,
                targetServings: $targetServings,
                showOwnershipVerification: $showOwnershipVerification,
                showPublishSheet: $showPublishSheet,
                showUnpublishConfirmation: $showUnpublishConfirmation,
                handleShareTapped: handleShareTapped,
                handleEditTapped: handleEditTapped,
                duplicateRecipe: duplicateRecipe,
                deleteRecipe: deleteRecipe,
                createUserCopyAndEdit: createUserCopyAndEdit,
                generateAIImage: generateAIImage
            ))
            .navigationDestination(isPresented: Binding(
                get: { selectedPublicRecipeId != nil },
                set: { if !$0 { selectedPublicRecipeId = nil } }
            )) {
                if let publicRecipeId = selectedPublicRecipeId {
                    PublicRecipeDetailView(publicRecipeId: publicRecipeId)
                }
            }
    }

    // MARK: - Main Content

    @ViewBuilder
    private var contentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Hero Image
                recipeImage
                    .frame(height: 300)
                    .clipped()

                // Content
                VStack(alignment: .leading, spacing: HeirloomSpacing.xl) {
                    // Unified Version Control Card
                    RecipeVersionSelector(
                        viewModel: versionViewModel,
                        selectedVersion: $selectedVersion,
                        isDiffExpanded: $isDiffExpanded,
                        changeSummary: changeSummary,
                        originalVersion: versionViewModel.versions.first(where: { $0.generation == 0 }),
                        heritageChainCount: recipe.heritageChain?.count ?? 0,
                        isOffline: isOffline
                    )
                    .padding(.horizontal, HeirloomSpacing.lg)

                    // Header Section
                    RecipeDetailHeader(
                        recipe: recipe,
                        displayTitle: displayTitle,
                        isInShoppingCart: isInShoppingCart,
                        selectedVersionCreatorName: selectedVersion?.isCurrent == false ? selectedVersion?.modifiedByName : nil,
                        onToggleFavorite: toggleFavorite,
                        onAddToShoppingList: addToShoppingList,
                        onViewOriginalRecipe: recipe.hasPublicUpstream ? {
                            selectedPublicRecipeId = recipe.sourcePublicRecipeId
                        } : nil
                    )

                    // Attribution Banner (for video recipes without attribution)
                    if needsAttribution {
                        attributionBanner
                    }

                    // Language Toggle (for multilingual recipes)
                    if hasTranslation {
                        languageToggle
                    }

                    // Tags and Collections Section
                    if (recipe.tags != nil && !recipe.tags!.isEmpty) || (recipe.collections != nil && !recipe.collections!.isEmpty) {
                        tagsAndCollectionsSection
                    }

                    // Ingredients Section
                    if let ingredients = displayIngredients, !ingredients.isEmpty {
                        RecipeIngredientsSection(
                            recipe: recipe,
                            ingredients: ingredients,
                            targetServings: $targetServings
                        )
                    }

                    // Metadata Section (servings/prep/cook)
                    RecipeMetadataSection(
                        recipe: recipe,
                        targetServings: $targetServings,
                        showScalingExplanation: $showScalingExplanation
                    )

                    // Instructions Section
                    if !displayInstructions.isEmpty {
                        RecipeInstructionsSection(instructions: displayInstructions)
                    }

                    // Start Cooking Button
                    if !displayInstructions.isEmpty {
                        startCookingButton
                    }

                    // Notes Section
                    if let notes = displayNotes {
                        notesSection(notes)
                    }

                    // Source Section
                    sourceSection

                    // More from this source
                    moreFromSourceSection

                    // Comments Section
                    commentsSection
                }
                .padding(HeirloomSpacing.lg)
            }
        }
        .background(HeirloomColors.cream)
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()) { _ in
            // Poll the NetworkMonitor's isConnected property for reliable UI updates
            let currentlyOffline = !networkMonitor.isConnected
            if isOffline != currentlyOffline {
                isOffline = currentlyOffline
                Log.debug("Network status poll detected change", category: .network, metadata: [
                    "isOffline": currentlyOffline
                ])
            }
        }
        .onAppear {
            // Initialize from NetworkMonitor
            isOffline = !networkMonitor.isConnected
        }
    }
}

// MARK: - View Modifiers

private struct RecipeDetailModifiers: ViewModifier {
    let recipe: Recipe
    let modelContext: ModelContext
    let analytics: AnalyticsService
    let versionViewModel: RecipeVersionSelectorViewModel
    let notificationService: FirebaseNotificationService

    @Binding var showDeleteConfirmation: Bool
    @Binding var showEditSheet: Bool
    @Binding var recipeToEdit: Recipe?
    @Binding var showHeritageEditConfirmation: Bool
    @Binding var showTagCollectionPicker: Bool
    @Binding var showCardPersonalization: Bool
    @Binding var showCloudKitShare: Bool
    @Binding var showComments: Bool
    @Binding var showScalingRepair: Bool
    @Binding var isCardFlipped: Bool
    @Binding var showCardBackEditor: Bool
    @Binding var cardBackRefreshTrigger: UUID
    @Binding var showVideoAttributionSheet: Bool
    @Binding var showHeirloomExplanation: Bool
    @Binding var showSignInPrompt: Bool
    @Binding var showFirebaseSignIn: Bool
    @Binding var showCookingMode: Bool
    @Binding var showRecipeCoachMark: Bool
    @Binding var selectedVersion: RecipeLineageVersion?
    @Binding var showLineageView: Bool
    @Binding var targetServings: Int
    @Binding var showOwnershipVerification: Bool
    @Binding var showPublishSheet: Bool
    @Binding var showUnpublishConfirmation: Bool

    let handleShareTapped: () -> Void
    let handleEditTapped: () -> Void
    let duplicateRecipe: () -> Void
    let deleteRecipe: () -> Void
    let createUserCopyAndEdit: () -> Void
    let generateAIImage: () -> Void

    // MARK: - Computed Views

    @ViewBuilder
    private var recipeActionsMenu: some View {
        Menu {
            Button {
                handleShareTapped()
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            .disabled(recipe.isSampleRecipe || recipe.isThemeRecipe)

            // Public discovery sharing (Phase 11)
            if recipe.isPublic {
                Button {
                    showUnpublishConfirmation = true
                } label: {
                    Label("Unpublish", systemImage: "globe.badge.chevron.backward")
                }
            } else {
                Button {
                    // If user already attested, skip verification
                    if recipe.publisherAttestationAcceptedAt != nil {
                        showPublishSheet = true
                    } else {
                        showOwnershipVerification = true
                    }
                } label: {
                    Label("Share Publicly", systemImage: "globe")
                }
                .disabled(recipe.isSampleRecipe || recipe.isThemeRecipe)
            }

            Divider()

            Button {
                handleEditTapped()
            } label: {
                Label("Edit", systemImage: "pencil")
            }

            Button {
                showTagCollectionPicker = true
            } label: {
                Label("Organize", systemImage: "tag")
            }

            Button {
                generateAIImage()
            } label: {
                Label("Generate AI Image", systemImage: "sparkles")
            }

            Button {
                showCardPersonalization = true
            } label: {
                Label("Personalize Card", systemImage: "paintbrush.fill")
            }

            Divider()

            Button {
                showComments = true
            } label: {
                let commentCount = recipe.comments?.count ?? 0
                Label("Comments (\(commentCount))", systemImage: "bubble.left.fill")
            }

            Button {
                withAnimation {
                    isCardFlipped.toggle()
                }
            } label: {
                Label(isCardFlipped ? "Show Front" : "Flip to Back", systemImage: "rectangle.portrait.on.rectangle.portrait.angled")
            }

            Divider()

            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .foregroundStyle(HeirloomColors.charcoal)
        }
    }

    func body(content: Content) -> some View {
        content
            .onAppear {
            // Initialize target servings to recipe's base serving count
            if targetServings == 0 {
                targetServings = recipe.parsedServingCount
            }

            // Track last viewed timestamp and mark as viewed
            recipe.lastViewed = Date()
            recipe.hasBeenViewed = true

            // Clear conflict badge when viewing the recipe
            if recipe.showConflictBadge || recipe.hasPendingConflicts {
                recipe.showConflictBadge = false
                recipe.hasPendingConflicts = false
            }

            try? modelContext.save()

            analytics.trackRecipeViewed(recipe: recipe)

            // Show coach mark on first recipe view
            if !UserDefaults.standard.bool(forKey: "hasSeenRecipeDetailCoachMark") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showRecipeCoachMark = true
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                recipeActionsMenu
            }
        }
        .confirmationDialog(
            "Delete Recipe?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                deleteRecipe()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You'll have 5 seconds to undo this action.")
        }
        .sheet(isPresented: $showEditSheet) {
            if let recipeToEdit = recipeToEdit {
                RecipeEditorView(recipe: recipeToEdit)
            }
        }
        .confirmationDialog(
            "Edit Heritage Recipe",
            isPresented: $showHeritageEditConfirmation,
            titleVisibility: .visible
        ) {
            Button("Create My Copy") {
                createUserCopyAndEdit()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This is a heritage recipe from our founding collections. Editing will create your personal copy that you can modify. The original will remain unchanged.")
        }
        .sheet(isPresented: $showTagCollectionPicker) {
            TagCollectionPickerView(recipe: recipe)
        }
        .sheet(isPresented: $showCardPersonalization) {
            CardPersonalizationView(recipe: recipe)
        }
        .sheet(isPresented: $showCloudKitShare) {
            RecipeShareSheet(recipe: recipe)
                .presentationDetents(UIDevice.current.userInterfaceIdiom == .pad ? [.medium, .large] : [.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showComments) {
            NavigationStack {
                RecipeCommentListView(recipe: recipe)
            }
        }
        .sheet(isPresented: $showScalingRepair) {
            ScalingRepairSheet(recipe: recipe)
        }
        .sheet(isPresented: $showCardBackEditor, onDismiss: {
            // Force card back preview to refresh with updated data
            cardBackRefreshTrigger = UUID()
        }) {
            CardBackEditorView(recipe: recipe)
        }
        .sheet(isPresented: $showVideoAttributionSheet) {
            VideoAttributionSheet(recipe: recipe) {
                // Refresh UI after attribution is saved
                // The computed property needsAttribution will automatically update
            }
        }
        .sheet(isPresented: $showOwnershipVerification) {
            OwnershipVerificationSheet(recipe: recipe) {
                // After confirmation, show the publish sheet
                showPublishSheet = true
            }
        }
        .sheet(isPresented: $showPublishSheet) {
            PublishRecipeSheet(recipe: recipe)
        }
        .sheet(isPresented: $showUnpublishConfirmation) {
            UnpublishConfirmationSheet(recipe: recipe)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showHeirloomExplanation) {
            HeirloomShareExplanationView()
        }
        .sheet(isPresented: $showSignInPrompt) {
            NavigationStack {
                VStack(spacing: HeirloomSpacing.xl) {
                    Spacer()

                    // Icon
                    ZStack {
                        Circle()
                            .fill(HeirloomColors.tomato.opacity(0.15))
                            .frame(width: 100, height: 100)

                        Image(systemName: "square.and.arrow.up.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(HeirloomColors.tomato)
                    }

                    // Message
                    VStack(spacing: 12) {
                        Text("Sign in to share")
                            .font(HeirloomFonts.title2)
                            .foregroundColor(HeirloomColors.primaryText)

                        Text("Create an account to share recipes with family and friends")
                            .font(HeirloomFonts.body)
                            .foregroundColor(HeirloomColors.secondaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }

                    Spacer()

                    // Sign in button
                    Button {
                        showSignInPrompt = false
                        // Small delay so sheets don't conflict
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showFirebaseSignIn = true
                        }
                    } label: {
                        Text("Continue to Sign In")
                            .font(HeirloomFonts.bodyBold)
                            .foregroundStyle(HeirloomColors.buttonTextLight)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(HeirloomColors.tomato)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 40)

                    // Maybe later button
                    Button {
                        showSignInPrompt = false
                    } label: {
                        Text("Maybe Later")
                            .font(HeirloomFonts.body)
                            .foregroundColor(HeirloomColors.secondaryText)
                    }
                    .padding(.bottom, 40)
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showSignInPrompt = false
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showFirebaseSignIn) {
            FirebaseSignInView()
                .presentationDetents([.large])
        }
        .fullScreenCover(isPresented: $showCookingMode) {
            CookingModeView(recipe: recipe, targetServings: targetServings)
        }
        .overlay {
            if showRecipeCoachMark {
                CoachMarkView(
                    message: "Tap the menu to edit this recipe or share it with others.\n\nSharing as Heirloom lets you track changes and see how recipes evolve.",
                    onDismiss: {
                        showRecipeCoachMark = false
                        UserDefaults.standard.set(true, forKey: "hasSeenRecipeDetailCoachMark")
                    }
                )
            }
        }
        .task {
            // Load versions when view appears
            await versionViewModel.loadVersions(for: recipe, context: modelContext)

            // Sync selected version from view model to local state
            // This ensures the view displays the correct version's data
            if selectedVersion == nil, let vmSelected = versionViewModel.selectedVersion {
                selectedVersion = vmSelected
                Log.debug("Synced selectedVersion from view model", category: .ui, metadata: [
                    "displayName": vmSelected.displayName,
                    "generation": vmSelected.generation,
                    "isCurrent": vmSelected.isCurrent
                ])
            }

            // DEBUG: Log version loading results
            Log.info("Version loading complete", category: .ui, metadata: [
                "recipeId": recipe.id.uuidString,
                "title": recipe.title,
                "versionsCount": versionViewModel.versions.count,
                "hasMultipleVersions": versionViewModel.versions.count > 1,
                "error": versionViewModel.error ?? "none"
            ])

            // Mark notifications as read for this recipe
            do {
                try await notificationService.markAllAsRead(for: recipe.id)
                Log.info("Marked all notifications as read for recipe", category: .ui, metadata: ["title": recipe.title])
            } catch {
                Log.error("Failed to mark notifications as read", category: .firebase, metadata: ["error": error.localizedDescription])
            }
        }
        .onChange(of: notificationService.unreadCount(for: recipe.id)) { oldValue, newValue in
            // Reload versions when new notifications arrive while view is open
            if newValue > 0 {
                Log.info("New notification arrived while recipe open - reloading versions", category: .ui, metadata: [
                    "recipeId": recipe.id.uuidString,
                    "unreadCount": newValue
                ])
                Task {
                    await versionViewModel.loadVersions(for: recipe, context: modelContext)

                    // Re-sync selected version after reload to get fresh data
                    // This ensures modifications from other users are visible
                    if let currentSelection = selectedVersion,
                       let refreshed = versionViewModel.versions.first(where: {
                           $0.modifiedBy == currentSelection.modifiedBy &&
                           $0.generation == currentSelection.generation
                       }) {
                        selectedVersion = refreshed
                        Log.debug("Refreshed selectedVersion after notification", category: .ui, metadata: [
                            "displayName": refreshed.displayName
                        ])
                    }

                    // Mark new notifications as read
                    try? await notificationService.markAllAsRead(for: recipe.id)
                }
            }
        }
        .onChange(of: selectedVersion) { oldValue, newValue in
            // Save the selected version ID and image info to recipe for persistence
            // This ensures the recipe card in list view shows the selected version's image
            if let newVersion = newValue {
                if let recipeId = newVersion.recipe?.id {
                    recipe.lastViewedVersionId = recipeId
                }

                // Update recipe's image to match selected version
                // This makes the preview card show the version's image
                if let versionRecipe = newVersion.recipe {
                    // Version has a local recipe - use its image
                    recipe.imageFileName = versionRecipe.imageFileName
                    recipe.firebaseImageURL = versionRecipe.firebaseImageURL
                } else if let recipeData = newVersion.recipeData {
                    // Remote version - use image from Firebase data
                    recipe.imageFileName = recipeData["imageFileName"] as? String
                    recipe.firebaseImageURL = recipeData["firebaseImageURL"] as? String
                }

                try? modelContext.save()
                Log.debug("Saved last viewed version with image", category: .database, metadata: [
                    "versionDisplayName": newVersion.displayName,
                    "imageFileName": recipe.imageFileName ?? "nil"
                ])
            }
        }
        .navigationDestination(isPresented: $showLineageView) {
            LineageContainerView(recipe: recipe) { selectedRecipe in
                // Handle recipe tap from lineage view
                Log.debug("Recipe tapped in lineage view", category: .ui, metadata: ["title": selectedRecipe.title])
            }
        }
    }
}

// MARK: - RecipeDetailView Extension

extension RecipeDetailView {
    // MARK: - Image Section
    private var recipeImage: some View {
        FlipCard(
            isFlipped: $isCardFlipped,
            showNudgeOnAppear: shouldShowFlipNudge,
            front: {
                ZStack {
                    AsyncRecipeImage(
                        imageFileName: displayImageFileName,
                        firebaseImageURL: displayFirebaseImageURL,
                        placeholder: recipe.sourceType?.iconName ?? "fork.knife",
                        isGenerating: recipe.needsAIImage
                    )

                    // Public recipe badge (bottom right overlay) - Phase 11
                    if recipe.isPublic {
                        PublicRecipeBadge(viewCount: recipe.publicViewCount)
                            .padding(HeirloomSpacing.sm)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    } else if recipe.canMakePublic {
                        // Publishable badge - tappable to open publish sheet
                        Button(action: {
                            // If user already attested, skip verification
                            if recipe.publisherAttestationAcceptedAt != nil {
                                showPublishSheet = true
                            } else {
                                showOwnershipVerification = true
                            }
                        }) {
                            PublishableBadge()
                                .padding(HeirloomSpacing.sm)
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    }
                }
            },
            back: {
                // Safely check if card back exists with optional binding
                if recipe.cardBack != nil {
                    // Card back exists - show preview with edit button
                    ZStack(alignment: .topTrailing) {
                        RecipeCardBackPreview(cardBack: recipe.cardBack!, recipe: recipe)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .id(cardBackRefreshTrigger)

                        // Edit affordance
                        Button {
                            showCardBackEditor = true
                        } label: {
                            Image(systemName: "pencil.circle.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(HeirloomColors.buttonTextLight)
                                .background(
                                    Circle()
                                        .fill(HeirloomColors.tomato)
                                        .frame(width: 36, height: 36)
                                )
                        }
                        .padding(HeirloomSpacing.md)
                    }
                } else {
                    // Show empty card back state
                    ZStack {
                        Rectangle()
                            .fill(Color(.systemBackground))

                        VStack(spacing: HeirloomSpacing.md) {
                            Image(systemName: "rectangle.portrait.on.rectangle.portrait")
                                .font(.system(size: 48))
                                .foregroundStyle(HeirloomColors.secondaryText)

                            Text("No card back yet")
                                .font(HeirloomFonts.body)
                                .foregroundStyle(HeirloomColors.secondaryText)

                            Button {
                                isCardFlipped = false
                                // Show the editor
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    showCardBackEditor = true
                                }
                            } label: {
                                Text("Add Card Back")
                                    .font(HeirloomFonts.bodyBold)
                                    .foregroundStyle(HeirloomColors.buttonTextLight)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(
                                        Capsule()
                                            .fill(HeirloomColors.tomato)
                                    )
                            }
                        }
                        .padding()
                    }
                }
            }
        )
        // TODO: Re-enable once FlipAffordanceBadge is added to Xcode project
        // .overlay(alignment: .bottomTrailing) {
        //     // Show flip affordance badge on first time
        //     if !FlipAffordanceBadge.hasSeenFlip {
        //         FlipAffordanceBadge()
        //             .padding(12)
        //     }
        // }
        .onTapGesture {
            withAnimation {
                isCardFlipped.toggle()
            }

            // TODO: Re-enable once FlipAffordanceBadge is added to Xcode project
            // Mark flip affordance as seen after first flip
            // if !FlipAffordanceBadge.hasSeenFlip {
            //     FlipAffordanceBadge.markAsSeen()
            // }
        }
        .onAppear {
            // Check if user should see flip nudge (first-time hint)
            if !UserDefaults.standard.bool(forKey: UserDefaultsKeys.hasSeenCardFlipNudge) {
                shouldShowFlipNudge = true
                // Mark as seen after animation plays
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    UserDefaults.standard.set(true, forKey: UserDefaultsKeys.hasSeenCardFlipNudge)
                }
            }
        }
    }

    // MARK: - Tags and Collections Section
    private var tagsAndCollectionsSection: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
            // Tags
            if let tags = recipe.tags, !tags.isEmpty {
                VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
                    Text("Tags")
                        .font(HeirloomFonts.caption2)
                        .foregroundStyle(HeirloomColors.secondaryText)
                        .textCase(.uppercase)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: HeirloomSpacing.xs) {
                            ForEach(tags, id: \.id) { tag in
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(tag.swiftUIColor)
                                        .frame(width: 8, height: 8)

                                    Text(tag.name)
                                        .font(HeirloomFonts.caption1)
                                }
                                .padding(.horizontal, HeirloomSpacing.sm)
                                .padding(.vertical, 6)
                                .background(tag.swiftUIColor.opacity(0.15))
                                .cornerRadius(12)
                            }
                        }
                    }
                }
            }

            // Collections
            if let collections = recipe.collections, !collections.isEmpty {
                VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
                    Text("Collections")
                        .font(HeirloomFonts.caption2)
                        .foregroundStyle(HeirloomColors.secondaryText)
                        .textCase(.uppercase)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: HeirloomSpacing.xs) {
                            ForEach(collections, id: \.id) { collection in
                                Button {
                                    selectedCollection = collection
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: collection.iconName)
                                            .font(HeirloomFonts.caption2)
                                            .foregroundStyle(collection.swiftUIColor)

                                        Text(collection.name)
                                            .font(HeirloomFonts.caption1)
                                            .foregroundStyle(HeirloomColors.primaryText)
                                    }
                                    .padding(.horizontal, HeirloomSpacing.sm)
                                    .padding(.vertical, 6)
                                    .background(collection.swiftUIColor.opacity(0.15))
                                    .cornerRadius(12)
                                }
                                .buttonStyle(.plain)
                                .popover(item: $selectedCollection) { selectedItem in
                                    if selectedItem.id == collection.id {
                                        VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
                                            HStack(spacing: HeirloomSpacing.sm) {
                                                Image(systemName: collection.iconName)
                                                    .font(HeirloomFonts.title2)
                                                    .foregroundStyle(collection.swiftUIColor)

                                                Text(collection.name)
                                                    .font(HeirloomFonts.bodyBold)
                                                    .foregroundStyle(HeirloomColors.primaryText)
                                            }

                                            if let desc = collection.desc, !desc.isEmpty {
                                                Text(desc)
                                                    .font(HeirloomFonts.body)
                                                    .foregroundStyle(HeirloomColors.secondaryText)
                                                    .fixedSize(horizontal: false, vertical: true)
                                            } else {
                                                Text("No description available")
                                                    .font(HeirloomFonts.caption1)
                                                    .foregroundStyle(HeirloomColors.secondaryText)
                                                    .italic()
                                            }
                                        }
                                        .padding(HeirloomSpacing.lg)
                                        .frame(maxWidth: 280)
                                        .presentationCompactAdaptation(.popover)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Metadata Section
    private var metadataSection: some View {
        HStack(spacing: HeirloomSpacing.lg) {
            // Servings with dropdown
            servingsMetadataItem

            if let prepTime = displayPrepTime {
                metadataItem(icon: "clock.fill", label: "Prep", value: prepTime)
            }

            if let cookTime = displayCookTime {
                metadataItem(icon: "flame.fill", label: "Cook", value: cookTime)
            }
        }
        .padding(HeirloomSpacing.md)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: HeirloomSpacing.cardCornerRadius)
                .fill(.white)
                .heirloomShadow(HeirloomShadows.subtle)
        )
    }

    private var servingsMetadataItem: some View {
        VStack(spacing: HeirloomSpacing.xs) {
            Image(systemName: "person.2.fill")
                .font(HeirloomFonts.title2)
                .foregroundStyle(HeirloomColors.tomato)

            Text("Servings")
                .font(HeirloomFonts.caption1)
                .foregroundStyle(HeirloomColors.charcoal.opacity(0.6))

            // Dropdown menu for serving sizes
            Menu {
                let availableSizes = recipe.availableServingSizes

                if recipe.isScalingAllowed {
                    // Scalable recipe: show all preset options
                    ForEach(availableSizes, id: \.self) { size in
                        Button {
                            let originalServings = recipe.parsedServingCount
                            targetServings = size

                            // Track scaling event
                            if size != originalServings {
                                analytics.track(event: .recipeScaled, properties: [
                                    "recipe_title": recipe.title,
                                    "category": recipe.category?.rawValue ?? "unknown",
                                    "original_servings": originalServings,
                                    "target_servings": size,
                                    "scale_factor": Double(size) / Double(originalServings)
                                ])
                            }
                        } label: {
                            HStack {
                                Text("\(size) \(servingUnitText(size))")
                                if size == targetServings {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } else {
                    // Locked recipe: show explanation when tapped
                    Button {
                        showScalingExplanation = true

                        // Track explanation view
                        analytics.track(event: .scalingExplanationViewed, properties: [
                            "recipe_title": recipe.title,
                            "category": recipe.category?.rawValue ?? "unknown"
                        ])
                    } label: {
                        Label("Why can't I scale this?", systemImage: "info.circle")
                    }
                }
            } label: {
                HStack(spacing: HeirloomSpacing.xs) {
                    Text("\(targetServings) \(servingUnitText(targetServings))")
                        .font(HeirloomFonts.bodyBold)
                        .foregroundStyle(HeirloomColors.charcoal)

                    Image(systemName: recipe.isScalingAllowed ? "chevron.down" : "lock.fill")
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(HeirloomColors.charcoal.opacity(0.5))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .sheet(isPresented: $showScalingExplanation) {
            ScalingExplanationSheet(recipe: recipe)
        }
    }

    private func servingUnitText(_ count: Int) -> String {
        if let servings = displayServings {
            // Try to extract unit from original servings string
            let lowercased = servings.lowercased()
            if lowercased.contains("cookie") {
                return count == 1 ? "cookie" : "cookies"
            } else if lowercased.contains("muffin") {
                return count == 1 ? "muffin" : "muffins"
            } else if lowercased.contains("serving") {
                return count == 1 ? "serving" : "servings"
            } else if lowercased.contains("portion") {
                return count == 1 ? "portion" : "portions"
            }
        }
        return count == 1 ? "serving" : "servings"
    }

    private func metadataItem(icon: String, label: String, value: String) -> some View {
        VStack(spacing: HeirloomSpacing.xs) {
            Image(systemName: icon)
                .font(HeirloomFonts.title2)
                .foregroundStyle(HeirloomColors.tomato)

            Text(label)
                .font(HeirloomFonts.caption1)
                .foregroundStyle(HeirloomColors.charcoal.opacity(0.6))

            Text(value)
                .font(HeirloomFonts.bodyBold)
                .foregroundStyle(HeirloomColors.charcoal)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Start Cooking Button
    private var startCookingButton: some View {
        Button {
            showCookingMode = true
            analytics.track(event: .cookingStarted, properties: [
                "recipe_id": recipe.id.uuidString,
                "recipe_title": recipe.title
            ])
        } label: {
            HStack {
                Image(systemName: "play.circle.fill")
                    .font(.title2)
                Text("Start Cooking")
                    .font(HeirloomFonts.bodyBold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(HeirloomColors.tomato)
            .foregroundStyle(HeirloomColors.buttonTextLight)
            .cornerRadius(12)
        }
    }

    // MARK: - Ingredients Section
    private func ingredientsSection(_ ingredients: [Ingredient]) -> some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
            sectionHeader(
                title: "Ingredients",
                icon: "list.bullet",
                count: ingredients.count
            )

            VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                ForEach(ingredients.sorted(by: { $0.orderIndex < $1.orderIndex })) { ingredient in
                    ingredientRow(ingredient)
                }
            }
            .id(targetServings) // Force refresh when servings change
            .padding(HeirloomSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: HeirloomSpacing.cardCornerRadius)
                    .fill(.white)
            )
        }
    }

    private var servingSizeAdjuster: some View {
        HStack(spacing: HeirloomSpacing.xs) {
            Button {
                servingMultiplier = max(0.5, servingMultiplier - 0.5)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(HeirloomFonts.title2)
                    .foregroundStyle(HeirloomColors.tomato)
            }
            .disabled(servingMultiplier <= 0.5)

            VStack(spacing: 2) {
                Text("\(scaledServings)")
                    .font(HeirloomFonts.bodyBold)
                    .foregroundStyle(HeirloomColors.primaryText)
                Text("servings")
                    .font(HeirloomFonts.caption2)
                    .foregroundStyle(HeirloomColors.secondaryText)
            }
            .frame(minWidth: 60)

            Button {
                servingMultiplier = min(10.0, servingMultiplier + 0.5)
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(HeirloomFonts.title2)
                    .foregroundStyle(HeirloomColors.tomato)
            }
            .disabled(servingMultiplier >= 10.0)
        }
    }

    private var scaledServings: String {
        guard let servings = displayServings else { return "1" }

        // Try to extract a number from servings string
        let numbers = servings.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        if let baseServings = Double(numbers) {
            let scaled = baseServings * servingMultiplier
            return scaled.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(scaled)) : String(format: "%.1f", scaled)
        }

        return servings
    }

    private func ingredientRow(_ ingredient: Ingredient) -> some View {
        HStack(alignment: .top, spacing: HeirloomSpacing.sm) {
            Image(systemName: "circle")
                .font(HeirloomFonts.caption1)
                .foregroundStyle(HeirloomColors.tomato)
                .padding(.top, 4)

            Text(scaledIngredientText(ingredient))
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.charcoal)
        }
    }

    private func scaledIngredientText(_ ingredient: Ingredient) -> String {
        // Calculate scale factor from target servings
        let originalServings = recipe.parsedServingCount
        let scaleFactor = Double(targetServings) / Double(originalServings)

        // If scaling is 1.0, just show original text
        guard scaleFactor != 1.0 else {
            return ingredient.displayText
        }

        // If ingredient has no quantity, can't scale it
        guard let quantity = ingredient.quantity else {
            return ingredient.displayText
        }

        // Scale the quantity
        let scaledQty = quantity * scaleFactor
        let scaledQtyMax = ingredient.quantityMax.map { $0 * scaleFactor }

        // Build scaled display text
        var parts: [String] = []

        // Format quantity with fractions
        parts.append(formatQuantity(scaledQty))

        if let max = scaledQtyMax {
            parts.append("-\(formatQuantity(max))")
        }

        if let unit = ingredient.unit {
            parts.append(unit)
        }

        parts.append(ingredient.name)

        if let prep = ingredient.preparation {
            parts.append("(\(prep))")
        }

        return parts.joined(separator: " ")
    }

    private func formatQuantity(_ value: Double) -> String {
        let fractions: [(Double, String)] = [
            (0.125, "⅛"), (0.25, "¼"), (0.333, "⅓"),
            (0.375, "⅜"), (0.5, "½"), (0.625, "⅝"),
            (0.666, "⅔"), (0.75, "¾"), (0.875, "⅞")
        ]

        let wholePart = Int(value)
        let fractionalPart = value - Double(wholePart)

        // First pass: exact matches (within 0.01)
        for (decimalValue, fractionSymbol) in fractions {
            if abs(fractionalPart - decimalValue) < 0.01 {
                if wholePart > 0 {
                    return "\(wholePart) \(fractionSymbol)"
                } else {
                    return fractionSymbol
                }
            }
        }

        // Second pass: snap to nearest common fraction (within 0.12)
        let commonFractions: [(Double, String)] = [
            (0.125, "⅛"), (0.25, "¼"), (0.333, "⅓"),
            (0.5, "½"), (0.666, "⅔"), (0.75, "¾")
        ]

        for (decimalValue, fractionSymbol) in commonFractions {
            if abs(fractionalPart - decimalValue) < 0.12 {
                if wholePart > 0 {
                    return "\(wholePart) \(fractionSymbol)"
                } else {
                    return fractionSymbol
                }
            }
        }

        if fractionalPart < 0.01 {
            return "\(wholePart)"
        }

        return String(format: "%.1f", value)
    }

    // MARK: - Instructions Section
    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
            sectionHeader(
                title: "Instructions",
                icon: "list.number",
                count: displayInstructions.count
            )

            VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
                ForEach(Array(displayInstructions.enumerated()), id: \.offset) { index, instruction in
                    instructionRow(
                        number: index + 1,
                        text: instruction,
                        isModified: selectedVersion?.generation ?? 0 > 0 &&
                                    index < recipe.instructions.count &&
                                    instruction != recipe.instructions[index]
                    )
                }
            }
            .padding(HeirloomSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: HeirloomSpacing.cardCornerRadius)
                    .fill(.white)
            )
        }
    }

    private func instructionRow(number: Int, text: String, isModified: Bool = false) -> some View {
        HStack(alignment: .top, spacing: HeirloomSpacing.md) {
            ZStack {
                Circle()
                    .fill(isModified ? HeirloomColors.success : HeirloomColors.tomato)
                    .frame(width: 32, height: 32)

                Text("\(number)")
                    .font(HeirloomFonts.bodyBold)
                    .foregroundStyle(HeirloomColors.buttonTextLight)
            }

            Text(text)
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.charcoal)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Notes Section
    private func notesSection(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
            sectionHeader(title: "Notes", icon: "note.text")

            Text(notes)
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.charcoal)
                .padding(HeirloomSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: HeirloomSpacing.cardCornerRadius)
                        .fill(.white)
                )
        }
    }

    // MARK: - Language Toggle
    // MARK: - Attribution Banner

    private var communityRecipeAttributionBanner: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
            HStack(spacing: HeirloomSpacing.md) {
                Image(systemName: "globe")
                    .font(.title2)
                    .foregroundStyle(HeirloomColors.familyGreen)

                VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
                    Text("From the Community")
                        .font(HeirloomFonts.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(HeirloomColors.primaryText)

                    if let creatorName = recipe.sourcePublicRecipeCreatorName {
                        Text("Based on recipe by \(creatorName)")
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(HeirloomColors.secondaryText)
                    }
                }

                Spacer()
            }
        }
        .padding(HeirloomSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: HeirloomSpacing.cardCornerRadius)
                .fill(HeirloomColors.familyGreen.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: HeirloomSpacing.cardCornerRadius)
                        .stroke(HeirloomColors.familyGreen.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal, HeirloomSpacing.lg)
    }

    private var attributionBanner: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
            HStack(spacing: HeirloomSpacing.md) {
                Image(systemName: "person.crop.circle.badge.exclamationmark")
                    .font(.title2)
                    .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
                    Text("Attribution Missing")
                        .font(HeirloomFonts.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(HeirloomColors.primaryText)

                    Text("Please credit the original creator of this recipe")
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(HeirloomColors.secondaryText)
                }

                Spacer()

                Button {
                    showVideoAttributionSheet = true
                } label: {
                    Text("Add")
                        .font(HeirloomFonts.caption1)
                        .fontWeight(.semibold)
                        .foregroundStyle(HeirloomColors.buttonTextLight)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(HeirloomColors.tomato)
                        .cornerRadius(8)
                }
            }
        }
        .padding(HeirloomSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: HeirloomSpacing.cardCornerRadius)
                .fill(Color.orange.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: HeirloomSpacing.cardCornerRadius)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
    }

    private var languageToggle: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
            HStack(spacing: HeirloomSpacing.sm) {
                Image(systemName: "globe")
                    .foregroundStyle(HeirloomColors.tomato)
                    .font(.callout)

                Text("Language")
                    .font(HeirloomFonts.caption2)
                    .foregroundStyle(HeirloomColors.secondaryText)
                    .textCase(.uppercase)
            }

            Picker("Language", selection: $showOriginalLanguage) {
                Text("English").tag(false)
                if let language = recipe.sourceLanguage {
                    Text(languageName(for: language)).tag(true)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Toggle between English and original language")
        }
        .padding(HeirloomSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: HeirloomSpacing.cardCornerRadius)
                .fill(.white)
                .heirloomShadow(HeirloomShadows.subtle)
        )
    }

    // MARK: - Source Section
    private var sourceSection: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
            // Provenance information
            HStack(spacing: HeirloomSpacing.sm) {
                Image(systemName: recipe.provenance.sourceType.iconName)
                    .foregroundStyle(HeirloomColors.tomato)
                    .font(.callout)

                Text(recipe.provenance.displaySource)
                    .font(HeirloomFonts.callout)
                    .foregroundStyle(HeirloomColors.charcoal.opacity(0.8))

                // Version/Generation badge
                if let badgeText = versionBadgeText {
                    Text(badgeText)
                        .font(HeirloomFonts.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(HeirloomColors.buttonTextLight)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(versionViewModel.versions.count > 1 ? HeirloomColors.familyGreen : (recipe.provenance.isOriginal ? HeirloomColors.tomato : HeirloomColors.familyGreen))
                        )
                }
            }

            // View Lineage Button - show when online and has lineage
            if !isOffline && (versionViewModel.versions.count > 1 || (recipe.heritageChain?.count ?? 0) > 0) {
                Button {
                    showLineageView = true
                } label: {
                    HStack(spacing: HeirloomSpacing.xs) {
                        Image(systemName: "network")
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(HeirloomColors.tomato)

                        Text("View Family Tree")
                            .font(HeirloomFonts.callout)
                            .foregroundStyle(HeirloomColors.tomato)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(HeirloomFonts.caption2)
                            .foregroundStyle(HeirloomColors.tomato.opacity(0.6))
                    }
                }
                .buttonStyle(.plain)
                .padding(.top, HeirloomSpacing.xs)
            }
            // Offline indicator when offline and has lineage data
            else if isOffline && (versionViewModel.versions.count > 1 || (recipe.heritageChain?.count ?? 0) > 0) {
                HStack(spacing: HeirloomSpacing.xs) {
                    Image(systemName: "network.slash")
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(HeirloomColors.warmGray)

                    Text("Family Tree")
                        .font(HeirloomFonts.callout)
                        .foregroundStyle(HeirloomColors.warmGray)

                    Text("(offline)")
                        .font(HeirloomFonts.caption2)
                        .foregroundStyle(HeirloomColors.warmGray)

                    Spacer()
                }
                .padding(.top, HeirloomSpacing.xs)
            }

            if recipe.timesCooked > 0 {
                HStack {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(HeirloomColors.tomato)
                    Text("Cooked \(recipe.timesCooked) time\(recipe.timesCooked == 1 ? "" : "s")")
                        .font(HeirloomFonts.callout)
                        .foregroundStyle(HeirloomColors.charcoal.opacity(0.7))
                }
            }

            if let lastCooked = recipe.lastCooked {
                Text("Last made \(lastCooked, style: .relative)")
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(HeirloomColors.charcoal.opacity(0.5))
            }

            Text("Added \(recipe.dateAdded, style: .date)")
                .font(HeirloomFonts.caption1)
                .foregroundStyle(HeirloomColors.charcoal.opacity(0.5))

            // Show edit indicator if recipe was edited after import (unshared only)
            if recipe.wasEditedAfterImport {
                VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
                    HStack(spacing: HeirloomSpacing.xs) {
                        Image(systemName: "pencil.circle.fill")
                            .foregroundStyle(HeirloomColors.tomato)
                            .font(.caption)

                        Text("Last edited \(recipe.lastModified, style: .date)")
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(HeirloomColors.charcoal.opacity(0.5))

                        Spacer()

                        // Diff toggle button
                        Button {
                            withAnimation {
                                isDiffExpanded.toggle()
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(isDiffExpanded ? "Hide original" : "Show original")
                                Image(systemName: isDiffExpanded ? "chevron.up" : "chevron.down")
                            }
                            .font(HeirloomFonts.caption2)
                            .foregroundStyle(HeirloomColors.tomato)
                        }
                    }

                    // Diff view (when expanded)
                    if isDiffExpanded, let diff = recipe.computeDiff() {
                        RecipeImportDiffView(diff: diff, currentRecipe: recipe)
                            .padding(.top, HeirloomSpacing.sm)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(.top, HeirloomSpacing.xs)
            }
        }
        .padding(.top, HeirloomSpacing.lg)
    }

    // MARK: - More From Source Section
    @ViewBuilder
    private var moreFromSourceSection: some View {
        if let source = recipe.knownSource {
            let siblings = (source.recipes ?? []).filter { $0.id != recipe.id }
            if !siblings.isEmpty {
                VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                    Text("More from \(source.name)")
                        .font(.headline)
                        .foregroundStyle(HeirloomColors.charcoal)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: HeirloomSpacing.sm) {
                            ForEach(siblings.prefix(10), id: \.id) { sibling in
                                NavigationLink(value: sibling) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        AsyncRecipeImage(
                                            imageFileName: sibling.imageFileName,
                                            firebaseImageURL: sibling.firebaseImageURL,
                                            placeholder: sibling.sourceType?.iconName ?? "fork.knife",
                                            isGenerating: sibling.needsAIImage
                                        )
                                        .frame(width: 140, height: 100)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))

                                        Text(sibling.title)
                                            .font(.caption)
                                            .foregroundStyle(HeirloomColors.charcoal)
                                            .lineLimit(2)
                                            .multilineTextAlignment(.leading)
                                            .frame(width: 140, alignment: .leading)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.top, HeirloomSpacing.lg)
            }
        }
    }

    // MARK: - Comments Section
    private var commentsSection: some View {
        let comments = recipe.comments ?? []
        let commentCount = comments.count
        let topComments = commentService.getTopComments(for: recipe, limit: 3)

        return VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
            // Section header
            Button {
                showComments = true
            } label: {
                HStack {
                    sectionHeader(
                        title: "Comments",
                        icon: "bubble.left.fill",
                        count: commentCount
                    )

                    Spacer()

                    if commentCount > 0 {
                        Image(systemName: "chevron.right")
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(HeirloomColors.charcoal.opacity(0.5))
                    }
                }
            }
            .buttonStyle(.plain)

            if commentCount > 0 {
                // Show top 3 comments preview
                VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                    ForEach(topComments) { comment in
                        commentPreviewRow(comment)
                            .onTapGesture {
                                showComments = true
                            }
                    }
                }
                .padding(HeirloomSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: HeirloomSpacing.cardCornerRadius)
                        .fill(.white)
                )

                // View all button
                if commentCount > 3 {
                    Button {
                        showComments = true
                    } label: {
                        HStack {
                            Text("View all \(commentCount) comments")
                                .font(HeirloomFonts.bodyBold)
                            Image(systemName: "arrow.right")
                                .font(HeirloomFonts.caption1)
                        }
                        .foregroundStyle(HeirloomColors.tomato)
                    }
                }
            } else {
                // Empty state
                VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                    Text("No comments yet")
                        .font(HeirloomFonts.body)
                        .foregroundStyle(HeirloomColors.charcoal.opacity(0.6))

                    Button {
                        showComments = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add the first comment")
                        }
                        .font(HeirloomFonts.bodyBold)
                        .foregroundStyle(HeirloomColors.tomato)
                    }
                }
                .padding(HeirloomSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: HeirloomSpacing.cardCornerRadius)
                        .fill(.white)
                )
            }
        }
        .padding(.top, HeirloomSpacing.lg)
    }

    private func commentPreviewRow(_ comment: RecipeComment) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Author and sentiment
            HStack {
                Text(comment.displayAuthor)
                    .font(HeirloomFonts.caption1)
                    .fontWeight(.semibold)
                    .foregroundStyle(HeirloomColors.charcoal.opacity(0.8))

                if let sentiment = comment.sentimentScore {
                    HStack(spacing: 2) {
                        Image(systemName: sentimentIcon(sentiment))
                            .font(HeirloomFonts.caption2)
                        Text(String(format: "%.0f%%", abs(sentiment) * 100))
                            .font(HeirloomFonts.caption2)
                    }
                    .foregroundStyle(sentimentColor(sentiment))
                }

                Spacer()

                if comment.upvotes > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(HeirloomFonts.caption2)
                        Text("\(comment.upvotes)")
                            .font(HeirloomFonts.caption2)
                    }
                    .foregroundStyle(.green)
                }
            }

            // Comment text
            Text(comment.text)
                .font(HeirloomFonts.subheadline)
                .foregroundStyle(HeirloomColors.charcoal)
                .lineLimit(2)
        }
    }

    private func sentimentIcon(_ score: Double) -> String {
        if score > 0.5 { return "face.smiling" }
        if score > 0.2 { return "hand.thumbsup.fill" }
        if score < -0.5 { return "exclamationmark.triangle.fill" }
        if score < -0.2 { return "hand.thumbsdown.fill" }
        return "minus.circle"
    }

    private func sentimentColor(_ score: Double) -> Color {
        if score > 0.2 { return .green }
        if score < -0.2 { return .red }
        return .secondary
    }

    // MARK: - Helper Views
    private func sectionHeader(title: String, icon: String, count: Int? = nil) -> some View {
        HStack(spacing: HeirloomSpacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(HeirloomColors.tomato)

            Text(title)
                .font(HeirloomFonts.title2)
                .foregroundStyle(HeirloomColors.charcoal)

            if let count = count {
                Text("(\(count))")
                    .font(HeirloomFonts.body)
                    .foregroundStyle(HeirloomColors.charcoal.opacity(0.5))
            }

            Spacer()
        }
    }

    private func languageName(for languageCode: String) -> String {
        switch languageCode {
        case "fr": return "French"
        case "es": return "Spanish"
        case "de": return "German"
        case "ja": return "Japanese"
        case "zh": return "Chinese"
        case "ko": return "Korean"
        default: return languageCode.uppercased()
        }
    }

    // MARK: - Actions

    private func handleShareTapped() {
        // Check if recipe can be shared
        if recipe.isSampleRecipe {
            toastManager.info(
                title: "Sample recipes can't be shared",
                message: "Everyone already has this recipe"
            )
            return
        }

        if recipe.isThemeRecipe {
            toastManager.info(
                title: "Heritage recipes can't be shared",
                message: "All users receive these automatically"
            )
            return
        }

        if recipe.isDemoRecipe {
            toastManager.info(
                title: "Demo recipe",
                message: "Create your own to share"
            )
            return
        }

        // Check if user is authenticated before sharing
        if firebaseAuth.isAuthenticated {
            showCloudKitShare = true
        } else {
            showSignInPrompt = true
        }
    }

    private func shareRecipe(as format: RecipeExportService.ShareFormat) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return
        }

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        exportService.shareRecipe(recipe, as: format, from: window, targetServings: targetServings)

        // Track analytics
        analytics.track(event: .recipeShared, properties: [
            "recipe_id": recipe.id.uuidString,
            "recipe_title": recipe.title,
            "share_format": String(describing: format),
            "target_servings": targetServings,
            "original_servings": recipe.parsedServingCount
        ])
    }

    private func toggleFavorite() {
        recipe.isFavorite.toggle()
        recipe.lastModified = Date()

        // Sync with Favorites collection
        syncFavoritesCollection()

        Log.info("Toggling favorite status", category: .ui, metadata: ["title": recipe.title, "isFavorite": recipe.isFavorite])
        Log.debug("Firebase backend configuration", category: .firebase, metadata: ["isFirebaseActive": backendConfig.isFirebaseActive])

        do {
            try modelContext.save()
            Log.info("Favorite status saved locally", category: .database)

            // Sync favorite status to Firebase
            if backendConfig.isFirebaseActive {
                Log.debug("Firebase active, uploading recipe", category: .firebase)
                Task {
                    do {
                        try await firebaseSync.uploadRecipe(recipe)
                        Log.info("Favorite status synced to Firebase", category: .firebase)
                    } catch {
                        Log.warning("Failed to sync favorite status to Firebase", category: .firebase, metadata: ["error": error.localizedDescription])
                    }
                }
            } else {
                Log.debug("Firebase not active, skipping upload", category: .firebase)
            }
        } catch {
            Log.error("Failed to save favorite status locally", category: .database, metadata: ["error": error.localizedDescription])
            toastManager.error(
                title: "Failed to update favorite",
                message: error.localizedDescription
            )
            return
        }

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: recipe.isFavorite ? .medium : .light)
        generator.impactOccurred()

        let message = recipe.isFavorite ? "Added to favorites" : "Removed from favorites"
        toastManager.success(title: message)

        // TODO: Add VoiceOver announcement once AccessibilityAnnouncementService is added to Xcode project
        // if recipe.isFavorite {
        //     AccessibilityAnnouncementService.shared.announceRecipeFavorited(title: recipe.title)
        // } else {
        //     AccessibilityAnnouncementService.shared.announceRecipeUnfavorited(title: recipe.title)
        // }

        // Track analytics
        analytics.trackRecipeFavorited(recipe: recipe, isFavorite: recipe.isFavorite)
    }

    private func syncFavoritesCollection() {
        // Fetch Favorites system collection
        let descriptor = FetchDescriptor<RecipeCollection>(
            predicate: #Predicate { collection in
                collection.name == "Favorites" && collection.isSystemCollection
            }
        )

        guard let favoritesCollection = try? modelContext.fetch(descriptor).first else {
            // Favorites collection doesn't exist - create it
            let favorites = RecipeCollection(
                name: "Favorites",
                description: "Your favorite recipes",
                iconName: "heart.fill",
                color: "#FF6B6B",
                isSystemCollection: true
            )
            modelContext.insert(favorites)

            if recipe.isFavorite {
                if recipe.collections == nil {
                    recipe.collections = [favorites]
                } else {
                    recipe.collections?.append(favorites)
                }
            }
            return
        }

        // Sync membership based on isFavorite boolean
        if recipe.isFavorite {
            // Add to Favorites if not already there
            if recipe.collections == nil {
                recipe.collections = [favoritesCollection]
            } else if !recipe.collections!.contains(where: { $0.id == favoritesCollection.id }) {
                recipe.collections?.append(favoritesCollection)
            }
        } else {
            // Remove from Favorites
            recipe.collections?.removeAll { $0.id == favoritesCollection.id }
        }
    }

    private var isInShoppingCart: Bool {
        recipe.isInShoppingCart(context: modelContext)
    }

    private func addToShoppingList() {
        if let existingCartRecipe = recipe.shoppingCartRecipe(context: modelContext) {
            // Remove from cart
            modelContext.delete(existingCartRecipe)
            recipe.isInShoppingList = false

            // Save changes
            do {
                try modelContext.save()

                // Haptic feedback
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()

                toastManager.success(title: "Removed from shopping list")

                // Track analytics
                analytics.trackShoppingListToggle(recipe: recipe, isInList: false)
            } catch {
                toastManager.error(
                    title: "Failed to remove from shopping list",
                    message: error.localizedDescription
                )
            }
        } else {
            // Add to cart with current target servings
            let cartRecipe = ShoppingCartRecipe(recipe: recipe, targetServings: targetServings)
            modelContext.insert(cartRecipe)
            recipe.isInShoppingList = true

            // Save changes
            do {
                try modelContext.save()

                // Haptic feedback
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()

                let servingText = targetServings == recipe.parsedServingCount
                    ? ""
                    : " (for \(targetServings))"
                toastManager.success(title: "Added to shopping list\(servingText)")

                // Track analytics
                analytics.trackShoppingListToggle(recipe: recipe, isInList: true)

                // Track scaled recipe added to cart
                if targetServings != recipe.parsedServingCount {
                    analytics.track(event: .scaledRecipeAddedToCart, properties: [
                        "recipe_title": recipe.title,
                        "category": recipe.category?.rawValue ?? "unknown",
                        "original_servings": recipe.parsedServingCount,
                        "target_servings": targetServings,
                        "scale_factor": Double(targetServings) / Double(recipe.parsedServingCount)
                    ])
                }
            } catch {
                toastManager.error(
                    title: "Failed to add to shopping list",
                    message: error.localizedDescription
                )
            }
        }

        recipe.lastModified = Date()
        try? modelContext.save()
    }

    private func deleteRecipe() {
        isDeleting = true

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        // NOTE: Do NOT delete from Firebase here!
        // UndoService handles Firebase deletion after the undo window expires.
        // This allows the user to undo the delete within 5 seconds.

        // Use UndoService for soft delete with undo capability
        let undoService = ServiceContainer.shared.resolve(UndoService.self)
        undoService.deleteRecipe(recipe, context: modelContext)

        // Show undo toast with countdown
        guard let undoItem = undoService.pendingUndos.last else {
            Log.error("Failed to create undo item for recipe deletion", category: .database)
            return
        }

        toastManager.showUndoToast(for: undoItem) { [undoItem] in
            // Undo action - use the captured undoItem, not pendingUndos.last
            undoService.undoDelete(undoItem)

            // Success haptic for undo
            let successGenerator = UINotificationFeedbackGenerator()
            successGenerator.notificationOccurred(.success)

            toastManager.success(title: "Recipe restored")

            // Update UI state
            isDeleting = false
        }

        // Track analytics
        analytics.trackRecipeDeleted(recipeTitle: recipe.title)

        // Dismiss view after short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            dismiss()
        }
    }

    private func duplicateRecipe() {
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        // Create a new recipe with copied data
        let duplicate = Recipe(
            title: "\(recipe.title) (Copy)",
            sourceType: recipe.sourceType ?? .manual,
            sourceURL: recipe.sourceURL,
            instructions: recipe.instructions,
            servings: recipe.servings,
            prepTime: recipe.prepTime,
            cookTime: recipe.cookTime
        )

        // Copy additional content
        duplicate.notes = recipe.notes
        duplicate.totalTime = recipe.totalTime

        // Copy source information (but not CloudKit/share metadata)
        duplicate.sourceBookTitle = recipe.sourceBookTitle
        duplicate.sourceBookAuthor = recipe.sourceBookAuthor
        duplicate.sourceBookPage = recipe.sourceBookPage
        duplicate.sourcePerson = recipe.sourcePerson
        duplicate.sourceDate = recipe.sourceDate
        duplicate.sourceStory = recipe.sourceStory
        duplicate.sourceImageURL = recipe.sourceImageURL

        // Copy scaling metadata
        duplicate.scalabilityRating = recipe.scalabilityRating
        duplicate.recipeCategory = recipe.recipeCategory
        duplicate.minimumServings = recipe.minimumServings
        duplicate.maximumServings = recipe.maximumServings
        duplicate.scalingNote = recipe.scalingNote

        // Copy organization (tags and collections will be nil - user can add them later)
        // NOT copying: isFavorite, timesCooked, lastCooked, isInShoppingList

        // Copy ingredients
        if let ingredients = recipe.ingredients {
            duplicate.ingredients = ingredients.map { ingredient in
                let newIngredient = Ingredient(
                    originalText: ingredient.originalText,
                    name: ingredient.name,
                    quantity: ingredient.quantity,
                    unit: ingredient.unit,
                    category: ingredient.category ?? .other,
                    orderIndex: ingredient.orderIndex
                )
                // Set additional properties not in init
                newIngredient.quantityMax = ingredient.quantityMax
                newIngredient.preparation = ingredient.preparation
                return newIngredient
            }
        }

        // Copy image filename (will point to same image file)
        duplicate.imageFileName = recipe.imageFileName

        // Insert into context
        modelContext.insert(duplicate)

        do {
            try modelContext.save()

            // Success haptic
            let successGenerator = UINotificationFeedbackGenerator()
            successGenerator.notificationOccurred(.success)

            toastManager.success(title: "Recipe duplicated")

            // Track analytics
            analytics.track(event: .featureUsed, properties: [
                "feature": "recipe_duplicated",
                "original_title": recipe.title,
                "has_ingredients": recipe.ingredients?.isEmpty == false,
                "has_instructions": !recipe.instructions.isEmpty
            ])

            // Navigate to the duplicate
            dismiss()
        } catch {
            toastManager.error(
                title: "Failed to duplicate recipe",
                message: error.localizedDescription
            )
        }
    }

    // MARK: - Heritage Recipe Lifecycle

    private func handleEditTapped() {
        if recipe.isThemeRecipe {
            // Show confirmation dialog for heritage recipes
            showHeritageEditConfirmation = true
        } else {
            // Directly edit non-heritage recipes
            recipeToEdit = recipe
            showEditSheet = true
        }
    }

    private func createUserCopyAndEdit() {
        // Create user's personal copy of the heritage recipe
        let userCopy = recipe.createUserCopy(context: modelContext)

        // Save context to persist the copy
        do {
            try modelContext.save()

            // Track that user created a copy
            UserDefaults.standard.set(true, forKey: "HeritageRecipeCopied_\(recipe.id.uuidString)")

            // Open editor with the new copy
            recipeToEdit = userCopy
            showEditSheet = true

            Log.info("User created copy of heritage recipe for editing", category: .database, metadata: [
                "original": recipe.title,
                "copy": userCopy.title
            ])
        } catch {
            Log.error("Failed to create user copy of heritage recipe", category: .database, metadata: [
                "error": error.localizedDescription
            ])
        }
    }

    // MARK: - AI Image Generation

    private func generateAIImage() {
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        Task {
            do {
                try await recipeImageGenerator.generateAndSaveImage(for: recipe)
                toastManager.success(title: "Image Generated", message: recipe.title)
            } catch {
                toastManager.error(title: "Generation Failed", message: error.localizedDescription)
            }
        }
    }
}

// MARK: - Heirloom Share Explanation View
struct HeirloomShareExplanationView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: HeirloomSpacing.xl) {
                    // Header
                    VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                        Image(systemName: "arrow.down.heart.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(HeirloomColors.familyGreen)

                        Text("What's an Heirloom Share?")
                            .font(HeirloomFonts.title2)
                            .foregroundStyle(HeirloomColors.primaryText)

                        Text("A special way to pass down family recipes through generations")
                            .font(HeirloomFonts.body)
                            .foregroundStyle(HeirloomColors.secondaryText)
                    }

                    // Features
                    VStack(alignment: .leading, spacing: HeirloomSpacing.lg) {
                        featureRow(
                            icon: "person.2.fill",
                            title: "Tracks Lineage",
                            description: "Records who shared it and tracks generations (1st Gen, 2nd Gen, etc.)"
                        )

                        featureRow(
                            icon: "clock.arrow.circlepath",
                            title: "Preserves History",
                            description: "Keeps the story of where the recipe came from and how it traveled through your family"
                        )

                        featureRow(
                            icon: "doc.on.doc.fill",
                            title: "Creates a Copy",
                            description: "Recipients get their own version to customize while preserving the original"
                        )

                        featureRow(
                            icon: "heart.fill",
                            title: "Special Meaning",
                            description: "Shows this recipe has personal significance and family history"
                        )
                    }

                    // Comparison
                    VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
                        Text("When to use each option:")
                            .font(HeirloomFonts.bodyBold)
                            .foregroundStyle(HeirloomColors.primaryText)

                        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                            HStack(alignment: .top, spacing: HeirloomSpacing.sm) {
                                Image(systemName: "icloud.fill")
                                    .foregroundStyle(HeirloomColors.tomato)
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Share Recipe")
                                        .font(HeirloomFonts.bodyBold)
                                        .foregroundStyle(HeirloomColors.primaryText)
                                    Text("Quick sharing for any recipe. Best for sharing with friends or trying recipes together.")
                                        .font(HeirloomFonts.caption1)
                                        .foregroundStyle(HeirloomColors.secondaryText)
                                }
                            }

                            HStack(alignment: .top, spacing: HeirloomSpacing.sm) {
                                Image(systemName: "arrow.down.heart.fill")
                                    .foregroundStyle(HeirloomColors.familyGreen)
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Share Recipe as Heirloom")
                                        .font(HeirloomFonts.bodyBold)
                                        .foregroundStyle(HeirloomColors.primaryText)
                                    Text("For cherished family recipes being passed down through generations. Preserves lineage and history.")
                                        .font(HeirloomFonts.caption1)
                                        .foregroundStyle(HeirloomColors.secondaryText)
                                }
                            }
                        }
                        .padding(HeirloomSpacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: HeirloomSpacing.cardCornerRadius)
                                .fill(HeirloomColors.cardBackground)
                        )
                    }
                }
                .padding(HeirloomSpacing.lg)
            }
            .navigationTitle("Heirloom Sharing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Got It") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: HeirloomSpacing.md) {
            Image(systemName: icon)
                .font(HeirloomFonts.title2)
                .foregroundStyle(HeirloomColors.familyGreen)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
                Text(title)
                    .font(HeirloomFonts.bodyBold)
                    .foregroundStyle(HeirloomColors.primaryText)

                Text(description)
                    .font(HeirloomFonts.body)
                    .foregroundStyle(HeirloomColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        RecipeDetailView(recipe: .example)
    }
    .modelContainer(for: Recipe.self, inMemory: true)
    .toastContainer()
}
