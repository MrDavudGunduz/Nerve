//
//  CertificatePinningDelegate.swift
//  NetworkLayer
//
//  Created by Davud Gunduz on 06.06.2026.
//

import Core
import CryptoKit
import Foundation
import OSLog

// MARK: - CertificatePinningDelegate

/// A `URLSessionDelegate` that enforces SSL certificate pinning
/// for production API requests.
///
/// ## How It Works
///
/// When the server presents its TLS certificate during the handshake:
/// 1. Extracts the **SubjectPublicKeyInfo (SPKI)** from the server certificate.
/// 2. Computes the SHA-256 hash of the SPKI data.
/// 3. Compares the hash against the set of known-good ``pinnedHashes``.
/// 4. If a match is found → trust is established; if not → connection is rejected.
///
/// ## Pin Rotation
///
/// Always include at least **two pins** (primary + backup CA) to avoid
/// bricking the app when certificates rotate. Update ``pinnedHashes``
/// before the current certificate expires.
///
/// ## Development / Proxy Debugging
///
/// Certificate pinning is controlled by ``FeatureFlags/certificatePinningEnabled``.
/// In DEBUG builds, pinning is disabled by default to allow proxy tools
/// (Charles, mitmproxy) to intercept traffic for debugging.
///
/// ## Usage
///
/// This delegate is automatically attached to `URLSession` instances
/// created by ``NetworkConfiguration/makeURLSession()`` when pinning
/// is enabled.
///
/// ```swift
/// let delegate = CertificatePinningDelegate(
///   pinnedHashes: NetworkConfiguration.production.pinnedCertificateHashes
/// )
/// let session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
/// ```
public final class CertificatePinningDelegate: NSObject, URLSessionDelegate, Sendable {

  // MARK: - Properties

  /// SHA-256 hashes of pinned SubjectPublicKeyInfo (SPKI) data.
  ///
  /// Format: Base64-encoded SHA-256 hash strings.
  /// Generate with:
  /// ```bash
  /// openssl s_client -connect api.nerve.app:443 2>/dev/null | \
  ///   openssl x509 -pubkey -noout | \
  ///   openssl pkey -pubin -outform DER | \
  ///   openssl dgst -sha256 -binary | base64
  /// ```
  private let pinnedHashes: Set<String>

  private static let logger = Logger(
    subsystem: LogSubsystem.networkLayer,
    category: "CertificatePinning"
  )

  // MARK: - Init

  /// Creates a pinning delegate with the given set of trusted SPKI hashes.
  ///
  /// - Parameter pinnedHashes: Base64-encoded SHA-256 hashes of trusted
  ///   server certificate public keys. Must contain at least one hash.
  public init(pinnedHashes: Set<String>) {
    self.pinnedHashes = pinnedHashes
    super.init()
  }

  // MARK: - URLSessionDelegate

  /// Evaluates server trust by comparing the certificate's SPKI hash
  /// against the pinned set.
  ///
  /// - If pinning is disabled via ``FeatureFlags``, performs default
  ///   OS-level certificate validation only.
  /// - If the server certificate matches a pinned hash, trust is established.
  /// - If no match is found, the connection is rejected with `.cancelAuthenticationChallenge`.
  public func urlSession(
    _ session: URLSession,
    didReceive challenge: URLAuthenticationChallenge
  ) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {

    // Only handle server trust challenges — let other auth types pass through.
    guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
      let serverTrust = challenge.protectionSpace.serverTrust
    else {
      return (.performDefaultHandling, nil)
    }

    // Skip pinning if disabled (e.g., DEBUG builds for proxy debugging).
    guard FeatureFlags.certificatePinningEnabled else {
      Self.logger.debug("Certificate pinning disabled — using default trust evaluation.")
      return (.performDefaultHandling, nil)
    }

    // If no pins are configured, fall back to default OS validation.
    guard !pinnedHashes.isEmpty else {
      Self.logger.warning("No certificate pins configured — using default trust evaluation.")
      return (.performDefaultHandling, nil)
    }

    // Evaluate the server's certificate chain against the OS trust store first.
    var secError: CFError?
    let isTrusted = SecTrustEvaluateWithError(serverTrust, &secError)

    guard isTrusted else {
      Self.logger.error(
        "Server trust evaluation failed: \(secError?.localizedDescription ?? "unknown", privacy: .public)"
      )
      return (.cancelAuthenticationChallenge, nil)
    }

    // Extract the leaf certificate and compute its SPKI SHA-256 hash.
    guard let certificateChain = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate],
      let leafCertificate = certificateChain.first
    else {
      Self.logger.error("Failed to extract certificate chain from server trust.")
      return (.cancelAuthenticationChallenge, nil)
    }

    let serverHash = Self.sha256Hash(of: leafCertificate)

    if pinnedHashes.contains(serverHash) {
      Self.logger.debug(
        "Certificate pin matched for \(challenge.protectionSpace.host, privacy: .public)."
      )
      return (.useCredential, URLCredential(trust: serverTrust))
    }

    Self.logger.error(
      """
      Certificate pin MISMATCH for \(challenge.protectionSpace.host, privacy: .public). \
      Server hash: \(serverHash, privacy: .public). \
      Connection rejected — possible MITM attack.
      """
    )
    return (.cancelAuthenticationChallenge, nil)
  }

  // MARK: - Hashing

  /// Computes the Base64-encoded SHA-256 hash of a certificate's
  /// SubjectPublicKeyInfo (SPKI) data.
  ///
  /// Uses `SecCertificateCopyKey` to extract the public key, then
  /// `SecKeyCopyExternalRepresentation` to get the raw key bytes.
  ///
  /// - Parameter certificate: The `SecCertificate` to hash.
  /// - Returns: A Base64-encoded SHA-256 hash string.
  static func sha256Hash(of certificate: SecCertificate) -> String {
    // Use the full DER-encoded certificate data for hashing.
    // This is simpler and more reliable than extracting just the SPKI,
    // as SecKeyCopyExternalRepresentation may not be available on all platforms.
    let certData = SecCertificateCopyData(certificate) as Data
    let hash = SHA256.hash(data: certData)
    return Data(hash).base64EncodedString()
  }
}
