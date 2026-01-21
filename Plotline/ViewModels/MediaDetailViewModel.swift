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
    var ratings: [RatingSource] = []
    var episodes: [EpisodeMetric] = []
    var episodesBySeason: [Int: [EpisodeMetric]] = [:]
    var selectedSeason: Int = 1
    var totalSeasons: Int = 1

    var isLoadingRatings = false
    var isLoadingEpisodes = false
    var isLoadingAllSeasons = false
    var ratingsError: String?
    var episodesError: String?

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

    // Awards
    var awardsData: AwardsData?

    // Credits (for filmography linking)
    var credits: TMDBCreditsResponse?

    // MARK: - Services

    private let tmdbService: TMDBService
    private let omdbService: OMDbService

    // MARK: - Initialization

    init(
        media: MediaItem,
        tmdbService: TMDBService = .shared,
        omdbService: OMDbService = .shared
    ) {
        self.media = media
        self.tmdbService = tmdbService
        self.omdbService = omdbService
        self.totalSeasons = media.totalSeasons ?? 1
    }

    // MARK: - Public Methods

    /// Load all detail data (TMDB details + OMDb ratings + movie features)
    @MainActor
    func loadDetails() async {
        // First, get TMDB details to get IMDb ID and movie-specific data
        await fetchTMDBDetails()

        // Then fetch data in parallel based on media type
        if media.isTVSeries {
            // TV Series: fetch ratings and episodes
            async let ratingsTask: () = fetchRatings()
            async let episodesTask: () = fetchEpisodesIfSeries()
            async let allSeasonsTask: () = fetchAllSeasons()
            _ = await (ratingsTask, episodesTask, allSeasonsTask)
        } else {
            // Movies: fetch ratings, awards, and movie-specific features
            async let ratingsTask: () = fetchRatings()
            async let movieFeaturesTask: () = fetchMovieFeatures()
            _ = await (ratingsTask, movieFeaturesTask)
        }
    }

    /// Fetch ratings from OMDb
    @MainActor
    func fetchRatings() async {
        guard let imdbId = media.imdbId else {
            ratingsError = "No IMDb ID available"
            return
        }

        isLoadingRatings = true
        ratingsError = nil

        do {
            ratings = try await omdbService.fetchRatings(imdbId: imdbId)
        } catch {
            ratingsError = error.localizedDescription
            debugPrint("Failed to fetch ratings: \(error)")
        }

        isLoadingRatings = false
    }

    /// Fetch episodes for current season (TV series only)
    @MainActor
    func fetchEpisodes() async {
        guard media.isTVSeries else { return }
        guard let imdbId = media.imdbId else {
            episodesError = "No IMDb ID available"
            return
        }

        isLoadingEpisodes = true
        episodesError = nil

        do {
            episodes = try await omdbService.fetchSeasonEpisodes(
                imdbId: imdbId,
                season: selectedSeason
            )
        } catch {
            episodesError = error.localizedDescription
            debugPrint("Failed to fetch episodes: \(error)")
        }

        isLoadingEpisodes = false
    }

    /// Change selected season and fetch new episodes
    @MainActor
    func selectSeason(_ season: Int) async {
        guard season != selectedSeason else { return }
        selectedSeason = season
        await fetchEpisodes()
    }

    /// Fetch all seasons' episodes for the grid view
    @MainActor
    func fetchAllSeasons() async {
        guard media.isTVSeries else { return }
        guard let imdbId = media.imdbId else {
            episodesError = "No IMDb ID available"
            return
        }

        isLoadingAllSeasons = true
        episodesError = nil

        // Get season count from OMDb (more reliable than TMDB for episode data)
        let omdbSeasonCount: Int
        do {
            let omdbDetails = try await omdbService.fetchDetails(imdbId: imdbId)
            omdbSeasonCount = omdbDetails.totalSeasonsInt ?? totalSeasons
            #if DEBUG
            if omdbSeasonCount != totalSeasons {
                print("📺 Season count differs: TMDB=\(totalSeasons), OMDb=\(omdbSeasonCount)")
            }
            #endif
        } catch {
            // Fall back to TMDB count if OMDb fails
            omdbSeasonCount = totalSeasons
            #if DEBUG
            print("⚠️ Failed to get OMDb season count, using TMDB: \(totalSeasons)")
            #endif
        }

        // Fetch all seasons concurrently using OMDb's count
        await withTaskGroup(of: (Int, [EpisodeMetric]?).self) { group in
            for season in 1...omdbSeasonCount {
                group.addTask {
                    do {
                        let episodes = try await self.omdbService.fetchSeasonEpisodes(
                            imdbId: imdbId,
                            season: season
                        )
                        return (season, episodes)
                    } catch {
                        debugPrint("Failed to fetch season \(season): \(error)")
                        return (season, nil)
                    }
                }
            }

            for await (season, episodes) in group {
                if let episodes = episodes {
                    episodesBySeason[season] = episodes
                }
            }
        }

        // Update totalSeasons to match OMDb for consistent UI
        if omdbSeasonCount != totalSeasons {
            totalSeasons = omdbSeasonCount
        }

        isLoadingAllSeasons = false
    }

    // MARK: - Private Methods

    @MainActor
    private func fetchTMDBDetails() async {
        do {
            let details = try await tmdbService.fetchDetails(for: media)

            // Update media with details using nil-coalescing to preserve existing values
            media.imdbId = details.imdbId ?? media.imdbId
            media.budget = details.budget ?? media.budget
            media.revenue = details.revenue ?? media.revenue
            media.collectionId = details.collectionId ?? media.collectionId
            media.collectionName = details.collectionName ?? media.collectionName

            // Update visual/content fields if missing (e.g., when navigating from filmography)
            if media.overview.isEmpty && !details.overview.isEmpty {
                media.overview = details.overview
            }
            if media.posterPath == nil {
                media.posterPath = details.posterPath
            }
            if media.backdropPath == nil {
                media.backdropPath = details.backdropPath
            }

            if let seasons = details.totalSeasons {
                totalSeasons = seasons
            }
        } catch {
            debugPrint("Failed to fetch TMDB details: \(error)")
        }
    }

    @MainActor
    private func fetchEpisodesIfSeries() async {
        guard media.isTVSeries else { return }
        await fetchEpisodes()
    }

    /// Fetch all movie-specific features
    @MainActor
    private func fetchMovieFeatures() async {
        guard !media.isTVSeries else { return }

        // Fetch collection, credits, and OMDb details concurrently
        async let collectionTask: () = fetchCollectionIfAvailable()
        async let creditsTask: () = fetchCreditsAndFilmography()
        async let omdbTask: () = fetchOMDbDetailsForFeatures()

        _ = await (collectionTask, creditsTask, omdbTask)
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
            debugPrint("Failed to fetch collection: \(error)")
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
            debugPrint("Failed to fetch credits: \(error)")
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
            debugPrint("Failed to fetch director filmography: \(error)")
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
            debugPrint("Failed to fetch actor filmography: \(error)")
        }
    }

    /// Fetch OMDb details for awards and score comparison
    @MainActor
    private func fetchOMDbDetailsForFeatures() async {
        guard let imdbId = media.imdbId else { return }

        do {
            let omdbDetails = try await omdbService.fetchDetails(imdbId: imdbId)
            awardsData = AwardsData.parse(from: omdbDetails.awards)
            media.awards = omdbDetails.awards
        } catch {
            debugPrint("Failed to fetch OMDb details: \(error)")
        }
    }

    // MARK: - Computed Properties

    /// Check if any ratings are available
    var hasRatings: Bool {
        !ratings.isEmpty
    }

    /// Check if episodes are available
    var hasEpisodes: Bool {
        !episodes.isEmpty
    }

    /// Check if episode grid should be shown
    /// Hidden for shows with 100+ episodes per season (OMDb API limit causes incomplete data)
    var shouldShowEpisodeGrid: Bool {
        guard !episodesBySeason.isEmpty else { return false }
        // Hide grid if any season hit the 100 episode API limit
        let maxEpisodesInAnySeason = episodesBySeason.values.map { $0.count }.max() ?? 0
        return maxEpisodesInAnySeason < 100
    }

    /// IMDb rating (if available)
    var imdbRating: RatingSource? {
        ratings.first { $0.ratingType == .imdb }
    }

    /// Rotten Tomatoes rating (if available)
    var rottenTomatoesRating: RatingSource? {
        ratings.first { $0.ratingType == .rottenTomatoes }
    }

    /// Metacritic rating (if available)
    var metacriticRating: RatingSource? {
        ratings.first { $0.ratingType == .metacritic }
    }

    /// Check if this is a TV series
    var isTVSeries: Bool {
        media.isTVSeries
    }

    /// Array of season numbers for picker
    var seasonNumbers: [Int] {
        Array(1...totalSeasons)
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

    /// Check if awards data is available
    var hasAwards: Bool {
        awardsData?.hasAwards == true
    }

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
        vm.ratings = RatingSource.previewRatings
        vm.episodes = EpisodeMetric.breakingBadS5
        vm.episodesBySeason = [
            1: EpisodeMetric.breakingBadS1,
            5: EpisodeMetric.breakingBadS5
        ]
        vm.totalSeasons = 5
        return vm
    }

    static var moviePreview: MediaDetailViewModel {
        let vm = MediaDetailViewModel(media: .moviePreview)
        vm.ratings = RatingSource.previewRatings
        vm.awardsData = .oscarWinnerPreview
        return vm
    }

    static var movieWithAllFeaturesPreview: MediaDetailViewModel {
        var media = MediaItem.moviePreview
        media.budget = 63_000_000
        media.revenue = 101_209_702
        media.collectionId = 1
        media.collectionName = "Test Collection"

        let vm = MediaDetailViewModel(media: media)
        vm.ratings = RatingSource.previewRatings
        vm.awardsData = .oscarWinnerPreview
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
