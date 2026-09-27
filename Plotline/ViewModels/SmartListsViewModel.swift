import Foundation
import Observation

/// ViewModel for personalized smart lists based on user favorites
///
/// The lists are a function of the favourites set, so they load once per set.
/// `update(...)` is safe to call on every appearance of Discover: returning to
/// the tab used to reload all three lists, flash their shimmer, and pick a new
/// random title for "Because you liked" each time.
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
    private static let minimumFavorites = TasteProfileViewModel.minimumFavorites

    /// The favourites set the current lists were built from.
    @ObservationIgnored private var listsFingerprint: String?
    @ObservationIgnored private var loadTask: Task<Void, Never>?
    /// Bumped on every reload. A loader from a superseded run checks it before
    /// writing anything, including its loading flag, so a late response can
    /// neither overwrite newer lists nor clear a newer run's shimmer.
    @ObservationIgnored private var generation = 0

    // MARK: - Initialization

    init(tmdbService: TMDBService = .shared) {
        self.tmdbService = tmdbService
    }

    // MARK: - Public Methods

    /// Rebuilds the three lists if, and only if, the favourites set changed.
    ///
    /// - Parameter topGenreIds: movie-genre ids per top genre, ranked, from
    ///   `TasteProfileViewModel.topMovieGenreIds`.
    @MainActor
    func update(
        favorites: [FavoriteItem],
        favoriteIds: Set<Int>,
        watchlistIds: Set<Int>,
        topGenreIds: [[Int]]
    ) {
        let fingerprint = TasteProfileViewModel.fingerprint(of: favorites)
        guard fingerprint != listsFingerprint else { return }
        listsFingerprint = fingerprint

        loadTask?.cancel()
        generation += 1
        let run = generation

        guard favorites.count >= Self.minimumFavorites else {
            hasEnoughData = false
            becauseYouLiked = []
            becauseYouLikedTitle = ""
            directorsToKnow = []
            topInYourGenres = []
            isLoadingBecause = false
            isLoadingDirectors = false
            isLoadingTopGenres = false
            return
        }

        hasEnoughData = true

        let excludedIds = favoriteIds.union(watchlistIds)
        let picked = Self.stablePick(from: favorites, fingerprint: fingerprint)

        loadTask = Task { [weak self] in
            guard let self else { return }
            async let becauseTask: () = loadBecauseYouLiked(
                picked: picked,
                excludedIds: excludedIds,
                run: run
            )
            async let directorsTask: () = loadDirectorsToKnow(
                favorites: favorites,
                excludedIds: excludedIds,
                run: run
            )
            async let genresTask: () = loadTopInYourGenres(
                topGenreIds: topGenreIds,
                excludedIds: excludedIds,
                run: run
            )

            _ = await (becauseTask, directorsTask, genresTask)
        }
    }

    /// Forgets which favourites set the lists were built for, so the next
    /// `update(...)` reloads them. Pull-to-refresh uses this; nothing else
    /// should need to.
    @MainActor
    func invalidate() {
        listsFingerprint = nil
    }

    // MARK: - Stable Pick

    /// The favourite "Because you liked" is built from.
    ///
    /// Deterministic per favourites set: the same library always yields the
    /// same title, on every visit and every launch, and only adding or
    /// removing a favourite can change it. Swift's `hashValue` is seeded per
    /// process, so this uses FNV-1a over the fingerprint instead.
    static func stablePick(from favorites: [FavoriteItem], fingerprint: String) -> FavoriteItem? {
        guard !favorites.isEmpty else { return nil }
        let ordered = favorites.sorted {
            ($0.isTVSeries ? 1 : 0, $0.tmdbId) < ($1.isTVSeries ? 1 : 0, $1.tmdbId)
        }
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in fingerprint.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return ordered[Int(hash % UInt64(ordered.count))]
    }

    // MARK: - Private Loaders

    private func isCurrent(_ run: Int) -> Bool {
        run == generation && !Task.isCancelled
    }

    /// "Because you liked [X]" — fetches TMDB recommendations for the stable
    /// pick, filters out favorites/watchlist, shows up to 10
    @MainActor
    private func loadBecauseYouLiked(
        picked: FavoriteItem?,
        excludedIds: Set<Int>,
        run: Int
    ) async {
        guard let picked else { return }
        isLoadingBecause = true
        becauseYouLikedTitle = picked.title

        do {
            let recommendations = try await tmdbService.fetchRecommendations(forFavorite: picked)
            guard isCurrent(run) else { return }
            becauseYouLiked = Array(
                recommendations
                    .filter { !excludedIds.contains($0.id) && $0.posterPath != nil }
                    .prefix(10)
            )
        } catch {
            #if DEBUG
            debugPrint("Smart Lists — failed to load 'Because you liked': \(error)")
            #endif
            guard isCurrent(run) else { return }
            becauseYouLiked = []
        }
        isLoadingBecause = false
    }

    /// "Directors you should know" — from top 10 rated favorites, fetch credits to find directors,
    /// then fetch their other top work, deduplicate by director name, show up to 10
    @MainActor
    private func loadDirectorsToKnow(
        favorites: [FavoriteItem],
        excludedIds: Set<Int>,
        run: Int
    ) async {
        isLoadingDirectors = true

        let topRated = Array(
            favorites
                .sorted { ($0.voteAverage, $1.tmdbId) > ($1.voteAverage, $0.tmdbId) }
                .prefix(10)
        )

        var results: [(item: MediaItem, directorName: String, fromTitle: String)] = []
        var seenDirectorNames: Set<String> = []

        for favorite in topRated {
            guard results.count < 10, isCurrent(run) else { break }

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

        guard isCurrent(run) else { return }
        directorsToKnow = results
        isLoadingDirectors = false
    }

    /// "Top in your genres" — the top genre's movie ids with TMDB discover
    /// (vote_count.gte 500), filters out known items, shows up to 10.
    ///
    /// A genre that stands for several movie genres (a series' Sci-Fi &
    /// Fantasy is both Fantasy and Science Fiction) is queried as either one.
    @MainActor
    private func loadTopInYourGenres(
        topGenreIds: [[Int]],
        excludedIds: Set<Int>,
        run: Int
    ) async {
        guard let genreIds = topGenreIds.first, !genreIds.isEmpty else {
            topInYourGenres = []
            isLoadingTopGenres = false
            return
        }
        isLoadingTopGenres = true

        do {
            let response = try await tmdbService.discoverMovies(
                params: [
                    "with_genres": genreIds.map(String.init).joined(separator: "|"),
                    "sort_by": "vote_average.desc",
                    "vote_count.gte": "500"
                ]
            )
            guard isCurrent(run) else { return }
            topInYourGenres = Array(
                response.results
                    .filter { !excludedIds.contains($0.id) && $0.posterPath != nil }
                    .prefix(10)
            )
        } catch {
            #if DEBUG
            debugPrint("Smart Lists — failed to load 'Top in your genres': \(error)")
            #endif
            guard isCurrent(run) else { return }
            topInYourGenres = []
        }
        isLoadingTopGenres = false
    }
}
