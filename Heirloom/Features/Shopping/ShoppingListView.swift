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
    @EnvironmentObject private var tabCoordinator: TabNavigationCoordinator

    private var toastManager: ToastManager { ServiceContainer.shared.resolve(ToastManager.self) }
    private var remindersService: RemindersService { ServiceContainer.shared.resolve(RemindersService.self) }

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
                            .accessibilityLabel("Export to Reminders")
                            .accessibilityHint("Export shopping list to Apple Reminders app")

                            Divider()

                            Button {
                                checkOffAll()
                            } label: {
                                Label("Check Off All", systemImage: "checkmark.circle")
                            }
                            .accessibilityLabel("Check Off All Items")

                            Button {
                                uncheckAll()
                            } label: {
                                Label("Uncheck All", systemImage: "circle")
                            }
                            .accessibilityLabel("Uncheck All Items")

                            Divider()

                            Button(role: .destructive) {
                                clearList()
                            } label: {
                                Label("Clear List", systemImage: "trash")
                            }
                            .accessibilityLabel("Clear Shopping List")
                            .accessibilityHint("Removes all recipes and items from shopping list")
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                        .accessibilityLabel("Shopping List Options")
                        .accessibilityHint("Opens menu with export, check off, and clear options")
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
            tabCoordinator.selectedTab = TabNavigationCoordinator.Tab.recipes.rawValue
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
                    .accessibilityLabel("\(cartRecipe.recipe?.title ?? "Recipe"), \(selectedRecipeIds.contains(cartRecipe.recipe?.id ?? UUID()) ? "Selected" : "Not selected")")
                    .accessibilityHint("Toggle recipe inclusion in shopping list")
                    .contextMenu {
                        if let recipe = cartRecipe.recipe {
                            Button {
                                removeRecipeFromList(cartRecipe)
                            } label: {
                                Label("Remove from List", systemImage: "cart.badge.minus")
                            }

                            Button {
                                toggleRecipeSelection(cartRecipe)
                            } label: {
                                let isSelected = selectedRecipeIds.contains(recipe.id)
                                Label(
                                    isSelected ? "Hide Items" : "Show Items",
                                    systemImage: isSelected ? "eye.slash" : "eye"
                                )
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            // Initialize with all recipes selected
            if selectedRecipeIds.isEmpty {
                selectedRecipeIds = Set(cartRecipes.compactMap { $0.recipe?.id })
            }
        }
        .onChange(of: cartRecipes.count) { oldCount, newCount in
            // When new recipes are added, automatically select them
            let currentRecipeIds = Set(cartRecipes.compactMap { $0.recipe?.id })
            let newRecipeIds = currentRecipeIds.subtracting(selectedRecipeIds)

            // Add any new recipes to selected set (so their items show up)
            selectedRecipeIds.formUnion(newRecipeIds)
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
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(category.rawValue), \(ingredients.count) items, \(category.aisleHint)")

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
                                Log.warning("Failed to extract recipe data for shopping list", category: .database, metadata: ["reason": "relationships may not be loaded yet"])

                                // Ensure sheet is not shown
                                selectedIngredientData = nil

                                // Show user feedback
                                toastManager.info(
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
                        .accessibilityLabel("View details, from \(combinedIngredient.recipeCount) recipes")
                        .accessibilityHint("Shows which recipes use this ingredient")
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
        .accessibilityLabel("\(combinedIngredient.displayText), \(combinedIngredient.isCheckedOff ? "Checked off" : "Not checked")\(isAggregated ? ", From \(combinedIngredient.recipeCount) recipes" : "")")
        .accessibilityHint("Toggles item as checked or unchecked")
        .accessibilityAddTraits(combinedIngredient.isCheckedOff ? .isSelected : [])
        .contextMenu {
            Button {
                toggleCombinedIngredient(combinedIngredient)
            } label: {
                Label(
                    combinedIngredient.isCheckedOff ? "Uncheck" : "Check Off",
                    systemImage: combinedIngredient.isCheckedOff ? "circle" : "checkmark.circle.fill"
                )
            }

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
                    guard !recipeData.isEmpty else { return }

                    // Create Identifiable data struct for sheet presentation
                    selectedIngredientData = IngredientRecipeData(
                        name: ingredientName,
                        displayText: displayText,
                        recipes: recipeData.sorted { $0.recipeTitle < $1.recipeTitle }
                    )
                } label: {
                    Label("View Recipes", systemImage: "square.stack.3d.up.fill")
                }
            }

            Button {
                UIPasteboard.general.string = combinedIngredient.displayText
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
        }
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

        // Combine ingredients with the same name (with normalization)
        var combined: [String: (category: GroceryCategory, scaledIngredients: [ScaledIngredient])] = [:]
        for (scaledIngredient, category) in allIngredients {
            let key = normalizeIngredientName(scaledIngredient.originalIngredient.name)
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
            // Single ingredient - just show it as-is
            if scaledIngredients.count == 1 {
                return scaledIngredients[0].fullDisplayString
            }

            // Multiple ingredients - check if they have units
            var hasUnits = true
            for ingredient in scaledIngredients {
                if ingredient.originalIngredient.unit?.trimmingCharacters(in: .whitespaces).isEmpty ?? true {
                    hasUnits = false
                    break
                }
            }

            // Handle unitless ingredients (like eggs, cloves, etc.)
            if !hasUnits {
                // Sum quantities for unitless ingredients
                var total = 0.0
                for ingredient in scaledIngredients {
                    if let qty = ingredient.scaledQuantity {
                        total += qty
                    }
                }

                // Use the shortest, simplest name
                let name = scaledIngredients.map { $0.originalIngredient.name }.min(by: { $0.count < $1.count }) ?? scaledIngredients[0].originalIngredient.name
                let qtyString = formatQuantity(total)

                var parts: [String] = [qtyString, name]
                if let prep = scaledIngredients[0].originalIngredient.preparation {
                    parts.append("(\(prep))")
                }
                return parts.joined(separator: " ")
            }

            // Multiple ingredients with units - group by normalized unit first
            // Step 1: Check all have quantities and units
            var ingredientsWithUnits: [(quantity: Double, unit: String, normalizedUnit: String)] = []
            for ingredient in scaledIngredients {
                guard let qty = ingredient.scaledQuantity,
                      let unit = ingredient.originalIngredient.unit, !unit.trimmingCharacters(in: .whitespaces).isEmpty else {
                    // Missing quantity or unit - can't combine
                    return "\(scaledIngredients.count)× \(scaledIngredients[0].fullDisplayString)"
                }

                let trimmedUnit = unit.trimmingCharacters(in: .whitespaces)
                let normalized = normalizeUnit(trimmedUnit)
                ingredientsWithUnits.append((quantity: qty, unit: trimmedUnit, normalizedUnit: normalized))
            }

            // Step 2: Group by normalized unit and sum quantities
            var unitGroups: [String: (total: Double, displayUnit: String)] = [:]
            for item in ingredientsWithUnits {
                if let existing = unitGroups[item.normalizedUnit] {
                    unitGroups[item.normalizedUnit] = (total: existing.total + item.quantity, displayUnit: existing.displayUnit)
                } else {
                    unitGroups[item.normalizedUnit] = (total: item.quantity, displayUnit: item.unit)
                }
            }

            // Step 3: If only one unit group, return summed total (with smart conversion)
            if unitGroups.count == 1, let (normalizedUnit, group) = unitGroups.first {
                // Use the shortest, simplest name (prefer "eggs" over "large eggs")
                let name = scaledIngredients.map { $0.originalIngredient.name }.min(by: { $0.count < $1.count }) ?? scaledIngredients[0].originalIngredient.name

                // Try to convert to a better unit if appropriate
                let (convertedQty, convertedUnit) = smartConvertUnit(quantity: group.total, unit: group.displayUnit, normalizedUnit: normalizedUnit)

                let qtyString = formatQuantity(convertedQty)
                var parts: [String] = [qtyString, convertedUnit, name]
                if let prep = scaledIngredients[0].originalIngredient.preparation {
                    parts.append("(\(prep))")
                }
                return parts.joined(separator: " ")
            }

            // Step 4: Multiple unit groups - try to convert and combine intelligently
            // Use the shortest, simplest name (prefer "eggs" over "large eggs")
            let name = scaledIngredients.map { $0.originalIngredient.name }.min(by: { $0.count < $1.count }) ?? scaledIngredients[0].originalIngredient.name
            let prep = scaledIngredients[0].originalIngredient.preparation

            // Try to convert smaller units to larger units
            var convertedGroups = unitGroups
            let conversionAttempts: [(from: String, to: String, factor: Double)] = [
                ("tsp", "tbsp", 3.0),
                ("teaspoon", "tablespoon", 3.0),
                ("tbsp", "cup", 16.0),
                ("tablespoon", "cup", 16.0),
                ("oz", "lb", 16.0),
                ("ounce", "pound", 16.0)
            ]

            // For each conversion rule, check if we have both units
            for conversion in conversionAttempts {
                if let smallerGroup = convertedGroups[conversion.from],
                   let largerGroup = convertedGroups[conversion.to] {
                    // Convert smaller to larger unit
                    let convertedQty = smallerGroup.total / conversion.factor
                    let combinedQty = largerGroup.total + convertedQty

                    // Update the larger unit with combined quantity
                    convertedGroups[conversion.to] = (total: combinedQty, displayUnit: largerGroup.displayUnit)
                    // Remove the smaller unit
                    convertedGroups.removeValue(forKey: conversion.from)
                }
            }

            // If we successfully converted to a single unit, format it
            if convertedGroups.count == 1, let (_, group) = convertedGroups.first {
                // Round the quantity intelligently before formatting
                let rounded = roundForCooking(group.total)
                let qtyString = formatQuantity(rounded)
                var parts: [String] = [qtyString, group.displayUnit, name]
                if let prep = prep {
                    parts.append("(\(prep))")
                }
                return parts.joined(separator: " ")
            }

            // Still multiple units - show as "2 cups + 1 tablespoon butter"
            // Sort by quantity (largest first) for better readability
            let sortedGroups = convertedGroups.sorted { $0.value.total > $1.value.total }

            var quantityParts: [String] = []
            for (_, group) in sortedGroups {
                let qty = formatQuantity(group.total)
                quantityParts.append("\(qty) \(group.displayUnit)")
            }

            var result = quantityParts.joined(separator: " + ") + " " + name
            if let prep = prep {
                result += " (\(prep))"
            }
            return result
        }

        /// Normalize unit for comparison (lowercase, singular form)
        private func normalizeUnit(_ unit: String) -> String {
            let lowercased = unit.lowercased().trimmingCharacters(in: .whitespaces)

            // Convert plural to singular for common units
            let singularMappings: [String: String] = [
                "cups": "cup",
                "tablespoons": "tablespoon",
                "tablespoon": "tbsp",
                "tbsps": "tbsp",
                "tbs": "tbsp",  // Add this mapping!
                "teaspoons": "teaspoon",
                "teaspoon": "tsp",
                "tsps": "tsp",
                "ounces": "ounce",
                "ounce": "oz",
                "ozs": "oz",
                "pounds": "pound",
                "pound": "lb",
                "lbs": "lb",
                "grams": "gram",
                "gram": "g",
                "g": "g",
                "kilograms": "kilogram",
                "kilogram": "kg",
                "kgs": "kg",
                "liters": "liter",
                "liter": "l",
                "litres": "litre",
                "litre": "l",
                "milliliters": "milliliter",
                "milliliter": "ml",
                "millilitres": "millilitre",
                "millilitre": "ml",
                "mls": "ml",
                "cloves": "clove",
                "pieces": "piece",
                "slices": "slice"
            ]

            return singularMappings[lowercased] ?? lowercased
        }

        /// Smart unit conversion - converts to larger units when appropriate
        /// Example: 5.5 teaspoons → 2 tablespoons (rounded from 1.83)
        private func smartConvertUnit(quantity: Double, unit: String, normalizedUnit: String) -> (quantity: Double, unit: String) {
            // Define conversion rules: (fromUnit, toUnit, conversionFactor, minimumQuantity)
            let conversions: [(from: String, to: String, factor: Double, minQty: Double)] = [
                // Volume conversions
                ("tsp", "tbsp", 3.0, 4.0),           // Convert tsp to tbsp if >= 4 tsp
                ("teaspoon", "tablespoon", 3.0, 4.0),
                ("tbsp", "cup", 16.0, 8.0),          // Convert tbsp to cups if >= 8 tbsp
                ("tablespoon", "cup", 16.0, 8.0),

                // Weight conversions
                ("oz", "lb", 16.0, 12.0),            // Convert oz to lb if >= 12 oz
                ("ounce", "pound", 16.0, 12.0),
                ("gram", "kilogram", 1000.0, 500.0), // Convert g to kg if >= 500g
                ("g", "kg", 1000.0, 500.0)
            ]

            // Check if this unit can be converted
            for conversion in conversions {
                if normalizedUnit == conversion.from && quantity >= conversion.minQty {
                    let convertedQty = quantity / conversion.factor

                    // Round intelligently for cooking measurements
                    let rounded = roundForCooking(convertedQty)

                    // Return converted unit
                    return (quantity: rounded, unit: conversion.to)
                }
            }

            // No conversion needed - return original
            return (quantity: quantity, unit: unit)
        }

        /// Round quantities intelligently for cooking
        /// Examples: 1.83 → 2, 1.875 → 2, 1.25 → 1.25, 2.6 → 2.5
        private func roundForCooking(_ value: Double) -> Double {
            // Check if it's close to a whole number (within 0.2)
            // This will round 1.875 (1⅞) and 1.833 up to 2
            let whole = round(value)
            if abs(value - whole) < 0.2 {
                return whole
            }

            // Check if it's close to a half (within 0.15)
            let half = round(value * 2) / 2
            if abs(value - half) < 0.15 {
                return half
            }

            // Check if it's close to a quarter (within 0.1)
            let quarter = round(value * 4) / 4
            if abs(value - quarter) < 0.1 {
                return quarter
            }

            // Check if it's close to an eighth (within 0.06)
            let eighth = round(value * 8) / 8
            if abs(value - eighth) < 0.06 {
                return eighth
            }

            // Return as-is if no good round exists
            return value
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

    // MARK: - Helper Functions

    /// Normalize ingredient names for better combining
    /// Examples: "large eggs" → "eggs", "medium onions" → "onions"
    private func normalizeIngredientName(_ name: String) -> String {
        var normalized = name.lowercased().trimmingCharacters(in: .whitespaces)

        // Strip common size/quality modifiers from the beginning
        let prefixesToRemove = [
            "large ", "medium ", "small ", "extra large ", "xl ", "jumbo ",
            "fresh ", "dried ", "frozen ", "canned ", "whole ",
            "ripe ", "unripe ", "raw ", "cooked "
        ]

        for prefix in prefixesToRemove {
            if normalized.hasPrefix(prefix) {
                normalized = String(normalized.dropFirst(prefix.count))
                break // Only remove one prefix
            }
        }

        return normalized
    }

    // MARK: - Actions
    private func removeRecipeFromList(_ cartRecipe: ShoppingCartRecipe) {
        // Uncheck all ingredients in the recipe
        if let ingredients = cartRecipe.recipe?.ingredients {
            for ingredient in ingredients {
                ingredient.isCheckedOff = false
            }
        }

        // Update recipe flag
        cartRecipe.recipe?.isInShoppingList = false

        // Remove from selected recipes
        if let recipeId = cartRecipe.recipe?.id {
            selectedRecipeIds.remove(recipeId)
        }

        // Delete the ShoppingCartRecipe
        modelContext.delete(cartRecipe)
        try? modelContext.save()

        // Add haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

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
                toastManager.info(
                    title: "Nothing to export",
                    message: "All items are checked off"
                )
            }
            return
        }

        do {
            try await remindersService.exportToReminders(items: items)
            await MainActor.run {
                toastManager.success(
                    title: "Exported to Reminders",
                    message: "Added \(items.count) items to 'Heirloom Shopping' list"
                )

                // TODO: Add VoiceOver announcement once AccessibilityAnnouncementService is added to Xcode project
                // AccessibilityAnnouncementService.shared.announceExportToRemindersSuccess(listName: "Heirloom Shopping")
            }
        } catch {
            await MainActor.run {
                toastManager.error(
                    title: "Export failed",
                    message: error.localizedDescription
                )

                // TODO: Add VoiceOver announcement once AccessibilityAnnouncementService is added to Xcode project
                // AccessibilityAnnouncementService.shared.announceExportToRemindersFailed(error: error.localizedDescription)
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

        // Add haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    private func toggleRecipeSelection(_ cartRecipe: ShoppingCartRecipe) {
        guard let recipeId = cartRecipe.recipe?.id else { return }
        if selectedRecipeIds.contains(recipeId) {
            selectedRecipeIds.remove(recipeId)
        } else {
            selectedRecipeIds.insert(recipeId)
        }

        // Add haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    private func checkOffAll() {
        for cartRecipe in cartRecipes {
            guard let ingredients = cartRecipe.recipe?.ingredients else { continue }
            for ingredient in ingredients {
                ingredient.isCheckedOff = true
            }
        }
        try? modelContext.save()

        // TODO: Add VoiceOver announcement once AccessibilityAnnouncementService is added to Xcode project
        // AccessibilityAnnouncementService.shared.announceAllItemsChecked()
    }

    private func uncheckAll() {
        for cartRecipe in cartRecipes {
            guard let ingredients = cartRecipe.recipe?.ingredients else { continue }
            for ingredient in ingredients {
                ingredient.isCheckedOff = false
            }
        }
        try? modelContext.save()

        // TODO: Add VoiceOver announcement once AccessibilityAnnouncementService is added to Xcode project
        // AccessibilityAnnouncementService.shared.announceAllItemsUnchecked()
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

        // Shopping cart is local-only (no Firebase sync needed for ephemeral data)

        // TODO: Add VoiceOver announcement once AccessibilityAnnouncementService is added to Xcode project
        // AccessibilityAnnouncementService.shared.announceShoppingListCleared()
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
        .environmentObject(TabNavigationCoordinator())
}

#Preview("Empty") {
    ShoppingListView()
        .modelContainer(for: Recipe.self, inMemory: true)
        .environmentObject(TabNavigationCoordinator())
}
