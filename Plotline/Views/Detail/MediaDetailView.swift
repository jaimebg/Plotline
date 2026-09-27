import SwiftUI

/// Detail view for movies and TV series
struct MediaDetailView: View {
    @Environment(\.themeManager) private var themeManager
    @Environment(\.favoritesManager) private var favoritesManager
    @Environment(\.watchlistManager) private var watchlistManager
    @State private var viewModel: MediaDetailViewModel
    @State private var titleVisible: Bool = false
    @State private var favoriteAnimationTrigger = false

    private let headerHeight: CGFloat = 280
    private let titleCollapseThreshold: CGFloat = 180

    init(media: MediaItem) {
        _viewModel = State(initialValue: MediaDetailViewModel(media: media))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Immersive header (backdrop only)
                headerSection

                // Content
                VStack(alignment: .leading, spacing: 24) {
                    // Title section, which now carries the rating too
                    titleSection
                        .opacity(titleVisible ? 0 : 1)

                    // Overview
                    overviewSection

                    // Where to watch. Answers "can I watch this", which comes
                    // before the analysis below answers "will I like it" —
                    // and applies to movies as well as series. Hidden until
                    // the load completes so it never shows a false "not
                    // available here" while the request is in flight.
                    if !viewModel.availableWatchRegions.isEmpty {
                        WatchProvidersSection(
                            availability: viewModel.watchAvailability,
                            region: viewModel.watchRegion,
                            regions: viewModel.availableWatchRegions,
                            onRegionChange: { viewModel.changeWatchRegion($0) }
                        )
                    }

                    // Series-specific content. Plotline's own analysis renders
                    // above the recommendations shelf below: it's the app's
                    // argument over a catalogue listing, so it doesn't sit
                    // under borrowed TMDB content.
                    if viewModel.isTVSeries {
                        // Plotline's own analysis. Outside the grid's gate on
                        // purpose: for the series the bundle covers this needs
                        // no network at all, and hiding it behind a fetch would
                        // repeat a mistake this project already had to fix on
                        // Discover.
                        SeriesAnalysisSection(
                            result: viewModel.analysis,
                            failedSeasons: viewModel.failedSeasons,
                            hasEnded: viewModel.media.hasEnded,
                            nextEpisodeDate: viewModel.nextScheduledAirDate(),
                            onRetry: { Task { await viewModel.retryEpisodes() } }
                        )

                        // Interactive quality curve, then the full-season grid
                        if viewModel.shouldShowEpisodeGrid {
                            let seasonAverages = viewModel.seasonAverages()
                            let standouts = viewModel.standoutIndex

                            seriesGraphSection(seasonAverages: seasonAverages, standouts: standouts)

                            // Not twice: when the analysis above is already the
                            // refusal for these seasons, it carries the retry.
                            if !viewModel.failedSeasons.isEmpty,
                               viewModel.analysis != .insufficientData(.seasonsNotLoaded) {
                                failedSeasonsNotice
                            }

                            EpisodeRatingsGridView(
                                episodesBySeason: viewModel.episodesBySeason,
                                totalSeasons: viewModel.totalSeasons,
                                seasonAverages: seasonAverages,
                                standouts: standouts
                            )
                        } else if viewModel.isLoadingAllSeasons {
                            episodeGridLoadingView
                        } else if let message = viewModel.episodesError {
                            episodeGridUnavailableView(message: message)
                        }
                    }

                    // Recommendations
                    if !viewModel.recommendations.isEmpty {
                        MediaSection(title: "You Might Also Like", items: viewModel.recommendations)
                    }

                    // Movie-specific content
                    if !viewModel.isTVSeries {
                        movieFeaturesSection
                    }
                }
                .padding()
                .padding(.top, -20) // Overlap with gradient for seamless transition
                .readableWidth()
            }
        }
        // Fires only when the answer flips, not on every scrolled frame: the
        // old preference-key version wrote a state value and opened an
        // animation transaction per frame for a value nothing read.
        .onScrollGeometryChange(for: Bool.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top > titleCollapseThreshold
        } action: { _, isPastThreshold in
            withAnimation(.easeInOut(duration: 0.2)) {
                titleVisible = isPastThreshold
            }
        }
        .background(Color.plotlineBackground)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(titleVisible ? .visible : .hidden, for: .navigationBar)
        .toolbarBackground(Color.plotlineBackground, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(viewModel.media.displayTitle)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .opacity(titleVisible ? 1 : 0)
            }

            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 16) {
                    watchlistMenuButton

                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            favoritesManager.toggleFavorite(viewModel.media)
                            favoriteAnimationTrigger.toggle()
                        }
                    } label: {
                        Image(systemName: favoritesManager.isFavorite(viewModel.media) ? "heart.fill" : "heart")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(favoritesManager.isFavorite(viewModel.media) ? .red : .primary)
                            .symbolEffect(.bounce, value: favoriteAnimationTrigger)
                    }
                    .accessibilityLabel(favoritesManager.isFavorite(viewModel.media) ? "Remove from favorites" : "Add to favorites")
                }
            }
        }
        .preferredColorScheme(themeManager.colorScheme)
        .task {
            await viewModel.loadDetails()
        }
    }

    // MARK: - Watchlist Menu

    private var watchlistMenuButton: some View {
        Menu {
            if watchlistManager.isOnWatchlist(viewModel.media) {
                let currentStatus = watchlistManager.watchlistStatus(for: viewModel.media)

                Button {
                    watchlistManager.updateStatus(tmdbId: viewModel.media.id, status: "want_to_watch")
                } label: {
                    Label("Want to Watch", systemImage: currentStatus == "want_to_watch" ? "checkmark" : "eye")
                }

                Button {
                    watchlistManager.updateStatus(tmdbId: viewModel.media.id, status: "watched")
                } label: {
                    Label("Watched", systemImage: currentStatus == "watched" ? "checkmark" : "checkmark.circle")
                }

                Divider()

                Button(role: .destructive) {
                    watchlistManager.removeFromWatchlist(viewModel.media)
                } label: {
                    Label("Remove from Watchlist", systemImage: "trash")
                }
            } else {
                Button {
                    watchlistManager.addToWatchlist(viewModel.media, status: "want_to_watch")
                } label: {
                    Label("Want to Watch", systemImage: "eye")
                }

                Button {
                    watchlistManager.addToWatchlist(viewModel.media, status: "watched")
                } label: {
                    Label("Watched", systemImage: "checkmark.circle")
                }
            }
        } label: {
            Image(systemName: watchlistManager.isOnWatchlist(viewModel.media) ? "eye.fill" : "eye")
                .font(.body.weight(.semibold))
                .foregroundStyle(watchlistManager.isOnWatchlist(viewModel.media) ? Color.plotlineAccent : .primary)
                .accessibilityLabel(watchlistManager.isOnWatchlist(viewModel.media) ? "Watchlist options, currently on watchlist" : "Add to watchlist")
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        GeometryReader { geometry in
            let minY = geometry.frame(in: .global).minY
            let isScrolledUp = minY < 0

            ZStack(alignment: .bottom) {
                // Backdrop image
                backdropImage
                    .frame(
                        width: geometry.size.width,
                        height: isScrolledUp ? headerHeight : headerHeight + minY
                    )
                    .offset(y: isScrolledUp ? 0 : -minY)

                // Gradient overlay for smooth transition to content
                LinearGradient(
                    colors: [
                        .clear,
                        .clear,
                        Color.plotlineBackground.opacity(0.7),
                        Color.plotlineBackground
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .frame(height: headerHeight)
        .accessibilityHidden(true)
    }

    // MARK: - Title Section

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Media type badge
            Text(viewModel.media.isTVSeries ? "TV SERIES" : "MOVIE")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Color.plotlineGoldText)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.plotlineCard.opacity(0.8))
                .clipShape(Capsule())

            // Title
            Text(viewModel.media.displayTitle)
                .font(.system(.title, weight: .bold))
                .foregroundStyle(.primary)

            // Metadata row. The rating lives here rather than in a section of
            // its own: TMDB is the only source this app has, and a heading over
            // a single tile was the leftover of a two-source layout. The source
            // is named in the accessibility label rather than on screen — a
            // third visible item pushed this row into truncating at large text
            // sizes. Nothing on this screen names TMDB visually any more.
            HStack(spacing: 12) {
                if let year = viewModel.media.year {
                    Label(year, systemImage: "calendar")
                        .font(.subheadline)
                        .foregroundStyle(.primary.opacity(0.9))
                }

                if let totalSeasons = viewModel.media.totalSeasons, viewModel.media.isTVSeries {
                    Label(totalSeasons == 1 ? "1 Season" : "\(totalSeasons) Seasons", systemImage: "film.stack")
                        .font(.subheadline)
                        .foregroundStyle(.primary.opacity(0.9))
                }

                if viewModel.media.voteAverage > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .foregroundStyle(Color.imdbYellow)

                        Text(viewModel.media.formattedRating)
                            .foregroundStyle(.primary.opacity(0.9))
                    }
                    .font(.subheadline)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Rated \(viewModel.media.formattedRating) out of 10 on TMDB")
                }
            }
            .labelStyle(.titleAndIcon)
        }
    }

    // MARK: - Backdrop Image

    @ViewBuilder
    private var backdropImage: some View {
        AsyncImage(url: viewModel.media.backdropURL) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            case .failure:
                fallbackView
            case .empty:
                Rectangle()
                    .fill(Color.plotlineCard)
                    .shimmering()
            @unknown default:
                Rectangle()
                    .fill(Color.plotlineCard)
            }
        }
    }

    // MARK: - Fallback View

    private var fallbackView: some View {
        ZStack {
            if let posterURL = viewModel.media.posterURL {
                AsyncImage(url: posterURL) { phase in
                    if case .success(let image) = phase {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .blur(radius: 20)
                            .overlay(Color.black.opacity(0.3))
                    } else {
                        Color.plotlineCard
                    }
                }
            } else {
                Color.plotlineCard
            }

            Image(systemName: viewModel.media.isTVSeries ? "tv" : "film")
                .font(.largeTitle)
                .imageScale(.large)
                .foregroundStyle(.primary.opacity(0.3))
        }
    }

    // MARK: - Overview Section

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Overview")
                .font(.system(.headline, weight: .semibold))
                .foregroundStyle(.primary)

            Text(viewModel.media.overview)
                .font(.body)
                .foregroundStyle(.secondary)
                .lineSpacing(4)
        }
    }

    // MARK: - Movie Features Section

    @ViewBuilder
    private var movieFeaturesSection: some View {
        // Awards return in Phase 3, sourced from the bundled dataset.
        // AwardsView stays in the codebase, dormant until then.

        // Box Office
        if viewModel.hasBoxOffice, let boxOffice = viewModel.boxOffice {
            BoxOfficeView(boxOffice: boxOffice)
        }

        // Franchise Timeline
        if viewModel.hasCollectionData, let collectionName = viewModel.media.collectionName {
            FranchiseTimelineView(
                movies: viewModel.collectionMovies,
                collectionName: collectionName,
                currentMovieId: viewModel.media.id,
                isLoading: viewModel.isLoadingCollection
            )
        }

        // Filmography
        if viewModel.hasFilmographyData {
            FilmographyView(
                selectedType: Binding(
                    get: { viewModel.selectedFilmographyType },
                    set: { viewModel.selectedFilmographyType = $0 }
                ),
                directorName: viewModel.director?.name,
                directorId: viewModel.director?.id,
                actorName: viewModel.leadActor?.name,
                actorId: viewModel.leadActor?.id,
                directorFilmography: viewModel.directorFilmography,
                actorFilmography: viewModel.actorFilmography,
                isLoading: viewModel.isLoadingFilmography
            )
        }
    }

    // MARK: - Series Quality Graph

    private var seasonBinding: Binding<Int> {
        Binding(
            get: { viewModel.selectedSeason },
            set: { viewModel.selectSeason($0) }
        )
    }

    /// Interactive per-season quality curve. Hidden when the selected season
    /// came back without episodes, so the chart never renders an empty axis.
    @ViewBuilder
    private func seriesGraphSection(seasonAverages: [Int: Double], standouts: StandoutIndex) -> some View {
        if !viewModel.episodes.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                if viewModel.availableSeasons.count > 1 {
                    Picker("Season", selection: seasonBinding) {
                        ForEach(viewModel.availableSeasons, id: \.self) { season in
                            Text("Season \(season)").tag(season)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(Color.plotlineGold)
                    .accessibilityLabel("Season")
                    .accessibilityHint("Choose which season to chart")
                }

                SeriesGraphView(
                    episodes: viewModel.episodes,
                    seasonNumber: viewModel.selectedSeason,
                    seasonAverage: seasonAverages[viewModel.selectedSeason],
                    standouts: standouts.directions(inSeason: viewModel.selectedSeason)
                )
            }
        }
    }

    // MARK: - Episode Grid Loading

    private var episodeGridLoadingView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Episode Scores")
                .font(.system(.headline, weight: .semibold))
                .foregroundStyle(.primary)

            // Cells share the width that is actually there. Five fixed 58pt
            // cells plus the label came to 358pt, wider than a 375pt iPhone
            // once the screen's own padding is taken off.
            VStack(spacing: 6) {
                ForEach(0..<8, id: \.self) { _ in
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.plotlineCard)
                            .frame(width: 32, height: 36)
                        ForEach(0..<5, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.plotlineCard)
                                .frame(maxWidth: 58, minHeight: 36, maxHeight: 36)
                        }
                    }
                    .shimmering()
                }
            }
            .accessibilityHidden(true)
        }
    }

    // MARK: - Failed Seasons

    /// Some seasons loaded and some did not. The grid marks the missing ones
    /// with "?", but says nothing about why or what to do; this does.
    private var failedSeasonsNotice: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Label {
                Text(SeriesAnalysisSection.seasonsNotLoadedNotice(viewModel.failedSeasons))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Button("Try Again") {
                Task { await viewModel.retryEpisodes() }
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isLoadingAllSeasons)
        }
        .padding()
        .background(Color.plotlineCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .contain)
    }

    // MARK: - Episode Grid Unavailable

    /// Shown when no season data could be loaded, so the series section never
    /// renders as a silent blank space.
    private func episodeGridUnavailableView(message: String) -> some View {
        ContentUnavailableView {
            Label("Episode Scores Unavailable", systemImage: "chart.bar.xaxis")
        } description: {
            Text(message)
        } actions: {
            Button("Try Again") {
                Task { await viewModel.retryEpisodes() }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        // `.contain` keeps the description and the Try Again button individually
        // reachable, so the message is not repeated by the container label.
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Episode scores unavailable")
    }
}

// MARK: - Preview

#Preview("TV Series Detail") {
    NavigationStack {
        MediaDetailView(media: .preview)
    }
}

#Preview("Movie Detail") {
    NavigationStack {
        MediaDetailView(media: .moviePreview)
    }
}
