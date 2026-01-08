import Testing
import Foundation

@testable import Heirloom

@Suite("Import Attempt Tests")
struct ImportAttemptTests {

    // MARK: - ImportAttempt Initialization Tests

    @Test("ImportAttempt stores required properties")
    func testImportAttempt_StoresProperties() {
        // Arrange
        let timestamp = Date()
        let extracted = ExtractedRecipe(
            title: "Test Recipe",
            ingredients: ["Salt"],
            instructions: ["Mix"]
        )

        // Act
        let attempt = ImportAttempt(
            id: "test-123",
            url: "https://example.com/recipe",
            domain: "example.com",
            timestamp: timestamp,
            userId: "user-456",
            status: .success,
            extracted: extracted,
            parserUsed: .schemaOrg,
            confidence: 0.95,
            errors: nil,
            parseTimeMs: 250
        )

        // Assert
        #expect(attempt.id == "test-123")
        #expect(attempt.url == "https://example.com/recipe")
        #expect(attempt.domain == "example.com")
        #expect(attempt.timestamp == timestamp)
        #expect(attempt.userId == "user-456")
        #expect(attempt.status == .success)
        #expect(attempt.extracted?.title == "Test Recipe")
        #expect(attempt.parserUsed == .schemaOrg)
        #expect(attempt.confidence == 0.95)
        #expect(attempt.errors == nil)
        #expect(attempt.parseTimeMs == 250)
    }

    @Test("ImportAttempt allows nil userId")
    func testImportAttempt_AllowsNilUserId() {
        // Act
        let attempt = ImportAttempt(
            id: "test-123",
            url: "https://example.com/recipe",
            domain: "example.com",
            timestamp: Date(),
            userId: nil,
            status: .success,
            extracted: nil,
            parserUsed: .heuristic,
            confidence: 0.8,
            errors: nil,
            parseTimeMs: 200
        )

        // Assert
        #expect(attempt.userId == nil)
    }

    @Test("ImportAttempt allows nil extracted recipe")
    func testImportAttempt_AllowsNilExtracted() {
        // Act
        let attempt = ImportAttempt(
            id: "test-123",
            url: "https://example.com/recipe",
            domain: "example.com",
            timestamp: Date(),
            userId: "user-456",
            status: .failed,
            extracted: nil,
            parserUsed: .none,
            confidence: 0.0,
            errors: [],
            parseTimeMs: 100
        )

        // Assert
        #expect(attempt.extracted == nil)
    }

    // MARK: - ImportStatus Enum Tests

    @Test("ImportStatus success has correct raw value")
    func testImportStatus_Success_RawValue() {
        // Assert
        #expect(ImportAttempt.ImportStatus.success.rawValue == "success")
    }

    @Test("ImportStatus partial has correct raw value")
    func testImportStatus_Partial_RawValue() {
        // Assert
        #expect(ImportAttempt.ImportStatus.partial.rawValue == "partial")
    }

    @Test("ImportStatus failed has correct raw value")
    func testImportStatus_Failed_RawValue() {
        // Assert
        #expect(ImportAttempt.ImportStatus.failed.rawValue == "failed")
    }

    // MARK: - ParserType Enum Tests

    @Test("ParserType schemaOrg has correct raw value")
    func testParserType_SchemaOrg_RawValue() {
        // Assert
        #expect(ImportAttempt.ParserType.schemaOrg.rawValue == "schemaOrg")
    }

    @Test("ParserType heuristic has correct raw value")
    func testParserType_Heuristic_RawValue() {
        // Assert
        #expect(ImportAttempt.ParserType.heuristic.rawValue == "heuristic")
    }

    @Test("ParserType none has correct raw value")
    func testParserType_None_RawValue() {
        // Assert
        #expect(ImportAttempt.ParserType.none.rawValue == "none")
    }

    // MARK: - ExtractedRecipe Tests

    @Test("ExtractedRecipe stores required fields")
    func testExtractedRecipe_StoresRequiredFields() {
        // Act
        let recipe = ExtractedRecipe(
            title: "Chocolate Cake",
            ingredients: ["Flour", "Sugar", "Cocoa"],
            instructions: ["Mix dry ingredients", "Add wet ingredients", "Bake"]
        )

        // Assert
        #expect(recipe.title == "Chocolate Cake")
        #expect(recipe.ingredients.count == 3)
        #expect(recipe.ingredients[0] == "Flour")
        #expect(recipe.instructions.count == 3)
        #expect(recipe.instructions[0] == "Mix dry ingredients")
    }

