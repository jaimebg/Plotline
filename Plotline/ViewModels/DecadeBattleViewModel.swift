import Foundation

/// Data for a single decade in the decade battle comparison
struct DecadeData: Identifiable {
    var id: String { decade }
    let decade: String
    let avgRating: Double
    let highRatedCount: Int
    let topGenre: String
}

/// Fetches top 50 movies per decade from 1970s to 2020s and computes comparative stats
@Observable
final class DecadeBattleViewModel {
    // MARK: - State

    var decades: [DecadeData] = []
    var isLoading = false

    // MARK: - Private

    private let tmdbService: TMDBService

    init(tmdbService: TMDBService = .shared) {
        self.tmdbService = tmdbService
    }

    // MARK: - Decades Definition

    private static let decadeRanges: [(label: String, start: String, end: String)] = [
        ("1970s", "1970-01-01", "1979-12-31"),
        ("1980s", "1980-01-01", "1989-12-31"),
        ("1990s", "1990-01-01", "1999-12-31"),
        ("2000s", "2000-01-01", "2009-12-31"),
        ("2010s", "2010-01-01", "2019-12-31"),
        ("2020s", "2020-01-01", "2029-12-31"),
    ]

    // MARK: - Fetch

    @MainActor
    func loadDecades() async {
        guard decades.isEmpty else { return }

        isLoading = true

        let result = await withTaskGroup(
            of: (String, [MediaItem]).self,
            returning: [DecadeData].self
        ) { group in
            for range in Self.decadeRanges {
                group.addTask {
                    let params: [String: String] = [
                        "primary_release_date.gte": range.start,
                        "primary_release_date.lte": range.end,
                        "sort_by": "vote_average.desc",
                        "vote_count.gte": "500"
                    ]

                    do {
                        // Fetch pages 1-3 to get up to 60 results (take top 50)
                        var allMovies: [MediaItem] = []
                        for page in 1...3 {
                            let response = try await self.tmdbService.discoverMovies(params: params, page: page)
                            allMovies.append(contentsOf: response.results)
                            if response.totalPages <= page { break }
                        }
                        let top50 = Array(allMovies.prefix(50))
                        return (range.label, top50)
                    } catch {
                        return (range.label, [])
                    }
                }
            }

            var collected: [DecadeData] = []
            for await (label, movies) in group {
                guard !movies.isEmpty else { continue }

                let avgRating = movies.map(\.voteAverage).reduce(0, +) / Double(movies.count)
                let highRatedCount = movies.filter { $0.voteAverage >= 8.0 }.count

                // Find dominant genre
                var genreCounts: [Int: Int] = [:]
                for movie in movies {
                    for gid in movie.genreIds ?? [] {
                        genreCounts[gid, default: 0] += 1
                    }
                }
                let topGenreId = genreCounts.max(by: { $0.value < $1.value })?.key
                let topGenre = topGenreId.flatMap { GenreLookup.name(for: $0) } ?? "N/A"

                collected.append(DecadeData(
                    decade: label,
                    avgRating: avgRating,
                    highRatedCount: highRatedCount,
                    topGenre: topGenre
                ))
            }

            // Sort by decade label
            return collected.sorted { $0.decade < $1.decade }
        }

        decades = result
        isLoading = false
    }
}
