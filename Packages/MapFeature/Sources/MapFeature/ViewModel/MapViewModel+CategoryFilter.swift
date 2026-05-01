//
//  MapViewModel+CategoryFilter.swift
//  MapFeature
//
//  Created by Davud Gunduz on 01.05.2026.
//

import Core
import Foundation

// MARK: - MapViewModel + Category Filtering

/// Extension containing category-based item filtering and re-clustering.
///
/// ## Behavior
///
/// - An **empty** `selectedCategories` set means all items are visible.
/// - Toggling a category already in the set **removes** it (deselect).
/// - When the set becomes empty all items are shown automatically.
extension MapViewModel {

  /// Toggles a category in the active filter set and immediately re-clusters.
  ///
  /// Selecting a category already in the set **removes** it (deselect).
  /// Selecting a category not in the set **adds** it.
  /// When the set becomes empty all items are shown.
  ///
  /// - Parameters:
  ///   - category: The category to toggle.
  ///   - region: The current visible region (needed for re-clustering).
  ///   - zoomLevel: The current zoom level.
  public func toggleCategory(
    _ category: NewsCategory,
    in region: GeoRegion,
    zoomLevel: Double
  ) async {
    if selectedCategories.contains(category) {
      selectedCategories.remove(category)
    } else {
      selectedCategories.insert(category)
    }
    await updateClusters(with: filteredItems, in: region, zoomLevel: zoomLevel)
  }

  /// Clears all category filters and shows all items.
  public func clearCategoryFilter(in region: GeoRegion, zoomLevel: Double) async {
    guard !selectedCategories.isEmpty else { return }
    selectedCategories.removeAll()
    await updateClusters(with: filteredItems, in: region, zoomLevel: zoomLevel)
  }
}