    @Test("ExtractedRecipe stores optional servings")
    func testExtractedRecipe_StoresServings() {
        // Act
        let recipe = ExtractedRecipe(
            title: "Test",
            ingredients: [],
            instructions: [],
            servings: "4 servings"
        )

        // Assert
        #expect(recipe.servings == "4 servings")
    }

    @Test("ExtractedRecipe stores optional times")
    func testExtractedRecipe_StoresTimes() {
        // Act
        let recipe = ExtractedRecipe(
            title: "Test",
            ingredients: [],
            instructions: [],
            servings: nil,
            prepTime: "15 min",
            cookTime: "30 min",
            totalTime: "45 min"
        )

        // Assert
        #expect(recipe.prepTime == "15 min")
        #expect(recipe.cookTime == "30 min")
        #expect(recipe.totalTime == "45 min")
    }

    @Test("ExtractedRecipe stores optional image URL")
    func testExtractedRecipe_StoresImageURL() {
        // Act
        let recipe = ExtractedRecipe(
            title: "Test",
            ingredients: [],
            instructions: [],
            servings: nil,
            prepTime: nil,
            cookTime: nil,
            totalTime: nil,
            imageUrl: "https://example.com/image.jpg"
        )

        // Assert
        #expect(recipe.imageUrl == "https://example.com/image.jpg")
    }

    @Test("ExtractedRecipe stores optional rating")
    func testExtractedRecipe_StoresRating() {
        // Act
        let recipe = ExtractedRecipe(
            title: "Test",
            ingredients: [],
            instructions: [],
            servings: nil,
            prepTime: nil,
            cookTime: nil,
            totalTime: nil,
            imageUrl: nil,
            rating: 4.5,
            ratingCount: 120
        )

        // Assert
        #expect(recipe.rating == 4.5)
        #expect(recipe.ratingCount == 120)
    }

    @Test("ExtractedRecipe stores optional metadata")
    func testExtractedRecipe_StoresMetadata() {
        // Act
        let recipe = ExtractedRecipe(
            title: "Test",
            ingredients: [],
            instructions: [],
            servings: nil,
            prepTime: nil,
            cookTime: nil,
            totalTime: nil,
            imageUrl: nil,
            rating: nil,
            ratingCount: nil,
            description: "A delicious recipe",
            author: "Chef John",
            category: "Desserts",
            cuisine: "Italian",
            keywords: ["chocolate", "cake", "dessert"]
        )

        // Assert
        #expect(recipe.description == "A delicious recipe")
        #expect(recipe.author == "Chef John")
        #expect(recipe.category == "Desserts")
        #expect(recipe.cuisine == "Italian")
        #expect(recipe.keywords?.count == 3)
        #expect(recipe.keywords?[0] == "chocolate")
    }

    // MARK: - ServerImportError Tests

    @Test("ServerImportError stores required fields")
    func testServerImportError_StoresFields() {
        // Act
        let error = ServerImportError(
            type: .parsing,
            message: "Failed to parse ingredients",
            field: "ingredients"
        )

        // Assert
        #expect(error.type == .parsing)
        #expect(error.message == "Failed to parse ingredients")
        #expect(error.field == "ingredients")
    }

    @Test("ServerImportError allows nil field")
    func testServerImportError_AllowsNilField() {
        // Act
        let error = ServerImportError(
            type: .network,
            message: "Connection timeout",
            field: nil
        )

        // Assert
        #expect(error.field == nil)
    }

    // MARK: - ErrorType Enum Tests

    @Test("ErrorType network has correct raw value")
    func testErrorType_Network_RawValue() {
        // Assert
        #expect(ServerImportError.ErrorType.network.rawValue == "network")
    }

    @Test("ErrorType parsing has correct raw value")
    func testErrorType_Parsing_RawValue() {
        // Assert
        #expect(ServerImportError.ErrorType.parsing.rawValue == "parsing")
    }

    @Test("ErrorType validation has correct raw value")
    func testErrorType_Validation_RawValue() {
        // Assert
        #expect(ServerImportError.ErrorType.validation.rawValue == "validation")
    }

    @Test("ErrorType timeout has correct raw value")
    func testErrorType_Timeout_RawValue() {
        // Assert
        #expect(ServerImportError.ErrorType.timeout.rawValue == "timeout")
    }

