import CoreData
import Foundation
import SwiftData
import SwiftUI

/// Manager for handling watchlist items with SwiftData persistence
@Observable
final class WatchlistManager {
    private var modelContext: ModelContext?
    private(set) var watchlistItems: [WatchlistItem] = []
    private(set) var watchlistIds: Set<Int> = []

    @ObservationIgnored private var remoteChangeTask: Task<Void, Never>?

    init() {}

    func configure(with context: ModelContext) {
        self.modelContext = context
        fetchWatchlist()
        observeRemoteChanges()
    }

    /// Re-fetches whenever CloudKit imports changes from another device —
    /// see `FavoritesManager.observeRemoteChanges()`.
    private func observeRemoteChanges() {
        guard remoteChangeTask == nil else { return }
        remoteChangeTask = Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: .NSPersistentStoreRemoteChange) {
                guard let self else { return }
                self.fetchWatchlist()
            }
        }
    }

    func isOnWatchlist(_ media: MediaItem) -> Bool {
        watchlistIds.contains(media.id)
    }

    func isOnWatchlist(tmdbId: Int) -> Bool {
        watchlistIds.contains(tmdbId)
    }

    func watchlistStatus(for media: MediaItem) -> String? {
        watchlistItems.first(where: { $0.tmdbId == media.id })?.watchStatus
    }

    func watchlistStatus(forTmdbId tmdbId: Int) -> String? {
        watchlistItems.first(where: { $0.tmdbId == tmdbId })?.watchStatus
    }

    func addToWatchlist(_ media: MediaItem, status: String = "want_to_watch") {
        guard let context = modelContext else { return }
        guard !isOnWatchlist(media) else { return }

        let item = WatchlistItem(from: media, status: status)
        context.insert(item)

        do {
            try context.save()
            fetchWatchlist()
        } catch {
            #if DEBUG
            print("Failed to save watchlist item: \(error)")
            #endif
        }
    }

    func removeFromWatchlist(_ media: MediaItem) {
        removeFromWatchlist(tmdbId: media.id)
    }

    func removeFromWatchlist(tmdbId: Int) {
        guard let context = modelContext else { return }

        let descriptor = FetchDescriptor<WatchlistItem>(
            predicate: #Predicate { $0.tmdbId == tmdbId }
        )

        do {
            let items = try context.fetch(descriptor)
            for item in items {
                context.delete(item)
            }
            try context.save()
            fetchWatchlist()
        } catch {
            #if DEBUG
            print("Failed to remove watchlist item: \(error)")
            #endif
        }
    }

    func updateStatus(tmdbId: Int, status: String) {
        guard let context = modelContext else { return }

        let descriptor = FetchDescriptor<WatchlistItem>(
            predicate: #Predicate { $0.tmdbId == tmdbId }
        )

        do {
            let items = try context.fetch(descriptor)
            if let item = items.first {
                item.watchStatus = status
                try context.save()
                fetchWatchlist()
            }
        } catch {
            #if DEBUG
            print("Failed to update watchlist status: \(error)")
            #endif
        }
    }

    func items(withStatus status: String) -> [WatchlistItem] {
        watchlistItems.filter { $0.watchStatus == status }
    }

    private func fetchWatchlist() {
        guard let context = modelContext else { return }

        do {
            let allItems = try context.fetch(FetchDescriptor<WatchlistItem>())

            // CloudKit cannot enforce uniqueness, so two devices adding the same
            // title leave two records. Keep the earliest-added on every device,
            // fold in anything only a later copy knows — a title marked watched
            // on the other device must stay watched — then delete the rest.
            let groups = DuplicateResolver.group(allItems, id: \.tmdbId, addedAt: \.addedAt)

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

            watchlistItems = groups.map(\.keeper)
            watchlistIds = Set(watchlistItems.map(\.tmdbId))
        } catch {
            #if DEBUG
            print("Failed to fetch watchlist: \(error)")
            #endif
            watchlistItems = []
            watchlistIds = []
        }
    }

    private func merge(_ duplicates: [WatchlistItem], into keeper: WatchlistItem) {
        let all = [keeper] + duplicates
        keeper.watchStatus = DuplicateResolver.mostAdvancedWatchStatus(all.map(\.watchStatus))
        keeper.posterPath = DuplicateResolver.firstPresent(all.map(\.posterPath))
        keeper.backdropPath = DuplicateResolver.firstPresent(all.map(\.backdropPath))
        if keeper.genreIds.isEmpty, let genres = duplicates.first(where: { !$0.genreIds.isEmpty })?.genreIds {
            keeper.genreIds = genres
        }
    }
}

// MARK: - Environment Key

struct WatchlistManagerKey: EnvironmentKey {
    static let defaultValue = WatchlistManager()
}

extension EnvironmentValues {
    var watchlistManager: WatchlistManager {
        get { self[WatchlistManagerKey.self] }
        set { self[WatchlistManagerKey.self] = newValue }
    }
}
