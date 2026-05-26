//
//  SettingsView.swift
//  Nerve
//
//  Created by Davud Gunduz on 18.05.2026.
//

import Core
import OSLog
import StorageLayer
import SwiftUI

// MARK: - SettingsView

/// The Settings tab providing cache management, app diagnostics, and
/// developer-facing build information.
///
/// ## Features
///
/// - **Cache Management:** View cached item count and clear all cached data.
/// - **Build Information:** Version, build number, and Swift version (debug only).
/// - **Storage Diagnostics:** TTL display and last prune timestamp.
///
/// ## Architecture
///
/// Services are resolved lazily from the ``DependencyContainer`` injected
/// via `@Environment`. This avoids blocking the view hierarchy during
/// initialization if a service is not yet registered.
struct SettingsView: View {

  @Environment(\.dependencyContainer) private var container

  @State private var cachedItemCount: Int?
  @State private var isLoadingCount = false
  @State private var isPruning = false
  @State private var showClearConfirmation = false
  @State private var lastPruneDate: Date?
  @State private var statusMessage: String?

  /// Tracked handle for the auto-dismiss timer so it can be cancelled
  /// when the view disappears or a new status replaces the current one.
  /// Prevents orphaned Tasks from mutating state after teardown (C-2).
  @State private var statusDismissTask: Task<Void, Never>?

  private static let logger = Logger(
    subsystem: LogSubsystem.main,
    category: "Settings"
  )

  // MARK: - Body

  var body: some View {
    NavigationStack {
      List {
        cacheSection
        aboutSection
        #if DEBUG
          developerSection
        #endif
      }
      .navigationTitle("Settings")
      .task {
        await loadCachedItemCount()
      }
      .onDisappear {
        statusDismissTask?.cancel()
        statusDismissTask = nil
      }
      .alert("Clear Cache", isPresented: $showClearConfirmation) {
        Button("Cancel", role: .cancel) {}
        Button("Clear All", role: .destructive) {
          Task { await clearCache() }
        }
      } message: {
        Text("This will remove all cached news items. Fresh data will be fetched on the next map load.")
      }
      .overlay {
        if let statusMessage {
          statusBanner(message: statusMessage)
        }
      }
    }
  }

  // MARK: - Cache Section

  private var cacheSection: some View {
    Section {
      HStack {
        Label("Cached Items", systemImage: "internaldrive.fill")
        Spacer()
        if isLoadingCount {
          ProgressView()
            .controlSize(.small)
        } else {
          Text(cachedItemCount.map { "\($0)" } ?? "—")
            .foregroundStyle(.secondary)
        }
      }
      .accessibilityIdentifier("settings-cached-items")

      HStack {
        Label("Cache TTL", systemImage: "clock.arrow.circlepath")
        Spacer()
        Text("24 hours")
          .foregroundStyle(.secondary)
      }
      .accessibilityIdentifier("settings-cache-ttl")

      if let lastPruneDate {
        HStack {
          Label("Last Pruned", systemImage: "trash.circle")
          Spacer()
          Text(lastPruneDate, style: .relative)
            .foregroundStyle(.secondary)
        }
      }

      Button(role: .destructive) {
        showClearConfirmation = true
      } label: {
        Label("Clear Cache", systemImage: "trash.fill")
      }
      .disabled(isPruning || cachedItemCount == 0)
      .accessibilityIdentifier("settings-clear-cache")
    } header: {
      Text("Storage")
    } footer: {
      Text("Cached data is automatically pruned after 24 hours. Clearing the cache removes all locally stored news items.")
    }
  }

  // MARK: - About Section

  private var aboutSection: some View {
    Section("About") {
      HStack {
        Label("Version", systemImage: "info.circle.fill")
        Spacer()
        Text(appVersion)
          .foregroundStyle(.secondary)
      }
      .accessibilityIdentifier("settings-version")

      HStack {
        Label("Build", systemImage: "hammer.fill")
        Spacer()
        Text(buildNumber)
          .foregroundStyle(.secondary)
      }
      .accessibilityIdentifier("settings-build")

      Link(destination: URL(string: "https://github.com/MrDavudGunduz/Nerve")!) {
        Label("Source Code", systemImage: "chevron.left.forwardslash.chevron.right")
      }
      .accessibilityIdentifier("settings-source-code")
    }
  }

