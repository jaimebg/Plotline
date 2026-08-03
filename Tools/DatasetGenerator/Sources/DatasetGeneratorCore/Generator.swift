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
        let output = URL(fileURLWithPath: "Plotline/Resources/PlotlineDataset.json")

        print("Fetching awards for \(SeedList.seriesIds.count) series…")
        let awardsById = (try? await wikidata.awards(forSeriesIds: SeedList.seriesIds)) ?? [:]
        print("  \(awardsById.count) series carry at least one award")

        var entries: [DatasetEntry] = []
        var skipped: [SkippedSeries] = []

        for seriesId in SeedList.seriesIds {
            // Kept outside the `do` so a failure in the episodes fetch (after
            // details already succeeded) can still record the series' name.
            var details: TMDBSeriesDetails?
            do {
                let fetchedDetails = try await tmdb.seriesDetails(id: seriesId)
                details = fetchedDetails
                let episodes = try await tmdb.episodes(seriesId: seriesId, seasonCount: fetchedDetails.seasonCount)

                let result = SeriesAnalysisEngine.analyze(
                    episodes: episodes,
                    hasEnded: fetchedDetails.hasEnded
                )
                guard case .analyzed(let analysis) = result else {
                    if case .insufficientData(let reason) = result {
                        print("  skipped \(fetchedDetails.name) (\(seriesId)): insufficient data (\(reason.rawValue))")
                        skipped.append(SkippedSeries(tmdbId: seriesId, name: fetchedDetails.name, reason: reason.rawValue))
                    }
                    continue
                }

                entries.append(
                    DatasetEntry(
                        tmdbId: seriesId,
                        name: fetchedDetails.name,
                        posterPath: fetchedDetails.posterPath,
                        analysis: analysis,
                        awards: awardsById[seriesId] ?? []
                    )
                )
                print("  \(fetchedDetails.name): score \(analysis.score.value), \(analysis.seasons.count) seasons")
            } catch {
                print("  failed \(seriesId): \(error)")
                skipped.append(SkippedSeries(tmdbId: seriesId, name: details?.name, reason: "\(error)"))
            }
        }

        // A near-total failure (TMDB unreachable, for instance) still produces
        // a syntactically valid, near-empty dataset. Writing that over a good
        // file already on disk would silently erase the bundle's content, so
        // refuse instead of writing anything.
        let floor = (SeedList.seriesIds.count + 1) / 2
        guard entries.count >= floor else {
            let message = """
            error: only \(entries.count) of \(SeedList.seriesIds.count) series produced an entry, \
            below the minimum of \(floor). This looks like an outage rather than ordinary \
            insufficient-data skips. The existing dataset at \(output.path) was left untouched.

            """
            FileHandle.standardError.write(Data(message.utf8))
            exit(1)
        }

        let dataset = DatasetBuilder.build(entries: entries, skipped: skipped)

        let encoder = JSONEncoder()
        // Sorted keys and pretty printing keep the committed file's diffs
        // readable across regenerations.
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]

        try FileManager.default.createDirectory(
            at: output.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try encoder.encode(dataset).write(to: output)

        print("\nWrote \(entries.count) entries, \(skipped.count) skipped, and \(dataset.lists.count) lists to \(output.path)")
    }
}
