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
            }
        }
        .padding()
        .background(Color.plotlineCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    NavigationStack {
        GenreEvolutionView()
    }
}
