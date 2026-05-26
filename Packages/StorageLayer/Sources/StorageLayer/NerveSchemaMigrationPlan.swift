//
//  NerveSchemaMigrationPlan.swift
//  StorageLayer
//
//  Created by Davud Gunduz on 18.05.2026.
//

import Foundation
import SwiftData

// MARK: - Schema Versions

/// V1 schema — the initial SwiftData schema shipped with Nerve 1.0.
///
/// Contains ``NewsItemPersistenceModel`` with all fields from the initial release.
///
/// ## Adding a New Version
///
/// 1. Duplicate this enum as `NerveSchemaV2` with the updated `@Model` definitions.
/// 2. Add a `MigrationStage` to ``NerveSchemaMigrationPlan/stages``.
/// 3. Update ``ModelRegistry/allModels`` to use the latest schema's model types.
/// 4. Bump the version comment in `StorageLayer.swift`.
///
/// ## Important
///
/// Never modify an existing `VersionedSchema` after it has shipped.
/// Create a new version instead — this preserves data integrity for
/// users upgrading from any previous release.
public enum NerveSchemaV1: VersionedSchema {

  public static var versionIdentifier: Schema.Version {
    Schema.Version(1, 0, 0)
  }

  public static var models: [any PersistentModel.Type] {
    [NewsItemPersistenceModel.self]
  }
}

// MARK: - Migration Plan

/// Defines the ordered sequence of schema migrations for Nerve's SwiftData store.
///
/// SwiftData uses this plan to automatically migrate the persistent store
/// when the app launches with a newer schema version than the one on disk.
///
/// ## Migration Types
///
/// - **Lightweight:** SwiftData handles the migration automatically (e.g.,
///   adding a new optional property, renaming with `#RenamedProperty`).
/// - **Custom:** A closure runs arbitrary logic during migration (e.g.,
///   computing a default value for a new required field from existing data).
///
/// ## Usage
///
/// ```swift
/// let container = try ModelContainer(
///   for: Schema(ModelRegistry.allModels),
///   migrationPlan: NerveSchemaMigrationPlan.self,
///   configurations: [config]
/// )
/// ```
///
/// ## Future Migrations
///
/// When adding V2:
/// ```swift
/// public enum NerveSchemaV2: VersionedSchema {
///   public static var versionIdentifier: Schema.Version {
///     Schema.Version(2, 0, 0)
///   }
///   public static var models: [any PersistentModel.Type] {
///     [NewsItemPersistenceModelV2.self]
///   }
/// }
/// ```
///
/// Then add to stages:
/// ```swift
/// .lightweight(fromVersion: NerveSchemaV1.self, toVersion: NerveSchemaV2.self)
/// ```
public enum NerveSchemaMigrationPlan: SchemaMigrationPlan {

  /// The ordered list of all schema versions, from oldest to newest.
  ///
  /// SwiftData walks this list to determine which migrations to apply
  /// when upgrading from an older on-disk schema.
  public static var schemas: [any VersionedSchema.Type] {
    [NerveSchemaV1.self]
  }

  /// The ordered sequence of migration stages.
  ///
  /// Currently empty — only V1 exists. When V2 is introduced,
  /// add a `.lightweight(fromVersion:toVersion:)` or
  /// `.custom(fromVersion:toVersion:willMigrate:didMigrate:)` stage.
  public static var stages: [MigrationStage] {
    // No migrations yet — V1 is the only version.
    // When adding V2, insert the migration stage here:
    // .lightweight(fromVersion: NerveSchemaV1.self, toVersion: NerveSchemaV2.self)
    []
  }
}
