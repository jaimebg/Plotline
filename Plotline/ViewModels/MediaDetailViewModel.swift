import Foundation
import Observation

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

        // Set total seasons if available
        if let seasons = media.totalSeasons {
            self.totalSeasons = seasons
        }
    }

    // MARK: - Public Methods

    /// Load all detail data (TMDB details + OMDb ratings)
    @MainActor
    func loadDetails() async {
        // First, get TMDB details to get IMDb ID if not available
        if media.imdbId == nil {
            await fetchTMDBDetails()
        }

        // Then fetch OMDb data in parallel
        async let ratingsTask: () = fetchRatings()
        async let episodesTask: () = fetchEpisodesIfSeries()
        async let allSeasonsTask: () = fetchAllSeasons()

        _ = await (ratingsTask, episodesTask, allSeasonsTask)
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
            #if DEBUG
            print("Failed to fetch ratings: \(error)")
            #endif
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
            #if DEBUG
            print("Failed to fetch episodes: \(error)")
            #endif
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

        // Fetch all seasons concurrently
        await withTaskGroup(of: (Int, [EpisodeMetric]?).self) { group in
            for season in 1...totalSeasons {
                group.addTask {
                    do {
                        let episodes = try await self.omdbService.fetchSeasonEpisodes(
                            imdbId: imdbId,
                            season: season
                        )
                        return (season, episodes)
                    } catch {
                        #if DEBUG
                        print("Failed to fetch season \(season): \(error)")
                        #endif
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

        isLoadingAllSeasons = false
    }

    // MARK: - Private Methods

    @MainActor
    private func fetchTMDBDetails() async {
        do {
            let details = try await tmdbService.fetchDetails(for: media)
            // Update media with IMDb ID and other details
            if let imdbId = details.imdbId {
                media.imdbId = imdbId
            }
            if let seasons = details.totalSeasons {
                totalSeasons = seasons
            }
        } catch {
            #if DEBUG
            print("Failed to fetch TMDB details: \(error)")
            #endif
        }
    }

    @MainActor
    private func fetchEpisodesIfSeries() async {
        guard media.isTVSeries else { return }
        await fetchEpisodes()
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
        return vm
    }
}
