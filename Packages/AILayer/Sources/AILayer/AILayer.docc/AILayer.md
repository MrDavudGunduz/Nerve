# `AILayer`

Privacy-first, on-device intelligence for news credibility analysis.

## Overview

`AILayer` provides on-device machine learning capabilities using **CoreML** and the **NaturalLanguage** framework. It performs clickbait detection and sentiment analysis on news headlines entirely on the device's Neural Processing Unit (NPU) — with zero network calls and zero data leaving the device.

### Privacy Guarantee

All inference runs locally. No headline text, user behavior, or analysis results are ever transmitted to external servers. See [ADR-004](../../docs/ADRs/004-on-device-coreml-over-server-ai.md) for the full rationale.

### Performance Target

- **< 50ms** per headline analysis on iPhone 15 Pro (Neural Engine).
- **< 5 MB** combined model size in the app bundle.

## Topics

### Analysis Pipeline

- `NewsAnalyzer`
- `NewsAnalyzerProtocol`
- `AnalysisPipeline`
- `BatchAnalysisEngine`

### Models

- `HeadlineAnalysis`
- `Sentiment`
- `ClickbaitClassifier`
- `SentimentClassifier`

### CoreML Integration

- `ModelLoader`
- `ModelConfiguration`
- `NeuralEngineAvailability`

### Scoring & Credibility

- `CredibilityScorer`
- `CredibilityBadge`
- `ScoreThresholds`

### Errors

- `AILayerError`
