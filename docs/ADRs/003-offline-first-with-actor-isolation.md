# ADR-003: Offline-First Architecture with Actor Isolation

| Field               | Value                                    |
| ------------------- | ---------------------------------------- |
| **Status**          | Accepted                                 |
| **Date**            | 2026-03-25                               |
| **Decision Makers** | Davud Gündüz                             |
| **Scope**           | `StorageLayer`, `NetworkLayer`, UI layer |

## Context

Nerve displays geographically-tagged news on an interactive map. Users may be in areas with poor connectivity (underground transit, rural areas, flights). The app must remain **fully functional** without an internet connection, displaying previously fetched data and gracefully handling sync when connectivity returns.

We needed to choose between:

1. **Network-first**: UI fetches from API, falls back to cache on failure.
2. **Offline-first**: UI reads exclusively from local storage; background sync writes to storage independently.

## Decision

We adopted an **Offline-First** architecture where:

- The **UI layer observes only SwiftData** via `@Query` — it never reads raw API responses.
- A **background sync engine** fetches from the API and writes to SwiftData through a `PersistenceActor`.
- All database writes are serialized through a Swift `actor` to prevent data races.

## Rationale

### Why Offline-First?

| Factor                      | Offline-First                  | Network-First                                      |
| --------------------------- | ------------------------------ | -------------------------------------------------- |
| **Cold start speed**        | Instant — data already local   | Blocked on network round-trip                      |
| **Connectivity resilience** | Full functionality offline     | Degraded or broken experience                      |
| **UI consistency**          | Single data source (SwiftData) | Dual sources (API + cache) create state mismatches |
| **Testability**             | Mock the storage layer only    | Must mock both network and cache layers            |
| **User perception**         | App feels fast and reliable    | Loading spinners on every interaction              |

### Why Actor Isolation?

SwiftData's `ModelContext` is **not thread-safe**. Concurrent reads and writes from multiple tasks can cause crashes or data corruption. Swift `actor` provides compile-time enforced serial access:

```swift
actor PersistenceActor {
    private let modelContainer: ModelContainer

    func upsertNews(_ items: [NewsDTO]) async throws {
        let context = ModelContext(modelContainer)
        // All writes happen serially within the actor
    }
}
```

**Benefits over alternatives:**

| Approach                         | Thread Safety | Compile-Time Checks      | Complexity |
| -------------------------------- | ------------- | ------------------------ | ---------- |
| Swift `actor`                    | ✅            | ✅ (Sendable, isolation) | Low        |
| `DispatchQueue.serial`           | ✅            | ❌ (runtime only)        | Medium     |
| `NSManagedObjectContext.perform` | ✅            | ❌ (runtime only)        | High       |

### Disadvantages Considered

- **Data freshness**: Users may see stale data if sync hasn't completed.
- **Storage growth**: Offline data accumulates; requires TTL-based cleanup.
- **Conflict resolution**: If the server has newer data, upsert strategy must handle merges.

### Mitigations

- **TTL metadata**: Each cached item has an expiration timestamp. Stale items are purged during sync.
- **Sync status UI**: A visible indicator (Online / Syncing / Offline) keeps users informed.
- **Upsert strategy**: Items are matched by unique server ID; newer data overwrites local records.
- **Pull-to-refresh**: Users can manually trigger a sync at any time.

## Consequences

- `NetworkLayer` never writes directly to the UI — all data flows through `StorageLayer`.
- The `PersistenceActor` is the single write entry point; no other code creates `ModelContext` instances.
- UI tests can operate entirely against pre-populated SwiftData stores without network mocking.
- Adding new data types requires defining both the DTO (network) and `@Model` (storage) representations.

## References

- [Build an app with SwiftData — WWDC 2023](https://developer.apple.com/videos/play/wwdc2023/10154/)
- [Swift Concurrency: Update a sample app — Apple](https://developer.apple.com/documentation/swift/updating-an-app-to-use-swift-concurrency)
- [Offline-First Design Patterns — Martin Fowler](https://martinfowler.com/articles/patterns-of-distributed-systems/)
