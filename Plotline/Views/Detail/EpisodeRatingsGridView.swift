import SwiftUI

/// Rating category for color coding
enum RatingCategory: String, CaseIterable {
    case awesome = "Awesome"
    case great = "Great"
    case good = "Good"
    case regular = "Regular"
    case bad = "Bad"
    case garbage = "Garbage"

    var color: Color {
        switch self {
        case .awesome: return .ratingAwesome
        case .great: return .ratingGreat
        case .good: return .ratingGood
        case .regular: return .ratingRegular
        case .bad: return .ratingBad
        case .garbage: return .ratingGarbage
        }
    }

    static func category(for rating: Double) -> RatingCategory {
        switch rating {
        case 9.0...: return .awesome
        case 8.0..<9.0: return .great
        case 7.0..<8.0: return .good
        case 6.0..<7.0: return .regular
        case 5.0..<6.0: return .bad
        default: return .garbage
        }
    }
}

/// Grid view showing episode ratings across all seasons
///
/// Laid out a season per column so the columns can be lazy: a long-running
/// series has dozens of seasons, and only the ones scrolled into view are
/// built. Episode labels sit in a fixed column outside the horizontal scroll,
/// so they stay put while the seasons move.
struct EpisodeRatingsGridView: View {
    let episodesBySeason: [Int: [EpisodeMetric]]
    let totalSeasons: Int

    private let cellSize: CGFloat = 58
    private let cellSpacing: CGFloat = 6
    private let cellHeight: CGFloat = 36
    @ScaledMetric(relativeTo: .caption) private var headerHeight: CGFloat = 20
    private let labelWidth: CGFloat = 32

    /// Derived once here rather than on every body pass: the highest episode
    /// number was a `flatMap` over every episode, and each cell's lookup was
    /// a linear search of its season.
    private let lookup: [Int: [Int: EpisodeMetric]]
    private let maxEpisodes: Int
    private let seasonNumbers: [Int]
    private let seasonAverages: [Int: Double]
    private let standouts: StandoutIndex

