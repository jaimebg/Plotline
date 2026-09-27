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
///
/// Every request belongs to one query — a media type and a sort — and results
/// only land if that query is still the one on screen. Switching Movies to
/// Series used to leave the movie request running: if it answered second it
/// filled the Series tab with movies, and an in-flight page 2 appended movies
/// to series and advanced the page counter. Now changing the query cancels
/// both the first-page and the next-page request, and a generation number
/// catches anything that answers after cancellation anyway.
@Observable
final class GenreResultsViewModel {
    // MARK: - State

    var results: [MediaItem] = []

    var isLoadingResults = false
    var isLoadingMore = false

    private(set) var selectedMediaType: GenreMediaType = .movies
    private(set) var selectedSort: GenreSort = .popularity

    var currentPage = 1
    var totalPages = 1

    var errorMessage: String?

    // MARK: - Private

    private let tmdbService: TMDBService
    @ObservationIgnored private var loadTask: Task<Void, Never>?
    @ObservationIgnored private var loadMoreTask: Task<Void, Never>?
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var hasLoaded = false

    init(tmdbService: TMDBService = .shared) {
        self.tmdbService = tmdbService
    }

    // MARK: - Query

    @MainActor
    func selectMediaType(_ type: GenreMediaType, genre: CuratedGenre) {
        guard type != selectedMediaType else { return }
        selectedMediaType = type
        reload(genre: genre)
    }

    @MainActor
    func selectSort(_ sort: GenreSort, genre: CuratedGenre) {
        guard sort != selectedSort else { return }
        selectedSort = sort
        reload(genre: genre)
    }

    /// First load only; returning from a pushed detail keeps what is there.
    @MainActor
    func loadIfNeeded(genre: CuratedGenre) {
        guard !hasLoaded else { return }
        reload(genre: genre)
    }

    // MARK: - Results

    /// Starts over at page 1 for the current query, abandoning any request
    /// that belongs to a previous one.
    @MainActor
    func reload(genre: CuratedGenre) {
        loadTask?.cancel()
        loadMoreTask?.cancel()
        generation += 1
        hasLoaded = true

        let run = generation
        let mediaType = selectedMediaType
        let sort = selectedSort

        currentPage = 1
        totalPages = 1
        isLoadingResults = true
        isLoadingMore = false
        results = []
        errorMessage = nil

        loadTask = Task { [weak self] in
            guard let self else { return }
            do {
                let response = try await fetchPage(1, genre: genre, mediaType: mediaType, sort: sort)
                guard run == generation, !Task.isCancelled else { return }
                results = response.results.filter { $0.posterPath != nil }
                totalPages = response.totalPages
                currentPage = 1
            } catch {
                guard run == generation, !Task.isCancelled else { return }
                errorMessage = "Couldn't load results"
                #if DEBUG
                debugPrint("Failed to load genre results: \(error)")
                #endif
            }
            isLoadingResults = false
        }
    }

    @MainActor
    func loadMore(genre: CuratedGenre) {
        guard canLoadMore, !isLoadingResults else { return }

        let run = generation
        let mediaType = selectedMediaType
        let sort = selectedSort
        let nextPage = currentPage + 1
        isLoadingMore = true

        loadMoreTask = Task { [weak self] in
            guard let self else { return }
            do {
                let response = try await fetchPage(nextPage, genre: genre, mediaType: mediaType, sort: sort)
                guard run == generation, !Task.isCancelled else { return }
                let newItems = response.results.filter { $0.posterPath != nil }
                let existingIds = Set(results.map(\.id))
                results.append(contentsOf: newItems.filter { !existingIds.contains($0.id) })
                currentPage = nextPage
                totalPages = response.totalPages
            } catch {
                guard run == generation, !Task.isCancelled else { return }
                #if DEBUG
                debugPrint("Failed to load more genre results: \(error)")
                #endif
            }
            isLoadingMore = false
        }
    }

    var canLoadMore: Bool {
        currentPage < totalPages && !isLoadingMore
    }

    private func fetchPage(
        _ page: Int,
        genre: CuratedGenre,
        mediaType: GenreMediaType,
        sort: GenreSort
    ) async throws -> TMDBResponse {
        let genreId = genre.genreId(for: mediaType)
        switch mediaType {
        case .movies:
            return try await tmdbService.discoverMovies(genreId: genreId, sortBy: sort.movieSortKey, page: page)
        case .series:
            return try await tmdbService.discoverSeries(genreId: genreId, sortBy: sort.tvSortKey, page: page)
        }
    }
}
