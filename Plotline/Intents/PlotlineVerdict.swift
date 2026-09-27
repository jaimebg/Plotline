import Foundation

// MARK: - Report

/// Where the analysis behind a verdict came from.
nonisolated enum VerdictSource: Equatable, Sendable {
    /// The analysis that ships in the app bundle.
    case bundled
    /// Computed just now from TMDB's episode ratings.
    case live
}

/// Everything Siri says about one series, before it is put into words.
nonisolated struct VerdictReport: Equatable, Sendable {
    enum Outcome: Equatable, Sendable {
        case analyzed(SeriesAnalysis, source: VerdictSource)
        /// The engine declined to judge, for this reason. Stated as-is rather
        /// than softened into a verdict.
        case refused(InsufficientDataReason, failedSeasons: [Int])
        /// The series' details could not be fetched at all.
        case couldNotLoad
        /// The fetch did not finish inside the intent's time budget.
        case timedOut
    }

    let series: SeriesEntity
    let outcome: Outcome
}

// MARK: - Loading

/// Produces a `VerdictReport` inside Siri's time budget.
///
/// A bundled series answers from the bundled analysis without touching the
/// network. Anything else is fetched — details, then every season — and run
/// through the engine exactly as the detail screen does, including its rule
/// that a season which failed to load means no verdict at all.
enum VerdictLoader {
    /// Siri and Shortcuts give an intent roughly ten seconds. Leave room to
    /// answer after giving up.
    nonisolated static let timeLimit: Duration = .seconds(8)

    static func report(for series: SeriesEntity, timeLimit: Duration = timeLimit) async -> VerdictReport {
        if let entry = DatasetStore.shared.entry(forTMDBId: series.id) {
            return VerdictReport(series: series, outcome: .analyzed(entry.analysis, source: .bundled))
        }

        let outcome = await withTimeLimit(timeLimit) {
            await liveOutcome(seriesId: series.id)
        }
        return VerdictReport(series: series, outcome: outcome ?? .timedOut)
    }

    private static func liveOutcome(seriesId: Int) async -> VerdictReport.Outcome {
        let service = TMDBService.shared
        // Without TMDB's season count there is no telling whether every season
        // was fetched, so no analysis could be called complete.
        guard let details = try? await service.fetchSeriesDetails(id: seriesId),
              let totalSeasons = details.totalSeasons else {
            return .couldNotLoad
        }

        let fetched = await service.fetchAllSeasons(seriesId: seriesId, totalSeasons: totalSeasons)
        return outcome(for: fetched, hasEnded: details.hasEnded, asOf: Date())
    }

    /// The engine's verdict on a season fetch. A fetch with any failed season
    /// is refused, never analysed from whatever happened to load.
    ///
    /// Pure, so the completeness rule can be tested without a network.
    nonisolated static func outcome(
        for fetched: SeasonFetchResult,
        hasEnded: Bool?,
        asOf now: Date
    ) -> VerdictReport.Outcome {
        let episodes = fetched.episodesBySeason.values.flatMap { $0 }
        let result = SeriesAnalysisEngine.analyze(
            episodes: episodes,
            hasEnded: hasEnded,
            unloadedSeasons: fetched.failedSeasons,
            asOf: now
        )

        switch result {
        case .analyzed(let analysis) where fetched.isComplete:
            return .analyzed(analysis, source: .live)
        case .analyzed:
            return .refused(.seasonsNotLoaded, failedSeasons: fetched.failedSeasons)
        case .insufficientData(let reason):
            return .refused(reason, failedSeasons: fetched.failedSeasons)
        }
    }