    /// - Parameter standouts: the analysis's season highs and lows, outlined
    ///   in the grid so they match the list in "What the Numbers Say".
    /// - Parameter seasonAverages: each season's average as the verdicts
    ///   define it (see `MediaDetailViewModel.seasonAverages(asOf:)`). When
    ///   omitted, computed with the engine's own definition, so the AVG row
    ///   never means something different from the verdicts above it.
    init(
        episodesBySeason: [Int: [EpisodeMetric]],
        totalSeasons: Int,
        seasonAverages: [Int: Double]? = nil,
        standouts: StandoutIndex = .empty
    ) {
        self.episodesBySeason = episodesBySeason
        self.totalSeasons = totalSeasons
        self.standouts = standouts

        let lookup = episodesBySeason.mapValues { episodes in
            // First wins, as the linear `first { }` it replaces did.
            Dictionary(episodes.map { ($0.episodeNumber, $0) }, uniquingKeysWith: { first, _ in first })
        }
        self.lookup = lookup
        // The highest episode number across all seasons, not the array count.
        self.maxEpisodes = lookup.values.compactMap { $0.keys.max() }.max() ?? 0

        // `1...0` traps, and a season that loaded is shown even when the
        // detail payload's count lags behind it.
        let listed = totalSeasons > 0 ? Array(1...totalSeasons) : []
        self.seasonNumbers = Set(listed).union(episodesBySeason.keys.filter { $0 > 0 }).sorted()

        self.seasonAverages = seasonAverages
            ?? episodesBySeason.compactMapValues { SeriesAnalysisEngine.seasonAverage(of: $0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header
            Text("Episode Scores")
                .font(.system(.headline, weight: .semibold))
                .foregroundStyle(.primary)

            // Legend
            legendView

            if !standouts.isEmpty {
                StandoutLegend()
            }

            // Grid
            HStack(alignment: .top, spacing: cellSpacing) {
                labelColumn

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: cellSpacing) {
                        ForEach(seasonNumbers, id: \.self) { season in
                            seasonColumn(season)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }

            Text("AVG. weights each episode by its votes and leaves out episodes with fewer than \(SeriesAnalysisEngine.minimumVotesPerEpisode), as the verdicts above do.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Episode ratings grid, \(seasonNumbers.count) seasons, \(maxEpisodes) episodes per season maximum")
    }

    // MARK: - Legend

    private var legendView: some View {
        HStack(spacing: 12) {
            ForEach(RatingCategory.allCases, id: \.self) { category in
                HStack(spacing: 4) {
                    Circle()
                        .fill(category.color)
                        .frame(width: 8, height: 8)
                    Text(category.rawValue)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Rating legend: " + RatingCategory.allCases.map { "\($0.rawValue)" }.joined(separator: ", "))
    }

    // MARK: - Label Column

    /// Episode labels and the AVG label, row for row with the season columns.
    private var labelColumn: some View {
        VStack(alignment: .leading, spacing: cellSpacing) {
            Color.clear
                .frame(width: labelWidth, height: headerHeight)

            if maxEpisodes > 0 {
                ForEach(1...maxEpisodes, id: \.self) { episodeNumber in
                    Text("E\(episodeNumber)")
                        .font(.system(.caption, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: labelWidth, height: cellHeight, alignment: .leading)
                }
            }

            Text("AVG.")
                .font(.system(.caption, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: labelWidth, height: cellHeight, alignment: .leading)
                .padding(.top, 4)
        }
        .padding(.leading, 4)
        .accessibilityHidden(true)
    }

    // MARK: - Season Column

    private func seasonColumn(_ season: Int) -> some View {
        VStack(spacing: cellSpacing) {
            Text("S\(season)")
                .font(.system(.caption, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: cellSize, height: headerHeight)

            if maxEpisodes > 0 {
                ForEach(1...maxEpisodes, id: \.self) { episodeNumber in
                    ratingCell(season: season, episodeNumber: episodeNumber)
                }
            }

            averageCell(season: season)
                .frame(height: cellHeight)
                .padding(.top, 4)
        }
    }

    // MARK: - Rating Cell

    @ViewBuilder
    private func ratingCell(season: Int, episodeNumber: Int) -> some View {
        let episodes = lookup[season]
        let episode = episodes?[episodeNumber]

        if episodes == nil {
            // Season data not loaded yet
            placeholderCell(text: "?")
                .accessibilityLabel("Season \(season), Episode \(episodeNumber), rating not yet loaded")
        } else if let episode, episode.hasValidRating {
            // Episode exists with valid rating
            let category = RatingCategory.category(for: episode.rating)
            Text(episode.formattedRating)
                .font(.system(.subheadline, design: .monospaced, weight: .bold))
                .foregroundStyle(category == .garbage ? .white : .black)
                .frame(width: cellSize, height: 36)
                .background(category.color)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay { standoutMarker(season: season, episodeNumber: episodeNumber) }
                .accessibilityLabel(ratingCellLabel(season: season, episodeNumber: episodeNumber, episode: episode, category: category))
        } else if let episode, !episode.hasValidRating {
            // Episode exists but has N/A rating
            placeholderCell(text: "N/A", font: .caption2)
                .accessibilityLabel("Season \(season), Episode \(episodeNumber), no rating available")
        } else {
            // Episode number doesn't exist for this season (shorter season)
            emptyCell
        }
    }

    /// Outline plus a corner glyph on a season high or low. The glyph carries
    /// the direction so the marker never depends on colour alone, and sits on
    /// a card-coloured badge so it reads over every rating colour in both
    /// appearances.
    @ViewBuilder
    private func standoutMarker(season: Int, episodeNumber: Int) -> some View {
        if let direction = standouts.direction(season: season, episode: episodeNumber) {
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Color.primary, lineWidth: 2)
                .overlay(alignment: .topTrailing) {
                    Image(systemName: direction.symbolName)
                        .font(.system(size: 6, weight: .bold))
                        .foregroundStyle(.primary)
                        .frame(width: 12, height: 12)
                        .background(Circle().fill(Color.plotlineCard))
                        .offset(x: 3, y: -3)
                }
                .accessibilityHidden(true)
        }
    }

    private func ratingCellLabel(
        season: Int,
        episodeNumber: Int,
        episode: EpisodeMetric,
        category: RatingCategory
    ) -> String {
        var label = "Season \(season), Episode \(episodeNumber), rating \(episode.formattedRating), \(category.rawValue)"
        if let direction = standouts.direction(season: season, episode: episodeNumber) {
            label += ", \(direction.accessibilityPhrase)"
        }
        return label
    }

    private var emptyCell: some View {
        Color.clear
            .frame(width: cellSize, height: 36)
    }

    private func placeholderCell(text: String, font: Font.TextStyle = .subheadline) -> some View {
        Text(text)
            .font(.system(font, design: .monospaced, weight: .bold))
            .foregroundStyle(.secondary)
            .frame(width: cellSize, height: 36)
            .background(Color.plotlineCard)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Average

    @ViewBuilder
    private func averageCell(season: Int) -> some View {
        if let avg = seasonAverages[season] {
            let category = RatingCategory.category(for: avg)

            VStack(spacing: 2) {
                Text(String(format: "%.1f", avg))
                    .font(.system(.subheadline, design: .monospaced, weight: .bold))
                    .foregroundStyle(.primary)

                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(category.color)
                        .frame(width: geo.size.width * (avg / 10.0))
                }
                .frame(height: 4)
            }
            .frame(width: cellSize)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Season \(season) average: \(String(format: "%.1f", avg)), \(category.rawValue)")
        } else {
            // No episode in the season has enough votes to average.
            emptyAverageCell
        }
    }

    private var emptyAverageCell: some View {
        Text("-")
            .font(.system(.subheadline, design: .monospaced))
            .foregroundStyle(.secondary)
            .frame(width: cellSize)
    }
}

// MARK: - Preview

#Preview("Episode Ratings Grid") {
    let episodesBySeason: [Int: [EpisodeMetric]] = [
        1: EpisodeMetric.breakingBadS1,
        5: EpisodeMetric.breakingBadS5
    ]

    return ZStack {
        Color.plotlineBackground.ignoresSafeArea()
        EpisodeRatingsGridView(
            episodesBySeason: episodesBySeason,
            totalSeasons: 5
        )
        .padding()
    }
    .preferredColorScheme(.dark)
}
