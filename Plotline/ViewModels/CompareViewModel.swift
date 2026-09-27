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

    /// The engine's analysis per series slot, keyed by slot index. Seeded from
    /// the bundle and replaced by a live result only under the detail screen's
    /// completeness rule — see `CompareSlotAnalysis`.
    private(set) var slotAnalyses: [Int: CompareSlotAnalysis] = [:]
    /// Slots whose analysis is being retried.
    private(set) var retryingSlots: Set<Int> = []
    /// Slots whose TMDB details arrived. Without them the season count and
    /// the series status are unknown, so a retry fetches them first.
    private var detailsLoaded: Set<Int> = []

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
        retryingSlots.remove(slotIndex)

        selectionTasks[slotIndex] = Task { [weak self] in
            guard let self else { return }
            let isCurrent = { !Task.isCancelled && self.selectionTokens[slotIndex] == token }

            var detailed = item
            var gotDetails = false
            var fetched: SeasonFetchResult?
            do {
                // Fetch full TMDB details
                detailed = try await TMDBService.shared.fetchDetails(for: item)
                gotDetails = true

                // Episode metrics come from TMDB, keyed by the series' TMDB id.
                if detailed.isTVSeries, let totalSeasons = detailed.totalSeasons, totalSeasons > 0 {
                    fetched = await TMDBService.shared.fetchAllSeasons(
                        seriesId: detailed.id,
                        totalSeasons: totalSeasons
                    )
                }
            } catch {
                // On failure, still set the basic item so the slot is not empty
                detailed = item
            }

            guard isCurrent() else { return }
            slots[slotIndex] = detailed
            if let previous { releaseEpisodesIfUnused(previous) }
            if gotDetails { detailsLoaded.insert(slotIndex) } else { detailsLoaded.remove(slotIndex) }

            if detailed.isTVSeries {
                // The bundled analysis is the instant seed; the live fetch
                // replaces it only when at least as complete.
                var analysis = CompareSlotAnalysis.seeded(
                    bundled: DatasetStore.shared.entry(forTMDBId: detailed.id)?.analysis,
                    status: gotDetails ? .reported(hasEnded: detailed.hasEnded) : .notLoaded
                )
                if let fetched {
                    let folded = analysis.folding(fetched, into: [:], hasEnded: detailed.hasEnded, asOf: Date())
                    analysis = folded.analysis
                    episodesData[detailed.id] = folded.episodes
                }
                slotAnalyses[slotIndex] = analysis
            } else {
                slotAnalyses[slotIndex] = nil
            }
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
        retryingSlots.remove(index)
        detailsLoaded.remove(index)
        slotAnalyses[index] = nil
        let removed = slots[index]
        slots[index] = nil
        if let removed { releaseEpisodesIfUnused(removed) }
    }

    /// Refetches a series slot's episodes after some or all of them failed.
    ///
    /// Fetches the details first when they never arrived: without them the
    /// season count is unknown, and a retry would ask for nothing and call
    /// that complete. What already loaded is kept — the fetch is merged in.
    func retryAnalysis(forSlot slotIndex: Int) {
        guard slotIndex >= 0, slotIndex < slots.count,
              let item = slots[slotIndex], item.isTVSeries,
              selectionTasks[slotIndex] == nil else { return }

        let token = UUID()
        selectionTokens[slotIndex] = token
        retryingSlots.insert(slotIndex)
        let needsDetails = !detailsLoaded.contains(slotIndex)

        selectionTasks[slotIndex] = Task { [weak self] in
            guard let self else { return }
            let isCurrent = { !Task.isCancelled && self.selectionTokens[slotIndex] == token }

            var detailed = item
            var gotDetails = !needsDetails
            if needsDetails, let fresh = try? await TMDBService.shared.fetchDetails(for: item) {
                detailed = fresh
                gotDetails = true
            }

            var fetched: SeasonFetchResult?
            if gotDetails, let totalSeasons = detailed.totalSeasons, totalSeasons > 0 {
                fetched = await TMDBService.shared.fetchAllSeasons(seriesId: detailed.id, totalSeasons: totalSeasons)
            }

            guard isCurrent() else { return }
            if gotDetails {
                slots[slotIndex] = detailed
                detailsLoaded.insert(slotIndex)
            }

            let status: CurrentSeriesStatus = gotDetails ? .reported(hasEnded: detailed.hasEnded) : .notLoaded
            let current = slotAnalyses[slotIndex] ?? .seeded(
                bundled: DatasetStore.shared.entry(forTMDBId: detailed.id)?.analysis,
                status: status
            )
            if let fetched {
                let folded = current.folding(
                    fetched,
                    into: episodesData[detailed.id] ?? [:],
                    hasEnded: detailed.hasEnded,
                    asOf: Date()
                )
                slotAnalyses[slotIndex] = folded.analysis
                episodesData[detailed.id] = folded.episodes
            } else {
                slotAnalyses[slotIndex] = current.updatingStatus(status)
            }

            retryingSlots.remove(slotIndex)
            selectionTasks[slotIndex] = nil
        }
    }

    /// The Plotline Analysis section's view of every filled slot, in order.
    var analysisEntries: [CompareAnalysisEntry] {
        filledSlots.map { index, item in
            CompareAnalysisEntry.make(
                slotIndex: index,
                label: chartLabel(forSlot: index),
                isSeries: item.isTVSeries,
                isRetrying: retryingSlots.contains(index),
                analysis: slotAnalyses[index]
            )
        }
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
