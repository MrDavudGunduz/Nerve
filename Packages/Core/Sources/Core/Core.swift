//
//  Core.swift
//  Core
//
//  Created by Davud Gunduz on 25.03.2026.
//

/// The foundational layer of Nerve — shared models, service protocols,
/// and dependency injection.
///
/// `Core` is the **platform-agnostic foundation** that every other module
/// in Nerve depends on. It contains no UI code and defines the contracts
/// that all feature modules program against.
///
/// ## Key Components
///
/// - ``DependencyContainer`` — Actor-based DI container
/// - ``NewsServiceProtocol`` — News fetching abstraction
/// - ``LocationServiceProtocol`` — Location tracking abstraction
/// - ``StorageServiceProtocol`` — Persistence abstraction
/// - ``AIAnalysisServiceProtocol`` — AI inference abstraction
/// - ``ImageServiceProtocol`` — Image loading abstraction
///
/// ## Domain Models
///
/// - ``NewsItem`` — Canonical news article model
/// - ``GeoCoordinate`` / ``GeoRegion`` — Geographic types
/// - ``HeadlineAnalysis`` — AI analysis result
/// - ``NerveError`` — Unified error type
///
/// ## Dependency Injection
///
/// The app's single ``DependencyContainer`` is created in `NerveApp`
/// and injected into the SwiftUI view hierarchy via
/// `@Environment(\.dependencyContainer)`. For non-UI contexts
/// (e.g., background tasks), pass the container explicitly.
public enum Core {

  /// The current version of the Core module.
  public static let version = "0.1.0"
}
