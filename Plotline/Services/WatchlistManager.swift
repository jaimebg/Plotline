import Foundation
import SwiftData
import SwiftUI

/// Manager for handling watchlist items with SwiftData persistence
@Observable
final class WatchlistManager {
    private var modelContext: ModelContext?
    private(set) var watchlistItems: [WatchlistItem] = []
    private(set) var watchlistIds: Set<Int> = []

    init() {}

    func configure(with context: ModelContext) {
        self.modelContext = context
        fetchWatchlist()
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

        let descriptor = FetchDescriptor<WatchlistItem>(
            sortBy: [SortDescriptor(\.addedAt, order: .reverse)]
        )

        do {
            let allItems = try context.fetch(descriptor)

            // Deduplicate by tmdbId (keep earliest added, remove later duplicates from CloudKit sync)
            var seenIds = Set<Int>()
            var uniqueItems: [WatchlistItem] = []
            var duplicatesToDelete: [WatchlistItem] = []

            for item in allItems {
                if seenIds.contains(item.tmdbId) {
                    duplicatesToDelete.append(item)
                } else {
                    seenIds.insert(item.tmdbId)
                    uniqueItems.append(item)
                }
            }

            // Clean up any duplicates that arrived via CloudKit
            for duplicate in duplicatesToDelete {
                context.delete(duplicate)
            }
            if !duplicatesToDelete.isEmpty {
                try context.save()
            }

            watchlistItems = uniqueItems
            watchlistIds = seenIds
        } catch {
            #if DEBUG
            print("Failed to fetch watchlist: \(error)")
            #endif
            watchlistItems = []
            watchlistIds = []
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
