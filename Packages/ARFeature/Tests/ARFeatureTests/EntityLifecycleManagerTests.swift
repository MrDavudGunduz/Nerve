//
//  EntityLifecycleManagerTests.swift
//  ARFeatureTests
//
//  Created by Davud Gunduz on 17.05.2026.
//

import Foundation
import Testing

@testable import ARFeature

#if canImport(RealityKit)
  import RealityKit

  // MARK: - EntityLifecycleManager Tests

  @Suite("EntityLifecycleManager Tests", .tags(.viewModel))
  @MainActor
  struct EntityLifecycleManagerTests {

    @Test("Initial tracked count is zero")
    func initialCountIsZero() {
      let manager = EntityLifecycleManager()
      #expect(manager.trackedCount == 0)
    }

    @Test("Track increases count")
    func trackIncreasesCount() {
      let manager = EntityLifecycleManager()
      let entity = Entity()
      entity.name = "TestEntity"
      manager.track(entity)
      #expect(manager.trackedCount == 1)
    }

    @Test("Track multiple entities")
    func trackMultipleEntities() {
      let manager = EntityLifecycleManager()
      for i in 0..<5 {
        let entity = Entity()
        entity.name = "Entity-\(i)"
        manager.track(entity)
      }
      #expect(manager.trackedCount == 5)
    }

    @Test("Teardown clears all tracked entities")
    func teardownClearsAll() {
      let manager = EntityLifecycleManager()
      let entity1 = Entity()
      entity1.name = "Entity1"
      let entity2 = Entity()
      entity2.name = "Entity2"
      manager.track(entity1)
      manager.track(entity2)

      #expect(manager.trackedCount == 2)
      manager.teardownAll()
      #expect(manager.trackedCount == 0)
    }

    @Test("Remove named entity decreases count")
    func removeNamedEntity() {
      let manager = EntityLifecycleManager()
      let entity = Entity()
      entity.name = "RemovableEntity"
      manager.track(entity)
      #expect(manager.trackedCount == 1)

      let removed = manager.remove(named: "RemovableEntity")
      #expect(removed == true)
      #expect(manager.trackedCount == 0)
    }

    @Test("Remove non-existent entity returns false")
    func removeNonExistentEntity() {
      let manager = EntityLifecycleManager()
      let removed = manager.remove(named: "Ghost")
      #expect(removed == false)
    }

    @Test("Teardown removes entity from parent")
    func teardownRemovesFromParent() {
      let manager = EntityLifecycleManager()
      let parent = Entity()
      let child = Entity()
      child.name = "ChildEntity"
      parent.addChild(child)

      manager.track(child)
      #expect(child.parent === parent)

      manager.teardownAll()
      #expect(child.parent == nil)
    }

    @Test("Track entity without name uses fallback key")
    func trackEntityWithoutName() {
      let manager = EntityLifecycleManager()
      let entity = Entity()
      // Entity name is empty string by default.
      manager.track(entity)
      #expect(manager.trackedCount == 1)
    }
  }
#endif
