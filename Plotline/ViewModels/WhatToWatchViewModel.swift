import Foundation
import Observation

/// ViewModel for the "What Should I Watch" 3-step recommendation flow
@Observable
final class WhatToWatchViewModel {
    // MARK: - State

    var currentStep: Int = 1
    var selectedMoods: [MoodFilter] = []
    var selectedTime: WatchTimeChoice?
    var results: [MediaItem] = []
    var whyLines: [Int: String] = [:]
    var isLoading = false

    // MARK: - Private

    private let tmdbService: TMDBService
    private var cachedPool: [MediaItem] = []

    // MARK: - Init

    init(tmdbService: TMDBService = .shared) {
        self.tmdbService = tmdbService
    }

    // MARK: - Computed

    var canProceedFromStep1: Bool { !selectedMoods.isEmpty }
    var canProceedFromStep2: Bool { selectedTime != nil }

    // MARK: - Mood Selection

    /// Add or remove a mood (max 2 selected)
    func toggleMood(_ mood: MoodFilter) {
        if let index = selectedMoods.firstIndex(of: mood) {
            selectedMoods.remove(at: index)
        } else if selectedMoods.count < 2 {
            selectedMoods.append(mood)
        }
    }

    // MARK: - Reset

    /// Clear all state back to step 1
    func reset() {
        currentStep = 1
        selectedMoods = []
        selectedTime = nil
        results = []
        whyLines = [:]
        isLoading = false
        cachedPool = []
    }

    // MARK: - Fetch

    /// Build TMDB discover params from selected moods, fetch results,
    /// filter out user's favorites/watchlist, and pick 3 random items
    @MainActor
    func fetchResults(
        favoriteIds: Set<Int>,
        watchlistIds: Set<Int>,
        topGenreIds: [Int]
    ) async {
        guard !selectedMoods.isEmpty, selectedTime != nil else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let params = buildDiscoverParams()
            let response: TMDBResponse

            switch selectedTime {
            case .movie:
                response = try await tmdbService.discoverMovies(params: params)
            case .series:
                response = try await tmdbService.discoverSeries(params: params)
            case .none:
                return
            }

            let excludedIds = favoriteIds.union(watchlistIds)

            cachedPool = response.results.filter { item in
                !excludedIds.contains(item.id) && item.posterPath != nil
            }

            pickRandomResults()
        } catch {
            #if DEBUG
            print("WhatToWatch fetch error: \(error)")
            #endif
            results = []
        }
    }

    /// Re-pick 3 random items from the cached pool
    @MainActor
    func shuffle(favoriteIds: Set<Int>, watchlistIds: Set<Int>) {
        let excludedIds = favoriteIds.union(watchlistIds)
        cachedPool = cachedPool.filter { !excludedIds.contains($0.id) }
        pickRandomResults()
    }

    // MARK: - Private Helpers

    private func buildDiscoverParams() -> [String: String] {
        var params: [String: String] = [
            "sort_by": "vote_average.desc",
            "include_adult": "false"
        ]

        // Combine genre IDs from all selected moods
        let allGenreIds = selectedMoods.flatMap(\.genreIds)
        if !allGenreIds.isEmpty {
            let uniqueIds = Array(Set(allGenreIds))
            params["with_genres"] = uniqueIds.map(String.init).joined(separator: "|")
        }

        // Use the strictest (highest) minRating among selected moods
        let ratings = selectedMoods.compactMap(\.minRating)
        if let maxRating = ratings.max() {
            params["vote_average.gte"] = String(maxRating)
        }

        // Use the strictest (highest) minVoteCount among selected moods
        let minVotes = selectedMoods.compactMap(\.minVoteCount)
        if let maxMinVote = minVotes.max() {
            params["vote_count.gte"] = String(maxMinVote)
        }

        // Use the most restrictive (lowest) maxVoteCount among selected moods
        let maxVotes = selectedMoods.compactMap(\.maxVoteCount)
        if let minMaxVote = maxVotes.min() {
            params["vote_count.lte"] = String(minMaxVote)
        }

        return params
    }

    private func pickRandomResults() {
        let picked = Array(cachedPool.shuffled().prefix(3))
        results = picked

        // Generate "why" lines based on selected moods
        whyLines = [:]
        for item in picked {
            whyLines[item.id] = generateWhyLine(for: item)
        }
    }

    private func generateWhyLine(for item: MediaItem) -> String {
        let moodLabels = selectedMoods.map(\.label)

        if moodLabels.count == 2 {
            return "Matches your \(moodLabels[0]) + \(moodLabels[1]) mood"
        } else if let first = moodLabels.first {
            return "Matches your \(first) mood"
        }

        return "Recommended for you"
    }
}
