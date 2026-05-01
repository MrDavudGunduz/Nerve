//
//  SceneKitContainer.swift
//  ARFeature
//
//  Created by Davud Gunduz on 01.05.2026.
//

import SwiftUI

#if canImport(SceneKit)
  import SceneKit

  // MARK: - SceneKitContainer (SwiftUI Bridge)

  /// A SwiftUI-representable wrapper for `SCNView`.
  ///
  /// This struct is **only** responsible for the SwiftUI ↔ SceneKit
  /// bridge. Scene construction is delegated to ``SceneViewFactory``.
  #if os(iOS) || os(visionOS)
    struct SceneKitContainer: UIViewRepresentable {

      let modelURL: URL?

      func makeUIView(context: Context) -> SCNView {
        SceneViewFactory.makeView(modelURL: modelURL)
      }

      func updateUIView(_ uiView: SCNView, context: Context) {
        // No reactive updates needed — scene is configured once.
      }
    }
  #elseif os(macOS)
    struct SceneKitContainer: NSViewRepresentable {

      let modelURL: URL?

      func makeNSView(context: Context) -> SCNView {
        SceneViewFactory.makeView(modelURL: modelURL)
      }

      func updateNSView(_ nsView: SCNView, context: Context) {
        // No reactive updates needed — scene is configured once.
      }
    }
  #endif

#endif