    /// Runs `operation`, or gives up after `limit` and returns nil. The
    /// operation is cancelled on giving up, which `fetchAllSeasons` honours by
    /// starting no further seasons.
    nonisolated static func withTimeLimit<T: Sendable>(
        _ limit: Duration,
        _ operation: @escaping @Sendable () async -> T
    ) async -> T? {
        await withTaskGroup(of: T?.self) { group in
            group.addTask { await operation() }
            group.addTask {
                try? await Task.sleep(for: limit)
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }
}

// MARK: - Copy

/// The words Siri says, and the snippet shows.
///
/// Numbers, not recommendations: the score and its three components, the
/// decline point with the averages either side, the ending verdict, and how
/// many episodes it all rests on. Nothing here says whether a series is worth
/// anyone's time — the engine does not establish that, so neither does Siri.
/// Verdict titles and evidence are the detail screen's own strings.
nonisolated enum VerdictCopy {
    /// Episodes with enough votes to enter the analysis — exactly the ones the
    /// score is computed from.
    static func ratedEpisodeCount(_ analysis: SeriesAnalysis) -> Int {
        analysis.seasons.reduce(0) { $0 + $1.reliableEpisodeCount }
    }

    static func episodes(_ count: Int) -> String {
        count == 1 ? "1 episode" : "\(count) episodes"
    }

    /// "Plotline Score 92 out of 100: level 95, consistency 88, trajectory 90."
    static func scoreSentence(_ score: PlotlineScore) -> String {
        "Plotline Score \(score.value) out of 100: \(componentList(score))."
    }

    /// "level 95, consistency 88, trajectory 90"
    static func componentList(_ score: PlotlineScore) -> String {
        "level \(score.level), consistency \(score.consistency), trajectory \(score.trajectory)"
    }

    /// What the analysis rests on and where it came from.
    static func basis(_ analysis: SeriesAnalysis, source: VerdictSource) -> String {
        let count = episodes(ratedEpisodeCount(analysis))
        switch source {
        case .bundled:
            return "Based on \(count) with enough votes to count, from Plotline's bundled analysis."
        case .live:
            return "Based on \(count) with enough votes to count, computed just now from TMDB's episode ratings."
        }
    }

    /// The decline and ending rows, each a title with the numbers under it.
    /// Absent verdicts produce no row: a missing decline point means the engine
    /// found none it could stand behind, not that the series holds up.
    @MainActor
    static func verdictRows(_ analysis: SeriesAnalysis) -> [(title: String, evidence: String)] {
        var rows: [(title: String, evidence: String)] = []
        if let decline = analysis.declinePoint {
            rows.append((SeriesVerdictsView.declineTitle(decline), SeriesVerdictsView.declineEvidence(decline)))
        }
        if let ending = analysis.endingVerdict {
            rows.append((SeriesVerdictsView.endingTitle(ending), SeriesVerdictsView.endingEvidence(ending)))
        }
        return rows
    }

    /// The refusal, in the detail screen's words.
    @MainActor
    static func refusal(_ reason: InsufficientDataReason, failedSeasons: [Int]) -> (title: String, explanation: String) {
        (
            SeriesAnalysisSection.title(for: reason),
            SeriesAnalysisSection.explanation(for: reason, failedSeasons: failedSeasons)
        )
    }

    static func couldNotLoad(_ name: String) -> String {
        "Plotline couldn't load the episode ratings for \(name) just now. Open Plotline to try again."
    }

    static func timedOut(_ name: String) -> String {
        "Plotline couldn't load the episode ratings for \(name) in time. Open Plotline to load it there."
    }

    /// What Siri says.
    @MainActor
    static func dialog(for report: VerdictReport) -> String {
        let name = report.series.name
        switch report.outcome {
        case .analyzed(let analysis, let source):
            var sentences = ["\(name): \(scoreSentence(analysis.score))"]
            for row in verdictRows(analysis) {
                sentences.append("\(row.title). \(row.evidence)")
            }
            sentences.append(basis(analysis, source: source))
            return sentences.joined(separator: " ")

        case .refused(let reason, let failedSeasons):
            // The title is the snippet's heading; spoken, the explanation
            // alone says it in a sentence.
            return "Plotline has no verdict on \(name). \(refusal(reason, failedSeasons: failedSeasons).explanation)"

        case .couldNotLoad:
            return couldNotLoad(name)

        case .timedOut:
            return timedOut(name)
        }
    }
}
