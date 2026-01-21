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
struct EpisodeRatingsGridView: View {
    let episodesBySeason: [Int: [EpisodeMetric]]
    let totalSeasons: Int

    private let cellSize: CGFloat = 58
    private let cellSpacing: CGFloat = 6

    private var maxEpisodes: Int {
        // Find the highest episode number across all seasons (not array count)
        episodesBySeason.values.flatMap { $0 }.map { $0.episodeNumber }.max() ?? 0
    }

    private var seasonNumbers: [Int] {
        Array(1...totalSeasons)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header
            Text("IMDb Scores")
                .font(.system(.headline, weight: .semibold))
                .foregroundStyle(.primary)

            // Legend
            legendView

            // Grid
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: cellSpacing) {
                    // Header row with season numbers
                    headerRow

                    // Episode rows
                    if maxEpisodes > 0 {
                        ForEach(1...maxEpisodes, id: \.self) { episodeNum in
                            episodeRow(episodeNumber: episodeNum)
                        }
                    }

                    // Average row
                    averageRow
                }
                .padding(.horizontal, 4)
            }
        }
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
    }

    // MARK: - Header Row

    private var headerRow: some View {
        HStack(spacing: cellSpacing) {
            // Empty cell for row labels
            Text("")
                .frame(width: 32)

            // Season headers
            ForEach(seasonNumbers, id: \.self) { season in
                Text("S\(season)")
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: cellSize)
            }
        }
    }

    // MARK: - Episode Row

    private func episodeRow(episodeNumber: Int) -> some View {
        HStack(spacing: cellSpacing) {
            // Episode label
            Text("E\(episodeNumber)")
                .font(.system(.caption, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 32, alignment: .leading)

            // Rating cells for each season
            ForEach(seasonNumbers, id: \.self) { season in
                ratingCell(season: season, episodeNumber: episodeNumber)
            }
        }
    }

    // MARK: - Rating Cell

    @ViewBuilder
    private func ratingCell(season: Int, episodeNumber: Int) -> some View {
        let episodes = episodesBySeason[season]
        let episode = episodes?.first { $0.episodeNumber == episodeNumber }

        switch (episodes, episode) {
        case (nil, _):
            // Season data not loaded yet
            placeholderCell(text: "?")

        case (_, let episode?) where episode.hasValidRating:
            // Episode exists with valid rating
            let category = RatingCategory.category(for: episode.rating)
            Text(episode.formattedRating)
                .font(.system(.subheadline, design: .monospaced, weight: .bold))
                .foregroundStyle(category == .good ? .black : .white)
                .frame(width: cellSize, height: 36)
                .background(category.color)
                .clipShape(RoundedRectangle(cornerRadius: 6))

        case (_, let episode?) where !episode.hasValidRating:
            // Episode exists but has N/A rating
            placeholderCell(text: "N/A", font: .caption2)

        default:
            // Episode number doesn't exist for this season (shorter season)
            emptyCell
        }
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

    // MARK: - Average Row

    private var averageRow: some View {
        HStack(spacing: cellSpacing) {
            // Label
            Text("AVG.")
                .font(.system(.caption, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: 32, alignment: .leading)

            // Average for each season
            ForEach(seasonNumbers, id: \.self) { season in
                averageCell(season: season)
            }
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private func averageCell(season: Int) -> some View {
        let validEpisodes = episodesBySeason[season]?.filter { $0.hasValidRating } ?? []

        if validEpisodes.isEmpty {
            emptyAverageCell
        } else {
            let avg = validEpisodes.reduce(0.0) { $0 + $1.rating } / Double(validEpisodes.count)
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