    @Test("ErrorType unsupported has correct raw value")
    func testErrorType_Unsupported_RawValue() {
        // Assert
        #expect(ServerImportError.ErrorType.unsupported.rawValue == "unsupported")
    }

    // MARK: - ImportResponse Tests

    @Test("ImportResponse stores all fields")
    func testImportResponse_StoresAllFields() {
        // Arrange
        let recipe = ExtractedRecipe(
            title: "Test Recipe",
            ingredients: ["Salt"],
            instructions: ["Mix"]
        )
        let metadata = ImportMetadata(
            parserUsed: .schemaOrg,
            parseTimeMs: 200,
            hasSchemaOrg: true,
            needsFeedback: false,
            domain: "example.com",
            sourceUrl: "https://example.com/recipe",
            timestamp: Date()
        )

        // Act
        let response = ImportResponse(
            status: .success,
            importId: "import-123",
            confidence: 0.9,
            recipe: recipe,
            warnings: ["Minor issue detected"],
            errors: nil,
            metadata: metadata
        )

        // Assert
        #expect(response.status == .success)
        #expect(response.importId == "import-123")
        #expect(response.confidence == 0.9)
        #expect(response.recipe?.title == "Test Recipe")
        #expect(response.warnings?.count == 1)
        #expect(response.errors == nil)
        #expect(response.metadata.domain == "example.com")
    }

    // MARK: - ImportMetadata Tests

    @Test("ImportMetadata stores all fields")
    func testImportMetadata_StoresAllFields() {
        // Arrange
        let timestamp = Date()

        // Act
        let metadata = ImportMetadata(
            parserUsed: .heuristic,
            parseTimeMs: 350,
            hasSchemaOrg: false,
            needsFeedback: true,
            domain: "test.com",
            sourceUrl: "https://test.com/recipe/123",
            timestamp: timestamp
        )

        // Assert
        #expect(metadata.parserUsed == .heuristic)
        #expect(metadata.parseTimeMs == 350)
        #expect(metadata.hasSchemaOrg == false)
        #expect(metadata.needsFeedback == true)
        #expect(metadata.domain == "test.com")
        #expect(metadata.sourceUrl == "https://test.com/recipe/123")
        #expect(metadata.timestamp == timestamp)
    }

    // MARK: - FeedbackRequest Tests

    @Test("FeedbackRequest stores required fields")
    func testFeedbackRequest_StoresRequiredFields() {
        // Act
        let feedback = FeedbackRequest(
            importId: "import-123",
            userId: "user-456",
            wasAccurate: true,
            corrections: nil,
            rating: nil,
            comment: nil
        )

        // Assert
        #expect(feedback.importId == "import-123")
        #expect(feedback.userId == "user-456")
        #expect(feedback.wasAccurate == true)
        #expect(feedback.corrections == nil)
        #expect(feedback.rating == nil)
        #expect(feedback.comment == nil)
    }

    @Test("FeedbackRequest stores corrections")
    func testFeedbackRequest_StoresCorrections() {
        // Arrange
        let corrections = [
            FeedbackRequest.Correction(field: "servings", correctValue: "4 servings"),
            FeedbackRequest.Correction(field: "prepTime", correctValue: "10 min")
        ]

        // Act
        let feedback = FeedbackRequest(
            importId: "import-123",
            userId: "user-456",
            wasAccurate: false,
            corrections: corrections,
            rating: 3,
            comment: "Mostly accurate"
        )

        // Assert
        #expect(feedback.wasAccurate == false)
        #expect(feedback.corrections?.count == 2)
        #expect(feedback.corrections?[0].field == "servings")
        #expect(feedback.corrections?[0].correctValue == "4 servings")
        #expect(feedback.rating == 3)
        #expect(feedback.comment == "Mostly accurate")
    }

    @Test("FeedbackRequest Correction stores field and value")
    func testFeedbackRequestCorrection_StoresFieldAndValue() {
        // Act
        let correction = FeedbackRequest.Correction(
            field: "cookTime",
            correctValue: "45 minutes"
        )

        // Assert
        #expect(correction.field == "cookTime")
        #expect(correction.correctValue == "45 minutes")
    }

    // MARK: - FeedbackResponse Tests

