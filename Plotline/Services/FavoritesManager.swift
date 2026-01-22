import Foundation
import SwiftData
import SwiftUI

/// Manager for handling favorite media items with SwiftData persistence
@Observable
final class FavoritesManager {
    private var modelContext: ModelContext?

    /// All favorite items, sorted by date added (newest first)
    private(set) var favorites: [FavoriteItem] = []

    /// Set of favorite TMDB IDs for quick lookup
    private(set) var favoriteIds: Set<Int> = []

    init() {}

    /// Configure the manager with a model context
    func configure(with context: ModelContext) {
        self.modelContext = context
        fetchFavorites()
    }

    // MARK: - Public Methods

    /// Check if a media item is favorited
    func isFavorite(_ media: MediaItem) -> Bool {
        favoriteIds.contains(media.id)
    }

    /// Check if a TMDB ID is favorited
    func isFavorite(tmdbId: Int) -> Bool {
        favoriteIds.contains(tmdbId)
    }

    /// Add a media item to favorites
    func addFavorite(_ media: MediaItem) {
        guard let context = modelContext else { return }
        guard !isFavorite(media) else { return }

        let favorite = FavoriteItem(from: media)
        context.insert(favorite)

        do {
            try context.save()
            favorites.insert(favorite, at: 0)
            favoriteIds.insert(media.id)
        } catch {
            print("Failed to save favorite: \(error)")
        }
    }

    /// Remove a media item from favorites
    func removeFavorite(_ media: MediaItem) {
        removeFavorite(tmdbId: media.id)
    }

    /// Remove a favorite by TMDB ID
    func removeFavorite(tmdbId: Int) {
        guard let context = modelContext else { return }

        let descriptor = FetchDescriptor<FavoriteItem>(
            predicate: #Predicate { $0.tmdbId == tmdbId }
        )

        do {
            let items = try context.fetch(descriptor)
            for item in items {
                context.delete(item)
            }
            try context.save()
            favorites.removeAll { $0.tmdbId == tmdbId }
            favoriteIds.remove(tmdbId)
        } catch {
            print("Failed to remove favorite: \(error)")
        }
    }

    /// Toggle favorite status for a media item
    func toggleFavorite(_ media: MediaItem) {
        if isFavorite(media) {
            removeFavorite(media)
        } else {
            addFavorite(media)
        }
    }

    /// Get a random favorite (for recommendations)
    func randomFavorite() -> FavoriteItem? {
        favorites.randomElement()
    }

    /// Get favorites filtered by media type
    func favorites(ofType mediaType: String) -> [FavoriteItem] {
        favorites.filter { $0.mediaType == mediaType }
    }

    // MARK: - Private Methods

    private func fetchFavorites() {
        guard let context = modelContext else { return }

        let descriptor = FetchDescriptor<FavoriteItem>(
            sortBy: [SortDescriptor(\.addedAt, order: .reverse)]
        )

        do {
            favorites = try context.fetch(descriptor)
            favoriteIds = Set(favorites.map(\.tmdbId))
        } catch {
            print("Failed to fetch favorites: \(error)")
            favorites = []
            favoriteIds = []
        }
    }
}

// MARK: - Environment Key

struct FavoritesManagerKey: EnvironmentKey {
    static let defaultValue = FavoritesManager()
}

extension EnvironmentValues {
    var favoritesManager: FavoritesManager {
        get { self[FavoritesManagerKey.self] }
        set { self[FavoritesManagerKey.self] = newValue }
    }
}
