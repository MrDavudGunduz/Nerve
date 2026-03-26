# `NetworkLayer`

Type-safe API client for fetching geographically-tagged news data.

## Overview

`NetworkLayer` provides a protocol-oriented networking stack built entirely on `URLSession` and Swift Concurrency. It handles API communication, response decoding, error mapping, and request interception (authentication, logging, retry logic).

### Key Principles

- **Zero third-party dependencies** — built on Foundation's `URLSession`.
- **Protocol-based** — implements `NewsServiceProtocol` defined in `Core`.
- **Fully testable** — supports `MockURLProtocol` injection for deterministic unit tests.
- **Offline-aware** — never writes directly to UI; all data flows through `StorageLayer`.

## Topics

### API Client

- `NewsAPIClient`
- `APIEndpoint`
- `HTTPMethod`

### Data Transfer Objects

- `NewsDTO`
- `NewsCategoryDTO`
- `APIResponse`
- `PaginatedResponse`

### Request Pipeline

- `RequestInterceptor`
- `AuthInterceptor`
- `LoggingInterceptor`
- `RetryInterceptor`

### Error Handling

- `NetworkError`
- `APIErrorResponse`

### Configuration

- `NetworkConfiguration`
- `APIEnvironment`
