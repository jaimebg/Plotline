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

    /// Season numbers whose fetch failed on the last `fetchAllSeasons()` —
    /// after `NetworkManager`'s own 429 retries. Distinct from a season that
    /// loaded empty; a non-empty list means `episodesBySeason` is incomplete.
    private(set) var failedSeasons: [Int] = []

    /// Where the analysis on screen came from. The bundled copy appears
    /// instantly and offline; a live recomputation replaces it as soon as
    /// TMDB's episodes arrive.
    enum AnalysisSource: Equatable {
        case bundled
        case live
    }

    var analysis: SeriesAnalysisResult?
    private(set) var analysisSource: AnalysisSource = .bundled

    /// Set once a full `loadDetails()` has run to completion. The screen's
    /// `.task` fires again every time it reappears — popping back from a
    /// recommendation, say — and a second load refetched everything and
    /// re-seeded the bundled analysis over the live one, so the verdicts
    /// flickered. Explicit retries go through `retryEpisodes()` instead.
    private(set) var hasLoadedDetails = false

    // MARK: - Watch Providers State

    var watchAvailability: RegionAvailability?
    private(set) var availableWatchRegions: [String] = []
    private var allWatchRegions: [String: RegionAvailability] = [:]

    /// The region the availability above belongs to.
    ///
    /// Held here rather than read from `WatchRegionStore` inside the view's
    /// body. The store is a plain singleton, so a body re-evaluation triggered
    /// by anything else — a scroll, a sibling screen changing region — would
    /// redraw the label from the store while the providers still came from the
    /// region they were fetched for, labelling one country's catalogue with
    /// another's name.
    private(set) var watchRegion: String = WatchRegionStore.shared.selected

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
        guard !hasLoadedDetails else { return }

        // Seed from the bundle only while nothing better is on screen. A live
        // analysis from an earlier, cancelled load must not be swapped back.
        if analysis == nil {
            loadBundledAnalysis()
        }

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

        // A load cut short — the screen was left before it finished, which
        // cancels `.task` — has not loaded anything worth keeping, so the next
        // appearance tries again.
        hasLoadedDetails = !Task.isCancelled
    }

    /// Explicit retry after some or all seasons failed to load.
    ///
    /// Refetches the series details first when they never arrived: without
    /// them `totalSeasons` is still the default of 1, and a retry would ask for
    /// season 1 alone and call that complete.
    @MainActor
    func retryEpisodes() async {
        guard media.isTVSeries else { return }
        if !hasLoadedSeriesDetails {
            await fetchTMDBDetails()
        }
        await fetchAllSeasons()
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

        let fetched = await tmdbService.fetchAllSeasons(
            seriesId: media.id,
            totalSeasons: totalSeasons
        )
        applySeasonFetch(fetched)

        isLoadingAllSeasons = false
    }

    /// Folds a season fetch into the screen's state and re-runs the analysis.
    ///
    /// Split from `fetchAllSeasons()` so the partial-fetch path can be tested
    /// without a network: `TMDBService` has no seam to stand a double in for.
    ///
    /// - Parameter now: explicit so the result never depends on the clock.
    @MainActor
    func applySeasonFetch(_ fetched: SeasonFetchResult, asOf now: Date = Date()) {
        // A retry that fails outright must not wipe seasons an earlier attempt
        // did load; merge rather than replace. The rule is shared with Compare.
        let merged = LiveSeriesAnalysis.merge(fetched, into: episodesBySeason)
        episodesBySeason = merged.episodesBySeason
        failedSeasons = merged.failedSeasons

        // An empty dictionary means "nothing to show": no network, no API key,
        // or a series TMDB has no episode data for.
        if episodesBySeason.isEmpty {
            episodesError = "We couldn't load episode scores for this series. It may not have episode data yet."
        }

        // Seasons that failed are absent from the dictionary, so the default
        // selection may point at a season with nothing to show.
        if episodesBySeason[selectedSeason] == nil, let firstAvailable = availableSeasons.first {
            selectedSeason = firstAvailable
        }

        syncEpisodesForSelectedSeason()

        recomputeAnalysis(asOf: now)

        // Computed once per fetch rather than per body pass: it walks every
        // episode of every season.
        let allEpisodes = episodesBySeason.values.flatMap { $0 }
        let comparison = CrewEffectAnalyzer.compare(episodes: allEpisodes, asOf: now)
        crewComparison = comparison.isEmpty ? nil : comparison

        // After `recomputeAnalysis`, so the split uses the decline on screen.
        watchTimePlan = WatchTimePlanner.plan(
            episodes: allEpisodes,
            declinePoint: analyzedResult?.declinePoint,
            asOf: now
        )
    }

    /// Runtime totals for the aired run. Nil when too few runtimes are known.
    private(set) var watchTimePlan: WatchTimePlan?

    /// The watch-time plan, only when every season loaded: a missing season
    /// would make the total quietly short.
    var visibleWatchTimePlan: WatchTimePlan? {
        guard failedSeasons.isEmpty else { return nil }
        return watchTimePlan
    }

    /// Directors and writers against their seasons, from the loaded episodes.
    /// Nil when nobody qualifies.
    private(set) var crewComparison: CrewComparison?

    /// The crew comparison, only when it can stand next to the analysis: with
    /// a full analysis on screen and every season loaded. A missing season
    /// would change both the people counted and the averages they are
    /// measured against.
    var visibleCrewComparison: CrewComparison? {
        guard analyzedResult != nil, failedSeasons.isEmpty else { return nil }
        return crewComparison
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

        // Shared with Compare, so the two screens can never disagree about
        // when a live result may replace the one on screen.
        guard let fresh = LiveSeriesAnalysis.replacement(
            for: analysis,
            episodesBySeason: episodesBySeason,
            failedSeasons: failedSeasons,
            hasEnded: media.hasEnded,
            asOf: now
        ) else { return }

        analysis = fresh
        analysisSource = .live
    }

    /// Each loaded season's average, defined exactly as the verdicts define it.
    ///
    /// Where the analysis on screen has a summary for the season, its figure is
    /// used verbatim, so the chart, the grid and the verdicts can never show
    /// three different numbers for one season. Other seasons fall back to the
    /// engine's own definition over the loaded episodes — vote-weighted, only
    /// episodes with enough votes — so the meaning of "average" never changes.
    func seasonAverages(asOf now: Date = Date()) -> [Int: Double] {
        var averages: [Int: Double] = [:]
        for (season, episodes) in episodesBySeason {
            averages[season] = SeriesAnalysisEngine.seasonAverage(of: episodes, asOf: now)
        }
        if case .analyzed(let current)? = analysis {
            for summary in current.seasons {
                averages[summary.seasonNumber] = summary.weightedAverage
            }
        }
        return averages
    }

    /// The analysis on screen, when it is a full one.
    var analyzedResult: SeriesAnalysis? {
        if case .analyzed(let value)? = analysis { return value }
        return nil
    }

    /// The analysis's season highs and lows, indexed for the chart and grid.
    var standoutIndex: StandoutIndex {
        StandoutIndex(analysis: analyzedResult)
    }

    /// The earliest future air date known for a main-run episode, from TMDB's
    /// `next_episode_to_air` or from the loaded seasons. Nil when nothing is
    /// dated — a missing date is not a schedule.
    func nextScheduledAirDate(asOf now: Date = Date()) -> Date? {
        var candidates = episodesBySeason
            .filter { $0.key > 0 }
            .values
            .flatMap { $0 }
            .compactMap(\.airDateValue)
        if let announced = media.nextEpisodeAirDate.flatMap(EpisodeMetric.parseAirDate) {
            candidates.append(announced)
        }
        return candidates.filter { $0 > now }.min()
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
        // Derived, not read: TMDB sends `media_type` on /trending and
        // /search/multi and omits it from /movie/top_rated, /tv/top_rated and
        // every /discover payload. Guarding on the field left the section
        // missing from most of the ways into this screen, while the two paths
        // it was tested on happened to carry it.
        let mediaType: MediaType = media.isTVSeries ? .tv : .movie

        guard let results = try? await tmdbService.fetchWatchProviders(mediaType: mediaType, id: media.id) else {
            return
        }

        allWatchRegions = results
        watchRegion = WatchRegionStore.shared.selected
        availableWatchRegions = Self.selectableRegions(from: results, including: watchRegion)
        watchAvailability = results[watchRegion]
    }

    /// The regions offered in the picker.
    ///
    /// The response only lists regions the title *is* available in, so a user
    /// whose own region is not among them would open the picker and not find
    /// it — able to look anywhere except home, with the choice persisted and
    /// no way back. Their region is always included, even when the answer it
    /// gives is "not here".
    static func selectableRegions(
        from results: [String: RegionAvailability],
        including current: String
    ) -> [String] {
        Set(results.keys).union([current]).sorted()
    }

    /// Reindexes the response already in memory. The cached payload carries
    /// every region, so switching costs no request.
    @MainActor
    func changeWatchRegion(_ region: String) {
        WatchRegionStore.shared.selected = region
        watchRegion = region
        availableWatchRegions = Self.selectableRegions(from: allWatchRegions, including: region)
        watchAvailability = allWatchRegions[region]
    }

    // MARK: - Private Methods

    /// Whether a series detail payload has been merged, so `totalSeasons`
    /// reflects TMDB rather than the default.
    private var hasLoadedSeriesDetails = false

    @MainActor
    private func fetchTMDBDetails() async {
        do {
            let details = try await tmdbService.fetchDetails(for: media)
            applyDetails(details)
            hasLoadedSeriesDetails = true
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

            // Taken as-is, nil included: a fresh payload with no next episode
            // means none is scheduled any more.
            media.nextEpisodeAirDate = details.nextEpisodeAirDate

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

    /// Array of season numbers for picker. Empty rather than a trap when TMDB
    /// reports zero seasons.
    var seasonNumbers: [Int] {
        totalSeasons > 0 ? Array(1...totalSeasons) : []
    }

    /// Seasons that actually came back with episodes. Seasons TMDB failed to
    /// return are absent, so the picker must not offer them.
    var availableSeasons: [Int] {
        episodesBySeason.keys.sorted()
    }

    /// Average episode rating for the current season, defined as the
    /// verdicts define it (see `seasonAverages(asOf:)`).
    var averageEpisodeRating: Double? {
        seasonAverages()[selectedSeason]
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
