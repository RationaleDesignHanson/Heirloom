import Foundation
import SwiftData

#if DEBUG
/// In-app test harness for validating SwiftData functionality
/// Use this to verify behavior that can't be tested with XCTest due to infrastructure issues
@MainActor
class TestHarness {

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Test Runner

    func runAllTests() -> TestResults {
        var results = TestResults()

        Log.info("Starting Test Harness", category: .general)

        // Recipe Migration Tests
        results.add(testMigrationCreatesBaseVersion())
        results.add(testMigrationCopiesAllData())
        results.add(testMigrationIsIdempotent())
        results.add(testMigrationStats())

        // Recipe Model Tests
        results.add(testRecipeComputedProperties())
        results.add(testRecipeVersionRelationships())

        // Multi-Recipe Import Tests
        results.add(testMultiRecipeImport())

        Log.info("Test Results", category: .general, metadata: ["summary": results.summary])

        return results
    }

    // MARK: - Migration Tests

    private func testMigrationCreatesBaseVersion() -> TestResult {
        let test = TestResult(name: "Migration creates base version")

        do {
            // Create recipe without version
            let recipe = Recipe(title: "Test Recipe", sourceType: .manual)
            recipe.instructions = ["Step 1", "Step 2"]
            recipe.servings = "4 servings"
            modelContext.insert(recipe)
            try modelContext.save()

            // Verify no base version initially
            guard recipe.baseVersion == nil else {
                test.fail("Recipe shouldn't have base version before migration")
                return test
            }

            // Run migration
            let migrationService = RecipeMigrationService.shared
            let count = try migrationService.migrateRecipesToVersions(context: modelContext)

            // Verify base version created
            guard let baseVersion = recipe.baseVersion else {
                test.fail("Migration didn't create base version")
                cleanup(recipe)
                return test
            }

            guard baseVersion.isBaseVersion else {
                test.fail("Created version isn't marked as base version")
                cleanup(recipe)
                return test
            }

            guard recipe.selectedVersionID == baseVersion.id else {
                test.fail("Selected version not set to base version")
                cleanup(recipe)
                return test
            }

            test.pass("Base version created correctly (migrated \(count) recipe)")
            cleanup(recipe)

        } catch {
            test.fail("Error: \(error.localizedDescription)")
        }

        return test
    }

    private func testMigrationCopiesAllData() -> TestResult {
        let test = TestResult(name: "Migration copies all recipe data")

        do {
            // Create recipe with data
            let recipe = Recipe(title: "Complete Recipe", sourceType: .manual)
            recipe.instructions = ["Preheat", "Mix", "Bake"]
            recipe.servings = "6 servings"
            recipe.prepTime = "15 minutes"
            recipe.cookTime = "30 minutes"
            recipe.notes = "Family favorite"

            // Add ingredients
            for (index, text) in ["1 cup flour", "2 eggs", "1/2 cup sugar"].enumerated() {
                let parsed = IngredientParser.parse(text)
                let ingredient = Ingredient(
                    originalText: text,
                    name: parsed.name,
                    quantity: parsed.quantity,
                    unit: parsed.unit,
                    category: .other,
                    orderIndex: index
                )
                ingredient.recipe = recipe
                modelContext.insert(ingredient)
            }

            modelContext.insert(recipe)
            try modelContext.save()

            let originalIngredients = recipe.ingredients?.map { $0.originalText } ?? []

            // Migrate
            let migrationService = RecipeMigrationService.shared
            _ = try migrationService.migrateRecipesToVersions(context: modelContext)

            // Verify all data copied
            guard let baseVersion = recipe.baseVersion else {
                test.fail("No base version created")
                cleanup(recipe)
                return test
            }

            guard baseVersion.title == recipe.title else {
                test.fail("Title not copied (expected '\(recipe.title)', got '\(baseVersion.title ?? "nil")')")
                cleanup(recipe)
                return test
            }

            guard baseVersion.instructions == recipe.instructions else {
                test.fail("Instructions not copied correctly")
                cleanup(recipe)
                return test
            }

            guard baseVersion.ingredients?.count == originalIngredients.count else {
                test.fail("Ingredient count mismatch (expected \(originalIngredients.count), got \(baseVersion.ingredients?.count ?? 0))")
                cleanup(recipe)
                return test
            }

            guard baseVersion.servings == recipe.servings else {
                test.fail("Servings not copied")
                cleanup(recipe)
                return test
            }

            guard baseVersion.prepTime == recipe.prepTime else {
                test.fail("Prep time not copied")
                cleanup(recipe)
                return test
            }

            guard baseVersion.cookTime == recipe.cookTime else {
                test.fail("Cook time not copied")
                cleanup(recipe)
                return test
            }

            test.pass("All recipe data copied to base version")
            cleanup(recipe)

        } catch {
            test.fail("Error: \(error.localizedDescription)")
        }

        return test
    }

