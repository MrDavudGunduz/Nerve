//
//  URLSessionNewsServiceTests.swift
//  NetworkLayer
//
//  Created by Davud Gunduz on 02.05.2026.
//

import Core
import Foundation
import Testing

@testable import NetworkLayer

// MARK: - URLSessionNewsService Tests

@Suite("URLSessionNewsService Tests")
struct URLSessionNewsServiceTests {

  // MARK: - Configuration

  @Test("Default configuration uses production base URL")
  func defaultConfiguration() {
    let config = NetworkConfiguration.production
    #expect(config.baseURL.absoluteString == "https://api.nerve.app/v1")
    #expect(config.maxRetryAttempts == 3)
    #expect(config.timeoutInterval == 30)
  }

  @Test("Staging configuration uses staging base URL")
  func stagingConfiguration() {
    let config = NetworkConfiguration.staging
    #expect(config.baseURL.absoluteString == "https://staging-api.nerve.app/v1")
    #expect(config.maxRetryAttempts == 2)
  }

  @Test("Development configuration uses localhost")
  func developmentConfiguration() {
    let config = NetworkConfiguration.development
    #expect(config.baseURL.absoluteString == "http://localhost:8080/v1")
    #expect(config.maxRetryAttempts == 1)
  }

  @Test("Custom configuration preserves all parameters")
  func customConfiguration() {
    let config = NetworkConfiguration(
      baseURL: URL(string: "https://custom.api.com/v2")!,
      timeoutInterval: 15,
      maxRetryAttempts: 5,
      retryBaseDelay: 2.0,
      apiKey: "test-key-123",
      additionalHeaders: ["X-Custom": "value"],
      maxConcurrentImageDownloads: 8,
      imageCacheSizeMB: 200
    )

    #expect(config.baseURL.absoluteString == "https://custom.api.com/v2")
    #expect(config.timeoutInterval == 15)
    #expect(config.maxRetryAttempts == 5)
    #expect(config.retryBaseDelay == 2.0)
    #expect(config.apiKey == "test-key-123")
    #expect(config.additionalHeaders["X-Custom"] == "value")
    #expect(config.maxConcurrentImageDownloads == 8)
    #expect(config.imageCacheSizeMB == 200)
  }

  @Test("URLSession factory creates a configured session")
  func urlSessionFactory() {
    let config = NetworkConfiguration.production
    let session = config.makeURLSession()

    #expect(session.configuration.timeoutIntervalForRequest == 30)
    #expect(session.configuration.waitsForConnectivity)
  }

  // MARK: - Service Initialization

  @Test("URLSessionNewsService conforms to NewsServiceProtocol")
  func conformsToProtocol() {
    let service = URLSessionNewsService(configuration: .development)
    // Type check — if this compiles, the conformance is valid.
    let _: any NewsServiceProtocol = service
    _ = service  // Suppress unused variable warning.
  }

  @Test("URLSessionNewsService is Sendable")
  func isSendable() {
    let service = URLSessionNewsService(configuration: .development)
    // Verify Sendable by capturing in a Task.
    Task {
      _ = service
    }
  }
}

// MARK: - URLSessionImageService Tests

@Suite("URLSessionImageService Tests")
struct URLSessionImageServiceTests {

  @Test("URLSessionImageService conforms to ImageServiceProtocol")
  func conformsToProtocol() async {
    let service = URLSessionImageService(cacheSizeMB: 10)
    // Type check — if this compiles, the conformance is valid.
    let _: any ImageServiceProtocol = service
  }

  @Test("Cache clear does not crash on empty cache")
  func clearEmptyCache() async {
    let service = URLSessionImageService(cacheSizeMB: 10)
    await service.clearCache()
    // No crash = success.
  }
}

// MARK: - NewsItemDTO Tests

@Suite("NewsItemDTO Domain Conversion Tests")
struct NewsItemDTOTests {

  @Test("DTO with valid data converts to domain model")
  func validDTOConversion() {
    let dto = NewsItemDTO(
      id: "test-1",
      headline: "Test Headline",
      summary: "Test summary text",
      source: "Test Source",
      articleUrl: "https://example.com/article",
      category: "technology",
      latitude: 41.0,
      longitude: 29.0,
      publishedAt: Date(),
      imageUrl: "https://example.com/image.jpg"
    )

    let item = dto.toDomainModel()
    #expect(item.id == "test-1")
    #expect(item.headline == "Test Headline")
    #expect(item.summary == "Test summary text")
    #expect(item.source == "Test Source")
    #expect(item.articleURL?.absoluteString == "https://example.com/article")
    #expect(item.category == .technology)
    #expect(item.coordinate.latitude == 41.0)
    #expect(item.coordinate.longitude == 29.0)
    #expect(item.imageURL?.absoluteString == "https://example.com/image.jpg")
    #expect(item.analysis == nil)
  }

