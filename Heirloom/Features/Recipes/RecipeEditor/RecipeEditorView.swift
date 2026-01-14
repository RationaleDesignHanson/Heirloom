import SwiftUI
import SwiftData
import PhotosUI

struct RecipeEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.firebaseSync) private var firebaseSync
    @Environment(\.firebaseLineage) private var firebaseLineage
    @Environment(\.aiIngredientParser) private var aiIngredientParser
    @Environment(\.firebaseAuth) private var firebaseAuth
    @EnvironmentObject private var tabCoordinator: TabNavigationCoordinator

    @Query(sort: \RecipeCollection.name) private var allCollections: [RecipeCollection]

    // Using concrete type for spell checker
    private var spellChecker: AIIngredientSpellChecker { ServiceContainer.shared.resolve(AIIngredientSpellChecker.self) }

    // Using concrete type for toast notifications
    private var toastManager: ToastManager { ServiceContainer.shared.resolve(ToastManager.self) }

    private var analytics: AnalyticsService { ServiceContainer.shared.resolve(AnalyticsService.self) }

    // Using concrete type for image storage
    private var imageStorageService: ImageStorageService { ServiceContainer.shared.resolve(ImageStorageService.self) }
    private var backendConfig: BackendConfig { ServiceContainer.shared.resolve(BackendConfig.self) }
    private var paywallManager: PaywallManager { ServiceContainer.shared.resolve(PaywallManager.self) }

    @State private var recipe: Recipe
    @State private var isNewRecipe: Bool
    @State private var isSaving = false

    // Form fields
    @State private var title = ""
    @State private var sourceType: RecipeSourceType = .manual
    @State private var sourceURL = ""
    @State private var servings = ""
    @State private var prepTime = ""
    @State private var cookTime = ""
    @State private var notes = ""
    @State private var instructions: [String] = [""]
    @State private var ingredientInputs: [String] = [""]

    // Collections selection
    @State private var selectedCollectionIDs: Set<UUID> = []

    // Image handling
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var recipeImage: UIImage?

    // Focus management for auto-focusing new ingredient fields
    @FocusState private var focusedIngredientIndex: Int?

    // Spell checking
    @State private var spellCheckResults: [Int: AIIngredientSpellChecker.SpellingResult] = [:]
    @State private var spellCheckTask: Task<Void, Never>?

    init(
        recipe: Recipe? = nil,
        initialImage: UIImage? = nil,
        initialIngredients: [String]? = nil,
        initialInstructions: [String]? = nil
    ) {
        let editingRecipe = recipe ?? Recipe()
        _recipe = State(initialValue: editingRecipe)
        _isNewRecipe = State(initialValue: recipe == nil)

        // Initialize form fields from recipe
        if let recipe = recipe {
            _title = State(initialValue: recipe.title)
            _sourceType = State(initialValue: recipe.sourceType ?? .manual)
            _sourceURL = State(initialValue: recipe.sourceURL ?? "")
            _servings = State(initialValue: recipe.servings ?? "")
            _prepTime = State(initialValue: recipe.prepTime ?? "")
            _cookTime = State(initialValue: recipe.cookTime ?? "")
            _notes = State(initialValue: recipe.notes ?? "")
            _instructions = State(initialValue: recipe.instructions.isEmpty ? [""] : recipe.instructions)

            if let ingredients = recipe.ingredients, !ingredients.isEmpty {
                _ingredientInputs = State(initialValue: ingredients.map { $0.originalText })
            }

            // Initialize selected collections
            if let collections = recipe.collections {
                _selectedCollectionIDs = State(initialValue: Set(collections.map { $0.id }))
            }
        } else {
            // Initialize from OCR/scanner if provided
            if let image = initialImage {
                _recipeImage = State(initialValue: image)
                _sourceType = State(initialValue: .cookbook)
            }

            if let ingredients = initialIngredients, !ingredients.isEmpty {
                _ingredientInputs = State(initialValue: ingredients)
            }

            if let instructions = initialInstructions, !instructions.isEmpty {
                _instructions = State(initialValue: instructions)
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                if shouldShowSignInReminder {
                    signInReminderSection
                }

                basicInfoSection
                imageSection
                metadataSection
                collectionsSection
                ingredientsSection
                instructionsSection
                notesSection
            }
            .navigationTitle(isNewRecipe ? "New Recipe" : "Edit Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        // Clear coordinator context if canceling new recipe
                        if isNewRecipe {
                            tabCoordinator.didCancelCreation()
                        }
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        saveRecipe()
                    } label: {
                        if isSaving {
                            ProgressView()
                                .tint(HeirloomColors.tomato)
                        } else {
                            Text("Save")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(title.isEmpty || isSaving)
                }
            }
            .task {
                // Load existing recipe image when editing
                if !isNewRecipe, let imageFileName = recipe.imageFileName {
                    if let loadedImage = await imageStorageService.loadImage(fileName: imageFileName) {
                        recipeImage = loadedImage
                        Log.info("Loaded existing recipe image", category: .storage, metadata: ["fileName": imageFileName])
                    } else {
                        Log.warning("Failed to load recipe image", category: .storage, metadata: ["fileName": imageFileName])
                    }
                }
            }
        }
    }

    // MARK: - Computed Properties

    /// User-created collections (excludes system and heritage collections)
    private var userCollections: [RecipeCollection] {
        allCollections.filter { !$0.isSystemCollection && !$0.isHeritageCollection }
    }

    /// Show sign-in reminder if creating new manual recipe and not authenticated
    private var shouldShowSignInReminder: Bool {
        isNewRecipe && sourceType == .manual && firebaseAuth.currentUser == nil
    }

    // MARK: - View Sections

    private var basicInfoSection: some View {
        Section("Recipe Details") {
            TextField("Recipe Title", text: $title)
                .font(HeirloomFonts.body)

            Picker("Source", selection: $sourceType) {
                ForEach(RecipeSourceType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .font(HeirloomFonts.body)

            if sourceType == .url {
                TextField("Recipe URL (optional)", text: $sourceURL)
                    .font(HeirloomFonts.body)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
            }
        }
    }

    private var imageSection: some View {
        Section("Photo") {
            if let image = recipeImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxHeight: 200)
                    .cornerRadius(8)
                    .clipped()
            }

            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Label(
                    recipeImage == nil ? "Add Photo" : "Change Photo",
                    systemImage: "photo"
                )
                .font(HeirloomFonts.body)
            }
            .onChange(of: selectedPhoto) { _, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        recipeImage = image
                    }
                }
            }
        }
    }

    private var metadataSection: some View {
        Section("Cooking Info") {
            HStack {
                Text("Servings")
                    .font(HeirloomFonts.body)
                Spacer()
                TextField("4", text: $servings)
                    .font(HeirloomFonts.body)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.numberPad)
                    .frame(width: 100)
            }

            HStack {
                Text("Prep Time")
                    .font(HeirloomFonts.body)
                Spacer()
                TextField("15 min", text: $prepTime)
                    .font(HeirloomFonts.body)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 100)
            }

            HStack {
                Text("Cook Time")
                    .font(HeirloomFonts.body)
                Spacer()
                TextField("30 min", text: $cookTime)
                    .font(HeirloomFonts.body)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 100)
            }
        }
    }

    private var collectionsSection: some View {
        Section {
            if userCollections.isEmpty {
                Text("No collections yet. Create one from the Collections tab.")
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(HeirloomColors.secondaryText)
            } else {
                ForEach(userCollections, id: \.id) { collection in
                    Button {
                        toggleCollection(collection)
                    } label: {
                        HStack(spacing: HeirloomSpacing.md) {
                            Image(systemName: collection.iconName)
                                .font(.title3)
                                .foregroundStyle(collection.swiftUIColor)
                                .frame(width: 28)

                            Text(collection.name)
                                .font(HeirloomFonts.body)
                                .foregroundStyle(HeirloomColors.primaryText)

                            Spacer()

                            if selectedCollectionIDs.contains(collection.id) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(collection.swiftUIColor)
                                    .font(.title3)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundStyle(HeirloomColors.charcoal.opacity(0.3))
                                    .font(.title3)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        } header: {
            Text("Collections (Optional)")
        } footer: {
            Text("Add this recipe to collections to keep your recipes organized.")
                .font(HeirloomFonts.caption1)
        }
    }

    private var ingredientsSection: some View {
        Section {
            ForEach(ingredientInputs.indices, id: \.self) { index in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        TextField("Ingredient", text: $ingredientInputs[index])
                            .font(HeirloomFonts.body)
                            .focused($focusedIngredientIndex, equals: index)
                            .onSubmit {
                                // Add new ingredient field when user presses Enter on last field
                                if index == ingredientInputs.count - 1 {
                                    ingredientInputs.append("")
                                    // Auto-focus the new field
                                    focusedIngredientIndex = ingredientInputs.count - 1
                                }
                            }
                            .onChange(of: ingredientInputs[index]) { oldValue, newValue in
                                // Debounced spell check
                                checkSpelling(for: index, text: newValue)
                            }

                        if ingredientInputs.count > 1 {
                            Button {
                                ingredientInputs.remove(at: index)
                                spellCheckResults.removeValue(forKey: index)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red)
                            }
                        }
                    }

                    // Show spell check suggestions if any
                    if let result = spellCheckResults[index], result.hasIssues {
                        ForEach(result.suggestions) { suggestion in
                            suggestionChip(for: suggestion, index: index)
                        }
                    }
                }
            }

            Button {
                ingredientInputs.append("")
            } label: {
                Label("Add Ingredient", systemImage: "plus.circle.fill")
                    .font(HeirloomFonts.body)
            }
        } header: {
            Text("Ingredients")
        }
    }

    private var instructionsSection: some View {
        Section {
            ForEach(instructions.indices, id: \.self) { index in
                HStack(alignment: .top) {
                    Text("\(index + 1).")
                        .font(HeirloomFonts.bodyBold)
                        .foregroundStyle(HeirloomColors.charcoal.opacity(0.6))
                        .frame(width: 25, alignment: .leading)

                    TextField("Step description", text: $instructions[index], axis: .vertical)
                        .font(HeirloomFonts.body)
                        .lineLimit(3...10)

                    if instructions.count > 1 {
                        Button {
                            instructions.remove(at: index)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .onMove { from, to in
                instructions.move(fromOffsets: from, toOffset: to)
            }

            Button {
                instructions.append("")
            } label: {
                Label("Add Step", systemImage: "plus.circle.fill")
                    .font(HeirloomFonts.body)
            }
        } header: {
            HStack {
                Text("Instructions")
                Spacer()
                if instructions.count > 1 {
                    Text("Drag to reorder")
                        .font(HeirloomFonts.caption2)
                        .foregroundStyle(HeirloomColors.secondaryText)
                }
            }
        }
    }

    private var notesSection: some View {
        Section("Notes") {
            TextField("Add any notes or tips...", text: $notes, axis: .vertical)
                .font(HeirloomFonts.body)
                .lineLimit(3...10)
        }
    }

    private var signInReminderSection: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 20))
                    .foregroundStyle(HeirloomColors.tomato)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Personalize your recipes")
                        .font(HeirloomFonts.bodyBold)
                        .foregroundStyle(HeirloomColors.primaryText)

                    Text("Sign in to replace \"My Recipe\" with your name on all recipes you create")
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(HeirloomColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Button {
                    // Navigate to settings to sign in
                    tabCoordinator.selectedTab = TabNavigationCoordinator.Tab.settings.rawValue
                    dismiss()
                } label: {
                    Text("Sign In")
                        .font(HeirloomFonts.caption1Bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(HeirloomColors.tomato)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 8)
        }
        .listRowBackground(HeirloomColors.tomato.opacity(0.05))
    }

    // MARK: - Actions

    private func toggleCollection(_ collection: RecipeCollection) {
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        if selectedCollectionIDs.contains(collection.id) {
            selectedCollectionIDs.remove(collection.id)
        } else {
            selectedCollectionIDs.insert(collection.id)
        }
    }

    private func saveRecipe() {
        isSaving = true

        Task {
            do {
                // Capture original state for CRDT operation tracking
                let originalTitle = recipe.title
                let originalServings = recipe.servings
                let originalPrepTime = recipe.prepTime
                let originalCookTime = recipe.cookTime
                let originalNotes = recipe.notes
                let originalInstructions = recipe.instructions
                let originalIngredients = recipe.ingredients?.map { $0.originalText } ?? []

                // Update recipe properties
                recipe.title = title
                recipe.sourceType = sourceType
                try recipe.setSourceURL(sourceURL.isEmpty ? nil : sourceURL)
                recipe.servings = servings.isEmpty ? nil : servings
                recipe.prepTime = prepTime.isEmpty ? nil : prepTime
                recipe.cookTime = cookTime.isEmpty ? nil : cookTime
                recipe.setNotes(notes.isEmpty ? nil : notes)
                recipe.instructions = instructions.filter { !$0.isEmpty }
                recipe.lastModified = Date()
                recipe.modifiedAt = Date()  // CRITICAL: Update modifiedAt to trigger sync

                // Apply selected collections
                let selectedCollections = allCollections.filter { selectedCollectionIDs.contains($0.id) }
                recipe.collections = selectedCollections.isEmpty ? nil : selectedCollections

                // Create CRDT operations for changes (if editing existing recipe)
                if !isNewRecipe && recipe.usesCRDT {
                    let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? "unknown-ios"
                    var operations: [RecipeOperation] = []
                    let emptyVectorClock = VectorClock() // Temporary, will be replaced with real clock during upload

                    if originalTitle != recipe.title {
                        operations.append(RecipeOperation(
                            recipeId: recipe.id,
                            deviceId: deviceId,
                            vectorClock: emptyVectorClock,
                            operationType: .update,
                            fieldPath: "title",
                            oldValue: .string(originalTitle),
                            newValue: .string(recipe.title)
                        ))
                    }
                    if originalServings != recipe.servings {
                        operations.append(RecipeOperation(
                            recipeId: recipe.id,
                            deviceId: deviceId,
                            vectorClock: emptyVectorClock,
                            operationType: .update,
                            fieldPath: "servings",
                            oldValue: originalServings.map { .string($0) },
                            newValue: recipe.servings.map { .string($0) } ?? .null
                        ))
                    }
                    if originalPrepTime != recipe.prepTime {
                        operations.append(RecipeOperation(
                            recipeId: recipe.id,
                            deviceId: deviceId,
                            vectorClock: emptyVectorClock,
                            operationType: .update,
                            fieldPath: "prepTime",
                            oldValue: originalPrepTime.map { .string($0) },
                            newValue: recipe.prepTime.map { .string($0) } ?? .null
                        ))
                    }
                    if originalCookTime != recipe.cookTime {
                        operations.append(RecipeOperation(
                            recipeId: recipe.id,
                            deviceId: deviceId,
                            vectorClock: emptyVectorClock,
                            operationType: .update,
                            fieldPath: "cookTime",
                            oldValue: originalCookTime.map { .string($0) },
                            newValue: recipe.cookTime.map { .string($0) } ?? .null
                        ))
                    }
                    if originalNotes != recipe.notes {
                        operations.append(RecipeOperation(
                            recipeId: recipe.id,
                            deviceId: deviceId,
                            vectorClock: emptyVectorClock,
                            operationType: .update,
                            fieldPath: "notes",
                            oldValue: originalNotes.map { .string($0) },
                            newValue: recipe.notes.map { .string($0) } ?? .null
                        ))
                    }
                    if originalInstructions != recipe.instructions {
                        operations.append(RecipeOperation(
                            recipeId: recipe.id,
                            deviceId: deviceId,
                            vectorClock: emptyVectorClock,
                            operationType: .update,
                            fieldPath: "instructions",
                            oldValue: .stringArray(originalInstructions),
                            newValue: .stringArray(recipe.instructions)
                        ))
                    }

                    // Add operations to recipe (they'll be uploaded with the recipe)
                    if !operations.isEmpty {
                        Log.info("Created CRDT operations for recipe edit", category: .crdt, metadata: ["operationCount": operations.count])

                        // Store operations data on recipe for upload
                        if let operationsData = try? JSONEncoder().encode(operations) {
                            recipe.pendingOperationsData = operationsData
                        }
                    }
                }

            // TRANSACTION: Delete old ingredients and create new ones atomically
            // This prevents partial deletion if save fails mid-operation
            do {
                // Phase 1: Delete old ingredients in batch
                if let oldIngredients = recipe.ingredients, !oldIngredients.isEmpty {
                    Log.info("Deleting old ingredients for re-parse",
                            category: .database,
                            metadata: ["count": oldIngredients.count, "recipeId": recipe.id.uuidString])

                    // Delete all old ingredients
                    for oldIngredient in oldIngredients {
                        modelContext.delete(oldIngredient)
                    }

                    // Clear the relationship immediately
                    recipe.ingredients = nil

                    // Commit deletion before proceeding (transaction checkpoint)
                    try modelContext.save()

                    Log.debug("Old ingredients deleted successfully", category: .database)
                }

                // Phase 2: Parse and create new ingredients
                let filteredIngredients = ingredientInputs.filter { !$0.isEmpty }

                guard !filteredIngredients.isEmpty else {
                    // No new ingredients - keep recipe.ingredients = nil
                    Log.debug("No ingredients to add", category: .database)
                    // Skip to end
                    recipe.ingredients = nil
                    try modelContext.save()
                    return
                }

                Log.info("Parsing new ingredients",
                        category: .database,
                        metadata: ["count": filteredIngredients.count, "recipeId": recipe.id.uuidString])

                // Parse all ingredients in batch for efficiency
                let parsedResults = try await aiIngredientParser.parseBatch(filteredIngredients)

                var newIngredients: [Ingredient] = []

                // Phase 3: Create new ingredient models
                for (index, ingredientText) in filteredIngredients.enumerated() {
                    let parsed = parsedResults[index]

                    // Categorize based on ingredient name
                    let category = GroceryCategory.categorize(parsed.name)

                    let ingredient = Ingredient(
                        originalText: ingredientText,
                        name: parsed.name,
                        quantity: parsed.quantity,
                        unit: parsed.unit,
                        category: category,
                        orderIndex: index
                    )
                    ingredient.recipe = recipe
                    newIngredients.append(ingredient)
                    modelContext.insert(ingredient)
                }

                // Phase 4: Update recipe relationship
                recipe.ingredients = newIngredients

                // Commit new ingredients (transaction complete)
                try modelContext.save()

                Log.info("New ingredients created successfully",
                        category: .database,
                        metadata: ["count": newIngredients.count, "recipeId": recipe.id.uuidString])

            } catch {
                // Rollback on any failure
                Log.error("Failed to update ingredients",
                         category: .database,
                         metadata: ["error": error.localizedDescription, "recipeId": recipe.id.uuidString])

                // Re-throw to fail the save
                throw error
            }

            // Track ingredient changes for CRDT (after transaction completes)
            if !isNewRecipe && recipe.usesCRDT {
                let currentIngredients = recipe.ingredients?.map { $0.originalText } ?? []

                // Check if ingredients changed
                if originalIngredients != currentIngredients {
                    Log.debug("Ingredients changed, creating CRDT operation", category: .crdt, metadata: [
                        "originalCount": originalIngredients.count,
                        "currentCount": currentIngredients.count
                    ])

                    let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? "unknown-ios"
                    let emptyVectorClock = VectorClock()

                    let ingredientOperation = RecipeOperation(
                        recipeId: recipe.id,
                        deviceId: deviceId,
                        vectorClock: emptyVectorClock,
                        operationType: .update,
                        fieldPath: "ingredients",
                        oldValue: .stringArray(originalIngredients),
                        newValue: .stringArray(currentIngredients)
                    )

                    // Append to existing pending operations (if any)
                    var allOperations: [RecipeOperation] = []
                    if let existingData = recipe.pendingOperationsData,
                       let existingOps = try? JSONDecoder().decode([RecipeOperation].self, from: existingData) {
                        allOperations = existingOps
                    }
                    allOperations.append(ingredientOperation)

                    if let operationsData = try? JSONEncoder().encode(allOperations) {
                        recipe.pendingOperationsData = operationsData
                    }

                    Log.info("Created CRDT operation for ingredient changes", category: .crdt)
                }
            }

            // Auto-detect recipe category for smart serving presets
            recipe.detectAndApplyCategory()

            // Save image if provided
            if let image = recipeImage {
                do {
                    try await recipe.saveImage(image)
                } catch {
                    Log.warning("Failed to save recipe image", category: .storage, metadata: ["error": error.localizedDescription])
                }
            }

            // Insert new recipe if needed
            if isNewRecipe {
                recipe.dateAdded = Date()

                // Initialize provenance metadata for new recipes
                if recipe.provenance == nil {
                    let provenanceSourceType: ProvenanceMetadata.SourceType

                    // Map RecipeSourceType to ProvenanceMetadata.SourceType
                    switch sourceType {
                    case .manual:
                        provenanceSourceType = .userCreated
                    case .url:
                        provenanceSourceType = .imported
                    case .cookbook:
                        provenanceSourceType = .userCreated
                    case .family:
                        provenanceSourceType = .shared
                    case .scan:
                        provenanceSourceType = .scanned
                    case .heritage:
                        provenanceSourceType = .imported
                    case .video:
                        provenanceSourceType = .video
                    }

                    recipe.provenance = ProvenanceMetadata(
                        sourceType: provenanceSourceType,
                        sourceURL: sourceURL.isEmpty ? nil : sourceURL,
                        sourceAttribution: nil,
                        generation: 0
                    )
                }

                modelContext.insert(recipe)

                // Track analytics
                analytics.trackRecipeCreated(recipe: recipe)

                // Track for paywall triggers (1st recipe, 5th recipe, etc.)
                paywallManager.trackRecipeAdded()
            } else {
                // Track analytics
                analytics.trackRecipeEdited(recipe: recipe)
            }

            // CRDT-aware transactional save (v2.0+)
            // Phase 1: Upload to Firebase FIRST (if active)
            if backendConfig.isFirebaseActive {
                do {
                    // Use transactional upload (uploads to Firebase, THEN marks as synced locally)
                    try await firebaseSync.uploadRecipeTransactional(recipe)
                    Log.info("Recipe synced to Firebase with transaction", category: .firebase, metadata: ["title": recipe.title])

                    // Track modification in lineage if this is an edit of a heirloom recipe
                    Log.debug("Checking if should record lineage modification", category: .firebase, metadata: ["isNewRecipe": isNewRecipe])
                    if !isNewRecipe {
                        Log.debug("Attempting to record lineage modification", category: .firebase)
                        do {
                            try await firebaseLineage.recordModification(
                                recipeId: recipe.id,
                                changeType: .modified,
                                changeDescription: "Recipe '\(recipe.title)' was edited",
                                fieldChanged: nil,
                                context: modelContext
                            )
                            Log.info("Lineage modification recorded", category: .firebase, metadata: ["recipeId": recipe.id.uuidString])
                        } catch {
                            Log.warning("Failed to record lineage modification", category: .firebase, metadata: ["error": error.localizedDescription])
                            // Don't fail the save - this is non-critical
                        }
                    } else {
                        Log.debug("Skipping lineage tracking for new recipe", category: .firebase)
                    }
                } catch {
                    Log.warning("Failed to sync recipe to Firebase", category: .firebase, metadata: ["error": error.localizedDescription])
                    // Fall back to local-only save
                    do {
                        try modelContext.save()
                        Log.info("Recipe saved locally after Firebase sync failed", category: .database)
                    } catch {
                        throw error
                    }
                }
            } else {
                // Phase 2: If Firebase not active, just save locally
                do {
                    try modelContext.save()
                    Log.info("Recipe saved locally (Firebase not active)", category: .database)
                } catch {
                    throw error
                }
            }

            await MainActor.run {
                isSaving = false

                // Haptic feedback
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)

                toastManager.success(
                    title: isNewRecipe ? "Recipe created!" : "Recipe updated!"
                )

                // Show share extension tip after first recipe save
                if isNewRecipe && !UserDefaults.standard.bool(forKey: UserDefaultsKeys.hasSeenShareExtensionCoachMark) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        toastManager.info(
                            title: "Pro tip: Share recipes directly from Safari",
                            message: "Use the share button in Safari to import recipes instantly"
                        )
                        UserDefaults.standard.set(true, forKey: UserDefaultsKeys.hasSeenShareExtensionCoachMark)
                    }
                }

                // Notify coordinator of recipe creation for cross-tab navigation
                if isNewRecipe {
                    tabCoordinator.didCreateRecipe()
                }

                dismiss()
            }
            } catch {
                await MainActor.run {
                    isSaving = false

                    // Haptic feedback
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.error)

                    toastManager.error(
                        title: "Failed to save recipe",
                        message: error.localizedDescription
                    )
                }
            }
        }
    }

    // MARK: - Spell Checking

    private func checkSpelling(for index: Int, text: String) {
        // Cancel any existing spell check task
        spellCheckTask?.cancel()

        // Skip spell check for empty or very short text
        guard text.count > 2 else {
            spellCheckResults.removeValue(forKey: index)
            return
        }

        // Debounce: wait 1 second after user stops typing
        spellCheckTask = Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)

            // Check if task was cancelled
            guard !Task.isCancelled else { return }

            // Run spell check
            do {
                let result = try await spellChecker.check(text)

                // Update results if there are issues
                if result.hasIssues {
                    spellCheckResults[index] = result
                } else {
                    spellCheckResults.removeValue(forKey: index)
                }
            } catch {
                Log.warning("Spell check failed", category: .general, metadata: ["error": error.localizedDescription])
            }
        }
    }

    private func suggestionChip(for suggestion: AIIngredientSpellChecker.Suggestion, index: Int) -> some View {
        Button {
            applySuggestion(suggestion, to: index)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "lightbulb.fill")
                    .font(.caption)
                    .foregroundStyle(HeirloomColors.tomato)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(suggestion.original)
                            .strikethrough()
                            .foregroundStyle(HeirloomColors.secondaryText)
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundStyle(HeirloomColors.secondaryText)
                        Text(suggestion.corrected)
                            .fontWeight(.medium)
                            .foregroundStyle(HeirloomColors.familyGreen)
                    }
                    .font(HeirloomFonts.caption1)

                    Text(suggestion.reason)
                        .font(HeirloomFonts.caption2)
                        .foregroundStyle(HeirloomColors.secondaryText)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(HeirloomColors.secondaryText)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(HeirloomColors.familyGreen.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(HeirloomColors.familyGreen.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func applySuggestion(_ suggestion: AIIngredientSpellChecker.Suggestion, to index: Int) {
        // Replace the original text with the corrected text
        let currentText = ingredientInputs[index]
        let correctedText = currentText.replacingOccurrences(
            of: suggestion.original,
            with: suggestion.corrected
        )

        ingredientInputs[index] = correctedText

        // Clear the suggestion after applying
        spellCheckResults.removeValue(forKey: index)

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        // Track analytics
        analytics.track(event: .featureUsed, properties: [
            "feature": "ingredient_spell_check",
            "action": "applied_suggestion",
            "original": suggestion.original,
            "corrected": suggestion.corrected
        ])
    }

}

// MARK: - Preview
#Preview {
    RecipeEditorView()
        .modelContainer(for: Recipe.self, inMemory: true)
        .toastContainer()
}

#Preview("Editing") {
    RecipeEditorView(recipe: .example)
        .modelContainer(for: Recipe.self, inMemory: true)
        .toastContainer()
}
