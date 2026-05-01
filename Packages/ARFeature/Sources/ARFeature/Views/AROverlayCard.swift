//
//  AROverlayCard.swift
//  ARFeature
//
//  Created by Davud Gunduz on 01.05.2026.
//

import Core
import SwiftUI

// MARK: - AROverlayCard

/// A floating informational card displayed over the AR/3D viewer.
///
/// Shows the news headline, source, publication date, and a color-coded
/// credibility badge. Designed as a glassmorphism-style overlay that
/// remains legible over both camera feeds and 3D backgrounds.
///
/// ## Layout
///
/// ```
/// ┌──────────────────────────────────┐
/// │  ✅ Verified    │    Source Name  │
/// │  Headline Text (multiline)       │
/// │  Apr 15, 2026                    │
/// └──────────────────────────────────┘
/// ```
///
/// ## Accessibility
///
/// - All text elements have `accessibilityLabel` and `accessibilityHint`.
/// - The credibility badge uses both color and icon for non-color-dependent signaling.
/// - Supports Dynamic Type via `.font(.body)` etc.
public struct AROverlayCard: View {

  // MARK: - Properties

  private let headline: String
  private let source: String
  private let date: String
  private let credibilityLabel: CredibilityLabel?
  private let onDismiss: (() -> Void)?

  // MARK: - Init

  /// Creates an overlay card with explicit values.
  ///
  /// - Parameters:
  ///   - headline: The news headline text.
  ///   - source: The publication source name.
  ///   - date: The formatted publication date.
  ///   - credibilityLabel: The AI credibility assessment, if available.
  ///   - onDismiss: Optional closure called when the user taps the dismiss button.
  public init(
    headline: String,
    source: String,
    date: String,
    credibilityLabel: CredibilityLabel? = nil,
    onDismiss: (() -> Void)? = nil
  ) {
    self.headline = headline
    self.source = source
    self.date = date
    self.credibilityLabel = credibilityLabel
    self.onDismiss = onDismiss
  }

  /// Convenience initializer from a ``NewsItem``.
  ///
  /// - Parameters:
  ///   - newsItem: The news item to display.
  ///   - onDismiss: Optional closure called when the user taps the dismiss button.
  public init(newsItem: NewsItem, onDismiss: (() -> Void)? = nil) {
    self.headline = newsItem.headline
    self.source = newsItem.source
    self.date = newsItem.publishedAt.formatted(
      .dateTime.month(.abbreviated).day().year()
    )
    self.credibilityLabel = newsItem.analysis?.credibilityLabel
    self.onDismiss = onDismiss
  }

  // MARK: - Body

  public var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      // Top row: credibility badge + source + dismiss
      HStack {
        if let credibilityLabel {
          credibilityBadge(credibilityLabel)
        }

        Spacer()

        Text(source)
          .font(.caption)
          .fontWeight(.semibold)
          .foregroundStyle(.secondary)
          .accessibilityLabel("Source: \(source)")

        if let onDismiss {
          Button(action: onDismiss) {
            Image(systemName: "xmark.circle.fill")
              .font(.title3)
              .foregroundStyle(.secondary)
          }
          .buttonStyle(.plain)
          .accessibilityLabel("Dismiss overlay")
          .accessibilityHint("Hides the news information card")
        }
      }

      // Headline
      Text(headline)
        .font(.headline)
        .fontWeight(.bold)
        .lineLimit(3)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityLabel("Headline: \(headline)")

      // Date
      Text(date)
        .font(.caption2)
        .foregroundStyle(.tertiary)
        .accessibilityLabel("Published: \(date)")
    }
    .padding(16)
    .frame(maxWidth: ARNewsConfiguration.overlayCardMaxWidth)
    .background(.ultraThinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
    .accessibilityElement(children: .contain)
    .accessibilityLabel("News overlay card")
  }

  // MARK: - Subviews

  @ViewBuilder
  private func credibilityBadge(_ label: CredibilityLabel) -> some View {
    HStack(spacing: 4) {
      Image(systemName: badgeIcon(for: label))
        .font(.caption)
      Text(label.rawValue)
        .font(.caption)
        .fontWeight(.medium)
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background(badgeColor(for: label).opacity(0.2))
    .foregroundStyle(badgeColor(for: label))
    .clipShape(Capsule())
    .accessibilityLabel("Credibility: \(label.rawValue)")
    .accessibilityHint(badgeAccessibilityHint(for: label))
  }

  // MARK: - Badge Helpers

  private func badgeIcon(for label: CredibilityLabel) -> String {
    switch label {
    case .verified: return "checkmark.seal.fill"
    case .caution: return "exclamationmark.triangle.fill"
    case .clickbait: return "nosign"
    }
  }

  private func badgeColor(for label: CredibilityLabel) -> Color {
    switch label {
    case .verified: return .green
    case .caution: return .orange
    case .clickbait: return .red
    }
  }

  private func badgeAccessibilityHint(for label: CredibilityLabel) -> String {
    switch label {
    case .verified:
      return "This headline has been assessed as likely genuine content."
    case .caution:
      return "This headline requires reader judgment. Exercise caution."
    case .clickbait:
      return "This headline has been flagged as likely clickbait."
    }
  }
}

// MARK: - Preview

#if DEBUG
  #Preview("Verified") {
    AROverlayCard(
      headline: "Apple Unveils Revolutionary Spatial Computing Chip at WWDC 2026",
      source: "TechCrunch",
      date: "Apr 15, 2026",
      credibilityLabel: .verified,
      onDismiss: {}
    )
    .padding()
    .background(.black)
  }

  #Preview("Caution") {
    AROverlayCard(
      headline: "You Won't Believe What This New AI Can Do — Scientists Are Shocked!",
      source: "BuzzFeed",
      date: "Apr 16, 2026",
      credibilityLabel: .caution,
      onDismiss: {}
    )
    .padding()
    .background(.black)
  }

  #Preview("Clickbait") {
    AROverlayCard(
      headline: "THIS ONE TRICK Will Change Your Life FOREVER!!!",
      source: "ClickHarvest",
      date: "Apr 17, 2026",
      credibilityLabel: .clickbait,
      onDismiss: {}
    )
    .padding()
    .background(.black)
  }
#endif
