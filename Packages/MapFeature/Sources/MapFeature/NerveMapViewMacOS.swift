//
//  NerveMapViewMacOS.swift
//  MapFeature
//
//  Created by Davud Gunduz on 28.04.2026.
//

#if os(macOS)

  import Core
  import CoreLocation
  import MapKit
  import Observation
  import SwiftUI

  // MARK: - NerveMapView (macOS)

  /// macOS-native map view using the SwiftUI `Map` API.
  ///
  /// This is the macOS counterpart of the iOS `NerveMapView` (which uses
  /// `UIViewRepresentable` + `MKMapView`). On macOS, `UIKit` is unavailable,
  /// so we use SwiftUI's declarative `Map` with `Annotation` markers instead.
  ///
  /// ## Feature Parity
  ///
  /// The macOS variant provides:
  /// - News cluster annotations with category-colored markers
  /// - User location tracking (via ``LocationServiceFactory``)
  /// - Region-change driven news loading
  /// - Category filter chip bar (SwiftUI-native)
  /// - Detail popover on annotation selection
  ///
  /// UIKit-specific features (custom `MKAnnotationView`, skeleton loading,
  /// pulse ring overlay) are omitted and will be revisited in a future
  /// AppKit/MapKit integration sprint.
  public struct NerveMapView: View {

    // MARK: - State

    @State private var viewModel: MapViewModel
    @State private var cameraPosition: MapCameraPosition = .region(Self.fallbackRegion)
    @State private var selectedCluster: NewsCluster?

    /// Istanbul fallback region — matches the iOS counterpart.
    private static let fallbackRegion = MKCoordinateRegion(
      center: CLLocationCoordinate2D(latitude: 41.0082, longitude: 28.9784),
      latitudinalMeters: 50_000,
      longitudinalMeters: 50_000
    )

    // MARK: - Init

    /// Creates a map view backed by the given view model.
    ///
    /// - Parameter viewModel: The ``MapViewModel`` to observe.
    ///   Defaults to a preview-safe instance with stub services.
    public init(viewModel: MapViewModel = MapViewModel()) {
      _viewModel = State(initialValue: viewModel)
    }

    // MARK: - Body

    public var body: some View {
      ZStack(alignment: .top) {
        mapContent

        // ── Category Filter Chips ──
        categoryChipBar
          .padding(.top, 8)

        // ── Loading Indicator ──
        if viewModel.isLoading {
          ProgressView()
            .controlSize(.small)
            .padding(8)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 52)
        }

        // ── Error Banner ──
        if let error = viewModel.error {
          errorBanner(message: error.errorDescription ?? "An error occurred.")
        }
      }
      .task {
        await viewModel.startLocationTracking()
        if let userCoord = viewModel.userLocation {
          cameraPosition = .region(
            MKCoordinateRegion(
              center: CLLocationCoordinate2D(
                latitude: userCoord.latitude,
                longitude: userCoord.longitude
              ),
              latitudinalMeters: 50_000,
              longitudinalMeters: 50_000
            )
          )
        }
        // Initial load with fallback region
        if let initialRegion = GeoRegion(
          center: GeoCoordinate(latitude: 41.0082, longitude: 28.9784)!,
          radiusMeters: 25_000
        ) {
          await viewModel.loadNews(for: initialRegion, zoomLevel: 12)
        }
      }
      .sheet(item: $selectedCluster) { cluster in
        clusterDetailSheet(cluster: cluster)
      }
    }

    // MARK: - Map Content

    @ViewBuilder
    private var mapContent: some View {
      Map(position: $cameraPosition) {
        // User location
        UserAnnotation()

        // News cluster annotations
        ForEach(viewModel.clusters) { cluster in
          Annotation(
            cluster.representativeHeadline,
            coordinate: CLLocationCoordinate2D(
              latitude: cluster.center.latitude,
              longitude: cluster.center.longitude
            )
          ) {
            clusterMarker(for: cluster)
              .onTapGesture {
                selectedCluster = cluster
              }
          }
        }
      }
      .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
      .mapControls {
        MapCompass()
        MapScaleView()
        MapZoomStepper()
      }
      .onMapCameraChange(frequency: .onEnd) { context in
        let region = context.region
        guard
          let center = GeoCoordinate(
            latitude: region.center.latitude,
            longitude: region.center.longitude
          ),
          let geoRegion = GeoRegion(
            center: center,
            radiusMeters: region.span.latitudeDelta * 111_000 / 2
          )
        else { return }
        let zoomLevel = region.approximateZoomLevel
        Task {
          await viewModel.loadNews(for: geoRegion, zoomLevel: zoomLevel)
        }
      }
    }

    // MARK: - Cluster Marker

    @ViewBuilder
    private func clusterMarker(for cluster: NewsCluster) -> some View {
      if cluster.isCluster {
        // Multi-item cluster bubble
        ZStack {
          Circle()
            .fill(categoryColor(for: cluster.dominantCategory).gradient)
            .frame(width: 36, height: 36)
            .shadow(
              color: categoryColor(for: cluster.dominantCategory).opacity(0.3),
              radius: 4, y: 2
            )

          Text("\(cluster.count)")
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
        }
      } else {
        // Single news pin
        VStack(spacing: 0) {
          ZStack {
            RoundedRectangle(cornerRadius: 6)
              .fill(categoryColor(for: cluster.dominantCategory).gradient)
              .frame(width: 28, height: 28)
              .shadow(color: .black.opacity(0.15), radius: 3, y: 2)

            Image(systemName: categoryIcon(for: cluster.dominantCategory))
              .font(.system(size: 13, weight: .semibold))
              .foregroundStyle(.white)
          }

          // Pin tail
          Triangle()
            .fill(categoryColor(for: cluster.dominantCategory))
            .frame(width: 10, height: 6)
        }
      }
    }

    // MARK: - Category Chip Bar

    private var categoryChipBar: some View {
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 8) {
          ForEach(NewsCategory.allCases, id: \.self) { category in
            Button {
              Task {
                let region = currentGeoRegion
                await viewModel.toggleCategory(category, in: region, zoomLevel: 12)
              }
            } label: {
              HStack(spacing: 4) {
                Image(systemName: categoryIcon(for: category))
                  .font(.system(size: 11))
                Text(category.rawValue.capitalized)
                  .font(.system(size: 12, weight: .medium))
              }
              .padding(.horizontal, 10)
              .padding(.vertical, 6)
              .background(
                viewModel.selectedCategories.contains(category)
                  ? categoryColor(for: category)
                  : Color(nsColor: .windowBackgroundColor).opacity(0.8)
              )
              .foregroundStyle(
                viewModel.selectedCategories.contains(category)
                  ? .white
                  : .primary
              )
              .clipShape(Capsule())
              .overlay(
                Capsule()
                  .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
              )
            }
            .buttonStyle(.plain)
          }
        }
        .padding(.horizontal, 12)
      }
      .frame(height: 36)
      .background(.ultraThinMaterial)
    }

    // MARK: - Error Banner

    private func errorBanner(message: String) -> some View {
      HStack(spacing: 8) {
        Image(systemName: "exclamationmark.triangle.fill")
          .foregroundStyle(.yellow)
        Text(message)
          .font(.callout)
          .lineLimit(2)
      }
      .padding(12)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
      .padding(.horizontal, 16)
      .padding(.top, 52)
      .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Detail Sheet

    private func clusterDetailSheet(cluster: NewsCluster) -> some View {
      VStack(alignment: .leading, spacing: 16) {
        // Header
        HStack {
          Image(systemName: categoryIcon(for: cluster.dominantCategory))
            .font(.title2)
            .foregroundStyle(categoryColor(for: cluster.dominantCategory))

          VStack(alignment: .leading) {
            Text(cluster.representativeHeadline)
              .font(.headline)
            Text(
              "\(cluster.count) \(cluster.count == 1 ? "story" : "stories") · \(cluster.dominantCategory.rawValue.capitalized)"
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
          }

          Spacer()
        }

        Divider()

        // Items list
        ScrollView {
          LazyVStack(alignment: .leading, spacing: 12) {
            ForEach(cluster.items, id: \.id) { item in
              VStack(alignment: .leading, spacing: 4) {
                Text(item.headline)
                  .font(.body)
                  .fontWeight(.medium)
                HStack {
                  Text(item.source)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                  if let analysis = item.analysis {
                    Spacer()
                    credibilityBadge(for: analysis)
                  }
                }
              }
              .padding(.vertical, 4)
            }
          }
        }
      }
      .padding(20)
      .frame(minWidth: 400, minHeight: 300)
    }

    // MARK: - Credibility Badge

    private func credibilityBadge(for analysis: HeadlineAnalysis) -> some View {
      let label = analysis.credibilityLabel
      let isVerified = label == .verified

      return HStack(spacing: 3) {
        Image(systemName: isVerified ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
          .font(.caption2)
        Text(label.rawValue)
          .font(.caption2)
      }
      .foregroundStyle(isVerified ? .green : .orange)
      .padding(.horizontal, 6)
      .padding(.vertical, 2)
      .background(
        (isVerified ? Color.green : Color.orange).opacity(0.1),
        in: Capsule()
      )
    }

    // MARK: - Helpers

    private var currentGeoRegion: GeoRegion {
      // Use fallback region values as default
      GeoRegion(
        center: GeoCoordinate(latitude: 41.0082, longitude: 28.9784)!,
        radiusMeters: 25_000
      )!
    }

    private func categoryColor(for category: NewsCategory) -> Color {
      switch category {
      case .politics:
        .blue
      case .business:
        .green
      case .technology:
        .purple
      case .health:
        .red
      case .sports:
        .orange
      case .entertainment:
        .pink
      case .science:
        .cyan
      case .environment:
        .teal
      case .other:
        .gray
      }
    }

    private func categoryIcon(for category: NewsCategory) -> String {
      switch category {
      case .politics:
        "building.columns.fill"
      case .business:
        "chart.line.uptrend.xyaxis"
      case .technology:
        "cpu.fill"
      case .health:
        "heart.fill"
      case .sports:
        "sportscourt.fill"
      case .entertainment:
        "film.fill"
      case .science:
        "atom"
      case .environment:
        "leaf.fill"
      case .other:
        "newspaper.fill"
      }
    }
  }

  // MARK: - Triangle Shape

  /// Simple downward-pointing triangle for pin tails.
  private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
      Path { path in
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
      }
    }
  }

  // MARK: - Preview

  #Preview {
    NerveMapView()
      .frame(width: 800, height: 600)
  }

#endif