    @Test("FeedbackResponse stores success status")
    func testFeedbackResponse_StoresSuccess() {
        // Act
        let response = FeedbackResponse(
            success: true,
            message: "Feedback received"
        )

        // Assert
        #expect(response.success == true)
        #expect(response.message == "Feedback received")
    }

    @Test("FeedbackResponse stores failure status")
    func testFeedbackResponse_StoresFailure() {
        // Act
        let response = FeedbackResponse(
            success: false,
            message: "Invalid import ID"
        )

        // Assert
        #expect(response.success == false)
        #expect(response.message == "Invalid import ID")
    }

    // MARK: - ImportResponse Extension Tests

    @Test("ImportResponse toImportedRecipe converts successfully")
    func testImportResponse_ToImportedRecipe_Converts() {
        // Arrange
        let recipe = ExtractedRecipe(
            title: "Test Recipe",
            ingredients: ["Salt", "Pepper"],
            instructions: ["Mix", "Cook"],
            servings: "4",
            prepTime: "10 min",
            cookTime: "20 min",
            totalTime: nil,
            imageUrl: "https://example.com/image.jpg",
            rating: nil,
            ratingCount: nil,
            description: "A test recipe",
            author: "Chef Test"
        )
        let metadata = ImportMetadata(
            parserUsed: .schemaOrg,
            parseTimeMs: 200,
            hasSchemaOrg: true,
            needsFeedback: false,
            domain: "example.com",
            sourceUrl: "https://example.com/recipe",
            timestamp: Date()
        )
        let response = ImportResponse(
            status: .success,
            importId: "import-123",
            confidence: 0.9,
            recipe: recipe,
            warnings: nil,
            errors: nil,
            metadata: metadata
        )

        // Act
        let imported = response.toImportedRecipe()

        // Assert
        #expect(imported != nil)
        #expect(imported?.title == "Test Recipe")
        #expect(imported?.description == "A test recipe")
        #expect(imported?.imageURL == "https://example.com/image.jpg")
        #expect(imported?.sourceURL == "https://example.com/recipe")
        #expect(imported?.author == "Chef Test")
        #expect(imported?.servings == "4")
        #expect(imported?.prepTime == "10 min")
        #expect(imported?.cookTime == "20 min")
        #expect(imported?.ingredients.count == 2)
        #expect(imported?.instructions.count == 2)
    }

    @Test("ImportResponse toImportedRecipe returns nil when no recipe")
    func testImportResponse_ToImportedRecipe_ReturnsNilWhenNoRecipe() {
        // Arrange
        let metadata = ImportMetadata(
            parserUsed: .none,
            parseTimeMs: 100,
            hasSchemaOrg: false,
            needsFeedback: true,
            domain: "example.com",
            sourceUrl: "https://example.com/recipe",
            timestamp: Date()
        )
        let response = ImportResponse(
            status: .failed,
            importId: "import-123",
            confidence: 0.0,
            recipe: nil,
            warnings: nil,
            errors: [ServerImportError(type: .parsing, message: "Failed", field: nil)],
            metadata: metadata
        )

        // Act
        let imported = response.toImportedRecipe()

        // Assert
        #expect(imported == nil)
    }

    // MARK: - Codable Tests

    @Test("ImportAttempt encodes and decodes")
    func testImportAttempt_Codable() throws {
        // Arrange
        let timestamp = Date()
        let original = ImportAttempt(
            id: "test-123",
            url: "https://example.com/recipe",
            domain: "example.com",
            timestamp: timestamp,
            userId: "user-456",
            status: .success,
            extracted: ExtractedRecipe(
                title: "Test",
                ingredients: ["Salt"],
                instructions: ["Mix"]
            ),
            parserUsed: .schemaOrg,
            confidence: 0.9,
            errors: nil,
            parseTimeMs: 200
        )
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        // Act
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(ImportAttempt.self, from: data)

        // Assert
        #expect(decoded.id == original.id)
        #expect(decoded.url == original.url)
        #expect(decoded.domain == original.domain)
        #expect(decoded.status == original.status)
        #expect(decoded.parserUsed == original.parserUsed)
        #expect(decoded.confidence == original.confidence)
    }

