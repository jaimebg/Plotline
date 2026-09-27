import Foundation

// MARK: - One slot's analysis

/// The engine's analysis for one Compare slot, and where it came from.
///
/// Follows exactly the detail screen's rule (`LiveSeriesAnalysis`): the
/// bundled analysis is the instant seed, and a live recomputation replaces it
/// only when it is at least as complete. A partial fetch is never presented as
/// a full analysis — with no seed it comes back as the engine's own
/// `.seasonsNotLoaded` refusal, and with a seed the seed stays.
nonisolated struct CompareSlotAnalysis: Equatable {
    enum Source: Equatable {
        case bundled
        case live
    }

    /// Nil until something is known: no seed, and no episode has loaded.
    private(set) var result: SeriesAnalysisResult?
    private(set) var source: Source
    /// Seasons still missing after the last fetch.
    private(set) var failedSeasons: [Int] = []
    /// TMDB's series status as `SeriesStatus` maps it. `nil` is unknown, which
    /// is never shown as ended.
    private(set) var hasEnded: Bool?
    /// The last main-run season with an aired episode, known only when the
    /// result on screen was computed here from the held episodes. A bundled
    /// seed carries no episode list, so for it this stays nil.
    private(set) var finalAiredSeason: Int?

    /// The state before any fetch: the bundled analysis if this series is one
    /// the app ships, otherwise nothing.
    static func seeded(bundled: SeriesAnalysis?, hasEnded: Bool?) -> CompareSlotAnalysis {
        CompareSlotAnalysis(
            result: bundled.map(SeriesAnalysisResult.analyzed),
            source: .bundled,
            hasEnded: hasEnded
        )
    }

    /// Folds a season fetch in, returning the new state and the merged
    /// episodes the slot now holds.
    ///
    /// - Parameters:
    ///   - held: the episodes the slot already holds, so a failed retry cannot
    ///     wipe seasons an earlier attempt loaded.
    ///   - hasEnded: the latest status from TMDB's details.
    ///   - now: explicit so the result never depends on the clock.
    func folding(
        _ fetched: SeasonFetchResult,
        into held: [Int: [EpisodeMetric]],
        hasEnded: Bool?,
        asOf now: Date
    ) -> (analysis: CompareSlotAnalysis, episodes: [Int: [EpisodeMetric]]) {
        let merged = LiveSeriesAnalysis.merge(fetched, into: held)

        var next = self
        next.failedSeasons = merged.failedSeasons
        next.hasEnded = hasEnded

        if let fresh = LiveSeriesAnalysis.replacement(
            for: result,
            episodesBySeason: merged.episodesBySeason,
            failedSeasons: merged.failedSeasons,
            hasEnded: hasEnded,
            asOf: now
        ) {
            next.result = fresh
            next.source = .live
            next.finalAiredSeason = merged.episodesBySeason.values
                .flatMap { $0 }
                .filter { $0.seasonNumber > 0 && $0.hasAired(asOf: now) }
                .map(\.seasonNumber)
                .max()
        }

        return (next, merged.episodesBySeason)
    }

    /// Records a status learned without a season fetch — a details retry.
    func updatingStatus(_ hasEnded: Bool?) -> CompareSlotAnalysis {
        var next = self
        next.hasEnded = hasEnded
        return next
    }
}

// MARK: - What the section shows per slot

/// A filled slot as the Plotline Analysis section sees it.
struct CompareAnalysisEntry: Equatable {
    enum State: Equatable {
        /// Movies have no episodes, so nothing to analyse.
        case movie
        /// A retry is in flight.
        case loading
        /// No seed and no episodes loaded: nothing to analyse yet.
        case unavailable
        /// The engine declined to judge, for this reason.
        case refused(InsufficientDataReason, failedSeasons: [Int])
        case analyzed(CompareAnalysisColumn)
    }

    let slotIndex: Int
    let label: String
    let state: State
    /// The bundled analysis is on screen and this load did not replace it.
    var isBundledFallback = false
    /// A retry could change what is shown.
    var canRetry = false

