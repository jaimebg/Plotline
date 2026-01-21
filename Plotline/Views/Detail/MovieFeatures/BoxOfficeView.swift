import SwiftUI

/// Box office performance display for movies
struct BoxOfficeView: View {
    let boxOffice: BoxOfficeData

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header
            Text("Box Office")
                .font(.system(.headline, weight: .semibold))
                .foregroundStyle(.primary)

            VStack(spacing: 12) {
                // Budget bar
                if boxOffice.budget > 0 {
                    MetricBar(
                        label: "Budget",
                        value: boxOffice.formattedBudget,
                        progress: 1.0,
                        color: .secondary
                    )
                }

                // Revenue bar
                if boxOffice.revenue > 0 {
                    MetricBar(
                        label: "Revenue",
                        value: boxOffice.formattedRevenue,
                        progress: min(boxOffice.revenueRatio, 1.0),
                        color: boxOffice.isProfitable ? Color.rottenGreen : Color.rottenRed
                    )
                }

                // ROI indicator
                if let roi = boxOffice.formattedROI {
                    HStack {
                        Text("Return")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Spacer()

                        HStack(spacing: 4) {
                            Image(systemName: boxOffice.isProfitable ? "arrow.up.right" : "arrow.down.right")
                                .font(.caption)

                            Text(roi)
                                .font(.system(.subheadline, weight: .semibold))
                        }
                        .foregroundStyle(boxOffice.isProfitable ? Color.rottenGreen : Color.rottenRed)
                    }
                }

                // Profit/Loss summary
                if boxOffice.budget > 0 && boxOffice.revenue > 0 {
                    HStack {
                        Text(boxOffice.isProfitable ? "Profit" : "Loss")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text(boxOffice.formattedProfit)
                            .font(.system(.subheadline, weight: .semibold))
                            .foregroundStyle(boxOffice.isProfitable ? Color.rottenGreen : Color.rottenRed)
                    }
                }
            }
        }
        .padding()
        .background(Color.plotlineCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Metric Bar Component

struct MetricBar: View {
    let label: String
    let value: String
    let progress: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(value)
                    .font(.system(.subheadline, weight: .medium))
                    .foregroundStyle(.primary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 8)

                    // Progress fill
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geometry.size.width * progress, height: 8)
                }
            }
            .frame(height: 8)
        }
    }
}

// MARK: - Preview

#Preview("Blockbuster") {
    BoxOfficeView(boxOffice: .blockbusterPreview)
        .padding()
        .background(Color.plotlineBackground)
}

#Preview("Modest Success") {
    BoxOfficeView(boxOffice: .modestPreview)
        .padding()
        .background(Color.plotlineBackground)
}

#Preview("Box Office Flop") {
    BoxOfficeView(boxOffice: .flopPreview)
        .padding()
        .background(Color.plotlineBackground)
}
