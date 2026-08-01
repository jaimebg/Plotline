import Foundation

/// ViewModel for the Visual Comparator — manages up to 3 media items for side-by-side comparison
@Observable
final class CompareViewModel {
    // MARK: - Slot State

    var slots: [MediaItem?] = [nil, nil, nil]
    var episodesData: [Int: [Int: [EpisodeMetric]]] = [:] // mediaId -> seasonNum -> episodes
    var isLoadingSlot: [Int: Bool] = [:]

    // MARK: - Search Sheet State

    var showSearch = false
    var searchSlotIndex = 0
    var searchQuery = ""
    var searchResults: [MediaItem] = []
    var isSearching = false

    // MARK: - Computed Properties

    var filledSlotCount: Int {
        slots.compactMap { $0 }.count
    }

    var canCompare: Bool {
        filledSlotCount >= 2
    }

    var filledSlots: [(index: Int, item: MediaItem)] {
        slots.enumerated().compactMap { index, item in
            guard let item else { return nil }
            return (index, item)
        }
    }

    var hasAnyMovie: Bool {
        filledSlots.contains { !$0.item.isTVSeries }
    }

    var hasAnySeries: Bool {
        filledSlots.contains { $0.item.isTVSeries }
    }

    /// Shared genre IDs across all filled slots
    var sharedGenreIds: Set<Int> {
        let genreSets = filledSlots.compactMap { $0.item.genreIds }.map { Set($0) }
        guard let first = genreSets.first else { return [] }
        return genreSets.dropFirst().reduce(first) { $0.intersection($1) }
    }

    /// All unique genre IDs across all filled slots
    var allGenreIds: [Int] {
        let all = filledSlots.flatMap { $0.item.genreIds ?? [] }
        return Array(Set(all)).sorted()
    }

    // MARK: - Actions

    /// Select a media item for a slot, fetching full details and ratings
    func selectItem(_ item: MediaItem, for slotIndex: Int) async {
        guard slotIndex >= 0, slotIndex < slots.count else { return }

        isLoadingSlot[slotIndex] = true
        defer { isLoadingSlot[slotIndex] = false }

        do {
            // Fetch full TMDB details
            let detailed = try await TMDBService.shared.fetchDetails(for: item)

            // Store in slot
            slots[slotIndex] = detailed

            // Episode metrics come from TMDB, keyed by the series' TMDB id.
            if detailed.isTVSeries, let totalSeasons = detailed.totalSeasons, totalSeasons > 0 {
                episodesData[detailed.id] = await TMDBService.shared.fetchAllSeasons(
                    seriesId: detailed.id,
                    totalSeasons: totalSeasons
                )
            }
        } catch {
            // On failure, still set the basic item so the slot is not empty
            slots[slotIndex] = item
        }
    }

    /// Remove a slot and its associated data
    func removeSlot(_ index: Int) {
        guard index >= 0, index < slots.count else { return }
        if let item = slots[index] {
            episodesData.removeValue(forKey: item.id)
        }
        slots[index] = nil
    }

    /// Returns all episodes flattened across all seasons for a series
    func allEpisodesFlat(for mediaId: Int) -> [EpisodeMetric] {
        guard let seasonMap = episodesData[mediaId] else { return [] }
        return seasonMap.keys.sorted().flatMap { seasonMap[$0] ?? [] }
    }

    /// Normalized rating value (0-100) for an item
    func normalizedRating(for item: MediaItem) -> Double? {
        item.voteAverage > 0 ? item.voteAverage * 10 : nil
    }

    /// Display value for an item's rating
    func displayRating(for item: MediaItem) -> String? {
        item.voteAverage > 0 ? item.formattedRating : nil
    }

    // MARK: - Search

    private var searchTask: Task<Void, Never>?

    func performSearch() {
        searchTask?.cancel()

        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }

        isSearching = true
        searchTask = Task {
            // Debounce
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }

            do {
                let results = try await TMDBService.shared.searchMulti(query: query)
                guard !Task.isCancelled else { return }
                searchResults = results
            } catch {
                guard !Task.isCancelled else { return }
                searchResults = []
            }
            isSearching = false
        }
    }

    func openSearchSheet(for slotIndex: Int) {
        searchSlotIndex = slotIndex
        searchQuery = ""
        searchResults = []
        showSearch = true
    }
}
