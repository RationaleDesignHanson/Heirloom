import SwiftUI
import SwiftData

struct DinnerPartyEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query private var allRecipes: [Recipe]

    @State private var party: DinnerParty?
    @State private var name: String = ""
    @State private var description: String = ""
    @State private var guestCount: Int = 4
    @State private var mealTime: Date = Date().addingTimeInterval(3600 * 4) // 4 hours from now
    @State private var selectedRecipes: Set<Recipe> = []
    @State private var showRecipePicker = false

    private var isEditing: Bool {
        party != nil
    }

    init(party: DinnerParty? = nil) {
        self.party = party
        if let party = party {
            _name = State(initialValue: party.name)
            _description = State(initialValue: party.desc ?? "")
            _guestCount = State(initialValue: party.guestCount)
            _mealTime = State(initialValue: party.mealTime)
            if let recipes = party.recipes {
                _selectedRecipes = State(initialValue: Set(recipes.compactMap { $0.recipe }))
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Event Details") {
                    TextField("Party name", text: $name)
                        .font(HeirloomFonts.body)

                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .font(HeirloomFonts.body)
                        .lineLimit(2...4)
                }

                Section("When") {
                    DatePicker(
                        "Meal time",
                        selection: $mealTime,
                        in: Date()...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .font(HeirloomFonts.body)
                }

                Section("Guests") {
                    Stepper("\(guestCount) guests", value: $guestCount, in: 1...100)
                        .font(HeirloomFonts.body)
                }

                Section {
                    if selectedRecipes.isEmpty {
                        Button {
                            showRecipePicker = true
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(HeirloomColors.tomato)
                                Text("Add Recipes")
                                    .foregroundStyle(HeirloomColors.primaryText)
                            }
                        }
                    } else {
                        ForEach(Array(selectedRecipes), id: \.id) { recipe in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(recipe.title)
                                        .font(HeirloomFonts.body)
                                        .foregroundStyle(HeirloomColors.primaryText)

                                    if let prepTime = recipe.prepTime, let cookTime = recipe.cookTime {
                                        Text("\(prepTime) prep + \(cookTime) cook")
                                            .font(HeirloomFonts.caption2)
                                            .foregroundStyle(HeirloomColors.secondaryText)
                                    }
                                }

                                Spacer()

                                Button {
                                    selectedRecipes.remove(recipe)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(Color.red.opacity(0.6))
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        Button {
                            showRecipePicker = true
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(HeirloomColors.tomato)
                                Text("Add More")
                                    .foregroundStyle(HeirloomColors.primaryText)
                            }
                        }
                    }
                } header: {
                    Text("Recipes (\(selectedRecipes.count))")
                } footer: {
                    if !selectedRecipes.isEmpty {
                        Text("Recipes will be automatically scheduled based on their prep and cook times to finish at the meal time.")
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Party" : "New Dinner Party")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Create") {
                        saveDinnerParty()
                    }
                    .disabled(!isValid)
                }
            }
            .sheet(isPresented: $showRecipePicker) {
                RecipePickerView(selectedRecipes: $selectedRecipes)
            }
        }
    }

    // MARK: - Validation

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !selectedRecipes.isEmpty &&
        mealTime > Date()
    }

    // MARK: - Actions

    private func saveDinnerParty() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedDescription = description.trimmingCharacters(in: .whitespaces)

        if let party = party {
            // Update existing party
            party.name = trimmedName
            party.desc = trimmedDescription.isEmpty ? nil : trimmedDescription
            party.guestCount = guestCount
            party.mealTime = mealTime
            party.lastModified = Date()

            // Update recipes
            party.recipes?.removeAll()

        } else {
            // Create new party
            let newParty = DinnerParty(
                name: trimmedName,
                description: trimmedDescription.isEmpty ? nil : trimmedDescription,
                guestCount: guestCount,
                mealTime: mealTime
            )
            modelContext.insert(newParty)

            // Add recipes with calculated start times
            addRecipes(to: newParty)
        }

        do {
            try modelContext.save()

            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)

            AnalyticsService.shared.track(event: .recipeCreated, properties: [
                "type": "dinner_party",
                "guest_count": guestCount,
                "recipe_count": selectedRecipes.count
            ])

            ToastManager.shared.success(
                title: isEditing ? "Party updated" : "Party created"
            )

            dismiss()
        } catch {
            ToastManager.shared.error(
                title: "Failed to save",
                message: error.localizedDescription
            )
        }
    }

    private func addRecipes(to party: DinnerParty) {
        // Sort recipes by total time (prep + cook) in descending order
        let sortedRecipes = selectedRecipes.sorted {
            ($0.parsedPrepTime + $0.parsedCookTime) > ($1.parsedPrepTime + $1.parsedCookTime)
        }

        // Calculate start times for each recipe
        // The longest recipe starts first, shortest starts last
        var currentOffset = 0

        for recipe in sortedRecipes {
            let totalTime = recipe.parsedPrepTime + recipe.parsedCookTime
            let partyRecipe = DinnerPartyRecipe(
                recipe: recipe,
                startTimeOffset: totalTime,
                scalingFactor: Double(guestCount) / Double(recipe.servings?.extractNumber() ?? 4)
            )
            partyRecipe.dinnerParty = party
            modelContext.insert(partyRecipe)

            currentOffset += totalTime
        }
    }
}

// MARK: - Recipe Picker

struct RecipePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Recipe.title) private var allRecipes: [Recipe]

    @Binding var selectedRecipes: Set<Recipe>
    @State private var searchText = ""

    var filteredRecipes: [Recipe] {
        if searchText.isEmpty {
            return allRecipes
        }
        return allRecipes.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredRecipes, id: \.id) { recipe in
                    Button {
                        if selectedRecipes.contains(recipe) {
                            selectedRecipes.remove(recipe)
                        } else {
                            selectedRecipes.insert(recipe)
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(recipe.title)
                                    .font(HeirloomFonts.body)
                                    .foregroundStyle(HeirloomColors.primaryText)

                                if let prepTime = recipe.prepTime, let cookTime = recipe.cookTime {
                                    Text("\(prepTime) + \(cookTime)")
                                        .font(HeirloomFonts.caption2)
                                        .foregroundStyle(HeirloomColors.secondaryText)
                                }
                            }

                            Spacer()

                            if selectedRecipes.contains(recipe) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(HeirloomColors.familyGreen)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundStyle(Color.gray.opacity(0.3))
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .searchable(text: $searchText, prompt: "Search recipes")
            .navigationTitle("Select Recipes")
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

// MARK: - String Extension

extension String {
    func extractNumber() -> Int {
        let components = self.components(separatedBy: CharacterSet.decimalDigits.inverted)
        let numbers = components.compactMap { Int($0) }
        return numbers.first ?? 4
    }
}

// MARK: - Preview

#Preview {
    DinnerPartyEditorView()
        .modelContainer(for: DinnerParty.self, inMemory: true)
        .toastContainer()
}
