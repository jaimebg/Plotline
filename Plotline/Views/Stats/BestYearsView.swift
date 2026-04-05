import Accessibility
import Charts
import SwiftUI

/// Shows the best years for movies with optional genre filtering
struct BestYearsView: View {
    @State private var viewModel = BestYearsViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                filterChips
                chartSection
            }
            .padding()
        }
        .background(Color.plotlineBackground)
        .navigationTitle("Best Years")
        .task {
            if viewModel.yearRatings.isEmpty {
                await viewModel.loadBestYears()
            }
        }
    }

    // MARK: - Filter Chips

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // "All" chip
                Button {
                    Task {
                        await viewModel.loadBestYears(genreId: nil)
                    }
                } label: {
                    Text("All")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(
                            viewModel.selectedGenreId == nil
                                ? Color(.systemBackground)
                                : .primary
                        )
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            viewModel.selectedGenreId == nil
                                ? Color.plotlineGold
                                : Color.plotlineCard
                        )
                        .clipShape(Capsule())
                }

                ForEach(CuratedGenre.all) { genre in
                    Button {
                        Task {
                            await viewModel.loadBestYears(genreId: genre.movieGenreId)
                        }
                    } label: {
                        Text(genre.name)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(
                                viewModel.selectedGenreId == genre.movieGenreId
                                    ? Color(.systemBackground)
                                    : .primary
                            )
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                viewModel.selectedGenreId == genre.movieGenreId
                                    ? Color.plotlineGold
                                    : Color.plotlineCard
                            )
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }

    // MARK: - Chart

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .frame(height: 300)
            } else if viewModel.yearRatings.isEmpty {
                ContentUnavailableView(
                    "No Data",
                    systemImage: "chart.bar",
                    description: Text("No rating data available.")
                )
                .frame(height: 300)
            } else {
                Chart(viewModel.yearRatings) { yr in
                    BarMark(
                        x: .value("Year", String(yr.year)),
                        y: .value("Rating", yr.avgRating)
                    )
                    .foregroundStyle(
                        yr.year == viewModel.bestYear
                            ? Color.plotlineGold
                            : Color.plotlineSecondaryAccent
                    )
                    .cornerRadius(3)
                }
                .frame(height: 300)
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
                    AxisMarks(values: .stride(by: 5)) { _ in
                        AxisValueLabel()
                            .foregroundStyle(Color(.secondaryLabel))
                    }
                }
                .accessibilityChartDescriptor(BestYearsAccessibility(yearRatings: viewModel.yearRatings, bestYear: viewModel.bestYear))
                .accessibilityLabel("Best years for film chart")
            }
        }
        .padding()
        .background(Color.plotlineCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct BestYearsAccessibility: AXChartDescriptorRepresentable {
    let yearRatings: [YearRating]
    let bestYear: Int?

    func makeChartDescriptor() -> AXChartDescriptor {
        let xAxis = AXCategoricalDataAxisDescriptor(
            title: "Year",
            categoryOrder: yearRatings.map { String($0.year) }
        )
        let yAxis = AXNumericDataAxisDescriptor(
            title: "Average Rating",
            range: 5...9,
            gridlinePositions: [5, 6, 7, 8, 9]
        ) { String(format: "%.1f", $0) }

        let dataPoints = yearRatings.map { yr in
            AXDataPoint(x: String(yr.year), y: yr.avgRating, label: "\(yr.year): \(String(format: "%.1f", yr.avgRating))")
        }

        let summary = bestYear.map { "Best year: \($0)" } ?? "Rating data across years"

        return AXChartDescriptor(
            title: "Best Years for Film",
            summary: summary,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [AXDataSeriesDescriptor(name: "Average Rating", isContinuous: false, dataPoints: dataPoints)]
        )
    }
}

#Preview {
    NavigationStack {
        BestYearsView()
    }
}
