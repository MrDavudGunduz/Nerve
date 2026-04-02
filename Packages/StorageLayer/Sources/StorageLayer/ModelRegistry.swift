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
  public static let allModels: [any PersistentModel.Type] = [
    NewsItemPersistenceModel.self
    // ↓ Register new @Model types below this line
  ]
}
