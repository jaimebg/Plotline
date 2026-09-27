import Foundation

/// Computes a user's taste profile from their favorites library
///
/// The profile is a function of the favourites set and nothing else, so it is
/// computed once per set: `update(favorites:)` is safe to call on every
/// appearance of Discover and does nothing unless a favourite was added or
/// removed. The network half — details and credits for every favourite — runs
/// in a task this view model owns rather than one tied to the view, so
/// switching tabs mid-computation does not throw the work away and start it
/// again on return.
@Observable
final class TasteProfileViewModel {

    // MARK: - Published Properties

    var topGenres: [(genre: String, percentage: Double)] = []
    /// TMDB *movie* genre ids for each entry of `topGenres`, in the same rank
    /// order, for querying `/discover/movie`. A TV genre is translated to its
    /// movie counterparts through `CuratedGenre`; one with no counterpart
    /// (Kids, Reality, News, Soap, Talk) has no entry here.
    private(set) var topMovieGenreIds: [[Int]] = []
    var favoriteDirector: (name: String, count: Int)?
    var favoriteActor: (name: String, count: Int)?
    var ratingSweetSpot: (low: Double, high: Double) = (0, 10)
    var preferredEra: String?
    var tasteTags: [TasteTag] = []
    var moviesCount = 0
    var seriesCount = 0
    var isLoading = false

    var hasEnoughData: Bool {
        favoritesCount >= Self.minimumFavorites
    }

    // MARK: - Private

    private let tmdbService = TMDBService.shared
    static let minimumFavorites = 5
    /// Requests in flight at once while profiling the library. Each favourite
    /// costs two requests, so an unbounded fan-out over 50 favourites was 100
    /// simultaneous calls against TMDB's rate limit.
    private static let maxConcurrentRequests = 4
    private var favoritesCount = 0

    /// The favourites set the current (or in-flight) profile describes.
    @ObservationIgnored private var profileFingerprint: String?
    @ObservationIgnored private var networkTask: Task<Void, Never>?

    // MARK: - Fingerprint

    /// Identifies a favourites set by what the profile is derived from: which
    /// titles are in it. Order-independent, so re-sorting the library is not a
    /// change.
    static func fingerprint(of favorites: [FavoriteItem]) -> String {
        favorites
            .map { "\($0.isTVSeries ? "tv" : "movie"):\($0.tmdbId)" }
            .sorted()
            .joined(separator: ",")
    }

    // MARK: - Main Entry

    /// Recomputes the profile if, and only if, the favourites set changed.
    ///
    /// Everything that needs no network — counts, genres, the rating sweet
    /// spot — is updated before this returns, so callers can read
    /// `topMovieGenreIds` straight away.
    @MainActor
    func update(favorites: [FavoriteItem]) {
        let fingerprint = Self.fingerprint(of: favorites)
        guard fingerprint != profileFingerprint else { return }
        profileFingerprint = fingerprint

        networkTask?.cancel()
        networkTask = nil

        favoritesCount = favorites.count
        guard hasEnoughData else {
            resetDerivedState()
            return
        }

        // Media type counts
        moviesCount = favorites.filter { $0.mediaType == "movie" }.count
        seriesCount = favorites.filter { $0.mediaType == "tv" }.count

        // Genre distribution
        let distribution = Self.genreDistribution(favorites: favorites)
        topGenres = distribution.map { (genre: $0.name, percentage: $0.percentage) }
        topMovieGenreIds = distribution.map(\.movieGenreIds).filter { !$0.isEmpty }

        // Rating sweet spot (IQR)
        ratingSweetSpot = computeRatingSweetSpot(favorites: favorites) ?? (0, 10)

        // Snapshot what the network half needs: a SwiftData model is not
        // something to carry across suspension points into child tasks.
        let refs = favorites.map { FavoriteRef(tmdbId: $0.tmdbId, isTVSeries: $0.isTVSeries) }
        let ratings = favorites.map(\.voteAverage)
        let seriesRatio = Double(seriesCount) / Double(favorites.count)

        isLoading = true
        networkTask = Task { [weak self] in
            guard let self else { return }
            await self.computeNetworkProfile(
                refs: refs,
                ratings: ratings,
                seriesRatio: seriesRatio,
                genreDistribution: topGenres,
                fingerprint: fingerprint
            )
        }
    }

