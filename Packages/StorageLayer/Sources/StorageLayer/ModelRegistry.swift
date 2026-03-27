//
//  ModelRegistry.swift
//  StorageLayer
//
//  Created by Davud Gunduz on 27.03.2026.
//

import SwiftData

/// A centralized registry of all SwiftData `@Model` types used across Nerve.
///
/// Adding a new `@Model` to the project requires a single update here,
/// preventing silent data loss from forgotten schema registrations.
///
/// ## Usage
///
/// ```swift
/// let schema = Schema(ModelRegistry.allModels)
/// let container = try ModelContainer(for: schema, ...)
/// ```
///
/// ## Adding New Models
///
/// When you create a new `@Model`, add it to ``allModels``:
///
/// ```swift
/// public static let allModels: [any PersistentModel.Type] = [
///   NewsItemModel.self,
///   AnalysisResultModel.self,
///   // Add new models here ↓
///   MyNewModel.self,
/// ]
/// ```
public enum ModelRegistry {

  /// All persistent model types that must be included in the SwiftData schema.
  ///
  /// - Important: Every `@Model` in the project **must** be listed here.
  ///   Forgetting to add a model will cause a runtime crash on first access
  ///   rather than silent data loss.
  public static let allModels: [any PersistentModel.Type] = [
    // Add @Model types here as they are implemented, e.g.:
    // NewsItemModel.self,
    // AnalysisResultModel.self,
  ]
}
