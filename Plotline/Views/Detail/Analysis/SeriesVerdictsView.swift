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
                        evidence: String(
                            format: "Season %d averaged %.1f; its best, season %d, averaged %.1f.",
                            ending.finalSeason,
                            ending.finalSeasonAverage,
                            ending.peakSeason,
                            ending.peakSeasonAverage
                        )
                    )
                }

                if let best = analysis.bestSeason, let worst = analysis.worstSeason, best != worst {
                    verdict(
                        icon: "chart.bar",
                        title: "Best season \(best), weakest season \(worst)",
                        evidence: "Measured across the seasons with enough rated episodes to judge."
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
        guard let high = analysis.consistency.highestRated,
              let low = analysis.consistency.lowestRated else {
            return String(format: "Episode ratings vary by %.2f on average.", analysis.consistency.standardDeviation)
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
}
