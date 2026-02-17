import Foundation
import WidgetKit

/// View model for the Daily Pick feature
@Observable
final class DailyPickViewModel {
    private(set) var recommendation: MediaItem?
    private(set) var basedOnFavorite: FavoriteItem?
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    var hasPick: Bool {
        recommendation != nil && basedOnFavorite != nil
    }

    private let tmdbService = TMDBService.shared
    private let cacheKey = "dailyPickCache"
    private let cacheDateKey = "dailyPickDate"

    func loadDailyPick(favorites: [FavoriteItem], favoriteIds: Set<Int>) async {
        guard !favorites.isEmpty else {
            recommendation = nil
            basedOnFavorite = nil
            return
        }

        // Check cache first - restore instantly without network request
        if let cached = loadCachedPick(), isCacheValid() {
            // Verify the cached favorite still exists
            if favorites.contains(where: { $0.tmdbId == cached.basedOnId }) {
                basedOnFavorite = favorites.first { $0.tmdbId == cached.basedOnId }
                // Use cached MediaItem directly if available
                if let cachedRecommendation = cached.recommendation {
                    recommendation = cachedRecommendation
                    return
                }
                // Fallback: fetch from network without loading indicator
                await loadRecommendation(id: cached.recommendationId, isTVSeries: cached.isTVSeries, showLoading: false)
                return
            }
        }

        // Generate new pick
        await generateNewPick(favorites: favorites, favoriteIds: favoriteIds)
    }

    func refreshPick(favorites: [FavoriteItem], favoriteIds: Set<Int>) async {
        let currentId = recommendation?.id
        clearCache()
        await generateNewPick(favorites: favorites, favoriteIds: favoriteIds, excludingId: currentId)
    }

    private func generateNewPick(
        favorites: [FavoriteItem],
        favoriteIds: Set<Int>,
        excludingId: Int? = nil
    ) async {
        isLoading = true
        errorMessage = nil

        var shuffledFavorites = favorites.shuffled()
        var attempts = 0
        let maxAttempts = min(5, favorites.count)

        while attempts < maxAttempts {
            guard let favorite = shuffledFavorites.popLast() else { break }
            attempts += 1

            do {
                let recommendations = try await tmdbService.fetchRecommendations(forFavorite: favorite)
                var filtered = recommendations.filter { !favoriteIds.contains($0.id) }
                if let excludingId {
                    filtered = filtered.filter { $0.id != excludingId }
                }

                if let pick = filtered.randomElement() {
                    recommendation = pick
                    basedOnFavorite = favorite
                    saveCachedPick(recommendation: pick, basedOnId: favorite.tmdbId)
                    updateWidgetDailyPick(pick: pick, basedOnTitle: favorite.title)
                    isLoading = false
                    return
                }
            } catch {
                continue
            }
        }

        isLoading = false
        errorMessage = "Couldn't find new recommendations"
    }

    private func loadRecommendation(id: Int, isTVSeries: Bool, showLoading: Bool = true) async {
        if showLoading {
            isLoading = true
        }

        do {
            if isTVSeries {
                recommendation = try await tmdbService.fetchSeriesDetails(id: id)
            } else {
                recommendation = try await tmdbService.fetchMovieDetails(id: id)
            }
        } catch {
            clearCache()
            errorMessage = "Failed to load recommendation"
        }

        isLoading = false
    }

    private func updateWidgetDailyPick(pick: MediaItem, basedOnTitle: String) {
        let widgetPick = WidgetDailyPick(
            tmdbId: pick.id,
            title: pick.displayTitle,
            posterPath: pick.posterPath,
            voteAverage: pick.voteAverage,
            mediaType: pick.isTVSeries ? "tv" : "movie",
            basedOnTitle: basedOnTitle
        )
        WidgetDataManager.updateDailyPick(widgetPick)

        // Pre-download poster image for widget
        Task.detached(priority: .utility) {
            await WidgetDataManager.cacheImages(posterPaths: [pick.posterPath])
            WidgetCenter.shared.reloadTimelines(ofKind: "DailyPickWidget")
        }
    }

    private struct CachedPick: Codable {
        let recommendationId: Int
        let basedOnId: Int
        let isTVSeries: Bool
        let recommendation: MediaItem?
    }

    private func saveCachedPick(recommendation: MediaItem, basedOnId: Int) {
        let cached = CachedPick(
            recommendationId: recommendation.id,
            basedOnId: basedOnId,
            isTVSeries: recommendation.isTVSeries,
            recommendation: recommendation
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
