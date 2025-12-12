import SwiftUI
import SwiftData

// MARK: - Ingredient Recipe Data
/// Identifiable wrapper for ingredient recipe data to use with .sheet(item:)
struct IngredientRecipeData: Identifiable {
    let id = UUID()
    let name: String
    let displayText: String
    let recipes: [(recipeId: UUID, recipeTitle: String, sourceIcon: String, ingredientText: String)]
}

struct ShoppingListView: View {
    @Query private var cartRecipes: [ShoppingCartRecipe]

    @Environment(\.modelContext) private var modelContext
    @State private var selectedRecipeIds: Set<UUID> = []
    @State private var selectedIngredientData: IngredientRecipeData?

    var body: some View {
        NavigationStack {
            Group {
                if cartRecipes.isEmpty {
                    emptyState
                } else {
                    shoppingList
                }
            }
            .navigationTitle("Shopping List")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if !cartRecipes.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button {
                                Task {
                                    await exportToReminders()
                                }
                            } label: {
                                Label("Export to Reminders", systemImage: "list.bullet.rectangle")
                            }

                            Divider()

                            Button {
                                checkOffAll()
                            } label: {
                                Label("Check Off All", systemImage: "checkmark.circle")
                            }

                            Button {
                                uncheckAll()
                            } label: {
                                Label("Uncheck All", systemImage: "circle")
                            }

                            Divider()

                            Button(role: .destructive) {
                                clearList()
                            } label: {
                                Label("Clear List", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .sheet(item: $selectedIngredientData) { data in
                IngredientRecipeListView(
                    ingredientName: data.name,
                    displayText: data.displayText,
                    recipeData: data.recipes
                )
            }
        }
    }

    // MARK: - Empty State
    private var emptyState: some View {
        EmptyStateView.emptyShoppingList {
            // Switch to Recipes tab
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let tabBar = windowScene.windows.first?.rootViewController as? UITabBarController {
                tabBar.selectedIndex = 0
            }
        }
    }

    // MARK: - Shopping List
    private var shoppingList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HeirloomSpacing.lg) {
                // Recipe sources
                recipeSources

                // Grouped ingredients
                ForEach(groupedIngredients.keys.sorted(by: { $0.sortOrder < $1.sortOrder }), id: \.self) { category in
                    if let ingredients = groupedIngredients[category] {
                        categorySection(category: category, ingredients: ingredients)
                    }
                }
            }
            .padding(HeirloomSpacing.lg)
        }
        .background(HeirloomColors.appBackground)
    }

    // MARK: - Recipe Sources
    private var recipeSources: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
            Text("From Recipes")
                .font(HeirloomFonts.caption1)
                .foregroundStyle(HeirloomColors.secondaryText)
                .textCase(.uppercase)

            VStack(spacing: HeirloomSpacing.xs) {
                ForEach(cartRecipes) { cartRecipe in
                    Button {
                        toggleRecipeSelection(cartRecipe)
                    } label: {
                        recipeRow(cartRecipe)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .onAppear {
            // Initialize with all recipes selected
            if selectedRecipeIds.isEmpty {
                selectedRecipeIds = Set(cartRecipes.compactMap { $0.recipe?.id })
            }
        }
    }

    private func recipeRow(_ cartRecipe: ShoppingCartRecipe) -> some View {
        guard let recipe = cartRecipe.recipe else {
            return AnyView(EmptyView())
        }

        let isSelected = selectedRecipeIds.contains(recipe.id)

        return AnyView(HStack {
            // Checkbox
            Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                .foregroundStyle(isSelected ? HeirloomColors.tomato : HeirloomColors.warmGray)
                .font(.title3)

            // Recipe icon
            Image(systemName: recipe.sourceType?.iconName ?? "fork.knife")
                .foregroundStyle(isSelected ? HeirloomColors.tomato : HeirloomColors.warmGray)
                .font(.caption)

            // Recipe title (with serving info)
            Text(cartRecipe.displayTitle)
                .font(HeirloomFonts.callout)
                .foregroundStyle(isSelected ? HeirloomColors.primaryText : HeirloomColors.secondaryText)

            Spacer()

            // Ingredient count
            let ingredientCount = cartRecipe.scaledIngredients.count
            Text("\(ingredientCount) items")
                .font(HeirloomFonts.caption1)
                .foregroundStyle(HeirloomColors.secondaryText)
        }
        .padding(HeirloomSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? .white : HeirloomColors.warmGray.opacity(0.1))
        ))
    }

    // MARK: - Category Section
    private func categorySection(category: GroceryCategory, ingredients: [CombinedIngredient]) -> some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: category.iconName)
                        .foregroundStyle(HeirloomColors.tomato)
                        .font(.title3)

                    Text(category.rawValue)
                        .font(HeirloomFonts.title3)
                        .foregroundStyle(HeirloomColors.primaryText)

                    Text("(\(ingredients.count))")
                        .font(HeirloomFonts.body)
                        .foregroundStyle(HeirloomColors.secondaryText)

                    Spacer()
                }

                Text(category.aisleHint)
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(HeirloomColors.secondaryText)
            }

            VStack(spacing: HeirloomSpacing.sm) {
                ForEach(ingredients) { combinedIngredient in
                    ingredientRow(combinedIngredient)
                }
            }
        }
    }

    // MARK: - Ingredient Row
    private func ingredientRow(_ combinedIngredient: CombinedIngredient) -> some View {
        let isAggregated = combinedIngredient.recipeCount > 1

        return Button {
            toggleCombinedIngredient(combinedIngredient)
        } label: {
            HStack(alignment: .top, spacing: HeirloomSpacing.md) {
                // Checkbox - always use circle/checkmark, color indicates aggregated status
                Image(systemName: combinedIngredient.isCheckedOff ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(combinedIngredient.isCheckedOff ? HeirloomColors.familyGreen : (isAggregated ? HeirloomColors.tomato : HeirloomColors.warmGray))

                VStack(alignment: .leading, spacing: 4) {
                    Text(combinedIngredient.displayText)
                        .font(HeirloomFonts.body)
                        .foregroundStyle(
                            combinedIngredient.isCheckedOff ?
                            HeirloomColors.secondaryText :
                            HeirloomColors.primaryText
                        )
                        .strikethrough(combinedIngredient.isCheckedOff)

                    // Show aggregate indicator for items from multiple recipes
                    if isAggregated {
                        Button {
                            // Extract data to avoid SwiftData context issues in sheet
                            let ingredientName = combinedIngredient.scaledIngredients.first?.originalIngredient.name ?? ""
                            let displayText = combinedIngredient.displayText

                            // Build recipe data array
                            var recipeData: [(recipeId: UUID, recipeTitle: String, sourceIcon: String, ingredientText: String)] = []
                            var seenIds = Set<UUID>()

                            for scaledIngredient in combinedIngredient.scaledIngredients {
                                if let recipe = scaledIngredient.originalIngredient.recipe,
                                   !seenIds.contains(recipe.id) {
                                    let data = (
                                        recipeId: recipe.id,
                                        recipeTitle: recipe.title,
                                        sourceIcon: recipe.sourceType?.iconName ?? "fork.knife",
                                        ingredientText: scaledIngredient.fullDisplayString
                                    )
                                    recipeData.append(data)
                                    seenIds.insert(recipe.id)
                                }
                            }

                            // Only show sheet if we successfully extracted data
                            guard !recipeData.isEmpty else {
                                print("⚠️ Failed to extract recipe data - relationships may not be loaded yet")

                                // Ensure sheet is not shown
                                selectedIngredientData = nil

                                // Show user feedback
                                ToastManager.shared.info(
                                    title: "Loading recipe data...",
                                    message: "Please try again"
                                )
                                return
                            }

                            // Create Identifiable data struct for sheet presentation
                            selectedIngredientData = IngredientRecipeData(
                                name: ingredientName,
                                displayText: displayText,
                                recipes: recipeData.sorted { $0.recipeTitle < $1.recipeTitle }
                            )
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "square.stack.3d.up.fill")
                                    .font(.caption2)
                                Text("From \(combinedIngredient.recipeCount) recipes")
                                    .font(HeirloomFonts.caption2)
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                            }
                            .foregroundStyle(HeirloomColors.tomato)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(HeirloomSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isAggregated ? HeirloomColors.tomato.opacity(0.05) : .white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isAggregated ? HeirloomColors.tomato.opacity(0.2) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Grouped Ingredients
    private var groupedIngredients: [GroceryCategory: [CombinedIngredient]] {
        // First, collect all SCALED ingredients with their categories (only from selected recipes)
        var allIngredients: [(ScaledIngredient, GroceryCategory)] = []

        for cartRecipe in cartRecipes {
            guard let recipe = cartRecipe.recipe,
                  selectedRecipeIds.contains(recipe.id) else { continue }

            // Use scaled ingredients from ShoppingCartRecipe
            let scaledIngredients = cartRecipe.scaledIngredients
            for scaledIngredient in scaledIngredients {
                let category = GroceryCategory.categorize(scaledIngredient.originalIngredient.name)
                allIngredients.append((scaledIngredient, category))
            }
        }

        // Combine ingredients with the same name
        var combined: [String: (category: GroceryCategory, scaledIngredients: [ScaledIngredient])] = [:]
        for (scaledIngredient, category) in allIngredients {
            let key = scaledIngredient.originalIngredient.name.lowercased().trimmingCharacters(in: .whitespaces)
            if combined[key] == nil {
                combined[key] = (category: category, scaledIngredients: [])
            }
            combined[key]?.scaledIngredients.append(scaledIngredient)
        }

        // Group by category
        var grouped: [GroceryCategory: [CombinedIngredient]] = [:]
        for (_, value) in combined {
            let combinedIngredient = CombinedIngredient(scaledIngredients: value.scaledIngredients, category: value.category)
            if grouped[value.category] == nil {
                grouped[value.category] = []
            }
            grouped[value.category]?.append(combinedIngredient)
        }

        return grouped
    }

    // MARK: - Combined Ingredient Helper
    struct CombinedIngredient: Identifiable {
        let id = UUID()
        let scaledIngredients: [ScaledIngredient]
        let category: GroceryCategory

        var displayText: String {
            if scaledIngredients.count == 1 {
                return scaledIngredients[0].fullDisplayString
            }

            // Try to combine quantities if they have the same unit
            let firstIngredient = scaledIngredients[0].originalIngredient
            let allHaveQuantities = scaledIngredients.allSatisfy { $0.scaledQuantity != nil }
            let allHaveSameUnit = Set(scaledIngredients.compactMap { $0.originalIngredient.unit }).count <= 1

            if allHaveQuantities && allHaveSameUnit {
                // Calculate total SCALED quantity
                let totalQty = scaledIngredients.compactMap { $0.scaledQuantity }.reduce(0.0, +)
                let unit = firstIngredient.unit ?? ""
                let name = firstIngredient.name

                // Format the quantity
                let qtyString = formatQuantity(totalQty)

                // Build display string
                var parts: [String] = [qtyString]
                if !unit.isEmpty {
                    parts.append(unit)
                }
                parts.append(name)

                if let prep = firstIngredient.preparation {
                    parts.append("(\(prep))")
                }

                return parts.joined(separator: " ")
            } else {
                // Fallback: show count multiplier
                return "\(scaledIngredients.count)× \(scaledIngredients[0].fullDisplayString)"
            }
        }

        private func formatQuantity(_ value: Double) -> String {
            // Handle zero or very small values
            if value < 0.05 {
                return ""
            }

            // Convert decimals to fractions for better display
            let fractions: [(Double, String)] = [
                (0.125, "⅛"), (0.25, "¼"), (0.333, "⅓"),
                (0.375, "⅜"), (0.5, "½"), (0.625, "⅝"),
                (0.667, "⅔"), (0.75, "¾"), (0.875, "⅞")
            ]

            let whole = Int(value)
            let fraction = value - Double(whole)

            // If it's essentially a whole number
            if fraction < 0.05 {
                return "\(whole)"
            }

            // Try to match common fractions
            for (threshold, symbol) in fractions {
                if abs(fraction - threshold) < 0.05 {
                    return whole > 0 ? "\(whole) \(symbol)" : symbol
                }
            }

            // Fallback: use decimal notation for odd values
            // Round to 1 decimal place
            let rounded = round(value * 10) / 10
            if rounded == Double(Int(rounded)) {
                return "\(Int(rounded))"
            }
            return String(format: "%.1f", rounded)
        }

        var isCheckedOff: Bool {
            scaledIngredients.allSatisfy { $0.originalIngredient.isCheckedOff }
        }

        var recipeCount: Int {
            scaledIngredients.count
        }
    }

    // MARK: - Actions
    private func exportToReminders() async {
        // Collect all unchecked items from selected recipes
        var items: [ShoppingListItem] = []

        for (_, combinedIngredients) in groupedIngredients {
            for combinedIngredient in combinedIngredients where !combinedIngredient.isCheckedOff {
                items.append(ShoppingListItem(
                    displayText: combinedIngredient.displayText,
                    recipeCount: combinedIngredient.recipeCount,
                    isAggregated: combinedIngredient.recipeCount > 1
                ))
            }
        }

        guard !items.isEmpty else {
            await MainActor.run {
                ToastManager.shared.info(
                    title: "Nothing to export",
                    message: "All items are checked off"
                )
            }
            return
        }

        do {
            try await RemindersService.shared.exportToReminders(items: items)
            await MainActor.run {
                ToastManager.shared.success(
                    title: "Exported to Reminders",
                    message: "Added \(items.count) items to 'Heirloom Shopping' list"
                )
            }
        } catch {
            await MainActor.run {
                ToastManager.shared.error(
                    title: "Export failed",
                    message: error.localizedDescription
                )
            }
        }
    }

    private func toggleCombinedIngredient(_ combinedIngredient: CombinedIngredient) {
        // Toggle all ORIGINAL ingredients in the combined group
        let newState = !combinedIngredient.isCheckedOff
        for scaledIngredient in combinedIngredient.scaledIngredients {
            scaledIngredient.originalIngredient.isCheckedOff = newState
        }
        try? modelContext.save()
    }

    private func toggleRecipeSelection(_ cartRecipe: ShoppingCartRecipe) {
        guard let recipeId = cartRecipe.recipe?.id else { return }
        if selectedRecipeIds.contains(recipeId) {
            selectedRecipeIds.remove(recipeId)
        } else {
            selectedRecipeIds.insert(recipeId)
        }
    }

    private func checkOffAll() {
        for cartRecipe in cartRecipes {
            guard let ingredients = cartRecipe.recipe?.ingredients else { continue }
            for ingredient in ingredients {
                ingredient.isCheckedOff = true
            }
        }
        try? modelContext.save()
    }

    private func uncheckAll() {
        for cartRecipe in cartRecipes {
            guard let ingredients = cartRecipe.recipe?.ingredients else { continue }
            for ingredient in ingredients {
                ingredient.isCheckedOff = false
            }
        }
        try? modelContext.save()
    }

    private func clearList() {
        for cartRecipe in cartRecipes {
            // Uncheck all ingredients in the recipe
            if let ingredients = cartRecipe.recipe?.ingredients {
                for ingredient in ingredients {
                    ingredient.isCheckedOff = false
                }
            }

            // Update recipe flag
            cartRecipe.recipe?.isInShoppingList = false

            // Delete the ShoppingCartRecipe
            modelContext.delete(cartRecipe)
        }
        try? modelContext.save()
    }
}

// MARK: - Ingredient Recipe List View

struct IngredientRecipeListView: View {
    let ingredientName: String
    let displayText: String
    let recipeData: [(recipeId: UUID, recipeTitle: String, sourceIcon: String, ingredientText: String)]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            if recipeData.isEmpty {
                // Fallback empty state (shouldn't normally happen)
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundStyle(HeirloomColors.warmGray)

                    Text("No recipe data available")
                        .font(HeirloomFonts.title3)
                        .foregroundStyle(HeirloomColors.primaryText)

                    Text("Please try again")
                        .font(HeirloomFonts.body)
                        .foregroundStyle(HeirloomColors.secondaryText)

                    Button("Close") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                }
                .navigationTitle("Recipe Sources")
                .navigationBarTitleDisplayMode(.inline)
            } else {
                List {
                    Section {
                        Text(displayText)
                            .font(HeirloomFonts.body)
                            .foregroundStyle(HeirloomColors.primaryText)
                    } header: {
                        Text("Ingredient")
                    }

                    Section {
                        ForEach(recipeData, id: \.recipeId) { data in
                            HStack {
                                Image(systemName: data.sourceIcon)
                                    .foregroundStyle(HeirloomColors.tomato)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(data.recipeTitle)
                                        .font(HeirloomFonts.body)
                                        .foregroundStyle(HeirloomColors.primaryText)

                                    Text(data.ingredientText)
                                        .font(HeirloomFonts.caption1)
                                        .foregroundStyle(HeirloomColors.secondaryText)
                                }
                            }
                        }
                    } header: {
                        Text("From \(recipeData.count) \(recipeData.count == 1 ? "Recipe" : "Recipes")")
                    }
                }
                .navigationTitle("Recipe Sources")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Preview
#Preview("With Items") {
    let container = try! ModelContainer(for: Recipe.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let context = container.mainContext

    // Create sample recipe in shopping list
    let recipe = Recipe.example
    recipe.isInShoppingList = true
    context.insert(recipe)

    // Create ingredients
    let ingredientTexts = [
        "2 1/4 cups all-purpose flour",
        "1 teaspoon baking soda",
        "1 cup butter",
        "2 cups chocolate chips"
    ]

    for (index, text) in ingredientTexts.enumerated() {
        let ingredient = Ingredient(
            originalText: text,
            name: text,
            orderIndex: index
        )
        ingredient.recipe = recipe
        context.insert(ingredient)
    }

    try? context.save()

    return ShoppingListView()
        .modelContainer(container)
}

#Preview("Empty") {
    ShoppingListView()
        .modelContainer(for: Recipe.self, inMemory: true)
}
