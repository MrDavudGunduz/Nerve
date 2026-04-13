//
//  NewsAnnotationView.swift
//  MapFeature
//
//  Created by Davud Gunduz on 31.03.2026.
//

#if canImport(UIKit)

  import Core
  import MapKit
  import UIKit

  // MARK: - NewsAnnotationView

  /// A custom annotation view for single news items on the map.
  ///
  /// Displays a compact pin with:
  /// - **Category icon** — SF Symbol representing the news category.
  /// - **Credibility badge** — small colored ring indicating trustworthiness.
  /// - **Selection animation** — scale + shadow lift on tap.
  public final class NewsAnnotationView: MKAnnotationView {

    // MARK: - Subviews

    private let iconView: UIImageView = {
      let imageView = UIImageView()
      imageView.contentMode = .scaleAspectFit
      imageView.tintColor = .white
      return imageView
    }()

    // MARK: - Constants

    private static let pinSize: CGFloat = 36
    /// Width of the credibility ring border.
    private static let ringWidth: CGFloat = 3

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
      let size = Self.pinSize
      frame = CGRect(x: 0, y: 0, width: size, height: size)
      centerOffset = CGPoint(x: 0, y: -size / 2)

      canShowCallout = false  // Bottom sheet replaces callout.
      collisionMode = .circle
      displayPriority = .defaultLow

      layer.cornerRadius = size / 2
      layer.borderWidth = Self.ringWidth
      layer.borderColor = UIColor.white.withAlphaComponent(0.4).cgColor
      layer.shadowColor = UIColor.black.cgColor
      layer.shadowOpacity = 0.15
      layer.shadowOffset = CGSize(width: 0, height: 1)
      layer.shadowRadius = 3

      addSubview(iconView)
    }

    // MARK: - Configuration

    override public var annotation: (any MKAnnotation)? {
      didSet { configure() }
    }

    override public func prepareForReuse() {
      super.prepareForReuse()
      iconView.image = nil
      layer.borderColor = UIColor.white.withAlphaComponent(0.4).cgColor
      layer.removeAllAnimations()
      transform = .identity
    }

    private func configure() {
      guard let newsAnnotation = annotation as? NewsAnnotation else { return }
      configure(with: newsAnnotation.cluster)
    }

    /// Configures the view with the given cluster.
    ///
    /// Called by ``NerveMapView/Coordinator`` after dequeuing to populate
    /// category color, icon, and credibility ring for the supplied cluster.
    ///
    /// - Parameter cluster: The ``NewsCluster`` to render.
    public func configure(with cluster: NewsCluster) {
      guard let item = cluster.items.first else { return }

      // Background color: category.
      backgroundColor = ClusterAnnotationView.color(for: item.category)

      // Category icon.
      let iconSize: CGFloat = 20
      iconView.frame = CGRect(
        x: (Self.pinSize - iconSize) / 2,
        y: (Self.pinSize - iconSize) / 2,
        width: iconSize, height: iconSize
      )
      iconView.image = Self.icon(for: item.category)

      // Credibility ring — border color signals the article's trustworthiness.
      if let analysis = item.analysis {
        layer.borderColor =
          ClusterAnnotationView.credibilityColor(
            for: analysis.credibilityLabel
          ).cgColor
      } else {
        layer.borderColor = UIColor.white.withAlphaComponent(0.35).cgColor
      }
    }

    // MARK: - Skeleton

    /// Replaces real content with a pulsing grey placeholder while data loads.
    public func showSkeleton() {
      iconView.image = nil
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

    // MARK: - Selection Animation

    override public func setSelected(_ selected: Bool, animated: Bool) {
      super.setSelected(selected, animated: animated)

      guard animated else {
        transform =
          selected
          ? CGAffineTransform(scaleX: 1.2, y: 1.2)
          : .identity
        return
      }

      UIView.animate(
        withDuration: 0.3, delay: 0,
        usingSpringWithDamping: 0.65, initialSpringVelocity: 0.8,
        options: [.curveEaseInOut],
        animations: {
          self.transform =
            selected
            ? CGAffineTransform(scaleX: 1.2, y: 1.2)
            : .identity
          self.layer.shadowOpacity = selected ? 0.35 : 0.15
          self.layer.shadowRadius = selected ? 6 : 3
        }
      )
    }

    // MARK: - Icons

    /// Returns an SF Symbol for the given category.
    public static func icon(for category: NewsCategory) -> UIImage? {
      let name: String
      switch category {
      case .politics: name = "building.columns.fill"
      case .technology: name = "cpu.fill"
      case .science: name = "atom"
      case .health: name = "heart.fill"
      case .sports: name = "sportscourt.fill"
      case .entertainment: name = "film.fill"
      case .business: name = "chart.line.uptrend.xyaxis"
      case .environment: name = "leaf.fill"
      case .other: name = "newspaper.fill"
      }
      return UIImage(systemName: name)?.withRenderingMode(.alwaysTemplate)
    }
  }

#endif
