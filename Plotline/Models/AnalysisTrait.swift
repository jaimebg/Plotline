import Foundation

/// The groups the Analysis tab's filter chips come in.
///
/// Chips in the same category are alternatives and combine with OR; chips in
/// different categories are requirements and combine with AND.
enum TraitCategory: String, CaseIterable, Identifiable, Hashable {
    case opening
    case ending
    case consistency
    case decline
    case status
    case genre

    var id: Self { self }

    var title: String {
        switch self {
        case .opening: "Opening"
        case .ending: "Ending"
        case .consistency: "Consistency"
        case .decline: "Decline"
        case .status: "Run status"
        case .genre: "Genre"
        }
    }

    /// What a chip in this category can and cannot establish, where the label
    /// alone would leave room to read more into it.
    var footnote: String? {
        switch self {
        case .ending:
            "Only series TMDB lists as ended, with enough rated episodes in the final season, carry an ending verdict."
        case .decline:
            String(
                format: "A decline point is a drop of at least %.1f in average episode rating that begins at a season boundary and still holds in the final season. None found can also mean too few seasons, or too thin a final one, to tell.",
                SeriesAnalysisEngine.minimumDeclineDrop
            )
        case .status:
            "Listed as returning: TMDB lists the series as returning or in production, or dates an upcoming episode. Everything else is not listed as returning — ended, or status unknown."
        case .opening, .consistency, .genre:
            nil
        }
    }
}

/// One filter chip, mapped one-to-one to a predicate over the engine's output.
///
/// Every label is either the detail screen's own verdict title for the same
/// value or says strictly less. A chip claims exactly what its predicate
/// establishes, never more — see `matches(_:)` for each predicate.
enum AnalysisTrait: Hashable, Identifiable {
    /// `analysis.openingVerdict?.kind == kind`.
    case opening(OpeningVerdict.Kind)
    /// `analysis.endingVerdict?.kind == kind`. The engine only produces an
    /// ending verdict for a series known to have ended, so these never match
    /// one whose status is running or unknown.
    case ending(EndingVerdict.Kind)
    /// `analysis.consistency.rating == rating`.
    case consistency(ConsistencyRating)
    /// `analysis.declinePoint != nil`.
    case declineFound
    /// `analysis.declinePoint == nil` — no decline the engine could stand
    /// behind, which is not proof the series holds up.
    case noDeclineFound
    /// `analysis.isOngoing == true`.
    case stillRunning
    /// `analysis.isOngoing == false`, which means ended **or** unknown. It is
    /// never labelled "Ended".
    case notKnownToBeRunning
    /// The entry's TMDB `genreIds` contains this id. Metadata, not analysis.
    case genre(Int)

    var id: Self { self }

    var category: TraitCategory {
        switch self {
        case .opening: .opening
        case .ending: .ending
        case .consistency: .consistency
        case .declineFound, .noDeclineFound: .decline
        case .stillRunning, .notKnownToBeRunning: .status
        case .genre: .genre
        }
    }

    var label: String {
        switch self {
        case .opening(let kind):
            switch kind {
            case .hooksEarly: "Hooks you early"
            // The detail screen goes on to "better later on"; the kind itself
            // establishes only that the opening trails the rest.
            case .slowStart: "Slow start"
            case .even: "Even from the start"
            }
        case .ending(let kind):
            switch kind {
            case .endsStrong: "Ends on a high"
            case .endsSteady: "Holds its level to the end"
            case .fadesOut: "Fades out at the end"
            }
        case .consistency(let rating):
            switch rating {
            case .verySteady: "Remarkably even"
            case .steady: "Holds a steady level"
            case .uneven: "Uneven episode to episode"
            case .rollercoaster: "A rollercoaster"
            }
        case .declineFound:
            "Falls off and stays down"
        case .noDeclineFound:
            "No decline point found"
        case .stillRunning:
            "Listed as returning"
        case .notKnownToBeRunning:
            "Not listed as returning"
        case .genre(let id):
            GenreLookup.name(for: id) ?? "Genre \(id)"
        }
    }

    func matches(_ entry: DatasetEntry) -> Bool {
        let analysis = entry.analysis
        switch self {
        case .opening(let kind):
            return analysis.openingVerdict?.kind == kind
        case .ending(let kind):
            return analysis.endingVerdict?.kind == kind
        case .consistency(let rating):
            return analysis.consistency.rating == rating
        case .declineFound:
            return analysis.declinePoint != nil
        case .noDeclineFound:
            return analysis.declinePoint == nil
        case .stillRunning:
            return analysis.isOngoing
        case .notKnownToBeRunning:
            return !analysis.isOngoing
        case .genre(let id):
            return entry.genreIds.contains(id)
        }
    }

