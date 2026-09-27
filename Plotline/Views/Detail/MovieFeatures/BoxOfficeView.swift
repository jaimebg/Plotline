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
                        color: boxOffice.isProfitable ? Color.rottenGreen : Color.plotlineAccent
                    )
                }

                // Gross as a multiple of budget. Not labelled a "return": the
                // budget leaves out marketing and the gross is not what the
                // studio keeps.
                if let roi = boxOffice.formattedROI {
                    HStack {
                        Text("Gross vs. budget")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Spacer()

                        HStack(spacing: 4) {
                            Image(systemName: boxOffice.isProfitable ? "arrow.up.right" : "arrow.down.right")
                                .font(.caption)

                            Text(roi)
                                .font(.system(.subheadline, weight: .semibold))
                        }
                        .foregroundStyle(boxOffice.isProfitable ? Color.rottenGreen : .primary)
                    }
                }

                // Gross minus budget. Called what it is: "Profit" and "Loss"
                // claimed a bottom line these two numbers cannot establish.
                if let difference = boxOffice.formattedProfit {
                    HStack {
                        Text("Gross minus budget")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text(difference)
                            .font(.system(.subheadline, weight: .semibold))
                            .foregroundStyle(boxOffice.isProfitable ? Color.rottenGreen : .primary)
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
