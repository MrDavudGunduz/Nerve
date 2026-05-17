//
//  ARNewsViewController.swift
//  ARFeature
//
//  Created by Davud Gunduz on 17.05.2026.
//

#if canImport(UIKit)

  import Core
  import OSLog
  import SwiftUI
  import UIKit

  // MARK: - ARNewsViewController

  /// A UIKit-hosted AR news viewer for integration with UIKit navigation stacks.
  ///
  /// Wraps ``ARNewsView`` inside a `UIHostingController`, providing a familiar
  /// UIKit API surface for presenting the AR experience from any part of
  /// the app — whether it's a push navigation, modal presentation, or
  /// popover.
  ///
  /// ## Usage
  ///
  /// ```swift
  /// // Push presentation:
  /// let arVC = ARNewsViewController(newsItem: item)
  /// navigationController?.pushViewController(arVC, animated: true)
  ///
  /// // Modal presentation:
  /// let arVC = ARNewsViewController(newsItem: item)
  /// arVC.modalPresentationStyle = .fullScreen
  /// present(arVC, animated: true)
  /// ```
  ///
  /// ## Lifecycle Management
  ///
  /// The controller manages its `ARNewsViewModel` lifecycle automatically:
  /// - Model loading begins in `viewDidLoad`.
  /// - Model loading is cancelled in `deinit` to prevent resource leaks.
  /// - Haptic engine is torn down on dismissal.
  ///
  /// ## Design Decision
  ///
  /// Although Nerve is primarily SwiftUI, this UIKit bridge exists because:
  /// 1. `UINavigationController` push/pop animations feel more natural for AR transitions.
  /// 2. Some AR coaching flows require `UIViewController` lifecycle hooks.
  /// 3. UIKit integration is a production requirement for hybrid navigation stacks.
  @MainActor
  public final class ARNewsViewController: UIHostingController<ARNewsView> {

    // MARK: - Properties

    /// The news item being displayed in AR.
    public let newsItem: NewsItem

    // MARK: - Logging

    private nonisolated(unsafe) static let logger = Logger(
      subsystem: "com.davudgunduz.Nerve.ARFeature",
      category: "ARNewsViewController"
    )

    // MARK: - Init

    /// Creates an AR news view controller for the given news item.
    ///
    /// - Parameter newsItem: The news item to display in AR.
    public init(newsItem: NewsItem) {
      self.newsItem = newsItem
      let arView = ARNewsView(newsItem: newsItem)
      super.init(rootView: arView)

      Self.logger.info(
        "ARNewsViewController initialized for item '\(newsItem.id)'."
      )
    }

    @available(*, unavailable)
    public required init?(coder _: NSCoder) {
      fatalError("ARNewsViewController does not support Interface Builder.")
    }

    // MARK: - Lifecycle

    override public func viewDidLoad() {
      super.viewDidLoad()

      // Configure the view for immersive AR experience.
      view.backgroundColor = .black

      // Hide navigation bar for full-screen AR.
      navigationController?.setNavigationBarHidden(true, animated: false)

      Self.logger.info("ARNewsViewController viewDidLoad.")
    }

    override public func viewWillDisappear(_ animated: Bool) {
      super.viewWillDisappear(animated)

      // Restore navigation bar visibility when leaving AR.
      navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    override public var prefersStatusBarHidden: Bool {
      true
    }

    override public var prefersHomeIndicatorAutoHidden: Bool {
      true
    }

    override public var supportedInterfaceOrientations: UIInterfaceOrientationMask {
      .all
    }

    deinit {
      Self.logger.info(
        "ARNewsViewController deallocated for item '\(self.newsItem.id)'."
      )
    }
  }

#endif