    @Test("ExtractedRecipe encodes and decodes")
    func testExtractedRecipe_Codable() throws {
        // Arrange
        let original = ExtractedRecipe(
            title: "Test Recipe",
            ingredients: ["Flour", "Sugar"],
            instructions: ["Mix", "Bake"],
            servings: "6",
            prepTime: "15 min",
            cookTime: "30 min",
            totalTime: "45 min",
            imageUrl: "https://example.com/image.jpg",
            rating: 4.5,
            ratingCount: 100,
            description: "A test",
            author: "Chef",
            category: "Desserts",
            cuisine: "American",
            keywords: ["cake", "sweet"]
        )
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        // Act
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(ExtractedRecipe.self, from: data)

        // Assert
        #expect(decoded.title == original.title)
        #expect(decoded.ingredients.count == 2)
        #expect(decoded.instructions.count == 2)
        #expect(decoded.servings == "6")
        #expect(decoded.author == "Chef")
        #expect(decoded.keywords?.count == 2)
    }

    @Test("ServerImportError encodes and decodes")
    func testServerImportError_Codable() throws {
        // Arrange
        let original = ServerImportError(
            type: .parsing,
            message: "Parse failed",
            field: "ingredients"
        )
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        // Act
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(ServerImportError.self, from: data)

        // Assert
        #expect(decoded.type == original.type)
        #expect(decoded.message == original.message)
        #expect(decoded.field == original.field)
    }

    // MARK: - Edge Case Tests

    @Test("ImportAttempt handles zero confidence")
    func testImportAttempt_HandlesZeroConfidence() {
        // Act
        let attempt = ImportAttempt(
            id: "test",
            url: "https://example.com",
            domain: "example.com",
            timestamp: Date(),
            userId: nil,
            status: .failed,
            extracted: nil,
            parserUsed: .none,
            confidence: 0.0,
            errors: [],
            parseTimeMs: 50
        )

        // Assert
        #expect(attempt.confidence == 0.0)
    }

    @Test("ImportAttempt handles perfect confidence")
    func testImportAttempt_HandlesPerfectConfidence() {
        // Act
        let attempt = ImportAttempt(
            id: "test",
            url: "https://example.com",
            domain: "example.com",
            timestamp: Date(),
            userId: "user",
            status: .success,
            extracted: ExtractedRecipe(
                title: "Test",
                ingredients: [],
                instructions: []
            ),
            parserUsed: .schemaOrg,
            confidence: 1.0,
            errors: nil,
            parseTimeMs: 100
        )

        // Assert
        #expect(attempt.confidence == 1.0)
    }

    @Test("ImportAttempt handles multiple errors")
    func testImportAttempt_HandlesMultipleErrors() {
        // Arrange
        let errors = [
            ServerImportError(type: .network, message: "Timeout", field: nil),
            ServerImportError(type: .parsing, message: "Invalid format", field: "ingredients"),
            ServerImportError(type: .validation, message: "Missing title", field: "title")
        ]

        // Act
        let attempt = ImportAttempt(
            id: "test",
            url: "https://example.com",
            domain: "example.com",
            timestamp: Date(),
            userId: "user",
            status: .partial,
            extracted: nil,
            parserUsed: .heuristic,
            confidence: 0.3,
            errors: errors,
            parseTimeMs: 500
        )

        // Assert
        #expect(attempt.errors?.count == 3)
        #expect(attempt.errors?[0].type == .network)
        #expect(attempt.errors?[1].type == .parsing)
        #expect(attempt.errors?[2].type == .validation)
    }

    @Test("ExtractedRecipe handles empty ingredients")
    func testExtractedRecipe_HandlesEmptyIngredients() {
        // Act
        let recipe = ExtractedRecipe(
            title: "Test",
            ingredients: [],
            instructions: ["Step 1"]
        )

        // Assert
        #expect(recipe.ingredients.count == 0)
        #expect(recipe.instructions.count == 1)
    }

    @Test("ExtractedRecipe handles empty instructions")
    func testExtractedRecipe_HandlesEmptyInstructions() {
        // Act
        let recipe = ExtractedRecipe(
            title: "Test",
            ingredients: ["Salt"],
            instructions: []
        )

        // Assert
        #expect(recipe.ingredients.count == 1)
        #expect(recipe.instructions.count == 0)
    }

    @Test("FeedbackRequest handles negative rating")
    func testFeedbackRequest_HandlesNegativeRating() {
        // Act
        let feedback = FeedbackRequest(
            importId: "test",
            userId: "user",
            wasAccurate: false,
            corrections: nil,
            rating: -1,
            comment: "Very inaccurate"
        )

        // Assert
        #expect(feedback.rating == -1)
    }
}
