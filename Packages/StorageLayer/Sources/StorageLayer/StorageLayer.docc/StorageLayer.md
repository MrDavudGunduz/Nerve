# `StorageLayer`

Actor-isolated SwiftData persistence layer powering Nerve's offline-first experience.

## Overview

`StorageLayer` is the **single source of truth** for all data in Nerve. It manages SwiftData schemas, provides thread-safe persistence through Swift `actor` isolation, and implements the sync engine that bridges network data into local storage.

### Architecture

All database writes are serialized through `PersistenceActor`, ensuring zero data races. The UI layer observes data exclusively via SwiftData `@Query` — never through raw API responses.

```
NetworkLayer → PersistenceActor → SwiftData → @Query → SwiftUI Views
```

> Important: Never create a `ModelContext` outside of `PersistenceActor`. All mutations must flow through the actor to maintain thread safety.

## Topics

### Schemas

- `NewsItemModel`
- `NewsCategoryModel`
- `CachedRegionModel`
- `AnalysisResultModel`

### Persistence

- `PersistenceActor`
- `StorageService`

### Sync Engine

- `SyncEngine`
- `SyncStatus`
- `UpsertStrategy`

### Schema Versioning

- `NerveSchemaV1`
- `NerveMigrationPlan`

### Configuration

- `StorageConfiguration`
- `CachePolicy`