    static func make(
        slotIndex: Int,
        label: String,
        isSeries: Bool,
        isRetrying: Bool,
        analysis: CompareSlotAnalysis?
    ) -> CompareAnalysisEntry {
        guard isSeries else { return CompareAnalysisEntry(slotIndex: slotIndex, label: label, state: .movie) }
        if isRetrying { return CompareAnalysisEntry(slotIndex: slotIndex, label: label, state: .loading) }

        switch analysis?.result {
        case nil:
            return CompareAnalysisEntry(slotIndex: slotIndex, label: label, state: .unavailable, canRetry: true)
        case .insufficientData(let reason)?:
            return CompareAnalysisEntry(
                slotIndex: slotIndex,
                label: label,
                state: .refused(reason, failedSeasons: analysis?.failedSeasons ?? []),
                canRetry: reason == .seasonsNotLoaded
            )
        case .analyzed(let result)?:
            let column = CompareAnalysisColumn(
                slotIndex: slotIndex,
                label: label,
                analysis: result,
                source: analysis?.source ?? .bundled,
                hasEnded: analysis?.hasEnded,
                finalAiredSeason: analysis?.finalAiredSeason
            )
            let isFallback = analysis?.source == .bundled
            return CompareAnalysisEntry(
                slotIndex: slotIndex,
                label: label,
                state: .analyzed(column),
                isBundledFallback: isFallback,
                canRetry: isFallback && !(analysis?.failedSeasons.isEmpty ?? true)
            )
        }
    }

    /// The one line that stands in for a slot's numbers. Nil for an analysed
    /// slot, which has its column instead.
    var note: (title: String, detail: String)? {
        switch state {
        case .movie:
            return (label, "Episode analysis applies to series.")
        case .loading:
            return (label, "Loading episode ratings…")
        case .unavailable:
            return (label, "Its episode ratings didn't load, so there is nothing to analyse yet.")
        case .refused(let reason, let failedSeasons):
            return (
                "\(label): \(SeriesAnalysisSection.title(for: reason))",
                SeriesAnalysisSection.explanation(for: reason, failedSeasons: failedSeasons)
            )
        case .analyzed:
            guard isBundledFallback else { return nil }
            return (
                label,
                "Shown from the analysis bundled with the app: this load didn't produce a live one at least as complete."
            )
        }
    }
}

/// An analysed series slot: one column of the side-by-side table.
struct CompareAnalysisColumn: Equatable {
    let slotIndex: Int
    let label: String
    let analysis: SeriesAnalysis
    let source: CompareSlotAnalysis.Source
    let hasEnded: Bool?
    let finalAiredSeason: Int?
}

// MARK: - The table

/// The rows of the side-by-side section, built as plain values so every string
/// and every highlight can be tested without a view.
///
/// Every value is written against what its predicate establishes. There is no
/// overall verdict and no row that names a better title: the numbers sit side
/// by side, and the only emphasis is on the higher of a number where higher is
/// unambiguous.
enum CompareAnalysisTable {
    enum RowKind: String, CaseIterable {
        case score, level, consistency, trajectory, steadiness, decline, opening, ending, evidence
    }

    struct Cell: Equatable {
        let slotIndex: Int
        let label: String
        let value: String
        let detail: String?
        /// The full reading for VoiceOver, without the title.
        let spoken: String
        let isHighlighted: Bool
    }

    struct Row: Equatable, Identifiable {
        var id: RowKind { kind }
        let kind: RowKind
        let title: String
        let caption: String?
        let cells: [Cell]

        /// The rows where higher is unambiguous: the score and its components.
        var isNumeric: Bool { CompareAnalysisTable.numericKinds.contains(kind) }

        /// The whole row as one sentence, so VoiceOver reads the comparison
        /// rather than a list of disconnected numbers.
        var accessibilityLabel: String {
            let readings = cells.map { cell in
                var reading = "\(cell.label), \(cell.spoken)"
                if cell.isHighlighted {
                    reading += cells.count == 2 ? ", the higher of the two" : ", the highest of the \(cells.count)"
                }
                return reading
            }
            return "\(title): \(readings.joined(separator: "; "))."
        }
    }

    /// Only these rows may emphasise a value. The rest are verdicts, where a
    /// "higher" reading would be a judgement the engine never made.
    static let numericKinds: Set<RowKind> = [.score, .level, .consistency, .trajectory]

    static func rows(for columns: [CompareAnalysisColumn]) -> [Row] {
        guard !columns.isEmpty else { return [] }
        return RowKind.allCases.map { row($0, columns: columns) }
    }

    /// The slots whose value is strictly the highest. Empty with fewer than
    /// two values, or when the highest is shared — a tie has no higher value.
    static func leaders(_ values: [(slotIndex: Int, value: Int)]) -> Set<Int> {
        guard values.count >= 2, let top = values.map(\.value).max() else { return [] }
        let atTop = values.filter { $0.value == top }
        return atTop.count == 1 ? [atTop[0].slotIndex] : []
    }

    // MARK: Rows

