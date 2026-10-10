import Charts
import SwiftUI

/// One analysed series a day, at the top of Discover: what Plotline does, in
/// the first second, with no network. Every string is a `FeaturedSeriesSummary`
/// field, so the card says no more than the detail screen.
struct FeaturedSeriesCard: View {
    let entry: DatasetEntry

    var body: some View {
        let summary = FeaturedSeriesSummary(entry: entry)

        VStack(alignment: .leading, spacing: 0) {
            CachedAsyncImage(url: Self.backdropURL(for: entry)) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                // Offline or still loading: a decorative glyph, as the See-all
                // rows show, so the band never reads as a broken block.
                Rectangle()
                    .fill(Color.plotlineBackground)
                    .overlay {
                        Image(systemName: "tv")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                    }
            }
            .frame(height: 180)
            .frame(maxWidth: .infinity)
            .clipped()

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Featured today")
                            .font(.caption.weight(.semibold))
                            .textCase(.uppercase)
                            .foregroundStyle(.secondary)
                        Text(summary.title)
                            .font(.system(.title2, weight: .bold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 8)

                    VStack(alignment: .trailing, spacing: 0) {
                        Text("\(summary.score)")
                            .font(.system(.title, design: .rounded, weight: .bold))
                            .foregroundStyle(Color.plotlineGoldText)
                            .monospacedDigit()
                        Text("Score")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                curve(summary.seasonPoints)

                Text(summary.verdict)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(summary.basis)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .background(Color.plotlineCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .contentShape(RoundedRectangle(cornerRadius: 16))
        // One element, so the capture suite's label queries can never land on
        // a child of this card (see FeaturedCardSourceTests).
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Featured series: \(summary.title). Plotline Score \(summary.score). \(summary.verdict).")
        .accessibilityValue(Self.accessibilityValue(for: summary))
        .accessibilityHint("Opens the series")
        // No `.isButton` trait: the NavigationLink around the card supplies it.
    }

    private func curve(_ points: [FeaturedSeriesSummary.SeasonPoint]) -> some View {
        let averages = points.map(\.average)
        let low = (averages.min() ?? 0) - 0.3
        let high = (averages.max() ?? 10) + 0.3
        return VStack(alignment: .leading, spacing: 4) {
            Text(VerdictCardContent.seasonAveragesCaption)
                .font(.caption)
                .foregroundStyle(.secondary)
            // x is the point's position, so a skipped season leaves no hole in
            // the line; every label names the season's own number.
            Chart {
                ForEach(Array(points.enumerated()), id: \.offset) { index, point in
                    LineMark(x: .value("Season", Double(index + 1)), y: .value("Average", point.average))
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(Color.plotlineGold)
                    PointMark(x: .value("Season", Double(index + 1)), y: .value("Average", point.average))
                        .foregroundStyle(Color.plotlineGold)
                        .symbolSize(24)
                }
            }
            .chartYScale(domain: low...high)
            .chartXScale(domain: 0.5...(Double(max(points.count, 2)) + 0.5))
            .chartXAxis {
                AxisMarks(values: Self.labelledIndices(count: points.count).map { Double($0 + 1) }) { value in
                    AxisValueLabel { Text(Self.axisLabel(at: value.as(Double.self), in: points)) }
                }
            }
            .chartYAxis(.hidden)
            .frame(height: 80)
            .accessibilityHidden(true)
        }
    }

    /// Which points the axis labels, by index. Up to eight points, all of
    /// them. Past that, every k-th with k = ceil(count / 6), and always the
    /// last; a sampled point closer than k to the last gives way to it, so no
    /// two labels sit fewer than k points apart and there are at most seven.
    /// At iPhone SE width a label per season loses the last one at twelve,
    /// collides at twenty and is unreadable at thirty-seven.
    nonisolated static func labelledIndices(count: Int) -> [Int] {
        guard count > 8 else { return Array(0..<max(count, 0)) }
        let step = (count + 5) / 6
        let last = count - 1
        return stride(from: 0, to: last, by: step).filter { last - $0 >= step } + [last]
    }

    /// `w780`, not the `original` that `MediaItem.backdropURL` asks for:
    /// that can be a 4K file, decoded whole on Discover's first screen for a
    /// band 180 points tall.
    static func backdropURL(for entry: DatasetEntry) -> URL? {
        guard let path = entry.backdropPath, !path.isEmpty else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w780\(path)")
    }

    /// The label for the point plotted at `position` (1-based).
    private static func axisLabel(at position: Double?, in points: [FeaturedSeriesSummary.SeasonPoint]) -> String {
        guard let position, points.indices.contains(Int(position) - 1) else { return "" }
        return points[Int(position) - 1].axisLabel
    }

    /// What VoiceOver reads after the label: every season, by its own
    /// number, then the basis line sighted users read under the verdict.
    static func accessibilityValue(for summary: FeaturedSeriesSummary) -> String {
        VerdictCardContent.seasonAveragesCaption + ": "
            + summary.seasonPoints
                .map { String(format: "season %d, %.1f", $0.season, $0.average) }
                .joined(separator: "; ")
            + ". " + summary.basis
    }
}
