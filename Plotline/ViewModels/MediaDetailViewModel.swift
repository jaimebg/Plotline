import Foundation
import Observation

/// Filmography type selector
enum FilmographyType: String, CaseIterable {
    case director = "Director"
    case actor = "Lead Actor"
}

/// ViewModel for the Media Detail screen
@Observable
final class MediaDetailViewModel {
    // MARK: - State

    var media: MediaItem
    var episodes: [EpisodeMetric] = []
    var episodesBySeason: [Int: [EpisodeMetric]] = [:]
    var selectedSeason: Int = 1
    var totalSeasons: Int = 1

    var isLoadingAllSeasons = false
    var episodesError: String?

    /// Where the analysis on screen came from. The bundled copy appears
    /// instantly and offline; a live recomputation replaces it as soon as
    /// TMDB's episodes arrive.
    enum AnalysisSource: Equatable {
        case bundled
        case live
    }

    var analysis: SeriesAnalysisResult?
    private(set) var analysisSource: AnalysisSource = .bundled

    // MARK: - Watch Providers State

    var watchAvailability: RegionAvailability?
    private(set) var availableWatchRegions: [String] = []
    private var allWatchRegions: [String: RegionAvailability] = [:]

    // MARK: - Movie Features State

    // Franchise / Collection
    var collectionMovies: [CollectionMovie] = []
    var isLoadingCollection = false

    // Filmography
    var director: CrewMember?
    var leadActor: CastMember?
    var directorFilmography: [PersonCrewCredit] = []
    var actorFilmography: [PersonCastCredit] = []
    var selectedFilmographyType: FilmographyType = .director
    var isLoadingFilmography = false

    // Recommendations
    var recommendations: [MediaItem] = []
    var isLoadingRecommendations = false

    // Credits (for filmography linking)
    var credits: TMDBCreditsResponse?

    // MARK: - Services

    private let tmdbService: TMDBService

    // MARK: - Initialization

    init(
        media: MediaItem,
        tmdbService: TMDBService = .shared
    ) {
        self.media = media
        self.tmdbService = tmdbService
        self.totalSeasons = media.totalSeasons ?? 1
    }

    // MARK: - Public Methods

    /// Load all detail data (TMDB details + movie features)
    @MainActor
    func loadDetails() async {
        loadBundledAnalysis()

        // First, get TMDB details for season count and movie-specific data
        await fetchTMDBDetails()

        if media.isTVSeries {
            // `fetchAllSeasons()` already covers season 1, and `episodes` is derived
            // from its result — fetching the selected season separately would issue a
            // duplicate request for the same payload on every series open.
            async let allSeasonsTask: () = fetchAllSeasons()
            async let recsTask: () = fetchRecommendations()
            async let watchProvidersTask: () = loadWatchProviders()
            _ = await (allSeasonsTask, recsTask, watchProvidersTask)
        } else {
            async let movieFeaturesTask: () = fetchMovieFeatures()
            async let recsTask: () = fetchRecommendations()
            async let watchProvidersTask: () = loadWatchProviders()
            _ = await (movieFeaturesTask, recsTask, watchProvidersTask)
        }
    }

    /// Re-derive `episodes` for the selected season from the already-fetched
    /// season dictionary. Deliberately does no networking: `fetchAllSeasons()`
    /// is the single source of episode data.
    @MainActor
    func syncEpisodesForSelectedSeason() {
        guard media.isTVSeries else { return }
        episodes = episodesBySeason[selectedSeason] ?? []
    }

    /// Change selected season and re-derive its episodes (no network request)
    @MainActor
    func selectSeason(_ season: Int) {
        guard season != selectedSeason else { return }
        selectedSeason = season
        syncEpisodesForSelectedSeason()
    }

    /// Fetch all seasons' episodes for the grid view
    @MainActor
    func fetchAllSeasons() async {
        guard media.isTVSeries else { return }

        isLoadingAllSeasons = true
        episodesError = nil

        episodesBySeason = await tmdbService.fetchAllSeasons(
            seriesId: media.id,
            totalSeasons: totalSeasons
        )

        // `TMDBService.fetchAllSeasons` swallows per-season failures, so an empty
        // dictionary is the only signal available for "nothing to show": no network,
        // no API key, or a series TMDB has no episode data for.
        if episodesBySeason.isEmpty {
            episodesError = "We couldn't load episode scores for this series. It may not have episode data yet."
        }

        // Seasons that failed are absent from the dictionary, so the default
        // selection may point at a season with nothing to show.
        if episodesBySeason[selectedSeason] == nil, let firstAvailable = availableSeasons.first {
            selectedSeason = firstAvailable
        }

        syncEpisodesForSelectedSeason()

        recomputeAnalysis()

        isLoadingAllSeasons = false
    }