    private static func row(_ kind: RowKind, columns: [CompareAnalysisColumn]) -> Row {
        switch kind {
        case .score:
            return numericRow(kind, title: "Plotline Score", caption: "Out of 100", columns: columns) { $0.score.value }
        case .level:
            return numericRow(kind, title: "Level", caption: PlotlineScoreCard.levelCaption, columns: columns) { $0.score.level }
        case .consistency:
            return numericRow(
                kind, title: "Consistency", caption: PlotlineScoreCard.consistencyCaption, columns: columns
            ) { $0.score.consistency }
        case .trajectory:
            return numericRow(
                kind, title: "Trajectory", caption: PlotlineScoreCard.trajectoryCaption, columns: columns
            ) { $0.score.trajectory }
        case .steadiness:
            return textRow(kind, title: "Episode to Episode", caption: nil, columns: columns) { steadiness($0) }
        case .decline:
            return textRow(kind, title: "Decline", caption: nil, columns: columns) { decline($0) }
        case .opening:
            return textRow(kind, title: "Opening", caption: nil, columns: columns) { opening($0) }
        case .ending:
            return textRow(kind, title: "Ending", caption: nil, columns: columns) { ending($0) }
        case .evidence:
            return textRow(
                kind,
                title: "Evidence",
                caption: "Rated episodes are those with at least \(SeriesAnalysisEngine.minimumVotesPerEpisode) votes",
                columns: columns
            ) { evidence($0) }
        }
    }

    private static func numericRow(
        _ kind: RowKind,
        title: String,
        caption: String,
        columns: [CompareAnalysisColumn],
        value: (SeriesAnalysis) -> Int
    ) -> Row {
        let values = columns.map { (slotIndex: $0.slotIndex, value: value($0.analysis)) }
        let highlighted = leaders(values)
        let cells = zip(columns, values).map { column, entry in
            Cell(
                slotIndex: column.slotIndex,
                label: column.label,
                value: "\(entry.value)",
                detail: nil,
                spoken: "\(entry.value) out of 100",
                isHighlighted: highlighted.contains(column.slotIndex)
            )
        }
        return Row(kind: kind, title: title, caption: caption, cells: cells)
    }

    private static func textRow(
        _ kind: RowKind,
        title: String,
        caption: String?,
        columns: [CompareAnalysisColumn],
        content: @MainActor (CompareAnalysisColumn) -> (value: String, detail: String?, spoken: String)
    ) -> Row {
        let cells = columns.map { column in
            let text = content(column)
            return Cell(
                slotIndex: column.slotIndex,
                label: column.label,
                value: text.value,
                detail: text.detail,
                spoken: text.spoken,
                isHighlighted: false
            )
        }
        return Row(kind: kind, title: title, caption: caption, cells: cells)
    }

    // MARK: Copy

    static func steadiness(_ column: CompareAnalysisColumn) -> (value: String, detail: String?, spoken: String) {
        let consistency = column.analysis.consistency
        let value = SeriesVerdictsView.consistencyTitle(consistency.rating)
        let detail = String(format: "Varies by %.2f on average", consistency.standardDeviation)
        return (value, detail, "\(value). Episode ratings vary by \(String(format: "%.2f", consistency.standardDeviation)) on average")
    }

    /// Whether the engine's decline test ran for this analysis, and what it
    /// found.
    enum DeclineFinding: Equatable {
        case declines(DeclinePoint)
        /// The test ran over these boundaries and none qualified.
        case noneFound(checkedAfter: [Int], throughSeason: Int)
        /// Fewer judgeable seasons than a decline needs.
        case tooFewSeasons(judgeable: Int)
        /// The run's latest season is too thin to say whether a fall lasts.
        case latestSeasonTooThin(Int)
    }

    /// Reconstructs whether a missing decline point means "tested and none
    /// found" or "never tested". The engine returns nil for both, and only the
    /// first supports "No lasting decline found".
    ///
    /// Mirrors the engine's preconditions: only seasons with enough rated
    /// episodes take part, the final aired season must be one of them, and a
    /// boundary needs `minimumSeasonsBeforeDecline` judgeable seasons before
    /// it and `minimumSeasonsAfterDecline` after. The final aired season is
    /// known exactly for a live result; for a bundled seed the latest summarised
    /// season stands in, and the copy names that season so the claim states
    /// its own scope.
    static func declineFinding(_ column: CompareAnalysisColumn) -> DeclineFinding {
        if let decline = column.analysis.declinePoint {
            return .declines(decline)
        }

        let judgeable = column.analysis.seasons
            .filter { $0.reliableEpisodeCount >= SeriesAnalysisEngine.minimumEpisodesForSeasonVerdict }
            .map(\.seasonNumber)
            .sorted()
        let finalSeason = column.finalAiredSeason ?? column.analysis.seasons.map(\.seasonNumber).max() ?? 0

        guard judgeable.contains(finalSeason) else {
            return .latestSeasonTooThin(finalSeason)
        }

        let before = SeriesAnalysisEngine.minimumSeasonsBeforeDecline
        let after = SeriesAnalysisEngine.minimumSeasonsAfterDecline
        guard judgeable.count >= before + after else {
            return .tooFewSeasons(judgeable: judgeable.count)
        }

        let checked = Array(judgeable[(before - 1)...(judgeable.count - after - 1)])
        return .noneFound(checkedAfter: checked, throughSeason: finalSeason)
    }

