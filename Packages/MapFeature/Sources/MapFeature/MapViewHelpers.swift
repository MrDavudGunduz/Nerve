//
//  MapViewHelpers.swift
//  MapFeature
//
//  Created by Davud Gunduz on 14.04.2026.
//

#if os(iOS) || os(visionOS)

  import UIKit

  // MARK: - UIView + ViewController

  extension UIView {

    /// Walks the responder chain to find the nearest presenting `UIViewController`.
    ///
    /// Used by map overlay views that need to present sheets or alerts
    /// without a direct reference to a controller.
    ///
    /// - Returns: The nearest ancestor `UIViewController`, or `nil` if the
    ///   view is not currently installed in a view controller hierarchy.
    var viewController: UIViewController? {
      var responder: UIResponder? = self
      while let r = responder {
        if let vc = r as? UIViewController { return vc }
        responder = r.next
      }
      return nil
    }
  }

#endif
