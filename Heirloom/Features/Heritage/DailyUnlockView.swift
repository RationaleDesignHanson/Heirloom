import SwiftUI
import SwiftData

/// View shown when user unlocks daily heritage recipes
struct DailyUnlockView: View {
    let unlockedRecipeIds: [String]
    let currentBatch: Int
    let totalBatches: Int
    let onDismiss: () -> Void

    @Environment(\.modelContext) private var modelContext

    @State private var showConfetti = false
    @State private var recipes: [Recipe] = []

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color.orange.opacity(0.1), Color.yellow.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 32) {
                        // Header
                        VStack(spacing: 16) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 60))
                                .foregroundStyle(.orange)
                                .symbolEffect(.bounce, value: showConfetti)

                            Text("New Recipes Unlocked!")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .multilineTextAlignment(.center)

                            Text("You've unlocked \(unlockedRecipeIds.count) new heritage recipes")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 40)

                        // Progress
                        VStack(spacing: 12) {
                            Text("Collection Progress")
                                .font(.headline)
                                .foregroundStyle(.secondary)

                            HStack(spacing: 8) {
                                Text("Day \(currentBatch) of \(totalBatches)")
                                    .font(.title2.bold())
                                Spacer()
                                Text("\(Int(Double(currentBatch) / Double(totalBatches) * 100))%")
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                            }

                            ProgressView(value: Double(currentBatch), total: Double(totalBatches))
                                .tint(.orange)
                                .scaleEffect(y: 2)
                        }
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal)

                        // Recipe cards
                        if !recipes.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Today's Unlocked Recipes")
                                    .font(.headline)
                                    .padding(.horizontal)

                                ForEach(recipes) { recipe in
                                    RecipeUnlockCard(recipe: recipe)
                                }
                            }
                        } else {
                            ProgressView("Loading recipes...")
                                .padding()
                        }

                        // Dismiss button
                        Button(action: onDismiss) {
                            Text("Start Cooking!")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(.orange, in: RoundedRectangle(cornerRadius: 16))
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 32)
                    }
                }
            }
            .navigationTitle("Daily Unlock")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        onDismiss()
                    }
                }
            }
        }
        .task {
            await loadRecipes()
            showConfetti = true
        }
    }

    private func loadRecipes() async {
        let descriptor = FetchDescriptor<Recipe>(
            predicate: #Predicate { recipe in
                recipe.isHeritageRecipe == true &&
                recipe.heritageCollectionId != nil
            }
        )

        do {
            let allRecipes = try modelContext.fetch(descriptor)
            // Filter to only the newly unlocked ones
            recipes = allRecipes.filter { recipe in
                if let heritageId = recipe.heritageCollectionId {
                    return unlockedRecipeIds.contains(heritageId)
                }
                return false
            }

            Log.info("Loaded unlocked recipes", category: .database, metadata: ["count": recipes.count])
        } catch {
            Log.error("Failed to load unlocked recipes", category: .database, metadata: ["error": error.localizedDescription])
        }
    }
}

// MARK: - Recipe Unlock Card

struct RecipeUnlockCard: View {
    let recipe: Recipe

    private var imageStorageService: ImageStorageService {
        ServiceContainer.shared.resolve(ImageStorageService.self)
    }

    @State private var recipeImage: UIImage?

    var body: some View {
        HStack(spacing: 16) {
            // Recipe image
            Group {
                if let image = recipeImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .overlay {
                            Image(systemName: "fork.knife")
                                .font(.title)
                                .foregroundStyle(.gray)
                        }
                }
            }
            .frame(width: 80, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Recipe info
            VStack(alignment: .leading, spacing: 6) {
                Text(recipe.title)
                    .font(.headline)
                    .lineLimit(2)

                if let historicalContext = recipe.historicalContext {
                    Text(historicalContext)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 12) {
                    if let prepTime = recipe.prepTime {
                        Label(prepTime, systemImage: "clock")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let servings = recipe.servings {
                        Label(servings, systemImage: "person.2")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            Image(systemName: "lock.open.fill")
                .font(.title2)
                .foregroundStyle(.orange)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
        .task {
            await loadImage()
        }
    }

    private func loadImage() async {
        guard let imageFileName = recipe.imageFileName else { return }
        recipeImage = await imageStorageService.loadImage(fileName: imageFileName)
    }
}

// MARK: - Preview

#Preview {
    DailyUnlockView(
        unlockedRecipeIds: ["recipe1", "recipe2", "recipe3", "recipe4", "recipe5"],
        currentBatch: 3,
        totalBatches: 20,
        onDismiss: {}
    )
    .modelContainer(for: Recipe.self, inMemory: true)
}
