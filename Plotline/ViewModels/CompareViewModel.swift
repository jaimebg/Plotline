import Foundation

/// ViewModel for the Visual Comparator — manages up to 3 media items for side-by-side comparison
///
/// `@MainActor` because every stored property here is observed by SwiftUI on the
/// main actor; `selectItem(_:for:)` and the debounced search task would otherwise
/// mutate them from whatever executor resumed the awaited call.
@Observable
@MainActor
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

    /// One in-flight selection per slot. Picking again for the same slot
    /// cancels the older fetch, and the token check below stops a fetch that
    /// answers after cancellation from overwriting the newer pick.
    private var selectionTasks: [Int: Task<Void, Never>] = [:]
    private var selectionTokens: [Int: UUID] = [:]
    /// What each slot is loading, so a title still being fetched for one slot
    /// cannot be picked for another in the meantime.
    private var pendingItems: [Int: MediaItem] = [:]

    /// Whether `item` already fills a slot other than `slotIndex`.
    ///
    /// Movies and series have separate TMDB id spaces, so the media type is
    /// part of the identity. Comparing a title with itself says nothing, and
    /// the same title twice would share its episode data and its chart keys.
    func isInAnotherSlot(_ item: MediaItem, excluding slotIndex: Int) -> Bool {
        let matches = { (other: MediaItem?) in
            other.map { $0.id == item.id && $0.isTVSeries == item.isTVSeries } ?? false
        }
        return slots.indices.contains { index in
            index != slotIndex && (matches(slots[index]) || matches(pendingItems[index]))
        }
    }

    /// Select a media item for a slot, fetching full details and ratings.
    ///
    /// Returns immediately; the fetch runs in a task owned by the slot.
    func selectItem(_ item: MediaItem, for slotIndex: Int) {
        guard slotIndex >= 0, slotIndex < slots.count else { return }
        guard !isInAnotherSlot(item, excluding: slotIndex) else { return }

        selectionTasks[slotIndex]?.cancel()
        let token = UUID()
        selectionTokens[slotIndex] = token
        let previous = slots[slotIndex]
        pendingItems[slotIndex] = item
        isLoadingSlot[slotIndex] = true

        selectionTasks[slotIndex] = Task { [weak self] in
            guard let self else { return }
            let isCurrent = { !Task.isCancelled && self.selectionTokens[slotIndex] == token }

            var detailed = item
            var episodes: [Int: [EpisodeMetric]]?
            do {
                // Fetch full TMDB details
                detailed = try await TMDBService.shared.fetchDetails(for: item)

                // Episode metrics come from TMDB, keyed by the series' TMDB id.
                if detailed.isTVSeries, let totalSeasons = detailed.totalSeasons, totalSeasons > 0 {
                    episodes = await TMDBService.shared.fetchAllSeasons(
                        seriesId: detailed.id,
                        totalSeasons: totalSeasons
                    ).episodesBySeason
                }
            } catch {
                // On failure, still set the basic item so the slot is not empty
                detailed = item
            }

            guard isCurrent() else { return }
            slots[slotIndex] = detailed
            if let episodes {
                episodesData[detailed.id] = episodes
            }
            if let previous { releaseEpisodesIfUnused(previous) }
            isLoadingSlot[slotIndex] = false
            pendingItems[slotIndex] = nil
            selectionTasks[slotIndex] = nil
        }
    }

    /// Remove a slot and its associated data
    func removeSlot(_ index: Int) {
        guard index >= 0, index < slots.count else { return }
        selectionTasks[index]?.cancel()
        selectionTasks[index] = nil
        selectionTokens[index] = nil
        pendingItems[index] = nil
        isLoadingSlot[index] = false
        let removed = slots[index]
        slots[index] = nil
        if let removed { releaseEpisodesIfUnused(removed) }
    }

    /// Drops a series' episode data once no slot shows it any more.
    private func releaseEpisodesIfUnused(_ item: MediaItem) {
        guard item.isTVSeries else { return }
        let stillShown = slots.contains { $0?.id == item.id && $0?.isTVSeries == true }
        if !stillShown {
            episodesData.removeValue(forKey: item.id)
        }
    }

    // MARK: - Chart Labels

    /// The name a slot's series goes by in a chart legend.
    ///
    /// Charts group marks by this string, so two slots must never share one:
    /// "Dune" (1984) and "Dune" (2021) used to collapse into a single series.
    /// A title that is unique among the filled slots stays as it is; a
    /// repeated one gains its year, and if that still collides, its slot.
    func chartLabel(forSlot slotIndex: Int) -> String {
        guard slotIndex >= 0, slotIndex < slots.count, let item = slots[slotIndex] else { return "" }
        let others = filledSlots.filter { $0.index != slotIndex }.map(\.item)
        guard others.contains(where: { $0.displayTitle == item.displayTitle }) else {
            return item.displayTitle
        }
        let withYear = item.year.map { "\(item.displayTitle) (\($0))" } ?? item.displayTitle
        let yearCollides = others.contains {
            $0.displayTitle == item.displayTitle && $0.year == item.year
        }
        return yearCollides ? "\(withYear) #\(slotIndex + 1)" : withYear
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
        // A search still debouncing or in flight from the last time the sheet
        // was open would otherwise land its results in this one.
        searchTask?.cancel()
        searchTask = nil
        isSearching = false
        searchSlotIndex = slotIndex
        searchQuery = ""
        searchResults = []
        showSearch = true
    }
}
