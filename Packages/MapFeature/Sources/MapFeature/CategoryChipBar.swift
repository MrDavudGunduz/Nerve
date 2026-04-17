//
//  CategoryChipBar.swift
//  MapFeature
//
//  Created by Davud Gunduz on 14.04.2026.
//

#if os(iOS) || os(visionOS)

  import Core
  import MapKit
  import UIKit

  // MARK: - CategoryChipBar

  /// A horizontally-scrolling row of category filter chips overlaid on the map.
  ///
  /// ## Responsibilities
  ///
  /// - Renders one chip per ``NewsCategory`` plus a special **"All"** chip that
  ///   clears all active filters.
  /// - Calls ``MapViewModel/toggleCategory(_:in:zoomLevel:)`` or
  ///   ``MapViewModel/clearCategoryFilter(in:zoomLevel:)`` when a chip is tapped.
  /// - Reflects the current ``MapViewModel/selectedCategories`` by adjusting
  ///   chip background opacity on each state update.
  ///
  /// ## Region Coupling
  ///
  /// The chip bar never holds a direct reference to `MKMapView`. Instead, it
  /// receives the current region + zoom level through the ``onChipTapped``
  /// closure, which is wired up by `NerveMapView.makeUIView`. This keeps the
  /// chip bar decoupled from its position in the view hierarchy and avoids
  /// fragile `superview as? MKMapView` casts.
  @MainActor
  final class CategoryChipBar: UIScrollView {

    // MARK: - Internal API

    /// Called when the user taps any chip.
    ///
    /// The closure should return the map's current ``GeoRegion`` and zoom level
    /// so that toggling a category immediately re-clusters the visible items.
    /// Return `nil` to cancel the tap (e.g., if the region is temporarily invalid).
    var onChipTapped: (() -> (GeoRegion, Double)?)?

    // MARK: - Private

    private let viewModel: MapViewModel

    private let stack: UIStackView = {
      let s = UIStackView()
      s.axis = .horizontal
      s.spacing = 8
      s.alignment = .center
      return s
    }()

    private var chipButtons: [UIButton] = []

    // MARK: - Init

    /// Creates the chip bar wired to the given view model.
    ///
    /// - Parameter viewModel: The ``MapViewModel`` whose category state is read
    ///   and mutated by chip interactions.
    init(viewModel: MapViewModel) {
      self.viewModel = viewModel
      super.init(frame: .zero)
      showsHorizontalScrollIndicator = false
      showsVerticalScrollIndicator = false
      contentInset = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
      buildChips()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Use init(viewModel:)") }

    // MARK: - Build

    private func buildChips() {
      stack.translatesAutoresizingMaskIntoConstraints = false
      addSubview(stack)
      NSLayoutConstraint.activate([
        stack.topAnchor.constraint(equalTo: topAnchor),
        stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        stack.leadingAnchor.constraint(equalTo: leadingAnchor),
        stack.trailingAnchor.constraint(equalTo: trailingAnchor),
        stack.heightAnchor.constraint(equalTo: heightAnchor),
      ])

      // "All" chip — tag -1 signals the clear-filter action.
      let allChip = makeChip(title: "All", tag: -1)
      stack.addArrangedSubview(allChip)
      chipButtons.append(allChip)

      // One chip per NewsCategory, ordered by CaseIterable.
      for (index, category) in NewsCategory.allCases.enumerated() {
        let chip = makeChip(
          title: category.rawValue.capitalized,
          tag: index,
          color: ClusterAnnotationView.color(for: category)
        )
        stack.addArrangedSubview(chip)
        chipButtons.append(chip)
      }

      updateSelection()
    }

    /// Constructs a single filter chip button with the given display properties.
    ///
    /// - Parameters:
    ///   - title: The chip label.
    ///   - tag: Integer tag used inside `chipTapped(_:)` to identify the chip.
    ///   - color: The chip's accent color (defaults to `.systemGray` for "All").
    private func makeChip(
      title: String,
      tag: Int,
      color: UIColor = .systemGray
    ) -> UIButton {
      var config = UIButton.Configuration.filled()
      config.title = title
      config.baseBackgroundColor = color.withAlphaComponent(0.85)
      config.baseForegroundColor = .white
      config.cornerStyle = .capsule
      config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 14, bottom: 6, trailing: 14)
      config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attrs in
        var a = attrs
        a.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        return a
      }

      let btn = UIButton(configuration: config)
      btn.tag = tag
      btn.layer.shadowColor = UIColor.black.cgColor
      btn.layer.shadowOpacity = 0.15
      btn.layer.shadowRadius = 3
      btn.layer.shadowOffset = CGSize(width: 0, height: 1)
      btn.addTarget(self, action: #selector(chipTapped(_:)), for: .touchUpInside)
      return btn
    }

    // MARK: - Actions

    @objc private func chipTapped(_ sender: UIButton) {
      // Ask the caller for the current region + zoom level via the closure.
      // This removes the fragile `superview as? MKMapView` cast and keeps
      // the chip bar decoupled from its position in the view hierarchy.
      guard let (geoRegion, zoomLevel) = onChipTapped?() else { return }

      if sender.tag == -1 {
        Task { @MainActor [weak self] in
          guard let self else { return }
          await viewModel.clearCategoryFilter(in: geoRegion, zoomLevel: zoomLevel)
          updateSelection()
        }
      } else {
        let category = NewsCategory.allCases[sender.tag]
        Task { @MainActor [weak self] in
          guard let self else { return }
          await viewModel.toggleCategory(category, in: geoRegion, zoomLevel: zoomLevel)
          updateSelection()
        }
      }
    }

    // MARK: - State Sync

    /// Updates chip background colors to reflect the current filter selection.
    ///
    /// Active categories display at full opacity; inactive ones are dimmed.
    /// The "All" chip is highlighted when no category filter is applied.
    func updateSelection() {
      let selected = viewModel.selectedCategories

      for btn in chipButtons {
        if btn.tag == -1 {
          // "All" chip: highlighted when no filter is active.
          let isAll = selected.isEmpty
          var config = btn.configuration
          config?.baseBackgroundColor =
            isAll
            ? UIColor.label.withAlphaComponent(0.85)
            : UIColor.systemGray.withAlphaComponent(0.70)
          btn.configuration = config
        } else {
          let category = NewsCategory.allCases[btn.tag]
          let isActive = selected.contains(category)
          let base = ClusterAnnotationView.color(for: category)
          var config = btn.configuration
          config?.baseBackgroundColor = isActive ? base : base.withAlphaComponent(0.40)
          btn.configuration = config
        }
      }
    }
  }

#endif
