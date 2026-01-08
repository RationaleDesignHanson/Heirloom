import Testing
import Foundation

@testable import Heirloom

@Suite("Recipe Computed Properties Tests")
struct RecipeComputedPropertiesTests {

    // MARK: - Source Display Name Tests

    @Test("URL source displays host name")
    func testSourceDisplayName_URL_ReturnsHost() {
        // Arrange
        let recipe = Heirloom.Recipe(
            title: "Test Recipe",
            sourceType: .url,
            sourceURL: "https://www.example.com/recipe"
        )

        // Act & Assert
        #expect(recipe.sourceDisplayName == "example.com")
    }

    @Test("URL source without host returns 'Website'")
    func testSourceDisplayName_URL_NoHost_ReturnsDefault() {
        // Arrange
        let recipe = Heirloom.Recipe(
            title: "Test Recipe",
            sourceType: .url,
            sourceURL: nil
        )

        // Act & Assert
        #expect(recipe.sourceDisplayName == "Website")
    }

    @Test("Cookbook source with title and page displays both")
    func testSourceDisplayName_Cookbook_WithTitleAndPage() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe", sourceType: .cookbook)
        recipe.sourceBookTitle = "Joy of Cooking"
        recipe.sourceBookPage = 42

        // Act & Assert
        #expect(recipe.sourceDisplayName == "Joy of Cooking, p. 42")
    }

    @Test("Cookbook source with title only")
    func testSourceDisplayName_Cookbook_TitleOnly() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe", sourceType: .cookbook)
        recipe.sourceBookTitle = "Joy of Cooking"

        // Act & Assert
        #expect(recipe.sourceDisplayName == "Joy of Cooking")
    }

    @Test("Cookbook source without title returns 'Cookbook'")
    func testSourceDisplayName_Cookbook_NoTitle_ReturnsDefault() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe", sourceType: .cookbook)

        // Act & Assert
        #expect(recipe.sourceDisplayName == "Cookbook")
    }

    @Test("Family source with person and date displays both")
    func testSourceDisplayName_Family_WithPersonAndDate() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe", sourceType: .family)
        recipe.sourcePerson = "Grandma Rose"
        recipe.sourceDate = "1987"

        // Act & Assert
        #expect(recipe.sourceDisplayName == "Grandma Rose, 1987")
    }

    @Test("Family source with person only")
    func testSourceDisplayName_Family_PersonOnly() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe", sourceType: .family)
        recipe.sourcePerson = "Grandma Rose"

        // Act & Assert
        #expect(recipe.sourceDisplayName == "Grandma Rose")
    }

    @Test("Family source without person returns 'Family Recipe'")
    func testSourceDisplayName_Family_NoPerson_ReturnsDefault() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe", sourceType: .family)

        // Act & Assert
        #expect(recipe.sourceDisplayName == "Family Recipe")
    }

    @Test("Scan source returns 'Scanned Recipe'")
    func testSourceDisplayName_Scan_ReturnsDefault() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe", sourceType: .scan)

        // Act & Assert
        #expect(recipe.sourceDisplayName == "Scanned Recipe")
    }

    @Test("Manual source returns 'My Recipe'")
    func testSourceDisplayName_Manual_ReturnsDefault() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe", sourceType: .manual)

        // Act & Assert
        #expect(recipe.sourceDisplayName == "My Recipe")
    }

    @Test("Heritage source returns 'Heritage Collection'")
    func testSourceDisplayName_Heritage_ReturnsDefault() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe", sourceType: .heritage)

        // Act & Assert
        #expect(recipe.sourceDisplayName == "Heritage Collection")
    }

    // MARK: - Love Marks Tests

    @Test("Recipe with less than 5 cooks should not show love marks")
    func testShouldShowLoveMarks_LessThan5_ReturnsFalse() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.timesCooked = 4

        // Act & Assert
        #expect(recipe.shouldShowLoveMarks == false)
    }

    @Test("Recipe with exactly 5 cooks should show love marks")
    func testShouldShowLoveMarks_Exactly5_ReturnsTrue() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.timesCooked = 5

        // Act & Assert
        #expect(recipe.shouldShowLoveMarks == true)
    }

    @Test("Recipe with more than 5 cooks should show love marks")
    func testShouldShowLoveMarks_MoreThan5_ReturnsTrue() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.timesCooked = 12

        // Act & Assert
        #expect(recipe.shouldShowLoveMarks == true)
    }

    @Test("Love mark intensity at 5 cooks")
    func testLoveMarkIntensity_5Cooks_Returns0Point25() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.timesCooked = 5

        // Act & Assert
        #expect(recipe.loveMarkIntensity == 0.25)
    }

    @Test("Love mark intensity at 10 cooks")
    func testLoveMarkIntensity_10Cooks_Returns0Point5() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.timesCooked = 10

        // Act & Assert
        #expect(recipe.loveMarkIntensity == 0.5)
    }

    @Test("Love mark intensity at 20 cooks caps at 1.0")
    func testLoveMarkIntensity_20Cooks_CapsAt1() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.timesCooked = 20

        // Act & Assert
        #expect(recipe.loveMarkIntensity == 1.0)
    }

    @Test("Love mark intensity at 30 cooks caps at 1.0")
    func testLoveMarkIntensity_30Cooks_CapsAt1() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.timesCooked = 30

        // Act & Assert
        #expect(recipe.loveMarkIntensity == 1.0)
    }

    // MARK: - Time Parsing Tests

    @Test("Parse prep time with minutes only")
    func testParsedPrepTime_MinutesOnly() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe", prepTime: "30 min")

        // Act & Assert
        #expect(recipe.parsedPrepTime == 30)
    }

    @Test("Parse prep time with hours only")
    func testParsedPrepTime_HoursOnly() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe", prepTime: "2 hours")

        // Act & Assert
        #expect(recipe.parsedPrepTime == 120)
    }

    @Test("Parse prep time with hours and minutes")
    func testParsedPrepTime_HoursAndMinutes() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe", prepTime: "1 hr 30 min")

        // Act & Assert
        #expect(recipe.parsedPrepTime == 90)
    }

    @Test("Parse prep time with plain number assumes minutes")
    func testParsedPrepTime_PlainNumber_AssumesMinutes() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe", prepTime: "45")

        // Act & Assert
        #expect(recipe.parsedPrepTime == 45)
    }

    @Test("Parse prep time returns 0 when nil")
    func testParsedPrepTime_Nil_Returns0() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe", prepTime: nil)

        // Act & Assert
        #expect(recipe.parsedPrepTime == 0)
    }

    @Test("Parse cook time with minutes only")
    func testParsedCookTime_MinutesOnly() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe", cookTime: "45 minutes")

        // Act & Assert
        #expect(recipe.parsedCookTime == 45)
    }

    @Test("Parse cook time with hours and minutes")
    func testParsedCookTime_HoursAndMinutes() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe", cookTime: "2 hr 15 min")

        // Act & Assert
        #expect(recipe.parsedCookTime == 135)
    }

    // MARK: - Parsed Serving Count Tests

    @Test("Parse servings with 'servings' keyword")
    func testParsedServingCount_WithServingsKeyword() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe", servings: "6 servings")

        // Act & Assert
        #expect(recipe.parsedServingCount == 6)
    }

    @Test("Parse servings with 'Makes' keyword")
    func testParsedServingCount_WithMakesKeyword() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe", servings: "Makes 12 cookies")

        // Act & Assert
        #expect(recipe.parsedServingCount == 12)
    }

    @Test("Parse servings with range uses first number")
    func testParsedServingCount_Range_UsesFirst() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe", servings: "4-6 servings")

        // Act & Assert
        #expect(recipe.parsedServingCount == 4)
    }

    @Test("Parse servings returns 4 when nil")
    func testParsedServingCount_Nil_Returns4() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe", servings: nil)

        // Act & Assert
        #expect(recipe.parsedServingCount == 4)
    }

    @Test("Parse servings with just number")
    func testParsedServingCount_JustNumber() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe", servings: "8")

        // Act & Assert
        #expect(recipe.parsedServingCount == 8)
    }

    // MARK: - List Item DTO Tests

    @Test("List item DTO contains correct basic properties")
    func testListItem_ContainsBasicProperties() {
        // Arrange
        let recipe = Heirloom.Recipe(
            title: "Chocolate Cake",
            sourceType: .family
        )
        recipe.isFavorite = true
        recipe.timesCooked = 5

        // Act
        let listItem = recipe.listItem

        // Assert
        #expect(listItem.id == recipe.id)
        #expect(listItem.title == "Chocolate Cake")
        #expect(listItem.sourceType == .family)
        #expect(listItem.isFavorite == true)
        #expect(listItem.timesCooked == 5)
    }

    @Test("List item DTO includes image file name")
    func testListItem_IncludesImageFileName() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.imageFileName = "recipe-123.jpg"

        // Act
        let listItem = recipe.listItem

        // Assert
        #expect(listItem.imageFileName == "recipe-123.jpg")
    }

    @Test("List item DTO includes source display name")
    func testListItem_IncludesSourceDisplayName() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe", sourceType: .family)
        recipe.sourcePerson = "Grandma"

        // Act
        let listItem = recipe.listItem

        // Assert
        #expect(listItem.sourceDisplayName == "Grandma")
    }

    @Test("List item DTO includes date added")
    func testListItem_IncludesDateAdded() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        let dateAdded = recipe.dateAdded

        // Act
        let listItem = recipe.listItem

        // Assert
        #expect(listItem.dateAdded == dateAdded)
    }

    // MARK: - Generation Display Tests

    @Test("Generation label with no versions")
    func testGenerationLabel_NoVersions_ReturnsOriginal() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")

        // Act & Assert
        #expect(recipe.generationLabel == "Original")
    }

    @Test("Generation label with one version")
    func testGenerationLabel_OneVersion_ReturnsOriginal() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.versions = []  // Empty array means no versions yet

        // Act & Assert
        #expect(recipe.generationLabel == "Original")
    }
}
