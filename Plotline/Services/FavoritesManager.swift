import Foundation
import SwiftData
import SwiftUI

/// Manager for handling favorite media items with SwiftData persistence
@Observable
final class FavoritesManager {
    private var modelContext: ModelContext?
    private(set) var favorites: [FavoriteItem] = []
    private(set) var favoriteIds: Set<Int> = []

    init() {}

    func configure(with context: ModelContext) {
        self.modelContext = context
        fetchFavorites()
    }

    func isFavorite(_ media: MediaItem) -> Bool {
        favoriteIds.contains(media.id)
    }

    func isFavorite(tmdbId: Int) -> Bool {
        favoriteIds.contains(tmdbId)
    }

    func addFavorite(_ media: MediaItem) {
        guard let context = modelContext else { return }
        guard !isFavorite(media) else { return }

        let favorite = FavoriteItem(from: media)
        context.insert(favorite)

        do {
            try context.save()
            fetchFavorites()
        } catch {
            print("Failed to save favorite: \(error)")
        }
    }

    func removeFavorite(_ media: MediaItem) {
        removeFavorite(tmdbId: media.id)
    }

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
            fetchFavorites()
        } catch {
            print("Failed to remove favorite: \(error)")
        }
    }

    func toggleFavorite(_ media: MediaItem) {
        if isFavorite(media) {
            removeFavorite(media)
        } else {
            addFavorite(media)
        }
    }

    func randomFavorite() -> FavoriteItem? {
        favorites.randomElement()
    }

    func favorites(ofType mediaType: String) -> [FavoriteItem] {
        favorites.filter { $0.mediaType == mediaType }
    }

    private func fetchFavorites() {
        guard let context = modelContext else { return }

        let descriptor = FetchDescriptor<FavoriteItem>(
            sortBy: [SortDescriptor(\.addedAt, order: .reverse)]
        )

        do {
            let allFavorites = try context.fetch(descriptor)

            // Deduplicate by tmdbId (keep earliest added, remove later duplicates from CloudKit sync)
            var seenIds = Set<Int>()
            var uniqueFavorites: [FavoriteItem] = []
            var duplicatesToDelete: [FavoriteItem] = []

            for favorite in allFavorites {
                if seenIds.contains(favorite.tmdbId) {
                    duplicatesToDelete.append(favorite)
                } else {
                    seenIds.insert(favorite.tmdbId)
                    uniqueFavorites.append(favorite)
                }
            }

            // Clean up any duplicates that arrived via CloudKit
            for duplicate in duplicatesToDelete {
                context.delete(duplicate)
            }
            if !duplicatesToDelete.isEmpty {
                try context.save()
            }

            favorites = uniqueFavorites
            favoriteIds = seenIds
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
