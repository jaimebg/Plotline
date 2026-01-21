import SwiftUI

/// Main discovery screen with trending and popular content
struct DiscoveryView: View {
    @State private var viewModel = DiscoveryViewModel()
    @State private var navigationPath = NavigationPath()
    @Namespace private var namespace

    var body: some View {
        NavigationStack(path: $navigationPath) {
            content
                .background(Color.plotlineBackground)
                .navigationTitle("Plotline")
                .navigationBarTitleDisplayMode(.large)
                .searchable(
                    text: $viewModel.searchText,
                    prompt: "Search movies and series"
                )
                .onChange(of: viewModel.searchText) { _, _ in
                    viewModel.search()
                }
                .navigationDestination(for: MediaItem.self) { item in
                    MediaDetailView(media: item)
                        .navigationTransition(.zoom(sourceID: item.id, in: namespace))
                }
                .refreshable {
                    await viewModel.refresh()
                }
        }
        .environment(\.navigationNamespace, namespace)
        .preferredColorScheme(.dark)
        .task {
            await viewModel.loadContent()
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        Group {
            if viewModel.isSearchActive {
                searchResultsView
            } else {
                mainContentView
            }
        }
        .animation(.none, value: viewModel.isSearchActive)
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContentView: some View {
        if viewModel.isLoading && !viewModel.hasContent {
            loadingView
        } else if let error = viewModel.errorMessage, !viewModel.hasContent {
            errorView(message: error)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 28) {
                    // Featured/Trending section
                    if !viewModel.trendingMovies.isEmpty {
                        FeaturedSection(
                            title: "Trending Now",
                            items: Array(viewModel.trendingMovies.prefix(5))
                        )
                    }

                    // Trending Movies
                    MediaSection(
                        title: "Trending Movies",
                        items: viewModel.trendingMovies
                    )

                    // Trending Series
                    MediaSection(
                        title: "Trending Series",
                        items: viewModel.trendingSeries
                    )

                    // Popular Movies
                    if !viewModel.popularMovies.isEmpty {
                        MediaSection(
                            title: "Popular Movies",
                            items: viewModel.popularMovies
                        )
                    }

                    // Top Rated Series
                    if !viewModel.topRatedSeries.isEmpty {
                        MediaSection(
                            title: "Top Rated Series",
                            items: viewModel.topRatedSeries
                        )
                    }
                }
                .padding(.vertical)
            }
            .scrollIndicators(.hidden)
        }
    }

    // MARK: - Search Results

    @ViewBuilder
    private var searchResultsView: some View {
        if viewModel.isSearching {
            SearchResultsSkeletonView()
        } else if viewModel.searchResults.isEmpty && !viewModel.searchText.isEmpty {
            ContentUnavailableView(
                "No Results",
                systemImage: "magnifyingglass",
                description: Text("No movies or series found for \"\(viewModel.searchText)\"")
            )
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.searchResults) { item in
                        NavigationLink(value: item) {
                            SearchResultRow(item: item)
                                .matchedTransitionSource(id: item.id, in: namespace)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        DiscoverySkeletonView()
    }

    // MARK: - Error View

    private func errorView(message: String) -> some View {
        ContentUnavailableView {
            Label("Unable to Load", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Try Again") {
                Task {
                    await viewModel.loadContent()
                }
            }
            .buttonStyle(.bordered)
        }
    }
}

// MARK: - Search Result Row

struct SearchResultRow: View {
    let item: MediaItem

    var body: some View {
        HStack(spacing: 12) {
            // Poster thumbnail
            AsyncImage(url: item.posterURL) { phase in
                switch phase {
                case .empty:
                    Rectangle()
                        .fill(Color.plotlineCard)
                        .shimmering()

                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)

                case .failure:
                    Rectangle()
                        .fill(Color.plotlineCard)
                        .overlay {
                            Image(systemName: item.isTVSeries ? "tv" : "film")
                                .foregroundStyle(.secondary)
                        }

                @unknown default:
                    Rectangle().fill(Color.plotlineCard)
                }
            }
            .frame(width: 60, height: 90)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(item.displayTitle)
                    .font(.system(.headline, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    if let year = item.year {
                        Text(year)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Text(item.isTVSeries ? "TV Series" : "Movie")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.plotlineCard)
                        .clipShape(Capsule())
                        .foregroundStyle(.secondary)
                }

                if item.voteAverage > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(Color.imdbYellow)
                        Text(item.formattedRating)
                            .font(.subheadline)
                            .foregroundStyle(.white)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color.plotlineCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Preview

#Preview {
    DiscoveryView()
}
