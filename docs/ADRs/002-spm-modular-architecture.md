# ADR-002: SPM Modular Architecture over Monolithic Structure

| Field               | Value                    |
| ------------------- | ------------------------ |
| **Status**          | Accepted                 |
| **Date**            | 2026-03-25               |
| **Decision Makers** | Davud Gündüz             |
| **Scope**           | Entire project structure |

## Context

Nerve is a multiplatform app (iOS, macOS, visionOS) with distinct feature domains: mapping, AR/3D, AI analysis, networking, and storage. We needed to decide between a **monolithic** project structure (all code in one target) and a **modular** architecture using Swift Package Manager.

## Decision

We adopted a **fully modular architecture** using **local SPM packages**, decomposing the app into six independent modules:

| Package        | Responsibility                                   |
| -------------- | ------------------------------------------------ |
| `Core`         | Shared models, protocols, DI container           |
| `NetworkLayer` | API client, DTOs, request interceptors           |
| `StorageLayer` | SwiftData schemas, persistence actors            |
| `MapFeature`   | Map UI, annotation clustering, location services |
| `ARFeature`    | RealityKit scenes, USDZ management, AR sessions  |
| `AILayer`      | CoreML inference, NLP pipelines, scoring         |

## Rationale

### Advantages of SPM Modular Architecture

| Factor                         | Modular (SPM)                                          | Monolithic                                 |
| ------------------------------ | ------------------------------------------------------ | ------------------------------------------ |
| **Build times**                | Incremental — only recompile changed modules           | Full recompilation on any change           |
| **Access control enforcement** | `internal` by default isolates module internals        | Everything accessible, discipline required |
| **Testability**                | Test each module in isolation with mock dependencies   | Tests require full app context             |
| **Platform conditionality**    | Each `Package.swift` declares its own platform support | `#if os(...)` scattered throughout         |
| **Team scalability**           | Developers can own modules independently               | Merge conflicts on shared files            |
| **Dependency clarity**         | Explicit dependency graph in `Package.swift`           | Implicit, hard to reason about             |
| **Reusability**                | Modules can be extracted into standalone packages      | Tightly coupled to app target              |

### Why SPM over CocoaPods / Carthage?

- **Apple-native**: Integrated directly into Xcode, no third-party tooling required.
- **visionOS support**: SPM supports all Apple platforms from day one; CocoaPods visionOS support is community-driven and lagging.
- **No `Podfile.lock` conflicts**: Common pain point in team environments eliminated.
- **Swift-native manifest**: `Package.swift` is type-checked Swift code, not YAML/Ruby.

### Disadvantages Considered

- **Initial setup overhead**: More files and directories compared to a single target.
- **Xcode SPM resolution**: Can be slow on first open or after cache invalidation.
- **Resource bundling**: SPM resource handling is less flexible than app targets (e.g., asset catalogs in packages require `Bundle.module`).

### Mitigations

- We use **local packages** (not remote), so dependency resolution is instant.
- Resources that require complex bundling (App Icon, Launch Screen) stay in the main app target.
- The `Core` module centralizes shared protocols, preventing circular dependencies.

## Consequences

- All new code must be written inside the appropriate SPM package.
- The app target (`NerveApp`) acts as a thin composition root — wiring DI and importing feature modules.
- Module boundaries enforce that business logic (`Core`, `NetworkLayer`, `StorageLayer`, `AILayer`) never imports UI frameworks.
- Adding a new feature domain means creating a new SPM package with its own `Package.swift`.

## References

- [Organizing Your Code with Local Packages — Apple](https://developer.apple.com/documentation/xcode/organizing-your-code-with-local-packages)
- [Swift Package Manager — Swift.org](https://www.swift.org/package-manager/)
- [Modular Architecture in iOS — PointFree](https://www.pointfree.co/collections/composable-architecture)