    private func testMigrationIsIdempotent() -> TestResult {
        let test = TestResult(name: "Migration is idempotent")

        do {
            // Create and migrate recipe
            let recipe = Recipe(title: "Idempotent Test", sourceType: .manual)
            recipe.instructions = ["Step 1"]
            modelContext.insert(recipe)
            try modelContext.save()

            let migrationService = RecipeMigrationService.shared

            // First migration
            let firstCount = try migrationService.migrateRecipesToVersions(context: modelContext)
            let firstVersionCount = recipe.versions?.count ?? 0

            guard firstCount == 1 else {
                test.fail("First migration should migrate 1 recipe, got \(firstCount)")
                cleanup(recipe)
                return test
            }

            // Second migration
            let secondCount = try migrationService.migrateRecipesToVersions(context: modelContext)
            let secondVersionCount = recipe.versions?.count ?? 0

            guard secondCount == 0 else {
                test.fail("Second migration should migrate 0 recipes, got \(secondCount)")
                cleanup(recipe)
                return test
            }

            guard firstVersionCount == secondVersionCount else {
                test.fail("Version count changed (was \(firstVersionCount), now \(secondVersionCount))")
                cleanup(recipe)
                return test
            }

            guard secondVersionCount == 1 else {
                test.fail("Should have exactly 1 version, got \(secondVersionCount)")
                cleanup(recipe)
                return test
            }

            test.pass("Migration is idempotent (no duplicate versions)")
            cleanup(recipe)

        } catch {
            test.fail("Error: \(error.localizedDescription)")
        }

        return test
    }

    private func testMigrationStats() -> TestResult {
        let test = TestResult(name: "Migration stats are accurate")

        do {
            // Create mix of recipes
            let migratedRecipe = Recipe(title: "Already Migrated", sourceType: .manual)
            let unmigr atedRecipe = Recipe(title: "Needs Migration", sourceType: .manual)

            modelContext.insert(migratedRecipe)
            modelContext.insert(unmigratedRecipe)
            try modelContext.save()

            // Migrate only one
            let migrationService = RecipeMigrationService.shared
            _ = try migrationService.migrateRecipesToVersions(context: modelContext)

            // Now both should be migrated - clear versions on one to simulate unmigrated
            if let versions = unmigratedRecipe.versions {
                for version in versions {
                    modelContext.delete(version)
                }
            }
            unmigratedRecipe.versions = []
            unmigratedRecipe.selectedVersionID = nil
            try modelContext.save()

            // Get stats
            let stats = try migrationService.getMigrationStats(context: modelContext)

            guard stats.totalRecipes == 2 else {
                test.fail("Total recipes should be 2, got \(stats.totalRecipes)")
                cleanup(migratedRecipe)
                cleanup(unmigratedRecipe)
                return test
            }

            guard stats.recipesWithVersions == 1 else {
                test.fail("Recipes with versions should be 1, got \(stats.recipesWithVersions)")
                cleanup(migratedRecipe)
                cleanup(unmigratedRecipe)
                return test
            }

            guard stats.recipesNeedingMigration == 1 else {
                test.fail("Recipes needing migration should be 1, got \(stats.recipesNeedingMigration)")
                cleanup(migratedRecipe)
                cleanup(unmigratedRecipe)
                return test
            }

            test.pass("Migration stats calculated correctly")
            cleanup(migratedRecipe)
            cleanup(unmigratedRecipe)

        } catch {
            test.fail("Error: \(error.localizedDescription)")
        }

        return test
    }

