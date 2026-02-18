import SwiftUI

/// Navigation routes for discovery (non-media destinations)
enum DiscoveryRoute: Hashable {
    case genreBrowse
}

/// Main discovery screen with trending and popular content
struct DiscoveryView: View {
    @Environment(\.themeManager) private var themeManager
    @Environment(\.deepLinkManager) private var deepLinkManager
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
                .navigationDestination(for: Genre.self) { genre in
                    GenreResultsView(genre: genre)
                }
                .navigationDestination(for: DiscoveryRoute.self) { route in
                    switch route {
                    case .genreBrowse:
                        GenreBrowseView(genres: viewModel.genres)
                    }
                }
                .refreshable {
                    await viewModel.refresh()
                }
                .toolbar {
                    ToolbarItem(placement: .largeTitle) {
                        AnimatedGradientText(text: "Plotline")
                    }
                }
        }
        .environment(\.navigationNamespace, namespace)
        .preferredColorScheme(themeManager.colorScheme)
        .task {
            await viewModel.loadContent()
        }
        .onChange(of: deepLinkManager.pendingMediaItem) { _, newItem in
            if let item = newItem {
                navigationPath.append(item)
                deepLinkManager.pendingMediaItem = nil
            }
        }
        .onChange(of: deepLinkManager.pendingSearchQuery) { _, newQuery in
            if let query = newQuery {
                viewModel.searchText = query
                viewModel.search()
                deepLinkManager.pendingSearchQuery = nil
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if viewModel.isSearchActive {
            searchResultsView
        } else {
            mainContentView
        }
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContentView: some View {
        if viewModel.isLoading && !viewModel.hasContent {
            DiscoverySkeletonView()
        } else if let error = viewModel.errorMessage, !viewModel.hasContent {
            errorView(message: error)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 28) {
                    // Personalized daily pick
                    DailyPickView()

                    // Browse by Genre
                    NavigationLink(value: DiscoveryRoute.genreBrowse) {
                        GenreBrowseCard()
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)

                    MediaSection(title: "Trending Movies", items: viewModel.trendingMovies)
                    MediaSection(title: "Trending Series", items: viewModel.trendingSeries)

                    if !viewModel.topRatedMovies.isEmpty {
                        MediaSection(title: "Top Rated Movies", items: viewModel.topRatedMovies)
                    }

                    if !viewModel.topRatedSeries.isEmpty {
                        MediaSection(title: "Top Rated Series", items: viewModel.topRatedSeries)
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
        // States: typing (debouncing) -> searching (loading) -> results or empty
        if viewModel.isSearching {
            SearchResultsSkeletonView()
        } else if !viewModel.hasSearched {
            // Waiting for debounce delay - show nothing while user types
            Color.clear
        } else if viewModel.searchResults.isEmpty {
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
                        }
                        .matchedTransitionSource(id: item.id, in: namespace)
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
        }
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
                        .frame(width: 60, height: 90)
                        .clipped()

                case .failure:
                    Rectangle()
                        .fill(Color.plotlineCard)
                        .overlay {
                            Image(systemName: item.isTVSeries ? "tv" : "film")
                                .foregroundStyle(.secondary)
                        }

                @unknown default:
                    Rectangle()
                        .fill(Color.plotlineCard)
                }
            }
            .frame(width: 60, height: 90)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.displayTitle)
                    .font(.system(.headline, weight: .semibold))
                    .foregroundStyle(.primary)
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
                            .foregroundStyle(.primary)
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

// MARK: - Genre Browse Card

/// Prominent card linking to genre browsing
struct GenreBrowseCard: View {
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.plotlinePrimary, Color.plotlineSecondaryAccent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)

                Image(systemName: "square.grid.2x2")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Browse by Genre")
                    .font(.system(.headline, weight: .bold))
                    .foregroundStyle(.primary)

                Text("Discover movies and series by category")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color.plotlineCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Preview

#Preview {
    DiscoveryView()
}
