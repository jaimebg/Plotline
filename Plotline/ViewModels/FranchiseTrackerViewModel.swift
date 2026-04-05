import Foundation
import Combine

/// Searches movie collections and shows franchise quality over time
@Observable
final class FranchiseTrackerViewModel {
    // MARK: - State

    var searchText = ""
    var searchResults: [TMDBCollectionSearchResult] = []
    var selectedCollection: TMDBCollectionResponse?
    var movies: [CollectionMovie] = []
    var isSearching = false
    var isLoadingCollection = false

    // MARK: - Private

    private let tmdbService: TMDBService
    private var searchTask: Task<Void, Never>?

    init(tmdbService: TMDBService = .shared) {
        self.tmdbService = tmdbService
    }

    // MARK: - Search (debounced)

    @MainActor
    func updateSearch(_ query: String) {
        searchText = query
        searchTask?.cancel()

        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            searchResults = []
            isSearching = false
            return
        }

        isSearching = true

        searchTask = Task {
            // Debounce 500ms
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }

            do {
                let response = try await tmdbService.searchCollections(query: query)
                guard !Task.isCancelled else { return }
                searchResults = response.results
            } catch {
                guard !Task.isCancelled else { return }
                searchResults = []
            }

            isSearching = false
        }
    }

    // MARK: - Load Collection

    @MainActor
    func loadCollection(id: Int) async {
        isLoadingCollection = true

        do {
            let response = try await tmdbService.fetchCollection(id: id)
            selectedCollection = response
            // Sort movies chronologically
            movies = response.parts.sorted { m1, m2 in
                (m1.yearInt ?? 0) < (m2.yearInt ?? 0)
            }
        } catch {
            #if DEBUG
            debugPrint("Failed to load collection: \(error)")
            #endif
        }

        isLoadingCollection = false
    }

    // MARK: - Navigation

    @MainActor
    func goBackToSearch() {
        selectedCollection = nil
        movies = []
    }
}
