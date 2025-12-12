import SwiftUI
import SwiftData

struct DinnerPartyActiveView: View {
    @Environment(\.dismiss) private var dismiss

    @Bindable var party: DinnerParty
    @State private var selectedRecipe: DinnerPartyRecipe?
    @State private var currentTime = Date()

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var activeRecipes: [DinnerPartyRecipe] {
        (party.recipes ?? []).filter { $0.shouldStartNow }
    }

    var upcomingRecipes: [DinnerPartyRecipe] {
        (party.recipes ?? []).filter {
            guard let startTime = $0.startTime else { return false }
            return startTime > currentTime && !$0.isCompleted
        }.sorted { $0.startTimeOffset > $1.startTimeOffset }
    }

    var completedRecipes: [DinnerPartyRecipe] {
        (party.recipes ?? []).filter { $0.isCompleted }
    }

    var progress: Double {
        let total = party.recipeCount
        guard total > 0 else { return 0 }
        return Double(completedRecipes.count) / Double(total)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: HeirloomSpacing.lg) {
                    // Progress Card
                    progressCard

                    // Active Recipes
                    if !activeRecipes.isEmpty {
                        sectionView(title: "Cook Now", recipes: activeRecipes, color: HeirloomColors.tomato)
                    }

                    // Upcoming Recipes
                    if !upcomingRecipes.isEmpty {
                        sectionView(title: "Coming Up", recipes: upcomingRecipes, color: HeirloomColors.amber)
                    }

                    // Completed Recipes
                    if !completedRecipes.isEmpty {
                        sectionView(title: "Completed", recipes: completedRecipes, color: HeirloomColors.familyGreen)
                    }
                }
                .padding()
            }
            .background(HeirloomColors.appBackground)
            .navigationTitle("Cooking Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onReceive(timer) { _ in
                currentTime = Date()
            }
            .sheet(item: $selectedRecipe) { partyRecipe in
                if let recipe = partyRecipe.recipe {
                    RecipeCookingSheetView(recipe: recipe, partyRecipe: partyRecipe)
                }
            }
        }
    }

    // MARK: - Progress Card

    private var progressCard: some View {
        VStack(spacing: HeirloomSpacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(party.name)
                        .font(HeirloomFonts.title2)
                        .foregroundStyle(HeirloomColors.primaryText)

                    Text("Meal at \(party.mealTime.formatted(date: .omitted, time: .shortened))")
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(HeirloomColors.secondaryText)
                }

                Spacer()

                Text("\(completedRecipes.count)/\(party.recipeCount)")
                    .font(HeirloomFonts.title2)
                    .foregroundStyle(HeirloomColors.familyGreen)
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(height: 12)
                        .cornerRadius(6)

                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [HeirloomColors.familyGreen, HeirloomColors.familyGreen.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progress, height: 12)
                        .cornerRadius(6)
                        .animation(.easeInOut, value: progress)
                }
            }
            .frame(height: 12)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    // MARK: - Section View

    private func sectionView(title: String, recipes: [DinnerPartyRecipe], color: Color) -> some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
            Text(title)
                .font(HeirloomFonts.title3)
                .foregroundStyle(HeirloomColors.primaryText)

            ForEach(recipes, id: \.id) { partyRecipe in
                if let recipe = partyRecipe.recipe {
                    recipeCard(recipe: recipe, partyRecipe: partyRecipe, accentColor: color)
                }
            }
        }
    }

    private func recipeCard(recipe: Recipe, partyRecipe: DinnerPartyRecipe, accentColor: Color) -> some View {
        Button {
            selectedRecipe = partyRecipe
        } label: {
            HStack(spacing: HeirloomSpacing.md) {
                // Status indicator
                Circle()
                    .fill(accentColor)
                    .frame(width: 12, height: 12)

                VStack(alignment: .leading, spacing: 4) {
                    Text(recipe.title)
                        .font(HeirloomFonts.bodyBold)
                        .foregroundStyle(HeirloomColors.primaryText)

                    if partyRecipe.startTime != nil {
                        if partyRecipe.shouldStartNow {
                            Text("Ready to cook")
                                .font(HeirloomFonts.caption1)
                                .foregroundStyle(accentColor)
                        } else if let timeUntil = partyRecipe.timeUntilStart, timeUntil > 0 {
                            let minutes = Int(timeUntil / 60)
                            Text("Start in \(minutes)m")
                                .font(HeirloomFonts.caption1)
                                .foregroundStyle(HeirloomColors.secondaryText)
                        } else {
                            Text("Completed")
                                .font(HeirloomFonts.caption1)
                                .foregroundStyle(HeirloomColors.familyGreen)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(HeirloomColors.secondaryText)
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.03), radius: 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Recipe Cooking Sheet

struct RecipeCookingSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let recipe: Recipe
    @Bindable var partyRecipe: DinnerPartyRecipe

    var body: some View {
        NavigationStack {
            CookingModeView(recipe: recipe)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") {
                            dismiss()
                        }
                    }

                    ToolbarItem(placement: .primaryAction) {
                        Button(partyRecipe.isCompleted ? "Mark Incomplete" : "Mark Complete") {
                            partyRecipe.isCompleted.toggle()

                            do {
                                try modelContext.save()

                                let generator = UINotificationFeedbackGenerator()
                                generator.notificationOccurred(.success)

                                ToastManager.shared.success(
                                    title: partyRecipe.isCompleted ? "Recipe completed" : "Marked incomplete"
                                )
                            } catch {
                                ToastManager.shared.error(
                                    title: "Failed to update",
                                    message: error.localizedDescription
                                )
                            }
                        }
                    }
                }
        }
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: DinnerParty.self, configurations: config)

    let party = DinnerParty(name: "Dinner Party", guestCount: 8, mealTime: Date().addingTimeInterval(3600))
    container.mainContext.insert(party)

    return DinnerPartyActiveView(party: party)
        .modelContainer(container)
        .toastContainer()
}