    @MainActor
    private func computeNetworkProfile(
        refs: [FavoriteRef],
        ratings: [Double],
        seriesRatio: Double,
        genreDistribution: [(genre: String, percentage: Double)],
        fingerprint: String
    ) async {
        let fetched = await fetchDetailsAndCredits(for: refs)

        // A newer favourites set superseded this run; its own task will
        // publish instead.
        guard !Task.isCancelled, fingerprint == profileFingerprint else { return }
        defer { isLoading = false }

        let details = fetched.compactMap(\.details)
        let allCredits = fetched.compactMap(\.credits)

        // Preferred era — from release dates in the details
        preferredEra = computePreferredEra(details: details)

        // Credits analysis — favorite director and actor
        let (director, directorCount) = findTopCrewMember(job: "Director", credits: allCredits)
        let (actor, actorCount) = findTopCastMember(credits: allCredits)
        favoriteDirector = director.flatMap { directorCount >= 2 ? (name: $0, count: directorCount) : nil }
        favoriteActor = actor.flatMap { actorCount >= 2 ? (name: $0, count: actorCount) : nil }

        // Popularity stats from details
        let popularities = details.map(\.voteCount).map(Double.init)
        let avgPopularity = popularities.isEmpty ? 0 : popularities.reduce(0, +) / Double(popularities.count)
        let medianPopularity = median(of: popularities)

        // Average rating
        let avgRating = ratings.isEmpty ? 0 : ratings.reduce(0, +) / Double(ratings.count)

        // Generate taste tags
        tasteTags = TasteTag.generate(
            genrePercentages: genreDistribution,
            preferredEra: preferredEra,
            directorAppearances: directorCount,
            seriesRatio: seriesRatio,
            avgPopularity: avgPopularity,
            medianPopularity: medianPopularity,
            avgRating: avgRating
        )
    }

    private func resetDerivedState() {
        topGenres = []
        topMovieGenreIds = []
        favoriteDirector = nil
        favoriteActor = nil
        ratingSweetSpot = (0, 10)
        preferredEra = nil
        tasteTags = []
        moviesCount = 0
        seriesCount = 0
        isLoading = false
    }

    // MARK: - Genre Distribution

    struct GenreShare: Equatable {
        let name: String
        let percentage: Double
        /// Movie-genre ids this display name stands for, sorted.
        let movieGenreIds: [Int]
    }

    /// Genre shares across the library, largest first.
    ///
    /// Counted by display name, because TMDB gives movies and series separate
    /// ids for the same genre (Action is 28 for a movie, 10759 for a series).
    /// Each name keeps the *movie* ids it maps to, derived from the favourite's
    /// own media type rather than looked up from the name: a name-to-id lookup
    /// is ambiguous for Action and War, and Swift's dictionary order made it
    /// pick a different one on each launch.
    static func genreDistribution(favorites: [FavoriteItem]) -> [GenreShare] {
        var genreCounts: [String: Int] = [:]
        var movieIds: [String: Set<Int>] = [:]
        var totalGenreSlots = 0

        for item in favorites {
            for gid in item.genreIdArray {
                guard let name = GenreLookup.name(for: gid) else { continue }
                genreCounts[name, default: 0] += 1
                movieIds[name, default: []].formUnion(movieGenreIds(for: gid, isTVSeries: item.isTVSeries))
                totalGenreSlots += 1
            }
        }

        guard totalGenreSlots > 0 else { return [] }

        return genreCounts
            .map { name, count in
                GenreShare(
                    name: name,
                    percentage: Double(count) / Double(totalGenreSlots),
                    movieGenreIds: (movieIds[name] ?? []).sorted()
                )
            }
            // Name breaks ties, so equal shares rank the same way every launch.
            .sorted { ($0.percentage, $1.name) > ($1.percentage, $0.name) }
    }

    /// The movie-genre ids a favourite's genre id corresponds to.
    ///
    /// A movie's ids are movie ids already. A series' ids are TV ids, mapped
    /// through the curated pairs: Action & Adventure (10759) becomes Action
    /// (28), War & Politics (10768) becomes War (10752), and Sci-Fi & Fantasy
    /// (10765) becomes both Fantasy (14) and Science Fiction (878). A TV genre
    /// with no movie counterpart maps to nothing.
    static func movieGenreIds(for genreId: Int, isTVSeries: Bool) -> Set<Int> {
        guard isTVSeries else { return [genreId] }
        return Set(CuratedGenre.all.filter { $0.tvGenreId == genreId }.map(\.movieGenreId))
    }

