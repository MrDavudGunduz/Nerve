//
//  NewsDetailSheet.swift
//  MapFeature
//
//  Created by Davud Gunduz on 12.04.2026.
//

#if canImport(UIKit)

  import Core
  import UIKit

  // MARK: - NewsDetailSheet

  /// A native iOS bottom sheet presenting the detail of a single news item or cluster.
  ///
  /// ## Presentation
  ///
  /// Present modally via `UISheetPresentationController`:
  ///
  /// ```swift
  /// let sheet = NewsDetailSheet(cluster: cluster)
  /// sheet.modalPresentationStyle = .pageSheet
  /// if let sheetController = sheet.sheetPresentationController {
  ///     sheetController.detents = [.medium(), .large()]
  ///     sheetController.prefersGrabberVisible = true
  /// }
  /// present(sheet, animated: true)
  /// ```
  ///
  /// ## Layout
  ///
  /// ```
  /// ┌─────────────────────────────┐
  /// │  ⎯  grabber                 │
  /// │  [Category icon]            │
  /// │  Headline (bold, 2 lines)   │
  /// │  Source  •  Date            │
  /// │  [Credibility chip]         │
  /// │  ─────────────────          │
  /// │  Sentiment  ●●●●○  Score   │
  /// │  [Habere Git ↗]            │
  /// └─────────────────────────────┘
  /// ```
  @MainActor
  public final class NewsDetailSheet: UIViewController {

    // MARK: - Data

    private let cluster: NewsCluster

    // MARK: - Subviews

    private let scrollView = UIScrollView()
    private let stackView: UIStackView = {
      let stack = UIStackView()
      stack.axis = .vertical
      stack.spacing = 12
      stack.alignment = .fill
      return stack
    }()

    private let iconContainer: UIView = {
      let view = UIView()
      view.layer.cornerRadius = 28
      view.layer.masksToBounds = true
      return view
    }()

    private let iconImageView: UIImageView = {
      let iv = UIImageView()
      iv.contentMode = .scaleAspectFit
      iv.tintColor = .white
      return iv
    }()

    private let headlineLabel: UILabel = {
      let label = UILabel()
      label.font = .preferredFont(forTextStyle: .headline)
      label.adjustsFontForContentSizeCategory = true
      label.numberOfLines = 3
      label.textColor = .label
      label.accessibilityIdentifier = "newsDetailHeadline"
      return label
    }()

    private let metaLabel: UILabel = {
      let label = UILabel()
      label.font = .preferredFont(forTextStyle: .caption1)
      label.adjustsFontForContentSizeCategory = true
      label.textColor = .secondaryLabel
      label.accessibilityIdentifier = "newsDetailMeta"
      return label
    }()

    private let credibilityChip: UIView = {
      let view = UIView()
      view.layer.cornerRadius = 10
      view.layer.masksToBounds = true
      return view
    }()

    private let credibilityLabel: UILabel = {
      let label = UILabel()
      label.font = .preferredFont(forTextStyle: .caption2)
      label.adjustsFontForContentSizeCategory = true
      label.textColor = .white
      label.textAlignment = .center
      label.accessibilityIdentifier = "newsDetailCredibility"
      return label
    }()

    private let separatorView: UIView = {
      let view = UIView()
      view.backgroundColor = .separator
      return view
    }()

    private let analysisStack: UIStackView = {
      let stack = UIStackView()
      stack.axis = .vertical
      stack.spacing = 8
      return stack
    }()

    private let openButton: UIButton = {
      var config = UIButton.Configuration.filled()
      config.title = "Read Article"
      config.image = UIImage(systemName: "arrow.up.right")
      config.imagePlacement = .trailing
      config.imagePadding = 6
      config.baseBackgroundColor = .systemBlue
      config.baseForegroundColor = .white
      config.cornerStyle = .large
      let btn = UIButton(configuration: config)
      btn.accessibilityIdentifier = "newsDetailOpenButton"
      btn.accessibilityHint = "Opens the full article in browser"
      return btn
    }()

    // MARK: - Init

    /// Creates a detail sheet for the given news cluster.
    ///
    /// - Parameter cluster: The ``NewsCluster`` to display. For multi-item
    ///   clusters the representative headline and dominant category are shown.
    public init(cluster: NewsCluster) {
      self.cluster = cluster
      super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    // MARK: - Lifecycle

    public override func viewDidLoad() {
      super.viewDidLoad()
      view.backgroundColor = .systemBackground
      buildLayout()
      populate()
    }

    // MARK: - Layout

    private func buildLayout() {
      // Scroll
      scrollView.translatesAutoresizingMaskIntoConstraints = false
      view.addSubview(scrollView)
      NSLayoutConstraint.activate([
        scrollView.topAnchor.constraint(equalTo: view.topAnchor),
        scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
        scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      ])

      // Stack inside scroll
      stackView.translatesAutoresizingMaskIntoConstraints = false
      scrollView.addSubview(stackView)
      NSLayoutConstraint.activate([
        stackView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 24),
        stackView.leadingAnchor.constraint(
          equalTo: scrollView.leadingAnchor, constant: 20),
        stackView.trailingAnchor.constraint(
          equalTo: scrollView.trailingAnchor, constant: -20),
        stackView.bottomAnchor.constraint(
          equalTo: scrollView.bottomAnchor, constant: -32),
        stackView.widthAnchor.constraint(
          equalTo: scrollView.widthAnchor, constant: -40),
      ])

      // Category icon circle
      iconContainer.translatesAutoresizingMaskIntoConstraints = false
      iconContainer.frame = CGRect(x: 0, y: 0, width: 56, height: 56)
      iconImageView.translatesAutoresizingMaskIntoConstraints = false
      iconContainer.addSubview(iconImageView)
      NSLayoutConstraint.activate([
        iconContainer.widthAnchor.constraint(equalToConstant: 56),
        iconContainer.heightAnchor.constraint(equalToConstant: 56),
        iconImageView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
        iconImageView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
        iconImageView.widthAnchor.constraint(equalToConstant: 28),
        iconImageView.heightAnchor.constraint(equalToConstant: 28),
      ])

      // Credibility chip
      credibilityChip.addSubview(credibilityLabel)
      credibilityLabel.translatesAutoresizingMaskIntoConstraints = false
      credibilityChip.translatesAutoresizingMaskIntoConstraints = false
      NSLayoutConstraint.activate([
        credibilityLabel.topAnchor.constraint(
          equalTo: credibilityChip.topAnchor, constant: 4),
        credibilityLabel.bottomAnchor.constraint(
          equalTo: credibilityChip.bottomAnchor, constant: -4),
        credibilityLabel.leadingAnchor.constraint(
          equalTo: credibilityChip.leadingAnchor, constant: 12),
        credibilityLabel.trailingAnchor.constraint(
          equalTo: credibilityChip.trailingAnchor, constant: -12),
      ])

      // Chip wrapper (left-aligned)
      let chipWrapper = UIView()
      chipWrapper.addSubview(credibilityChip)
      credibilityChip.translatesAutoresizingMaskIntoConstraints = false
      NSLayoutConstraint.activate([
        credibilityChip.topAnchor.constraint(equalTo: chipWrapper.topAnchor),
        credibilityChip.bottomAnchor.constraint(equalTo: chipWrapper.bottomAnchor),
        credibilityChip.leadingAnchor.constraint(equalTo: chipWrapper.leadingAnchor),
      ])

      // Separator
      separatorView.translatesAutoresizingMaskIntoConstraints = false
      separatorView.heightAnchor.constraint(equalToConstant: 1).isActive = true

      // Button
      openButton.translatesAutoresizingMaskIntoConstraints = false
      openButton.heightAnchor.constraint(equalToConstant: 50).isActive = true
      openButton.addTarget(self, action: #selector(openArticle), for: .touchUpInside)

      // Assemble
      stackView.addArrangedSubview(iconContainer)
      stackView.addArrangedSubview(headlineLabel)
      stackView.addArrangedSubview(metaLabel)
      stackView.addArrangedSubview(chipWrapper)
      stackView.addArrangedSubview(separatorView)
      stackView.addArrangedSubview(analysisStack)
      stackView.addArrangedSubview(openButton)
    }

    // MARK: - Population

    private func populate() {
      guard let item = cluster.items.first else { return }

      // Category
      iconContainer.backgroundColor = ClusterAnnotationView.color(for: item.category)
      iconImageView.image = NewsAnnotationView.icon(for: item.category)

      // Headline
      headlineLabel.text = cluster.representativeHeadline

      // Meta
      let dateText = item.publishedAt.formatted(.relative(presentation: .named))
      metaLabel.text = "\(item.source)  •  \(dateText)"

      // Credibility chip
      if let credibility = cluster.averageCredibilityLabel {
        credibilityChip.backgroundColor = ClusterAnnotationView.credibilityColor(
          for: credibility)
        credibilityLabel.text = credibility.rawValue.uppercased()
      } else {
        credibilityChip.isHidden = true
      }

      // Analysis detail (only for single items with a score)
      if let analysis = item.analysis {
        analysisStack.isHidden = false
        buildAnalysisRows(analysis: analysis)
      } else {
        analysisStack.isHidden = true
      }

      // CTA button
      openButton.isHidden = item.articleURL == nil
    }

    /// Builds sentiment + clickbait score rows inside `analysisStack`.
    private func buildAnalysisRows(analysis: HeadlineAnalysis) {
      // Sentiment row
      let sentimentRow = makeRowLabel(
        title: "Sentiment",
        value: analysis.sentiment.rawValue.capitalized
      )
      analysisStack.addArrangedSubview(sentimentRow)

      // Clickbait score row
      let scorePercent = Int(analysis.clickbaitScore * 100)
      let scoreRow = makeRowLabel(
        title: "Clickbait Score",
        value: "\(scorePercent)%"
      )
      analysisStack.addArrangedSubview(scoreRow)

      // Progress bar
      let progressBar = CredibilityProgressBar(score: analysis.clickbaitScore)
      progressBar.translatesAutoresizingMaskIntoConstraints = false
      progressBar.heightAnchor.constraint(equalToConstant: 6).isActive = true
      analysisStack.addArrangedSubview(progressBar)

      // Confidence
      let confPercent = Int(analysis.confidence * 100)
      let confRow = makeRowLabel(
        title: "Confidence",
        value: "\(confPercent)%"
      )
      analysisStack.addArrangedSubview(confRow)
    }

    private func makeRowLabel(title: String, value: String) -> UIView {
      let container = UIView()
      let titleLabel = UILabel()
      titleLabel.text = title
      titleLabel.font = .systemFont(ofSize: 14)
      titleLabel.textColor = .secondaryLabel

      let valueLabel = UILabel()
      valueLabel.text = value
      valueLabel.font = .systemFont(ofSize: 14, weight: .medium)
      valueLabel.textColor = .label
      valueLabel.textAlignment = .right

      [titleLabel, valueLabel].forEach {
        $0.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview($0)
      }

      NSLayoutConstraint.activate([
        titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
        titleLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        valueLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        valueLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        titleLabel.trailingAnchor.constraint(
          lessThanOrEqualTo: valueLabel.leadingAnchor, constant: -8),
        container.heightAnchor.constraint(equalToConstant: 24),
      ])
      return container
    }

    // MARK: - Actions

    @objc private func openArticle() {
      guard let url = cluster.items.first?.articleURL else { return }
      UIApplication.shared.open(url)
    }
  }

  // MARK: - CredibilityProgressBar

  /// A thin horizontal bar that fills left-to-right according to a clickbait score.
  ///
  /// Color transitions from green (genuine) to red (clickbait) following
  /// the same thresholds as ``Core/HeadlineAnalysis/credibilityLabel``.
  private final class CredibilityProgressBar: UIView {

    private let fillLayer = CALayer()

    init(score: Double) {
      super.init(frame: .zero)
      backgroundColor = .systemGray5
      layer.cornerRadius = 3
      layer.masksToBounds = true

      fillLayer.cornerRadius = 3
      fillLayer.backgroundColor = colorForScore(score).cgColor
      layer.addSublayer(fillLayer)

      // Store score for layoutSubviews
      self.score = score
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private var score: Double = 0

    override func layoutSubviews() {
      super.layoutSubviews()
      let fillWidth = bounds.width * CGFloat(score)
      fillLayer.frame = CGRect(x: 0, y: 0, width: fillWidth, height: bounds.height)
    }

    private func colorForScore(_ score: Double) -> UIColor {
      switch score {
      case ..<0.3: return ClusterAnnotationView.credibilityColor(for: .verified)
      case 0.3..<0.7: return ClusterAnnotationView.credibilityColor(for: .caution)
      default: return ClusterAnnotationView.credibilityColor(for: .clickbait)
      }
    }
  }

#endif