    // MARK: - Recipe Model Tests

    private func testRecipeComputedProperties() -> TestResult {
        let test = TestResult(name: "Recipe computed properties work correctly")

        do {
            let recipe = Recipe(title: "Property Test", sourceType: .manual)

            // Create base version
            let baseVersion = RecipeVersion(
                creatorUserID: "user1",
                creatorDisplayName: "Original Cook",
                creationYear: "2020",
                isBaseVersion: true
            )
            baseVersion.title = recipe.title
            modelContext.insert(baseVersion)

            recipe.versions = [baseVersion]
            recipe.selectedVersionID = baseVersion.id
            modelContext.insert(recipe)
            try modelContext.save()

            // Test baseVersion
            guard recipe.baseVersion?.id == baseVersion.id else {
                test.fail("baseVersion computed property incorrect")
                cleanup(recipe)
                return test
            }

            // Test generationLabel with one version
            guard recipe.generationLabel == "Original" else {
                test.fail("generationLabel should be 'Original' for 1 version, got '\(recipe.generationLabel)'")
                cleanup(recipe)
                return test
            }

            // Add contributor version
            let contributorVersion = RecipeVersion(
                creatorUserID: "user2",
                creatorDisplayName: "Contributor",
                creationYear: "2024"
            )
            contributorVersion.title = recipe.title
            modelContext.insert(contributorVersion)
            recipe.versions?.append(contributorVersion)
            try modelContext.save()

            // Test generationLabel with two versions
            guard recipe.generationLabel == "2 Generations" else {
                test.fail("generationLabel should be '2 Generations', got '\(recipe.generationLabel)'")
                cleanup(recipe)
                return test
            }

            // Test hasMultipleVersions
            guard recipe.hasMultipleVersions == true else {
                test.fail("hasMultipleVersions should be true")
                cleanup(recipe)
                return test
            }

            test.pass("All computed properties work correctly")
            cleanup(recipe)

        } catch {
            test.fail("Error: \(error.localizedDescription)")
        }

        return test
    }

    private func testRecipeVersionRelationships() -> TestResult {
        let test = TestResult(name: "Recipe-Version relationships maintained")

        do {
            let recipe = Recipe(title: "Relationship Test", sourceType: .manual)

            let version1 = RecipeVersion(
                creatorUserID: "u1",
                creatorDisplayName: "Cook 1",
                creationYear: "2020",
                isBaseVersion: true
            )
            let version2 = RecipeVersion(
                creatorUserID: "u2",
                creatorDisplayName: "Cook 2",
                creationYear: "2024"
            )

            modelContext.insert(version1)
            modelContext.insert(version2)
            recipe.versions = [version1, version2]
            modelContext.insert(recipe)
            try modelContext.save()

            // Verify relationship
            guard recipe.versions?.count == 2 else {
                test.fail("Recipe should have 2 versions, has \(recipe.versions?.count ?? 0)")
                cleanup(recipe)
                return test
            }

            guard recipe.baseVersion?.id == version1.id else {
                test.fail("Base version not correctly identified")
                cleanup(recipe)
                return test
            }

            let contributors = recipe.contributorVersions
            guard contributors.count == 1 else {
                test.fail("Should have 1 contributor version, has \(contributors.count)")
                cleanup(recipe)
                return test
            }

            guard contributors.first?.id == version2.id else {
                test.fail("Contributor version not correctly identified")
                cleanup(recipe)
                return test
            }

            test.pass("Recipe-Version relationships work correctly")
            cleanup(recipe)

        } catch {
            test.fail("Error: \(error.localizedDescription)")
        }

        return test
    }

    // MARK: - Integration Tests

