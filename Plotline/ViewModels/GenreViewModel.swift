import Foundation
import Observation

/// Sort options for genre discovery results
enum GenreSort: String, CaseIterable {
    case popularity = "Popularity"
    case rating = "Rating"
    case releaseDate = "Release Date"

    /// TMDB `sort_by` value for movies
    var movieSortKey: String {
        switch self {
        case .popularity: return "popularity.desc"
        case .rating: return "vote_average.desc"
        case .releaseDate: return "primary_release_date.desc"
        }
    }

    /// TMDB `sort_by` value for TV series
    var tvSortKey: String {
        switch self {
        case .popularity: return "popularity.desc"
        case .rating: return "vote_average.desc"
        case .releaseDate: return "first_air_date.desc"
        }
    }

    var icon: String {
        switch self {
        case .popularity: return "flame"
        case .rating: return "star.fill"
        case .releaseDate: return "calendar"
        }
    }
}

/// Media type toggle for genre results
enum GenreMediaType: String, CaseIterable {
    case movies = "Movies"
    case series = "Series"
}

/// ViewModel for genre discovery results
@Observable
final class GenreResultsViewModel {
    // MARK: - State

    var results: [MediaItem] = []

    var isLoadingResults = false
    var isLoadingMore = false

    var selectedMediaType: GenreMediaType = .movies
    var selectedSort: GenreSort = .popularity

    var currentPage = 1
    var totalPages = 1

    var errorMessage: String?

    // MARK: - Private

    private let tmdbService: TMDBService

    init(tmdbService: TMDBService = .shared) {
        self.tmdbService = tmdbService
    }

    // MARK: - Results

    @MainActor
    func loadResults(genreId: Int) async {
        currentPage = 1
        totalPages = 1
        isLoadingResults = true
        results = []
        errorMessage = nil

        do {
            let sortKey = selectedMediaType == .movies ? selectedSort.movieSortKey : selectedSort.tvSortKey
            let response: TMDBResponse
            if selectedMediaType == .movies {
                response = try await tmdbService.discoverMovies(genreId: genreId, sortBy: sortKey, page: 1)
            } else {
                response = try await tmdbService.discoverSeries(genreId: genreId, sortBy: sortKey, page: 1)
            }
            results = response.results.filter { $0.posterPath != nil }
            totalPages = response.totalPages
            currentPage = 1
        } catch {
            errorMessage = "Couldn't load results"
            #if DEBUG
            debugPrint("Failed to load genre results: \(error)")
            #endif
        }

        isLoadingResults = false
    }

    @MainActor
    func loadMore(genreId: Int) async {
        guard !isLoadingMore && currentPage < totalPages else { return }

        isLoadingMore = true
        let nextPage = currentPage + 1

        do {
            let sortKey = selectedMediaType == .movies ? selectedSort.movieSortKey : selectedSort.tvSortKey
            let response: TMDBResponse
            if selectedMediaType == .movies {
                response = try await tmdbService.discoverMovies(genreId: genreId, sortBy: sortKey, page: nextPage)
            } else {
                response = try await tmdbService.discoverSeries(genreId: genreId, sortBy: sortKey, page: nextPage)
            }

            let newItems = response.results.filter { $0.posterPath != nil }
            let existingIds = Set(results.map(\.id))
            results.append(contentsOf: newItems.filter { !existingIds.contains($0.id) })
            currentPage = nextPage
            totalPages = response.totalPages
        } catch {
            #if DEBUG
            debugPrint("Failed to load more genre results: \(error)")
            #endif
        }

        isLoadingMore = false
    }

    var canLoadMore: Bool {
        currentPage < totalPages && !isLoadingMore
    }
}
