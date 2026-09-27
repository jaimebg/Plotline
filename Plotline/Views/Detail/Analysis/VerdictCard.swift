import SwiftUI
import Charts
import CoreTransferable
import UniformTypeIdentifiers

/// Everything the shareable verdict card says, worked out before anything is
/// drawn.
///
/// Every string is either taken verbatim from the detail screen's own copy
/// (`SeriesVerdictsView`'s static functions) or is a plain count, so the card
/// cannot make a claim the screen does not. Kept as data so tests can read the
/// card's words without rendering it.
nonisolated struct VerdictCardContent: Hashable, Sendable {
    struct Verdict: Hashable, Sendable {
        let title: String
        let evidence: String
    }

    let title: String
    let score: PlotlineScore
    /// Ratings to draw, in order: every rated, aired main-run episode in
    /// broadcast order, or each season's average when no episodes are loaded.
    let curve: [Double]
    let curveCaption: String
    let decline: Verdict?
    let ending: Verdict?
    /// Only the positive run-status cases the screen states. An unknown status,
    /// or `isOngoing == false`, yields nothing — never "Ended".
    let status: Verdict?
    let basis: String

    static let credit = "Ratings: TMDB · Analysis: Plotline"

    /// Every line of text on the card, for tests.
    var allText: [String] {
        var lines = [
            "PLOTLINE · SERIES ANALYSIS", title, "Plotline Score", "Out of 100",
            "Level", "Consistency", "Trajectory", curveCaption, basis, Self.credit
        ]
        for verdict in [decline, ending, status].compactMap({ $0 }) {
            lines.append(verdict.title)
            lines.append(verdict.evidence)
        }
        return lines
    }
}

extension VerdictCardContent {
    /// - Parameters:
    ///   - episodes: whatever episodes are loaded, any season; may be empty
    ///     when the analysis on screen is the bundled one and the network is
    ///     unavailable.
    ///   - hasEnded / nextEpisodeDate: the same inputs the detail screen's
    ///     run-status row reads, so the card says exactly what the row says.
    @MainActor
    init(
        title: String,
        analysis: SeriesAnalysis,
        episodes: [EpisodeMetric],
        hasEnded: Bool?,
        nextEpisodeDate: Date?,
        asOf now: Date = Date()
    ) {
        let rated = episodes
            .filter { $0.seasonNumber > 0 && $0.hasAired(asOf: now) && $0.hasValidRating }
            .sorted { ($0.seasonNumber, $0.episodeNumber) < ($1.seasonNumber, $1.episodeNumber) }

        let curve: [Double]
        let curveCaption: String
        if rated.count >= 2 {
            curve = rated.map(\.rating)
            curveCaption = "Episode ratings in broadcast order"
        } else {
            curve = analysis.seasons.map(\.weightedAverage)
            curveCaption = "Season averages, weighted by votes"
        }

        let status = SeriesVerdictsView.runStatus(hasEnded: hasEnded, nextEpisodeDate: nextEpisodeDate)

        self.init(
            title: title,
            score: analysis.score,
            curve: curve,
            curveCaption: curveCaption,
            decline: analysis.declinePoint.map {
                Verdict(title: SeriesVerdictsView.declineTitle($0), evidence: SeriesVerdictsView.declineEvidence($0))
            },
            ending: analysis.endingVerdict.map {
                Verdict(title: SeriesVerdictsView.endingTitle($0), evidence: SeriesVerdictsView.endingEvidence($0))
            },
            status: status.map { Verdict(title: $0.title, evidence: $0.evidence) },
            basis: Self.basis(for: analysis)
        )
    }

    /// "Based on 62 episodes with enough votes to count, across 5 seasons."
    static func basis(for analysis: SeriesAnalysis) -> String {
        let episodes = analysis.seasons.reduce(0) { $0 + $1.reliableEpisodeCount }
        let seasons = analysis.seasons.count
        return "Based on \(episodes) \(episodes == 1 ? "episode" : "episodes") with enough votes to count, "
            + "across \(seasons) \(seasons == 1 ? "season" : "seasons")."
    }
}

// MARK: - Transferable

/// The verdict card as something `ShareLink` can hand over: a PNG, rendered
/// only when the share sheet actually asks for it.
nonisolated struct VerdictCardImage: Transferable, Sendable {
    let content: VerdictCardContent

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { card in
            try await MainActor.run {
                guard let data = VerdictCardRenderer.pngData(for: card.content) else {
                    throw CocoaError(.fileWriteUnknown)
                }
                return data
            }
        }
        .suggestedFileName { card in
            let safeTitle = card.content.title
                .components(separatedBy: CharacterSet(charactersIn: "/\\:"))
                .joined(separator: "-")
            return "Plotline - \(safeTitle).png"
        }
    }
}

@MainActor
enum VerdictCardRenderer {
    /// Points; rendered at 2x for a 1080-pixel-wide image.
    static let width: CGFloat = 540
    static let scale: CGFloat = 2

    static func image(for content: VerdictCardContent) -> UIImage? {
        let renderer = ImageRenderer(content: VerdictCardView(content: content))
        renderer.proposedSize = ProposedViewSize(width: width, height: nil)
        renderer.scale = scale
        renderer.isOpaque = true
        return renderer.uiImage
    }

