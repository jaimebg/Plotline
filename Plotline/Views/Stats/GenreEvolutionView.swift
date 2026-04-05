import Accessibility
import Charts
import SwiftUI

/// Shows how a genre's average movie rating has evolved over 50 years
struct GenreEvolutionView: View {
    @State private var viewModel = GenreEvolutionViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                genreChips
                chartSection
            }
            .padding()
        }
        .background(Color.plotlineBackground)
        .navigationTitle("Genre Evolution")
        .task {
            // Load first genre on appear
            if let first = CuratedGenre.all.first, viewModel.selectedGenreId == 0 {
                await viewModel.loadEvolution(genreId: first.movieGenreId)
            }
        }
    }

    // MARK: - Genre Chips

    private var genreChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(CuratedGenre.all) { genre in
                    Button {
                        Task {
                            await viewModel.loadEvolution(genreId: genre.movieGenreId)
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
                    .frame(height: 250)
            } else if viewModel.points.isEmpty {
                ContentUnavailableView(
                    "No Data",
                    systemImage: "chart.xyaxis.line",
                    description: Text("Select a genre to see its rating evolution.")
                )
                .frame(height: 250)
            } else {
                Chart(viewModel.points) { point in
                    LineMark(
                        x: .value("Year", point.year),
                        y: .value("Rating", point.avgRating)
                    )
                    .foregroundStyle(Color.plotlineGold)
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
                .frame(height: 250)
                .chartYScale(domain: 4...9)
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(Color(.separator))
                        AxisValueLabel()
                            .foregroundStyle(Color(.secondaryLabel))
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: 10)) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(Color(.separator))
                        AxisValueLabel()
                            .foregroundStyle(Color(.secondaryLabel))
                    }
                }
                .accessibilityChartDescriptor(GenreEvolutionAccessibility(points: viewModel.points))
                .accessibilityLabel("Genre rating evolution chart")
            }
        }
        .padding()
        .background(Color.plotlineCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct GenreEvolutionAccessibility: AXChartDescriptorRepresentable {
    let points: [GenreYearPoint]

    func makeChartDescriptor() -> AXChartDescriptor {
        let xAxis = AXNumericDataAxisDescriptor(
            title: "Year",
            range: Double(points.first?.year ?? 1970)...Double(points.last?.year ?? 2024),
            gridlinePositions: stride(from: Double(points.first?.year ?? 1970), through: Double(points.last?.year ?? 2024), by: 10).map { $0 }
        ) { "Year \(Int($0))" }

        let yAxis = AXNumericDataAxisDescriptor(
            title: "Average Rating",
            range: 4...9,
            gridlinePositions: [4, 5, 6, 7, 8, 9]
        ) { String(format: "%.1f", $0) }

        let dataPoints = points.map { p in
            AXDataPoint(x: Double(p.year), y: p.avgRating, label: "\(p.year): \(String(format: "%.1f", p.avgRating))")
        }

        return AXChartDescriptor(
            title: "Genre Rating Evolution",
            summary: {
                guard !points.isEmpty else { return "No data" }
                let first = points.first!, last = points.last!
                let trend = last.avgRating > first.avgRating ? "trending up" : "trending down"
                return "From \(first.year) to \(last.year), \(trend). Current average: \(String(format: "%.1f", last.avgRating))"
            }(),
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [AXDataSeriesDescriptor(name: "Rating Evolution", isContinuous: true, dataPoints: dataPoints)]
        )
    }
}

#Preview {
    NavigationStack {
        GenreEvolutionView()
    }
}
