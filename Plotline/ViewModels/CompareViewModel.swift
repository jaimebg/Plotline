import Foundation

/// ViewModel for the Visual Comparator — manages up to 3 media items for side-by-side comparison
@Observable
final class CompareViewModel {
    // MARK: - Slot State

    var slots: [MediaItem?] = [nil, nil, nil]
    var ratingsData: [Int: [RatingSource]] = [:]
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

    /// All rating source names present across all filled slots
    var allRatingSources: [String] {
        var sources: [String] = []
        // TMDB is always available
        sources.append("TMDB")
        // Collect external rating sources
        let externalSources = ["Internet Movie Database", "Rotten Tomatoes", "Metacritic"]
        for sourceName in externalSources {
            let anyHasIt = filledSlots.contains { _, item in
                ratingsData[item.id]?.contains { $0.source == sourceName } == true
            }
            if anyHasIt {
                sources.append(sourceName)
            }
        }
        return sources
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
            var detailed = try await TMDBService.shared.fetchDetails(for: item)

            // Store in slot
            slots[slotIndex] = detailed

            // Fetch OMDb ratings if we have an IMDb ID
            if let imdbId = detailed.imdbId {
                if let ratings = try? await OMDbService.shared.fetchRatings(imdbId: imdbId) {
                    ratingsData[detailed.id] = ratings
                    detailed.externalRatings = ratings
                    slots[slotIndex] = detailed
                }

                // Fetch season episodes for TV series
                if detailed.isTVSeries, let totalSeasons = detailed.totalSeasons, totalSeasons > 0 {
                    var seasonMap: [Int: [EpisodeMetric]] = [:]
                    for season in 1...totalSeasons {
                        if let episodes = try? await OMDbService.shared.fetchSeasonEpisodes(
                            imdbId: imdbId, season: season
                        ) {
                            seasonMap[season] = episodes
                        }
                    }
                    episodesData[detailed.id] = seasonMap
                }
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
            ratingsData.removeValue(forKey: item.id)
            episodesData.removeValue(forKey: item.id)
        }
        slots[index] = nil
    }

    /// Returns all episodes flattened across all seasons for a series
    func allEpisodesFlat(for mediaId: Int) -> [EpisodeMetric] {
        guard let seasonMap = episodesData[mediaId] else { return [] }
        return seasonMap.keys.sorted().flatMap { seasonMap[$0] ?? [] }
    }

    /// Normalized rating value (0-100) for a given source and item
    func normalizedRating(for sourceName: String, item: MediaItem) -> Double? {
        if sourceName == "TMDB" {
            return item.voteAverage * 10 // voteAverage is 0-10
        }
        guard let ratings = ratingsData[item.id] else { return nil }
        guard let rating = ratings.first(where: { $0.source == sourceName }) else { return nil }
        guard let normalized = rating.normalizedValue else { return nil }
        return normalized * 100 // normalizedValue is 0-1, we want 0-100
    }

    /// Display value for a given source and item
    func displayRating(for sourceName: String, item: MediaItem) -> String? {
        if sourceName == "TMDB" {
            return item.formattedRating
        }
        guard let ratings = ratingsData[item.id] else { return nil }
        return ratings.first(where: { $0.source == sourceName })?.displayValue
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
