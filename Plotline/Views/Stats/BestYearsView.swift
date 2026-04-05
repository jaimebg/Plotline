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
            }
        }
        .padding()
        .background(Color.plotlineCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    NavigationStack {
        BestYearsView()
    }
}
