import Foundation

/// Computes a user's taste profile from their favorites library
@Observable
final class TasteProfileViewModel {

    // MARK: - Published Properties

    var topGenres: [(genre: String, percentage: Double)] = []
    var favoriteDirector: (name: String, count: Int)?
    var favoriteActor: (name: String, count: Int)?
    var ratingSweetSpot: (low: Double, high: Double) = (0, 10)
    var preferredEra: String?
    var tasteTags: [TasteTag] = []
    var moviesCount = 0
    var seriesCount = 0
    var isLoading = false

    var hasEnoughData: Bool {
        favoritesCount >= minimumFavorites
    }

    // MARK: - Private

    private let tmdbService = TMDBService.shared
    private let minimumFavorites = 5
    private var favoritesCount = 0

    // MARK: - Main Entry

    @MainActor
    func computeProfile(favorites: [FavoriteItem], watchlistItems: [WatchlistItem]) async {
        favoritesCount = favorites.count
        guard hasEnoughData else { return }

        isLoading = true
        defer { isLoading = false }

        // Media type counts
        moviesCount = favorites.filter { $0.mediaType == "movie" }.count
        seriesCount = favorites.filter { $0.mediaType == "tv" }.count

        // Genre distribution
        let genreDistribution = computeGenreDistribution(favorites: favorites)
        topGenres = genreDistribution

        // Rating sweet spot (IQR)
        if let sweetSpot = computeRatingSweetSpot(favorites: favorites) {
            ratingSweetSpot = sweetSpot
        }

        // Preferred era — requires fetching details for release dates
        let details = await fetchDetails(for: favorites)
        preferredEra = computePreferredEra(details: details)

        // Credits analysis — favorite director and actor
        let allCredits = await fetchAllCredits(for: favorites)
        let (director, directorCount) = findTopCrewMember(job: "Director", credits: allCredits)
        let (actor, actorCount) = findTopCastMember(credits: allCredits)
        if let director, directorCount >= 2 {
            favoriteDirector = (name: director, count: directorCount)
        }
        if let actor, actorCount >= 2 {
            favoriteActor = (name: actor, count: actorCount)
        }

        // Popularity stats from details
        let popularities = details.map(\.voteCount).map(Double.init)
        let avgPopularity = popularities.isEmpty ? 0 : popularities.reduce(0, +) / Double(popularities.count)
        let medianPopularity = median(of: popularities)

        // Average rating
        let ratings = favorites.map(\.voteAverage)
        let avgRating = ratings.isEmpty ? 0 : ratings.reduce(0, +) / Double(ratings.count)

        // Series ratio
        let seriesRatio = favorites.isEmpty ? 0 : Double(seriesCount) / Double(favorites.count)

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

    // MARK: - Genre Distribution

    private func computeGenreDistribution(favorites: [FavoriteItem]) -> [(genre: String, percentage: Double)] {
        var genreCounts: [String: Int] = [:]
        var totalGenreSlots = 0

        for item in favorites {
            for gid in item.genreIdArray {
                if let name = GenreLookup.name(for: gid) {
                    genreCounts[name, default: 0] += 1
                    totalGenreSlots += 1
                }
            }
        }

        guard totalGenreSlots > 0 else { return [] }

        return genreCounts
            .map { (genre: $0.key, percentage: Double($0.value) / Double(totalGenreSlots)) }
            .sorted { $0.percentage > $1.percentage }
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

        return decadeCounts.max(by: { $0.value < $1.value })?.key
    }

    // MARK: - Network Fetching

    private func fetchDetails(for favorites: [FavoriteItem]) async -> [MediaItem] {
        await withTaskGroup(of: MediaItem?.self) { group in
            for item in favorites {
                group.addTask { [tmdbService] in
                    do {
                        if item.isTVSeries {
                            return try await tmdbService.fetchSeriesDetails(id: item.tmdbId)
                        } else {
                            return try await tmdbService.fetchMovieDetails(id: item.tmdbId)
                        }
                    } catch {
                        return nil
                    }
                }
            }

            var results: [MediaItem] = []
            for await result in group {
                if let item = result {
                    results.append(item)
                }
            }
            return results
        }
    }

    private func fetchAllCredits(for favorites: [FavoriteItem]) async -> [TMDBCreditsResponse] {
        await withTaskGroup(of: TMDBCreditsResponse?.self) { group in
            for item in favorites {
                group.addTask { [tmdbService] in
                    do {
                        if item.isTVSeries {
                            return try await tmdbService.fetchSeriesCredits(id: item.tmdbId)
                        } else {
                            return try await tmdbService.fetchMovieCredits(id: item.tmdbId)
                        }
                    } catch {
                        return nil
                    }
                }
            }

            var results: [TMDBCreditsResponse] = []
            for await result in group {
                if let credits = result {
                    results.append(credits)
                }
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
        guard let top = counts.max(by: { $0.value < $1.value }) else {
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
        guard let top = counts.max(by: { $0.value < $1.value }) else {
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
