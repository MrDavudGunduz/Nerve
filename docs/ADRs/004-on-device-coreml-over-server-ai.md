# ADR-004: On-Device CoreML over Server-Side AI

| Field               | Value            |
| ------------------- | ---------------- |
| **Status**          | Accepted         |
| **Date**            | 2026-03-25       |
| **Decision Makers** | Davud Gündüz     |
| **Scope**           | `AILayer` module |

## Context

Nerve performs two AI tasks on news headlines:

1. **Clickbait detection** — binary classification (clickbait vs. genuine).
2. **Sentiment analysis** — 3-class classification (positive / neutral / negative).

We needed to decide where inference runs:

- **Server-side**: API endpoint processes headlines, returns scores.
- **On-device**: CoreML models run locally on the device's Neural Processing Unit (NPU).

## Decision

We chose **on-device inference via CoreML**, with all models bundled in the `AILayer` SPM package.

## Rationale

### Privacy

| Approach         | User Data Leaves Device     | GDPR/Privacy Compliance                      |
| ---------------- | --------------------------- | -------------------------------------------- |
| On-device CoreML | ❌ Never                    | Inherently compliant                         |
| Server-side API  | ✅ Headlines sent to server | Requires consent, data processing agreements |

For a news app, headline analysis reveals user interests and reading patterns — sensitive behavioral data. On-device processing eliminates this concern entirely.

### Performance & Cost

| Factor              | On-Device                 | Server-Side                     |
| ------------------- | ------------------------- | ------------------------------- |
| **Latency**         | < 50ms (NPU)              | 200–500ms (network + inference) |
| **Offline support** | ✅ Works without internet | ❌ Requires connectivity        |
| **Server cost**     | $0                        | Scales with user count          |
| **Bandwidth**       | Zero overhead             | Payload per headline            |

### Apple Silicon NPU Utilization

Modern Apple devices (A14+ / M1+) have dedicated **Neural Engines** optimized for ML inference. CoreML automatically dispatches to the NPU when available:

- iPhone 15 Pro Neural Engine: **35 TOPS** (trillion operations per second)
- Runs concurrently with CPU/GPU without impacting UI performance
- No battery drain from network radio usage

### Disadvantages Considered

- **Model size in bundle**: Adds to the app download size.
- **Model updates**: Requires app update to ship improved models (vs. server-side hot-swap).
- **Training complexity**: Must train, convert, and validate models locally via Create ML.
- **Accuracy ceiling**: Lightweight on-device models may underperform large server models (e.g., GPT-class).

### Mitigations

- **Bundle size**: Target < 5 MB combined for both models (text classifiers are inherently small).
- **Model updates**: Use CoreML Model Deployment for over-the-air updates without app releases.
- **Accuracy**: For headline-level binary/ternary classification, lightweight models achieve > 90% accuracy. We don't need GPT-class language understanding.
- **Fallback**: If model accuracy proves insufficient, `NewsAnalyzerProtocol` abstraction allows swapping to a server-side implementation without changing consumers.

## Consequences

- `AILayer` has zero networking dependencies — it operates entirely offline.
- `.mlmodelc` files are bundled as SPM resources using `Bundle.module`.
- Background analysis runs in a `TaskGroup` with concurrency limits to avoid NPU saturation.
- Analysis results are persisted in SwiftData alongside `NewsItem`, not computed on-the-fly.
- Model retraining requires a developer with Create ML / PyTorch + CoreML Tools knowledge.

## References

- [CoreML Documentation — Apple](https://developer.apple.com/documentation/coreml)
- [Create ML — Apple](https://developer.apple.com/documentation/createml)
- [Deploying Model Updates — Apple](https://developer.apple.com/documentation/coreml/downloading_and_compiling_a_model_on_the_user_s_device)
- [NaturalLanguage Framework — Apple](https://developer.apple.com/documentation/naturallanguage)