    static func decline(_ column: CompareAnalysisColumn) -> (value: String, detail: String?, spoken: String) {
        let drop = String(format: "%.1f", SeriesAnalysisEngine.minimumDeclineDrop)
        switch declineFinding(column) {
        case .declines(let decline):
            let value = "Falls off after season \(decline.afterSeason)"
            let detail = String(format: "%.1f up to then, %.1f after", decline.averageBefore, decline.averageAfter)
            return (value, detail, "\(value). \(SeriesVerdictsView.declineEvidence(decline))")

        case .noneFound(let checked, let through):
            let value = "No lasting decline found"
            let seasons = checked.count == 1
                ? "season \(checked[0])"
                : "seasons \(checked.map(String.init).formatted(.list(type: .and)))"
            let detail = "None after \(seasons) fell \(drop) or more and stayed down through season \(through)"
            return (value, detail, "\(value). \(detail).")

        case .tooFewSeasons(let judgeable):
            let needed = SeriesAnalysisEngine.minimumSeasonsBeforeDecline + SeriesAnalysisEngine.minimumSeasonsAfterDecline
            let value = "Too few rated seasons to test"
            let detail = "A decline needs \(needed) seasons with \(SeriesAnalysisEngine.minimumEpisodesForSeasonVerdict)+ rated episodes; this has \(judgeable)"
            return (value, detail, "\(value). \(detail).")

        case .latestSeasonTooThin(let season):
            let value = "Latest season too thin to test"
            let detail = "Season \(season) has too few rated episodes to say whether a fall lasts"
            return (value, detail, "\(value). \(detail).")
        }
    }

    static func opening(_ column: CompareAnalysisColumn) -> (value: String, detail: String?, spoken: String) {
        // The engine judges the opening only when at least one rated episode
        // follows the opening run; nil means there are too few to compare.
        guard let opening = column.analysis.openingVerdict else {
            let value = "Too few rated episodes to judge"
            return (value, nil, value)
        }
        let value = SeriesVerdictsView.openingTitle(opening)
        let detail = String(
            format: "First %d rated %.1f, rest %.1f",
            opening.episodesConsidered.count, opening.openingAverage, opening.remainderAverage
        )
        return (value, detail, "\(value). \(SeriesVerdictsView.openingEvidence(opening))")
    }

    /// The ending verdict is shown only for a series TMDB confirms has ended,
    /// as the engine requires. Unknown status is stated as unknown — never as
    /// ended, and never as returning either.
    static func ending(_ column: CompareAnalysisColumn) -> (value: String, detail: String?, spoken: String) {
        switch column.hasEnded {
        case true?:
            guard let ending = column.analysis.endingVerdict else {
                let value = "No ending verdict"
                let detail = column.source == .live
                    ? "Too few rated seasons to judge how it finishes"
                    : "The bundled analysis has none for it"
                return (value, detail, "\(value). \(detail).")
            }
            let value = SeriesVerdictsView.endingTitle(ending)
            let detail = ending.finalSeason == ending.peakSeason
                ? String(format: "Final season %d, its highest, %.1f", ending.finalSeason, ending.finalSeasonAverage)
                : String(
                    format: "Final season %.1f, best (season %d) %.1f",
                    ending.finalSeasonAverage, ending.peakSeason, ending.peakSeasonAverage
                )
            return (value, detail, "\(value). \(SeriesVerdictsView.endingEvidence(ending))")

        case false?:
            let value = "No ending to judge"
            let detail = "TMDB lists it as returning or in production"
            return (value, detail, "\(value). \(detail).")

        case nil:
            let value = "No ending to judge"
            let detail = "TMDB's status doesn't confirm a finished run"
            return (value, detail, "\(value). \(detail).")
        }
    }

    static func evidence(_ column: CompareAnalysisColumn) -> (value: String, detail: String?, spoken: String) {
        let rated = column.analysis.seasons.reduce(0) { $0 + $1.reliableEpisodeCount }
        let seasons = column.analysis.seasons.count
        let value = "Based on \(rated) rated \(rated == 1 ? "episode" : "episodes")"
        let detail = "Across \(seasons) \(seasons == 1 ? "season" : "seasons")"
        return (value, detail, "\(value), across \(seasons) \(seasons == 1 ? "season" : "seasons")")
    }
}
