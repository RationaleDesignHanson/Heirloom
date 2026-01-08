import Testing
import Foundation

@testable import Heirloom

@Suite("Recipe Source Type Tests")
struct RecipeSourceTypeTests {

    // MARK: - Enum Cases Tests

    @Test("RecipeSourceType has all expected cases")
    func testRecipeSourceType_AllCases() {
        // Arrange & Act
        let allCases = RecipeSourceType.allCases

        // Assert
        #expect(allCases.count == 6)
        #expect(allCases.contains(.url))
        #expect(allCases.contains(.cookbook))
        #expect(allCases.contains(.family))
        #expect(allCases.contains(.manual))
        #expect(allCases.contains(.scan))
        #expect(allCases.contains(.heritage))
    }

    // MARK: - Icon Name Tests

    @Test("URL source type returns correct icon name")
    func testIconName_URL_ReturnsGlobeIcon() {
        // Arrange
        let sourceType = RecipeSourceType.url

        // Act & Assert
        #expect(sourceType.iconName == "globe")
    }

    @Test("Cookbook source type returns correct icon name")
    func testIconName_Cookbook_ReturnsBookIcon() {
        // Arrange
        let sourceType = RecipeSourceType.cookbook

        // Act & Assert
        #expect(sourceType.iconName == "book.closed")
    }

    @Test("Family source type returns correct icon name")
    func testIconName_Family_ReturnsFigureIcon() {
        // Arrange
        let sourceType = RecipeSourceType.family

        // Act & Assert
        #expect(sourceType.iconName == "figure.2.and.child.holdinghands")
    }

    @Test("Manual source type returns correct icon name")
    func testIconName_Manual_ReturnsPencilIcon() {
        // Arrange
        let sourceType = RecipeSourceType.manual

        // Act & Assert
        #expect(sourceType.iconName == "pencil")
    }

    @Test("Scan source type returns correct icon name")
    func testIconName_Scan_ReturnsCameraIcon() {
        // Arrange
        let sourceType = RecipeSourceType.scan

        // Act & Assert
        #expect(sourceType.iconName == "camera")
    }

    @Test("Heritage source type returns correct icon name")
    func testIconName_Heritage_ReturnsSparklesIcon() {
        // Arrange
        let sourceType = RecipeSourceType.heritage

        // Act & Assert
        #expect(sourceType.iconName == "sparkles")
    }

    // MARK: - Display Name Tests

    @Test("URL source type returns correct display name")
    func testDisplayName_URL_ReturnsWebsite() {
        // Arrange
        let sourceType = RecipeSourceType.url

        // Act & Assert
        #expect(sourceType.displayName == "Website")
    }

    @Test("Cookbook source type returns correct display name")
    func testDisplayName_Cookbook_ReturnsCookbook() {
        // Arrange
        let sourceType = RecipeSourceType.cookbook

        // Act & Assert
        #expect(sourceType.displayName == "Cookbook")
    }

    @Test("Family source type returns correct display name")
    func testDisplayName_Family_ReturnsFamilyRecipe() {
        // Arrange
        let sourceType = RecipeSourceType.family

        // Act & Assert
        #expect(sourceType.displayName == "Family Recipe")
    }

    @Test("Manual source type returns correct display name")
    func testDisplayName_Manual_ReturnsMyRecipe() {
        // Arrange
        let sourceType = RecipeSourceType.manual

        // Act & Assert
        #expect(sourceType.displayName == "My Recipe")
    }

    @Test("Scan source type returns correct display name")
    func testDisplayName_Scan_ReturnsScannedRecipe() {
        // Arrange
        let sourceType = RecipeSourceType.scan

        // Act & Assert
        #expect(sourceType.displayName == "Scanned Recipe")
    }

    @Test("Heritage source type returns correct display name")
    func testDisplayName_Heritage_ReturnsHeritageCollection() {
        // Arrange
        let sourceType = RecipeSourceType.heritage

        // Act & Assert
        #expect(sourceType.displayName == "Heritage Collection")
    }

    // MARK: - Codable Tests

    @Test("RecipeSourceType encodes to raw string value")
    func testCodable_Encoding() throws {
        // Arrange
        let encoder = JSONEncoder()
        let sourceType = RecipeSourceType.cookbook

        // Act
        let encoded = try encoder.encode(sourceType)
        let jsonString = String(data: encoded, encoding: .utf8)

        // Assert
        #expect(jsonString == "\"cookbook\"")
    }

