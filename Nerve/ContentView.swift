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
    @State private var selectedTab: Tab = .map

    private var sidebarView: some View {
      NavigationSplitView {
        List(selection: $selectedTab) {
          Label("Map", systemImage: "map.fill")
            .tag(Tab.map)
          Label("Headlines", systemImage: "newspaper.fill")
            .tag(Tab.headlines)
          Label("Insights", systemImage: "chart.bar.xaxis")
            .tag(Tab.insights)
          Label("Settings", systemImage: "gearshape.fill")
            .tag(Tab.settings)
        }
        .navigationTitle("Nerve")
      } detail: {
        switch selectedTab {
        case .map:
          NerveMapView()
        case .headlines, .insights, .settings:
          VStack(spacing: 16) {
            Image(systemName: tabIcon(for: selectedTab))
              .font(.system(size: 48))
              .foregroundStyle(.tertiary)
            Text(selectedTab.title)
              .font(.title2)
              .foregroundStyle(.secondary)
            Text("Coming soon")
              .font(.subheadline)
              .foregroundStyle(.tertiary)
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }
    }

    private func tabIcon(for tab: Tab) -> String {
      switch tab {
      case .map: "map.fill"
      case .headlines: "newspaper.fill"
      case .insights: "chart.bar.xaxis"
      case .settings: "gearshape.fill"
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

  var title: String {
    switch self {
    case .map: "Map"
    case .headlines: "Headlines"
    case .insights: "Insights"
    case .settings: "Settings"
    }
  }
}

// MARK: - Preview

#Preview {
  ContentView()
}
