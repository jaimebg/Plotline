import SwiftUI

/// The engine's verdicts, each shown with the data that supports it.
///
/// Every string here is written against what the engine actually proves. The
/// decline point establishes a relative fall that never recovers; it says
/// nothing about how good the show was beforehand, so neither does the copy.
struct SeriesVerdictsView: View {
    let analysis: SeriesAnalysis

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What the Numbers Say")
                .font(.system(.headline, weight: .semibold))
                .foregroundStyle(.primary)

            VStack(spacing: 10) {
                if let decline = analysis.declinePoint {
                    verdict(
                        icon: "arrow.down.right",
                        title: "Falls off after season \(decline.afterSeason)",
                        evidence: String(
                            format: "Averaged %.1f up to then, %.1f across seasons %@.",
                            decline.averageBefore,
                            decline.averageAfter,
                            decline.seasonsAfter.map(String.init).joined(separator: ", ")
                        )
                    )
                }

                verdict(
                    icon: consistencyIcon,
                    title: consistencyTitle,
                    evidence: consistencyEvidence
                )

                if let opening = analysis.openingVerdict {
                    verdict(
                        icon: "play.circle",
                        title: openingTitle(opening),
                        evidence: String(
                            format: "First %d episodes averaged %.1f against %.1f for the rest.",
                            opening.episodesConsidered.count,
                            opening.openingAverage,
                            opening.remainderAverage
                        )
                    )
                }

                if let ending = analysis.endingVerdict {
                    verdict(
                        icon: "flag.checkered",
                        title: endingTitle(ending),
                        evidence: Self.endingEvidence(ending)
                    )
                }

                if let best = analysis.bestSeason, let worst = analysis.worstSeason, best != worst {
                    verdict(
                        icon: "chart.bar",
                        title: "Best season \(best), weakest season \(worst)",
                        evidence: Self.seasonSpreadEvidence(analysis, best: best, worst: worst)
                    )
                }

                // Only the positive case is stated: `isOngoing == false` also
                // covers "status unknown", which is no evidence of an ending.
                if analysis.isOngoing {
                    verdict(
                        icon: "dot.radiowaves.up.forward",
                        title: "Still running",
                        evidence: "More episodes are on the way, so there is no ending to judge yet."
                    )
                }
            }
        }
    }

    // MARK: - Rows

    private func verdict(icon: String, title: String, evidence: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(Color.plotlineSecondaryAccent)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)

                Text(evidence)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.plotlineCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(evidence)")
    }

    // MARK: - Copy

    private var consistencyIcon: String {
        switch analysis.consistency.rating {
        case .verySteady, .steady: "equal.circle"
        case .uneven: "waveform.path"
        case .rollercoaster: "waveform.path.ecg"
        }
    }

    private var consistencyTitle: String {
        switch analysis.consistency.rating {
        case .verySteady: "Remarkably even"
        case .steady: "Holds a steady level"
        case .uneven: "Uneven episode to episode"
        case .rollercoaster: "A rollercoaster"
        }
    }

    private var consistencyEvidence: String {
        Self.consistencyEvidence(analysis.consistency)
    }

    /// The spread behind the consistency rating.
    ///
    /// When every rated episode shares a rating, the highest and lowest are
    /// different episodes with the same number, and naming both reads as a
    /// range that isn't one: "Ranges from S1E1 at 8.0 down to S3E6 at 8.0."
    /// Same self-comparison the ending verdict had; stated once instead.
    static func consistencyEvidence(_ consistency: Consistency) -> String {
        guard let high = consistency.highestRated,
              let low = consistency.lowestRated else {
            return String(format: "Episode ratings vary by %.2f on average.", consistency.standardDeviation)
        }

        if high.rating == low.rating {
            return String(format: "Every rated episode sits at %.1f.", high.rating)
        }

        return String(
            format: "Ranges from %@ at %.1f down to %@ at %.1f.",
            high.shortCode, high.rating, low.shortCode, low.rating
        )
    }

    private func openingTitle(_ opening: OpeningVerdict) -> String {
        switch opening.kind {
        case .hooksEarly:
            return "Hooks you early"
        case .slowStart:
            if let season = opening.improvesAtSeason {
                return "Slow start, better from season \(season)"
            }
            return "Slow start, better later on"
        case .even:
            return "Even from the start"
        }
    }

    private func endingTitle(_ ending: EndingVerdict) -> String {
        switch ending.kind {
        case .endsStrong: "Ends on a high"
        case .endsSteady: "Holds its level to the end"
        case .fadesOut: "Fades out at the end"
        }
    }

    /// The numbers behind the best/weakest season pair.
    ///
    /// Without them the row was the badge §5 of the spec calls decoration: a
    /// claim with nothing under it, while the season averages that produced it
    /// sat one property away.
    static func seasonSpreadEvidence(_ analysis: SeriesAnalysis, best: Int, worst: Int) -> String {
        let averages = Dictionary(
            analysis.seasons.map { ($0.seasonNumber, $0.weightedAverage) },
            uniquingKeysWith: { first, _ in first }
        )

        guard let high = averages[best], let low = averages[worst] else {
            return "Measured across the seasons with enough rated episodes to judge."
        }

        return String(
            format: "Season %d averaged %.1f against season %d's %.1f.",
            best, high, worst, low
        )
    }

    /// The numbers behind the ending verdict.
    ///
    /// The last season is often the peak — that is what `endsStrong` usually
    /// means — and comparing it to itself reads as a tautology on screen:
    /// "Season 5 averaged 9.0; its best, season 5, averaged 9.0." When the two
    /// coincide, the fact is stated once instead of dressed up as a comparison.
    ///
    /// Internal rather than private so the copy can be tested directly. Static
    /// because it depends on nothing but its argument.
    static func endingEvidence(_ ending: EndingVerdict) -> String {
        if ending.finalSeason == ending.peakSeason {
            return String(
                format: "Season %d, its highest-rated, averaged %.1f.",
                ending.finalSeason,
                ending.finalSeasonAverage
            )
        }

        return String(
            format: "Season %d averaged %.1f; its best, season %d, averaged %.1f.",
            ending.finalSeason,
            ending.finalSeasonAverage,
            ending.peakSeason,
            ending.peakSeasonAverage
        )
    }
}