    /// Every chip in `category`, in display order. Genre chips depend on the
    /// data, so they come from `AnalysisExplorer.genreTraits(in:)` instead.
    static func traits(in category: TraitCategory) -> [AnalysisTrait] {
        switch category {
        case .opening:
            [.opening(.hooksEarly), .opening(.slowStart), .opening(.even)]
        case .ending:
            [.ending(.endsStrong), .ending(.endsSteady), .ending(.fadesOut)]
        case .consistency:
            [.consistency(.verySteady), .consistency(.steady), .consistency(.uneven), .consistency(.rollercoaster)]
        case .decline:
            [.declineFound, .noDeclineFound]
        case .status:
            [.stillRunning, .notKnownToBeRunning]
        case .genre:
            []
        }
    }

    /// The engine traits a series actually carries, for its row: opening,
    /// consistency, ending and decline, in that order. Status and genre are
    /// left out — they are not verdicts.
    static func verdicts(of analysis: SeriesAnalysis) -> [AnalysisTrait] {
        var traits: [AnalysisTrait] = []
        if let opening = analysis.openingVerdict {
            traits.append(.opening(opening.kind))
        }
        traits.append(.consistency(analysis.consistency.rating))
        if let ending = analysis.endingVerdict {
            traits.append(.ending(ending.kind))
        }
        if analysis.declinePoint != nil {
            traits.append(.declineFound)
        }
        return traits
    }
}

/// How the Analysis tab orders its results: the Plotline Score or one of its
/// three components, highest first.
enum AnalysisSort: String, CaseIterable, Identifiable, Hashable {
    case plotlineScore
    case level
    case consistency
    case trajectory

    var id: Self { self }

    var title: String {
        switch self {
        case .plotlineScore: "Plotline Score"
        case .level: "Level"
        case .consistency: "Consistency"
        case .trajectory: "Trajectory"
        }
    }

    func value(of score: PlotlineScore) -> Int {
        switch self {
        case .plotlineScore: score.value
        case .level: score.level
        case .consistency: score.consistency
        case .trajectory: score.trajectory
        }
    }
}

/// The Analysis tab's filtering, sorting and counting, as pure functions over
/// dataset entries so each rule can be tested without a view.
enum AnalysisExplorer {
    /// OR within a category, AND across categories. An empty selection
    /// matches everything.
    static func matches(_ entry: DatasetEntry, selection: Set<AnalysisTrait>) -> Bool {
        let byCategory = Dictionary(grouping: selection, by: \.category)
        return byCategory.values.allSatisfy { alternatives in
            alternatives.contains { $0.matches(entry) }
        }
    }

    /// The matching entries, highest first on `sort`. Ties fall back to the
    /// Plotline Score, then the name, so the order never depends on the file.
    static func results(
        _ entries: [DatasetEntry],
        selection: Set<AnalysisTrait>,
        sort: AnalysisSort
    ) -> [DatasetEntry] {
        entries
            .filter { matches($0, selection: selection) }
            .sorted { lhs, rhs in
                let left = sort.value(of: lhs.analysis.score)
                let right = sort.value(of: rhs.analysis.score)
                if left != right { return left > right }
                if lhs.analysis.score.value != rhs.analysis.score.value {
                    return lhs.analysis.score.value > rhs.analysis.score.value
                }
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
    }

    /// "12 of 123 analysed series" — both numbers counted, never written in.
    static func countSummary(matched: Int, total: Int) -> String {
        "\(matched) of \(total) analysed series"
    }

    /// How many entries each active category would let through if it were
    /// dropped, in category order. Explains an empty result: the category
    /// whose removal brings series back is the one excluding them.
    static func matchesWithout(
        _ entries: [DatasetEntry],
        selection: Set<AnalysisTrait>
    ) -> [(category: TraitCategory, count: Int)] {
        let active = Set(selection.map(\.category))
        return TraitCategory.allCases.filter(active.contains).map { category in
            let remaining = selection.filter { $0.category != category }
            return (category, entries.filter { matches($0, selection: remaining) }.count)
        }
    }

    /// One chip per genre the dataset actually carries and `GenreLookup` can
    /// name, most common first. Built from the data, so a regenerated dataset
    /// brings its own genres.
    static func genreTraits(in entries: [DatasetEntry]) -> [AnalysisTrait] {
        var counts: [Int: Int] = [:]
        for entry in entries {
            for id in entry.genreIds where GenreLookup.name(for: id) != nil {
                counts[id, default: 0] += 1
            }
        }
        return counts
            .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
            .map { .genre($0.key) }
    }

    /// The year a series first aired, from TMDB's "YYYY-MM-DD".
    static func year(of entry: DatasetEntry) -> String? {
        guard let date = entry.firstAirDate, date.count >= 4 else { return nil }
        return String(date.prefix(4))
    }
}