  // MARK: - Developer Section (DEBUG only)

  #if DEBUG
    private var developerSection: some View {
      Section("Developer") {
        HStack {
          Label("Swift Version", systemImage: "swift")
          Spacer()
          Text("6.0")
            .foregroundStyle(.secondary)
            .font(.system(.body, design: .monospaced))
        }

        HStack {
          Label("Concurrency", systemImage: "checkmark.shield.fill")
          Spacer()
          Text("Strict")
            .foregroundStyle(.green)
            .font(.system(.body, design: .monospaced))
        }

        HStack {
          Label("Build Config", systemImage: "wrench.and.screwdriver.fill")
          Spacer()
          Text("DEBUG")
            .foregroundStyle(.orange)
            .font(.system(.body, design: .monospaced))
        }

        Button {
          Task { await pruneExpiredCache() }
        } label: {
          Label("Prune Expired Cache", systemImage: "arrow.triangle.2.circlepath")
        }
        .disabled(isPruning)
        .accessibilityIdentifier("settings-prune-cache")
      }
    }
  #endif

  // MARK: - Status Banner

  private func statusBanner(message: String) -> some View {
    VStack {
      Spacer()
      Text(message)
        .font(.subheadline.weight(.medium))
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.thinMaterial.opacity(0.95))
        .background(Color.accentColor.opacity(0.8))
        .clipShape(Capsule())
        .padding(.bottom, 16)
    }
    .transition(.move(edge: .bottom).combined(with: .opacity))
    .animation(.spring(duration: 0.3), value: statusMessage)
  }

  // MARK: - Actions

  private func loadCachedItemCount() async {
    isLoadingCount = true
    defer { isLoadingCount = false }

    do {
      let storageService = try await container.resolve(StorageServiceProtocol.self)
      let items = try await storageService.fetchNews(in: nil, limit: nil, offset: nil)
      cachedItemCount = items.count
    } catch {
      Self.logger.warning("Failed to load cached item count: \(error.localizedDescription)")
      cachedItemCount = nil
    }
  }

  /// Clears all cached news items using a single batch delete operation.
  ///
  /// Replaces the previous N-round-trip loop (`deleteNews(id:)` per item)
  /// with ``StorageServiceProtocol/deleteAllNews()`` for O(1) actor hops.
  private func clearCache() async {
    isPruning = true
    defer { isPruning = false }

    do {
      let storageService = try await container.resolve(StorageServiceProtocol.self)
      let deletedCount = try await storageService.deleteAllNews()
      cachedItemCount = 0
      lastPruneDate = Date()
      showStatus("Cache cleared successfully")
      Self.logger.info("Cache cleared: \(deletedCount) items removed.")
    } catch {
      Self.logger.error("Failed to clear cache: \(error.localizedDescription)")
      showStatus("Failed to clear cache")
    }
  }

  private func pruneExpiredCache() async {
    isPruning = true
    defer { isPruning = false }

    do {
      let storageService = try await container.resolve(StorageServiceProtocol.self)
      try await storageService.pruneExpiredCache()
      lastPruneDate = Date()
      await loadCachedItemCount()
      showStatus("Expired cache pruned")
      Self.logger.info("Manual prune completed.")
    } catch {
      Self.logger.error("Failed to prune cache: \(error.localizedDescription)")
      showStatus("Failed to prune cache")
    }
  }

  /// Shows a status banner that auto-dismisses after 2 seconds.
  ///
  /// The dismiss Task is tracked via ``statusDismissTask`` so it can be
  /// cancelled when the view disappears or a new status replaces the
  /// current one — preventing orphaned state mutations (audit fix C-2).
  private func showStatus(_ message: String) {
    statusDismissTask?.cancel()
    statusMessage = message
    statusDismissTask = Task {
      try? await Task.sleep(for: .seconds(2))
      guard !Task.isCancelled else { return }
      statusMessage = nil
    }
  }

  // MARK: - App Info

  private var appVersion: String {
    Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
  }

  private var buildNumber: String {
    Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
  }
}

// MARK: - Preview

#Preview {
  SettingsView()
}

