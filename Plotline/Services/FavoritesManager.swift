import CoreData
import Foundation
import SwiftData
import SwiftUI

/// Manager for handling favorite media items with SwiftData persistence
@Observable
final class FavoritesManager {
    private var modelContext: ModelContext?
    private(set) var favorites: [FavoriteItem] = []
    private(set) var favoriteIds: Set<Int> = []

    @ObservationIgnored private var remoteChangeTask: Task<Void, Never>?

    init() {}

    func configure(with context: ModelContext) {
        self.modelContext = context
        fetchFavorites()
        observeRemoteChanges()
    }

    /// Re-fetches whenever CloudKit imports changes from another device.
    ///
    /// `favorites` is a snapshot, not a live query: without this, a favorite
    /// added on the iPad appeared on the iPhone only after a relaunch.
    private func observeRemoteChanges() {
        guard remoteChangeTask == nil else { return }
        remoteChangeTask = Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: .NSPersistentStoreRemoteChange) {
                guard let self else { return }
                self.fetchFavorites()
            }
        }
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
            #if DEBUG
            print("Failed to save favorite: \(error)")
            #endif
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
            #if DEBUG
            print("Failed to remove favorite: \(error)")
            #endif
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

        do {
            let allFavorites = try context.fetch(FetchDescriptor<FavoriteItem>())

            // CloudKit cannot enforce uniqueness, so two devices adding the same
            // title leave two records. Keep the earliest-added on every device,
            // fold in anything only a later copy knows, then delete the rest.
            let groups = DuplicateResolver.group(allFavorites, id: \.tmdbId, addedAt: \.addedAt)

            var removedDuplicates = false
            for group in groups where !group.duplicates.isEmpty {
                merge(group.duplicates, into: group.keeper)
                for duplicate in group.duplicates {
                    context.delete(duplicate)
                }
                removedDuplicates = true
            }
            if removedDuplicates {
                try context.save()
            }

            favorites = groups.map(\.keeper)
            favoriteIds = Set(favorites.map(\.tmdbId))
        } catch {
            #if DEBUG
            print("Failed to fetch favorites: \(error)")
            #endif
            favorites = []
            favoriteIds = []
        }
    }

    /// A favorite carries no progress to lose, only display metadata a later
    /// copy may have filled in where the keeper has none.
    private func merge(_ duplicates: [FavoriteItem], into keeper: FavoriteItem) {
        let all = [keeper] + duplicates
        keeper.posterPath = DuplicateResolver.firstPresent(all.map(\.posterPath))
        keeper.backdropPath = DuplicateResolver.firstPresent(all.map(\.backdropPath))
        if keeper.genreIds.isEmpty, let genres = duplicates.first(where: { !$0.genreIds.isEmpty })?.genreIds {
            keeper.genreIds = genres
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