    static func pngData(for content: VerdictCardContent) -> Data? {
        image(for: content)?.pngData()
    }
}

// MARK: - Card View

/// The card itself, drawn in a fixed dark palette.
///
/// Fixed on purpose, and the one place in the app that is: `ImageRenderer`
/// does not reliably inherit the colour scheme, and an image leaves the app —
/// it will be seen in whatever appearance the recipient uses, so it has to
/// carry its own contrast. The adaptive-colour rule applies to on-screen UI.
struct VerdictCardView: View {
    let content: VerdictCardContent

    private enum Palette {
        static let background = Color(hex: "121212")
        static let panel = Color(hex: "1E1E1E")
        static let text = Color(hex: "FFFFFF")
        static let secondaryText = Color(hex: "B8B8B8")
        static let gold = Color.plotlineGold
        static let accent = Color(hex: "FF7A33")
        static let track = Color(hex: "3A3A3A")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            header
            scoreBlock
            curveBlock

            if content.decline != nil || content.ending != nil || content.status != nil {
                VStack(alignment: .leading, spacing: 10) {
                    if let decline = content.decline {
                        verdictRow(decline, symbol: "arrow.down.right")
                    }
                    if let ending = content.ending {
                        verdictRow(ending, symbol: "flag.checkered")
                    }
                    if let status = content.status {
                        verdictRow(status, symbol: "dot.radiowaves.up.forward")
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(content.basis)
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Rectangle()
                    .fill(Palette.track)
                    .frame(height: 1)

                Text(VerdictCardContent.credit)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.secondaryText)
            }
        }
        .padding(36)
        .frame(width: VerdictCardRenderer.width, alignment: .leading)
        .background(Palette.background)
        .environment(\.colorScheme, .dark)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PLOTLINE · SERIES ANALYSIS")
                .font(.system(size: 12, weight: .bold))
                .tracking(2)
                .foregroundStyle(Palette.gold)

            Text(content.title)
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(Palette.text)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var scoreBlock: some View {
        HStack(alignment: .center, spacing: 24) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(content.score.value)")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.gold)
                Text("Plotline Score")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.text)
                Text("Out of 100")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.secondaryText)
            }
            .fixedSize()

            VStack(spacing: 12) {
                component("Level", value: content.score.level)
                component("Consistency", value: content.score.consistency)
                component("Trajectory", value: content.score.trajectory)
            }
        }
        .padding(20)
        .background(Palette.panel)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func component(_ name: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(name)
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.text)
                Spacer()
                Text("\(value)")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.secondaryText)
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.track)
                    Capsule()
                        .fill(Palette.gold)
                        .frame(width: geometry.size.width * CGFloat(min(max(value, 0), 100)) / 100)
                }
            }
            .frame(height: 5)
        }
    }

    private var curveBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(content.curveCaption)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.secondaryText)

            Chart {
                ForEach(Array(content.curve.enumerated()), id: \.offset) { index, rating in
                    AreaMark(
                        x: .value("Position", index),
                        yStart: .value("Floor", yDomain.lowerBound),
                        yEnd: .value("Rating", rating)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Palette.gold.opacity(0.35), Palette.gold.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.monotone)

                    LineMark(x: .value("Position", index), y: .value("Rating", rating))
                        .foregroundStyle(Palette.gold)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .interpolationMethod(.monotone)
                }
            }
            .chartXAxis(.hidden)
            .chartXScale(domain: 0...max(content.curve.count - 1, 1))
            .chartYScale(domain: yDomain)
            .chartYAxis {
                AxisMarks(position: .leading, values: yAxisValues) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Palette.track)
                    AxisValueLabel {
                        if let rating = value.as(Double.self) {
                            Text(String(format: "%.1f", rating))
                                .font(.system(size: 10))
                                .foregroundStyle(Palette.secondaryText)
                        }
                    }
                }
            }
            .frame(height: 120)
        }
    }

    private func verdictRow(_ verdict: VerdictCardContent.Verdict, symbol: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.accent)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 3) {
                Text(verdict.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.text)
                Text(verdict.evidence)
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Palette.panel)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var yDomain: ClosedRange<Double> {
        let low = (content.curve.min() ?? 0) - 0.3
        let high = (content.curve.max() ?? 10) + 0.3
        let lower = max(0, low)
        let upper = min(10, max(high, lower + 0.5))
        return lower...upper
    }

    private var yAxisValues: [Double] {
        let lower = yDomain.lowerBound
        let upper = yDomain.upperBound
        return [lower, (lower + upper) / 2, upper]
    }
}

#Preview("Verdict Card") {
    ScrollView {
        VerdictCardView(
            content: VerdictCardContent(
                title: "Breaking Bad",
                score: PlotlineScore(value: 86, level: 90, consistency: 72, trajectory: 71),
                curve: EpisodeMetric.breakingBadS1.map(\.rating) + EpisodeMetric.breakingBadS5.map(\.rating),
                curveCaption: "Episode ratings in broadcast order",
                decline: nil,
                ending: .init(title: "Ends on a high", evidence: "Season 5, its highest-rated, averaged 9.2."),
                status: nil,
                basis: "Based on 62 episodes with enough votes to count, across 5 seasons."
            )
        )
    }
}
