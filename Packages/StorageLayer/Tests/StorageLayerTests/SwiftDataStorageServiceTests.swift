//
//  SwiftDataStorageServiceTests.swift
//  StorageLayerTests
//
//  Created by Davud Gunduz on 11.04.2026.
//

import Core
import Foundation
import SwiftData
import Testing

@testable import StorageLayer

// MARK: - Test Helpers

/// Creates an in-memory `ModelContainer` for isolated unit testing.
/// Each test gets a fresh container — no on-disk state between runs.
private func makeTestContainer() throws -> ModelContainer {
  let schema = Schema(ModelRegistry.allModels)
  let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
  return try ModelContainer(for: schema, configurations: [config])
}

private func makeService() throws -> SwiftDataStorageService {
  let container = try makeTestContainer()
  let actor = PersistenceActor(modelContainer: container)
  return SwiftDataStorageService(persistenceActor: actor)
}

private func makeDomainItem(
  id: String = "test-\(UUID().uuidString)",
  headline: String = "Test Headline",
  category: NewsCategory = .technology,
  lat: Double = 41.0082,
  lon: Double = 28.9784
) -> NewsItem {
  NewsItem(
    id: id,
    headline: headline,
    summary: "Test summary.",
    source: "TestSource",
    category: category,
    coordinate: GeoCoordinate(latitude: lat, longitude: lon)!,
    publishedAt: Date()
  )
}

// MARK: - Save & Fetch Tests

@Suite("SwiftDataStorageService — Save & Fetch")
struct SwiftDataStorageSaveTests {

  @Test("saveNews inserts new items")
  func insertItems() async throws {
    let service = try makeService()
    let items = [makeDomainItem(id: "a"), makeDomainItem(id: "b")]
    try await service.saveNews(items)

    let fetched = try await service.fetchNews(in: nil, limit: nil, offset: nil)
    #expect(fetched.count == 2)
  }

  @Test("saveNews with empty array is a no-op")
  func emptyInsert() async throws {
    let service = try makeService()
    try await service.saveNews([])
    let fetched = try await service.fetchNews(in: nil, limit: nil, offset: nil)
    #expect(fetched.isEmpty)
  }

  @Test("saveNews upserts existing items by ID")
  func upsert() async throws {
    let service = try makeService()
    let original = makeDomainItem(id: "upsert-1", headline: "Original")
    try await service.saveNews([original])

    let updated = makeDomainItem(id: "upsert-1", headline: "Updated")
    try await service.saveNews([updated])

    let fetched = try await service.fetchNews(in: nil, limit: nil, offset: nil)
    #expect(fetched.count == 1)
    #expect(fetched.first?.headline == "Updated")
  }

  @Test("fetchNews with limit returns at most N items")
  func fetchWithLimit() async throws {
    let service = try makeService()
    let items = (0..<10).map { makeDomainItem(id: "item-\($0)") }
    try await service.saveNews(items)

    let fetched = try await service.fetchNews(in: nil, limit: 5, offset: nil)
    #expect(fetched.count == 5)
  }

  @Test("fetchNews with offset paginates correctly")
  func fetchWithOffset() async throws {
    let service = try makeService()
    // Insert 6 items with sequential dates so sort order is deterministic.
    let base = Date(timeIntervalSinceReferenceDate: 1_000_000)
    let items = (0..<6).map { i -> NewsItem in
      NewsItem(
        id: "page-\(i)",
        headline: "Item \(i)",
        summary: "",
        source: "S",
        category: .technology,
        coordinate: GeoCoordinate(latitude: 41, longitude: 29)!,
        publishedAt: base.addingTimeInterval(TimeInterval(i))
      )
    }
    try await service.saveNews(items)

    let page1 = try await service.fetchNews(in: nil, limit: 3, offset: 0)
    let page2 = try await service.fetchNews(in: nil, limit: 3, offset: 3)
    #expect(page1.count == 3)
    #expect(page2.count == 3)
    // Pages must not overlap.
    let ids1 = Set(page1.map(\.id))
    let ids2 = Set(page2.map(\.id))
    #expect(ids1.isDisjoint(with: ids2))
  }

