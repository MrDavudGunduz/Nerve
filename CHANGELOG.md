# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Added

- **Dependency Injection Container** (`Core/DI/`)
  - Actor-based `DependencyContainer` with singleton, transient, and scoped lifetimes.
  - Circular dependency detection for transient services via `resolvingKeys`.
  - Named registrations for multiple implementations of the same protocol.
  - Scope invalidation (`invalidateScope`) for session-based lifecycles.
  - `ServiceKey` with `ObjectIdentifier`-based O(1) hash lookup.
  - `DependencyError` enum with descriptive `CustomStringConvertible` messages.

- **Domain Models** (`Core/Models/`)
  - `NewsItem` — canonical news article model with `Codable`, `Hashable`, `Identifiable`.
  - `GeoCoordinate` — failable initializer with lat/lon range validation + validated `Codable` conformance.
  - `GeoRegion` — circular region with non-negative radius validation.
  - `HeadlineAnalysis` — AI analysis result with value clamping (0.0–1.0) and `CredibilityLabel`.
  - `NerveError` — unified error enum with modular categories, `ErrorContext` for diagnostics, and context-ignoring `Equatable`.
  - `NewsCategory` and `Sentiment` enums.

- **Service Protocols** (`Core/Protocols/`)
  - `NewsServiceProtocol` — news fetching abstraction.
  - `LocationServiceProtocol` — location tracking abstraction.
  - `StorageServiceProtocol` — persistence abstraction with pagination.
  - `AIAnalysisServiceProtocol` — on-device AI inference abstraction.
  - `ImageServiceProtocol` — image loading and caching abstraction.

- **SwiftUI–DI Bridge** (`Nerve/DependencyContainerEnvironment.swift`)
  - `EnvironmentKey` for `DependencyContainer` injection into the view hierarchy.
  - DEBUG-mode warning when container accessed without prior injection.

- **ModelContainer Configuration** (`Nerve/NerveApp.swift`)
  - Graceful fallback from persistent to in-memory storage with `OSLog` error reporting.
  - Schema sourced from `ModelRegistry.allModels` for centralized model management.

- **ModelRegistry** (`StorageLayer/ModelRegistry.swift`)
  - Centralized `@Model` type registry to prevent forgotten schema registrations.

- **Comprehensive Test Suite** (59 tests, 15 suites)
  - `Core`: DI container resolution, lifecycle management, circular dependency detection, concurrent singleton resolution, factory error propagation, domain model validation, Codable round-trips, boundary values, error descriptions.
  - `NetworkLayer`: Protocol conformance stubs (`StubNewsService`, `StubImageService`) + DI round-trip.
  - `StorageLayer`: Protocol conformance stub (`StubStorageService`) + DI round-trip + operation tests.
  - `MapFeature`: Protocol conformance stub (`StubLocationService` actor) + DI round-trip.
  - `ARFeature`: Protocol conformance stubs + DI round-trip + multi-protocol resolution + error handling.
  - `AILayer`: Protocol conformance stub (`StubAIAnalysisService`) + DI round-trip + batch analysis.
  - `NerveTests`: App-level integration tests with Swift Testing migration.

- Project documentation: `README.md`, `DEVELOPMENT_ROADMAP.md`, `CONTRIBUTING.md`, `CHANGELOG.md`.
- Architecture Decision Records (ADRs) for SwiftData, SPM modularity, offline-first, CoreML, Observation framework.
- GitHub Pull Request template.
- MIT License.

### Fixed

- **Actor Reentrancy Bug** in `DependencyContainer` — concurrent singleton `resolve` calls no longer falsely throw `circularDependency` errors. Removed `resolvingKeys` guard for singleton/scoped lifetimes; concurrency handled by double-check caching mechanism.

---

## [0.1.0] — 2026-03-25

### Added

- **Project Initialization**
  - Created multiplatform Xcode project targeting iOS 17+, macOS 14+, visionOS 1+.
  - Bootstrapped `ContentView` with `NavigationStack` and platform-adaptive UI.
  - Set up `NerveTests` and `NerveUITests` targets.
  - Created six local SPM packages with Swift 6.0 strict concurrency.

---

<!-- Links -->

[Unreleased]: https://github.com/MrDavudGunduz/Nerve/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/MrDavudGunduz/Nerve/releases/tag/v0.1.0
