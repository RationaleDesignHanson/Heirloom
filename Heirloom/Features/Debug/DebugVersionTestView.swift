import SwiftUI
import SwiftData

/// Debug menu for testing version features
/// ONLY for development - remove before production
#if DEBUG
struct DebugVersionTestView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var statusMessage = ""
    @State private var showSuccess = false

    var body: some View {
        NavigationStack {
            List {
                Section("Test 5: Create Sample Recipe") {
                    Button("Create Multi-Version Recipe") {
                        createSampleRecipe()
                    }
                }

                Section("Test 1: Migration") {
                    Button("Run Migration") {
                        runMigration()
                    }

                    Button("Check Migration Stats") {
                        checkMigrationStats()
                    }
                }

                Section("Status") {
                    if !statusMessage.isEmpty {
                        Text(statusMessage)
                            .font(HeirloomFonts.caption1)
                            .foregroundColor(showSuccess ? .green : .red)
                    }
                }
            }
            .navigationTitle("Version Testing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Test 5: Create Sample Recipe

    private func createSampleRecipe() {
        do {
            let recipe = Recipe(title: "Grandma's Lasagna")
            recipe.instructions = [
                "Preheat oven to 375°F",
                "Brown ground beef",
                "Layer noodles, meat, cheese",
                "Bake 45 minutes"
            ]

            // Create base version (Grandma)
            let base = RecipeVersion(
                creatorUserID: "original",
                creatorDisplayName: "Grandma Kay",
                creationYear: "1987",
                isBaseVersion: true
            )
            base.title = recipe.title
            base.ingredients = ["2 lbs ground beef", "1 box lasagna noodles", "32 oz ricotta"]
            base.instructions = recipe.instructions

            // Create Mom's version with changes
            let mom = RecipeVersion(
                creatorUserID: "user-mom",
                creatorDisplayName: "Mom",
                creationYear: "2015"
            )
            mom.title = recipe.title
            mom.ingredients = ["2 lbs ground turkey", "1 box lasagna noodles", "32 oz ricotta"] // Changed!
            mom.instructions = recipe.instructions
            mom.recordChange(field: "ingredient-0", from: "2 lbs ground beef", to: "2 lbs ground turkey")
            mom.notes = "I use turkey instead — healthier!"
            mom.timesCooked = 5

            // Create Your version
            let you = RecipeVersion(
                creatorUserID: "user-you",
                creatorDisplayName: "You",
                creationYear: "2025"
            )
            you.title = "My Amazing Lasagna" // Changed!
            you.ingredients = mom.ingredients
            you.instructions = [
                "Preheat oven to 375°F",
                "Brown ground turkey with garlic", // Changed!
                "Layer noodles, meat, cheese",
                "Bake 45 minutes"
            ]
            you.recordChange(field: "title", from: recipe.title, to: "My Amazing Lasagna")
            you.recordChange(field: "instruction-1", from: "Brown ground beef", to: "Brown ground turkey with garlic")
            you.notes = "Added garlic for extra flavor"

            recipe.versions = [base, mom, you]
            recipe.selectedVersionID = you.id
            recipe.sharingPermission = .heirloom

            modelContext.insert(recipe)
            try modelContext.save()

            statusMessage = "✅ Created 'Grandma's Lasagna' with 3 versions (Grandma, Mom, You)"
            showSuccess = true

        } catch {
            statusMessage = "❌ Error: \(error.localizedDescription)"
            showSuccess = false
        }
    }

    // MARK: - Test 1: Migration

    private func runMigration() {
        do {
            let migrated = try RecipeMigrationService.shared.migrateRecipesToVersions(context: modelContext)
            statusMessage = "✅ Migrated \(migrated) recipes to version system"
            showSuccess = true
        } catch {
            statusMessage = "❌ Migration error: \(error.localizedDescription)"
            showSuccess = false
        }
    }

    private func checkMigrationStats() {
        do {
            let stats = try RecipeMigrationService.shared.getMigrationStats(context: modelContext)
            statusMessage = """
            📊 Migration Stats:
            Total recipes: \(stats.totalRecipes)
            With versions: \(stats.recipesWithVersions)
            Need migration: \(stats.recipesNeedingMigration)
            Progress: \(Int(stats.migrationProgress * 100))%
            """
            showSuccess = true
        } catch {
            statusMessage = "❌ Stats error: \(error.localizedDescription)"
            showSuccess = false
        }
    }
}

#Preview {
    DebugVersionTestView()
        .modelContainer(for: [Recipe.self, RecipeVersion.self], inMemory: true)
}
#endif
