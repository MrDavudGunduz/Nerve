//
//  EntityLifecycleManager.swift
//  ARFeature
//
//  Created by Davud Gunduz on 17.05.2026.
//

#if canImport(RealityKit)

  import Core
  import Foundation
  import OSLog
  import RealityKit

  // MARK: - EntityLifecycleManager

  /// Manages the creation, tracking, and teardown of RealityKit entities.
  ///
  /// Prevents VRAM leaks by maintaining a registry of all entities added
  /// to the scene and providing a deterministic `teardownAll()` method
  /// that recursively removes entities and releases their resources.
  ///
  /// ## VRAM Safety
  ///
  /// RealityKit entities hold GPU-side resources (mesh data, textures,
  /// collision shapes). If entities are not explicitly removed from the
  /// scene before the view disappears, those resources remain allocated.
  ///
  /// This manager ensures:
  /// 1. All entities are tracked upon addition.
  /// 2. `teardownAll()` removes all tracked entities from their parents.
  /// 3. References are cleared to allow ARC deallocation.
  ///
  /// ## Thread Safety
  ///
  /// `@MainActor`-isolated because RealityKit entity manipulation must
  /// happen on the main thread.
  ///
  /// ## Usage
  ///
  /// ```swift
  /// let lifecycle = EntityLifecycleManager()
  ///
  /// // In RealityView make:
  /// let entity = try await ModelEntity(contentsOf: url)
  /// lifecycle.track(entity)
  /// content.add(entity)
  ///
  /// // In onDisappear:
  /// lifecycle.teardownAll()
  /// ```
  @MainActor
  public final class EntityLifecycleManager {

    // MARK: - Properties

    /// Tracked entities, keyed by name for diagnostics.
    private var trackedEntities: [String: Entity] = [:]

    private static let logger = Logger(
      subsystem: LogSubsystem.arFeature,
      category: "EntityLifecycleManager"
    )

    // MARK: - Init

    public init() {}

    // MARK: - Tracking

    /// Registers an entity for lifecycle management.
    ///
    /// - Parameter entity: The entity to track. Uses `entity.name` as the key.
    public func track(_ entity: Entity) {
      let key = entity.name.isEmpty ? UUID().uuidString : entity.name
      trackedEntities[key] = entity
      Self.logger.debug("Tracking entity '\(key)'.")
    }

    /// The number of currently tracked entities.
    public var trackedCount: Int {
      trackedEntities.count
    }

    // MARK: - Teardown

    /// Removes all tracked entities from the scene graph and releases references.
    ///
    /// This method:
    /// 1. Removes each entity from its parent.
    /// 2. Recursively removes all child entities.
    /// 3. Clears the internal tracking dictionary.
    ///
    /// Call this in `onDisappear` or when the AR session ends.
    public func teardownAll() {
      Self.logger.info(
        "Tearing down \(self.trackedEntities.count) tracked entities."
      )

      for (key, entity) in trackedEntities {
        recursivelyRemove(entity)
        Self.logger.debug("Removed entity '\(key)' from scene graph.")
      }

      trackedEntities.removeAll()
      Self.logger.info("Entity lifecycle teardown complete.")
    }

    /// Removes a specific entity by name.
    ///
    /// - Parameter name: The name of the entity to remove.
    /// - Returns: `true` if the entity was found and removed.
    @discardableResult
    public func remove(named name: String) -> Bool {
      guard let entity = trackedEntities.removeValue(forKey: name) else {
        return false
      }
      recursivelyRemove(entity)
      Self.logger.debug("Removed tracked entity '\(name)'.")
      return true
    }

    // MARK: - Private

    /// Recursively removes an entity and all its children from the scene.
    private func recursivelyRemove(_ entity: Entity) {
      // Remove children first (depth-first).
      for child in entity.children {
        recursivelyRemove(child)
      }
      entity.removeFromParent()
    }
  }

#endif