    @Test("RecipeSourceType decodes from raw string value")
    func testCodable_Decoding() throws {
        // Arrange
        let decoder = JSONDecoder()
        let jsonData = "\"family\"".data(using: .utf8)!

        // Act
        let decoded = try decoder.decode(RecipeSourceType.self, from: jsonData)

        // Assert
        #expect(decoded == .family)
    }

    @Test("RecipeSourceType decodes all valid cases")
    func testCodable_DecodesAllCases() throws {
        // Arrange
        let decoder = JSONDecoder()
        let testCases: [(String, RecipeSourceType)] = [
            ("\"url\"", .url),
            ("\"cookbook\"", .cookbook),
            ("\"family\"", .family),
            ("\"manual\"", .manual),
            ("\"scan\"", .scan),
            ("\"heritage\"", .heritage)
        ]

        // Act & Assert
        for (json, expectedType) in testCases {
            let jsonData = json.data(using: .utf8)!
            let decoded = try decoder.decode(RecipeSourceType.self, from: jsonData)
            #expect(decoded == expectedType, "Failed to decode \(json)")
        }
    }

    @Test("RecipeSourceType encoding-decoding round trip")
    func testCodable_RoundTrip() throws {
        // Arrange
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        // Act & Assert - test all cases
        for sourceType in RecipeSourceType.allCases {
            let encoded = try encoder.encode(sourceType)
            let decoded = try decoder.decode(RecipeSourceType.self, from: encoded)
            #expect(decoded == sourceType, "Round trip failed for \(sourceType)")
        }
    }

    // MARK: - Recipe Integration Tests

    @Test("Recipe can be initialized with each source type")
    func testRecipe_InitializationWithSourceTypes() {
        // Act & Assert
        for sourceType in RecipeSourceType.allCases {
            let recipe = Heirloom.Recipe(title: "Test Recipe", sourceType: sourceType)
            #expect(recipe.sourceType == sourceType)
        }
    }

    @Test("Recipe source type can be changed after initialization")
    func testRecipe_SourceTypeCanBeChanged() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe", sourceType: .manual)

        // Act
        recipe.sourceType = .cookbook

        // Assert
        #expect(recipe.sourceType == .cookbook)
    }

    @Test("Recipe source type affects source display name")
    func testRecipe_SourceTypeAffectsDisplayName() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe", sourceType: .manual)

        // Act & Assert - manual type
        #expect(recipe.sourceDisplayName == "My Recipe")

        // Change source type
        recipe.sourceType = .heritage

        // Assert - heritage type
        #expect(recipe.sourceDisplayName == "Heritage Collection")
    }

    // MARK: - Raw Value Tests

    @Test("RecipeSourceType raw values match expected strings")
    func testRawValues_MatchExpectedStrings() {
        // Assert
        #expect(RecipeSourceType.url.rawValue == "url")
        #expect(RecipeSourceType.cookbook.rawValue == "cookbook")
        #expect(RecipeSourceType.family.rawValue == "family")
        #expect(RecipeSourceType.manual.rawValue == "manual")
        #expect(RecipeSourceType.scan.rawValue == "scan")
        #expect(RecipeSourceType.heritage.rawValue == "heritage")
    }

    @Test("RecipeSourceType can be initialized from raw value")
    func testRawValue_Initialization() {
        // Act & Assert
        #expect(RecipeSourceType(rawValue: "url") == .url)
        #expect(RecipeSourceType(rawValue: "cookbook") == .cookbook)
        #expect(RecipeSourceType(rawValue: "family") == .family)
        #expect(RecipeSourceType(rawValue: "manual") == .manual)
        #expect(RecipeSourceType(rawValue: "scan") == .scan)
        #expect(RecipeSourceType(rawValue: "heritage") == .heritage)
    }

    @Test("RecipeSourceType returns nil for invalid raw value")
    func testRawValue_InvalidReturnsNil() {
        // Act
        let invalidSourceType = RecipeSourceType(rawValue: "invalid")

        // Assert
        #expect(invalidSourceType == nil)
    }
}
