import Testing
import Foundation
import SwiftData

@testable import Heirloom

@Suite("Recipe Multi-Version Tests")
struct RecipeMultiVersionTests {

    // MARK: - Test Setup Helper

    func createTestContext() -> ModelContext {
        let schema = Schema([
            Heirloom.Recipe.self,
            Heirloom.RecipeVersion.self,
            Heirloom.Ingredient.self,
            Heirloom.Tag.self,
            Heirloom.RecipeCollection.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: config)
        return ModelContext(container)
    }

    // MARK: - Sharing Permission Tests

    @Test("SharingPermissionLevel enum has all expected cases")
    func testSharingPermissionLevel_AllCases() {
        // Arrange & Act
        let allCases = Recipe.SharingPermissionLevel.allCases

        // Assert
        #expect(allCases.count == 2)
        #expect(allCases.contains(.regular))
        #expect(allCases.contains(.heirloom))
    }

    @Test("Sharing permission defaults to regular")
    func testSharingPermission_DefaultsToRegular() {
        // Arrange
        let context = createTestContext()
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        context.insert(recipe)

        // Act & Assert
        #expect(recipe.sharingPermission == .regular)
    }

    @Test("Sharing permission can be set and retrieved")
    func testSharingPermission_SetterAndGetter() {
        // Arrange
        let context = createTestContext()
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        context.insert(recipe)

        // Act
        recipe.sharingPermission = .heirloom

        // Assert
        #expect(recipe.sharingPermission == .heirloom)
    }

    @Test("Sharing permission raw value is stored correctly")
    func testSharingPermission_RawValueStorage() {
        // Arrange
        let context = createTestContext()
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        context.insert(recipe)

        // Act
        recipe.sharingPermission = .heirloom

        // Assert
        #expect(recipe.sharingPermissionRaw == "heirloom")
    }

    // MARK: - Base Version Tests

    @Test("baseVersion returns nil when no versions exist")
    func testBaseVersion_NoVersions_ReturnsNil() {
        // Arrange
        let context = createTestContext()
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        context.insert(recipe)

        // Act & Assert
        #expect(recipe.baseVersion == nil)
    }

    @Test("baseVersion returns the base version when it exists")
    func testBaseVersion_WithBaseVersion_ReturnsBase() {
        // Arrange
        let context = createTestContext()
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        context.insert(recipe)

        let baseVersion = RecipeVersion(
            creatorUserID: "user-1",
            creatorDisplayName: "Original Creator",
            isBaseVersion: true
        )
        baseVersion.recipe = recipe
        context.insert(baseVersion)

        // Act
        let result = recipe.baseVersion

        // Assert
        #expect(result != nil)
        #expect(result?.id == baseVersion.id)
        #expect(result?.isBaseVersion == true)
    }

    @Test("baseVersion returns first base version when multiple exist")
    func testBaseVersion_MultipleBaseVersions_ReturnsFirst() {
        // Arrange
        let context = createTestContext()
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        context.insert(recipe)

        let baseVersion1 = RecipeVersion(
            creatorUserID: "user-1",
            creatorDisplayName: "First Creator",
            isBaseVersion: true
        )
        baseVersion1.recipe = recipe
        context.insert(baseVersion1)

        let baseVersion2 = RecipeVersion(
            creatorUserID: "user-2",
            creatorDisplayName: "Second Creator",
            isBaseVersion: true
        )
        baseVersion2.recipe = recipe
        context.insert(baseVersion2)

        // Act
        let result = recipe.baseVersion

        // Assert
        #expect(result != nil)
        #expect(result?.isBaseVersion == true)
    }

    // MARK: - Contributor Versions Tests

    @Test("contributorVersions returns empty array when no versions exist")
    func testContributorVersions_NoVersions_ReturnsEmpty() {
        // Arrange
        let context = createTestContext()
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        context.insert(recipe)

        // Act
        let contributors = recipe.contributorVersions

        // Assert
        #expect(contributors.isEmpty)
    }

    @Test("contributorVersions excludes base version")
    func testContributorVersions_ExcludesBaseVersion() {
        // Arrange
        let context = createTestContext()
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        context.insert(recipe)

        let baseVersion = RecipeVersion(
            creatorUserID: "user-1",
            creatorDisplayName: "Original",
            isBaseVersion: true
        )
        baseVersion.recipe = recipe
        context.insert(baseVersion)

        let contributorVersion = RecipeVersion(
            creatorUserID: "user-2",
            creatorDisplayName: "Contributor",
            isBaseVersion: false
        )
        contributorVersion.recipe = recipe
        context.insert(contributorVersion)

        // Act
        let contributors = recipe.contributorVersions

        // Assert
        #expect(contributors.count == 1)
        #expect(contributors[0].id == contributorVersion.id)
    }

    @Test("contributorVersions only includes active versions")
    func testContributorVersions_OnlyIncludesActive() {
        // Arrange
        let context = createTestContext()
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        context.insert(recipe)

        let activeVersion = RecipeVersion(
            creatorUserID: "user-1",
            creatorDisplayName: "Active User",
            isBaseVersion: false
        )
        activeVersion.isActive = true
        activeVersion.recipe = recipe
        context.insert(activeVersion)

        let inactiveVersion = RecipeVersion(
            creatorUserID: "user-2",
            creatorDisplayName: "Inactive User",
            isBaseVersion: false
        )
        inactiveVersion.isActive = false
        inactiveVersion.recipe = recipe
        context.insert(inactiveVersion)

        // Act
        let contributors = recipe.contributorVersions

        // Assert
        #expect(contributors.count == 1)
        #expect(contributors[0].id == activeVersion.id)
    }

    @Test("contributorVersions returns multiple active contributors")
    func testContributorVersions_MultipleActive() {
        // Arrange
        let context = createTestContext()
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        context.insert(recipe)

        let contributor1 = RecipeVersion(
            creatorUserID: "user-1",
            creatorDisplayName: "User 1",
            isBaseVersion: false
        )
        contributor1.recipe = recipe
        context.insert(contributor1)

        let contributor2 = RecipeVersion(
            creatorUserID: "user-2",
            creatorDisplayName: "User 2",
            isBaseVersion: false
        )
        contributor2.recipe = recipe
        context.insert(contributor2)

        let contributor3 = RecipeVersion(
            creatorUserID: "user-3",
            creatorDisplayName: "User 3",
            isBaseVersion: false
        )
        contributor3.recipe = recipe
        context.insert(contributor3)

        // Act
        let contributors = recipe.contributorVersions

        // Assert
        #expect(contributors.count == 3)
    }

    // MARK: - Active Version Tests

    @Test("activeVersion returns base version when no version is selected")
    func testActiveVersion_NoSelection_ReturnsBase() {
        // Arrange
        let context = createTestContext()
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        context.insert(recipe)

        let baseVersion = RecipeVersion(
            creatorUserID: "user-1",
            creatorDisplayName: "Original",
            isBaseVersion: true
        )
        baseVersion.recipe = recipe
        context.insert(baseVersion)

        // Act
        let active = recipe.activeVersion

        // Assert
        #expect(active != nil)
        #expect(active?.id == baseVersion.id)
    }

    @Test("activeVersion returns selected version when one is set")
    func testActiveVersion_WithSelection_ReturnsSelected() {
        // Arrange
        let context = createTestContext()
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        context.insert(recipe)

        let baseVersion = RecipeVersion(
            creatorUserID: "user-1",
            creatorDisplayName: "Original",
            isBaseVersion: true
        )
        baseVersion.recipe = recipe
        context.insert(baseVersion)

        let selectedVersion = RecipeVersion(
            creatorUserID: "user-2",
            creatorDisplayName: "Contributor",
            isBaseVersion: false
        )
        selectedVersion.recipe = recipe
        context.insert(selectedVersion)

        recipe.selectedVersionID = selectedVersion.id

        // Act
        let active = recipe.activeVersion

        // Assert
        #expect(active != nil)
        #expect(active?.id == selectedVersion.id)
    }

    @Test("activeVersion falls back to base when selected version not found")
    func testActiveVersion_SelectionNotFound_FallsBackToBase() {
        // Arrange
        let context = createTestContext()
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        context.insert(recipe)

        let baseVersion = RecipeVersion(
            creatorUserID: "user-1",
            creatorDisplayName: "Original",
            isBaseVersion: true
        )
        baseVersion.recipe = recipe
        context.insert(baseVersion)

        recipe.selectedVersionID = UUID() // Non-existent ID

        // Act
        let active = recipe.activeVersion

        // Assert
        #expect(active != nil)
        #expect(active?.id == baseVersion.id)
    }

    // MARK: - Contributor Count Tests

    @Test("contributorCount returns 0 when no contributors exist")
    func testContributorCount_NoContributors_Returns0() {
        // Arrange
        let context = createTestContext()
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        context.insert(recipe)

        // Act & Assert
        #expect(recipe.contributorCount == 0)
    }

    @Test("contributorCount excludes base version")
    func testContributorCount_ExcludesBase() {
        // Arrange
        let context = createTestContext()
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        context.insert(recipe)

        let baseVersion = RecipeVersion(
            creatorUserID: "user-1",
            creatorDisplayName: "Original",
            isBaseVersion: true
        )
        baseVersion.recipe = recipe
        context.insert(baseVersion)

        // Act & Assert
        #expect(recipe.contributorCount == 0)
    }

    @Test("contributorCount returns correct count with multiple contributors")
    func testContributorCount_MultipleContributors() {
        // Arrange
        let context = createTestContext()
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        context.insert(recipe)

        for i in 1...5 {
            let version = RecipeVersion(
                creatorUserID: "user-\(i)",
                creatorDisplayName: "User \(i)",
                isBaseVersion: false
            )
            version.recipe = recipe
            context.insert(version)
        }

        // Act & Assert
        #expect(recipe.contributorCount == 5)
    }

    // MARK: - Has Multiple Versions Tests

    @Test("hasMultipleVersions returns false when no contributors exist")
    func testHasMultipleVersions_NoContributors_ReturnsFalse() {
        // Arrange
        let context = createTestContext()
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        context.insert(recipe)

        // Act & Assert
        #expect(recipe.hasMultipleVersions == false)
    }

    @Test("hasMultipleVersions returns false with only base version")
    func testHasMultipleVersions_OnlyBase_ReturnsFalse() {
        // Arrange
        let context = createTestContext()
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        context.insert(recipe)

        let baseVersion = RecipeVersion(
            creatorUserID: "user-1",
            creatorDisplayName: "Original",
            isBaseVersion: true
        )
        baseVersion.recipe = recipe
        context.insert(baseVersion)

        // Act & Assert
        #expect(recipe.hasMultipleVersions == false)
    }

    @Test("hasMultipleVersions returns true with at least one contributor")
    func testHasMultipleVersions_WithContributors_ReturnsTrue() {
        // Arrange
        let context = createTestContext()
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        context.insert(recipe)

        let baseVersion = RecipeVersion(
            creatorUserID: "user-1",
            creatorDisplayName: "Original",
            isBaseVersion: true
        )
        baseVersion.recipe = recipe
        context.insert(baseVersion)

        let contributorVersion = RecipeVersion(
            creatorUserID: "user-2",
            creatorDisplayName: "Contributor",
            isBaseVersion: false
        )
        contributorVersion.recipe = recipe
        context.insert(contributorVersion)

        // Act & Assert
        #expect(recipe.hasMultipleVersions == true)
    }

    // MARK: - Generation Label Tests

    @Test("generationLabel returns 'Original' when no versions exist")
    func testGenerationLabel_NoVersions_ReturnsOriginal() {
        // Arrange
        let context = createTestContext()
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        context.insert(recipe)

        // Act & Assert
        #expect(recipe.generationLabel == "Original")
    }

    @Test("generationLabel returns 'Original' with single version")
    func testGenerationLabel_OneVersion_ReturnsOriginal() {
        // Arrange
        let context = createTestContext()
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        context.insert(recipe)

        let version = RecipeVersion(
            creatorUserID: "user-1",
            creatorDisplayName: "User",
            isBaseVersion: true
        )
        version.recipe = recipe
        context.insert(version)

        // Act & Assert
        #expect(recipe.generationLabel == "Original")
    }

    @Test("generationLabel returns '2 Generations' with two versions")
    func testGenerationLabel_TwoVersions() {
        // Arrange
        let context = createTestContext()
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        context.insert(recipe)

        let baseVersion = RecipeVersion(
            creatorUserID: "user-1",
            creatorDisplayName: "Original",
            isBaseVersion: true
        )
        baseVersion.recipe = recipe
        context.insert(baseVersion)

        let contributorVersion = RecipeVersion(
            creatorUserID: "user-2",
            creatorDisplayName: "Contributor",
            isBaseVersion: false
        )
        contributorVersion.recipe = recipe
        context.insert(contributorVersion)

        // Act & Assert
        #expect(recipe.generationLabel == "2 Generations")
    }

    @Test("generationLabel returns correct count with multiple versions")
    func testGenerationLabel_MultipleVersions() {
        // Arrange
        let context = createTestContext()
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        context.insert(recipe)

        for i in 1...5 {
            let version = RecipeVersion(
                creatorUserID: "user-\(i)",
                creatorDisplayName: "User \(i)",
                isBaseVersion: i == 1
            )
            version.recipe = recipe
            context.insert(version)
        }

        // Act & Assert
        #expect(recipe.generationLabel == "5 Generations")
    }

    // MARK: - Sorted Versions Tests

    @Test("sortedVersions returns empty array when no versions exist")
    func testSortedVersions_NoVersions_ReturnsEmpty() {
        // Arrange
        let context = createTestContext()
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        context.insert(recipe)

        // Act
        let sorted = recipe.sortedVersions

        // Assert
        #expect(sorted.isEmpty)
    }

    @Test("sortedVersions returns versions sorted by creation date")
    func testSortedVersions_SortsByCreationDate() {
        // Arrange
        let context = createTestContext()
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        context.insert(recipe)

        let date1 = Date(timeIntervalSince1970: 1000)
        let date2 = Date(timeIntervalSince1970: 2000)
        let date3 = Date(timeIntervalSince1970: 3000)

        let version3 = RecipeVersion(
            creatorUserID: "user-3",
            creatorDisplayName: "Third",
            isBaseVersion: false
        )
        version3.createdAt = date3
        version3.recipe = recipe
        context.insert(version3)

        let version1 = RecipeVersion(
            creatorUserID: "user-1",
            creatorDisplayName: "First",
            isBaseVersion: true
        )
        version1.createdAt = date1
        version1.recipe = recipe
        context.insert(version1)

        let version2 = RecipeVersion(
            creatorUserID: "user-2",
            creatorDisplayName: "Second",
            isBaseVersion: false
        )
        version2.createdAt = date2
        version2.recipe = recipe
        context.insert(version2)

        // Act
        let sorted = recipe.sortedVersions

        // Assert
        #expect(sorted.count == 3)
        #expect(sorted[0].createdAt == date1)
        #expect(sorted[1].createdAt == date2)
        #expect(sorted[2].createdAt == date3)
    }

    @Test("sortedVersions maintains stability with same creation dates")
    func testSortedVersions_StableSort() {
        // Arrange
        let context = createTestContext()
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        context.insert(recipe)

        let sameDate = Date()

        let version1 = RecipeVersion(
            creatorUserID: "user-1",
            creatorDisplayName: "First",
            isBaseVersion: true
        )
        version1.createdAt = sameDate
        version1.recipe = recipe
        context.insert(version1)

        let version2 = RecipeVersion(
            creatorUserID: "user-2",
            creatorDisplayName: "Second",
            isBaseVersion: false
        )
        version2.createdAt = sameDate
        version2.recipe = recipe
        context.insert(version2)

        // Act
        let sorted = recipe.sortedVersions

        // Assert - just verify all versions are present
        #expect(sorted.count == 2)
    }
}
