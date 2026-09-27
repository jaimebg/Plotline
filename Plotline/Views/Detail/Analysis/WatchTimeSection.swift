import SwiftUI

/// How long the aired run takes to watch, per season, and — when the analysis
/// found a decline — how that time falls on either side of it.
///
/// It lays out the facts and leaves the decision to the viewer: nothing here
/// says where to stop.
struct WatchTimeSection: View {
    let plan: WatchTimePlan

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Watch Time")
                .font(.system(.headline, weight: .semibold))
                .foregroundStyle(.primary)

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "clock")
                        .font(.body)
                        .foregroundStyle(Color.plotlineSecondaryAccent)
                        .frame(width: 24)
                        .accessibilityHidden(true)

                    Text(WatchTimePlanner.summary(plan))
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel(
                            WatchTimePlanner.summary(plan)
                                .replacingOccurrences(
                                    of: WatchTimePlanner.duration(minutes: plan.totalMinutes),
                                    with: WatchTimePlanner.spokenDuration(minutes: plan.totalMinutes)
                                )
                        )
                }

                FlowLayout(spacing: 8) {
                    ForEach(plan.seasons) { season in
                        seasonChip(season)
                    }
                }

                if let split = plan.split {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(WatchTimePlanner.splitLine(split))
                            .font(.caption)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Split at the decline point in What the Numbers Say; the averages are that verdict's own.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.plotlineCard)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .accessibilityElement(children: .contain)
    }

    private func seasonChip(_ season: WatchTimePlan.Season) -> some View {
        let partial = season.knownRuntimeCount < season.airedCount
        let duration = WatchTimePlanner.duration(minutes: season.minutes)

        return HStack(spacing: 4) {
            Text("S\(season.seasonNumber)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(duration)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.primary)
            if partial {
                Text("(\(season.knownRuntimeCount) of \(season.airedCount))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.plotlineBackground)
        .clipShape(Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Season \(season.seasonNumber): \(WatchTimePlanner.spokenDuration(minutes: season.minutes))"
                + (partial ? ", runtime known for \(season.knownRuntimeCount) of \(season.airedCount) episodes" : "")
        )
    }
}
