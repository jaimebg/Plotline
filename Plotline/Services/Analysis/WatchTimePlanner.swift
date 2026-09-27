import Foundation

/// How long a series takes to watch, from the runtimes TMDB lists.
nonisolated struct WatchTimePlan: Hashable, Sendable {
    struct Season: Hashable, Sendable, Identifiable {
        var id: Int { seasonNumber }

        let seasonNumber: Int
        /// Sum over this season's aired episodes with a known runtime.
        let minutes: Int
        let knownRuntimeCount: Int
        let airedCount: Int
    }

    /// Watch time on either side of the decline point. Facts only: which
    /// seasons, how long, and the averages the decline verdict itself states.
    struct Split: Hashable, Sendable {
        let seasonsBefore: [Int]
        let minutesBefore: Int
        let averageBefore: Double
        let seasonsAfter: [Int]
        let minutesAfter: Int
        let averageAfter: Double
    }

    let totalMinutes: Int
    let knownRuntimeCount: Int
    let airedCount: Int
    let seasons: [Season]
    let split: Split?

    var coverage: Double {
        airedCount > 0 ? Double(knownRuntimeCount) / Double(airedCount) : 0
    }
}

/// Totals runtimes for the aired main run. Pure: no networking, no clock unless
/// one is passed.
nonisolated enum WatchTimePlanner {
    /// Below this share of aired episodes with a known runtime, a total would
    /// understate the run by too much to be worth showing.
    static let minimumCoverage = 0.8

    /// - Parameters:
    ///   - episodes: every loaded episode; specials and unaired ones are left out.
    ///   - declinePoint: the analysis's decline, if any, to split the time at.
    /// - Returns: nil when nothing has aired, or runtime is known for fewer
    ///   than `minimumCoverage` of the aired episodes.
    static func plan(
        episodes: [EpisodeMetric],
        declinePoint: DeclinePoint?,
        asOf now: Date = Date()
    ) -> WatchTimePlan? {
        let aired = episodes.filter { $0.seasonNumber > 0 && $0.hasAired(asOf: now) }
        guard !aired.isEmpty else { return nil }

        let known = aired.filter { knownRuntime($0) != nil }
        guard !known.isEmpty,
              Double(known.count) / Double(aired.count) >= minimumCoverage else { return nil }

        let seasons = Dictionary(grouping: aired, by: \.seasonNumber)
            .sorted { $0.key < $1.key }
            .map { seasonNumber, episodes in
                WatchTimePlan.Season(
                    seasonNumber: seasonNumber,
                    minutes: minutes(in: episodes),
                    knownRuntimeCount: episodes.filter { knownRuntime($0) != nil }.count,
                    airedCount: episodes.count
                )
            }

        let split = declinePoint.flatMap { decline -> WatchTimePlan.Split? in
            let before = seasons.filter { $0.seasonNumber <= decline.afterSeason }
            let after = seasons.filter { $0.seasonNumber > decline.afterSeason }
            guard !before.isEmpty, !after.isEmpty else { return nil }
            return WatchTimePlan.Split(
                seasonsBefore: before.map(\.seasonNumber),
                minutesBefore: before.reduce(0) { $0 + $1.minutes },
                averageBefore: decline.averageBefore,
                seasonsAfter: after.map(\.seasonNumber),
                minutesAfter: after.reduce(0) { $0 + $1.minutes },
                averageAfter: decline.averageAfter
            )
        }

        return WatchTimePlan(
            totalMinutes: minutes(in: aired),
            knownRuntimeCount: known.count,
            airedCount: aired.count,
            seasons: seasons,
            split: split
        )
    }

    /// A runtime of zero is TMDB's placeholder, not a length.
    private static func knownRuntime(_ episode: EpisodeMetric) -> Int? {
        guard let runtime = episode.runtime, runtime > 0 else { return nil }
        return runtime
    }

    private static func minutes(in episodes: [EpisodeMetric]) -> Int {
        episodes.reduce(0) { $0 + (knownRuntime($1) ?? 0) }
    }

    // MARK: - Copy

    /// "45 min", "7.5 h", "62 h".
    static func duration(minutes: Int) -> String {
        if minutes < 90 { return "\(minutes) min" }
        let hours = Double(minutes) / 60
        if hours < 10 {
            let rounded = (hours * 10).rounded() / 10
            return rounded == rounded.rounded() ? "\(Int(rounded)) h" : String(format: "%.1f h", rounded)
        }
        return "\(Int(hours.rounded())) h"
    }

    /// The same duration, spelled out for VoiceOver.
    static func spokenDuration(minutes: Int) -> String {
        duration(minutes: minutes)
            .replacingOccurrences(of: " min", with: " minutes")
            .replacingOccurrences(of: " h", with: " hours")
    }

    /// "About 62 h across 5 seasons; runtime known for 60 of 62 aired episodes."
    static func summary(_ plan: WatchTimePlan) -> String {
        let seasons = plan.seasons.count == 1 ? "1 season" : "\(plan.seasons.count) seasons"
        let coverage = plan.knownRuntimeCount == plan.airedCount
            ? "runtime known for all \(plan.airedCount) aired \(plan.airedCount == 1 ? "episode" : "episodes")"
            : "runtime known for \(plan.knownRuntimeCount) of \(plan.airedCount) aired episodes"
        return "About \(duration(minutes: plan.totalMinutes)) across \(seasons); \(coverage)."
    }

    /// "Seasons 1–3: 31 h, weighted avg 8.4 · After: seasons 4–7, 28 h, weighted avg 7.1"
    ///
    /// States where the time goes on each side of the decline and nothing
    /// else — no "stop after", no "worth it".
    static func splitLine(_ split: WatchTimePlan.Split) -> String {
        String(
            format: "%@: %@, weighted avg %.1f · After: %@, %@, weighted avg %.1f",
            seasonRange(split.seasonsBefore, capitalized: true),
            duration(minutes: split.minutesBefore),
            split.averageBefore,
            seasonRange(split.seasonsAfter, capitalized: false),
            duration(minutes: split.minutesAfter),
            split.averageAfter
        )
    }

    /// "Season 4", "Seasons 1–3": the first and last aired season on one side
    /// of the boundary.
    static func seasonRange(_ seasons: [Int], capitalized: Bool) -> String {
        let word = capitalized ? "Season" : "season"
        guard let first = seasons.min(), let last = seasons.max() else { return "" }
        return first == last ? "\(word) \(first)" : "\(word)s \(first)–\(last)"
    }
}
