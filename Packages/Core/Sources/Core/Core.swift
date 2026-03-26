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
public enum Core {

  /// The current version of the Core module.
  public static let version = "0.1.0"
}
