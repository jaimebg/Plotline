import Charts
import SwiftUI

/// Compares movie quality across decades with avg ratings, high-rated counts, and dominant genres
struct DecadeBattleView: View {
    @State private var viewModel = DecadeBattleViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if viewModel.isLoading {
                    ProgressView("Loading decades...")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 80)
                } else if viewModel.decades.isEmpty {
                    ContentUnavailableView(
                        "No Data",
                        systemImage: "calendar.badge.exclamationmark",
                        description: Text("Could not load decade data.")
                    )
                } else {
                    avgRatingChart
                    highRatedChart
                    dominantGenreTable
                }
            }
            .padding()
        }
        .background(Color.plotlineBackground)
        .navigationTitle("Decade Battle")
        .task {
            await viewModel.loadDecades()
        }
    }

    // MARK: - Average Rating Chart

    private var avgRatingChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Average Rating", systemImage: "star.fill")
                .font(.headline)
                .foregroundStyle(.primary)

            Chart(viewModel.decades) { decade in
                BarMark(
                    x: .value("Decade", decade.decade),
                    y: .value("Rating", decade.avgRating)
                )
                .foregroundStyle(Color.plotlineGold)
                .cornerRadius(4)
                .annotation(position: .top) {
                    Text(String(format: "%.1f", decade.avgRating))
                        .font(.caption2)
                        .foregroundStyle(Color(.secondaryLabel))
                }
            }
            .frame(height: 200)
            .chartYScale(domain: 5...9)
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color(.separator))
                    AxisValueLabel()
                        .foregroundStyle(Color(.secondaryLabel))
                }
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .foregroundStyle(Color(.secondaryLabel))
                }
            }
        }
        .padding()
        .background(Color.plotlineCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - High Rated Count Chart

    private var highRatedChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Films Rated 8.0+", systemImage: "trophy.fill")
                .font(.headline)
                .foregroundStyle(.primary)

            Chart(viewModel.decades) { decade in
                BarMark(
                    x: .value("Decade", decade.decade),
                    y: .value("Count", decade.highRatedCount)
                )
                .foregroundStyle(Color.plotlineSecondaryAccent)
                .cornerRadius(4)
                .annotation(position: .top) {
                    Text("\(decade.highRatedCount)")
                        .font(.caption2)
                        .foregroundStyle(Color(.secondaryLabel))
                }
            }
            .frame(height: 200)
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color(.separator))
                    AxisValueLabel()
                        .foregroundStyle(Color(.secondaryLabel))
                }
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .foregroundStyle(Color(.secondaryLabel))
                }
            }
        }
        .padding()
        .background(Color.plotlineCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Dominant Genre Table

    private var dominantGenreTable: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Dominant Genre", systemImage: "tag.fill")
                .font(.headline)
                .foregroundStyle(.primary)

            ForEach(viewModel.decades) { decade in
                HStack {
                    Text(decade.decade)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)

                    Spacer()

                    Text(decade.topGenre)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.plotlineBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        .background(Color.plotlineCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    NavigationStack {
        DecadeBattleView()
    }
}
