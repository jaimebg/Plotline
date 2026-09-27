import Foundation
import FoundationModels

// MARK: - The app's side

/// A description of what someone is in the mood for, turned into the Analysis
/// tab's own filter categories — and nothing else.
///
/// Deliberately has no free text a model could fill with a verdict, a title or
/// a description: every field is a choice from a fixed set, except genre
/// names, which only count when they name a genre the dataset carries.
struct AnalysisRequestInterpretation: Equatable {
    var openings: [OpeningVerdict.Kind] = []
    var endings: [EndingVerdict.Kind] = []
    var consistencies: [ConsistencyRating] = []
    /// `true` asks for a decline point, `false` for none found, `nil` either.
    var declineFound: Bool?
    /// `true` asks for still running, `false` for not known to be running.
    var stillRunning: Bool?
    var genreNames: [String] = []
    var sort: AnalysisSort?

    /// The chips this interpretation selects, given the genre chips on offer.
    /// Genre names are matched case-insensitively; any that match no chip are
    /// returned so the screen can say so rather than silently drop them.
    func selection(availableGenres: [AnalysisTrait]) -> (selection: Set<AnalysisTrait>, unmatchedGenres: [String]) {
        var selection = Set<AnalysisTrait>()
        selection.formUnion(openings.map(AnalysisTrait.opening))
        selection.formUnion(endings.map(AnalysisTrait.ending))
        selection.formUnion(consistencies.map(AnalysisTrait.consistency))
        if let declineFound {
            selection.insert(declineFound ? .declineFound : .noDeclineFound)
        }
        if let stillRunning {
            selection.insert(stillRunning ? .stillRunning : .notKnownToBeRunning)
        }

        var unmatched: [String] = []
        for name in genreNames {
            let wanted = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !wanted.isEmpty else { continue }
            let chips = availableGenres.filter {
                $0.label.compare(wanted, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
            }
            if chips.isEmpty {
                unmatched.append(wanted)
            } else {
                selection.formUnion(chips)
            }
        }
        return (selection, unmatched)
    }
}

/// Whether the on-device model can be asked right now, and if not, the one
/// line the screen shows instead of the field.
enum AnalysisTranslatorAvailability: Equatable {
    case available
    case unavailable(String)
}

/// Why a description could not be turned into filters. Each case carries the
/// line shown to the viewer; none of them stops the chips from working.
enum AnalysisTranslationError: Error, Equatable {
    /// A guardrail or refusal: the model would not handle this request.
    case declined
    case tooLong
    case unsupportedLanguage
    case unavailable
    case failed

