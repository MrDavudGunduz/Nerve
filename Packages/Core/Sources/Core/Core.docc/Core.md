# `Core`

The foundational layer of Nerve — shared models, service protocols, and dependency injection.

## Overview

`Core` is the **platform-agnostic foundation** that every other module in Nerve depends on. It contains no UI code (zero SwiftUI or UIKit imports) and defines the contracts that all feature modules program against.

### Design Philosophy

- **Protocol-Driven**: Every service is defined as a protocol here and implemented in its respective module.
- **Dependency Injection**: A lightweight DI container wires concrete implementations at app startup.
- **Sendable by Default**: All value types conform to `Sendable` for safe use across concurrency boundaries.

## Topics

### Domain Models

- `NewsItem`
- `NewsCategory`
- `HeadlineAnalysis`
- `Sentiment`
- `Coordinate`

### Service Protocols

- `NewsServiceProtocol`
- `LocationServiceProtocol`
- `StorageServiceProtocol`
- `NewsAnalyzerProtocol`
- `ARAssetServiceProtocol`

### Dependency Injection

- `DependencyContainer`
- `ServiceKey`

### Errors

- `NerveError`
- `NetworkError`
- `StorageError`
- `AILayerError`
