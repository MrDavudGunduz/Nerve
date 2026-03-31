# Contributing to Nerve

> **Last Updated:** March 31, 2026  
> **Project Overview:** See [README.md](README.md)

---

Thank you for your interest in contributing to Nerve. This document defines the standards, conventions, and workflows that keep the codebase clean, consistent, and production-ready.

---

## Getting Started

### Prerequisites

| Requirement                | Minimum |
| -------------------------- | ------- |
| Xcode                      | 16.0+   |
| Swift                      | 6.0     |
| iOS Deployment Target      | 17.0    |
| macOS Deployment Target    | 14.0    |
| visionOS Deployment Target | 1.0     |

### Setup

1. **Fork** the repository.
2. **Clone** your fork:
   ```bash
   git clone https://github.com/<your-username>/Nerve.git
   cd Nerve
   ```
3. **Open** in Xcode:
   ```bash
   open Nerve.xcodeproj
   ```
4. **Resolve packages:** File → Packages → Resolve Package Versions.
5. **Create** a feature branch from `main` (see [Branch Naming](#branch-naming)).

---

## Branch Naming

All branches follow the pattern `<type>/<short-description>`:

| Type        | Purpose                                 | Example                          |
| ----------- | --------------------------------------- | -------------------------------- |
| `feature/`  | New functionality                       | `feature/map-clustering`         |
| `bugfix/`   | Bug fixes                               | `bugfix/memory-leak-ar-session`  |
| `refactor/` | Code restructuring (no behavior change) | `refactor/di-container-simplify` |
| `docs/`     | Documentation only                      | `docs/adr-swiftdata-decision`    |
| `test/`     | Adding or updating tests                | `test/network-layer-unit-tests`  |
| `chore/`    | Build, CI, tooling changes              | `chore/swiftlint-config-update`  |

> **Rules:** Lowercase with hyphens. Keep descriptions to 2–4 words. Never commit directly to `main`.

---

## Commit Convention

We follow [Conventional Commits](https://www.conventionalcommits.org/) v1.0.0.

### Format

```
<type>(<scope>): <description>

[optional body]

[optional footer(s)]
```

### Types

| Type       | Description                                             |
| ---------- | ------------------------------------------------------- |
| `feat`     | A new feature                                           |
| `fix`      | A bug fix                                               |
| `refactor` | Code change that neither fixes a bug nor adds a feature |
| `docs`     | Documentation only                                      |
| `test`     | Adding or correcting tests                              |
| `chore`    | Build process, CI, or auxiliary tool changes            |
| `perf`     | Performance improvement                                 |
| `style`    | Code style (formatting, whitespace) — no logic change   |

### Scope

Use the SPM module name when the change is scoped to a single package:

```
feat(MapFeature): add quad-tree annotation clustering
fix(NetworkLayer): handle timeout error with retry logic
test(AILayer): add clickbait scoring unit tests
docs(Core): add DocC documentation for DI container
```

### Full Example

```
feat(StorageLayer): implement PersistenceActor with upsert strategy

- Add actor-isolated SwiftData writes
- Implement TTL-based cache invalidation
- Define @Model schemas for NewsItem and CachedRegion

Closes #42
```

---

## Pull Request Workflow

### Before Opening a PR

1. Rebase on the latest `main`:
   ```bash
   git fetch origin
   git rebase origin/main
   ```
2. Run all tests locally:

   ```bash
   # SPM package tests
   for pkg in Core NetworkLayer StorageLayer MapFeature ARFeature AILayer; do
     swift test --package-path Packages/$pkg
   done

   # App target tests
   xcodebuild test -scheme Nerve -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
   ```

3. Run SwiftLint:
   ```bash
   swiftlint lint --strict
   ```

### Opening the PR

- Fill out the [PR template](.github/PULL_REQUEST_TEMPLATE.md) completely.
- Request review from at least **one** team member.
- Use **Squash Merge** into `main` with a clean conventional commit message.

### PR Checklist

- [ ] Branch follows naming convention.
- [ ] All tests pass.
- [ ] SwiftLint passes with zero violations.
- [ ] New `public` APIs have `///` documentation.
- [ ] `CHANGELOG.md` updated (if user-facing change).
- [ ] No unrelated changes included.

---

## Code Standards

### Swift Style

- Follow [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/).
- **SwiftLint** enforced — see `.swiftlint.yml` for the shared configuration.
- Maximum line length: **120 characters**.
- Use `// MARK: -` to organize code sections within files.

### Architecture Rules

| Rule                                                                                     | Rationale                                     |
| ---------------------------------------------------------------------------------------- | --------------------------------------------- |
| `Core`, `NetworkLayer`, `StorageLayer`, `AILayer` must **never** import SwiftUI or UIKit | Keeps business logic platform-agnostic        |
| All services accessed via **protocols** defined in `Core`                                | Enables mock injection for testing            |
| Concurrency must use **Swift Concurrency** (`async/await`, `Actor`)                      | No GCD or OperationQueue; prevents data races |
| UI observes **only SwiftData** — never raw API responses                                 | Maintains single source of truth              |

> For the rationale behind these rules, see the [Architecture Decision Records](docs/ADRs/).

### Access Control

| Visibility | Usage                                             |
| ---------- | ------------------------------------------------- |
| `internal` | Default for all symbols                           |
| `public`   | Only for APIs consumed by other SPM modules       |
| `private`  | All implementation details                        |
| `open`     | Avoid unless explicitly designing for subclassing |

### Concurrency

- Enable strict concurrency checking: `SWIFT_STRICT_CONCURRENCY = complete`.
- All shared mutable state must live inside a Swift `actor`.
- Value types crossing isolation domains must conform to `Sendable`.

---

## Testing Requirements

### Coverage Targets

| Module         | Framework               | Minimum Coverage |
| -------------- | ----------------------- | ---------------- |
| `Core`         | Swift Testing (`@Test`) | 90%              |
| `NetworkLayer` | Swift Testing (`@Test`) | 85%              |
| `StorageLayer` | Swift Testing (`@Test`) | 85%              |
| `AILayer`      | Swift Testing (`@Test`) | 80%              |
| `MapFeature`   | Swift Testing (`@Test`) | 70%              |
| `ARFeature`    | Swift Testing (`@Test`) | 60%              |

### Rules

- **No network calls** in unit tests — use `MockURLProtocol` or protocol-based mocks.
- Tests must be **deterministic** — no reliance on timing, external state, or execution order.
- Name tests descriptively:
  ```swift
  @Test("Fetches and decodes news items from valid JSON response")
  func fetchNews_withValidResponse_returnsDecodedItems() async throws { ... }
  ```

---

## Documentation

### DocC

All `public` symbols in SPM packages must have `///` documentation comments following Apple's DocC conventions:

```swift
/// Analyzes a news headline for clickbait indicators and sentiment.
///
/// Runs inference on-device using CoreML, with no network calls required.
/// Results are cached alongside the `NewsItem` in SwiftData.
///
/// - Parameter headline: The raw headline text to analyze.
/// - Returns: A ``HeadlineAnalysis`` containing clickbait score, sentiment, and confidence.
/// - Throws: ``AILayerError/modelNotLoaded`` if the CoreML model failed to initialize.
public func analyzeHeadline(_ headline: String) async throws -> HeadlineAnalysis
```

Each SPM package has a DocC catalog in `Sources/<Module>/<Module>.docc/` — keep it updated when adding new public APIs.

### Architecture Decision Records (ADRs)

Significant architectural decisions are documented in [`docs/ADRs/`](docs/ADRs/) using a consistent format: Context → Decision → Rationale → Consequences. When making a major technical choice, create a new ADR following the established template.

---

## Code of Conduct

Be respectful, constructive, and professional. We follow the [Contributor Covenant](https://www.contributor-covenant.org/version/2/1/code_of_conduct/) v2.1.

---

## Questions?

Should anything be unclear regarding the project setup or architecture, don't hesitate to contact the maintainer directly at [EMAIL_ADDRESS](mailto:mr.davud.gunduz@gmail.com).
