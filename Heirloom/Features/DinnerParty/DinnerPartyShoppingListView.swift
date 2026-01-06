import SwiftUI
import SwiftData

struct DinnerPartyShoppingListView: View {
    @Bindable var party: DinnerParty
    @State private var groupedIngredients: [String: [ScaledIngredient]] = [:]
    @Environment(\.modelContext) private var modelContext

    private var toastManager: ToastManager { ServiceContainer.shared.resolve(ToastManager.self) }

    struct ScaledIngredient: Identifiable {
        let id = UUID()
        let text: String
        let recipeName: String
        var isChecked: Bool = false
    }

    var body: some View {
        List {
            headerSection
            addToMainShoppingButton
            categoryList
        }
        .navigationTitle("Shopping List")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                ShareLink(item: generateShoppingListText()) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }
        }
        .onAppear {
            loadIngredients()
        }
    }

    private var headerSection: some View {
        Section {
            HStack {
                Image(systemName: "person.2.fill")
                Text("Scaled for \(party.guestCount) guests")
                    .font(HeirloomFonts.body)
                Spacer()
            }
            .foregroundStyle(HeirloomColors.secondaryText)
        }
    }

    private var addToMainShoppingButton: some View {
        Section {
            Button {
                addToMainShoppingList()
            } label: {
                HStack {
                    Image(systemName: "cart.fill.badge.plus")
                        .font(.title3)
                        .foregroundStyle(HeirloomColors.tomato)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Add All to Main Shopping List")
                            .font(HeirloomFonts.bodyBold)
                            .foregroundStyle(HeirloomColors.primaryText)

                        Text("Adds scaled recipes to your main shopping tab")
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(HeirloomColors.secondaryText)
                    }

                    Spacer()

                    Image(systemName: "arrow.right")
                        .foregroundStyle(HeirloomColors.secondaryText)
                }
            }
        }
    }

    private var categoryList: some View {
        ForEach(sortedCategories, id: \.self) { category in
            categorySection(category)
        }
    }

    private func categorySection(_ category: String) -> some View {
        Section(category) {
            if let ingredients = Binding($groupedIngredients[category]) {
                ForEach(ingredients) { $ingredient in
                    ingredientRow($ingredient)
                }
            }
        }
    }

    private func ingredientRow(_ ingredient: Binding<ScaledIngredient>) -> some View {
        HStack {
            Button {
                ingredient.wrappedValue.isChecked.toggle()
            } label: {
                HStack {
                    Image(systemName: ingredient.wrappedValue.isChecked ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(ingredient.wrappedValue.isChecked ? HeirloomColors.familyGreen : Color.gray.opacity(0.3))
                        .font(.title3)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(ingredient.wrappedValue.text)
                            .font(HeirloomFonts.body)
                            .foregroundStyle(HeirloomColors.primaryText)
                            .strikethrough(ingredient.wrappedValue.isChecked)

                        Text("from \(ingredient.wrappedValue.recipeName)")
                            .font(HeirloomFonts.caption2)
                            .foregroundStyle(HeirloomColors.secondaryText)
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }

    // MARK: - Data Loading

    private func loadIngredients() {
        var ingredients: [String: [ScaledIngredient]] = [:]

        guard let recipes = party.recipes else { return }

        for partyRecipe in recipes {
            guard let recipe = partyRecipe.recipe,
                  let recipeIngredients = recipe.ingredients else { continue }

            for ingredient in recipeIngredients {
                let category = ingredient.category?.rawValue ?? "Other"
                let scaledText = scaleIngredientText(
                    ingredient.originalText,
                    factor: partyRecipe.scalingFactor
                )

                let scaledIngredient = ScaledIngredient(
                    text: scaledText,
                    recipeName: recipe.title
                )

                if ingredients[category] != nil {
                    ingredients[category]?.append(scaledIngredient)
                } else {
                    ingredients[category] = [scaledIngredient]
                }
            }
        }

        groupedIngredients = ingredients
    }

    private func scaleIngredientText(_ text: String, factor: Double) -> String {
        // Scale ingredient quantities by factor, handling ranges precisely
        guard factor != 1.0 else { return text }

        // First, check for ranges (e.g., "1-2 cups", "1/2 cup", "1 to 2 cups")
        // For ranges, we take only the first/minimum value and scale it (users want precision)
        let rangePattern = #"(\d+\.?\d*)\s*[-/to]+\s*(\d+\.?\d*)"#
        if let rangeRegex = try? NSRegularExpression(pattern: rangePattern),
           let match = rangeRegex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let firstRange = Range(match.range(at: 1), in: text),
           let minValue = Double(text[firstRange]) {

            // Scale just the minimum value for precision
            let scaled = minValue * factor
            let formatted = scaled.truncatingRemainder(dividingBy: 1) == 0 ?
                String(format: "%.0f", scaled) :
                String(format: "%.1f", scaled)

            // Replace the entire range with just the scaled min value
            let fullRangeRange = Range(match.range, in: text)!
            var scaledText = text
            scaledText.replaceSubrange(fullRangeRange, with: formatted)
            return scaledText
        }

        // No range found - scale all numbers normally
        let pattern = #"(\d+\.?\d*)"#
        let regex = try? NSRegularExpression(pattern: pattern)
        let nsString = text as NSString
        let results = regex?.matches(in: text, range: NSRange(location: 0, length: nsString.length))

        var scaledText = text
        results?.reversed().forEach { result in
            if let range = Range(result.range, in: text),
               let number = Double(text[range]) {
                let scaled = number * factor
                let formatted = scaled.truncatingRemainder(dividingBy: 1) == 0 ?
                    String(format: "%.0f", scaled) :
                    String(format: "%.1f", scaled)
                scaledText = scaledText.replacingOccurrences(
                    of: String(text[range]),
                    with: formatted,
                    options: [],
                    range: range
                )
            }
        }

        return scaledText
    }

    private var sortedCategories: [String] {
        Array(groupedIngredients.keys).sorted()
    }

    private func generateShoppingListText() -> String {
        var text = "\(party.name) - Shopping List\n"
        text += "For \(party.guestCount) guests\n\n"

        for category in sortedCategories {
            text += "\(category):\n"
            if let ingredients = groupedIngredients[category] {
                for ingredient in ingredients {
                    text += "  • \(ingredient.text) (from \(ingredient.recipeName))\n"
                }
            }
            text += "\n"
        }

        return text
    }

    private func addToMainShoppingList() {
        guard let partyRecipes = party.recipes else {
            toastManager.error(title: "No recipes found", message: "This party has no recipes.")
            return
        }

        var addedCount = 0
        var skippedCount = 0

        for partyRecipe in partyRecipes {
            guard let recipe = partyRecipe.recipe else { continue }

            // Check if recipe is already in shopping list
            if recipe.isInShoppingCart(context: modelContext) {
                skippedCount += 1
                continue
            }

            // Calculate target servings from scaling factor
            let originalServings = recipe.parsedServingCount
            let targetServings = Int(Double(originalServings) * partyRecipe.scalingFactor)

            // Create ShoppingCartRecipe entry
            let cartRecipe = ShoppingCartRecipe(recipe: recipe, targetServings: targetServings)
            modelContext.insert(cartRecipe)

            // Mark recipe as in shopping list
            recipe.isInShoppingList = true

            addedCount += 1
        }

        // Save changes
        do {
            try modelContext.save()

            // Show success message
            if addedCount > 0 {
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)

                if skippedCount > 0 {
                    toastManager.success(
                        title: "Added \(addedCount) recipe\(addedCount == 1 ? "" : "s")",
                        message: "\(skippedCount) already in shopping list"
                    )
                } else {
                    toastManager.success(
                        title: "Added to Shopping List!",
                        message: "\(addedCount) recipe\(addedCount == 1 ? "" : "s") added"
                    )
                }
            } else if skippedCount > 0 {
                toastManager.info(
                    title: "Already Added",
                    message: "All recipes are already in your shopping list"
                )
            }
        } catch {
            toastManager.error(
                title: "Failed to add",
                message: error.localizedDescription
            )
        }
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: DinnerParty.self, configurations: config)

    let party = DinnerParty(name: "Dinner Party", guestCount: 8, mealTime: Date())
    container.mainContext.insert(party)

    return NavigationStack {
        DinnerPartyShoppingListView(party: party)
    }
    .modelContainer(container)
}
