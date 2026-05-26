//
//  ModelRegistry.swift
//  StorageLayer
//
//  Created by Davud Gunduz on 27.03.2026.
//

import SwiftData

/// A centralized registry of all SwiftData `@Model` types used across Nerve.
///
/// This is the **single source of truth** for the SwiftData schema.
/// `NerveApp` passes ``allModels`` to `Schema(ModelRegistry.allModels)` so
/// the `ModelContainer` is always consistent with every `@Model` in the project.
///
/// ## Schema Versioning
///
/// When the schema evolves, update **both** this registry and the
/// ``NerveSchemaMigrationPlan``:
///
/// 1. Create a new `VersionedSchema` enum (e.g., `NerveSchemaV2`).
/// 2. Add a `MigrationStage` to ``NerveSchemaMigrationPlan/stages``.
/// 3. Update ``allModels`` below to include the latest model types.
///
/// ## Adding New Models
///
/// When you create a new `@Model`, register it here:
///
/// ```swift
/// public static let allModels: [any PersistentModel.Type] = [
///   NewsItemPersistenceModel.self,
///   // Add new models here ↓
///   AnalysisResultPersistenceModel.self,
/// ]
/// ```
///
/// - Warning: Forgetting to register a model will **not** produce a compile error,
///   but will cause a runtime crash on first SwiftData access. The
///   `StorageLayerTests` suite includes a regression test for this.
public enum ModelRegistry {

  /// All persistent `@Model` types included in the SwiftData schema.
  ///
  /// - Important: Every `@Model` defined in `StorageLayer` **must** be listed here.
  ///   This array must stay in sync with the latest ``NerveSchemaV1/models``
  ///   (or the most recent `VersionedSchema`).
  public static let allModels: [any PersistentModel.Type] = [
    NewsItemPersistenceModel.self
    // ↓ Register new @Model types below this line
  ]
}
