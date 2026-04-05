import Foundation
import Observation

/// ViewModel for personalized smart lists based on user favorites
@Observable
final class SmartListsViewModel {
    // MARK: - State

    var becauseYouLiked: [MediaItem] = []
    var becauseYouLikedTitle: String = ""
    var directorsToKnow: [(item: MediaItem, directorName: String, fromTitle: String)] = []
    var topInYourGenres: [MediaItem] = []

    var isLoadingBecause = false
    var isLoadingDirectors = false
    var isLoadingTopGenres = false

    /// Minimum 5 favorites required to activate smart lists
    var hasEnoughData = false

    // MARK: - Private Properties

    private let tmdbService: TMDBService
    private static let minimumFavorites = 5

    // MARK: - Initialization

    init(tmdbService: TMDBService = .shared) {
        self.tmdbService = tmdbService
    }

    // MARK: - Public Methods

    /// Load all three smart lists concurrently
    @MainActor
    func loadLists(
        favorites: [FavoriteItem],
        favoriteIds: Set<Int>,
        watchlistIds: Set<Int>,
        topGenreIds: [Int]
    ) async {
        guard favorites.count >= Self.minimumFavorites else {
            hasEnoughData = false
            return
        }

        hasEnoughData = true

        let excludedIds = favoriteIds.union(watchlistIds)

        async let becauseTask: () = loadBecauseYouLiked(
            favorites: favorites,
            excludedIds: excludedIds
        )
        async let directorsTask: () = loadDirectorsToKnow(
            favorites: favorites,
            excludedIds: excludedIds
        )
        async let genresTask: () = loadTopInYourGenres(
            topGenreIds: topGenreIds,
            excludedIds: excludedIds
        )

        _ = await (becauseTask, directorsTask, genresTask)
    }

    // MARK: - Private Loaders

    /// "Because you liked [X]" — picks a random favorite, fetches TMDB recommendations,
    /// filters out favorites/watchlist, shows up to 10
    @MainActor
    private func loadBecauseYouLiked(
        favorites: [FavoriteItem],
        excludedIds: Set<Int>
    ) async {
        isLoadingBecause = true
        defer { isLoadingBecause = false }

        guard let picked = favorites.randomElement() else { return }
        becauseYouLikedTitle = picked.title

        do {
            let recommendations = try await tmdbService.fetchRecommendations(forFavorite: picked)
            becauseYouLiked = Array(
                recommendations
                    .filter { !excludedIds.contains($0.id) && $0.posterPath != nil }
                    .prefix(10)
            )
        } catch {
            #if DEBUG
            debugPrint("Smart Lists — failed to load 'Because you liked': \(error)")
            #endif
        }
    }

    /// "Directors you should know" — from top 10 rated favorites, fetch credits to find directors,
    /// then fetch their other top work, deduplicate by director name, show up to 10
    @MainActor
    private func loadDirectorsToKnow(
        favorites: [FavoriteItem],
        excludedIds: Set<Int>
    ) async {
        isLoadingDirectors = true
        defer { isLoadingDirectors = false }

        let topRated = Array(
            favorites.sorted { $0.voteAverage > $1.voteAverage }.prefix(10)
        )

        var results: [(item: MediaItem, directorName: String, fromTitle: String)] = []
        var seenDirectorNames: Set<String> = []

        for favorite in topRated {
            guard results.count < 10 else { break }

            do {
                // Fetch credits to find the director
                let credits: TMDBCreditsResponse
                if favorite.isTVSeries {
                    credits = try await tmdbService.fetchSeriesCredits(id: favorite.tmdbId)
                } else {
                    credits = try await tmdbService.fetchMovieCredits(id: favorite.tmdbId)
                }

                guard let director = credits.crew.first(where: { $0.job == "Director" }),
                      !seenDirectorNames.contains(director.name) else { continue }

                seenDirectorNames.insert(director.name)

                // Fetch the director's other work
                let personCredits = try await tmdbService.fetchPersonMovieCredits(personId: director.id)
                let topWork = personCredits.crew
                    .filter { $0.isDirector && $0.posterPath != nil && !excludedIds.contains($0.id) && $0.id != favorite.tmdbId }
                    .sorted { $0.voteAverage > $1.voteAverage }

                if let best = topWork.first {
                    results.append((
                        item: best.toMediaItem(),
                        directorName: director.name,
                        fromTitle: favorite.title
                    ))
                }
            } catch {
                #if DEBUG
                debugPrint("Smart Lists — failed to load director for '\(favorite.title)': \(error)")
                #endif
                continue
            }
        }

        directorsToKnow = results
    }

    /// "Top in your genres" — uses first genre from topGenreIds with TMDB discover
    /// (vote_count.gte 500), filters out known items, shows up to 10
    @MainActor
    private func loadTopInYourGenres(
        topGenreIds: [Int],
        excludedIds: Set<Int>
    ) async {
        isLoadingTopGenres = true
        defer { isLoadingTopGenres = false }

        guard let genreId = topGenreIds.first else { return }

        do {
            let response = try await tmdbService.discoverMovies(
                params: [
                    "with_genres": "\(genreId)",
                    "sort_by": "vote_average.desc",
                    "vote_count.gte": "500"
                ]
            )
            topInYourGenres = Array(
                response.results
                    .filter { !excludedIds.contains($0.id) && $0.posterPath != nil }
                    .prefix(10)
            )
        } catch {
            #if DEBUG
            debugPrint("Smart Lists — failed to load 'Top in your genres': \(error)")
            #endif
        }
    }
}