    // MARK: - Rating Sweet Spot (IQR)

    private func computeRatingSweetSpot(favorites: [FavoriteItem]) -> (low: Double, high: Double)? {
        let sorted = favorites.map(\.voteAverage).sorted()
        guard sorted.count >= 4 else { return nil }

        let q1Index = sorted.count / 4
        let q3Index = (sorted.count * 3) / 4
        return (low: sorted[q1Index], high: sorted[q3Index])
    }

    // MARK: - Preferred Era

    private func computePreferredEra(details: [MediaItem]) -> String? {
        var decadeCounts: [String: Int] = [:]

        for item in details {
            guard let dateString = item.displayDate,
                  dateString.count >= 4,
                  let year = Int(dateString.prefix(4)) else { continue }
            let decade = (year / 10) * 10
            let label = "\(decade)s"
            decadeCounts[label, default: 0] += 1
        }

        // Label breaks ties so the result does not depend on dictionary order.
        return decadeCounts.max { ($0.value, $1.key) < ($1.value, $0.key) }?.key
    }

    // MARK: - Network Fetching

    private nonisolated struct FavoriteRef: Sendable {
        let tmdbId: Int
        let isTVSeries: Bool
    }

    private nonisolated struct FavoriteFetch: Sendable {
        let details: MediaItem?
        let credits: TMDBCreditsResponse?
    }

    /// Details and credits for every favourite, with at most
    /// `maxConcurrentRequests` requests in flight. Each child makes its two
    /// requests one after the other, so the cap is on requests, not titles.
    private func fetchDetailsAndCredits(for refs: [FavoriteRef]) async -> [FavoriteFetch] {
        await withTaskGroup(of: FavoriteFetch.self) { group in
            var results: [FavoriteFetch] = []
            var pending = refs[...]

            func addNext() {
                guard let ref = pending.popFirst() else { return }
                group.addTask { [tmdbService] in
                    guard !Task.isCancelled else { return FavoriteFetch(details: nil, credits: nil) }
                    let details: MediaItem? = ref.isTVSeries
                        ? try? await tmdbService.fetchSeriesDetails(id: ref.tmdbId)
                        : try? await tmdbService.fetchMovieDetails(id: ref.tmdbId)
                    guard !Task.isCancelled else { return FavoriteFetch(details: details, credits: nil) }
                    let credits: TMDBCreditsResponse? = ref.isTVSeries
                        ? try? await tmdbService.fetchSeriesCredits(id: ref.tmdbId)
                        : try? await tmdbService.fetchMovieCredits(id: ref.tmdbId)
                    return FavoriteFetch(details: details, credits: credits)
                }
            }

            for _ in 0..<Self.maxConcurrentRequests { addNext() }
            for await result in group {
                results.append(result)
                addNext()
            }
            return results
        }
    }

    // MARK: - Credits Analysis

    private func findTopCrewMember(job: String, credits: [TMDBCreditsResponse]) -> (name: String?, count: Int) {
        var counts: [String: Int] = [:]
        for credit in credits {
            for member in credit.crew where member.job == job {
                counts[member.name, default: 0] += 1
            }
        }
        guard let top = counts.max(by: { ($0.value, $1.key) < ($1.value, $0.key) }) else {
            return (nil, 0)
        }
        return (top.key, top.value)
    }

    private func findTopCastMember(credits: [TMDBCreditsResponse]) -> (name: String?, count: Int) {
        var counts: [String: Int] = [:]
        for credit in credits {
            // Only consider lead cast (top 3 billed)
            for member in credit.cast.prefix(3) {
                counts[member.name, default: 0] += 1
            }
        }
        guard let top = counts.max(by: { ($0.value, $1.key) < ($1.value, $0.key) }) else {
            return (nil, 0)
        }
        return (top.key, top.value)
    }

    // MARK: - Helpers

    private func median(of values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let count = sorted.count
        if count.isMultiple(of: 2) {
            return (sorted[count / 2 - 1] + sorted[count / 2]) / 2.0
        } else {
            return sorted[count / 2]
        }
    }
}
