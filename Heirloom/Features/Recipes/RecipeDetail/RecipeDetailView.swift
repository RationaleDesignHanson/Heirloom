import SwiftUI
import SwiftData
import FirebaseFirestore
import FirebaseAuth

struct RecipeDetailView: View {
    let recipe: Recipe

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var showEditSheet = false
    @State private var showCookingMode = false
    @State private var showShareSheet = false
    @State private var showTagCollectionPicker = false
    @State private var showCardPersonalization = false
    @State private var showCloudKitShare = false
    @State private var showHeirloomExplanation = false
    @State private var servingMultiplier: Double = 1.0
    @State private var targetServings: Int = 0
    @State private var showScalingExplanation = false
    @State private var showComments = false
    @State private var showCardBack = false
    @State private var selectedCollection: RecipeCollection?

    // Version selector
    @StateObject private var versionViewModel = RecipeVersionSelectorViewModel()
    @State private var selectedVersion: RecipeLineageVersion?
    @State private var isDiffExpanded = false

    // Notification service
    @EnvironmentObject private var notificationService: FirebaseNotificationService

    // MARK: - Computed Display Properties

    /// The title to display (from selected version or base recipe)
    private var displayTitle: String {
        selectedVersion?.title ?? recipe.title
    }

    /// The ingredients to display (always show current recipe's ingredients)
    private var displayIngredients: [Ingredient]? {
        recipe.ingredients
    }

    /// The instructions to display (always show current recipe's instructions)
    private var displayInstructions: [String] {
        recipe.instructions
    }

    /// The image filename to display (from selected version or base recipe)
    private var displayImageFileName: String? {
        if let selected = selectedVersion {
            // If viewing current version's recipe, use its image
            if let versionRecipe = selected.recipe {
                return versionRecipe.imageFileName
            }
            // If viewing remote version, try to get image from recipe data
            if let recipeData = selected.recipeData,
               let imageFileName = recipeData["imageFileName"] as? String {
                return imageFileName
            }
        }
        // Fall back to base recipe's image
        return recipe.imageFileName
    }

    /// Badge text for version/generation indicator
    private var versionBadgeText: String? {
        let versionCount = versionViewModel.versions.count

        // If we have multiple versions, show the count
        if versionCount > 1 {
            return "\(versionCount) versions"
        }

        // Otherwise, fall back to generation-based badge
        guard let provenance = recipe.provenance else { return nil }
        if provenance.isOriginal {
            return "Original"
        } else if provenance.generation > 0 {
            return "Gen \(provenance.generation)"
        }

        return nil
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

        // Check ingredients
        if let currentRecipe = selected.recipe,
           let currentIngredients = currentRecipe.ingredients {
            let currentTexts = currentIngredients.map { $0.originalText }
            let originalTexts: [String]
            if let originalRecipe = original.recipe, let ingredients = originalRecipe.ingredients {
                originalTexts = ingredients.map { $0.originalText }
            } else if let data = original.recipeData,
                      let ingredientsData = data["ingredients"] as? [[String: Any]] {
                originalTexts = ingredientsData.compactMap { $0["originalText"] as? String }
            } else {
                originalTexts = []
            }

            let addedCount = currentTexts.filter { !originalTexts.contains($0) }.count
            let removedCount = originalTexts.filter { !currentTexts.contains($0) }.count
            let modifiedCount = addedCount + removedCount

            if modifiedCount > 0 {
                changes.append("\(modifiedCount) ingredient\(modifiedCount == 1 ? "" : "s") modified")
            }
        }

        // Check instructions
        if let currentRecipe = selected.recipe {
            let currentInstructions = currentRecipe.instructions
            let originalInstructions: [String]
            if let originalRecipe = original.recipe {
                originalInstructions = originalRecipe.instructions
            } else if let data = original.recipeData,
                      let instructions = data["instructions"] as? [String] {
                originalInstructions = instructions
            } else {
                originalInstructions = []
            }

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

        return changes.isEmpty ? nil : changes.joined(separator: ", ")
    }

    var body: some View {
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
                        originalVersion: versionViewModel.versions.first(where: { $0.generation == 0 })
                    )
                    .padding(.horizontal, HeirloomSpacing.lg)

                    // Header Section
                    headerSection

                    // Tags and Collections Section
                    if (recipe.tags != nil && !recipe.tags!.isEmpty) || (recipe.collections != nil && !recipe.collections!.isEmpty) {
                        tagsAndCollectionsSection
                    }

                    // Metadata Section (includes serving selector dropdown)
                    metadataSection

                    // Start Cooking Button
                    if !recipe.instructions.isEmpty {
                        startCookingButton
                    }

                    // Ingredients Section
                    if let ingredients = recipe.ingredients, !ingredients.isEmpty {
                        ingredientsSection(ingredients)
                    } else {
                        // Debug: Show why ingredients aren't showing
                        VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
                            sectionHeader(
                                title: "Ingredients",
                                icon: "list.bullet",
                                count: 0
                            )

                            Text("No ingredients found. Recipe.ingredients is \(recipe.ingredients == nil ? "nil" : "empty array")")
                                .font(HeirloomFonts.caption1)
                                .foregroundStyle(.red)
                                .padding(HeirloomSpacing.md)
                        }
                    }

