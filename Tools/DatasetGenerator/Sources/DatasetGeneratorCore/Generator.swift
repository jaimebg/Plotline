import Foundation

/// The whole tool, behind one public entry point.
///
/// Everything below is `internal` — including the app's engine, which lives in
/// this same module via symlink — so the executable never touches a shared type
/// and the app never needed a single `public` keyword to make sharing work.
public enum Generator {
    public static func run() async throws {
        guard let apiKey = ProcessInfo.processInfo.environment["TMDB_API_KEY"], !apiKey.isEmpty else {
            FileHandle.standardError.write(Data("error: TMDB_API_KEY is not set\n".utf8))
            exit(1)
        }

        let tmdb = TMDBClient(apiKey: apiKey)
        let wikidata = WikidataClient()

        print("Fetching awards for \(SeedList.seriesIds.count) series…")
        let awardsById = (try? await wikidata.awards(forSeriesIds: SeedList.seriesIds)) ?? [:]
        print("  \(awardsById.count) series carry at least one award")

        var entries: [DatasetEntry] = []

        for seriesId in SeedList.seriesIds {
            do {
                let details = try await tmdb.seriesDetails(id: seriesId)
                let episodes = try await tmdb.episodes(seriesId: seriesId, seasonCount: details.seasonCount)

                guard case .analyzed(let analysis) = SeriesAnalysisEngine.analyze(
                    episodes: episodes,
                    hasEnded: details.hasEnded
                ) else {
                    print("  skipped \(details.name) (\(seriesId)): insufficient data")
                    continue
                }

                entries.append(
                    DatasetEntry(
                        tmdbId: seriesId,
                        name: details.name,
                        posterPath: details.posterPath,
                        analysis: analysis,
                        awards: awardsById[seriesId] ?? []
                    )
                )
                print("  \(details.name): score \(analysis.score.value), \(analysis.seasons.count) seasons")
            } catch {
                print("  failed \(seriesId): \(error)")
            }
        }

        let dataset = DatasetBuilder.build(entries: entries)

        let encoder = JSONEncoder()
        // Sorted keys and pretty printing keep the committed file's diffs
        // readable across regenerations.
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]

        let output = URL(fileURLWithPath: "Plotline/Resources/PlotlineDataset.json")
        try FileManager.default.createDirectory(
            at: output.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try encoder.encode(dataset).write(to: output)

        print("\nWrote \(entries.count) entries and \(dataset.lists.count) lists to \(output.path)")
    }
}
