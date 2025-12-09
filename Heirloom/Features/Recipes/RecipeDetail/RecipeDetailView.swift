import SwiftUI
import SwiftData

struct RecipeDetailView: View {
    let recipe: Recipe

    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var showEditSheet = false
    @State private var showCookingMode = false
    @State private var showShareSheet = false
    @State private var servingMultiplier: Double = 1.0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Hero Image
                recipeImage
                    .frame(height: 300)
                    .clipped()

                // Content
                VStack(alignment: .leading, spacing: HeirloomSpacing.xl) {
                    // Header Section
                    headerSection

                    // Metadata Section
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
                }
                .padding(HeirloomSpacing.lg)
            }
        }
        .background(HeirloomColors.cream)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            AnalyticsService.shared.trackRecipeViewed(recipe: recipe)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Menu {
                        Button {
                            shareRecipe(as: .text)
                        } label: {
                            Label("As Text", systemImage: "doc.text")
                        }

                        Button {
                            shareRecipe(as: .pdf)
                        } label: {
                            Label("As PDF", systemImage: "doc.richtext")
                        }
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        showEditSheet = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
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
        .fullScreenCover(isPresented: $showCookingMode) {
            CookingModeView(recipe: recipe)
        }
    }

    // MARK: - Image Section
    private var recipeImage: some View {
        AsyncRecipeImage(
            imageFileName: recipe.imageFileName,
            placeholder: recipe.sourceType?.iconName ?? "fork.knife"
        )
    }

    // MARK: - Header Section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
            // Title
            Text(recipe.title)
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
                        recipe.isInShoppingList ? "In List" : "Shopping List",
                        systemImage: recipe.isInShoppingList ? "checkmark.circle.fill" : "cart"
                    )
                    .font(HeirloomFonts.bodyBold)
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
    }

    // MARK: - Metadata Section
    private var metadataSection: some View {
        HStack(spacing: HeirloomSpacing.lg) {
            if let servings = recipe.servings {
                metadataItem(icon: "person.2.fill", label: "Servings", value: servings)
            }

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
            HStack {
                sectionHeader(
                    title: "Ingredients",
                    icon: "list.bullet",
                    count: ingredients.count
                )

                Spacer()

                // Serving size adjuster
                if recipe.servings != nil {
                    servingSizeAdjuster
                }
            }

            VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                ForEach(ingredients.sorted(by: { $0.orderIndex < $1.orderIndex })) { ingredient in
                    ingredientRow(ingredient)
                }
            }
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
        // If multiplier is 1.0, just show original text
        guard servingMultiplier != 1.0 else {
            return ingredient.displayText
        }

        // If ingredient has no quantity, can't scale it
        guard let quantity = ingredient.quantity else {
            return ingredient.displayText
        }

        // Scale the quantity
        let scaledQty = quantity * servingMultiplier
        let scaledQtyMax = ingredient.quantityMax.map { $0 * servingMultiplier }

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
                count: recipe.instructions.count
            )

            VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
                ForEach(Array(recipe.instructions.enumerated()), id: \.offset) { index, instruction in
                    instructionRow(number: index + 1, text: instruction)
                }
            }
            .padding(HeirloomSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.white)
            )
        }
    }

    private func instructionRow(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: HeirloomSpacing.md) {
            ZStack {
                Circle()
                    .fill(HeirloomColors.tomato)
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

    private func shareRecipe(as format: RecipeShareService.ShareFormat) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return
        }

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        RecipeShareService.shared.shareRecipe(recipe, as: format, from: window)

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

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: recipe.isFavorite ? .medium : .light)
        generator.impactOccurred()

        let message = recipe.isFavorite ? "Added to favorites" : "Removed from favorites"
        ToastManager.shared.success(title: message)

        // Track analytics
        AnalyticsService.shared.trackRecipeFavorited(recipe: recipe, isFavorite: recipe.isFavorite)
    }

    private func addToShoppingList() {
        recipe.isInShoppingList.toggle()
        recipe.lastModified = Date()

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: recipe.isInShoppingList ? .medium : .light)
        generator.impactOccurred()

        let message = recipe.isInShoppingList ? "Added to shopping list" : "Removed from shopping list"
        ToastManager.shared.success(title: message)

        // Track analytics
        AnalyticsService.shared.trackShoppingListToggle(recipe: recipe, isInList: recipe.isInShoppingList)
    }

    private func deleteRecipe() {
        isDeleting = true

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)

        // Track analytics before deletion
        AnalyticsService.shared.trackRecipeDeleted(recipeTitle: recipe.title)

        // TODO: Implement delete with model context
        ToastManager.shared.success(title: "Recipe deleted")
        dismiss()
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
