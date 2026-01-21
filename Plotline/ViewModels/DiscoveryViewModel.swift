import Foundation
import Observation

/// ViewModel for the Discovery screen
@Observable
final class DiscoveryViewModel {
    // MARK: - Published State

    var trendingMovies: [MediaItem] = []
    var trendingSeries: [MediaItem] = []
    var topRatedMovies: [MediaItem] = []
    var topRatedSeries: [MediaItem] = []

    var searchResults: [MediaItem] = []
    var searchText: String = ""

    var isLoading = false
    var isSearching = false
    var errorMessage: String?

    // MARK: - Private Properties

    private let tmdbService: TMDBService
    private var searchTask: Task<Void, Never>?

    // MARK: - Initialization

    init(tmdbService: TMDBService = .shared) {
        self.tmdbService = tmdbService
    }

    // MARK: - Public Methods

    /// Load all discovery content
    @MainActor
    func loadContent() async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil

        do {
            // Fetch all content concurrently
            async let movies = tmdbService.fetchTrendingMovies()
            async let series = tmdbService.fetchTrendingSeries()
            async let topMovies = tmdbService.fetchTopRatedMovies()
            async let topSeries = tmdbService.fetchTopRatedSeries()

            self.trendingMovies = try await movies
            self.trendingSeries = try await series
            self.topRatedMovies = try await topMovies
            self.topRatedSeries = try await topSeries

        } catch {
            self.errorMessage = error.localizedDescription
            #if DEBUG
            print("Error loading content: \(error)")
            #endif
        }

        isLoading = false
    }

    /// Refresh all content
    @MainActor
    func refresh() async {
        await loadContent()
    }

    /// Search for content with debouncing
    @MainActor
    func search() {
        // Cancel previous search task
        searchTask?.cancel()

        // Clear results if search is empty
        guard !searchText.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }

        // Show loading state immediately to avoid showing "No Results" during debounce
        isSearching = true

        // Debounce search
        searchTask = Task {
            // Wait 300ms before searching
            try? await Task.sleep(for: .milliseconds(300))

            guard !Task.isCancelled else { return }

            do {
                let results = try await tmdbService.searchMulti(query: searchText)
                guard !Task.isCancelled else { return }
                self.searchResults = results
            } catch {
                guard !Task.isCancelled else { return }
                #if DEBUG
                print("Search error: \(error)")
                #endif
            }

            isSearching = false
        }
    }

    /// Clear search
    @MainActor
    func clearSearch() {
        searchText = ""
        searchResults = []
        searchTask?.cancel()
        isSearching = false
    }

    // MARK: - Computed Properties

    /// Check if there's content to display
    var hasContent: Bool {
        !trendingMovies.isEmpty || !trendingSeries.isEmpty
    }

    /// Check if search is active
    var isSearchActive: Bool {
        !searchText.isEmpty
    }

    /// Check if showing search results
    var showSearchResults: Bool {
        isSearchActive && !searchResults.isEmpty
    }
}

// MARK: - Preview Helper

extension DiscoveryViewModel {
    static var preview: DiscoveryViewModel {
        let vm = DiscoveryViewModel()
        vm.trendingMovies = [.moviePreview]
        vm.trendingSeries = [.preview]
        vm.topRatedMovies = [.moviePreview]
        vm.topRatedSeries = [.preview]
        return vm
    }
}
