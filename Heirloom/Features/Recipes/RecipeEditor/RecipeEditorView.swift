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
    private var ingredientFormatter: IngredientFormatter { ServiceContainer.shared.resolve(IngredientFormatter.self) }

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

    // Focus management for number pad fields (servings, times)
    @FocusState private var focusedField: Field?

    enum Field {
        case servings
        case prepTime
        case cookTime
    }

    // Edit mode for ingredient/instruction deletion
    @State private var isEditingList = false

    // Sign in sheet
    @State private var showSignIn = false

    // Spell checking
    @State private var spellCheckResults: [Int: AIIngredientSpellChecker.SpellingResult] = [:]
    @State private var spellCheckTask: Task<Void, Never>?

    // AI ingredient parsing (on blur)
    @State private var parsedIngredients: [Int: Ingredient] = [:]
    @State private var ingredientParsingTasks: [Int: Task<Void, Never>] = [:]
    @State private var lastFocusedIngredientIndex: Int?

    // Version creation prompt
    @State private var showVersionPrompt = false
    @State private var shouldCreateNewVersion = false

    // Permission validation
    @State private var hasEditPermission = true
    @State private var permissionCheckReason: String?

    // Collection picker for new recipes
    @State private var showCollectionPicker = false
    @State private var savedRecipe: Recipe?

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
                // Build full ingredient string from fields for editor display
                // For video-imported recipes, originalText may not include quantity/unit
                _ingredientInputs = State(initialValue: ingredients.map { ingredient in
                    // If originalText already includes quantity, use it as-is
                    // Otherwise, reconstruct from fields
                    if let quantity = ingredient.quantity, quantity > 0 {
                        // Reconstruct: "2 cups flour, sifted"
                        var parts: [String] = []

                        // Add quantity
                        if let quantityMax = ingredient.quantityMax, quantityMax != quantity {
                            parts.append("\(Int(quantity))-\(Int(quantityMax))")
                        } else {
                            // Format nicely: "2" for whole numbers, "0.5" for fractions
                            if quantity.truncatingRemainder(dividingBy: 1) == 0 {
                                parts.append("\(Int(quantity))")
                            } else {
                                parts.append("\(quantity)")
                            }
                        }

                        // Add unit
                        if let unit = ingredient.unit {
                            parts.append(unit)
                        }

                        // Add ingredient name (from parsed name field, not originalText)
                        // CRITICAL: Use ingredient.name to avoid duplicating quantity/unit
                        parts.append(ingredient.name)

                        // Add preparation
                        if let prep = ingredient.preparation {
                            parts.append(prep)
                        }

                        return parts.joined(separator: " ")
                    } else {
                        // No quantity - use originalText as-is
                        return ingredient.originalText
                    }
                })
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

    // MARK: - Permission Validation

    /// Validates whether the current user has permission to edit this recipe
    /// Security layer to prevent unauthorized modifications
    private func validateEditPermission() {
        // New recipes can always be edited
        guard !isNewRecipe else {
            hasEditPermission = true
            permissionCheckReason = nil
            Log.info("Edit permission granted: new recipe", category: .auth)
            return
        }

        // Check if user is signed in
        guard firebaseAuth.currentUser?.uid != nil else {
            // Not signed in - allow editing local recipes for now
            // TODO: Consider blocking edits for shared recipes when not signed in
            hasEditPermission = true
            permissionCheckReason = nil
            Log.warning("Edit permission granted: no auth (local recipe)", category: .auth)
            return
        }

        // Check provenance metadata for ownership
        let provenance = recipe.provenance
        if provenance.isOriginal {
            // User created this recipe - full edit permission
            hasEditPermission = true
            permissionCheckReason = nil
            Log.info("Edit permission granted: recipe owner", category: .auth, metadata: [
                "recipeId": recipe.id.uuidString,
                "generation": provenance.generation
            ])
            return
        } else if provenance.isShared {
            // Recipe was shared to this user - all shared recipes are currently editable (heirloom behavior)
            hasEditPermission = true
            permissionCheckReason = "Shared recipe (heirloom)"
            Log.info("Edit permission granted: shared recipe", category: .auth, metadata: [
                "recipeId": recipe.id.uuidString,
                "generation": provenance.generation,
                "sharedBy": provenance.sharedByName ?? "unknown"
            ])
            return
        }

        // Default: allow editing (non-shared, non-original implies user-created)
        hasEditPermission = true
        permissionCheckReason = nil
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
                        handleSaveButton()
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

                // Keyboard toolbar for number pad fields only (servings, times)
                // Number pads don't have a return key, so we provide a Done button
                // Only show when a number pad field is focused to avoid duplicating
                // the automatic Done button that SwiftUI shows for text fields
                ToolbarItemGroup(placement: .keyboard) {
                    if focusedField != nil {
                        Spacer()
                        Button("Done") {
                            focusedField = nil
                        }
                    }
                }
            }
            .onAppear {
                // Validate edit permissions on appear
                validateEditPermission()
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
            .alert("Create New Version?", isPresented: $showVersionPrompt) {
                Button("Save Changes") {
                    shouldCreateNewVersion = false
                    saveRecipe()
                }
                Button("Create New Version") {
                    shouldCreateNewVersion = true
                    saveRecipe()
                }
                Button("Cancel", role: .cancel) {
                    // Do nothing
                }
            } message: {
                Text("You've made changes to this recipe. Would you like to save over the current version, or create a new version to keep both?")
            }
            .sheet(isPresented: $showCollectionPicker) {
                if let recipe = savedRecipe {
                    TagCollectionPickerView(recipe: recipe)
                        .onDisappear {
                            // Dismiss the editor after collection picker closes
                            dismiss()
                        }
                }
            }
            .sheet(isPresented: $showSignIn) {
                FirebaseSignInView()
                    .presentationDetents([.large])
            }
            .onChange(of: focusedIngredientIndex) { oldIndex, newIndex in
                // When focus changes, parse the ingredient that just lost focus
                if let oldIndex = oldIndex, oldIndex != newIndex {
                    parseIngredientWithAI(at: oldIndex)
                }
                lastFocusedIngredientIndex = oldIndex
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
                    .focused($focusedField, equals: .servings)
                    .frame(width: 100)
            }

            HStack {
                Text("Prep Time")
                    .font(HeirloomFonts.body)
                Spacer()
                TextField("15 min", text: $prepTime)
                    .font(HeirloomFonts.body)
                    .multilineTextAlignment(.trailing)
                    .focused($focusedField, equals: .prepTime)
                    .frame(width: 100)
            }

            HStack {
                Text("Cook Time")
                    .font(HeirloomFonts.body)
                Spacer()
                TextField("30 min", text: $cookTime)
                    .font(HeirloomFonts.body)
                    .multilineTextAlignment(.trailing)
                    .focused($focusedField, equals: .cookTime)
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
                                .font(HeirloomFonts.title2)
                                .foregroundStyle(collection.swiftUIColor)
                                .frame(width: 28)

                            Text(collection.name)
                                .font(HeirloomFonts.body)
                                .foregroundStyle(HeirloomColors.primaryText)

                            Spacer()

                            if selectedCollectionIDs.contains(collection.id) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(collection.swiftUIColor)
                                    .font(HeirloomFonts.title2)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundStyle(HeirloomColors.charcoal.opacity(0.3))
                                    .font(HeirloomFonts.title2)
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
                VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
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
                            .disabled(isEditingList)

                        if ingredientInputs.count > 1 && isEditingList {
                            Button {
                                withAnimation {
                                    ingredientInputs.remove(at: index)
                                    spellCheckResults.removeValue(forKey: index)
                                }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red)
                                    .font(.system(size: 22))
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Show spell check suggestions if any
                    if let result = spellCheckResults[index], result.hasIssues, !isEditingList {
                        ForEach(result.suggestions) { suggestion in
                            suggestionChip(for: suggestion, index: index)
                        }
                    }
                }
            }
            .onDelete { indexSet in
                // Only allow deletion if more than 1 ingredient remains
                guard ingredientInputs.count > 1 else { return }

                withAnimation {
                    ingredientInputs.remove(atOffsets: indexSet)
                    // Clean up spell check results for deleted ingredients
                    indexSet.forEach { spellCheckResults.removeValue(forKey: $0) }
                    // Clean up parsed ingredients cache
                    indexSet.forEach { parsedIngredients.removeValue(forKey: $0) }
                }
            }

            if !isEditingList {
                Button {
                    ingredientInputs.append("")
                } label: {
                    Label("Add Ingredient", systemImage: "plus.circle.fill")
                        .font(HeirloomFonts.body)
                }
            }
        } header: {
            HStack {
                Text("Ingredients")
                Spacer()
                if ingredientInputs.count > 1 {
                    Button {
                        withAnimation {
                            isEditingList.toggle()
                        }
                    } label: {
                        Text(isEditingList ? "Done" : "Edit")
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(HeirloomColors.tomato)
                    }
                }
            }
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
                        .disabled(isEditingList)

                    if instructions.count > 1 && isEditingList {
                        Button {
                            let indexToRemove = index
                            _ = withAnimation {
                                instructions.remove(at: indexToRemove)
                            }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red)
                                .font(.system(size: 22))
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .onMove { from, to in
                instructions.move(fromOffsets: from, toOffset: to)
            }
            .onDelete { indexSet in
                // Only allow deletion if more than 1 instruction remains
                guard instructions.count > 1 else { return }

                withAnimation {
                    instructions.remove(atOffsets: indexSet)
                }
            }

            if !isEditingList {
                Button {
                    instructions.append("")
                } label: {
                    Label("Add Step", systemImage: "plus.circle.fill")
                        .font(HeirloomFonts.body)
                }
            }
        } header: {
            HStack {
                Text("Instructions")
                Spacer()
                if instructions.count > 1 {
                    if isEditingList {
                        Button {
                            withAnimation {
                                isEditingList = false
                            }
                        } label: {
                            Text("Done")
                                .font(HeirloomFonts.caption1)
                                .foregroundStyle(HeirloomColors.tomato)
                        }
                    } else {
                        HStack(spacing: HeirloomSpacing.sm) {
                            Text("Drag to reorder")
                                .font(HeirloomFonts.caption2)
                                .foregroundStyle(HeirloomColors.secondaryText)

                            Button {
                                withAnimation {
                                    isEditingList = true
                                }
                            } label: {
                                Text("Edit")
                                    .font(HeirloomFonts.caption1)
                                    .foregroundStyle(HeirloomColors.tomato)
                            }
                        }
                    }
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

                VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
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
                    // Show sign in sheet
                    showSignIn = true
                } label: {
                    Text("Sign In")
                        .font(HeirloomFonts.caption1Bold)
                        .foregroundStyle(HeirloomColors.buttonTextLight)
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

    /// Handle Save button tap - check if changes exist and show version prompt if editing
    private func handleSaveButton() {
        // For new recipes, just save directly
        guard !isNewRecipe else {
            saveRecipe()
            return
        }

        // For existing recipes, check if changes were made
        if hasChanges() {
            // Show version creation prompt
            showVersionPrompt = true
        } else {
            // No changes, just save
            saveRecipe()
        }
    }

    /// Check if user has made any changes to the recipe
    private func hasChanges() -> Bool {
        // Compare current form values to original recipe values
        if title != recipe.title { return true }
        if (sourceURL.isEmpty ? nil : sourceURL) != recipe.sourceURL { return true }
        if (servings.isEmpty ? nil : servings) != recipe.servings { return true }
        if (prepTime.isEmpty ? nil : prepTime) != recipe.prepTime { return true }
        if (cookTime.isEmpty ? nil : cookTime) != recipe.cookTime { return true }
        if (notes.isEmpty ? nil : notes) != recipe.notes { return true }

        // Check instructions
        let currentInstructions = instructions.filter { !$0.isEmpty }
        if currentInstructions != recipe.instructions { return true }

        // Check ingredients
        let currentIngredients = ingredientInputs.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        let originalIngredients = recipe.ingredients?.map { $0.originalText } ?? []
        if currentIngredients != originalIngredients { return true }

        // Check collections
        let currentCollectionIDs = selectedCollectionIDs
        let originalCollectionIDs = Set(recipe.collections?.map { $0.id } ?? [])
        if currentCollectionIDs != originalCollectionIDs { return true }

        // Check image
        if recipeImage != nil && recipe.imageFileName == nil { return true }

        return false
    }

    /// Create a new version of the recipe (duplicate with changes)
    private func createNewVersion() async throws {
        // Create new recipe with new ID
        let newRecipe = Recipe(
            title: title,
            sourceType: sourceType,
            instructions: instructions.filter { !$0.isEmpty },
            servings: servings.isEmpty ? nil : servings,
            prepTime: prepTime.isEmpty ? nil : prepTime,
            cookTime: cookTime.isEmpty ? nil : cookTime
        )

        // Copy additional properties
        try newRecipe.setSourceURL(sourceURL.isEmpty ? nil : sourceURL)
        newRecipe.setNotes(notes.isEmpty ? nil : notes)
        newRecipe.lastModified = Date()
        newRecipe.modifiedAt = Date()

        // Copy collections
        let selectedCollections = allCollections.filter { selectedCollectionIDs.contains($0.id) }
        newRecipe.collections = selectedCollections.isEmpty ? nil : selectedCollections

        // Create ingredients
        let currentIngredients = ingredientInputs.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        for (index, ingredientText) in currentIngredients.enumerated() {
            // Use AI-parsed ingredient if available, otherwise fall back to basic parser
            let ingredient: Ingredient
            if let aiParsed = parsedIngredients[index] {
                // Use AI-parsed result (includes preparation)
                ingredient = Ingredient(
                    originalText: ingredientText,
                    name: aiParsed.name,
                    quantity: aiParsed.quantity,
                    unit: aiParsed.unit,
                    category: GroceryCategory.categorize(aiParsed.name),
                    orderIndex: index
                )
                ingredient.quantityMax = aiParsed.quantityMax
                ingredient.preparation = aiParsed.preparation
            } else {
                // Fall back to basic regex parser
                let parsed = IngredientParser.parse(ingredientText)
                ingredient = Ingredient(
                    originalText: ingredientText,
                    name: parsed.name.isEmpty ? ingredientText : parsed.name,
                    quantity: parsed.quantity,
                    unit: parsed.unit,
                    category: GroceryCategory.categorize(parsed.name.isEmpty ? ingredientText : parsed.name),
                    orderIndex: index
                )
                ingredient.quantityMax = parsed.quantityMax
            }

            // Reformat the ingredient text to preserve fractions for imperial, decimals for metric
            if ingredient.quantity != nil || ingredient.unit != nil {
                let formatted = ingredientFormatter.format(ingredient, scaleFactor: 1.0, convertUnits: false)
                ingredient.originalText = formatted
            }

            ingredient.recipe = newRecipe
            modelContext.insert(ingredient)
        }

        // Save new recipe image if present
        if let image = recipeImage {
            do {
                let fileName = try await imageStorageService.saveImage(image, recipeId: newRecipe.id)
                newRecipe.imageFileName = fileName
                Log.info("Saved new version image", category: .storage, metadata: ["fileName": fileName])
            } catch {
                Log.error("Failed to save new version image", category: .storage, metadata: ["error": error.localizedDescription])
            }
        }

        // Insert new recipe into context
        modelContext.insert(newRecipe)
        try modelContext.save()

        Log.info("Created new recipe version", category: .storage, metadata: [
            "originalId": recipe.id.uuidString,
            "newId": newRecipe.id.uuidString,
            "title": newRecipe.title
        ])

        // Sync to Firebase if authenticated
        if firebaseAuth.currentUser != nil {
            do {
                try await firebaseSync.uploadRecipe(newRecipe)
                Log.info("New recipe version synced to Firebase", category: .firebase)
            } catch {
                Log.warning("Failed to sync new version to Firebase", category: .firebase, metadata: ["error": error.localizedDescription])
            }
        }

        // Reset state and show collection picker
        isSaving = false
        shouldCreateNewVersion = false

        // Show collection picker for the new version
        savedRecipe = newRecipe
        showCollectionPicker = true
    }

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
        // SECURITY: Revalidate edit permissions before saving
        validateEditPermission()

        guard hasEditPermission else {
            Log.error("Save blocked: no edit permission", category: .auth, metadata: [
                "recipeId": recipe.id.uuidString,
                "reason": permissionCheckReason ?? "unknown"
            ])
            toastManager.show(type: .error, title: "Permission Denied", message: "You don't have permission to edit this recipe")
            return
        }

        isSaving = true

        Task {
            // DIAGNOSTIC: Count Heritage recipes BEFORE save
            let heritageCountBefore = (try? modelContext.fetch(FetchDescriptor<Recipe>()))?.filter { $0.isThemeRecipe }.count ?? 0
            Log.info("🔍 SAVE START - Heritage recipes BEFORE save", category: .database, metadata: ["count": heritageCountBefore])

            do {
                // If user chose to create new version, duplicate the recipe
                if shouldCreateNewVersion {
                    try await createNewVersion()
                    return
                }

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

                // Log servings change for debugging Task #36
                if originalServings != recipe.servings {
                    Log.info("Servings modified", category: .database, metadata: [
                        "recipeId": recipe.id.uuidString,
                        "oldServings": originalServings ?? "nil",
                        "newServings": recipe.servings ?? "nil",
                        "rawInput": servings
                    ])
                }
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

                    // Track ingredient changes
                    let newIngredients = ingredientInputs.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                    if originalIngredients != newIngredients {
                        operations.append(RecipeOperation(
                            recipeId: recipe.id,
                            deviceId: deviceId,
                            vectorClock: emptyVectorClock,
                            operationType: .update,
                            fieldPath: "ingredients",
                            oldValue: .stringArray(originalIngredients),
                            newValue: .stringArray(newIngredients)
                        ))
                        Log.debug("Created CRDT operation for ingredient change", category: .crdt, metadata: [
                            "oldCount": originalIngredients.count,
                            "newCount": newIngredients.count
                        ])
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

                // Phase 2.5: Pre-parse any uncached ingredients IN PARALLEL for better performance
                // This avoids sequential AI calls during the main loop
                let uncachedIndices = filteredIngredients.enumerated().compactMap { (index, _) -> Int? in
                    parsedIngredients[index] == nil ? index : nil
                }

                if !uncachedIndices.isEmpty {
                    Log.info("Parsing \(uncachedIndices.count) uncached ingredients in parallel", category: .ai)

                    // Parse all uncached ingredients in parallel using TaskGroup
                    await withTaskGroup(of: (Int, Ingredient?).self) { group in
                        for index in uncachedIndices {
                            let text = filteredIngredients[index]
                            group.addTask {
                                do {
                                    let parsed = try await self.aiIngredientParser.parse(text)
                                    return (index, parsed)
                                } catch {
                                    Log.warning("Parallel AI parse failed for index \(index)", category: .ai)
                                    return (index, nil)
                                }
                            }
                        }

                        // Collect results into parsedIngredients cache
                        for await (index, parsed) in group {
                            if let parsed = parsed {
                                parsedIngredients[index] = parsed
                            }
                        }
                    }
                }

                var newIngredients: [Ingredient] = []

                // Phase 3: Create new ingredient models (all should be cached now)
                for (index, ingredientText) in filteredIngredients.enumerated() {
                    // Use cached AI-parsed ingredient (pre-parsed above), fallback to regex parser
                    let parsed: Ingredient
                    if let cachedParsed = parsedIngredients[index] {
                        parsed = cachedParsed
                        Log.debug("Using cached AI parse", category: .ai, metadata: ["index": index])
                    } else {
                        // Fallback to regex parser if AI parse failed
                        let regexParsed = IngredientParser.parse(ingredientText)
                        parsed = Ingredient(
                            originalText: ingredientText,
                            name: regexParsed.name.isEmpty ? ingredientText : regexParsed.name,
                            quantity: regexParsed.quantity,
                            unit: regexParsed.unit,
                            category: .other,
                            orderIndex: index
                        )
                        parsed.quantityMax = regexParsed.quantityMax
                        Log.debug("Using regex fallback parse", category: .ai, metadata: ["index": index])
                    }

                    // Categorize based on ingredient name
                    let category = GroceryCategory.categorize(parsed.name)

                    let ingredient = Ingredient(
                        originalText: ingredientText, // Will be reformatted below
                        name: parsed.name,
                        quantity: parsed.quantity,
                        unit: parsed.unit,
                        category: category,
                        orderIndex: index
                    )
                    ingredient.quantityMax = parsed.quantityMax
                    ingredient.preparation = parsed.preparation

                    // Reformat the ingredient text to preserve fractions for imperial, decimals for metric
                    if parsed.quantity != nil || parsed.unit != nil {
                        let formatted = ingredientFormatter.format(ingredient, scaleFactor: 1.0, convertUnits: false)
                        ingredient.originalText = formatted
                    }

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

                // Configure provenance metadata for new recipes
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
                case .generated:
                    provenanceSourceType = .ai
                case .readRecipe:
                    provenanceSourceType = .userCreated
                }

                recipe.provenance = ProvenanceMetadata(
                    sourceType: provenanceSourceType,
                    sourceURL: sourceURL.isEmpty ? nil : sourceURL,
                    sourceAttribution: nil,
                    generation: 0
                )

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

            // DIAGNOSTIC: Count Heritage recipes AFTER save
            let heritageCountAfter = (try? modelContext.fetch(FetchDescriptor<Recipe>()))?.filter { $0.isThemeRecipe }.count ?? 0
            Log.info("🔍 SAVE END - Heritage recipes AFTER save", category: .database, metadata: ["count": heritageCountAfter])

            if heritageCountBefore != heritageCountAfter {
                Log.error("🚨 HERITAGE RECIPES CHANGED DURING SAVE!", category: .database, metadata: [
                    "before": heritageCountBefore,
                    "after": heritageCountAfter,
                    "delta": heritageCountAfter - heritageCountBefore
                ])
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

                    // Show collection picker for new recipes
                    savedRecipe = recipe
                    showCollectionPicker = true
                } else {
                    // For edited recipes, just dismiss
                    dismiss()
                }
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
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(HeirloomColors.tomato)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: HeirloomSpacing.xs) {
                        Text(suggestion.original)
                            .strikethrough()
                            .foregroundStyle(HeirloomColors.secondaryText)
                        Image(systemName: "arrow.right")
                            .font(HeirloomFonts.caption2)
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
                    .font(HeirloomFonts.caption1)
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

    // MARK: - AI Ingredient Parsing

    private func parseIngredientWithAI(at index: Int) {
        // Don't parse empty ingredients
        guard index < ingredientInputs.count else { return }
        let text = ingredientInputs[index].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        // Cancel any existing parsing task for this index
        ingredientParsingTasks[index]?.cancel()

        // Start new parsing task
        let task = Task {
            do {
                Log.debug("Parsing ingredient with AI", category: .ai, metadata: [
                    "index": index,
                    "text": text
                ])

                let parsed = try await aiIngredientParser.parse(text)

                // Check if task was cancelled
                guard !Task.isCancelled else { return }

                // Store parsed result
                await MainActor.run {
                    parsedIngredients[index] = parsed

                    Log.info("Ingredient parsed successfully", category: .ai, metadata: [
                        "index": index,
                        "name": parsed.name,
                        "quantity": parsed.quantity ?? 0,
                        "unit": parsed.unit ?? "",
                        "preparation": parsed.preparation ?? ""
                    ])
                }

                // Track analytics
                analytics.track(event: .featureUsed, properties: [
                    "feature": "ai_ingredient_parsing",
                    "success": true,
                    "has_quantity": parsed.quantity != nil,
                    "has_unit": parsed.unit != nil,
                    "has_preparation": parsed.preparation != nil
                ])

            } catch {
                // Don't interrupt user - just log and fall back to regex parser on save
                Log.warning("AI ingredient parsing failed, will use fallback", category: .ai, metadata: [
                    "error": error.localizedDescription
                ])

                analytics.track(event: .featureUsed, properties: [
                    "feature": "ai_ingredient_parsing",
                    "success": false,
                    "error": error.localizedDescription
                ])
            }
        }

        ingredientParsingTasks[index] = task
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
