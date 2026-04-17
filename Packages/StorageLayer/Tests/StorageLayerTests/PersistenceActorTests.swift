//
//  PersistenceActorTests.swift
//  StorageLayerTests
//
//  Direct unit tests for PersistenceActor's async methods, validating
//  the upsert, fetch, delete, and prune operations at the actor level
//  independent of the SwiftDataStorageService facade.
//

import Core
import Foundation
import SwiftData
import Testing

@testable import StorageLayer

// MARK: - Helpers

private func makeTestContainer() throws -> ModelContainer {
  let schema = Schema(ModelRegistry.allModels)
  let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
  return try ModelContainer(for: schema, configurations: [config])
}

private func makeItem(
  id: String = "pa-\(UUID().uuidString)",
  headline: String = "Test",
  lat: Double = 41.0082,
  lon: Double = 28.9784
) -> NewsItem {
  NewsItem(
    id: id,
    headline: headline,
    summary: "Summary",
    source: "Src",
    category: .technology,
    coordinate: GeoCoordinate(latitude: lat, longitude: lon)!,
    publishedAt: Date()
  )
}

// MARK: - Save Tests

@Suite("PersistenceActor — Save")
struct PersistenceActorSaveTests {

  @Test("save inserts and persists items")
  func insertItems() async throws {
    let actor = PersistenceActor(modelContainer: try makeTestContainer())
    let items = [makeItem(id: "s1"), makeItem(id: "s2")]
    try await actor.save(items)

    let fetched = try await actor.fetch(in: nil, limit: nil, offset: nil)
    #expect(fetched.count == 2)
  }

  @Test("save with empty array is a no-op")
  func emptyArray() async throws {
    let actor = PersistenceActor(modelContainer: try makeTestContainer())
    try await actor.save([])
    let fetched = try await actor.fetch(in: nil, limit: nil, offset: nil)
    #expect(fetched.isEmpty)
  }

  @Test("save upserts existing items by ID")
  func upsertById() async throws {
    let actor = PersistenceActor(modelContainer: try makeTestContainer())
    try await actor.save([makeItem(id: "u1", headline: "Original")])
    try await actor.save([makeItem(id: "u1", headline: "Updated")])

    let fetched = try await actor.fetch(in: nil, limit: nil, offset: nil)
    #expect(fetched.count == 1)
    #expect(fetched.first?.headline == "Updated")
  }
}

// MARK: - Fetch Tests

@Suite("PersistenceActor — Fetch")
struct PersistenceActorFetchTests {

  @Test("fetch with limit returns at most N items")
  func fetchLimit() async throws {
    let actor = PersistenceActor(modelContainer: try makeTestContainer())
    let items = (0..<8).map { makeItem(id: "fl-\($0)") }
    try await actor.save(items)

    let fetched = try await actor.fetch(in: nil, limit: 3, offset: nil)
    #expect(fetched.count == 3)
  }

  @Test("fetch with offset skips items")
  func fetchOffset() async throws {
    let actor = PersistenceActor(modelContainer: try makeTestContainer())
    let base = Date(timeIntervalSinceReferenceDate: 1_000_000)
    let items = (0..<5).map { i -> NewsItem in
      NewsItem(
        id: "fo-\(i)",
        headline: "Item \(i)",
        summary: "",
        source: "S",
        category: .science,
        coordinate: GeoCoordinate(latitude: 41, longitude: 29)!,
        publishedAt: base.addingTimeInterval(TimeInterval(i))
      )
    }
    try await actor.save(items)

    let page1 = try await actor.fetch(in: nil, limit: 2, offset: 0)
    let page2 = try await actor.fetch(in: nil, limit: 2, offset: 2)
    #expect(page1.count == 2)
    #expect(page2.count == 2)
    let ids1 = Set(page1.map(\.id))
    let ids2 = Set(page2.map(\.id))
    #expect(ids1.isDisjoint(with: ids2))
  }

  @Test("fetch with region filters by bounding box")
  func fetchRegion() async throws {
    let actor = PersistenceActor(modelContainer: try makeTestContainer())
    let istanbul = makeItem(id: "ist", lat: 41.0082, lon: 28.9784)
    let tokyo = makeItem(id: "tok", lat: 35.6762, lon: 139.6503)
    try await actor.save([istanbul, tokyo])

    let center = GeoCoordinate(latitude: 41.0, longitude: 29.0)!
    let region = GeoRegion(center: center, radiusMeters: 50_000)!
    let fetched = try await actor.fetch(in: region, limit: nil, offset: nil)
    #expect(fetched.count == 1)
    #expect(fetched.first?.id == "ist")
  }
}

// MARK: - Delete Tests

@Suite("PersistenceActor — Delete")
struct PersistenceActorDeleteTests {

  @Test("delete removes the item by ID")
  func deleteById() async throws {
    let actor = PersistenceActor(modelContainer: try makeTestContainer())
    try await actor.save([makeItem(id: "del-1")])
    try await actor.delete(id: "del-1")

    let fetched = try await actor.fetch(in: nil, limit: nil, offset: nil)
    #expect(fetched.isEmpty)
  }

  @Test("delete with unknown ID does not throw")
  func deleteUnknown() async throws {
    let actor = PersistenceActor(modelContainer: try makeTestContainer())
    try await actor.save([makeItem(id: "keep")])
    try await actor.delete(id: "nonexistent")

    let fetched = try await actor.fetch(in: nil, limit: nil, offset: nil)
    #expect(fetched.count == 1)
  }
}

// MARK: - Prune Tests

@Suite("PersistenceActor — Prune")
struct PersistenceActorPruneTests {

  @Test("pruneExpired removes 48h-old items")
  func pruneOldItems() async throws {
    let container = try makeTestContainer()
    let actor = PersistenceActor(modelContainer: container)

    try await actor.save([makeItem(id: "fresh"), makeItem(id: "stale")])

    // Manually override cachedAt to 48h ago via a separate context.
    let ctx = ModelContext(container)
    ctx.autosaveEnabled = false
    let desc = FetchDescriptor<NewsItemPersistenceModel>(
      predicate: #Predicate { $0.id == "stale" }
    )
    if let record = try ctx.fetch(desc).first {
      record.cachedAt = Date(timeIntervalSinceNow: -172_800)
      try ctx.save()
    }

    try await actor.pruneExpired()

    let remaining = try await actor.fetch(in: nil, limit: nil, offset: nil)
    #expect(remaining.count == 1)
    #expect(remaining.first?.id == "fresh")
  }

  @Test("pruneExpired is a no-op when nothing is expired")
  func pruneNothing() async throws {
    let actor = PersistenceActor(modelContainer: try makeTestContainer())
    try await actor.save([makeItem(id: "a"), makeItem(id: "b")])
    try await actor.pruneExpired()

    let remaining = try await actor.fetch(in: nil, limit: nil, offset: nil)
    #expect(remaining.count == 2)
  }
}
