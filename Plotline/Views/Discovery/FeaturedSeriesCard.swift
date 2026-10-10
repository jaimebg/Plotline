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
            CachedAsyncImage(url: entry.asMediaItem.backdropURL) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle().fill(Color.plotlineBackground)
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

                curve(summary.seasonAverages)

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
        .accessibilityValue(curveDescription(summary.seasonAverages))
        .accessibilityHint("Opens the series")
        // No `.isButton` trait: the NavigationLink around the card supplies it.
    }

    private func curve(_ averages: [Double]) -> some View {
        let low = (averages.min() ?? 0) - 0.3
        let high = (averages.max() ?? 10) + 0.3
        return VStack(alignment: .leading, spacing: 4) {
            Text(VerdictCardContent.seasonAveragesCaption)
                .font(.caption)
                .foregroundStyle(.secondary)
            Chart {
                ForEach(Array(averages.enumerated()), id: \.offset) { index, average in
                    LineMark(x: .value("Season", index + 1), y: .value("Average", average))
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(Color.plotlineGold)
                    PointMark(x: .value("Season", index + 1), y: .value("Average", average))
                        .foregroundStyle(Color.plotlineGold)
                        .symbolSize(24)
                }
            }
            .chartYScale(domain: low...high)
            .chartXScale(domain: 1...max(averages.count, 2))
            .chartXAxis {
                AxisMarks(values: .stride(by: 1)) { value in
                    AxisValueLabel { Text("S\(value.as(Int.self) ?? 0)") }
                }
            }
            .chartYAxis(.hidden)
            .frame(height: 80)
        }
    }

    private func curveDescription(_ averages: [Double]) -> String {
        VerdictCardContent.seasonAveragesCaption + ": "
            + averages.enumerated()
                .map { String(format: "season %d, %.1f", $0.offset + 1, $0.element) }
                .joined(separator: "; ")
    }
}
