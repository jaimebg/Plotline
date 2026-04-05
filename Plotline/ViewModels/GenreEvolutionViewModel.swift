import Foundation

/// Data point for genre evolution chart — avg rating for a given year
struct GenreYearPoint: Identifiable {
    var id: Int { year }
    let year: Int
    let avgRating: Double
}

/// Fetches average rating of top 20 movies per year for a selected genre over 50 years
@Observable
final class GenreEvolutionViewModel {
    // MARK: - State

    var points: [GenreYearPoint] = []
    var selectedGenreId: Int = 0
    var isLoading = false

    // MARK: - Private

    private let tmdbService: TMDBService
    private var cache: [Int: [GenreYearPoint]] = [:]

    init(tmdbService: TMDBService = .shared) {
        self.tmdbService = tmdbService
    }

    // MARK: - Fetch

    @MainActor
    func loadEvolution(genreId: Int) async {
        selectedGenreId = genreId

        // Return cached results if available
        if let cached = cache[genreId] {
            points = cached
            return
        }

        isLoading = true
        points = []

        let currentYear = Calendar.current.component(.year, from: Date())
        let startYear = currentYear - 49

        let result = await withTaskGroup(of: (Int, Double?).self, returning: [GenreYearPoint].self) { group in
            for year in startYear...currentYear {
                group.addTask {
                    let params: [String: String] = [
                        "with_genres": "\(genreId)",
                        "primary_release_year": "\(year)",
                        "sort_by": "vote_count.desc",
                        "vote_count.gte": "100"
                    ]

                    do {
                        let response = try await self.tmdbService.discoverMovies(params: params, page: 1)
                        let top20 = Array(response.results.prefix(20))
                        guard !top20.isEmpty else { return (year, nil) }
                        let avg = top20.map(\.voteAverage).reduce(0, +) / Double(top20.count)
                        return (year, avg)
                    } catch {
                        return (year, nil)
                    }
                }
            }

            var collected: [GenreYearPoint] = []
            for await (year, avg) in group {
                if let avg {
                    collected.append(GenreYearPoint(year: year, avgRating: avg))
                }
            }
            return collected.sorted { $0.year < $1.year }
        }

        points = result
        cache[genreId] = result
        isLoading = false
    }
}