    private func testMultiRecipeImport() -> TestResult {
        let test = TestResult(name: "Multi-recipe import flow")

        do {
            // Simulate OCR extraction
            let extractor = AIRecipeExtractor()
            let extractedRecipes = [
                AIRecipeExtractor.ExtractedRecipe(
                    title: "Recipe 1",
                    servings: "4",
                    prepTime: "10 min",
                    cookTime: "20 min",
                    ingredients: ["1 cup flour", "2 eggs"],
                    instructions: ["Mix", "Bake"],
                    notes: "Test recipe",
                    confidence: 0.95
                ),
                AIRecipeExtractor.ExtractedRecipe(
                    title: "Recipe 2",
                    servings: "2",
                    prepTime: "5 min",
                    cookTime: "15 min",
                    ingredients: ["1 cup milk"],
                    instructions: ["Heat"],
                    notes: nil,
                    confidence: 0.88
                )
            ]

            // Convert to Recipe models
            var recipes: [Recipe] = []
            for extracted in extractedRecipes {
                let recipe = Recipe(title: extracted.title, sourceType: .scan)
                recipe.servings = extracted.servings
                recipe.prepTime = extracted.prepTime
                recipe.cookTime = extracted.cookTime
                recipe.instructions = extracted.instructions
                recipe.notes = extracted.notes

                // Add ingredients
                for (index, ingredientText) in extracted.ingredients.enumerated() {
                    let parsed = IngredientParser.parse(ingredientText)
                    let ingredient = Ingredient(
                        originalText: ingredientText,
                        name: parsed.name,
                        quantity: parsed.quantity,
                        unit: parsed.unit,
                        category: .other,
                        orderIndex: index
                    )
                    ingredient.recipe = recipe
                    modelContext.insert(ingredient)
                }

                modelContext.insert(recipe)
                recipes.append(recipe)
            }

            try modelContext.save()

            // Verify recipes saved
            guard recipes.count == 2 else {
                test.fail("Should have 2 recipes")
                recipes.forEach { cleanup($0) }
                return test
            }

            guard recipes[0].ingredients?.count == 2 else {
                test.fail("Recipe 1 should have 2 ingredients")
                recipes.forEach { cleanup($0) }
                return test
            }

            guard recipes[1].ingredients?.count == 1 else {
                test.fail("Recipe 2 should have 1 ingredient")
                recipes.forEach { cleanup($0) }
                return test
            }

            // Run migration on imported recipes
            let migrationService = RecipeMigrationService.shared
            let migrated = try migrationService.migrateRecipesToVersions(context: modelContext)

            guard migrated == 2 else {
                test.fail("Should have migrated 2 recipes, migrated \(migrated)")
                recipes.forEach { cleanup($0) }
                return test
            }

            guard recipes.allSatisfy({ $0.baseVersion != nil }) else {
                test.fail("All recipes should have base versions")
                recipes.forEach { cleanup($0) }
                return test
            }

            test.pass("Multi-recipe import flow works end-to-end")
            recipes.forEach { cleanup($0) }

        } catch {
            test.fail("Error: \(error.localizedDescription)")
        }

        return test
    }

    // MARK: - Helpers

    private func cleanup(_ recipe: Recipe) {
        if let versions = recipe.versions {
            for version in versions {
                modelContext.delete(version)
            }
        }
        if let ingredients = recipe.ingredients {
            for ingredient in ingredients {
                modelContext.delete(ingredient)
            }
        }
        modelContext.delete(recipe)
        try? modelContext.save()
    }
}

// MARK: - Test Result Types

struct TestResult {
    let name: String
    var passed: Bool = false
    var message: String = ""

    mutating func pass(_ message: String = "") {
        self.passed = true
        self.message = message
        Log.info("Test passed", category: .general, metadata: ["test": name, "message": message])
    }

    mutating func fail(_ message: String) {
        self.passed = false
        self.message = message
        Log.error("Test failed", category: .general, metadata: ["test": name, "message": message])
    }
}

struct TestResults {
    private var results: [TestResult] = []

    mutating func add(_ result: TestResult) {
        results.append(result)
    }

    var passed: Int {
        results.filter { $0.passed }.count
    }

    var failed: Int {
        results.filter { !$0.passed }.count
    }

    var total: Int {
        results.count
    }

    var summary: String {
        let passRate = total > 0 ? (Double(passed) / Double(total) * 100) : 0
        return """

        Total: \(total) tests
        Passed: \(passed) (\(String(format: "%.1f", passRate))%)
        Failed: \(failed)

        \(passed == total ? "🎉 All tests passed!" : "⚠️  Some tests failed")
        """
    }

    var allPassed: Bool {
        failed == 0
    }
}
#endif