    var message: String {
        switch self {
        case .declined:
            "The on-device model wouldn't interpret that request. Try describing it another way, or use the filters below."
        case .tooLong:
            "That description is too long for the on-device model. Try a shorter one."
        case .unsupportedLanguage:
            "The on-device model doesn't support this language yet. The filters below still work."
        case .unavailable:
            "Apple Intelligence isn't available right now. The filters below still work."
        case .failed:
            "Couldn't interpret that just now. The filters below still work."
        }
    }
}

/// Turns a sentence into filters. Behind a protocol so tests can supply a
/// fake and never touch the model.
protocol AnalysisRequestTranslating {
    var availability: AnalysisTranslatorAvailability { get }
    func interpret(_ request: String, genreNames: [String]) async throws -> AnalysisRequestInterpretation
}

// MARK: - Apple's on-device model

/// Asks Apple's on-device Foundation Model to fill in `GeneratedAnalysisFilter`.
///
/// The model's whole job is translation: guided generation constrains it to
/// the schema below, which has a slot for each filter category and nowhere to
/// put a verdict, a description or a series name. What it returns is applied
/// to the chips, where the viewer can see and change it. The verdicts
/// themselves still come only from the engine's bundled analysis.
struct FoundationModelsAnalysisTranslator: AnalysisRequestTranslating {
    var availability: AnalysisTranslatorAvailability {
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            guard model.supportsLocale() else {
                return .unavailable("Describing what you want isn't available in your language yet. The filters below still work.")
            }
            return .available
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible:
                return .unavailable("Describing what you want needs a device that supports Apple Intelligence. The filters below work without it.")
            case .appleIntelligenceNotEnabled:
                return .unavailable("Turn on Apple Intelligence in Settings to describe what you want in your own words. The filters below work without it.")
            case .modelNotReady:
                return .unavailable("Apple Intelligence is still getting ready on this device. The filters below work in the meantime.")
            @unknown default:
                return .unavailable("Apple Intelligence isn't available right now. The filters below still work.")
            }
        }
    }

    func interpret(_ request: String, genreNames: [String]) async throws -> AnalysisRequestInterpretation {
        guard case .available = availability else {
            throw AnalysisTranslationError.unavailable
        }

        let session = LanguageModelSession(instructions: Self.instructions(genreNames: genreNames))
        do {
            let response = try await session.respond(
                to: request,
                generating: GeneratedAnalysisFilter.self,
                options: GenerationOptions(samplingMode: .greedy)
            )
            return response.content.interpretation
        } catch let error as AnalysisTranslationError {
            throw error
        } catch {
            throw Self.classify(error)
        }
    }

    static func classify(_ error: any Error) -> AnalysisTranslationError {
        if #available(iOS 27.0, *), let error = error as? LanguageModelError {
            switch error {
            case .guardrailViolation, .refusal:
                return .declined
            case .contextSizeExceeded:
                return .tooLong
            case .unsupportedLanguageOrLocale:
                return .unsupportedLanguage
            default:
                return .failed
            }
        }
        if let error = error as? LanguageModelSession.GenerationError {
            switch error {
            case .guardrailViolation, .refusal:
                return .declined
            case .exceededContextWindowSize:
                return .tooLong
            case .unsupportedLanguageOrLocale:
                return .unsupportedLanguage
            case .assetsUnavailable:
                return .unavailable
            default:
                return .failed
            }
        }
        return .failed
    }

    static func instructions(genreNames: [String]) -> String {
        """
        You turn a person's description of the TV series they are in the mood for into filters for \
        Plotline, an app that analyses episode ratings. You never name, suggest, describe or judge any \
        series. You only fill in the filter fields, using only the options given.

        First list in mentioned only the aspects the description explicitly talks about. Fill in only \
        those aspects. Leave every other list empty and every other choice as noPreference. Never \
        guess an aspect the description does not mention.

        opening: hooksEarly means the first episodes are rated clearly higher than the rest. slowStart \
        means the first episodes are rated clearly lower than the rest, so it gets better. even means \
        the opening is rated about the same as the rest.
        ending, which only finished series have: endsStrong means the final season is at or near its \
        best season. endsSteady means the final season is a little below its best. fadesOut means the \
        final season is well below its best. A finished, completed or ended series is an ending \
        request: if it does not say how it should end, choose all three.
        consistency: verySteady means remarkably even from episode to episode. steady means it holds \
        a steady level. uneven means uneven from episode to episode. rollercoaster means wild swings \
        between strong and weak episodes. Consistent, reliable or stays steady means verySteady and steady.
        decline: declines means quality falls at some season and never recovers. noDecline means no \
        such lasting fall was found. Never gets worse means noDecline.
        status: stillRunning means still airing or returning. notKnownToBeRunning means not known to \
        be airing. A finished series is an ending request, not a status.
        genre: only these, spelled exactly: \(genreNames.joined(separator: ", ")).
        order: plotlineScore for the best overall. level for the highest-rated episodes. consistency \
        for the most even. trajectory for the one that improves most over its run.

        Example: "a finished show that ends strong and stays steady" mentions ending and consistency: \
        ending endsStrong; consistency verySteady and steady; nothing else.
        Example: "a comedy that gets better after a slow start" mentions opening and genre: opening \
        slowStart; genre Comedy; nothing else.
        Example: "something still on air that never falls off, most consistent first" mentions status, \
        decline and order: status stillRunning; decline noDecline; order consistency; nothing else.
        """
    }
}

// MARK: - The schema the model fills

