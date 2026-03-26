# ADR-001: SwiftData over Core Data

| Field               | Value                 |
| ------------------- | --------------------- |
| **Status**          | Accepted              |
| **Date**            | 2026-03-25            |
| **Decision Makers** | Davud Gündüz          |
| **Scope**           | `StorageLayer` module |

## Context

Nerve requires a local persistence layer to support offline-first functionality. The two primary options within the Apple ecosystem are **Core Data** (mature, UIKit-era framework) and **SwiftData** (modern, Swift-native framework introduced at WWDC 2023).

The app targets iOS 17+, macOS 14+, and visionOS 1+ — all of which have first-class SwiftData support.

## Decision

We chose **SwiftData** as the persistence framework for the `StorageLayer` module.

## Rationale

### Advantages of SwiftData

| Factor                    | SwiftData                                           | Core Data                                               |
| ------------------------- | --------------------------------------------------- | ------------------------------------------------------- |
| **Swift-native API**      | `@Model` macro, `#Predicate`                        | `NSManagedObject` subclassing, `NSPredicate` strings    |
| **SwiftUI integration**   | `@Query` property wrapper, automatic view updates   | Requires `@FetchRequest` + `NSFetchedResultsController` |
| **Concurrency safety**    | Works with Swift `actor` isolation and `ModelActor` | Thread confinement rules, `perform` blocks              |
| **Boilerplate**           | Minimal — no `.xcdatamodeld` file needed            | Requires managed object model editor                    |
| **Observation framework** | Native `@Observable` compatibility                  | Manual `objectWillChange` or Combine publishers         |
| **visionOS support**      | First-class                                         | Supported but no SwiftUI-native query                   |

### Disadvantages Considered

- **Maturity**: SwiftData is newer (WWDC 2023) and may have undiscovered edge cases in production.
- **Migration tooling**: Core Data has battle-tested lightweight and heavyweight migration support; SwiftData's migration APIs are still evolving.
- **Community resources**: Core Data has ~15 years of Stack Overflow answers, blog posts, and books.

### Mitigations

- We target only iOS 17+ / macOS 14+ / visionOS 1+, so SwiftData is fully available.
- Schema migrations are handled via `VersionedSchema` and `SchemaMigrationPlan`.
- We isolate all persistence behind protocols in `Core`, allowing a future swap if needed.

## Consequences

- All `@Model` definitions live in `StorageLayer`.
- UI layers use `@Query` to observe data — never direct API responses.
- The `PersistenceActor` pattern ensures thread-safe writes via Swift `actor`.
- If SwiftData reveals critical bugs, we can swap the implementation behind `StorageServiceProtocol` without touching UI code.

## References

- [SwiftData Documentation — Apple](https://developer.apple.com/documentation/swiftdata)
- [Migrate to SwiftData — WWDC 2023](https://developer.apple.com/videos/play/wwdc2023/10189/)
- [Model your schema with enumerations — WWDC 2024](https://developer.apple.com/videos/play/wwdc2024/10137/)
