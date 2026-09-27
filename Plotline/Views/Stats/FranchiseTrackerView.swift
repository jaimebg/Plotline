import Accessibility
import Charts
import SwiftUI

/// Searches movie franchises and shows quality progression with charts and movie lists
struct FranchiseTrackerView: View {
    @State private var viewModel = FranchiseTrackerViewModel()

    var body: some View {
        Group {
            if viewModel.selectedCollection != nil {
                collectionDetail
            } else {
                searchMode
            }
        }
        .navigationTitle("Franchise Tracker")
    }

    // MARK: - Search Mode

    private var searchMode: some View {
        List {
            if viewModel.isSearching {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowBackground(Color.plotlineCard)
            } else if viewModel.searchResults.isEmpty && !viewModel.searchText.isEmpty {
                ContentUnavailableView.search(text: viewModel.searchText)
                    .listRowBackground(Color.plotlineCard)
            } else {
                ForEach(viewModel.searchResults) { result in
                    Button {
                        Task {
                            await viewModel.loadCollection(id: result.id)
                        }
                    } label: {
                        HStack(spacing: 12) {
                            posterThumbnail(url: result.posterURL)

                            Text(result.name)
                                .font(.body)
                                .foregroundStyle(.primary)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .listRowBackground(Color.plotlineCard)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.plotlineBackground)
        .searchable(text: Binding(
            get: { viewModel.searchText },
            set: { viewModel.updateSearch($0) }
        ), prompt: "Search franchises...")
    }

    // MARK: - Collection Detail

    private var collectionDetail: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Chart
                if ratedMovies.count >= 2 {
                    franchiseChart
                }

                // Movie List
                movieList

                // Back button
                Button {
                    viewModel.goBackToSearch()
                } label: {
                    Label("Search Another", systemImage: "magnifyingglass")
                        .font(.body.weight(.medium))
                        .foregroundStyle(Color.plotlineGoldText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.plotlineCard)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.top, 4)
            }
            .padding()
        }
        .background(Color.plotlineBackground)
        .overlay {
            if viewModel.isLoadingCollection {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.plotlineBackground.opacity(0.8))
            }
        }
    }

    // MARK: - Franchise Chart

    /// Movies with valid year and non-zero rating, sorted chronologically
    private var ratedMovies: [CollectionMovie] {
        viewModel.movies.filter { $0.yearInt != nil && $0.voteAverage > 0 }
    }

    private var franchiseChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Quality Over Time", systemImage: "chart.xyaxis.line")
                .font(.headline)
                .foregroundStyle(.primary)

            Chart(ratedMovies) { movie in
                LineMark(
                    x: .value("Year", movie.yearInt ?? 0),
                    y: .value("Rating", movie.voteAverage)
                )
                .foregroundStyle(Color.plotlineGold)
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2))

                PointMark(
                    x: .value("Year", movie.yearInt ?? 0),
                    y: .value("Rating", movie.voteAverage)
                )
                .foregroundStyle(Color.plotlineGold)
                .symbolSize(40)
                .annotation(position: .top, spacing: 4) {
                    Text(movie.formattedRating)
                        .font(.caption2)
                        .foregroundStyle(Color(.secondaryLabel))
                }
            }
            .frame(height: 220)
            .chartYScale(domain: 0...10)
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
            .accessibilityChartDescriptor(
                FranchiseQualityAccessibility(
                    collectionName: viewModel.selectedCollection?.name ?? "Franchise",
                    movies: ratedMovies.map { (title: $0.title, year: $0.yearInt ?? 0, rating: $0.voteAverage) }
                )
            )
        }
        .padding()
        .background(Color.plotlineCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Movie List

    private var movieList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Movies", systemImage: "film.stack")
                .font(.headline)
                .foregroundStyle(.primary)

            ForEach(viewModel.movies) { movie in
                NavigationLink(value: movie.toMediaItem()) {
                    HStack(spacing: 12) {
                        posterThumbnail(url: movie.posterURL)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(movie.title)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                                .lineLimit(1)

                            if let year = movie.year {
                                Text(year)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        if movie.voteAverage > 0 {
                            Text(movie.formattedRating)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.plotlineGoldText)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .padding()
        .background(Color.plotlineCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Helpers

    private func posterThumbnail(url: URL?) -> some View {
        AsyncImage(url: url) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
        } placeholder: {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.plotlineBackground)
                .overlay {
                    Image(systemName: "film")
                        .foregroundStyle(.secondary)
                }
        }
        .frame(width: 40, height: 60)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

#Preview {
    NavigationStack {
        FranchiseTrackerView()
    }
}

// MARK: - Chart Accessibility

/// VoiceOver's Audio Graph for "Quality Over Time": each film's TMDB rating
/// by release year, in release order.
struct FranchiseQualityAccessibility: AXChartDescriptorRepresentable {
    let collectionName: String
    let movies: [(title: String, year: Int, rating: Double)]

    func makeChartDescriptor() -> AXChartDescriptor {
        let years = movies.map(\.year)
        let lower = Double(years.min() ?? 0)
        let upper = Double(years.max() ?? 0)
        let xAxis = AXNumericDataAxisDescriptor(
            title: "Release year",
            range: lower...max(upper, lower + 1),
            gridlinePositions: []
        ) { String(Int($0)) }
        let yAxis = AXNumericDataAxisDescriptor(
            title: "Rating",
            range: 0...10,
            gridlinePositions: [0, 2, 4, 6, 8, 10]
        ) { String(format: "%.1f", $0) }

        let best = movies.max { $0.rating < $1.rating }
        let worst = movies.min { $0.rating < $1.rating }
        var summary = "\(movies.count) rated films"
        if let best, let worst {
            summary += ". Highest: \(best.title), \(String(format: "%.1f", best.rating)). Lowest: \(worst.title), \(String(format: "%.1f", worst.rating))"
        }

        return AXChartDescriptor(
            title: "\(collectionName) quality over time",
            summary: summary,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [
                AXDataSeriesDescriptor(
                    name: "Rating",
                    isContinuous: true,
                    dataPoints: movies.map { movie in
                        AXDataPoint(x: Double(movie.year), y: movie.rating, label: "\(movie.title), \(movie.year)")
                    }
                )
            ]
        )
    }
}
