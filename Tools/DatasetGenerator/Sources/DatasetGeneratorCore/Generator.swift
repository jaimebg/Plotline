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
        let awardsById: [Int: [String]]
        do {
            awardsById = try await wikidata.awards(forSeriesIds: SeedList.seriesIds)
        } catch {
            // Swallowing this wrote a complete, plausible dataset with every
            // award stripped, reported success and exited 0 — a Wikidata
            // timeout silently shipping an award-free release. Failing loudly
            // is the only honest outcome: the same rule the entry guard below
            // already applies, now applied to this path too.
            let message = """
            error: the Wikidata awards fetch failed (\(FetchFailure.detail(for: error) ?? "unknown error")). \
            Writing now would ship a dataset with every award stripped while reporting success, \
            so nothing was written and the existing dataset at \(output.path) was left untouched. \
            Re-run when the endpoint answers.

            """
            FileHandle.standardError.write(Data(message.utf8))
            exit(1)
        }
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
                        skipped.append(
                            SkippedSeries(
                                tmdbId: seriesId,
                                name: fetchedDetails.name,
                                kind: reason.rawValue,
                                detail: nil
                            )
                        )
                    }
                    continue
                }

                entries.append(
                    DatasetEntry(
                        tmdbId: seriesId,
                        name: fetchedDetails.name,
                        mediaType: "tv",
                        overview: fetchedDetails.overview,
                        posterPath: fetchedDetails.posterPath,
                        backdropPath: fetchedDetails.backdropPath,
                        voteAverage: fetchedDetails.voteAverage,
                        genreIds: fetchedDetails.genreIds,
                        firstAirDate: fetchedDetails.firstAirDate,
                        analysis: analysis,
                        awards: awardsById[seriesId] ?? []
                    )
                )
                print("  \(fetchedDetails.name): score \(analysis.score.value), \(analysis.seasons.count) seasons")
            } catch {
                // `\(error)` is forbidden here and in the record below. A
                // URLSession error carries `NSErrorFailingURLKey`, the TMDB
                // request URL carries `api_key=…`, and this string is both
                // printed and written into a file that is committed and copied
                // into the app bundle. Only a fixed category and, at most, a
                // status code ever leave this scope.
                let detail = FetchFailure.detail(for: error)
                print("  failed \(seriesId): \(detail ?? "unknown error")")
                skipped.append(
                    SkippedSeries(
                        tmdbId: seriesId,
                        name: details?.name,
                        kind: SkippedSeries.fetchFailedKind,
                        detail: detail
                    )
                )
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

/// Reduces a thrown error to something safe to publish.
///
/// The rule this type exists to enforce: **a raw error never reaches the
/// dataset, the console, or a log.** `URLSession` puts the failing URL in its
/// errors' `userInfo` under `NSErrorFailingURLKey`, and `TMDBClient` sends the
/// API key in the query string, so `"\(error)"` can expand to a live secret —
/// which would then be committed to git and copied into the shipped app bundle.
/// The outage guard cannot catch that: one transient failure is enough, and the
/// guard only trips past 50%.
///
/// So nothing here interpolates an error, an error's `localizedDescription`, or
/// its `userInfo`. Every branch returns either a constant or an integer read out
/// of a known case, and the default is `nil` rather than a best effort.
enum FetchFailure {
    static func detail(for error: Error) -> String? {
        if let tmdb = error as? TMDBClientError {
            switch tmdb {
            case .badStatus(let code): return "HTTP \(code)"
            case .missingAPIKey: return "missingAPIKey"
            }
        }
        if let wikidata = error as? WikidataError {
            switch wikidata {
            case .badStatus(let code): return "HTTP \(code)"
            }
        }
        // `URLError.Code` is a bare integer — no URL, no user info.
        if let urlError = error as? URLError {
            return "URLError \(urlError.code.rawValue)"
        }
        if error is DecodingError {
            return "decodingFailed"
        }
        return nil
    }
}