/// The only shape the model may produce: first a list of the categories the
/// description actually mentions, then one slot per filter category.
///
/// Properties are generated in declaration order, so `mentioned` is settled
/// before any slot is filled — and a slot for an aspect it does not list is
/// ignored. Left to itself a small on-device model tends to fill every slot,
/// and a guessed chip is a claim the person never made.
@Generable(description: "Filters over Plotline's analysis of TV series episode ratings")
nonisolated struct GeneratedAnalysisFilter: Equatable {
    @Guide(description: "Only the aspects the description explicitly talks about.")
    var mentioned: [GeneratedAspect]

    @Guide(description: "How the series opens. Empty unless opening is mentioned.")
    var opening: [GeneratedOpening]

    @Guide(description: "How a finished series ends. Empty unless ending is mentioned.")
    var ending: [GeneratedEnding]

    @Guide(description: "How evenly it holds its quality. Empty unless consistency is mentioned.")
    var consistency: [GeneratedConsistency]

    @Guide(description: "Whether it has a lasting decline. noPreference unless decline is mentioned.")
    var decline: GeneratedDecline

    @Guide(description: "Whether it is still running. noPreference unless status is mentioned.")
    var status: GeneratedStatus

    @Guide(description: "Genres asked for, spelled exactly as listed. Empty unless genre is mentioned.")
    var genres: [String]

    @Guide(description: "How to order the results. noPreference unless order is mentioned.")
    var order: GeneratedOrder

    /// Straight into the app's own terms, keeping only the aspects the model
    /// says the description mentions. Duplicates are dropped; order is kept.
    ///
    /// One contradiction is resolved rather than passed on: an ending verdict
    /// exists only for a series known to have ended, so "still running" next
    /// to an ending request could never match anything and is dropped.
    var interpretation: AnalysisRequestInterpretation {
        let aspects = Set(mentioned)
        let endings = aspects.contains(.ending) ? ending.map(\.kind).uniqued() : []
        var stillRunning = aspects.contains(.status) ? status.stillRunning : nil
        if !endings.isEmpty, stillRunning == true {
            stillRunning = nil
        }
        return AnalysisRequestInterpretation(
            openings: aspects.contains(.opening) ? opening.map(\.kind).uniqued() : [],
            endings: endings,
            consistencies: aspects.contains(.consistency) ? consistency.map(\.rating).uniqued() : [],
            declineFound: aspects.contains(.decline) ? decline.declineFound : nil,
            stillRunning: stillRunning,
            genreNames: aspects.contains(.genre) ? genres.uniqued() : [],
            sort: aspects.contains(.order) ? order.sort : nil
        )
    }
}

@Generable
nonisolated enum GeneratedAspect: Equatable {
    case opening, ending, consistency, decline, status, genre, order
}

@Generable
nonisolated enum GeneratedOpening: Equatable {
    case hooksEarly, slowStart, even

    var kind: OpeningVerdict.Kind {
        switch self {
        case .hooksEarly: .hooksEarly
        case .slowStart: .slowStart
        case .even: .even
        }
    }
}

@Generable
nonisolated enum GeneratedEnding: Equatable {
    case endsStrong, endsSteady, fadesOut

    var kind: EndingVerdict.Kind {
        switch self {
        case .endsStrong: .endsStrong
        case .endsSteady: .endsSteady
        case .fadesOut: .fadesOut
        }
    }
}

@Generable
nonisolated enum GeneratedConsistency: Equatable {
    case verySteady, steady, uneven, rollercoaster

    var rating: ConsistencyRating {
        switch self {
        case .verySteady: .verySteady
        case .steady: .steady
        case .uneven: .uneven
        case .rollercoaster: .rollercoaster
        }
    }
}

@Generable
nonisolated enum GeneratedDecline: Equatable {
    case noPreference, declines, noDecline

    var declineFound: Bool? {
        switch self {
        case .noPreference: nil
        case .declines: true
        case .noDecline: false
        }
    }
}

@Generable
nonisolated enum GeneratedStatus: Equatable {
    case noPreference, stillRunning, notKnownToBeRunning

    var stillRunning: Bool? {
        switch self {
        case .noPreference: nil
        case .stillRunning: true
        case .notKnownToBeRunning: false
        }
    }
}

@Generable
nonisolated enum GeneratedOrder: Equatable {
    case noPreference, plotlineScore, level, consistency, trajectory

    var sort: AnalysisSort? {
        switch self {
        case .noPreference: nil
        case .plotlineScore: .plotlineScore
        case .level: .level
        case .consistency: .consistency
        case .trajectory: .trajectory
        }
    }
}

private extension Array where Element: Hashable {
    nonisolated func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
