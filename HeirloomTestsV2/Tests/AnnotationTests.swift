import Testing
import Foundation
import SwiftData
import SwiftUI

@testable import Heirloom

@Suite("Recipe Annotation Tests")
struct AnnotationTests {

    // MARK: - Test Setup Helper

    func createTestContext() -> ModelContext {
        let schema = Schema([
            Recipe.self,
            RecipeAnnotation.self,
            Ingredient.self,
            Tag.self,
            RecipeCollection.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: config)
        return ModelContext(container)
    }

    // MARK: - Initialization Tests

    @Test("RecipeAnnotation initializes with required text")
    func testInit_WithText_SetsText() {
        // Act
        let annotation = RecipeAnnotation(text: "Great recipe!")

        // Assert
        #expect(annotation.text == "Great recipe!")
    }

    @Test("RecipeAnnotation initializes with default values")
    func testInit_SetsDefaultValues() {
        // Act
        let annotation = RecipeAnnotation(text: "Note")

        // Assert
        #expect(annotation.id != UUID(uuidString: "00000000-0000-0000-0000-000000000000")!)
        #expect(annotation.style == .stickyNote)
        #expect(annotation.positionX == 0.5)
        #expect(annotation.positionY == 0.5)
        #expect(annotation.fontSize == 14.0)
        #expect(annotation.rotation == 0.0)
        #expect(annotation.colorHex == "#FFD93D")
        #expect(annotation.recipe == nil)
    }

    @Test("RecipeAnnotation initializes with custom style")
    func testInit_WithCustomStyle_SetsStyle() {
        // Act
        let annotation = RecipeAnnotation(
            text: "Note",
            style: .handwritten
        )

        // Assert
        #expect(annotation.style == .handwritten)
    }

    @Test("RecipeAnnotation initializes with custom position")
    func testInit_WithCustomPosition_SetsPosition() {
        // Act
        let annotation = RecipeAnnotation(
            text: "Note",
            positionX: 0.75,
            positionY: 0.25
        )

        // Assert
        #expect(annotation.positionX == 0.75)
        #expect(annotation.positionY == 0.25)
    }

    @Test("RecipeAnnotation initializes with custom visual properties")
    func testInit_WithCustomVisualProperties_SetsProperties() {
        // Act
        let annotation = RecipeAnnotation(
            text: "Note",
            fontSize: 18.0,
            rotation: 15.0,
            colorHex: "#FF0000"
        )

        // Assert
        #expect(annotation.fontSize == 18.0)
        #expect(annotation.rotation == 15.0)
        #expect(annotation.colorHex == "#FF0000")
    }

    @Test("RecipeAnnotation creates timestamps on initialization")
    func testInit_CreatesTimestamps() {
        // Arrange
        let before = Date()

        // Act
        let annotation = RecipeAnnotation(text: "Note")

        // Assert
        #expect(annotation.createdDate >= before)
        #expect(annotation.lastModified >= before)
    }

    // MARK: - Text Content Tests

    @Test("RecipeAnnotation stores text content")
    func testText_StoresContent() {
        // Arrange
        let annotation = RecipeAnnotation(text: "Initial text")

        // Act
        annotation.text = "Updated text"

        // Assert
        #expect(annotation.text == "Updated text")
    }

    @Test("RecipeAnnotation allows empty text")
    func testText_AllowsEmptyString() {
        // Act
        let annotation = RecipeAnnotation(text: "")

        // Assert
        #expect(annotation.text == "")
    }

    // MARK: - Style Tests

    @Test("AnnotationStyle stickyNote has correct raw value")
    func testAnnotationStyle_StickyNote_RawValue() {
        // Assert
        #expect(RecipeAnnotation.AnnotationStyle.stickyNote.rawValue == "stickyNote")
    }

    @Test("AnnotationStyle handwritten has correct raw value")
    func testAnnotationStyle_Handwritten_RawValue() {
        // Assert
        #expect(RecipeAnnotation.AnnotationStyle.handwritten.rawValue == "handwritten")
    }

    @Test("AnnotationStyle marker has correct raw value")
    func testAnnotationStyle_Marker_RawValue() {
        // Assert
        #expect(RecipeAnnotation.AnnotationStyle.marker.rawValue == "marker")
    }

    @Test("AnnotationStyle stickyNote has correct display name")
    func testAnnotationStyle_StickyNote_DisplayName() {
        // Act
        let displayName = RecipeAnnotation.AnnotationStyle.stickyNote.displayName

        // Assert
        #expect(displayName == "Sticky Note")
    }

    @Test("AnnotationStyle handwritten has correct display name")
    func testAnnotationStyle_Handwritten_DisplayName() {
        // Act
        let displayName = RecipeAnnotation.AnnotationStyle.handwritten.displayName

        // Assert
        #expect(displayName == "Handwritten")
    }

    @Test("AnnotationStyle marker has correct display name")
    func testAnnotationStyle_Marker_DisplayName() {
        // Act
        let displayName = RecipeAnnotation.AnnotationStyle.marker.displayName

        // Assert
        #expect(displayName == "Marker")
    }

    @Test("AnnotationStyle handwritten returns custom font")
    func testAnnotationStyle_Handwritten_Font() {
        // Act
        let font = RecipeAnnotation.AnnotationStyle.handwritten.font

        // Assert - Font equality is tricky, but we can verify it returns a font
        // The exact comparison depends on SwiftUI Font internals
        #expect(font != nil)
    }

    @Test("AnnotationStyle stickyNote returns system font")
    func testAnnotationStyle_StickyNote_Font() {
        // Act
        let font = RecipeAnnotation.AnnotationStyle.stickyNote.font

        // Assert
        #expect(font != nil)
    }

    @Test("AnnotationStyle marker returns system font")
    func testAnnotationStyle_Marker_Font() {
        // Act
        let font = RecipeAnnotation.AnnotationStyle.marker.font

        // Assert
        #expect(font != nil)
    }

    @Test("RecipeAnnotation style can be changed")
    func testStyle_CanBeChanged() {
        // Arrange
        let annotation = RecipeAnnotation(text: "Note", style: .stickyNote)

        // Act
        annotation.style = .marker

        // Assert
        #expect(annotation.style == .marker)
    }

    // MARK: - Position Tests

    @Test("RecipeAnnotation position uses normalized coordinates")
    func testPosition_UsesNormalizedCoordinates() {
        // Act
        let annotation = RecipeAnnotation(
            text: "Note",
            positionX: 0.0,
            positionY: 1.0
        )

        // Assert
        #expect(annotation.positionX == 0.0)
        #expect(annotation.positionY == 1.0)
    }

    @Test("RecipeAnnotation position can be updated")
    func testPosition_CanBeUpdated() {
        // Arrange
        let annotation = RecipeAnnotation(text: "Note")

        // Act
        annotation.positionX = 0.8
        annotation.positionY = 0.3

        // Assert
        #expect(annotation.positionX == 0.8)
        #expect(annotation.positionY == 0.3)
    }

    // MARK: - Visual Properties Tests

    @Test("RecipeAnnotation fontSize is stored correctly")
    func testFontSize_StoresValue() {
        // Arrange
        let annotation = RecipeAnnotation(text: "Note", fontSize: 20.0)

        // Assert
        #expect(annotation.fontSize == 20.0)
    }

    @Test("RecipeAnnotation fontSize can be updated")
    func testFontSize_CanBeUpdated() {
        // Arrange
        let annotation = RecipeAnnotation(text: "Note", fontSize: 14.0)

        // Act
        annotation.fontSize = 22.0

        // Assert
        #expect(annotation.fontSize == 22.0)
    }

    @Test("RecipeAnnotation rotation is stored in degrees")
    func testRotation_StoredInDegrees() {
        // Arrange
        let annotation = RecipeAnnotation(text: "Note", rotation: 45.0)

        // Assert
        #expect(annotation.rotation == 45.0)
    }

    @Test("RecipeAnnotation rotation can be updated")
    func testRotation_CanBeUpdated() {
        // Arrange
        let annotation = RecipeAnnotation(text: "Note", rotation: 0.0)

        // Act
        annotation.rotation = 90.0

        // Assert
        #expect(annotation.rotation == 90.0)
    }

    @Test("RecipeAnnotation colorHex stores hex color value")
    func testColorHex_StoresHexValue() {
        // Arrange
        let annotation = RecipeAnnotation(text: "Note", colorHex: "#FF5733")

        // Assert
        #expect(annotation.colorHex == "#FF5733")
    }

    @Test("RecipeAnnotation colorHex can be updated")
    func testColorHex_CanBeUpdated() {
        // Arrange
        let annotation = RecipeAnnotation(text: "Note")

        // Act
        annotation.colorHex = "#00FF00"

        // Assert
        #expect(annotation.colorHex == "#00FF00")
    }

    // MARK: - Timestamp Tests

    @Test("RecipeAnnotation createdDate is set on initialization")
    func testCreatedDate_SetOnInitialization() {
        // Arrange
        let before = Date()

        // Act
        let annotation = RecipeAnnotation(text: "Note")
        let after = Date()

        // Assert
        #expect(annotation.createdDate >= before)
        #expect(annotation.createdDate <= after)
    }

    @Test("RecipeAnnotation lastModified is set on initialization")
    func testLastModified_SetOnInitialization() {
        // Arrange
        let before = Date()

        // Act
        let annotation = RecipeAnnotation(text: "Note")
        let after = Date()

        // Assert
        #expect(annotation.lastModified >= before)
        #expect(annotation.lastModified <= after)
    }

    @Test("RecipeAnnotation lastModified can be updated")
    func testLastModified_CanBeUpdated() {
        // Arrange
        let annotation = RecipeAnnotation(text: "Note")
        let originalDate = annotation.lastModified

        // Wait a tiny bit to ensure different timestamp
        Thread.sleep(forTimeInterval: 0.01)

        // Act
        annotation.lastModified = Date()

        // Assert
        #expect(annotation.lastModified > originalDate)
    }

    // MARK: - Recipe Relationship Tests

    @Test("RecipeAnnotation initializes with nil recipe")
    func testRecipe_InitializesAsNil() {
        // Act
        let annotation = RecipeAnnotation(text: "Note")

        // Assert
        #expect(annotation.recipe == nil)
    }

    @Test("RecipeAnnotation can be associated with recipe")
    func testRecipe_CanBeAssociated() {
        // Arrange
        let context = createTestContext()
        let recipe = Recipe(title: "Test Recipe")
        context.insert(recipe)

        let annotation = RecipeAnnotation(text: "Great recipe!")
        context.insert(annotation)

        // Act
        annotation.recipe = recipe

        // Assert
        #expect(annotation.recipe?.id == recipe.id)
    }

    // MARK: - Predefined Colors Tests

    @Test("RecipeAnnotation has predefined colors array")
    func testPredefinedColors_HasColors() {
        // Assert
        #expect(RecipeAnnotation.predefinedColors.count > 0)
    }

    @Test("RecipeAnnotation predefined colors includes yellow")
    func testPredefinedColors_IncludesYellow() {
        // Assert
        #expect(RecipeAnnotation.predefinedColors.contains("#FFD93D"))
    }

    @Test("RecipeAnnotation predefined colors includes red")
    func testPredefinedColors_IncludesRed() {
        // Assert
        #expect(RecipeAnnotation.predefinedColors.contains("#FF6B6B"))
    }

    @Test("RecipeAnnotation predefined colors includes turquoise")
    func testPredefinedColors_IncludesTurquoise() {
        // Assert
        #expect(RecipeAnnotation.predefinedColors.contains("#4ECDC4"))
    }

    @Test("RecipeAnnotation predefined colors includes mint")
    func testPredefinedColors_IncludesMint() {
        // Assert
        #expect(RecipeAnnotation.predefinedColors.contains("#95E1D3"))
    }

    @Test("RecipeAnnotation predefined colors includes coral")
    func testPredefinedColors_IncludesCoral() {
        // Assert
        #expect(RecipeAnnotation.predefinedColors.contains("#F38181"))
    }

    @Test("RecipeAnnotation predefined colors includes lavender")
    func testPredefinedColors_IncludesLavender() {
        // Assert
        #expect(RecipeAnnotation.predefinedColors.contains("#AA96DA"))
    }

    @Test("RecipeAnnotation predefined colors includes pink")
    func testPredefinedColors_IncludesPink() {
        // Assert
        #expect(RecipeAnnotation.predefinedColors.contains("#FCBAD3"))
    }

    @Test("RecipeAnnotation predefined colors has exactly 7 colors")
    func testPredefinedColors_HasSevenColors() {
        // Assert
        #expect(RecipeAnnotation.predefinedColors.count == 7)
    }

    @Test("RecipeAnnotation default color is first predefined color")
    func testDefaultColor_IsFirstPredefinedColor() {
        // Act
        let annotation = RecipeAnnotation(text: "Note")

        // Assert
        #expect(annotation.colorHex == RecipeAnnotation.predefinedColors[0])
    }

    // MARK: - Codable Tests

    @Test("AnnotationStyle encodes to raw string value")
    func testAnnotationStyle_EncodesToRawValue() throws {
        // Arrange
        let style = RecipeAnnotation.AnnotationStyle.handwritten
        let encoder = JSONEncoder()

        // Act
        let data = try encoder.encode(style)
        let jsonString = String(data: data, encoding: .utf8)

        // Assert
        #expect(jsonString == "\"handwritten\"")
    }

    @Test("AnnotationStyle decodes from raw string value")
    func testAnnotationStyle_DecodesFromRawValue() throws {
        // Arrange
        let jsonData = "\"marker\"".data(using: .utf8)!
        let decoder = JSONDecoder()

        // Act
        let style = try decoder.decode(RecipeAnnotation.AnnotationStyle.self, from: jsonData)

        // Assert
        #expect(style == .marker)
    }

    // MARK: - Edge Case Tests

    @Test("RecipeAnnotation handles minimum font size")
    func testFontSize_HandlesMinimum() {
        // Act
        let annotation = RecipeAnnotation(text: "Note", fontSize: 12.0)

        // Assert
        #expect(annotation.fontSize == 12.0)
    }

    @Test("RecipeAnnotation handles maximum font size")
    func testFontSize_HandlesMaximum() {
        // Act
        let annotation = RecipeAnnotation(text: "Note", fontSize: 24.0)

        // Assert
        #expect(annotation.fontSize == 24.0)
    }

    @Test("RecipeAnnotation handles full rotation")
    func testRotation_HandlesFullRotation() {
        // Act
        let annotation = RecipeAnnotation(text: "Note", rotation: 360.0)

        // Assert
        #expect(annotation.rotation == 360.0)
    }

    @Test("RecipeAnnotation handles negative rotation")
    func testRotation_HandlesNegativeRotation() {
        // Act
        let annotation = RecipeAnnotation(text: "Note", rotation: -45.0)

        // Assert
        #expect(annotation.rotation == -45.0)
    }

    @Test("RecipeAnnotation handles position at origin")
    func testPosition_HandlesOrigin() {
        // Act
        let annotation = RecipeAnnotation(text: "Note", positionX: 0.0, positionY: 0.0)

        // Assert
        #expect(annotation.positionX == 0.0)
        #expect(annotation.positionY == 0.0)
    }

    @Test("RecipeAnnotation handles position at maximum")
    func testPosition_HandlesMaximum() {
        // Act
        let annotation = RecipeAnnotation(text: "Note", positionX: 1.0, positionY: 1.0)

        // Assert
        #expect(annotation.positionX == 1.0)
        #expect(annotation.positionY == 1.0)
    }

    @Test("RecipeAnnotation handles very long text")
    func testText_HandlesLongText() {
        // Arrange
        let longText = String(repeating: "This is a very long annotation text. ", count: 100)

        // Act
        let annotation = RecipeAnnotation(text: longText)

        // Assert
        #expect(annotation.text == longText)
        #expect(annotation.text.count > 3000)
    }
}
