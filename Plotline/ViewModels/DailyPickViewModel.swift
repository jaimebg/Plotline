import Foundation

/// View model for the Daily Pick feature
@Observable
final class DailyPickViewModel {
    /// The recommended media item
    private(set) var recommendation: MediaItem?

    /// The favorite item that triggered this recommendation
    private(set) var basedOnFavorite: FavoriteItem?

    /// Loading state
    private(set) var isLoading = false

    /// Error message if loading failed
    private(set) var errorMessage: String?

    /// Whether we have a valid pick to display
    var hasPick: Bool {
        recommendation != nil && basedOnFavorite != nil
    }

    private let tmdbService = TMDBService.shared
    private let cacheKey = "dailyPickCache"
    private let cacheDateKey = "dailyPickDate"

    // MARK: - Public Methods

    /// Load or refresh the daily pick based on user favorites
    func loadDailyPick(favorites: [FavoriteItem], favoriteIds: Set<Int>) async {
        guard !favorites.isEmpty else {
            recommendation = nil
            basedOnFavorite = nil
            return
        }

        // Check cache first
        if let cached = loadCachedPick(), isCacheValid() {
            // Verify the cached favorite still exists
            if favorites.contains(where: { $0.tmdbId == cached.basedOnId }) {
                basedOnFavorite = favorites.first { $0.tmdbId == cached.basedOnId }
                await loadRecommendation(id: cached.recommendationId, isTVSeries: cached.isTVSeries)
                return
            }
        }

        // Generate new pick
        await generateNewPick(favorites: favorites, favoriteIds: favoriteIds)
    }

    /// Force refresh the daily pick (ignores cache, excludes current pick)
    func refreshPick(favorites: [FavoriteItem], favoriteIds: Set<Int>) async {
        let currentId = recommendation?.id
        clearCache()
        await generateNewPick(favorites: favorites, favoriteIds: favoriteIds, excludingId: currentId)
    }

    // MARK: - Private Methods

    private func generateNewPick(
        favorites: [FavoriteItem],
        favoriteIds: Set<Int>,
        excludingId: Int? = nil
    ) async {
        isLoading = true
        errorMessage = nil

        // Try multiple favorites if needed
        var shuffledFavorites = favorites.shuffled()
        var attempts = 0
        let maxAttempts = min(5, favorites.count)

        while attempts < maxAttempts {
            guard let favorite = shuffledFavorites.popLast() else { break }
            attempts += 1

            do {
                let recommendations = try await tmdbService.fetchRecommendations(forFavorite: favorite)

                // Filter out items already in favorites and the excluded ID
                var filtered = recommendations.filter { !favoriteIds.contains($0.id) }
                if let excludingId {
                    filtered = filtered.filter { $0.id != excludingId }
                }

                // Pick a random recommendation from the filtered list
                if let pick = filtered.randomElement() {
                    recommendation = pick
                    basedOnFavorite = favorite
                    saveCachedPick(recommendationId: pick.id, basedOnId: favorite.tmdbId, isTVSeries: pick.isTVSeries)
                    isLoading = false
                    return
                }
            } catch {
                // Continue to next favorite
                continue
            }
        }

        // No valid recommendations found
        isLoading = false
        errorMessage = "Couldn't find new recommendations"
    }

    private func loadRecommendation(id: Int, isTVSeries: Bool) async {
        isLoading = true

        do {
            if isTVSeries {
                recommendation = try await tmdbService.fetchSeriesDetails(id: id)
            } else {
                recommendation = try await tmdbService.fetchMovieDetails(id: id)
            }
        } catch {
            // If cache load fails, clear it
            clearCache()
            errorMessage = "Failed to load recommendation"
        }

        isLoading = false
    }

    // MARK: - Cache Management

    private struct CachedPick: Codable {
        let recommendationId: Int
        let basedOnId: Int
        let isTVSeries: Bool
    }

    private func saveCachedPick(recommendationId: Int, basedOnId: Int, isTVSeries: Bool) {
        let cached = CachedPick(
            recommendationId: recommendationId,
            basedOnId: basedOnId,
            isTVSeries: isTVSeries
        )

        if let data = try? JSONEncoder().encode(cached) {
            UserDefaults.standard.set(data, forKey: cacheKey)
            UserDefaults.standard.set(Date(), forKey: cacheDateKey)
        }
    }

    private func loadCachedPick() -> CachedPick? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else { return nil }
        return try? JSONDecoder().decode(CachedPick.self, from: data)
    }

    private func isCacheValid() -> Bool {
        guard let cacheDate = UserDefaults.standard.object(forKey: cacheDateKey) as? Date else {
            return false
        }
        return Calendar.current.isDateInToday(cacheDate)
    }

    private func clearCache() {
        UserDefaults.standard.removeObject(forKey: cacheKey)
        UserDefaults.standard.removeObject(forKey: cacheDateKey)
    }
}
