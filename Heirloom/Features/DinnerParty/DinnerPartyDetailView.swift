import SwiftUI
import SwiftData

struct DinnerPartyDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.firebaseSync) private var firebaseSync

    private var toastManager: ToastManager { ServiceContainer.shared.resolve(ToastManager.self) }
    private var backendConfig: BackendConfig { ServiceContainer.shared.resolve(BackendConfig.self) }
    private var shoppingSync: DinnerPartyShoppingSync { ServiceContainer.shared.resolve(DinnerPartyShoppingSync.self) }

    @Bindable var party: DinnerParty
    @State private var showEditSheet = false

    var sortedRecipes: [DinnerPartyRecipe] {
        (party.recipes ?? []).sorted { $0.startTimeOffset > $1.startTimeOffset }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: HeirloomSpacing.lg) {
                    // Header Card
                    headerCard

                    // Timeline
                    timelineSection

                    // Shopping List Button
                    shoppingListButton

                    // Active Cooking Button
                    if party.isInProgress || party.isUpcoming {
                        startCookingButton
                    }
                }
                .padding()
            }
            .background(HeirloomColors.appBackground)
            .navigationTitle(party.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showEditSheet = true
                        } label: {
                            Label("Edit Party", systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            deleteParty()
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showEditSheet) {
                DinnerPartyEditorView(party: party)
            }
        }
    }

    // MARK: - Header Card

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
            // Guest count and meal time
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "person.2.fill")
                        .font(.title3)
                    Text("\(party.guestCount)")
                        .font(HeirloomFonts.title2)
                }
                .foregroundStyle(HeirloomColors.familyGreen)

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(party.mealTime.formatted(date: .abbreviated, time: .omitted))
                        .font(HeirloomFonts.bodyBold)
                    Text(party.mealTime.formatted(date: .omitted, time: .shortened))
                        .font(HeirloomFonts.body)
                }
                .foregroundStyle(HeirloomColors.primaryText)
            }

            if let description = party.desc {
                Divider()
                Text(description)
                    .font(HeirloomFonts.body)
                    .foregroundStyle(HeirloomColors.secondaryText)
            }

            Divider()

            // Stats
            HStack(spacing: HeirloomSpacing.xl) {
                statItem(icon: "fork.knife", value: "\(party.recipeCount)", label: "recipes")
                statItem(icon: "clock.fill", value: totalTimeDisplay, label: "total time")

                if let startTime = party.earliestStartTime {
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Start cooking")
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(HeirloomColors.secondaryText)
                        Text(startTime.formatted(date: .omitted, time: .shortened))
                            .font(HeirloomFonts.bodyBold)
                            .foregroundStyle(HeirloomColors.tomato)
                    }
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    // MARK: - Timeline Section

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
            Text("Cooking Timeline")
                .font(HeirloomFonts.title3)
                .foregroundStyle(HeirloomColors.primaryText)

            ForEach(sortedRecipes, id: \.id) { partyRecipe in
                if let recipe = partyRecipe.recipe {
                    timelineItem(recipe: recipe, partyRecipe: partyRecipe)
                }
            }
        }
    }

    private func timelineItem(recipe: Recipe, partyRecipe: DinnerPartyRecipe) -> some View {
        HStack(alignment: .top, spacing: HeirloomSpacing.md) {
            // Timeline marker
            VStack(spacing: 4) {
                Circle()
                    .fill(partyRecipe.isCompleted ? HeirloomColors.familyGreen : HeirloomColors.tomato)
                    .frame(width: 12, height: 12)

                if sortedRecipes.last?.id != partyRecipe.id {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(height: 60)

            // Recipe card
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(recipe.title)
                            .font(HeirloomFonts.bodyBold)
                            .foregroundStyle(HeirloomColors.primaryText)

                        if let startTime = partyRecipe.startTime {
                            Text("Start at \(startTime.formatted(date: .omitted, time: .shortened))")
                                .font(HeirloomFonts.caption1)
                                .foregroundStyle(HeirloomColors.secondaryText)
                        }
                    }

                    Spacer()

                    if partyRecipe.isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(HeirloomColors.familyGreen)
                            .font(.title3)
                    }
                }

                // Timing details
                HStack(spacing: HeirloomSpacing.md) {
                    if let prepTime = recipe.prepTime {
                        Label(prepTime, systemImage: "knife.chef")
                            .font(HeirloomFonts.caption2)
                            .foregroundStyle(HeirloomColors.secondaryText)
                    }

                    if let cookTime = recipe.cookTime {
                        Label(cookTime, systemImage: "flame")
                            .font(HeirloomFonts.caption2)
                            .foregroundStyle(HeirloomColors.secondaryText)
                    }

                    if partyRecipe.scalingFactor != 1.0 {
                        Text(String(format: "%.1fx", partyRecipe.scalingFactor))
                            .font(HeirloomFonts.caption2)
                            .foregroundStyle(HeirloomColors.amber)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(HeirloomColors.amber.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.03), radius: 4)
        }
    }

    // MARK: - Shopping List Button

    private var shoppingListButton: some View {
        NavigationLink {
            DinnerPartyShoppingListView(party: party)
        } label: {
            HStack {
                Image(systemName: "cart.fill")
                    .font(.title3)
                Text("View Shopping List")
                    .font(HeirloomFonts.bodyBold)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(HeirloomColors.secondaryText)
            }
            .foregroundStyle(HeirloomColors.primaryText)
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 4)
        }
    }

    // MARK: - Start Cooking Button

    private var startCookingButton: some View {
        NavigationLink {
            DinnerPartyActiveView(party: party)
        } label: {
            HStack {
                Image(systemName: "flame.fill")
                    .font(.title3)
                Text(party.isInProgress ? "Continue Cooking" : "Start Cooking")
                    .font(HeirloomFonts.title3)
                Spacer()
                Image(systemName: "arrow.right.circle.fill")
                    .font(.title2)
            }
            .foregroundStyle(.white)
            .padding()
            .background(
                LinearGradient(
                    colors: [HeirloomColors.tomato, HeirloomColors.tomato.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
            .shadow(color: HeirloomColors.tomato.opacity(0.3), radius: 12, y: 6)
        }
    }

    // MARK: - Helpers

    private func statItem(icon: String, value: String, label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(HeirloomColors.secondaryText)
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(HeirloomFonts.bodyBold)
                    .foregroundStyle(HeirloomColors.primaryText)
                Text(label)
                    .font(HeirloomFonts.caption2)
                    .foregroundStyle(HeirloomColors.secondaryText)
            }
        }
    }

    private var totalTimeDisplay: String {
        let total = party.totalPrepTime + party.totalCookTime
        if total >= 60 {
            let hours = total / 60
            let minutes = total % 60
            if minutes > 0 {
                return "\(hours)h \(minutes)m"
            }
            return "\(hours)h"
        }
        return "\(total)m"
    }

    // MARK: - Actions

    private func deleteParty() {
        let partyId = party.id

        // Clean up shopping cart before deletion
        shoppingSync.cleanupShoppingCart(party, context: modelContext)

        modelContext.delete(party)

        do {
            try modelContext.save()

            // Delete from Firebase if active
            if backendConfig.isFirebaseActive {
                Task {
                    do {
                        try await firebaseSync.deleteDinnerParty(partyId)
                        Log.info("Dinner party deleted from Firebase", category: .firebase, metadata: ["partyId": partyId])
                    } catch {
                        Log.warning("Failed to delete dinner party from Firebase", category: .firebase, metadata: ["error": error.localizedDescription, "partyId": partyId])
                    }
                }
            }

            toastManager.success(title: "Dinner party deleted")
            dismiss()
        } catch {
            toastManager.error(title: "Failed to delete", message: error.localizedDescription)
        }
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: DinnerParty.self, configurations: config)

    let party = DinnerParty(name: "Thanksgiving Dinner", guestCount: 12, mealTime: Date().addingTimeInterval(7200))
    container.mainContext.insert(party)

    return DinnerPartyDetailView(party: party)
        .modelContainer(container)
        .toastContainer()
}
