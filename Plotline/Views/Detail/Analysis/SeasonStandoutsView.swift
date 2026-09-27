import SwiftUI

/// Which side of its season's average a standout episode sits on.
enum StandoutDirection: Hashable {
    case high
    case low

    /// A glyph that tells the two apart without relying on colour.
    var symbolName: String {
        switch self {
        case .high: "arrowtriangle.up.fill"
        case .low: "arrowtriangle.down.fill"
        }
    }

    /// What the marker means, as far as the engine's predicate goes: a
    /// position relative to the season's average, nothing about whether the
    /// episode is worth watching.
    var legend: String {
        switch self {
        case .high: "Well above its season's average"
        case .low: "Well below its season's average"
        }
    }

    /// Appended to an episode's accessibility label.
    var accessibilityPhrase: String {
        switch self {
        case .high: "well above its season's average"
        case .low: "well below its season's average"
        }
    }
}

/// The engine's standout episodes, indexed for the chart and the grid.
///
/// Built from the analysis on screen, so the markers and the list in "What the
/// Numbers Say" always name the same episodes.
struct StandoutIndex: Equatable {
    private let directions: [Int: [Int: StandoutDirection]]

    init(analysis: SeriesAnalysis?) {
        var directions: [Int: [Int: StandoutDirection]] = [:]
        for reference in analysis?.standoutHighs ?? [] {
            directions[reference.seasonNumber, default: [:]][reference.episodeNumber] = .high
        }
        for reference in analysis?.standoutLows ?? [] {
            directions[reference.seasonNumber, default: [:]][reference.episodeNumber] = .low
        }
        self.directions = directions
    }

    static let empty = StandoutIndex(analysis: nil)

    func direction(season: Int, episode: Int) -> StandoutDirection? {
        directions[season]?[episode]
    }

    /// Episode number → direction, for one season.
    func directions(inSeason season: Int) -> [Int: StandoutDirection] {
        directions[season] ?? [:]
    }

    var isEmpty: Bool { directions.isEmpty }
}

/// Each season's highs and lows, stated as the numeric relation the engine
/// proved and nothing more.
///
/// The predicate is "at least 1.5 standard deviations and 0.4 points from its
/// own season's vote-weighted average, in a season with enough rated episodes
/// to measure a spread". So the copy says how far above or below, against which
/// average, from how many episodes — never "essential", never "skip".
struct SeasonStandoutsView: View {
    let analysis: SeriesAnalysis

    /// Rows shown per direction before the list is expanded.
    private static let collapsedCount = 3

    @State private var isExpanded = false

    var body: some View {
        let highs = analysis.standoutHighs
        let lows = analysis.standoutLows

        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "arrow.up.arrow.down")
                .font(.body)
                .foregroundStyle(Color.plotlineSecondaryAccent)
                .frame(width: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Season highs and lows")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)

                    Text(Self.predicateExplanation)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !highs.isEmpty {
                    group(.high, references: highs)
                }
                if !lows.isEmpty {
                    group(.low, references: lows)
                }

                if max(highs.count, lows.count) > Self.collapsedCount {
                    Button(isExpanded ? "Show fewer" : "Show all \(highs.count + lows.count)") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded.toggle()
                        }
                    }
                    .font(.caption.weight(.semibold))
                    .tint(Color.plotlineAccent)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.plotlineCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .contain)
    }

    private func group(_ direction: StandoutDirection, references: [EpisodeReference]) -> some View {
        let shown = isExpanded ? references : Array(references.prefix(Self.collapsedCount))

        return VStack(alignment: .leading, spacing: 6) {
            ForEach(shown) { reference in
                let line = Self.line(for: reference, direction: direction, season: summary(for: reference))
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: direction.symbolName)
                        .font(.caption2)
                        .foregroundStyle(.primary)
                        .accessibilityHidden(true)
                    Text(line)
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(line)
            }
        }
    }

    private func summary(for reference: EpisodeReference) -> SeasonSummary? {
        analysis.seasons.first { $0.seasonNumber == reference.seasonNumber }
    }

    // MARK: - Copy

    /// The predicate, in words. Static so the thresholds on screen are the
    /// engine's own and cannot drift from them.
    static var predicateExplanation: String {
        String(
            format: "Episodes at least %.1f standard deviations and %.1f points from their own season's "
                + "vote-weighted average. Only seasons with %d or more episodes with enough votes take part.",
            SeriesAnalysisEngine.standoutZScoreThreshold,
            SeriesAnalysisEngine.minimumStandoutDelta,
            SeriesAnalysisEngine.minimumEpisodesForZScore
        )
    }

    /// One standout, e.g. "S3E7 · 9.4 — 1.1 above season 3's weighted average
    /// of 8.3 (from 9 episodes with enough votes)".
    ///
    /// Internal and static so the copy can be tested directly. When the season
    /// summary is missing the relation cannot be quantified, so only the
    /// episode and its rating are stated.
    static func line(for reference: EpisodeReference, direction: StandoutDirection, season: SeasonSummary?) -> String {
        let head = String(format: "%@ · %.1f", reference.shortCode, reference.rating)
        guard let season else { return head }

        let delta = abs(reference.rating - season.weightedAverage)
        let side = direction == .high ? "above" : "below"
        let episodes = season.reliableEpisodeCount == 1 ? "episode" : "episodes"

        return String(
            format: "%@ — %.1f %@ season %d's weighted average of %.1f (from %d %@ with enough votes)",
            head,
            delta,
            side,
            season.seasonNumber,
            season.weightedAverage,
            season.reliableEpisodeCount,
            episodes
        )
    }
}

/// The marker legend shared by the chart and the grid.
struct StandoutLegend: View {
    var directions: [StandoutDirection] = [.high, .low]

    var body: some View {
        HStack(spacing: 14) {
            ForEach(directions, id: \.self) { direction in
                HStack(spacing: 4) {
                    Image(systemName: direction.symbolName)
                        .font(.system(size: 8))
                        .foregroundStyle(.primary)
                    Text(direction.legend)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Marked episodes: " + directions.map(\.legend).joined(separator: "; ")
        )
    }
}
