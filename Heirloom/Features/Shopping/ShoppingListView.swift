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

    // Dependency injection for formatter (future use for unit conversion)
    private var formatter: IngredientFormatter {
        ServiceContainer.shared.resolve(IngredientFormatter.self)
    }

    // Observe UnitsConfiguration for reactive updates
    @ObservedObject private var unitsConfig: UnitsConfiguration = ServiceContainer.shared.resolve(UnitsConfiguration.self)

    @State private var selectedRecipeIds: Set<UUID> = []
    @State private var selectedIngredientData: IngredientRecipeData?
    @State private var showSettings = false

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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        if cartRecipes.isEmpty {
                            // Empty state menu items
                            Button {
                                tabCoordinator.selectedTab = TabNavigationCoordinator.Tab.collections.rawValue
                            } label: {
                                Label("Add Recipes", systemImage: "plus.circle")
                            }
                            .accessibilityLabel("Add recipes to shopping list")
                            .accessibilityHint("Navigate to Collections to add recipes")
                        } else {
                            // Non-empty state menu items
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
                        }

                        Divider()

                        Button {
                            showSettings = true
                        } label: {
                            Label("Settings", systemImage: "gearshape")
                        }
                        .accessibilityLabel("Settings")
                        .accessibilityHint("Open app settings")
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(HeirloomColors.primaryText)
                    }
                    .accessibilityLabel("Shopping List Options")
                    .accessibilityHint("Opens menu with shopping list and app options")
                }
            }
            .sheet(item: $selectedIngredientData) { data in
                IngredientRecipeListView(
                    ingredientName: data.name,
                    displayText: data.displayText,
                    recipeData: data.recipes
                )
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack {
                    SettingsView()
                        .environmentObject(tabCoordinator)
                }
            }
        }
    }

    // MARK: - Empty State
    private var emptyState: some View {
        EmptyStateView.emptyShoppingList {
            // Switch to Collections tab
            tabCoordinator.selectedTab = TabNavigationCoordinator.Tab.collections.rawValue
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
                .font(HeirloomFonts.title2)

            // Recipe icon
            Image(systemName: recipe.sourceType?.iconName ?? "fork.knife")
                .foregroundStyle(isSelected ? HeirloomColors.tomato : HeirloomColors.warmGray)
                .font(HeirloomFonts.caption1)

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
            VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
                HStack {
                    Image(systemName: category.iconName)
                        .foregroundStyle(HeirloomColors.tomato)
                        .font(HeirloomFonts.title2)

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
                    .font(HeirloomFonts.title2)
                    .foregroundStyle(combinedIngredient.isCheckedOff ? HeirloomColors.familyGreen : (isAggregated ? HeirloomColors.tomato : HeirloomColors.warmGray))

                VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
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
                            HStack(spacing: HeirloomSpacing.xs) {
                                Image(systemName: "square.stack.3d.up.fill")
                                    .font(HeirloomFonts.caption2)
                                Text("From \(combinedIngredient.recipeCount) recipe\(combinedIngredient.recipeCount == 1 ? "" : "s")")
                                    .font(HeirloomFonts.caption2)
                                Image(systemName: "chevron.right")
                                    .font(HeirloomFonts.caption2)
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

        // Add stable sort within each category
        let sortedDict = Dictionary(uniqueKeysWithValues: grouped.map { (key: GroceryCategory, value: [CombinedIngredient]) -> (GroceryCategory, [CombinedIngredient]) in
            let sortedIngredients = value.sorted { (a: CombinedIngredient, b: CombinedIngredient) -> Bool in
                // Primary: Completion status (unchecked first)
                if a.isCheckedOff != b.isCheckedOff {
                    return !a.isCheckedOff // unchecked first
                }
                // Secondary: Alphabetical by name
                return a.displayText < b.displayText
            }
            return (key, sortedIngredients)
        })

        return sortedDict
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
                let formatter = ServiceContainer.sharedUnsafe.resolveUnsafe(IngredientFormatter.self)
                let qtyString = formatter.formatQuantity(total, unit: nil)

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

                let formatter = ServiceContainer.sharedUnsafe.resolveUnsafe(IngredientFormatter.self)
                let qtyString = formatter.formatQuantity(convertedQty, unit: convertedUnit)
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
                let formatter = ServiceContainer.sharedUnsafe.resolveUnsafe(IngredientFormatter.self)
                let qtyString = formatter.formatQuantity(rounded, unit: group.displayUnit)
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
            let formatter = ServiceContainer.sharedUnsafe.resolveUnsafe(IngredientFormatter.self)
            for (_, group) in sortedGroups {
                let qty = formatter.formatQuantity(group.total, unit: group.displayUnit)
                quantityParts.append("\(qty) \(group.displayUnit)")
            }

            var result = quantityParts.joined(separator: " + ") + " " + name
            if let prep = prep {
                result += " (\(prep))"
            }

            // FINAL STEP: Simplify any " + " expressions
            return simplifyAdditionExpression(result)
        }

        // MARK: - Addition Expression Simplification

        /// Size descriptors that should NOT be treated as units for combination purposes
        private static let sizeDescriptors: Set<String> = [
            "large", "medium", "small", "extra large", "xl", "jumbo", "big",
            "fresh", "dried", "frozen", "canned", "whole", "ripe", "raw", "cooked"
        ]

        /// Simplifies addition expressions like "2 large + 3 medium + 3 eggs" → "8 eggs"
        private func simplifyAdditionExpression(_ text: String) -> String {
            // Only process if this looks like an addition expression
            guard text.contains(" + ") else { return text }

            let parts = text.components(separatedBy: " + ")
            guard parts.count >= 2 else { return text }

            // Extract the ingredient name from the last part
            guard let (ingredientName, _) = extractIngredientName(from: text) else {
                return text
            }

            // Parse each part and collect quantities with their units
            var quantities: [(qty: Double, unit: String?)] = []

            for part in parts {
                if let parsed = parseAdditionPart(part.trimmingCharacters(in: .whitespaces), ingredientName: ingredientName) {
                    quantities.append(parsed)
                } else {
                    // Couldn't parse a part - return original
                    return text
                }
            }

            // Check if all parts have compatible units (or no units / size descriptors only)
            let realUnits = quantities.compactMap { $0.unit }.filter { !Self.sizeDescriptors.contains($0.lowercased()) }
            let uniqueRealUnits = Set(realUnits.map { normalizeUnit($0) })

            // Case 1: No real units (all unitless or size descriptors) - just sum quantities
            if uniqueRealUnits.isEmpty {
                let total = quantities.reduce(0.0) { $0 + $1.qty }
                let formatter = ServiceContainer.sharedUnsafe.resolveUnsafe(IngredientFormatter.self)
                let qtyString = formatter.formatQuantity(total, unit: nil)
                return "\(qtyString) \(ingredientName)".trimmingCharacters(in: .whitespaces)
            }

            // Case 2: Single real unit type - convert and sum
            if uniqueRealUnits.count == 1 {
                let targetUnit = uniqueRealUnits.first!
                var total = 0.0

                for (qty, unit) in quantities {
                    if let unit = unit, !Self.sizeDescriptors.contains(unit.lowercased()) {
                        // Has a real unit - convert if needed
                        let (converted, _) = convertToUnit(qty, fromUnit: normalizeUnit(unit), toUnit: targetUnit)
                        total += converted
                    } else {
                        // No unit or size descriptor - just add quantity
                        total += qty
                    }
                }

                let formatter = ServiceContainer.sharedUnsafe.resolveUnsafe(IngredientFormatter.self)
                let qtyString = formatter.formatQuantity(total, unit: targetUnit)
                return "\(qtyString) \(targetUnit) \(ingredientName)".trimmingCharacters(in: .whitespaces)
            }

            // Case 3: Multiple incompatible real units - try to convert to common unit
            return tryConvertAndCombine(quantities: quantities, ingredientName: ingredientName) ?? text
        }

        /// Extracts the ingredient name from an addition expression
        private func extractIngredientName(from text: String) -> (name: String, prep: String?)? {
            let parts = text.components(separatedBy: " + ")
            guard let lastPart = parts.last?.trimmingCharacters(in: .whitespaces) else { return nil }

            var words = lastPart.split(separator: " ").map(String.init)

            // Remove leading number
            if let first = words.first, Double(first) != nil || first.contains("/") || first.contains("⁄") ||
               first.allSatisfy({ $0.isNumber || $0 == "." || $0 == "/" || "¼½¾⅓⅔⅛⅜⅝⅞".contains($0) }) {
                words.removeFirst()
            }

            // Remove unit or size descriptor if present
            if let first = words.first?.lowercased() {
                let allUnitsAndDescriptors = Self.sizeDescriptors.union([
                    "cup", "cups", "tbsp", "tablespoon", "tablespoons", "tsp", "teaspoon", "teaspoons",
                    "oz", "oz.", "ounce", "ounces", "lb", "lb.", "pound", "pounds",
                    "gram", "grams", "g", "kg", "kilogram", "kilograms",
                    "ml", "milliliter", "milliliters", "l", "liter", "liters",
                    "clove", "cloves", "slice", "slices", "piece", "pieces", "can", "cans",
                    "pinch", "dash", "bunch", "package", "pkg", "stick", "sticks"
                ])
                if allUnitsAndDescriptors.contains(first) {
                    words.removeFirst()
                }
            }

            guard !words.isEmpty else { return nil }

            let name = words.joined(separator: " ")
            if let parenStart = name.firstIndex(of: "("),
               let parenEnd = name.lastIndex(of: ")"),
               parenStart < parenEnd {
                let prep = String(name[name.index(after: parenStart)..<parenEnd])
                let cleanName = String(name[..<parenStart]).trimmingCharacters(in: .whitespaces)
                return (cleanName, prep)
            }

            return (name, nil)
        }

        /// Parses a single part of an addition expression
        private func parseAdditionPart(_ part: String, ingredientName: String) -> (qty: Double, unit: String?)? {
            var text = part

            // Remove the ingredient name from the end if present
            let lowerName = ingredientName.lowercased()
            let lowerText = text.lowercased()
            if lowerText.hasSuffix(lowerName) {
                text = String(text.dropLast(ingredientName.count)).trimmingCharacters(in: .whitespaces)
            }

            guard !text.isEmpty else { return nil }

            let words = text.split(separator: " ").map(String.init)
            guard !words.isEmpty else { return nil }

            var qty: Double = 0
            var wordIndex = 0

            if let firstQty = parseQuantityString(words[0]) {
                qty = firstQty
                wordIndex = 1

                // Check for mixed number like "1 1/2"
                if wordIndex < words.count, let fractionPart = parseQuantityString(words[wordIndex]) {
                    if fractionPart < 1 {
                        qty += fractionPart
                        wordIndex += 1
                    }
                }
            } else {
                return nil
            }

            let unit = wordIndex < words.count ? words[wordIndex...].joined(separator: " ") : nil
            return (qty, unit?.isEmpty == true ? nil : unit)
        }

        /// Parses a quantity string that might be a number, fraction, or unicode fraction
        private func parseQuantityString(_ str: String) -> Double? {
            let unicodeFractions: [Character: Double] = [
                "¼": 0.25, "½": 0.5, "¾": 0.75,
                "⅓": 1.0/3, "⅔": 2.0/3,
                "⅛": 0.125, "⅜": 0.375, "⅝": 0.625, "⅞": 0.875
            ]

            if str.count == 1, let char = str.first, let val = unicodeFractions[char] {
                return val
            }

            if let lastChar = str.last, let fracVal = unicodeFractions[lastChar] {
                let wholePart = String(str.dropLast())
                if let whole = Double(wholePart) {
                    return whole + fracVal
                }
            }

            if str.contains("/") || str.contains("⁄") {
                let separator: Character = str.contains("/") ? "/" : "⁄"
                let parts = str.split(separator: separator)
                if parts.count == 2,
                   let num = Double(parts[0]),
                   let den = Double(parts[1]),
                   den != 0 {
                    return num / den
                }
            }

            return Double(str)
        }

        /// Attempts to convert all quantities to a common unit and combine
        private func tryConvertAndCombine(quantities: [(qty: Double, unit: String?)], ingredientName: String) -> String? {
            let toTeaspoons: [String: Double] = [
                "tsp": 1, "teaspoon": 1,
                "tbsp": 3, "tablespoon": 3,
                "cup": 48,
                "pint": 96,
                "quart": 192,
                "gallon": 768
            ]

            let toGrams: [String: Double] = [
                "g": 1, "gram": 1,
                "kg": 1000, "kilogram": 1000,
                "oz": 28.35, "oz.": 28.35, "ounce": 28.35,
                "lb": 453.6, "lb.": 453.6, "pound": 453.6
            ]

            var totalTeaspoons: Double = 0
            var totalGrams: Double = 0
            var isVolume = false
            var isWeight = false
            var hasUnitless = false

            for (qty, unit) in quantities {
                guard let unit = unit else {
                    hasUnitless = true
                    continue
                }

                let normalized = normalizeUnit(unit)

                if Self.sizeDescriptors.contains(normalized.lowercased()) {
                    hasUnitless = true
                    continue
                }

                if let factor = toTeaspoons[normalized.lowercased()] {
                    totalTeaspoons += qty * factor
                    isVolume = true
                } else if let factor = toGrams[normalized.lowercased()] {
                    totalGrams += qty * factor
                    isWeight = true
                }
            }

            if (isVolume && isWeight) || (hasUnitless && (isVolume || isWeight)) {
                return nil
            }

            let formatter = ServiceContainer.sharedUnsafe.resolveUnsafe(IngredientFormatter.self)

            if isVolume {
                let (resultQty, resultUnit) = convertFromTeaspoons(totalTeaspoons)
                let qtyString = formatter.formatQuantity(resultQty, unit: resultUnit)
                return "\(qtyString) \(resultUnit) \(ingredientName)"
            }

            if isWeight {
                let (resultQty, resultUnit) = convertFromGrams(totalGrams)
                let qtyString = formatter.formatQuantity(resultQty, unit: resultUnit)
                return "\(qtyString) \(resultUnit) \(ingredientName)"
            }

            return nil
        }

        private func convertFromTeaspoons(_ tsp: Double) -> (Double, String) {
            if tsp >= 48 {
                return (tsp / 48, "cup")
            } else if tsp >= 3 {
                return (tsp / 3, "tbsp")
            } else {
                return (tsp, "tsp")
            }
        }

        private func convertFromGrams(_ g: Double) -> (Double, String) {
            if g >= 1000 {
                return (g / 1000, "kg")
            } else if g >= 453.6 {
                return (g / 453.6, "lb")
            } else if g >= 28.35 {
                return (g / 28.35, "oz")
            } else {
                return (g, "g")
            }
        }

        private func convertToUnit(_ qty: Double, fromUnit: String, toUnit: String) -> (Double, String) {
            if fromUnit.lowercased() == toUnit.lowercased() {
                return (qty, toUnit)
            }
            return (qty, fromUnit)
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


        var isCheckedOff: Bool {
            scaledIngredients.allSatisfy { $0.originalIngredient.isCheckedOff }
        }

        var instanceCount: Int {
            scaledIngredients.count
        }

        var recipeCount: Int {
            Set(scaledIngredients.compactMap { $0.originalIngredient.recipe?.id }).count
        }
    }

    // MARK: - Helper Functions

    /// Normalize ingredient names for better combining by extracting the core ingredient name
    /// Examples: "3 large garlic cloves, minced" → "garlic", "1 large onion, chopped" → "onion"
    private func normalizeIngredientName(_ name: String) -> String {
        var normalized = name.lowercased().trimmingCharacters(in: .whitespaces)

        // Step 1: Remove leading quantity (numbers, fractions, unicode fractions)
        normalized = removeLeadingQuantity(from: normalized)

        // Step 2: Remove size/quality descriptors
        let descriptors = [
            "large", "medium", "small", "extra large", "xl", "jumbo", "big",
            "fresh", "dried", "frozen", "canned", "whole",
            "ripe", "unripe", "raw", "cooked",
            "organic", "free range", "boneless", "skinless"
        ]

        for descriptor in descriptors {
            // Remove from anywhere in the text, not just prefix
            normalized = normalized.replacingOccurrences(of: " \(descriptor) ", with: " ")
            if normalized.hasPrefix("\(descriptor) ") {
                normalized = String(normalized.dropFirst(descriptor.count + 1))
            }
        }

        // Step 3: Remove unit words
        let units = [
            "clove", "cloves", "piece", "pieces", "slice", "slices",
            "can", "cans", "package", "packages", "pkg",
            "cup", "cups", "tbsp", "tablespoon", "tablespoons",
            "tsp", "teaspoon", "teaspoons",
            "oz", "oz.", "ounce", "ounces",
            "lb", "lb.", "pound", "pounds",
            "gram", "grams", "g", "kg",
            "bunch", "bunches", "head", "heads",
            "stick", "sticks", "sprig", "sprigs"
        ]

        for unit in units {
            normalized = normalized.replacingOccurrences(of: " \(unit) ", with: " ")
            if normalized.hasPrefix("\(unit) ") {
                normalized = String(normalized.dropFirst(unit.count + 1))
            }
            if normalized.hasSuffix(" \(unit)") {
                normalized = String(normalized.dropLast(unit.count + 1))
            }
        }

        // Step 4: Remove compound suffixes like "and pepper", "and salt"
        let compoundSuffixes = [
            " and pepper", " and salt", " & pepper", " & salt",
            " and black pepper", " and sea salt"
        ]
        for suffix in compoundSuffixes {
            if normalized.hasSuffix(suffix) {
                normalized = String(normalized.dropLast(suffix.count))
            }
        }

        // Step 5: Extract core name (before comma, parentheses, or "for")
        if let commaIndex = normalized.firstIndex(of: ",") {
            normalized = String(normalized[..<commaIndex])
        }
        if let parenIndex = normalized.firstIndex(of: "(") {
            normalized = String(normalized[..<parenIndex])
        }
        if normalized.contains(" for ") {
            let parts = normalized.components(separatedBy: " for ")
            normalized = parts[0]
        }

        // Step 6: Clean up extra whitespace
        normalized = normalized.trimmingCharacters(in: .whitespaces)
        normalized = normalized.replacingOccurrences(of: "  ", with: " ")

        // Step 7: Singularize (remove trailing 's' if appropriate)
        // Be careful not to break words like "grass", "glass", "swiss"
        if normalized.hasSuffix("es") && normalized.count > 3 {
            // "tomatoes" → "tomatoe" (keep for now)
        } else if normalized.hasSuffix("s") && !normalized.hasSuffix("ss") && normalized.count > 2 {
            normalized = String(normalized.dropLast())
        }

        return normalized
    }

    /// Remove leading quantity from ingredient text (e.g., "3 large garlic" → "large garlic")
    private func removeLeadingQuantity(from text: String) -> String {
        var result = text
        let words = result.split(separator: " ", maxSplits: 3).map(String.init)

        guard !words.isEmpty else { return result }

        var wordsToRemove = 0

        // Check first word for quantity
        if isQuantityString(words[0]) {
            wordsToRemove = 1

            // Check second word for fraction (e.g., "1 1/2")
            if words.count > 1 && isQuantityString(words[1]) {
                wordsToRemove = 2
            }
        }

        if wordsToRemove > 0 {
            result = words.dropFirst(wordsToRemove).joined(separator: " ")
        }

        return result
    }

    /// Check if a string represents a quantity (number, fraction, or unicode fraction)
    private func isQuantityString(_ str: String) -> Bool {
        // Check for plain numbers
        if Double(str) != nil {
            return true
        }

        // Check for fractions (1/2, ½, ¼, etc.)
        let unicodeFractions: Set<Character> = ["¼", "½", "¾", "⅓", "⅔", "⅛", "⅜", "⅝", "⅞"]
        if str.count == 1, let char = str.first, unicodeFractions.contains(char) {
            return true
        }

        // Check for fraction format "1/2" or "1⁄2"
        if str.contains("/") || str.contains("⁄") {
            return true
        }

        // Check for decimal format "0.5"
        if str.contains(".") && Double(str) != nil {
            return true
        }

        return false
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
        withAnimation(.easeInOut(duration: 0.25)) {
            // Toggle all ORIGINAL ingredients in the combined group
            let newState = !combinedIngredient.isCheckedOff
            for scaledIngredient in combinedIngredient.scaledIngredients {
                scaledIngredient.originalIngredient.isCheckedOff = newState
            }
            try? modelContext.save()
        }

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
                VStack(spacing: HeirloomSpacing.md) {
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
