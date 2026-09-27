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
    /// The query `searchResults` (or `searchErrorMessage`) answers. It lags
    /// `searchText` while the user is typing and the debounce is pending.
    private(set) var resultsQuery: String = ""
    /// Set when the last search failed, so the screen can say so instead of
    /// showing "No Results" or an older query's results.
    private(set) var searchErrorMessage: String?

    let genres: [CuratedGenre] = CuratedGenre.all

    var isLoading = false
    var isSearching = false
    var hasSearched = false
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
            self.errorMessage = (error as? NetworkError)?.errorDescription ?? "Couldn't load content. Pull to refresh."
            #if DEBUG
            print("Error loading content: \(error)")
            #endif
        }

        isLoading = false
    }

    /// Loads the feeds unless they are already on screen.
    ///
    /// Discover's `.task` runs on every appearance of the tab, and used to
    /// refetch all four feeds each time the user came back to it. A failed
    /// load leaves no content, so returning to the tab still retries.
    @MainActor
    func loadContentIfNeeded() async {
        guard !hasContent else { return }
        await loadContent()
    }

    /// Refresh all content
    @MainActor
    func refresh() async {
        await loadContent()
    }

    /// How long typing has to pause before a search is sent.
    private static let searchDebounce: Duration = .milliseconds(350)

    /// Search for content with debouncing
    @MainActor
    func search() {
        // Cancel previous search task. Everything below runs on the main
        // actor, so a cancelled task can never write after this line: its
        // cancellation checks follow every suspension point.
        searchTask?.cancel()

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        // Clear results if search is empty
        guard !query.isEmpty else {
            searchResults = []
            resultsQuery = ""
            searchErrorMessage = nil
            isSearching = false
            hasSearched = false
            return
        }

        // Debounce search - delay showing loading state until user stops typing
        searchTask = Task {
            try? await Task.sleep(for: Self.searchDebounce)

            guard !Task.isCancelled else { return }

            // Only show loading state after debounce delay
            isSearching = true
            hasSearched = true

            do {
                let results = try await tmdbService.searchMulti(query: query)
                guard !Task.isCancelled else { return }
                searchResults = results
                searchErrorMessage = nil
            } catch {
                guard !Task.isCancelled else { return }
                #if DEBUG
                print("Search error: \(error)")
                #endif
                // Never leave the previous query's results under this one.
                searchResults = []
                searchErrorMessage = (error as? NetworkError)?.errorDescription
                    ?? "Couldn't search right now. Check your connection and try again."
            }

            resultsQuery = query
            isSearching = false
        }
    }

    /// Clear search
    @MainActor
    func clearSearch() {
        searchText = ""
        searchResults = []
        resultsQuery = ""
        searchErrorMessage = nil
        searchTask?.cancel()
        isSearching = false
        hasSearched = false
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