    // MARK: - Analysis

    /// Reads the analysis shipped in the app bundle, if this series is one of
    /// the titles it covers.
    ///
    /// This runs before any request, so a bundled series shows its analysis in
    /// the first frame and keeps showing it with no connection at all. It is a
    /// seed and a fallback, never the truth: `recomputeAnalysis` overwrites it
    /// the moment fresher episodes arrive.
    @MainActor
    func loadBundledAnalysis() {
        guard media.isTVSeries else { return }
        guard let entry = DatasetStore.shared.entry(forTMDBId: media.id) else { return }

        analysis = .analyzed(entry.analysis)
        analysisSource = .bundled
    }

    /// Recomputes from the episodes currently held, replacing anything the
    /// bundle provided.
    ///
    /// `media.hasEnded` is read at call time rather than passed in: by the time
    /// episodes exist, `fetchTMDBDetails()` has already populated it. It stays
    /// optional all the way down — the engine treats an unknown status as
    /// grounds to withhold the ending verdict, not as proof the show is still
    /// running.
    ///
    /// - Parameter now: explicit so the result never depends on the clock.
    @MainActor
    func recomputeAnalysis(asOf now: Date = Date()) {
        guard media.isTVSeries else { return }

        let episodes = episodesBySeason.values.flatMap { $0 }
        guard !episodes.isEmpty else { return }

        let fresh = SeriesAnalysisEngine.analyze(
            episodes: episodes,
            hasEnded: media.hasEnded,
            asOf: now
        )

        guard isAtLeastAsComplete(fresh) else { return }

        analysis = fresh
        analysisSource = .live
    }

    /// Whether a freshly-computed analysis may replace the bundled one.
    ///
    /// `TMDBService.fetchAllSeasons` swallows per-season failures, and a failed
    /// detail request leaves `totalSeasons` at 1 — so a flaky connection can
    /// hand back a single cached season for a five-season series. Assigning
    /// that unconditionally would replace a complete bundled analysis with a
    /// fragment, or with "Not Enough Ratings Yet" for a series whose full
    /// analysis is sitting in the app bundle. Fresher data wins, but only when
    /// it is not less than what we already had.
    private func isAtLeastAsComplete(_ fresh: SeriesAnalysisResult) -> Bool {
        guard analysisSource == .bundled, case .analyzed(let bundled) = analysis else {
            return true
        }
        guard case .analyzed(let live) = fresh else { return false }

        return live.seasons.count >= bundled.seasons.count
    }

    // MARK: - Watch Providers

    /// Loads streaming availability for the region currently selected in
    /// `WatchRegionStore`.
    ///
    /// Applies to movies as well as series — unlike the analysis above, half
    /// the value of this feature is on movie screens. `watchAvailability`
    /// stays nil, and the section stays hidden, until this completes: a
    /// "not available here" shown while the request is still in flight would
    /// state something untrue.
    @MainActor
    func loadWatchProviders() async {
        guard let mediaType = media.mediaType else { return }

        guard let results = try? await tmdbService.fetchWatchProviders(mediaType: mediaType, id: media.id) else {
            return
        }

        allWatchRegions = results
        availableWatchRegions = results.keys.sorted()
        watchAvailability = results[WatchRegionStore.shared.selected]
    }

    /// Reindexes the response already in memory. The cached payload carries
    /// every region, so switching costs no request.
    @MainActor
    func changeWatchRegion(_ region: String) {
        WatchRegionStore.shared.selected = region
        watchAvailability = allWatchRegions[region]
    }

    // MARK: - Private Methods

    @MainActor
    private func fetchTMDBDetails() async {
        do {
            let details = try await tmdbService.fetchDetails(for: media)
            applyDetails(details)
        } catch {
            #if DEBUG
            debugPrint("Failed to fetch TMDB details: \(error)")
            #endif
        }
    }

