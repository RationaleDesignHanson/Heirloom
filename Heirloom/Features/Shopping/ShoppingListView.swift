import SwiftUI
import SwiftData

struct ShoppingListView: View {
    @Query(filter: #Predicate<Recipe> { recipe in
        recipe.isInShoppingList == true
    })
    private var recipesInList: [Recipe]

    @Environment(\.modelContext) private var modelContext
    @State private var selectedRecipeIds: Set<UUID> = []
    @State private var showRecipeList = false
    @State private var selectedCombinedIngredient: CombinedIngredient?

    var body: some View {
        NavigationStack {
            Group {
                if recipesInList.isEmpty {
                    emptyState
                } else {
                    shoppingList
                }
            }
            .navigationTitle("Shopping List")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if !recipesInList.isEmpty {
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
            .sheet(isPresented: $showRecipeList) {
                if let combinedIngredient = selectedCombinedIngredient {
                    IngredientRecipeListView(combinedIngredient: combinedIngredient)
                }
            }
        }
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: HeirloomSpacing.lg) {
            Image(systemName: "cart")
                .font(.system(size: 60))
                .foregroundStyle(HeirloomColors.warmGray)

            VStack(spacing: HeirloomSpacing.sm) {
                Text("No Items Yet")
                    .font(HeirloomFonts.title2)
                    .foregroundStyle(HeirloomColors.primaryText)

                Text("Add recipes to your shopping list to see their ingredients here")
                    .font(HeirloomFonts.body)
                    .foregroundStyle(HeirloomColors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, HeirloomSpacing.xl)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(HeirloomColors.appBackground)
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
                ForEach(recipesInList) { recipe in
                    Button {
                        toggleRecipeSelection(recipe)
                    } label: {
                        recipeRow(recipe)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .onAppear {
            // Initialize with all recipes selected
            if selectedRecipeIds.isEmpty {
                selectedRecipeIds = Set(recipesInList.map { $0.id })
            }
        }
    }

    private func recipeRow(_ recipe: Recipe) -> some View {
        let isSelected = selectedRecipeIds.contains(recipe.id)

        return HStack {
            // Checkbox
            Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                .foregroundStyle(isSelected ? HeirloomColors.tomato : HeirloomColors.warmGray)
                .font(.title3)

            // Recipe icon
            Image(systemName: recipe.sourceType?.iconName ?? "fork.knife")
                .foregroundStyle(isSelected ? HeirloomColors.tomato : HeirloomColors.warmGray)
                .font(.caption)

            // Recipe title
            Text(recipe.title)
                .font(HeirloomFonts.callout)
                .foregroundStyle(isSelected ? HeirloomColors.primaryText : HeirloomColors.secondaryText)

            Spacer()

            // Ingredient count
            if let count = recipe.ingredients?.count {
                Text("\(count) items")
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(HeirloomColors.secondaryText)
            }
        }
        .padding(HeirloomSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? .white : HeirloomColors.warmGray.opacity(0.1))
        )
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
                            selectedCombinedIngredient = combinedIngredient
                            showRecipeList = true
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
        // First, collect all ingredients with their categories (only from selected recipes)
        var allIngredients: [(Ingredient, GroceryCategory)] = []

        for recipe in recipesInList where selectedRecipeIds.contains(recipe.id) {
            guard let ingredients = recipe.ingredients else { continue }
            for ingredient in ingredients {
                let category = GroceryCategory.categorize(ingredient.name)
                allIngredients.append((ingredient, category))
            }
        }

        // Combine ingredients with the same name
        var combined: [String: (category: GroceryCategory, ingredients: [Ingredient])] = [:]
        for (ingredient, category) in allIngredients {
            let key = ingredient.name.lowercased().trimmingCharacters(in: .whitespaces)
            if combined[key] == nil {
                combined[key] = (category: category, ingredients: [])
            }
            combined[key]?.ingredients.append(ingredient)
        }

        // Group by category
        var grouped: [GroceryCategory: [CombinedIngredient]] = [:]
        for (_, value) in combined {
            let combinedIngredient = CombinedIngredient(ingredients: value.ingredients, category: value.category)
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
        let ingredients: [Ingredient]
        let category: GroceryCategory

        var displayText: String {
            if ingredients.count == 1 {
                return ingredients[0].displayText
            }

            // Try to combine quantities if they have the same unit
            let firstIngredient = ingredients[0]
            let allHaveQuantities = ingredients.allSatisfy { $0.quantity != nil }
            let allHaveSameUnit = Set(ingredients.compactMap { $0.unit }).count <= 1

            if allHaveQuantities && allHaveSameUnit {
                // Calculate total quantity
                let totalQty = ingredients.compactMap { $0.quantity }.reduce(0.0, +)
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
                return "\(ingredients.count)× \(firstIngredient.displayText)"
            }
        }

        private func formatQuantity(_ value: Double) -> String {
            // Convert decimals to fractions for better display
            let fractions: [(Double, String)] = [
                (0.125, "⅛"), (0.25, "¼"), (0.333, "⅓"),
                (0.375, "⅜"), (0.5, "½"), (0.625, "⅝"),
                (0.666, "⅔"), (0.75, "¾"), (0.875, "⅞")
            ]

            let wholePart = Int(value)
            let fractionalPart = value - Double(wholePart)

            // Check if it matches a common fraction
            for (decimalValue, fractionSymbol) in fractions {
                if abs(fractionalPart - decimalValue) < 0.01 {
                    if wholePart > 0 {
                        return "\(wholePart) \(fractionSymbol)"
                    } else {
                        return fractionSymbol
                    }
                }
            }

            // If it's a whole number, return it as an integer
            if fractionalPart < 0.01 {
                return "\(wholePart)"
            }

            // Otherwise return as decimal
            return String(format: "%.1f", value)
        }

        var isCheckedOff: Bool {
            ingredients.allSatisfy { $0.isCheckedOff }
        }

        var recipeCount: Int {
            ingredients.count
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
        // Toggle all ingredients in the combined group
        let newState = !combinedIngredient.isCheckedOff
        for ingredient in combinedIngredient.ingredients {
            ingredient.isCheckedOff = newState
        }
        try? modelContext.save()
    }

    private func toggleRecipeSelection(_ recipe: Recipe) {
        if selectedRecipeIds.contains(recipe.id) {
            selectedRecipeIds.remove(recipe.id)
        } else {
            selectedRecipeIds.insert(recipe.id)
        }
    }

    private func checkOffAll() {
        for recipe in recipesInList {
            guard let ingredients = recipe.ingredients else { continue }
            for ingredient in ingredients {
                ingredient.isCheckedOff = true
            }
        }
        try? modelContext.save()
    }

    private func uncheckAll() {
        for recipe in recipesInList {
            guard let ingredients = recipe.ingredients else { continue }
            for ingredient in ingredients {
                ingredient.isCheckedOff = false
            }
        }
        try? modelContext.save()
    }

    private func clearList() {
        for recipe in recipesInList {
            recipe.isInShoppingList = false

            // Uncheck all ingredients
            guard let ingredients = recipe.ingredients else { continue }
            for ingredient in ingredients {
                ingredient.isCheckedOff = false
            }
        }
        try? modelContext.save()
    }
}

// MARK: - Ingredient Recipe List View

struct IngredientRecipeListView: View {
    let combinedIngredient: ShoppingListView.CombinedIngredient
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(combinedIngredient.displayText)
                        .font(HeirloomFonts.body)
                        .foregroundStyle(HeirloomColors.primaryText)
                } header: {
                    Text("Ingredient")
                }

                Section {
                    ForEach(recipeList, id: \.id) { recipe in
                        HStack {
                            Image(systemName: recipe.sourceType?.iconName ?? "fork.knife")
                                .foregroundStyle(HeirloomColors.tomato)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(recipe.title)
                                    .font(HeirloomFonts.body)
                                    .foregroundStyle(HeirloomColors.primaryText)

                                if let ingredientText = ingredientTextForRecipe(recipe) {
                                    Text(ingredientText)
                                        .font(HeirloomFonts.caption1)
                                        .foregroundStyle(HeirloomColors.secondaryText)
                                }
                            }
                        }
                    }
                } header: {
                    Text("From \(recipeList.count) \(recipeList.count == 1 ? "Recipe" : "Recipes")")
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

    private var recipeList: [Recipe] {
        // Get unique recipes from the combined ingredient
        var uniqueRecipes: [Recipe] = []
        var seenIds = Set<UUID>()

        for ingredient in combinedIngredient.ingredients {
            if let recipe = ingredient.recipe, !seenIds.contains(recipe.id) {
                uniqueRecipes.append(recipe)
                seenIds.insert(recipe.id)
            }
        }

        return uniqueRecipes.sorted { $0.title < $1.title }
    }

    private func ingredientTextForRecipe(_ recipe: Recipe) -> String? {
        // Find the ingredient from this recipe
        for ingredient in combinedIngredient.ingredients {
            if ingredient.recipe?.id == recipe.id {
                return ingredient.displayText
            }
        }
        return nil
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
