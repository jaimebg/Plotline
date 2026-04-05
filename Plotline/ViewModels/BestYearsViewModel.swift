import Foundation

/// Data point for best years chart — avg rating for a given year
struct YearRating: Identifiable {
    var id: Int { year }
    let year: Int
    let avgRating: Double
}

/// Fetches average rating of top 20 movies per year for the last 30 years, filterable by genre
@Observable
final class BestYearsViewModel {
    // MARK: - State

    var yearRatings: [YearRating] = []
    var selectedGenreId: Int? = nil
    var isLoading = false

    /// The year with the highest average rating
    var bestYear: Int? {
        yearRatings.max(by: { $0.avgRating < $1.avgRating })?.year
    }

    // MARK: - Private

    private let tmdbService: TMDBService
    private var cache: [String: [YearRating]] = [:]

    init(tmdbService: TMDBService = .shared) {
        self.tmdbService = tmdbService
    }

    // MARK: - Fetch

    @MainActor
    func loadBestYears(genreId: Int? = nil) async {
        selectedGenreId = genreId
        let cacheKey = genreId.map { "\($0)" } ?? "all"

        // Return cached results if available
        if let cached = cache[cacheKey] {
            yearRatings = cached
            return
        }

        isLoading = true
        yearRatings = []

        let currentYear = Calendar.current.component(.year, from: Date())
        let startYear = currentYear - 29

        let result = await withTaskGroup(of: (Int, Double?).self, returning: [YearRating].self) { group in
            for year in startYear...currentYear {
                group.addTask {
                    var params: [String: String] = [
                        "primary_release_year": "\(year)",
                        "sort_by": "vote_average.desc",
                        "vote_count.gte": "200"
                    ]
                    if let genreId {
                        params["with_genres"] = "\(genreId)"
                    }

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

            var collected: [YearRating] = []
            for await (year, avg) in group {
                if let avg {
                    collected.append(YearRating(year: year, avgRating: avg))
                }
            }
            return collected.sorted { $0.year < $1.year }
        }

        yearRatings = result
        cache[cacheKey] = result
        isLoading = false
    }
}
