import Testing
import Foundation
import SwiftData
import SwiftUI

@testable import Heirloom

@Suite("Recipe Card Style Tests")
struct CardStyleTests {

    // MARK: - Test Setup Helper

    func createTestContext() -> ModelContext {
        let schema = Schema([
            Recipe.self,
            RecipeCardStyle.self,
            Ingredient.self,
            Tag.self,
            RecipeCollection.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: config)
        return ModelContext(container)
    }

    // MARK: - Initialization Tests

    @Test("RecipeCardStyle initializes with default values")
    func testInit_WithDefaults_SetsDefaultValues() {
        // Act
        let style = RecipeCardStyle()

        // Assert
        #expect(style.id != UUID(uuidString: "00000000-0000-0000-0000-000000000000")!)
        #expect(style.backgroundType == .default)
        #expect(style.coffeeStainEnabled == false)
        #expect(style.wornEdgesIntensity == 0.0)
        #expect(style.autoLoveMarks == false)
        #expect(style.backgroundColorHex == nil)
        #expect(style.backgroundImageName == nil)
        #expect(style.coffeeStainPosition == nil)
        #expect(style.recipe == nil)
    }

    @Test("RecipeCardStyle initializes with custom background type")
    func testInit_WithCustomBackgroundType_SetsBackgroundType() {
        // Act
        let style = RecipeCardStyle(backgroundType: .gradient)

        // Assert
        #expect(style.backgroundType == .gradient)
    }

    @Test("RecipeCardStyle initializes with coffee stain enabled")
    func testInit_WithCoffeeStain_EnablesStain() {
        // Act
        let style = RecipeCardStyle(coffeeStainEnabled: true)

        // Assert
        #expect(style.coffeeStainEnabled == true)
    }

    @Test("RecipeCardStyle initializes with worn edges intensity")
    func testInit_WithWornEdges_SetsIntensity() {
        // Act
        let style = RecipeCardStyle(wornEdgesIntensity: 0.5)

        // Assert
        #expect(style.wornEdgesIntensity == 0.5)
    }

    @Test("RecipeCardStyle initializes with auto love marks")
    func testInit_WithAutoLoveMarks_EnablesAutoMarks() {
        // Act
        let style = RecipeCardStyle(autoLoveMarks: true)

        // Assert
        #expect(style.autoLoveMarks == true)
    }

    @Test("RecipeCardStyle initializes with all custom parameters")
    func testInit_WithAllCustomParams_SetsAllValues() {
        // Act
        let style = RecipeCardStyle(
            backgroundType: .texture,
            coffeeStainEnabled: true,
            wornEdgesIntensity: 0.75,
            autoLoveMarks: true
        )

        // Assert
        #expect(style.backgroundType == .texture)
        #expect(style.coffeeStainEnabled == true)
        #expect(style.wornEdgesIntensity == 0.75)
        #expect(style.autoLoveMarks == true)
    }

    @Test("RecipeCardStyle creates timestamps on initialization")
    func testInit_CreatesTimestamps() {
        // Arrange
        let before = Date()

        // Act
        let style = RecipeCardStyle()

        // Assert
        #expect(style.createdDate >= before)
        #expect(style.lastModified >= before)
    }

    // MARK: - BackgroundType Enum Tests

    @Test("BackgroundType default has correct raw value")
    func testBackgroundType_Default_RawValue() {
        // Assert
        #expect(RecipeCardStyle.BackgroundType.default.rawValue == "default")
    }

    @Test("BackgroundType solid has correct raw value")
    func testBackgroundType_Solid_RawValue() {
        // Assert
        #expect(RecipeCardStyle.BackgroundType.solid.rawValue == "solid")
    }

    @Test("BackgroundType gradient has correct raw value")
    func testBackgroundType_Gradient_RawValue() {
        // Assert
        #expect(RecipeCardStyle.BackgroundType.gradient.rawValue == "gradient")
    }

    @Test("BackgroundType pattern has correct raw value")
    func testBackgroundType_Pattern_RawValue() {
        // Assert
        #expect(RecipeCardStyle.BackgroundType.pattern.rawValue == "pattern")
    }

    @Test("BackgroundType texture has correct raw value")
    func testBackgroundType_Texture_RawValue() {
        // Assert
        #expect(RecipeCardStyle.BackgroundType.texture.rawValue == "texture")
    }

    @Test("BackgroundType can be changed")
    func testBackgroundType_CanBeChanged() {
        // Arrange
        let style = RecipeCardStyle(backgroundType: .default)

        // Act
        style.backgroundType = .solid

        // Assert
        #expect(style.backgroundType == .solid)
    }

    // MARK: - Background Customization Tests

    @Test("RecipeCardStyle can set background color hex")
    func testBackgroundColorHex_CanBeSet() {
        // Arrange
        let style = RecipeCardStyle()

        // Act
        style.backgroundColorHex = "#FEFDFB"

        // Assert
        #expect(style.backgroundColorHex == "#FEFDFB")
    }

    @Test("RecipeCardStyle can clear background color hex")
    func testBackgroundColorHex_CanBeCleared() {
        // Arrange
        let style = RecipeCardStyle()
        style.backgroundColorHex = "#FEFDFB"

        // Act
        style.backgroundColorHex = nil

        // Assert
        #expect(style.backgroundColorHex == nil)
    }

    @Test("RecipeCardStyle can set background image name")
    func testBackgroundImageName_CanBeSet() {
        // Arrange
        let style = RecipeCardStyle()

        // Act
        style.backgroundImageName = "pattern-dots"

        // Assert
        #expect(style.backgroundImageName == "pattern-dots")
    }

    @Test("RecipeCardStyle can clear background image name")
    func testBackgroundImageName_CanBeCleared() {
        // Arrange
        let style = RecipeCardStyle()
        style.backgroundImageName = "pattern-dots"

        // Act
        style.backgroundImageName = nil

        // Assert
        #expect(style.backgroundImageName == nil)
    }

    // MARK: - Coffee Stain Tests

    @Test("RecipeCardStyle coffee stain can be enabled")
    func testCoffeeStain_CanBeEnabled() {
        // Arrange
        let style = RecipeCardStyle()

        // Act
        style.coffeeStainEnabled = true

        // Assert
        #expect(style.coffeeStainEnabled == true)
    }

    @Test("RecipeCardStyle coffee stain can be disabled")
    func testCoffeeStain_CanBeDisabled() {
        // Arrange
        let style = RecipeCardStyle(coffeeStainEnabled: true)

        // Act
        style.coffeeStainEnabled = false

        // Assert
        #expect(style.coffeeStainEnabled == false)
    }

    // MARK: - CoffeeStainPosition Enum Tests

    @Test("CoffeeStainPosition topLeft has correct raw value")
    func testCoffeeStainPosition_TopLeft_RawValue() {
        // Assert
        #expect(RecipeCardStyle.CoffeeStainPosition.topLeft.rawValue == "topLeft")
    }

    @Test("CoffeeStainPosition topRight has correct raw value")
    func testCoffeeStainPosition_TopRight_RawValue() {
        // Assert
        #expect(RecipeCardStyle.CoffeeStainPosition.topRight.rawValue == "topRight")
    }

    @Test("CoffeeStainPosition bottomLeft has correct raw value")
    func testCoffeeStainPosition_BottomLeft_RawValue() {
        // Assert
        #expect(RecipeCardStyle.CoffeeStainPosition.bottomLeft.rawValue == "bottomLeft")
    }

    @Test("CoffeeStainPosition bottomRight has correct raw value")
    func testCoffeeStainPosition_BottomRight_RawValue() {
        // Assert
        #expect(RecipeCardStyle.CoffeeStainPosition.bottomRight.rawValue == "bottomRight")
    }

    @Test("CoffeeStainPosition center has correct raw value")
    func testCoffeeStainPosition_Center_RawValue() {
        // Assert
        #expect(RecipeCardStyle.CoffeeStainPosition.center.rawValue == "center")
    }

    @Test("RecipeCardStyle coffee stain position can be set")
    func testCoffeeStainPosition_CanBeSet() {
        // Arrange
        let style = RecipeCardStyle()

        // Act
        style.coffeeStainPosition = .topRight

        // Assert
        #expect(style.coffeeStainPosition == .topRight)
    }

    @Test("RecipeCardStyle coffee stain position can be changed")
    func testCoffeeStainPosition_CanBeChanged() {
        // Arrange
        let style = RecipeCardStyle()
        style.coffeeStainPosition = .topLeft

        // Act
        style.coffeeStainPosition = .bottomRight

        // Assert
        #expect(style.coffeeStainPosition == .bottomRight)
    }

    @Test("RecipeCardStyle coffee stain position can be cleared")
    func testCoffeeStainPosition_CanBeCleared() {
        // Arrange
        let style = RecipeCardStyle()
        style.coffeeStainPosition = .center

        // Act
        style.coffeeStainPosition = nil

        // Assert
        #expect(style.coffeeStainPosition == nil)
    }

    // MARK: - Worn Edges Tests

    @Test("RecipeCardStyle worn edges intensity stores value")
    func testWornEdgesIntensity_StoresValue() {
        // Arrange
        let style = RecipeCardStyle(wornEdgesIntensity: 0.3)

        // Assert
        #expect(style.wornEdgesIntensity == 0.3)
    }

    @Test("RecipeCardStyle worn edges intensity can be changed")
    func testWornEdgesIntensity_CanBeChanged() {
        // Arrange
        let style = RecipeCardStyle(wornEdgesIntensity: 0.2)

        // Act
        style.wornEdgesIntensity = 0.8

        // Assert
        #expect(style.wornEdgesIntensity == 0.8)
    }

    @Test("RecipeCardStyle worn edges intensity handles minimum")
    func testWornEdgesIntensity_HandlesMinimum() {
        // Act
        let style = RecipeCardStyle(wornEdgesIntensity: 0.0)

        // Assert
        #expect(style.wornEdgesIntensity == 0.0)
    }

    @Test("RecipeCardStyle worn edges intensity handles maximum")
    func testWornEdgesIntensity_HandlesMaximum() {
        // Act
        let style = RecipeCardStyle(wornEdgesIntensity: 1.0)

        // Assert
        #expect(style.wornEdgesIntensity == 1.0)
    }

    // MARK: - Auto Love Marks Tests

    @Test("RecipeCardStyle auto love marks can be enabled")
    func testAutoLoveMarks_CanBeEnabled() {
        // Arrange
        let style = RecipeCardStyle()

        // Act
        style.autoLoveMarks = true

        // Assert
        #expect(style.autoLoveMarks == true)
    }

    @Test("RecipeCardStyle auto love marks can be disabled")
    func testAutoLoveMarks_CanBeDisabled() {
        // Arrange
        let style = RecipeCardStyle(autoLoveMarks: true)

        // Act
        style.autoLoveMarks = false

        // Assert
        #expect(style.autoLoveMarks == false)
    }

    // MARK: - Timestamp Tests

    @Test("RecipeCardStyle createdDate is set on initialization")
    func testCreatedDate_SetOnInitialization() {
        // Arrange
        let before = Date()

        // Act
        let style = RecipeCardStyle()
        let after = Date()

        // Assert
        #expect(style.createdDate >= before)
        #expect(style.createdDate <= after)
    }

    @Test("RecipeCardStyle lastModified is set on initialization")
    func testLastModified_SetOnInitialization() {
        // Arrange
        let before = Date()

        // Act
        let style = RecipeCardStyle()
        let after = Date()

        // Assert
        #expect(style.lastModified >= before)
        #expect(style.lastModified <= after)
    }

    @Test("RecipeCardStyle lastModified can be updated")
    func testLastModified_CanBeUpdated() {
        // Arrange
        let style = RecipeCardStyle()
        let originalDate = style.lastModified

        // Wait a tiny bit to ensure different timestamp
        Thread.sleep(forTimeInterval: 0.01)

        // Act
        style.lastModified = Date()

        // Assert
        #expect(style.lastModified > originalDate)
    }

    // MARK: - Recipe Relationship Tests

    @Test("RecipeCardStyle initializes with nil recipe")
    func testRecipe_InitializesAsNil() {
        // Act
        let style = RecipeCardStyle()

        // Assert
        #expect(style.recipe == nil)
    }

    @Test("RecipeCardStyle can be associated with recipe")
    func testRecipe_CanBeAssociated() {
        // Arrange
        let context = createTestContext()
        let recipe = Recipe(title: "Test Recipe")
        context.insert(recipe)

        let style = RecipeCardStyle()
        context.insert(style)

        // Act
        style.recipe = recipe

        // Assert
        #expect(style.recipe?.id == recipe.id)
    }

    // MARK: - Predefined Background Colors Tests

    @Test("RecipeCardStyle has predefined background colors")
    func testPredefinedBackgroundColors_HasColors() {
        // Assert
        #expect(RecipeCardStyle.predefinedBackgroundColors.count > 0)
    }

    @Test("RecipeCardStyle predefined colors includes cream")
    func testPredefinedBackgroundColors_IncludesCream() {
        // Assert
        #expect(RecipeCardStyle.predefinedBackgroundColors.contains("#FEFDFB"))
    }

    @Test("RecipeCardStyle predefined colors includes warm white")
    func testPredefinedBackgroundColors_IncludesWarmWhite() {
        // Assert
        #expect(RecipeCardStyle.predefinedBackgroundColors.contains("#FFF9E6"))
    }

    @Test("RecipeCardStyle predefined colors includes vanilla")
    func testPredefinedBackgroundColors_IncludesVanilla() {
        // Assert
        #expect(RecipeCardStyle.predefinedBackgroundColors.contains("#FFF4E0"))
    }

    @Test("RecipeCardStyle predefined colors includes linen")
    func testPredefinedBackgroundColors_IncludesLinen() {
        // Assert
        #expect(RecipeCardStyle.predefinedBackgroundColors.contains("#F8F3E8"))
    }

    @Test("RecipeCardStyle predefined colors includes peach")
    func testPredefinedBackgroundColors_IncludesPeach() {
        // Assert
        #expect(RecipeCardStyle.predefinedBackgroundColors.contains("#FFE5D9"))
    }

    @Test("RecipeCardStyle predefined colors includes light blue")
    func testPredefinedBackgroundColors_IncludesLightBlue() {
        // Assert
        #expect(RecipeCardStyle.predefinedBackgroundColors.contains("#E8F2F7"))
    }

    @Test("RecipeCardStyle predefined colors includes mint")
    func testPredefinedBackgroundColors_IncludesMint() {
        // Assert
        #expect(RecipeCardStyle.predefinedBackgroundColors.contains("#F0F7E8"))
    }

    @Test("RecipeCardStyle predefined colors includes tan")
    func testPredefinedBackgroundColors_IncludesTan() {
        // Assert
        #expect(RecipeCardStyle.predefinedBackgroundColors.contains("#FCF0E3"))
    }

    @Test("RecipeCardStyle has exactly 8 predefined background colors")
    func testPredefinedBackgroundColors_HasEightColors() {
        // Assert
        #expect(RecipeCardStyle.predefinedBackgroundColors.count == 8)
    }

    // MARK: - Predefined Patterns Tests

    @Test("RecipeCardStyle has predefined patterns")
    func testPredefinedPatterns_HasPatterns() {
        // Assert
        #expect(RecipeCardStyle.predefinedPatterns.count > 0)
    }

    @Test("RecipeCardStyle predefined patterns includes dots")
    func testPredefinedPatterns_IncludesDots() {
        // Assert
        #expect(RecipeCardStyle.predefinedPatterns.contains("pattern-dots"))
    }

    @Test("RecipeCardStyle predefined patterns includes lines")
    func testPredefinedPatterns_IncludesLines() {
        // Assert
        #expect(RecipeCardStyle.predefinedPatterns.contains("pattern-lines"))
    }

    @Test("RecipeCardStyle predefined patterns includes grid")
    func testPredefinedPatterns_IncludesGrid() {
        // Assert
        #expect(RecipeCardStyle.predefinedPatterns.contains("pattern-grid"))
    }

    @Test("RecipeCardStyle predefined patterns includes vintage")
    func testPredefinedPatterns_IncludesVintage() {
        // Assert
        #expect(RecipeCardStyle.predefinedPatterns.contains("pattern-vintage"))
    }

    @Test("RecipeCardStyle has exactly 4 predefined patterns")
    func testPredefinedPatterns_HasFourPatterns() {
        // Assert
        #expect(RecipeCardStyle.predefinedPatterns.count == 4)
    }

    // MARK: - Predefined Textures Tests

    @Test("RecipeCardStyle has predefined textures")
    func testPredefinedTextures_HasTextures() {
        // Assert
        #expect(RecipeCardStyle.predefinedTextures.count > 0)
    }

    @Test("RecipeCardStyle predefined textures includes paper")
    func testPredefinedTextures_IncludesPaper() {
        // Assert
        #expect(RecipeCardStyle.predefinedTextures.contains("texture-paper"))
    }

    @Test("RecipeCardStyle predefined textures includes fabric")
    func testPredefinedTextures_IncludesFabric() {
        // Assert
        #expect(RecipeCardStyle.predefinedTextures.contains("texture-fabric"))
    }

    @Test("RecipeCardStyle predefined textures includes kraft")
    func testPredefinedTextures_IncludesKraft() {
        // Assert
        #expect(RecipeCardStyle.predefinedTextures.contains("texture-kraft"))
    }

    @Test("RecipeCardStyle predefined textures includes parchment")
    func testPredefinedTextures_IncludesParchment() {
        // Assert
        #expect(RecipeCardStyle.predefinedTextures.contains("texture-parchment"))
    }

    @Test("RecipeCardStyle has exactly 4 predefined textures")
    func testPredefinedTextures_HasFourTextures() {
        // Assert
        #expect(RecipeCardStyle.predefinedTextures.count == 4)
    }

    // MARK: - Codable Tests

    @Test("BackgroundType encodes to raw string value")
    func testBackgroundType_EncodesToRawValue() throws {
        // Arrange
        let type = RecipeCardStyle.BackgroundType.gradient
        let encoder = JSONEncoder()

        // Act
        let data = try encoder.encode(type)
        let jsonString = String(data: data, encoding: .utf8)

        // Assert
        #expect(jsonString == "\"gradient\"")
    }

    @Test("BackgroundType decodes from raw string value")
    func testBackgroundType_DecodesFromRawValue() throws {
        // Arrange
        let jsonData = "\"texture\"".data(using: .utf8)!
        let decoder = JSONDecoder()

        // Act
        let type = try decoder.decode(RecipeCardStyle.BackgroundType.self, from: jsonData)

        // Assert
        #expect(type == .texture)
    }

    @Test("CoffeeStainPosition encodes to raw string value")
    func testCoffeeStainPosition_EncodesToRawValue() throws {
        // Arrange
        let position = RecipeCardStyle.CoffeeStainPosition.bottomLeft
        let encoder = JSONEncoder()

        // Act
        let data = try encoder.encode(position)
        let jsonString = String(data: data, encoding: .utf8)

        // Assert
        #expect(jsonString == "\"bottomLeft\"")
    }

    @Test("CoffeeStainPosition decodes from raw string value")
    func testCoffeeStainPosition_DecodesFromRawValue() throws {
        // Arrange
        let jsonData = "\"center\"".data(using: .utf8)!
        let decoder = JSONDecoder()

        // Act
        let position = try decoder.decode(RecipeCardStyle.CoffeeStainPosition.self, from: jsonData)

        // Assert
        #expect(position == .center)
    }

    // MARK: - Edge Case Tests

    @Test("RecipeCardStyle handles intermediate worn edges intensity")
    func testWornEdgesIntensity_HandlesIntermediateValue() {
        // Act
        let style = RecipeCardStyle(wornEdgesIntensity: 0.42)

        // Assert
        #expect(style.wornEdgesIntensity == 0.42)
    }

    @Test("RecipeCardStyle can have coffee stain without position")
    func testCoffeeStain_EnabledWithoutPosition() {
        // Act
        let style = RecipeCardStyle(coffeeStainEnabled: true)

        // Assert
        #expect(style.coffeeStainEnabled == true)
        #expect(style.coffeeStainPosition == nil)
    }

    @Test("RecipeCardStyle can have coffee stain position without enabled")
    func testCoffeeStain_PositionWithoutEnabled() {
        // Arrange
        let style = RecipeCardStyle(coffeeStainEnabled: false)

        // Act
        style.coffeeStainPosition = .topLeft

        // Assert
        #expect(style.coffeeStainEnabled == false)
        #expect(style.coffeeStainPosition == .topLeft)
    }

    @Test("RecipeCardStyle can combine all love mark features")
    func testLoveMarks_CombinedFeatures() {
        // Act
        let style = RecipeCardStyle(
            coffeeStainEnabled: true,
            wornEdgesIntensity: 0.7,
            autoLoveMarks: true
        )
        style.coffeeStainPosition = .bottomRight

        // Assert
        #expect(style.coffeeStainEnabled == true)
        #expect(style.coffeeStainPosition == .bottomRight)
        #expect(style.wornEdgesIntensity == 0.7)
        #expect(style.autoLoveMarks == true)
    }

    @Test("RecipeCardStyle solid background can have color")
    func testSolidBackground_WithColor() {
        // Act
        let style = RecipeCardStyle(backgroundType: .solid)
        style.backgroundColorHex = "#FEFDFB"

        // Assert
        #expect(style.backgroundType == .solid)
        #expect(style.backgroundColorHex == "#FEFDFB")
    }

    @Test("RecipeCardStyle pattern background can have image name")
    func testPatternBackground_WithImageName() {
        // Act
        let style = RecipeCardStyle(backgroundType: .pattern)
        style.backgroundImageName = "pattern-dots"

        // Assert
        #expect(style.backgroundType == .pattern)
        #expect(style.backgroundImageName == "pattern-dots")
    }

    @Test("RecipeCardStyle texture background can have image name")
    func testTextureBackground_WithImageName() {
        // Act
        let style = RecipeCardStyle(backgroundType: .texture)
        style.backgroundImageName = "texture-paper"

        // Assert
        #expect(style.backgroundType == .texture)
        #expect(style.backgroundImageName == "texture-paper")
    }
}