  @Test("DTO with unknown category falls back to .other")
  func unknownCategoryFallback() {
    let dto = NewsItemDTO(
      id: "test-2",
      headline: "Test",
      summary: "Summary",
      source: "Source",
      articleUrl: nil,
      category: "unknown_category",
      latitude: 0.0,
      longitude: 0.0,
      publishedAt: Date(),
      imageUrl: nil
    )

    let item = dto.toDomainModel()
    #expect(item.category == .other)
  }

  @Test("DTO with invalid coordinate falls back to (0, 0)")
  func invalidCoordinateFallback() {
    let dto = NewsItemDTO(
      id: "test-3",
      headline: "Test",
      summary: "Summary",
      source: "Source",
      articleUrl: nil,
      category: "science",
      latitude: 999.0,  // Invalid
      longitude: -999.0,  // Invalid
      publishedAt: Date(),
      imageUrl: nil
    )

    let item = dto.toDomainModel()
    #expect(item.coordinate.latitude == 0.0)
    #expect(item.coordinate.longitude == 0.0)
  }

  @Test("DTO with nil optional URLs converts cleanly")
  func nilOptionalURLs() {
    let dto = NewsItemDTO(
      id: "test-4",
      headline: "Test",
      summary: "Summary",
      source: "Source",
      articleUrl: nil,
      category: "health",
      latitude: 40.0,
      longitude: 28.0,
      publishedAt: Date(),
      imageUrl: nil
    )

    let item = dto.toDomainModel()
    #expect(item.articleURL == nil)
    #expect(item.imageURL == nil)
  }
}

// MARK: - RetryPolicy Tests

/// Actor-based counter for thread-safe mutation in test closures.
private actor CallCounter {
  var count = 0
  func increment() -> Int {
    count += 1
    return count
  }
}

@Suite("RetryPolicy Tests")
struct RetryPolicyTests {

  @Test("Successful operation returns immediately without retry")
  func successNoRetry() async throws {
    let counter = CallCounter()
    let result = try await RetryPolicy.execute(maxAttempts: 3) {
      await counter.increment()
      return 42
    }
    #expect(result == 42)
    let count = await counter.count
    #expect(count == 1)
  }

  @Test("Operation retries on transient failure and succeeds")
  func retryThenSucceed() async throws {
    let counter = CallCounter()
    let result = try await RetryPolicy.execute(
      maxAttempts: 3,
      baseDelay: 0.01  // Minimal delay for test speed.
    ) {
      let current = await counter.increment()
      if current < 3 {
        throw URLError(.timedOut)
      }
      return "success"
    }
    #expect(result == "success")
    let count = await counter.count
    #expect(count == 3)
  }

  @Test("All attempts exhausted throws last error")
  func allAttemptsExhausted() async {
    let counter = CallCounter()
    do {
      _ = try await RetryPolicy.execute(
        maxAttempts: 2,
        baseDelay: 0.01
      ) { () -> Int in
        await counter.increment()
        throw URLError(.notConnectedToInternet)
      }
      #expect(Bool(false), "Should have thrown")
    } catch {
      let count = await counter.count
      #expect(count == 2)
      #expect(error is URLError)
    }
  }

  @Test("Non-retryable error skips remaining attempts")
  func nonRetryableSkips() async {
    let counter = CallCounter()
    do {
      _ = try await RetryPolicy.execute(
        maxAttempts: 3,
        baseDelay: 0.01,
        shouldRetry: { _ in false }
      ) { () -> Int in
        await counter.increment()
        throw URLError(.badURL)
      }
      #expect(Bool(false), "Should have thrown")
    } catch {
      let count = await counter.count
      #expect(count == 1)  // No retries.
    }
  }

  @Test("Delay computation is correct")
  func delayComputation() {
    // base=1.0, multiplier=2.0
    #expect(RetryPolicy.delay(forAttempt: 0) == 1.0)
    #expect(RetryPolicy.delay(forAttempt: 1) == 2.0)
    #expect(RetryPolicy.delay(forAttempt: 2) == 4.0)
    #expect(RetryPolicy.delay(forAttempt: 3) == 8.0)
  }

  @Test("Delay is capped at maxDelay")
  func delayCapped() {
    let delay = RetryPolicy.delay(forAttempt: 100, maxDelay: 30.0)
    #expect(delay == 30.0)
  }
}

// MARK: - Placeholder Compatibility

@Suite("Placeholder Service Backward Compatibility")
struct PlaceholderCompatibilityTests {

  @Test("PlaceholderNewsService still conforms and returns empty")
  func placeholderNewsService() async throws {
    let service: any NewsServiceProtocol = PlaceholderNewsService()
    let region = GeoRegion(
      center: GeoCoordinate(latitude: 41, longitude: 29)!,
      radiusMeters: 50_000
    )!
    let items = try await service.fetchNews(for: region)
    #expect(items.isEmpty)
  }

  @Test("PlaceholderImageService still conforms and returns empty data")
  func placeholderImageService() async throws {
    let service: any ImageServiceProtocol = PlaceholderImageService()
    let data = try await service.loadImage(from: URL(string: "https://example.com/img.png")!)
    #expect(data.isEmpty)
  }
}
