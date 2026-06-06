//
//  MapViewModelFactory.swift
//  MapFeature
//
//  Created by Davud Gunduz on 06.06.2026.
//

import Core
import Foundation
import OSLog

// MARK: - MapViewModelFactory

/// Factory that resolves ``MapViewModel`` dependencies from a
/// ``DependencyContainer`` and constructs a fully-wired instance.
///
/// This factory encapsulates the DI resolution logic that was previously
/// implicit in ``NerveMapView``'s `@State` initialization. By centralizing
/// service resolution here:
///
/// 1. ``NerveMapView`` no longer depends on stub services at init time.
/// 2. DI resolution errors are handled gracefully with fallback services.
/// 3. The same factory can be used from SwiftUI views, UIKit coordinators,
///    or unit tests.
///
/// ## Usage
///
/// ```swift
/// // In a SwiftUI view:
/// @Environment(\.dependencyContainer) var container
///
/// let viewModel = await MapViewModelFactory.make(from: container)
/// ```
///
/// ## Error Handling
///
/// If any service fails to resolve, the factory falls back to the
/// corresponding stub service and logs a warning. This ensures the map
/// view always renders — even if the DI container is misconfigured.
@MainActor
public enum MapViewModelFactory {

  private static let logger = Logger(
    subsystem: LogSubsystem.mapFeature,
    category: "MapViewModelFactory"
  )

  // MARK: - Factory

  /// Creates a ``MapViewModel`` by resolving all dependencies from the
  /// given container.
  ///
  /// Falls back to stub services for any resolution that fails, ensuring
  /// the view model is always constructable. Failures are logged at
  /// warning level for diagnostics.
  ///
  /// - Parameter container: The ``DependencyContainer`` to resolve from.
  /// - Returns: A fully-configured ``MapViewModel``.
  public static func make(from container: DependencyContainer) async -> MapViewModel {
    let newsService = await resolveOrFallback(
      NewsServiceProtocol.self,
      from: container,
      fallback: StubNewsServiceInternal()
    )

    let storageService = await resolveOrFallback(
      StorageServiceProtocol.self,
      from: container,
      fallback: StubStorageServiceInternal()
    )

    let locationService = await resolveOrFallback(
      LocationServiceProtocol.self,
      from: container,
      fallback: StubLocationServiceInternal()
    )

    // Clustering service — resolve from container or use default AnnotationClusterer.
    let clusterer = await resolveOrFallback(
      ClusteringServiceProtocol.self,
      from: container,
      fallback: AnnotationClusterer()
    )

    // AI service is optional — nil if not registered.
    let aiService = try? await container.resolve(AIAnalysisServiceProtocol.self)

    return MapViewModel(
      clusterer: clusterer,
      newsService: newsService,
      storageService: storageService,
      locationService: locationService,
      aiService: aiService
    )
  }

  // MARK: - Private

  /// Attempts to resolve a service from the container, falling back to a
  /// default implementation if resolution fails.
  ///
  /// Logs a warning on failure to help diagnose misconfigured containers
  /// without crashing the app.
  private static func resolveOrFallback<T: Sendable>(
    _ type: T.Type,
    from container: DependencyContainer,
    fallback: T
  ) async -> T {
    do {
      return try await container.resolve(type)
    } catch {
      logger.warning(
        """
        Failed to resolve \(String(describing: type)) from DependencyContainer: \
        \(error.localizedDescription, privacy: .public). \
        Using fallback stub service.
        """
      )
      return fallback
    }
  }
}
