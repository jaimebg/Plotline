import Foundation

/// State for the Analysis tab: the selected chips, the sort, and the optional
/// natural-language request that fills them in.
///
/// Reads only the bundled dataset, so the tab works offline and with no TMDB
/// key. Entries and translator are injected for tests.
@Observable
final class AnalysisExplorerViewModel {
    enum RequestState: Equatable {
        case idle
        case interpreting
        /// The chips the request set, and any genre names that matched none.
        case interpreted(selection: Set<AnalysisTrait>, sort: AnalysisSort?, unmatchedGenres: [String])
        case failed(String)
    }

    /// Longer descriptions are cut here rather than sent to overflow the
    /// model's context. Far more than any mood needs.
    static let maximumRequestLength = 400

    let entries: [DatasetEntry]
    let genreTraits: [AnalysisTrait]
    private let translator: any AnalysisRequestTranslating

    var selection: Set<AnalysisTrait> = []
    var sort: AnalysisSort = .plotlineScore
    var request = ""
    private(set) var requestState: RequestState = .idle

    /// Both default to the real thing — the bundled dataset and Apple's
    /// on-device model — resolved here rather than as default arguments,
    /// which are evaluated outside the main actor.
    init(
        entries: [DatasetEntry]? = nil,
        translator: (any AnalysisRequestTranslating)? = nil
    ) {
        let entries = entries ?? DatasetStore.shared.entries
        self.entries = entries
        self.genreTraits = AnalysisExplorer.genreTraits(in: entries)
        self.translator = translator ?? FoundationModelsAnalysisTranslator()
    }

    // MARK: - Results

    var results: [DatasetEntry] {
        AnalysisExplorer.results(entries, selection: selection, sort: sort)
    }

    var countSummary: String {
        AnalysisExplorer.countSummary(matched: results.count, total: entries.count)
    }

    func traits(in category: TraitCategory) -> [AnalysisTrait] {
        category == .genre ? genreTraits : AnalysisTrait.traits(in: category)
    }

    /// For the empty state: each active category, and how many series come
    /// back without it.
    var matchesWithoutEachCategory: [(category: TraitCategory, count: Int)] {
        AnalysisExplorer.matchesWithout(entries, selection: selection)
    }

    // MARK: - Chips

    func isSelected(_ trait: AnalysisTrait) -> Bool {
        selection.contains(trait)
    }

    func toggle(_ trait: AnalysisTrait) {
        if selection.contains(trait) {
            selection.remove(trait)
        } else {
            selection.insert(trait)
        }
    }

    func clear(_ category: TraitCategory) {
        selection = selection.filter { $0.category != category }
    }

    func clearFilters() {
        selection = []
        if case .interpreted = requestState {
            requestState = .idle
        }
    }

    // MARK: - Natural language

    var translatorAvailability: AnalysisTranslatorAvailability {
        translator.availability
    }

    /// Sends the request to the translator and applies what comes back to the
    /// chips, replacing the current selection. The viewer sees the result as
    /// chips and can change any of it; the translator never sees the data.
    func interpretRequest() async {
        let text = String(
            request.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.maximumRequestLength)
        )
        guard !text.isEmpty, requestState != .interpreting else { return }

        requestState = .interpreting
        do {
            let interpretation = try await translator.interpret(text, genreNames: genreTraits.map(\.label))
            apply(interpretation)
        } catch is CancellationError {
            requestState = .idle
        } catch let error as AnalysisTranslationError {
            requestState = .failed(error.message)
        } catch {
            requestState = .failed(AnalysisTranslationError.failed.message)
        }
    }

    func apply(_ interpretation: AnalysisRequestInterpretation) {
        let (newSelection, unmatched) = interpretation.selection(availableGenres: genreTraits)
        // A request that maps to no chip leaves the viewer's own chips alone
        // rather than wiping them for nothing.
        guard !newSelection.isEmpty else {
            requestState = .interpreted(selection: [], sort: nil, unmatchedGenres: unmatched)
            return
        }
        selection = newSelection
        if let sort = interpretation.sort {
            self.sort = sort
        }
        requestState = .interpreted(selection: newSelection, sort: interpretation.sort, unmatchedGenres: unmatched)
    }

    /// "Interpreted as: Ending — Ends on a high · Consistency — Remarkably
    /// even or Holds a steady level · sorted by Plotline Score". Built from the
    /// chips, so it can only say what the chips say.
    static func interpretationSummary(
        selection: Set<AnalysisTrait>,
        sort: AnalysisSort?,
        unmatchedGenres: [String]
    ) -> String {
        var summary: String
        if selection.isEmpty {
            summary = "Nothing in that description matches a filter Plotline can check. Try how a series opens, ends, or holds its level."
        } else {
            var parts: [String] = TraitCategory.allCases.compactMap { category in
                let chosen = selection
                    .filter { $0.category == category }
                    .map(\.label)
                    .sorted()
                guard !chosen.isEmpty else { return nil }
                return "\(category.title) — \(chosen.joined(separator: " or "))"
            }
            if let sort {
                parts.append("sorted by \(sort.title)")
            }
            summary = "Interpreted as: " + parts.joined(separator: " · ")
        }
        if !unmatchedGenres.isEmpty {
            summary += ". Not a genre in the analysed series: \(unmatchedGenres.joined(separator: ", "))"
        }
        return summary
    }
}
