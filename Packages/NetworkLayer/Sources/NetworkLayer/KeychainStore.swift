//
//  KeychainStore.swift
//  NetworkLayer
//
//  Created by Davud Gunduz on 06.06.2026.
//

import Foundation
import Security

// MARK: - KeychainStore

/// A lightweight, type-safe wrapper around the iOS/macOS Keychain for
/// securely storing sensitive strings (e.g., API keys, tokens).
///
/// Uses `kSecClassGenericPassword` with a fixed service identifier
/// scoped to the Nerve application. All operations are synchronous
/// and thread-safe (Keychain APIs are internally serialized by the OS).
///
/// ## Usage
///
/// ```swift
/// // Store an API key securely.
/// try KeychainStore.save("sk-abc123", for: .apiKey)
///
/// // Retrieve the stored key.
/// let key = KeychainStore.load(for: .apiKey)
///
/// // Remove the stored key.
/// KeychainStore.delete(for: .apiKey)
/// ```
///
/// ## Security
///
/// - Data is encrypted at rest by the Secure Enclave.
/// - `kSecAttrAccessible` is set to `.afterFirstUnlockThisDeviceOnly`
///   to balance availability (background tasks) with security
///   (not transferred to new devices via backup).
public enum KeychainStore: Sendable {

  // MARK: - Keys

  /// Named keys for items stored in the Keychain.
  ///
  /// Each key maps to a unique `kSecAttrAccount` value.
  public enum Key: String, Sendable {
    /// The REST API authentication key.
    case apiKey = "com.davudgunduz.Nerve.apiKey"
  }

  // MARK: - Constants

  /// The Keychain service identifier scoping all Nerve entries.
  private static let service = "com.davudgunduz.Nerve"

  // MARK: - Save

  /// Stores a string value securely in the Keychain.
  ///
  /// If an entry already exists for the given key, it is updated in-place
  /// via `SecItemUpdate`. This avoids the `-25299 (errSecDuplicateItem)`
  /// error that `SecItemAdd` returns on duplicate inserts.
  ///
  /// - Parameters:
  ///   - value: The string to store.
  ///   - key: The named key to associate with the value.
  /// - Throws: `KeychainError.saveFailed` if the operation fails.
  @discardableResult
  public static func save(_ value: String, for key: Key) throws -> Bool {
    guard let data = value.data(using: .utf8) else {
      throw KeychainError.encodingFailed
    }

    let query: [CFString: Any] = [
      kSecClass: kSecClassGenericPassword,
      kSecAttrService: service,
      kSecAttrAccount: key.rawValue,
    ]

    // Try to update first — avoids duplicate-item errors.
    let updateAttributes: [CFString: Any] = [
      kSecValueData: data,
      kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
    ]

    let updateStatus = SecItemUpdate(query as CFDictionary, updateAttributes as CFDictionary)

    if updateStatus == errSecSuccess {
      return true
    }

    if updateStatus == errSecItemNotFound {
      // Item doesn't exist yet — insert a new entry.
      var addQuery = query
      addQuery[kSecValueData] = data
      addQuery[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

      let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
      guard addStatus == errSecSuccess else {
        throw KeychainError.saveFailed(status: addStatus)
      }
      return true
    }

    throw KeychainError.saveFailed(status: updateStatus)
  }

  // MARK: - Load

  /// Retrieves a string value from the Keychain.
  ///
  /// - Parameter key: The named key to look up.
  /// - Returns: The stored string, or `nil` if no entry exists.
  public static func load(for key: Key) -> String? {
    let query: [CFString: Any] = [
      kSecClass: kSecClassGenericPassword,
      kSecAttrService: service,
      kSecAttrAccount: key.rawValue,
      kSecReturnData: true,
      kSecMatchLimit: kSecMatchLimitOne,
    ]

    var result: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &result)

    guard status == errSecSuccess, let data = result as? Data else {
      return nil
    }

    return String(data: data, encoding: .utf8)
  }

  // MARK: - Delete

  /// Removes a value from the Keychain.
  ///
  /// No-op if the key does not exist (returns without error).
  ///
  /// - Parameter key: The named key to remove.
  public static func delete(for key: Key) {
    let query: [CFString: Any] = [
      kSecClass: kSecClassGenericPassword,
      kSecAttrService: service,
      kSecAttrAccount: key.rawValue,
    ]

    SecItemDelete(query as CFDictionary)
  }

  // MARK: - Delete All

  /// Removes all Nerve-scoped entries from the Keychain.
  ///
  /// Primarily intended for test teardown or account logout.
  public static func deleteAll() {
    let query: [CFString: Any] = [
      kSecClass: kSecClassGenericPassword,
      kSecAttrService: service,
    ]

    SecItemDelete(query as CFDictionary)
  }
}

// MARK: - KeychainError

/// Errors thrown by ``KeychainStore`` operations.
public enum KeychainError: Error, Sendable {
  /// The string could not be encoded to UTF-8 data.
  case encodingFailed
  /// The Keychain save/update operation failed with the given OSStatus.
  case saveFailed(status: OSStatus)
}

extension KeychainError: LocalizedError {
  public var errorDescription: String? {
    switch self {
    case .encodingFailed:
      return "Failed to encode the value as UTF-8 data."
    case .saveFailed(let status):
      return "Keychain save failed with status \(status)."
    }
  }
}
