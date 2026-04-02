//
//  ContentView.swift
//  Nerve
//
//  Created by Davud Gunduz on 25.03.2026.
//

import Core
import MapFeature
import SwiftUI

// MARK: - ContentView

/// The root view of the Nerve application.
///
/// Uses a tab-based navigation structure on iOS/visionOS and a
/// sidebar layout on macOS. The **Map** tab is the primary entry point,
/// rendered by ``MapFeature/NerveMapView``.
struct ContentView: View {

  @Environment(\.dependencyContainer) private var container

  // MARK: - Body

  var body: some View {
    #if os(iOS) || os(visionOS)
      tabView
    #elseif os(macOS)
      sidebarView
    #endif
  }

  // MARK: - Tab Layout (iOS / visionOS)

  #if os(iOS) || os(visionOS)
    private var tabView: some View {
      TabView {
        NerveMapView()
          .tabItem {
            Label("Map", systemImage: "map.fill")
          }
          .tag(Tab.map)

        placeholderTab(
          title: "Headlines",
          icon: "newspaper.fill",
          tag: .headlines
        )

        placeholderTab(
          title: "Insights",
          icon: "chart.bar.xaxis",
          tag: .insights
        )

        placeholderTab(
          title: "Settings",
          icon: "gearshape.fill",
          tag: .settings
        )
      }
    }
  #endif

  // MARK: - Sidebar Layout (macOS)

  #if os(macOS)
    private var sidebarView: some View {
      NavigationSplitView {
        List {
          Label("Map", systemImage: "map.fill")
          Label("Headlines", systemImage: "newspaper.fill")
          Label("Insights", systemImage: "chart.bar.xaxis")
          Label("Settings", systemImage: "gearshape.fill")
        }
        .navigationTitle("Nerve")
      } detail: {
        NerveMapView()
      }
    }
  #endif

  // MARK: - Helpers

  #if os(iOS) || os(visionOS)
    private func placeholderTab(
      title: String,
      icon: String,
      tag: Tab
    ) -> some View {
      VStack(spacing: 16) {
        Image(systemName: icon)
          .font(.system(size: 48))
          .foregroundStyle(.tertiary)
        Text(title)
          .font(.title2)
          .foregroundStyle(.secondary)
        Text("Coming soon")
          .font(.subheadline)
          .foregroundStyle(.tertiary)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .tabItem { Label(title, systemImage: icon) }
      .tag(tag)
    }
  #endif
}

// MARK: - Tab

private enum Tab: Hashable {
  case map, headlines, insights, settings
}

// MARK: - Preview

#Preview {
  ContentView()
}
