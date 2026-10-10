import Foundation

/// `dataset-generator seed`: rewrites `SeedList.swift` from TMDB's listings.
/// Run from the repository root, like the generator itself.
public enum SeedCommand {
    static let output = URL(fileURLWithPath: "Tools/DatasetGenerator/Sources/DatasetGeneratorCore/SeedList.swift")
    static let maxPopularPages = 100
    static let maxGenrePages = 5

    public static func run() async throws {
        guard let apiKey = ProcessInfo.processInfo.environment["TMDB_API_KEY"], !apiKey.isEmpty else {
            FileHandle.standardError.write(Data("error: TMDB_API_KEY is not set\n".utf8))
            exit(1)
        }
        let tmdb = TMDBClient(apiKey: apiKey)
        let curated = Set(SeedCuration.handPickedIds).union(SeedCuration.excludedIds)
        let needed = SeedSelector.target - SeedCuration.handPickedIds.count

        do {
            var popular: [SeedCandidate] = []
            var usable = Set<Int>()
            var page = 1
            while usable.count < needed && page <= maxPopularPages {
                let result = try await tmdb.discoverSeries(page: page, genreId: nil, excludingGenres: SeedSelector.excludedGenres)
                popular += result.candidates
                for candidate in result.candidates where SeedSelector.isEligible(candidate) && !curated.contains(candidate.id) {
                    usable.insert(candidate.id)
                }
                if page >= result.totalPages { break }
                page += 1
                try await Task.sleep(nanoseconds: 120_000_000)
            }
            print("Fetched \(page) popular pages, \(usable.count) usable series")

            var byGenre: [Int: [SeedCandidate]] = [:]
            for genre in SeedSelector.flooredGenres {
                for genrePage in 1...maxGenrePages {
                    let result = try await tmdb.discoverSeries(page: genrePage, genreId: genre, excludingGenres: SeedSelector.excludedGenres)
                    byGenre[genre, default: []] += result.candidates
                    if genrePage >= result.totalPages { break }
                    try await Task.sleep(nanoseconds: 120_000_000)
                }
            }

            let selection = SeedSelector.select(
                handPicked: SeedCuration.handPickedIds,
                excluded: SeedCuration.excludedIds,
                popular: popular,
                byGenre: byGenre
            )
            try SeedSelector.render(selection.seeds).write(to: output, atomically: true, encoding: .utf8)

            print("Wrote \(selection.seeds.count) discovered seeds (+\(SeedCuration.handPickedIds.count) hand-picked) to \(output.path)")
            for (genre, count) in selection.shortGenres.sorted(by: { $0.key < $1.key }) {
                print("  genre \(genre) is below the floor: \(count) of \(SeedSelector.genreFloor)")
            }
        } catch {
            // Never `\(error)`: see `FetchFailure`.
            let message = "error: seeding failed (\(FetchFailure.detail(for: error) ?? "unknown error")). Nothing was written.\n"
            FileHandle.standardError.write(Data(message.utf8))
            exit(1)
        }
    }
}