  @Test("fetchNews with region filters by bounding box")
  func fetchWithRegion() async throws {
    let service = try makeService()

    let istanbul = makeDomainItem(id: "ist", lat: 41.0082, lon: 28.9784)
    let tokyo = makeDomainItem(id: "tok", lat: 35.6762, lon: 139.6503)
    try await service.saveNews([istanbul, tokyo])

    let istanbulCenter = GeoCoordinate(latitude: 41.0, longitude: 29.0)!
    let region = GeoRegion(center: istanbulCenter, radiusMeters: 50_000)!

    let fetched = try await service.fetchNews(in: region, limit: nil, offset: nil)
    #expect(fetched.count == 1)
    #expect(fetched.first?.id == "ist")
  }
}

// MARK: - Delete Tests

@Suite("SwiftDataStorageService — Delete")
struct SwiftDataStorageDeleteTests {

  @Test("deleteNews removes the item by ID")
  func deleteByID() async throws {
    let service = try makeService()
    let item = makeDomainItem(id: "del-1")
    try await service.saveNews([item])
    try await service.deleteNews(id: "del-1")

    let fetched = try await service.fetchNews(in: nil, limit: nil, offset: nil)
    #expect(fetched.isEmpty)
  }

  @Test("deleteNews with unknown ID is a no-op")
  func deleteUnknown() async throws {
    let service = try makeService()
    let item = makeDomainItem(id: "keep-me")
    try await service.saveNews([item])

    // Should not throw.
    try await service.deleteNews(id: "does-not-exist")

    let fetched = try await service.fetchNews(in: nil, limit: nil, offset: nil)
    #expect(fetched.count == 1)
  }
}

// MARK: - Prune Tests

@Suite("SwiftDataStorageService — Prune")
struct SwiftDataStoragePruneTests {

  @Test("pruneExpiredCache removes items older than 24h")
  func pruneExpired() async throws {
    let container = try makeTestContainer()
    let actor = PersistenceActor(modelContainer: container)
    let service = SwiftDataStorageService(persistenceActor: actor)

    // Insert one fresh item and one 2-day-old item
    // by directly setting cachedAt on the persistence model.
    // We use save(items) for the fresh one; the expired one
    // is created via PersistenceActor.save then mutated via a test-only
    // extension. Since `NewsItemPersistenceModel.cachedAt` is mutable,
    // we rely on the fact that SwiftData lets us override it in memory.

    let fresh = makeDomainItem(id: "fresh")
    let stale = makeDomainItem(id: "stale")
    try await service.saveNews([fresh, stale])

    // Manually override cachedAt to 2 days ago via a private context.
    let stallContext = ModelContext(container)
    stallContext.autosaveEnabled = false
    let descriptor = FetchDescriptor<NewsItemPersistenceModel>(
      predicate: #Predicate { $0.id == "stale" }
    )
    if let record = try stallContext.fetch(descriptor).first {
      record.cachedAt = Date(timeIntervalSinceNow: -172_800)  // -48h
      try stallContext.save()
    }

    try await service.pruneExpiredCache()

    let remaining = try await service.fetchNews(in: nil, limit: nil, offset: nil)
    #expect(remaining.count == 1)
    #expect(remaining.first?.id == "fresh")
  }

  @Test("pruneExpiredCache is a no-op when nothing is expired")
  func pruneNoExpiry() async throws {
    let service = try makeService()
    let items = [makeDomainItem(id: "a"), makeDomainItem(id: "b")]
    try await service.saveNews(items)

    try await service.pruneExpiredCache()

    let remaining = try await service.fetchNews(in: nil, limit: nil, offset: nil)
    #expect(remaining.count == 2)
  }
}
