//
//  MapViewModelStateTests.swift
//  MapFeatureTests
//
//  Tests for MapViewModel's published state lifecycle — initial values,
//  reset semantics, and no-op safety guards.
//

import Core
import Testing

@testable import MapFeature

@Suite("MapViewModel State Lifecycle Tests")
@MainActor
struct MapViewModelStateTests {

  private var region: GeoRegion {
    GeoRegion(
      center: GeoCoordinate(latitude: 41, longitude: 29)!,
      radiusMeters: 50_000
    )!
  }

  // MARK: Initial State

  @Test("isLoading is false on initialisation")
  func initialLoadingFalse() {
    #expect(!MapViewModel().isLoading)
  }

  @Test("clusters is empty on initialisation")
  func initialClustersEmpty() {
    #expect(MapViewModel().clusters.isEmpty)
  }

  @Test("userLocation is nil on initialisation")
  func initialUserLocationNil() {
    #expect(MapViewModel().userLocation == nil)
  }

  @Test("error is nil on initialisation")
  func initialErrorNil() {
    #expect(MapViewModel().error == nil)
  }

  // MARK: Protocol Conformance / DI

  @Test("AnnotationClusterer resolves via DependencyContainer")
  func diRoundTrip() async throws {
    let container = DependencyContainer()
    await container.register(ClusteringServiceProtocol.self) {
      AnnotationClusterer()
    }
    let service = try await container.resolve(ClusteringServiceProtocol.self)
    let region = GeoRegion(
      center: GeoCoordinate(latitude: 41, longitude: 29)!, radiusMeters: 10_000)!
    let clusters = try await service.cluster(items: [], in: region, zoomLevel: 10)
    #expect(clusters.isEmpty)
  }

  // MARK: Reset

  @Test("reset clears all published state including the category filter")
  func resetClearsAll() async {
    let vm = MapViewModel()
    await vm.toggleCategory(.technology, in: region, zoomLevel: 10)
    vm.reset()
    #expect(vm.clusters.isEmpty)
    #expect(vm.error == nil)
    #expect(!vm.isLoading)
  }

  // MARK: Guards

  @Test("recluster on empty allItems is a no-op and does not crash")
  func reclusterEmptyNoCrash() async {
    let vm = MapViewModel()
    await vm.recluster(in: region, zoomLevel: 10)
    #expect(vm.clusters.isEmpty)
  }
}
