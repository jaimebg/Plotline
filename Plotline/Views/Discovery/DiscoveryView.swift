import SwiftUI

/// Main discovery screen with trending and popular content
struct DiscoveryView: View {
    @Environment(\.themeManager) private var themeManager
    @Environment(\.deepLinkManager) private var deepLinkManager
    @Environment(\.favoritesManager) private var favoritesManager
    @Environment(\.watchlistManager) private var watchlistManager
    @State private var viewModel = DiscoveryViewModel()
    @State private var tasteProfileVM = TasteProfileViewModel()
    @State private var smartListsVM = SmartListsViewModel()
    @State private var showWhatToWatch = false
    /// True from the moment the user taps the search field until they cancel.
    /// Drives nothing but which of `content`'s branches renders behind the
    /// field; the query itself still decides everything below that.
    @State private var isSearchPresented = false
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
                    isPresented: $isSearchPresented,
                    prompt: "Search movies and series"
                )
                .onChange(of: viewModel.searchText) { _, _ in
                    viewModel.search()
                }
                .navigationDestination(for: MediaItem.self) { item in
                    MediaDetailView(media: item)
                        .navigationTransition(.zoom(sourceID: item.id, in: namespace))
                }
                .navigationDestination(for: CuratedGenre.self) { genre in
                    GenreResultsView(genre: genre)
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
        .task {
            await tasteProfileVM.computeProfile(
                favorites: favoritesManager.favorites,
                watchlistItems: watchlistManager.watchlistItems
            )
        }
        .task(id: tasteProfileVM.hasEnoughData) {
            guard tasteProfileVM.hasEnoughData else { return }
            let genreIds = tasteProfileVM.topGenres.compactMap { genre -> Int? in
                GenreLookup.genres.first(where: { $0.value == genre.genre })?.key
            }
            await smartListsVM.loadLists(
                favorites: favoritesManager.favorites,
                favoriteIds: favoritesManager.favoriteIds,
                watchlistIds: watchlistManager.watchlistIds,
                topGenreIds: genreIds
            )
        }
        .sheet(isPresented: $showWhatToWatch) {
            WhatToWatchView()
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

    /// `isSearchPresented` alone would not do. The deep-link handler below
    /// writes `searchText` and searches without ever presenting the field, so
    /// gating on the binding would land a deep-linked query on the main feed
    /// with results it never shows. The binding only decides what an *empty*
    /// query looks like; a query with text behaves as it always has.
    @ViewBuilder
    private var content: some View {
        if isSearchPresented || viewModel.isSearchActive {
            if viewModel.isSearchActive {
                searchResultsView
            } else {
                searchIdleView
            }
        } else {
            mainContentView
        }
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContentView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 28) {
                curatedShelves

                networkSections
            }
            .padding(.vertical)
        }
        .scrollIndicators(.hidden)
    }

    /// Everything that depends on TMDB, with its own loading and failure
    /// states. When these fail the curated shelves above are still on screen.
    ///
    /// The failure branch and the trending section carry accessibility
    /// identifiers because they are the only place in the app where "TMDB
    /// answered" and "TMDB gave us nothing" are distinguishable from outside
    /// the process. `ColdStartUITests` reads them to prove each of its two
    /// passes ran in the mode it claims.
    @ViewBuilder
    private var networkSections: some View {
        if viewModel.isLoading && !viewModel.hasContent {
            DiscoverySkeletonView()
        } else if let error = viewModel.errorMessage, !viewModel.hasContent {
            errorView(message: error)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier(AccessibilityAnchors.discoverNetworkError)
        } else {
            // Taste Profile Card
            if tasteProfileVM.hasEnoughData {
                NavigationLink {
                    TasteProfileView(viewModel: tasteProfileVM)
                } label: {
                    TasteProfileCard(
                        topGenres: tasteProfileVM.topGenres,
                        tasteTags: tasteProfileVM.tasteTags,
                        hasEnoughData: tasteProfileVM.hasEnoughData
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
            }

            // What Should I Watch? button
            if tasteProfileVM.hasEnoughData {
                Button {
                    showWhatToWatch = true
                } label: {
                    HStack {
                        Image(systemName: "sparkle.magnifyingglass")
                            .font(.title3)
                        Text("What Should I Watch?")
                            .font(.headline)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .padding()
                    .background(Color.plotlineCard)
                    .foregroundStyle(Color.plotlineGold)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
            }

            // Smart Lists
            SmartListsView(viewModel: smartListsVM)

            MediaSection(title: "Trending Movies", items: viewModel.trendingMovies)
                .accessibilityIdentifier(AccessibilityAnchors.discoverTrendingMovies)
            MediaSection(title: "Trending Series", items: viewModel.trendingSeries)

            if !viewModel.topRatedMovies.isEmpty {
                MediaSection(title: "Top Rated Movies", items: viewModel.topRatedMovies)
            }

            if !viewModel.topRatedSeries.isEmpty {
                MediaSection(title: "Top Rated Series", items: viewModel.topRatedSeries)
            }
        }
    }

    // MARK: - Curated Shelves

    /// Plotline's own analysis, shipped in the bundle. These render instantly,
    /// with no network and no user data, which is what keeps the first launch
    /// from being an empty screen.
    @ViewBuilder
    private var curatedShelves: some View {
        ForEach(DatasetStore.shared.lists) { list in
            if let title = CuratedListCopy.title(for: list.id) {
                VStack(alignment: .leading, spacing: 0) {
                    MediaSection(
                        title: title,
                        subtitle: CuratedListCopy.subtitle(for: list.id),
                        items: DatasetStore.shared.entries(for: list).map(\.asMediaItem)
                    )
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel(title)
                .accessibilityHint(CuratedListCopy.subtitle(for: list.id) ?? "")
                .accessibilityIdentifier(AccessibilityAnchors.discoverShelf)
            }
        }
    }

    // MARK: - Search, Nothing Typed Yet

    /// What the search field opens onto before there is a query: every genre,
    /// one tap from results. It needs no network, no API key and no saved data,
    /// so it renders whatever TMDB is doing.
    private var searchIdleView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Browse by Genre")
                    .font(.system(.title3, weight: .bold))
                    .foregroundStyle(.primary)

                GenreGrid(genres: viewModel.genres) { genre in
                    pushAfterSearchCloses(genre)
                }
            }
            .padding()
        }
        .scrollIndicators(.hidden)
    }

    /// Pushes a genre picked from the search state, once search has closed.
    ///
    /// The wait is not padding. On iPad the same tap collapses the tab-bar
    /// search field, and a push issued while that collapse is in flight is
    /// lost: the entry stays in `navigationPath` but the stack never renders
    /// it, so testing the path for emptiness cannot detect the loss and
    /// re-issue it. Measured, not assumed — the button fires, its other state
    /// writes stick, and the same genre pushes fine from the feed. Pushing
    /// once, after the collapse, is the only ordering that survives.
    /// iPhone keeps its search field inline, has no collapse to wait for, and
    /// pushes immediately — the idiom check is there so the primary device
    /// never pays for the iPad workaround. 300ms was measured as too short and
    /// 600ms as enough.
    private func pushAfterSearchCloses(_ genre: CuratedGenre) {
        guard UIDevice.current.userInterfaceIdiom == .pad else {
            navigationPath.append(genre)
            return
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))
            navigationPath.append(genre)
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
                .accessibilityHidden(true)
        }
        .padding()
        .background(Color.plotlineCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(searchResultAccessibilityLabel)
    }

    private var searchResultAccessibilityLabel: String {
        var label = item.displayTitle
        if let year = item.year { label += ", \(year)" }
        label += ", \(item.isTVSeries ? "TV Series" : "Movie")"
        if item.voteAverage > 0 { label += ", rated \(item.formattedRating) out of 10" }
        return label
    }
}

// MARK: - Preview

#Preview {
    DiscoveryView()
}
