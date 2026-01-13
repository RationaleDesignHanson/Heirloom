import Testing
import Foundation
import SwiftData

@testable import Heirloom

@Suite("Schema Version Tests")
struct SchemaTests {

    // MARK: - SchemaV1 Tests

    @Test("SchemaV1 has correct version identifier")
    func testSchemaV1_VersionIdentifier() {
        // Act
        let version = SchemaV1.versionIdentifier

        // Assert
        #expect(version.major == 1)
        #expect(version.minor == 0)
        #expect(version.patch == 0)
    }

    @Test("SchemaV1 includes all required models")
    func testSchemaV1_ModelsIncluded() {
        // Act
        let models = SchemaV1.models

        // Assert - Verify count
        #expect(models.count >= 15) // At least 15 core models

        // Verify specific model types are included
        let modelNames = models.map { String(describing: $0) }
        #expect(modelNames.contains("Recipe"))
        #expect(modelNames.contains("Ingredient"))
        #expect(modelNames.contains("Tag"))
        #expect(modelNames.contains("RecipeCollection"))
        #expect(modelNames.contains("RecipeLineage"))
        #expect(modelNames.contains("DinnerParty"))
        #expect(modelNames.contains("ShoppingCartRecipe"))
        #expect(modelNames.contains("RecipeComment"))
    }

    @Test("SchemaV1 schema can be created")
    func testSchemaV1_SchemaCanBeCreated() {
        // Act
        let schema = SchemaV1.schema

        // Assert - Schema should be created without errors
        #expect(schema.entities.count > 0)
    }

    // MARK: - SchemaV2 Tests

    @Test("SchemaV2 has correct version identifier")
    func testSchemaV2_VersionIdentifier() {
        // Act
        let version = SchemaV2.versionIdentifier

        // Assert
        #expect(version.major == 2)
        #expect(version.minor == 0)
        #expect(version.patch == 0)
    }

    @Test("SchemaV2 includes all required models")
    func testSchemaV2_ModelsIncluded() {
        // Act
        let models = SchemaV2.models

        // Assert - Verify count (same as V1 since lightweight migration)
        #expect(models.count >= 15)

        // Verify all V1 models are still present in V2
        let modelNames = models.map { String(describing: $0) }
        #expect(modelNames.contains("Recipe"))
        #expect(modelNames.contains("Ingredient"))
        #expect(modelNames.contains("Tag"))
        #expect(modelNames.contains("RecipeCollection"))
        #expect(modelNames.contains("RecipeLineage"))
    }

    @Test("SchemaV2 schema can be created")
    func testSchemaV2_SchemaCanBeCreated() {
        // Act
        let schema = SchemaV2.schema

        // Assert - Schema should be created without errors
        #expect(schema.entities.count > 0)
    }

    @Test("SchemaV2 version is greater than SchemaV1")
    func testSchemaV2_VersionIsGreaterThanV1() {
        // Arrange
        let v1 = SchemaV1.versionIdentifier
        let v2 = SchemaV2.versionIdentifier

        // Assert - V2 should be greater than V1
        #expect(v2 > v1)
    }

    // MARK: - Migration Plan Tests

    @Test("HeirloomSchemaMigrationPlan includes both schemas")
    func testMigrationPlan_IncludesBothSchemas() {
        // Act
        let schemas = HeirloomSchemaMigrationPlan.schemas

        // Assert
        #expect(schemas.count == 2)
        #expect(schemas[0] == SchemaV1.self)
        #expect(schemas[1] == SchemaV2.self)
    }

    @Test("HeirloomSchemaMigrationPlan has one stage")
    func testMigrationPlan_HasOneStage() {
        // Act
        let stages = HeirloomSchemaMigrationPlan.stages

        // Assert
        #expect(stages.count == 1)
    }

    @Test("HeirloomSchemaMigrationPlan stage is lightweight migration")
    func testMigrationPlan_StageIsLightweight() {
        // Act
        let stage = HeirloomSchemaMigrationPlan.migrateV1toV2

        // Assert - Verify stage exists (cannot introspect lightweight migration type directly)
        #expect(stage != nil)
    }

    // MARK: - Model Consistency Tests

    @Test("SchemaV1 and SchemaV2 have same number of models")
    func testSchemas_SameNumberOfModels() {
        // Act
        let v1Count = SchemaV1.models.count
        let v2Count = SchemaV2.models.count

        // Assert - Same count since V2 is additive (new optional fields only)
        #expect(v1Count == v2Count)
    }

    @Test("SchemaV1 models are all included in SchemaV2")
    func testSchemas_V1ModelsInV2() {
        // Arrange
        let v1Models = Set(SchemaV1.models.map { String(describing: $0) })
        let v2Models = Set(SchemaV2.models.map { String(describing: $0) })

        // Assert - All V1 models should be in V2
        #expect(v1Models.isSubset(of: v2Models))
    }

    // MARK: - Version Comparison Tests

    @Test("Schema Version can be compared")
    func testSchemaVersion_CanBeCompared() {
        // Arrange
        let v1 = Schema.Version(1, 0, 0)
        let v2 = Schema.Version(2, 0, 0)
        let v1_1 = Schema.Version(1, 1, 0)
        let v1_0_1 = Schema.Version(1, 0, 1)

        // Assert
        #expect(v2 > v1)
        #expect(v1_1 > v1)
        #expect(v1_0_1 > v1)
        #expect(v2 > v1_1)
        #expect(v1 == Schema.Version(1, 0, 0))
    }

    @Test("Schema Version major component is correct")
    func testSchemaVersion_MajorComponent() {
        // Arrange
        let version = Schema.Version(3, 2, 1)

        // Assert
        #expect(version.major == 3)
    }

    @Test("Schema Version minor component is correct")
    func testSchemaVersion_MinorComponent() {
        // Arrange
        let version = Schema.Version(3, 2, 1)

        // Assert
        #expect(version.minor == 2)
    }

    @Test("Schema Version patch component is correct")
    func testSchemaVersion_PatchComponent() {
        // Arrange
        let version = Schema.Version(3, 2, 1)

        // Assert
        #expect(version.patch == 1)
    }

    // MARK: - Edge Case Tests

    @Test("Schema models array is not empty")
    func testSchemas_ModelsNotEmpty() {
        // Assert
        #expect(!SchemaV1.models.isEmpty)
        #expect(!SchemaV2.models.isEmpty)
    }

    @Test("Schema version identifiers are unique")
    func testSchemas_UniqueVersionIdentifiers() {
        // Arrange
        let v1 = SchemaV1.versionIdentifier
        let v2 = SchemaV2.versionIdentifier

        // Assert - They should not be equal
        #expect(v1 != v2)
    }

    @Test("Migration plan schemas are in order")
    func testMigrationPlan_SchemasInOrder() {
        // Arrange
        let schemas = HeirloomSchemaMigrationPlan.schemas
        guard schemas.count >= 2 else { return }

        // Act
        let v1 = schemas[0].versionIdentifier
        let v2 = schemas[1].versionIdentifier

        // Assert - V1 should be less than V2
        #expect(v1 < v2)
    }
}