    /// Folds a freshly-fetched detail payload into `media`.
    ///
    /// Internal rather than private so the merge can be tested directly:
    /// `TMDBService` is a struct with no seam to stand a double in for, and
    /// this merge silently dropped `hasEnded` once already — the field only
    /// exists to reach the analysis engine, and losing it here deletes the
    /// ending verdict from every series the moment its episodes load.
    @MainActor
    func applyDetails(_ payload: MediaItem) {
        var details = payload

        // Deep link stubs have "Loading..." as title — replace media entirely
        let isStub = media.displayTitle == "Loading..." || (media.voteAverage == 0 && media.overview.isEmpty)
        if isStub {
            // Preserve any enriched fields already set on the stub
            details.budget = details.budget ?? media.budget
            details.revenue = details.revenue ?? media.revenue
            details.collectionId = details.collectionId ?? media.collectionId
            details.collectionName = details.collectionName ?? media.collectionName
            media = details
        } else {
            // Normal flow: only update enriched fields missing from the original
            media.budget = details.budget ?? media.budget
            media.revenue = details.revenue ?? media.revenue
            media.collectionId = details.collectionId ?? media.collectionId
            media.collectionName = details.collectionName ?? media.collectionName

            // The series status arrives only here — list payloads never carry
            // it — and it is the sole input that lets the engine judge an
            // ending. Dropping it leaves every live recomputation blind.
            media.hasEnded = details.hasEnded ?? media.hasEnded

            if media.overview.isEmpty && !details.overview.isEmpty {
                media.overview = details.overview
            }
            if media.posterPath == nil {
                media.posterPath = details.posterPath
            }
            if media.backdropPath == nil {
                media.backdropPath = details.backdropPath
            }
        }

        if let seasons = details.totalSeasons {
            totalSeasons = seasons
        }
    }

    /// Fetch all movie-specific features
    @MainActor
    private func fetchMovieFeatures() async {
        guard !media.isTVSeries else { return }

        async let collectionTask: () = fetchCollectionIfAvailable()
        async let creditsTask: () = fetchCreditsAndFilmography()

        _ = await (collectionTask, creditsTask)
    }

    /// Fetch collection/franchise movies if available
    @MainActor
    private func fetchCollectionIfAvailable() async {
        guard let collectionId = media.collectionId else { return }

        isLoadingCollection = true
        defer { isLoadingCollection = false }

        do {
            let collection = try await tmdbService.fetchCollection(id: collectionId)
            collectionMovies = collection.parts
                .filter { $0.releaseDate?.isEmpty == false }
                .sorted { ($0.yearInt ?? 0) < ($1.yearInt ?? 0) }
        } catch {
            #if DEBUG
            debugPrint("Failed to fetch collection: \(error)")
            #endif
        }
    }

    /// Fetch credits and filmography for director and lead actor
    @MainActor
    private func fetchCreditsAndFilmography() async {
        isLoadingFilmography = true
        defer { isLoadingFilmography = false }

        do {
            let movieCredits = try await tmdbService.fetchMovieCredits(id: media.id)
            credits = movieCredits
            director = movieCredits.crew.first { $0.job == "Director" }
            leadActor = movieCredits.cast.first

            async let directorTask: () = fetchDirectorFilmography()
            async let actorTask: () = fetchActorFilmography()
            _ = await (directorTask, actorTask)
        } catch {
            #if DEBUG
            debugPrint("Failed to fetch credits: \(error)")
            #endif
        }
    }

    /// Fetch director's filmography
    @MainActor
    private func fetchDirectorFilmography() async {
        guard let directorId = director?.id else { return }

        do {
            let credits = try await tmdbService.fetchPersonMovieCredits(personId: directorId)
            directorFilmography = Array(
                credits.crew
                    .filter { $0.isDirector && $0.title != nil && $0.id != media.id }
                    .sorted { $0.popularity > $1.popularity }
                    .prefix(15)
            )
        } catch {
            #if DEBUG
            debugPrint("Failed to fetch director filmography: \(error)")
            #endif
        }
    }

    /// Fetch lead actor's filmography
    @MainActor
    private func fetchActorFilmography() async {
        guard let actorId = leadActor?.id else { return }

        do {
            let credits = try await tmdbService.fetchPersonMovieCredits(personId: actorId)
            actorFilmography = Array(
                credits.cast
                    .filter { $0.title != nil && $0.id != media.id }
                    .sorted { $0.popularity > $1.popularity }
                    .prefix(15)
            )
        } catch {
            #if DEBUG
            debugPrint("Failed to fetch actor filmography: \(error)")
            #endif
        }
    }

    /// Fetch recommendations for this media item
    @MainActor
    private func fetchRecommendations() async {
        isLoadingRecommendations = true
        defer { isLoadingRecommendations = false }
        do {
            recommendations = Array(try await tmdbService.fetchRecommendations(for: media).prefix(10))
        } catch {
            #if DEBUG
            debugPrint("Failed to fetch recommendations: \(error)")
            #endif
        }
    }

    // MARK: - Computed Properties

