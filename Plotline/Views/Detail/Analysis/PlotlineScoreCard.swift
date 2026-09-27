import SwiftUI

/// Plotline's own 0-100 score, with the three components it is made of.
///
/// The breakdown is the point. A bare number is an opinion; a number that
/// shows its working is an analysis, and that distinction is what this app
/// offers over a catalogue listing.
struct PlotlineScoreCard: View {
    let score: PlotlineScore

    /// What each component measures. Shared with Compare, so a component
    /// never means one thing on the detail screen and another beside it.
    static let levelCaption = "How highly its episodes rate"
    static let consistencyCaption = "How evenly it holds that level"
    static let trajectoryCaption = "Whether it climbs or slides"

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(score.value)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.plotlineGold)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Plotline Score")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("Out of 100")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 10) {
                component("Level", value: score.level, caption: Self.levelCaption)
                component("Consistency", value: score.consistency, caption: Self.consistencyCaption)
                component("Trajectory", value: score.trajectory, caption: Self.trajectoryCaption)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.plotlineCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Plotline Score \(score.value) out of 100. Level \(score.level), consistency \(score.consistency), trajectory \(score.trajectory)."
        )
    }

    private func component(_ name: String, value: Int, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(name)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(value)")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            // The caption explains the component, so it sits under the
            // component's name rather than under the bar it describes.
            Text(caption)
                .font(.caption2)
                .foregroundStyle(.secondary)

            ProgressView(value: Double(value), total: 100)
                .tint(Color.plotlineGold)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name): \(value) out of 100. \(caption)")
    }
}

#Preview {
    PlotlineScoreCard(score: PlotlineScore(value: 82, level: 88, consistency: 74, trajectory: 61))
        .padding()
}
