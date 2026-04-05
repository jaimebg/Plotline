import Accessibility
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
            .accessibilityChartDescriptor(DecadeAvgRatingAccessibility(decades: viewModel.decades))
            .accessibilityLabel("Average rating by decade chart")
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
            .accessibilityChartDescriptor(DecadeHighRatedAccessibility(decades: viewModel.decades))
            .accessibilityLabel("High rated films count by decade chart")
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

struct DecadeAvgRatingAccessibility: AXChartDescriptorRepresentable {
    let decades: [DecadeData]

    func makeChartDescriptor() -> AXChartDescriptor {
        let xAxis = AXCategoricalDataAxisDescriptor(
            title: "Decade",
            categoryOrder: decades.map(\.decade)
        )
        let yAxis = AXNumericDataAxisDescriptor(
            title: "Average Rating",
            range: 5...9,
            gridlinePositions: [5, 6, 7, 8, 9]
        ) { String(format: "%.1f", $0) }

        let dataPoints = decades.map { d in
            AXDataPoint(x: d.decade, y: d.avgRating, label: "\(d.decade): \(String(format: "%.1f", d.avgRating)) average")
        }

        return AXChartDescriptor(
            title: "Average Rating by Decade",
            summary: decades.max { $0.avgRating < $1.avgRating }.map { "Best decade: \($0.decade) with \(String(format: "%.1f", $0.avgRating))" } ?? "",
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [AXDataSeriesDescriptor(name: "Average Rating", isContinuous: false, dataPoints: dataPoints)]
        )
    }
}

struct DecadeHighRatedAccessibility: AXChartDescriptorRepresentable {
    let decades: [DecadeData]

    func makeChartDescriptor() -> AXChartDescriptor {
        let xAxis = AXCategoricalDataAxisDescriptor(
            title: "Decade",
            categoryOrder: decades.map(\.decade)
        )
        let maxCount = decades.map(\.highRatedCount).max() ?? 10
        let yAxis = AXNumericDataAxisDescriptor(
            title: "Films Rated 8.0+",
            range: 0...Double(maxCount),
            gridlinePositions: []
        ) { "\(Int($0)) films" }

        let dataPoints = decades.map { d in
            AXDataPoint(x: d.decade, y: Double(d.highRatedCount), label: "\(d.decade): \(d.highRatedCount) films rated 8.0+")
        }

        return AXChartDescriptor(
            title: "High Rated Films by Decade",
            summary: decades.max { $0.highRatedCount < $1.highRatedCount }.map { "Most high-rated films: \($0.decade) with \($0.highRatedCount)" } ?? "",
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [AXDataSeriesDescriptor(name: "Films 8.0+", isContinuous: false, dataPoints: dataPoints)]
        )
    }
}

#Preview {
    NavigationStack {
        DecadeBattleView()
    }
}
