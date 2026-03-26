# ADR-005: Observation Framework over Combine

| Field               | Value                                         |
| ------------------- | --------------------------------------------- |
| **Status**          | Accepted                                      |
| **Date**            | 2026-03-25                                    |
| **Decision Makers** | Davud Gündüz                                  |
| **Scope**           | All UI-facing ViewModels and state management |

## Context

SwiftUI views need to observe changes in state objects and re-render accordingly. Two Apple-provided options exist:

    1. **Combine + `ObservableObject`**: The `@Published` / `@StateObject` / `@ObservedObject` pattern, available since iOS 13.
    2. **Observation Framework + `@Observable`**: The macro-based observation system introduced at WWDC 2023, available from iOS 17+.

## Decision

We chose the **Observation Framework** (`@Observable` macro) as the primary state observation mechanism across all modules.

## Rationale

### Granular View Updates

This is the **decisive technical advantage**:

```swift
// Combine — ObservableObject
class MapViewModel: ObservableObject {
    @Published var annotations: [Annotation] = []
    @Published var selectedAnnotation: Annotation?
    @Published var syncStatus: SyncStatus = .idle
}
// Any @Published change re-evaluates ALL views observing this object.
```

```swift
// Observation — @Observable
@Observable
class MapViewModel {
    var annotations: [Annotation] = []
    var selectedAnnotation: Annotation?
    var syncStatus: SyncStatus = .idle
}
// Only views reading the SPECIFIC changed property re-evaluate.
```

With Combine, changing `syncStatus` causes views that only read `annotations` to re-render — a significant performance concern for a map with 1,000+ annotations. Observation eliminates this entirely.

### Comparison

| Factor                      | Observation (`@Observable`)         | Combine (`ObservableObject`)                            |
| --------------------------- | ----------------------------------- | ------------------------------------------------------- |
| **View update granularity** | Per-property                        | Per-object (all `@Published`)                           |
| **Boilerplate**             | Zero — macro generates everything   | `@Published` on every property                          |
| **Property wrappers**       | Just `@State`                       | `@StateObject`, `@ObservedObject`, `@EnvironmentObject` |
| **SwiftUI integration**     | Native — no special wrappers needed | Requires explicit `@ObservedObject`                     |
| **Thread safety**           | Works with `@MainActor`             | `@Published` emits on arbitrary threads                 |
| **Non-UI observation**      | `withObservationTracking`           | `sink`, `assign`, cancellable management                |
| **Minimum deployment**      | iOS 17+                             | iOS 13+                                                 |

### Disadvantages Considered

- **iOS 17+ requirement**: Excludes iOS 16 and earlier devices.
- **Newness**: Smaller body of community knowledge, fewer blog posts and tutorials.
- **Debugging**: Observation tracking is implicit; harder to audit which properties trigger re-renders compared to explicit `@Published`.

### Mitigations

- Nerve already targets **iOS 17+** — no backward-compatibility constraint.
- Apple has clearly signaled Observation as the future; investing in Combine patterns would be building on deprecated infrastructure.
- SwiftUI's `_printChanges()` and Instruments Time Profiler remain effective debugging tools for observation.

## Consequences

- **No Combine imports** in ViewModel or state management code. Combine is only used if a third-party API requires it (with immediate bridging to `async/await`).
- ViewModels are simple `@Observable` classes annotated with `@MainActor`.
- Views reference ViewModels via `@State` (owned) or `@Environment` (injected) — never `@StateObject`/`@ObservedObject`.
- Map view performance scales with annotation count because only the changed property triggers a view update.

## References

- [Observation Framework — Apple](https://developer.apple.com/documentation/observation)
- [Discover Observation in SwiftUI — WWDC 2023](https://developer.apple.com/videos/play/wwdc2023/10149/)
- [Migrating from ObservableObject — Apple](https://developer.apple.com/documentation/swiftui/migrating-from-the-observable-object-protocol-to-the-observable-macro)
