import Testing
import Foundation

@testable import Heirloom

@Suite("Recipe Provenance Tests")
struct RecipeProvenanceTests {

    // MARK: - Ensure Provenance Migration Tests

    @Test("ensureProvenance creates provenance when nil")
    func testEnsureProvenance_WhenNil_CreatesProvenance() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe", sourceType: .manual)
        #expect(recipe.provenance == nil)

        // Act
        recipe.ensureProvenance()

        // Assert
        #expect(recipe.provenance != nil)
    }

    @Test("ensureProvenance does not replace existing provenance")
    func testEnsureProvenance_WithExisting_DoesNotReplace() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        let existingProvenance = ProvenanceMetadata(
            sourceType: .imported,
            sourceURL: "https://example.com",
            sourceAttribution: "Example Site",
            generation: 2
        )
        recipe.provenance = existingProvenance

        // Act
        recipe.ensureProvenance()

        // Assert
        #expect(recipe.provenance?.generation == 2)
        #expect(recipe.provenance?.sourceAttribution == "Example Site")
    }

    @Test("ensureProvenance maps manual sourceType to userCreated")
    func testEnsureProvenance_ManualSource_MapsToUserCreated() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe", sourceType: .manual)

        // Act
        recipe.ensureProvenance()

        // Assert
        #expect(recipe.provenance?.sourceType == .userCreated)
    }

    @Test("ensureProvenance maps url sourceType to imported")
    func testEnsureProvenance_URLSource_MapsToImported() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe", sourceType: .url)
        recipe.sourceURL = "https://example.com/recipe"

        // Act
        recipe.ensureProvenance()

        // Assert
        #expect(recipe.provenance?.sourceType == .imported)
        #expect(recipe.provenance?.sourceURL == "https://example.com/recipe")
    }

    @Test("ensureProvenance maps cookbook sourceType to scanned")
    func testEnsureProvenance_CookbookSource_MapsToScanned() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe", sourceType: .cookbook)

        // Act
        recipe.ensureProvenance()

        // Assert
        #expect(recipe.provenance?.sourceType == .scanned)
    }

    @Test("ensureProvenance maps scan sourceType to scanned")
    func testEnsureProvenance_ScanSource_MapsToScanned() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe", sourceType: .scan)

        // Act
        recipe.ensureProvenance()

        // Assert
        #expect(recipe.provenance?.sourceType == .scanned)
    }

    @Test("ensureProvenance maps family sourceType with sharedBy to shared")
    func testEnsureProvenance_FamilyWithSharedBy_MapsToShared() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe", sourceType: .family)
        recipe.sharedBy = "Grandma Rose"

        // Act
        recipe.ensureProvenance()

        // Assert
        #expect(recipe.provenance?.sourceType == .shared)
        #expect(recipe.provenance?.sharedByName == "Grandma Rose")
    }

    @Test("ensureProvenance maps family sourceType without sharedBy to userCreated")
    func testEnsureProvenance_FamilyWithoutSharedBy_MapsToUserCreated() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe", sourceType: .family)

        // Act
        recipe.ensureProvenance()

        // Assert
        #expect(recipe.provenance?.sourceType == .userCreated)
    }

    @Test("ensureProvenance sets generation from generationCount")
    func testEnsureProvenance_SetsGenerationFromCount() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.generationCount = 3

        // Act
        recipe.ensureProvenance()

        // Assert
        #expect(recipe.provenance?.generation == 2) // generationCount - 1
    }

    @Test("ensureProvenance handles zero generationCount")
    func testEnsureProvenance_ZeroGenerationCount() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.generationCount = 0

        // Act
        recipe.ensureProvenance()

        // Assert
        #expect(recipe.provenance?.generation == 0)
    }

    @Test("ensureProvenance preserves passedDownBy as sharedByName")
    func testEnsureProvenance_PreservesPassedDownBy() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe", sourceType: .family)
        recipe.passedDownBy = "Great Grandma"

        // Act
        recipe.ensureProvenance()

        // Assert
        #expect(recipe.provenance?.sharedByName == "Great Grandma")
    }

    // MARK: - Source Attribution Tests

    @Test("sourceAttribution returns provenance attribution when available")
    func testSourceAttribution_WithProvenance_ReturnsProvenanceAttribution() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.provenance = ProvenanceMetadata(
            sourceType: .imported,
            sourceAttribution: "From AllRecipes"
        )

        // Act & Assert
        #expect(recipe.sourceAttribution == "From AllRecipes")
    }

    @Test("sourceAttribution falls back to sourcePerson")
    func testSourceAttribution_NoProvenance_FallsBackToSourcePerson() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe", sourceType: .family)
        recipe.sourcePerson = "Aunt Marie"

        // Act & Assert
        #expect(recipe.sourceAttribution == "Aunt Marie")
    }

    @Test("sourceAttribution falls back to sourceBookTitle")
    func testSourceAttribution_NoProvenance_FallsBackToBookTitle() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe", sourceType: .cookbook)
        recipe.sourceBookTitle = "Joy of Cooking"

        // Act & Assert
        #expect(recipe.sourceAttribution == "Joy of Cooking")
    }

    @Test("sourceAttribution returns nil when no attribution available")
    func testSourceAttribution_NoAttribution_ReturnsNil() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")

        // Act & Assert
        #expect(recipe.sourceAttribution == nil)
    }

    // MARK: - Display Source Tests

    @Test("displaySource uses provenance when available")
    func testDisplaySource_WithProvenance_UsesProvenanceDisplay() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.provenance = ProvenanceMetadata(
            sourceType: .shared,
            sharedByName: "Sarah M.",
            generation: 1
        )

        // Act & Assert
        #expect(recipe.displaySource == "Shared by Sarah M.")
    }

    @Test("displaySource falls back to sourceDisplayName without provenance")
    func testDisplaySource_NoProvenance_FallsBackToSourceDisplayName() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe", sourceType: .manual)

        // Act & Assert
        #expect(recipe.displaySource == "My Recipe")
    }

    @Test("displaySource shows attribution for imported recipes")
    func testDisplaySource_ImportedWithAttribution() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.provenance = ProvenanceMetadata(
            sourceType: .imported,
            sourceURL: "https://www.allrecipes.com/recipe/123",
            sourceAttribution: "AllRecipes.com"
        )

        // Act & Assert
        #expect(recipe.displaySource == "AllRecipes.com")
    }

    // MARK: - Original Recipe Detection Tests

    @Test("isOriginalRecipe returns true for generation 0 with provenance")
    func testIsOriginalRecipe_Generation0_ReturnsTrue() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.provenance = ProvenanceMetadata(
            sourceType: .userCreated,
            generation: 0
        )

        // Act & Assert
        #expect(recipe.isOriginalRecipe == true)
    }

    @Test("isOriginalRecipe returns false for generation > 0")
    func testIsOriginalRecipe_GenerationGreaterThan0_ReturnsFalse() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.provenance = ProvenanceMetadata(
            sourceType: .shared,
            generation: 2
        )

        // Act & Assert
        #expect(recipe.isOriginalRecipe == false)
    }

    @Test("isOriginalRecipe falls back to generationCount when no provenance")
    func testIsOriginalRecipe_NoProvenance_FallsBackToGenerationCount() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.generationCount = 1

        // Act & Assert
        #expect(recipe.isOriginalRecipe == true)
    }

    @Test("isOriginalRecipe returns false when generationCount > 1")
    func testIsOriginalRecipe_GenerationCountGreaterThan1_ReturnsFalse() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.generationCount = 3

        // Act & Assert
        #expect(recipe.isOriginalRecipe == false)
    }

    // MARK: - Shared Recipe Detection Tests

    @Test("isSharedRecipe returns true when generation > 0")
    func testIsSharedRecipe_WithGeneration_ReturnsTrue() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.provenance = ProvenanceMetadata(
            sourceType: .shared,
            generation: 1,
            sharedByName: "Mom"
        )

        // Act & Assert
        #expect(recipe.isSharedRecipe == true)
    }

    @Test("isSharedRecipe returns false for original recipes")
    func testIsSharedRecipe_Original_ReturnsFalse() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.provenance = ProvenanceMetadata(
            sourceType: .userCreated,
            generation: 0
        )

        // Act & Assert
        #expect(recipe.isSharedRecipe == false)
    }

    @Test("isSharedRecipe falls back to sharedBy field")
    func testIsSharedRecipe_NoProvenance_ChecksSharedBy() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.sharedBy = "Aunt Marie"

        // Act & Assert
        #expect(recipe.isSharedRecipe == true)
    }

    @Test("isSharedRecipe falls back to passedDownBy field")
    func testIsSharedRecipe_NoProvenance_ChecksPassedDownBy() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.passedDownBy = "Grandma"

        // Act & Assert
        #expect(recipe.isSharedRecipe == true)
    }

    @Test("isSharedRecipe returns false when no sharing indicators")
    func testIsSharedRecipe_NoIndicators_ReturnsFalse() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")

        // Act & Assert
        #expect(recipe.isSharedRecipe == false)
    }

    // MARK: - Generation Display Text Tests

    @Test("generationDisplayText returns nil for generation 0")
    func testGenerationDisplayText_Generation0_ReturnsNil() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.provenance = ProvenanceMetadata(
            sourceType: .userCreated,
            generation: 0
        )

        // Act & Assert
        #expect(recipe.generationDisplayText == nil)
    }

    @Test("generationDisplayText returns '1st Generation' for generation 1")
    func testGenerationDisplayText_Generation1() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.provenance = ProvenanceMetadata(
            sourceType: .shared,
            generation: 1
        )

        // Act & Assert
        #expect(recipe.generationDisplayText == "1st Generation")
    }

    @Test("generationDisplayText returns '2nd Generation' for generation 2")
    func testGenerationDisplayText_Generation2() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.provenance = ProvenanceMetadata(
            sourceType: .shared,
            generation: 2
        )

        // Act & Assert
        #expect(recipe.generationDisplayText == "2nd Generation")
    }

    @Test("generationDisplayText returns '3rd Generation' for generation 3")
    func testGenerationDisplayText_Generation3() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.provenance = ProvenanceMetadata(
            sourceType: .shared,
            generation: 3
        )

        // Act & Assert
        #expect(recipe.generationDisplayText == "3rd Generation")
    }

    @Test("generationDisplayText returns 'Nth Generation' for generation > 3")
    func testGenerationDisplayText_HighGeneration() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.provenance = ProvenanceMetadata(
            sourceType: .shared,
            generation: 5
        )

        // Act & Assert
        #expect(recipe.generationDisplayText == "5th Generation")
    }

    @Test("generationDisplayText falls back to generationCount")
    func testGenerationDisplayText_NoProvenance_UsesGenerationCount() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.generationCount = 3

        // Act & Assert
        #expect(recipe.generationDisplayText == "Gen 3")
    }

    @Test("generationDisplayText returns nil for generationCount <= 1")
    func testGenerationDisplayText_GenerationCount1_ReturnsNil() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.generationCount = 1

        // Act & Assert
        #expect(recipe.generationDisplayText == nil)
    }

    // MARK: - Trending Status Tests

    @Test("isTrending returns false when no provenance")
    func testIsTrending_NoProvenance_ReturnsFalse() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")

        // Act & Assert
        #expect(recipe.isTrending == false)
    }

    @Test("isTrending returns provenance cached metrics value")
    func testIsTrending_WithProvenance_ReturnsMetricsValue() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.provenance = ProvenanceMetadata(
            sourceType: .imported,
            cachedMetrics: AggregatedMetrics(
                totalShares: 10,
                trendingScore: 15.0
            )
        )

        // Act & Assert
        #expect(recipe.isTrending == true)
    }

    @Test("isTrending returns false when trending score too low")
    func testIsTrending_LowScore_ReturnsFalse() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.provenance = ProvenanceMetadata(
            sourceType: .imported,
            cachedMetrics: AggregatedMetrics(
                totalShares: 10,
                trendingScore: 5.0 // Below threshold
            )
        )

        // Act & Assert
        #expect(recipe.isTrending == false)
    }

    // MARK: - Share Count Tests

    @Test("totalShares returns 0 when no provenance")
    func testTotalShares_NoProvenance_Returns0() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")

        // Act & Assert
        #expect(recipe.totalShares == 0)
    }

    @Test("totalShares returns cached metrics value")
    func testTotalShares_WithProvenance_ReturnsMetricsValue() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.provenance = ProvenanceMetadata(
            sourceType: .imported,
            cachedMetrics: AggregatedMetrics(totalShares: 42)
        )

        // Act & Assert
        #expect(recipe.totalShares == 42)
    }

    @Test("shareCountDisplay returns empty string when no shares")
    func testShareCountDisplay_NoShares_ReturnsEmpty() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.provenance = ProvenanceMetadata(
            sourceType: .imported,
            cachedMetrics: AggregatedMetrics(totalShares: 0)
        )

        // Act & Assert
        #expect(recipe.shareCountDisplay == "")
    }

    @Test("shareCountDisplay returns '1 share' for single share")
    func testShareCountDisplay_OneShare() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.provenance = ProvenanceMetadata(
            sourceType: .imported,
            cachedMetrics: AggregatedMetrics(totalShares: 1)
        )

        // Act & Assert
        #expect(recipe.shareCountDisplay == "1 share")
    }

    @Test("shareCountDisplay returns count for multiple shares")
    func testShareCountDisplay_MultipleShares() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.provenance = ProvenanceMetadata(
            sourceType: .imported,
            cachedMetrics: AggregatedMetrics(totalShares: 42)
        )

        // Act & Assert
        #expect(recipe.shareCountDisplay == "42 shares")
    }

    @Test("shareCountDisplay returns '100+ shares' for high counts")
    func testShareCountDisplay_HighCount() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.provenance = ProvenanceMetadata(
            sourceType: .imported,
            cachedMetrics: AggregatedMetrics(totalShares: 150)
        )

        // Act & Assert
        #expect(recipe.shareCountDisplay == "100+ shares")
    }
}
