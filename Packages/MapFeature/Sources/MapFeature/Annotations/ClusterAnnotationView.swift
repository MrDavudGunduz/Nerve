//
//  ClusterAnnotationView.swift
//  MapFeature
//
//  Created by Davud Gunduz on 31.03.2026.
//

#if canImport(UIKit)

  import Core
  import MapKit
  import UIKit

  // MARK: - ClusterAnnotationView

  /// A custom annotation view for multi-item news clusters.
  ///
  /// Displays a circular bubble with:
  /// - **Count label** — number of stories in the cluster.
  /// - **Category ring** — color-coded border matching the dominant category.
  /// - **Credibility dot** — small indicator for average credibility.
  ///
  /// Includes spring animations for expand/collapse transitions
  /// when the map zoom level changes.
  public final class ClusterAnnotationView: MKAnnotationView {

    // MARK: - Subviews

    private let countLabel: UILabel = {
      let label = UILabel()
      label.textAlignment = .center
      label.font = .systemFont(ofSize: 14, weight: .bold)
      label.textColor = .white
      label.adjustsFontSizeToFitWidth = true
      label.minimumScaleFactor = 0.6
      return label
    }()

    // MARK: - Constants

    private static let baseSize: CGFloat = 44
    private static let maxSize: CGFloat = 64
    /// Width of the credibility ring border.
    private static let ringWidth: CGFloat = 3.5

    // MARK: - Init

    override init(annotation: (any MKAnnotation)?, reuseIdentifier: String?) {
      super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
      setupView()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
      fatalError("init(coder:) is not supported")
    }

    // MARK: - Setup

    private func setupView() {
      canShowCallout = false  // Bottom sheet replaces callout.
      collisionMode = .circle
      displayPriority = .defaultHigh

      addSubview(countLabel)

      layer.borderWidth = Self.ringWidth
      layer.borderColor = UIColor.white.withAlphaComponent(0.4).cgColor
      layer.shadowColor = UIColor.black.cgColor
      layer.shadowOpacity = 0.2
      layer.shadowOffset = CGSize(width: 0, height: 2)
      layer.shadowRadius = 4
    }

    // MARK: - Configuration

    override public var annotation: (any MKAnnotation)? {
      didSet { configure() }
    }

    override public func prepareForReuse() {
      super.prepareForReuse()
      countLabel.text = nil
      layer.borderColor = UIColor.white.withAlphaComponent(0.4).cgColor
      layer.removeAllAnimations()
      transform = .identity
      alpha = 1.0
    }

    private func configure() {
      guard let newsAnnotation = annotation as? NewsAnnotation else { return }
      configure(with: newsAnnotation.cluster)
    }

    /// Configures the view with the given cluster.
    ///
    /// Called by ``NerveMapView/Coordinator`` after dequeuing to populate
    /// count label, size, category color, and credibility ring.
    ///
    /// - Parameter cluster: The ``NewsCluster`` to render.
    public func configure(with cluster: NewsCluster) {
      // Size scales with item count (log scale to prevent oversized bubbles).
      let scale = min(
        1.0 + log2(Double(cluster.count)) * 0.15,
        Self.maxSize / Self.baseSize
      )
      let size = Self.baseSize * scale
      frame = CGRect(x: 0, y: 0, width: size, height: size)
      centerOffset = CGPoint(x: 0, y: -size / 2)

      // Background: category color.
      backgroundColor = Self.color(for: cluster.dominantCategory)
      layer.cornerRadius = size / 2
      layer.masksToBounds = false

      // Count label.
      countLabel.text = "\(cluster.count)"
      countLabel.frame = bounds

      // Credibility ring — visible border whose color signals trustworthiness.
      if let label = cluster.averageCredibilityLabel {
        layer.borderColor = Self.credibilityColor(for: label).cgColor
      } else {
        // No analysis yet — neutral ring.
        layer.borderColor = UIColor.white.withAlphaComponent(0.35).cgColor
      }

      // ── Accessibility ──
      isAccessibilityElement = true
      accessibilityTraits = .button
      let credibility = cluster.averageCredibilityLabel?.rawValue ?? "unanalyzed"
      accessibilityLabel = "News cluster: \(cluster.count) stories, \(cluster.dominantCategory.rawValue.capitalized) category. Credibility: \(credibility)"
      accessibilityHint = "Double tap to view cluster details"
    }

    // MARK: - Skeleton

    /// Replaces real content with a pulsing grey placeholder while data loads.
    public func showSkeleton() {
      countLabel.text = nil
      backgroundColor = .systemGray4
      layer.borderColor = UIColor.clear.cgColor

      let pulse = CABasicAnimation(keyPath: "opacity")
      pulse.fromValue = 1.0
      pulse.toValue = 0.4
      pulse.duration = 0.8
      pulse.autoreverses = true
      pulse.repeatCount = .infinity
      pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
      layer.add(pulse, forKey: "skeletonPulse")
    }

    /// Restores the normal appearance after data has loaded.
    public func hideSkeleton() {
      layer.removeAnimation(forKey: "skeletonPulse")
    }

    // MARK: - Animation

    /// Plays a spring scale animation when the cluster appears or updates.
    public func animateAppearance() {
      transform = CGAffineTransform(scaleX: 0.3, y: 0.3)
      alpha = 0.0

      UIView.animate(
        withDuration: 0.5, delay: 0,
        usingSpringWithDamping: 0.6, initialSpringVelocity: 1.0,
        options: [.curveEaseOut],
        animations: {
          self.transform = .identity
          self.alpha = 1.0
        }
      )
    }

    /// Plays a collapse animation before removal.
    public func animateDisappearance(completion: @escaping () -> Void) {
      UIView.animate(
        withDuration: 0.25, delay: 0,
        options: [.curveEaseIn],
        animations: {
          self.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
          self.alpha = 0.0
        },
        completion: { _ in completion() }
      )
    }

    // MARK: - Colors

    /// Returns the theme color for a news category.
    public static func color(for category: NewsCategory) -> UIColor {
      switch category {
      case .politics: return UIColor(red: 0.20, green: 0.40, blue: 0.80, alpha: 1.0)
      case .technology: return UIColor(red: 0.55, green: 0.30, blue: 0.85, alpha: 1.0)
      case .science: return UIColor(red: 0.00, green: 0.70, blue: 0.60, alpha: 1.0)
      case .health: return UIColor(red: 0.90, green: 0.30, blue: 0.35, alpha: 1.0)
      case .sports: return UIColor(red: 0.95, green: 0.55, blue: 0.15, alpha: 1.0)
      case .entertainment: return UIColor(red: 0.90, green: 0.25, blue: 0.60, alpha: 1.0)
      case .business: return UIColor(red: 0.18, green: 0.55, blue: 0.34, alpha: 1.0)
      case .environment: return UIColor(red: 0.30, green: 0.70, blue: 0.30, alpha: 1.0)
      case .other: return UIColor(red: 0.50, green: 0.50, blue: 0.55, alpha: 1.0)
      }
    }

    /// Returns the indicator color for a credibility label.
    public static func credibilityColor(for label: CredibilityLabel) -> UIColor {
      switch label {
      case .verified: return UIColor(red: 0.20, green: 0.78, blue: 0.35, alpha: 1.0)
      case .caution: return UIColor(red: 0.95, green: 0.75, blue: 0.15, alpha: 1.0)
      case .clickbait: return UIColor(red: 0.90, green: 0.22, blue: 0.21, alpha: 1.0)
      }
    }
  }

#endif