    /// Check if episodes are available
    var hasEpisodes: Bool {
        !episodes.isEmpty
    }

    /// Check if episode grid should be shown
    var shouldShowEpisodeGrid: Bool {
        !episodesBySeason.isEmpty
    }

    /// Check if this is a TV series
    var isTVSeries: Bool {
        media.isTVSeries
    }

    /// Array of season numbers for picker
    var seasonNumbers: [Int] {
        Array(1...totalSeasons)
    }

    /// Seasons that actually came back with episodes. Seasons TMDB failed to
    /// return are absent, so the picker must not offer them.
    var availableSeasons: [Int] {
        episodesBySeason.keys.sorted()
    }

    /// Average episode rating for current season
    var averageEpisodeRating: Double? {
        guard !episodes.isEmpty else { return nil }
        let validEpisodes = episodes.filter { $0.hasValidRating }
        guard !validEpisodes.isEmpty else { return nil }
        let sum = validEpisodes.reduce(0.0) { $0 + $1.rating }
        return sum / Double(validEpisodes.count)
    }

    /// Highest rated episode in current season
    var highestRatedEpisode: EpisodeMetric? {
        episodes.filter { $0.hasValidRating }.max { $0.rating < $1.rating }
    }

    /// Lowest rated episode in current season
    var lowestRatedEpisode: EpisodeMetric? {
        episodes.filter { $0.hasValidRating }.min { $0.rating < $1.rating }
    }

    // MARK: - Movie Feature Computed Properties

    /// Check if this is a movie (not TV series)
    var isMovie: Bool {
        !media.isTVSeries
    }

    /// Check if collection/franchise data is available
    var hasCollectionData: Bool {
        !collectionMovies.isEmpty
    }

    /// Check if filmography data is available
    var hasFilmographyData: Bool {
        !directorFilmography.isEmpty || !actorFilmography.isEmpty
    }

    /// Check if director filmography is available
    var hasDirectorFilmography: Bool {
        !directorFilmography.isEmpty
    }

    /// Check if actor filmography is available
    var hasActorFilmography: Bool {
        !actorFilmography.isEmpty
    }

    /// Check if box office data is available
    var hasBoxOffice: Bool {
        media.boxOffice != nil
    }

    /// Box office data
    var boxOffice: BoxOfficeData? {
        media.boxOffice
    }

    /// Awards return in Phase 3, sourced from the bundled dataset.
    var hasAwards: Bool { false }

    /// Current filmography based on selected type
    var currentFilmography: [(id: Int, title: String, year: String?, rating: String, posterURL: URL?)] {
        switch selectedFilmographyType {
        case .director:
            return directorFilmography.map { credit in
                (credit.id, credit.title ?? "", credit.year, credit.formattedRating, credit.posterURL)
            }
        case .actor:
            return actorFilmography.map { credit in
                (credit.id, credit.title ?? "", credit.year, credit.formattedRating, credit.posterURL)
            }
        }
    }

    /// Name of the person for current filmography type
    var currentFilmographyPersonName: String? {
        selectedFilmographyType == .director ? director?.name : leadActor?.name
    }
}

// MARK: - Preview Helper

extension MediaDetailViewModel {
    static var preview: MediaDetailViewModel {
        let vm = MediaDetailViewModel(media: .preview)
        vm.episodes = EpisodeMetric.breakingBadS5
        vm.episodesBySeason = [
            1: EpisodeMetric.breakingBadS1,
            5: EpisodeMetric.breakingBadS5
        ]
        vm.totalSeasons = 5
        return vm
    }

    static var moviePreview: MediaDetailViewModel {
        MediaDetailViewModel(media: .moviePreview)
    }

    static var movieWithAllFeaturesPreview: MediaDetailViewModel {
        var media = MediaItem.moviePreview
        media.budget = 63_000_000
        media.revenue = 101_209_702
        media.collectionId = 1
        media.collectionName = "Test Collection"

        let vm = MediaDetailViewModel(media: media)
        vm.collectionMovies = [
            CollectionMovie(
                id: 550,
                title: "Fight Club",
                overview: nil,
                releaseDate: "1999-10-15",
                voteAverage: 8.4,
                voteCount: 25000,
                posterPath: nil,
                backdropPath: nil
            ),
            CollectionMovie(
                id: 551,
                title: "Fight Club 2",
                overview: nil,
                releaseDate: "2005-10-15",
                voteAverage: 7.2,
                voteCount: 15000,
                posterPath: nil,
                backdropPath: nil
            )
        ]
        return vm
    }
}