                    // Instructions Section
                    if !recipe.instructions.isEmpty {
                        instructionsSection
                    }

                    // Notes Section
                    if let notes = recipe.notes {
                        notesSection(notes)
                    }

                    // Source Section
                    sourceSection

                    // Comments Section
                    commentsSection
                }
                .padding(HeirloomSpacing.lg)
            }
        }
        .background(HeirloomColors.cream)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Initialize target servings to recipe's base serving count
            if targetServings == 0 {
                targetServings = recipe.parsedServingCount
            }

            // Track last viewed timestamp
            recipe.lastViewed = Date()
            try? modelContext.save()

            AnalyticsService.shared.trackRecipeViewed(recipe: recipe)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Menu {
                        Button {
                            showCloudKitShare = true
                        } label: {
                            Label("Share Recipe", systemImage: "square.and.arrow.up")
                        }
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        showEditSheet = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }

                    Button {
                        showTagCollectionPicker = true
                    } label: {
                        Label("Organize", systemImage: "tag")
                    }

                    Button {
                        showCardPersonalization = true
                    } label: {
                        Label("Personalize Card", systemImage: "paintbrush.fill")
                    }

                    Button {
                        duplicateRecipe()
                    } label: {
                        Label("Duplicate", systemImage: "doc.on.doc")
                    }

                    Divider()

                    Button {
                        showComments = true
                    } label: {
                        let commentCount = recipe.comments?.count ?? 0
                        Label("Comments (\(commentCount))", systemImage: "bubble.left.fill")
                    }

                    Button {
                        showCardBack = true
                    } label: {
                        Label("Customize Card Back", systemImage: "rectangle.portrait.on.rectangle.portrait")
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
            Text("This action cannot be undone.")
        }
        .sheet(isPresented: $showEditSheet) {
            RecipeEditorView(recipe: recipe)
        }
        .sheet(isPresented: $showTagCollectionPicker) {
            TagCollectionPickerView(recipe: recipe)
        }
        .sheet(isPresented: $showCardPersonalization) {
            CardPersonalizationView(recipe: recipe)
        }
        .sheet(isPresented: $showCloudKitShare) {
            RecipeShareSheet(recipe: recipe)
        }
        .sheet(isPresented: $showComments) {
            NavigationStack {
                RecipeCommentListView(recipe: recipe)
            }
        }
        .sheet(isPresented: $showCardBack) {
            CardBackEditorView(recipe: recipe)
        }
        .sheet(isPresented: $showHeirloomExplanation) {
            HeirloomShareExplanationView()
        }
        .fullScreenCover(isPresented: $showCookingMode) {
            CookingModeView(recipe: recipe)
        }
        .task {
            // Load versions when view appears
            await versionViewModel.loadVersions(for: recipe, context: modelContext)

            // Mark notifications as read for this recipe
            do {
                try await notificationService.markAllAsRead(for: recipe.id)
                print("✅ [Notifications] Marked all notifications as read for recipe: \(recipe.title)")
            } catch {
                print("❌ [Notifications] Failed to mark as read: \(error)")
            }
        }
        .onChange(of: selectedVersion) { oldValue, newValue in
            // Save the selected version ID to recipe for persistence
            if let newVersion = newValue, let recipeId = newVersion.recipe?.id {
                recipe.lastViewedVersionId = recipeId
                try? modelContext.save()
                print("✅ [VersionSelector] Saved last viewed version: \(newVersion.displayName)")
            }
        }
    }

    // MARK: - Image Section
    private var recipeImage: some View {
        AsyncRecipeImage(
            imageFileName: displayImageFileName,
            placeholder: recipe.sourceType?.iconName ?? "fork.knife"
        )
    }

    // MARK: - Header Section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
            // Title
            Text(displayTitle)
                .font(HeirloomFonts.title1)
                .foregroundStyle(HeirloomColors.charcoal)

            // Source Badge
            HStack(spacing: HeirloomSpacing.xs) {
                Image(systemName: recipe.sourceType?.iconName ?? "square.and.pencil")
                    .font(.caption)
                Text(recipe.sourceDisplayName)
                    .font(HeirloomFonts.caption1)
            }
            .foregroundStyle(HeirloomColors.charcoal.opacity(0.6))

            // Action Buttons
            HStack(spacing: HeirloomSpacing.md) {
                // Favorite Button
                Button {
                    toggleFavorite()
                } label: {
                    Label(
                        recipe.isFavorite ? "Favorited" : "Favorite",
                        systemImage: recipe.isFavorite ? "heart.fill" : "heart"
                    )
                    .font(HeirloomFonts.bodyBold)
                }
                .buttonStyle(SecondaryButtonStyle())

                // Add to Shopping List Button
                Button {
                    addToShoppingList()
                } label: {
                    Label(
                        isInShoppingCart ? "In List" : "Shopping List",
                        systemImage: isInShoppingCart ? "checkmark.circle.fill" : "cart"
                    )
                    .font(HeirloomFonts.bodyBold)
                }
                .buttonStyle(SecondaryButtonStyle())
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
                                            .font(.caption2)
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
                                                    .font(.title3)
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

            if let prepTime = recipe.prepTime {
                metadataItem(icon: "clock.fill", label: "Prep", value: prepTime)
            }

            if let cookTime = recipe.cookTime {
                metadataItem(icon: "flame.fill", label: "Cook", value: cookTime)
            }
        }
        .padding(HeirloomSpacing.md)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white)
                .shadow(color: HeirloomColors.cardShadow, radius: 4, x: 0, y: 2)
        )
    }

    private var servingsMetadataItem: some View {
        VStack(spacing: 4) {
            Image(systemName: "person.2.fill")
                .font(.title3)
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
                                AnalyticsService.shared.track(event: .recipeScaled, properties: [
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
                        AnalyticsService.shared.track(event: .scalingExplanationViewed, properties: [
                            "recipe_title": recipe.title,
                            "category": recipe.category?.rawValue ?? "unknown"
                        ])
                    } label: {
                        Label("Why can't I scale this?", systemImage: "info.circle")
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text("\(targetServings) \(servingUnitText(targetServings))")
                        .font(HeirloomFonts.bodyBold)
                        .foregroundStyle(HeirloomColors.charcoal)

                    Image(systemName: recipe.isScalingAllowed ? "chevron.down" : "lock.fill")
                        .font(.caption)
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
        if let servings = recipe.servings {
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
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
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
            AnalyticsService.shared.track(event: .cookingStarted, properties: [
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
            .foregroundStyle(.white)
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
                RoundedRectangle(cornerRadius: 12)
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
                    .font(.title3)
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
                    .font(.title3)
                    .foregroundStyle(HeirloomColors.tomato)
            }
            .disabled(servingMultiplier >= 10.0)
        }
    }

    private var scaledServings: String {
        guard let servings = recipe.servings else { return "1" }

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
                .font(.caption)
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

        for (decimalValue, fractionSymbol) in fractions {
            if abs(fractionalPart - decimalValue) < 0.01 {
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
                RoundedRectangle(cornerRadius: 12)
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
                    .foregroundStyle(.white)
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
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.white)
                )
        }
    }

    // MARK: - Source Section
    private var sourceSection: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
            // Provenance information
            if let provenance = recipe.provenance {
                HStack(spacing: HeirloomSpacing.sm) {
                    Image(systemName: provenance.sourceType.iconName)
                        .foregroundStyle(HeirloomColors.tomato)
                        .font(.callout)

                    Text(provenance.displaySource)
                        .font(HeirloomFonts.callout)
                        .foregroundStyle(HeirloomColors.charcoal.opacity(0.8))

                    // Version/Generation badge
                    if let badgeText = versionBadgeText {
                        Text(badgeText)
                            .font(HeirloomFonts.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(versionViewModel.versions.count > 1 ? HeirloomColors.familyGreen : (provenance.isOriginal ? HeirloomColors.tomato : HeirloomColors.familyGreen))
                            )
                    }
                }
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
        }
        .padding(.top, HeirloomSpacing.lg)
    }

    // MARK: - Comments Section
    private var commentsSection: some View {
        let comments = recipe.comments ?? []
        let commentCount = comments.count
        let topComments = CommentService.shared.getTopComments(for: recipe, limit: 3)

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
                            .font(.caption)
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
                    RoundedRectangle(cornerRadius: 12)
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
                                .font(.caption)
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
                    RoundedRectangle(cornerRadius: 12)
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
                            .font(.caption2)
                        Text(String(format: "%.0f%%", abs(sentiment) * 100))
                            .font(.caption2)
                    }
                    .foregroundStyle(sentimentColor(sentiment))
                }

                Spacer()

                if comment.upvotes > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.caption2)
                        Text("\(comment.upvotes)")
                            .font(.caption2)
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

    // MARK: - Actions

    private func shareRecipe(as format: RecipeExportService.ShareFormat) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return
        }

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        RecipeExportService.shared.shareRecipe(recipe, as: format, from: window)

        // Track analytics
        AnalyticsService.shared.track(event: .recipeShared, properties: [
            "recipe_id": recipe.id.uuidString,
            "recipe_title": recipe.title,
            "share_format": String(describing: format)
        ])
    }

    private func toggleFavorite() {
        recipe.isFavorite.toggle()
        recipe.lastModified = Date()

        print("❤️ [Favorite] Toggling favorite for '\(recipe.title)' to \(recipe.isFavorite)")
        print("🔧 [Favorite] Backend: Firebase, isFirebaseActive: \(BackendConfig.shared.isFirebaseActive)")

        do {
            try modelContext.save()
            print("💾 [Favorite] Local save successful")

            // Sync favorite status to Firebase
            if BackendConfig.shared.isFirebaseActive {
                print("🔄 [Favorite] Firebase is active, starting upload...")
                Task {
                    do {
                        try await FirebaseSyncService.shared.uploadRecipe(recipe)
                        print("✅ Favorite status synced to Firebase")
                    } catch {
                        print("⚠️ Failed to sync favorite status: \(error.localizedDescription)")
                    }
                }
            } else {
                print("⏭️ [Favorite] Firebase not active, skipping upload")
            }
        } catch {
            print("❌ [Favorite] Local save failed: \(error.localizedDescription)")
            ToastManager.shared.error(
                title: "Failed to update favorite",
                message: error.localizedDescription
            )
            return
        }

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: recipe.isFavorite ? .medium : .light)
        generator.impactOccurred()

        let message = recipe.isFavorite ? "Added to favorites" : "Removed from favorites"
        ToastManager.shared.success(title: message)

        // TODO: Add VoiceOver announcement once AccessibilityAnnouncementService is added to Xcode project
        // if recipe.isFavorite {
        //     AccessibilityAnnouncementService.shared.announceRecipeFavorited(title: recipe.title)
        // } else {
        //     AccessibilityAnnouncementService.shared.announceRecipeUnfavorited(title: recipe.title)
        // }

        // Track analytics
        AnalyticsService.shared.trackRecipeFavorited(recipe: recipe, isFavorite: recipe.isFavorite)
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

                ToastManager.shared.success(title: "Removed from shopping list")

                // Track analytics
                AnalyticsService.shared.trackShoppingListToggle(recipe: recipe, isInList: false)
            } catch {
                ToastManager.shared.error(
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
                ToastManager.shared.success(title: "Added to shopping list\(servingText)")

                // Track analytics
                AnalyticsService.shared.trackShoppingListToggle(recipe: recipe, isInList: true)

                // Track scaled recipe added to cart
                if targetServings != recipe.parsedServingCount {
                    AnalyticsService.shared.track(event: .scaledRecipeAddedToCart, properties: [
                        "recipe_title": recipe.title,
                        "category": recipe.category?.rawValue ?? "unknown",
                        "original_servings": recipe.parsedServingCount,
                        "target_servings": targetServings,
                        "scale_factor": Double(targetServings) / Double(recipe.parsedServingCount)
                    ])
                }
            } catch {
                ToastManager.shared.error(
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
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)

        // Store title and ID before deletion
        let recipeTitle = recipe.title
        let recipeId = recipe.id.uuidString

        // Track analytics before deletion
        AnalyticsService.shared.trackRecipeDeleted(recipeTitle: recipeTitle)

        // Delete from context
        modelContext.delete(recipe)

        do {
            try modelContext.save()

            // Delete from Firebase if active
            if BackendConfig.shared.isFirebaseActive {
                Task {
                    do {
                        // Delete recipe document from Firestore
                        let db = FirebaseFirestore.Firestore.firestore()
                        guard let userId = FirebaseAuth.Auth.auth().currentUser?.uid else { return }
                        try await db.collection("users/\(userId)/recipes").document(recipeId).delete()
                        print("✅ Recipe deleted from Firestore")

                        // Delete recipe image from Firebase Storage
                        if let recipeUUID = UUID(uuidString: recipeId) {
                            do {
                                try await FirebaseSyncService.shared.deleteImage(for: recipeUUID)
                                print("✅ Recipe image deleted from Firebase Storage")
                            } catch {
                                print("⚠️ Failed to delete image from Firebase Storage: \(error.localizedDescription)")
                            }
                        }
                    } catch {
                        print("⚠️ Failed to delete recipe from Firebase: \(error.localizedDescription)")
                        // Don't fail the deletion - local deletion succeeded
                    }
                }
            }

            // Success haptic
            let successGenerator = UINotificationFeedbackGenerator()
            successGenerator.notificationOccurred(.success)

            ToastManager.shared.success(title: "Recipe deleted")

            // TODO: Add VoiceOver announcement once AccessibilityAnnouncementService is added to Xcode project
            // AccessibilityAnnouncementService.shared.announceRecipeDeleted(title: recipeTitle)

            dismiss()
        } catch {
            isDeleting = false
            ToastManager.shared.error(
                title: "Failed to delete recipe",
                message: error.localizedDescription
            )
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

            ToastManager.shared.success(title: "Recipe duplicated")

            // Track analytics
            AnalyticsService.shared.track(event: .featureUsed, properties: [
                "feature": "recipe_duplicated",
                "original_title": recipe.title,
                "has_ingredients": recipe.ingredients?.isEmpty == false,
                "has_instructions": !recipe.instructions.isEmpty
            ])

            // Navigate to the duplicate
            dismiss()
        } catch {
            ToastManager.shared.error(
                title: "Failed to duplicate recipe",
                message: error.localizedDescription
            )
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
                            RoundedRectangle(cornerRadius: 12)
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
                .font(.title3)
                .foregroundStyle(HeirloomColors.familyGreen)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
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
