//
//  StorageLayer.swift
//  StorageLayer
//
//  Created by Davud Gunduz on 25.03.2026.
//

import Core

/// Actor-isolated SwiftData persistence layer powering Nerve's
/// offline-first experience.
///
/// All database writes are serialized through `PersistenceActor`,
/// ensuring zero data races.
public enum StorageLayer {

  /// The current version of the StorageLayer module.
  public static let version = "0.1.0"
}
