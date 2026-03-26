//
//  ContentView.swift
//  Nerve
//
//  Created by Davud Gunduz on 25.03.2026.
//

import SwiftUI

/// The root view of the Nerve application.
///
/// Provides platform-adaptive navigation that serves as the composition root
/// for all feature modules. On iOS, it presents a tab-based interface.
/// On macOS, it uses a sidebar navigation. On visionOS, it adapts to
/// spatial computing conventions.
struct ContentView: View {

  // MARK: - Body

  var body: some View {
    NavigationStack {
      VStack(spacing: 24) {
        Spacer()

        Image(systemName: "globe.europe.africa.fill")
          .font(.system(size: 80))
          .foregroundStyle(.tint)
          .symbolEffect(.pulse, options: .repeating)

        Text("Nerve")
          .font(.largeTitle)
          .fontWeight(.bold)

        Text("Spatial News Intelligence")
          .font(.title3)
          .foregroundStyle(.secondary)

        platformInfoView

        Spacer()
      }
      .padding()
      .navigationTitle("Nerve")
      #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
      #endif
    }
  }

  // MARK: - Platform Info

  /// Displays the current platform for verification purposes.
  private var platformInfoView: some View {
    HStack(spacing: 8) {
      Image(systemName: platformIcon)
      Text(platformName)
    }
    .font(.subheadline)
    .foregroundStyle(.tertiary)
    .padding(.horizontal, 16)
    .padding(.vertical, 8)
    .background(.quaternary, in: Capsule())
  }

  private var platformName: String {
    #if os(iOS)
      "iOS"
    #elseif os(macOS)
      "macOS"
    #elseif os(visionOS)
      "visionOS"
    #else
      "Unknown"
    #endif
  }

  private var platformIcon: String {
    #if os(iOS)
      "iphone"
    #elseif os(macOS)
      "macbook"
    #elseif os(visionOS)
      "visionpro"
    #else
      "questionmark.circle"
    #endif
  }
}

// MARK: - Preview

#Preview {
  ContentView()
}
