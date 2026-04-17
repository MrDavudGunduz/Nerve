//
//  ErrorBannerView.swift
//  MapFeature
//
//  Created by Davud Gunduz on 14.04.2026.
//

#if os(iOS) || os(visionOS)

  import UIKit

  // MARK: - ErrorBannerView

  /// A UIView-based dismissable error banner shown at the top of the map.
  ///
  /// ## Behaviour
  ///
  /// - Slides in via a fade-in animation when ``show(message:)`` is called.
  /// - Auto-dismisses after 4 seconds via a `Timer` scheduled on `.common`
  ///   RunLoop mode so it fires even while the map is being panned or scrolled.
  /// - Can be dismissed immediately by the user tapping the banner.
  /// - Calling ``show(message:)`` while the banner is already visible resets
  ///   the dismiss timer without re-animating the banner.
  ///
  /// ## Why pure UIKit?
  ///
  /// `NerveMapView` wraps `MKMapView` via `UIViewRepresentable`. Embedding a
  /// `UIHostingController` for a SwiftUI banner inside `updateUIView` would
  /// require a `UIViewController` parent — a fragile assumption. Pure UIKit
  /// keeps the overlay self-contained and avoids view hierarchy issues.
  final class ErrorBannerView: UIView {

    // MARK: - Private

    private let label = UILabel()
    private var dismissTimer: Timer?

    // MARK: - Init

    override init(frame: CGRect) {
      super.init(frame: frame)
      setUp()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Use init(frame:)") }

    // MARK: - Layout

    private func setUp() {
      backgroundColor = UIColor.systemRed.withAlphaComponent(0.92)
      layer.cornerRadius = 12
      layer.masksToBounds = true

      label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
      label.textColor = .white
      label.numberOfLines = 2
      label.textAlignment = .center
      label.translatesAutoresizingMaskIntoConstraints = false
      addSubview(label)

      NSLayoutConstraint.activate([
        label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
        label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
        label.topAnchor.constraint(equalTo: topAnchor, constant: 8),
        label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
      ])

      let tap = UITapGestureRecognizer(target: self, action: #selector(dismiss))
      addGestureRecognizer(tap)
    }

    // MARK: - Public API

    /// Displays the banner with the given message and starts a 4-second auto-dismiss timer.
    ///
    /// Calling `show` again while the banner is visible resets the dismiss timer.
    /// The timer is scheduled on `.common` RunLoop mode so it fires correctly
    /// even while the user is scrolling or interacting with the map.
    ///
    /// - Parameter message: The error text to display (max two lines).
    func show(message: String) {
      label.text = message
      dismissTimer?.invalidate()
      UIView.animate(withDuration: 0.25) { self.alpha = 1 }
      dismissTimer = Timer(
        timeInterval: 4,
        target: self,
        selector: #selector(dismiss),
        userInfo: nil,
        repeats: false
      )
      // Schedule on .common so the timer fires during map panning/scrolling.
      RunLoop.main.add(dismissTimer!, forMode: .common)
    }

    // MARK: - Private Actions

    /// Immediately fades out the banner and cancels the dismiss timer.
    @objc private func dismiss() {
      dismissTimer?.invalidate()
      dismissTimer = nil
      UIView.animate(withDuration: 0.25) { self.alpha = 0 }
    }
  }

#endif
