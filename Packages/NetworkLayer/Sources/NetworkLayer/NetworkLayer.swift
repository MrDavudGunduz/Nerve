//
//  NetworkLayer.swift
//  NetworkLayer
//
//  Created by Davud Gunduz on 25.03.2026.
//

import Core

/// Type-safe API client for fetching geographically-tagged news data.
///
/// Built entirely on `URLSession` and Swift Concurrency with zero
/// third-party dependencies.
///
/// ## Key Components
///
/// - ``URLSessionNewsService`` — Production REST client with retry
/// - ``URLSessionImageService`` — Two-tier (memory + disk) image cache
/// - ``NetworkConfiguration`` — Centralized endpoint and timeout config
/// - ``PlaceholderNewsService`` — Debug fallback (empty responses)
/// - ``PlaceholderImageService`` — Debug fallback (empty data)
public enum NetworkLayer {

  /// The current version of the NetworkLayer module.
  public static let version = "1.0.0"
}

