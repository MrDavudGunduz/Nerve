//
//  NerveSchemaMigrationPlanTests.swift
//  StorageLayerTests
//
//  Tests for the schema migration plan to ensure safe data evolution.
//

import Foundation
import SwiftData
import Testing

@testable import StorageLayer

@Suite("NerveSchemaMigrationPlan Tests")
struct NerveSchemaMigrationPlanTests {

  @Test("V1 schema contains NewsItemPersistenceModel")
  func v1SchemaContainsExpectedModels() {
    let models = NerveSchemaV1.models
    #expect(models.count == 1)
    #expect(models.first == NewsItemPersistenceModel.self)
  }

  @Test("V1 schema version is 1.0.0")
  func v1SchemaVersion() {
    let version = NerveSchemaV1.versionIdentifier
    #expect(version == Schema.Version(1, 0, 0))
  }

  @Test("Migration plan schemas list contains V1")
  func migrationPlanSchemas() {
    let schemas = NerveSchemaMigrationPlan.schemas
    #expect(schemas.count == 1)
    #expect(schemas.first == NerveSchemaV1.self)
  }

  @Test("Migration plan stages are empty for V1-only")
  func migrationPlanStagesEmpty() {
    let stages = NerveSchemaMigrationPlan.stages
    #expect(stages.isEmpty)
  }

  @Test("ModelRegistry.allModels matches NerveSchemaV1.models")
  func modelRegistryMatchesSchema() {
    let registryModels = ModelRegistry.allModels
    let schemaModels = NerveSchemaV1.models

    #expect(registryModels.count == schemaModels.count)

    // Verify each model in the registry is also in the schema.
    for model in registryModels {
      let found = schemaModels.contains(where: { $0 == model })
      #expect(found, "Model \(model) is in ModelRegistry but not in NerveSchemaV1")
    }
  }

  @Test("ModelContainer can be created with migration plan in-memory")
  func modelContainerWithMigrationPlan() throws {
    let schema = Schema(ModelRegistry.allModels)
    let config = ModelConfiguration(
      schema: schema,
      isStoredInMemoryOnly: true
    )
    let container = try ModelContainer(
      for: schema,
      migrationPlan: NerveSchemaMigrationPlan.self,
      configurations: [config]
    )
    #expect(container.schema.entities.count >= 1)
  }
}
