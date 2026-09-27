import AppIntents
import CoreSpotlight

/// A TV series as Siri, Shortcuts and Spotlight see it.
///
/// The identifier is the TMDB id, so an entity resolved from a Spotlight
/// result, a Shortcuts parameter or a TMDB search all name the same series.
///
/// `bundledScore` comes from the analysis that ships in the app bundle and is
/// nil for anything outside it. Wherever it is shown it is said to be the
/// bundled figure: the detail screen recomputes live and may legitimately
/// arrive at a different number.
nonisolated struct SeriesEntity: AppEntity, IndexedEntity, Hashable, Sendable {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Series"
    static let defaultQuery = SeriesEntityQuery()

    let id: Int
    let name: String
    /// First-air year, when TMDB knows it.
    let year: String?
    /// The bundled analysis's Plotline Score, when the series is in the dataset.
    let bundledScore: Int?
    /// What Spotlight shows under the title. Only entities built from a
    /// dataset entry carry one, and only those are ever indexed.
    let spotlightSummary: String?

    init(id: Int, name: String, year: String?, bundledScore: Int?, spotlightSummary: String? = nil) {
        self.id = id
        self.name = name
        self.year = year
        self.bundledScore = bundledScore
        self.spotlightSummary = spotlightSummary
    }

    init(entry: DatasetEntry) {
        self.init(
            id: entry.tmdbId,
            name: entry.name,
            year: entry.firstAirDate.flatMap(Self.year(from:)),
            bundledScore: entry.analysis.score.value,
            spotlightSummary: Self.spotlightSummary(for: entry)
        )
    }

    init(media: MediaItem) {
        self.init(id: media.id, name: media.displayTitle, year: media.year, bundledScore: nil)
    }

    var displayRepresentation: DisplayRepresentation {
        let subtitle = Self.subtitle(year: year, bundledScore: bundledScore)
        return DisplayRepresentation(
            title: "\(name)",
            subtitle: subtitle.map { "\($0)" },
            image: .init(systemName: "tv")
        )
    }

    /// "2008 · Plotline Score 92", either half omitted when unknown.
    static func subtitle(year: String?, bundledScore: Int?) -> String? {
        let parts = [year, bundledScore.map { "Plotline Score \($0)" }].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// "2008 · Plotline Score 92 out of 100 · from Plotline's bundled analysis
    /// of 62 episodes with enough votes to count".
    ///
    /// Says where the number comes from because a Spotlight row cannot be
    /// recomputed live, and says what it rests on because every figure this
    /// app shows carries its evidence.
    static func spotlightSummary(for entry: DatasetEntry) -> String {
        let analysis = entry.analysis
        let episodes = VerdictCopy.ratedEpisodeCount(analysis)
        return [
            entry.firstAirDate.flatMap(year(from:)),
            "Plotline Score \(analysis.score.value) out of 100",
            "from Plotline's bundled analysis of \(VerdictCopy.episodes(episodes)) with enough votes to count",
        ]
        .compactMap { $0 }
        .joined(separator: " · ")
    }

    static func year(from date: String) -> String? {
        date.count >= 4 ? String(date.prefix(4)) : nil
    }

    // MARK: - Spotlight

    var attributeSet: CSSearchableItemAttributeSet {
        let attributes = defaultAttributeSet
        attributes.title = name
        attributes.displayName = name
        if let spotlightSummary {
            attributes.contentDescription = spotlightSummary
        }
        return attributes
    }
}

// MARK: - Query

/// Resolves series for Siri, Shortcuts and Spotlight.
///
/// Suggestions and search lead with the bundled dataset — the series Plotline
/// has already analysed — and only then fall back to TMDB's own search.
nonisolated struct SeriesEntityQuery: EntityStringQuery {
    init() {}

    func entities(for identifiers: [Int]) async throws -> [SeriesEntity] {
        var resolved: [SeriesEntity] = []
        for id in identifiers {
            if let entry = await DatasetStore.shared.entry(forTMDBId: id) {
                resolved.append(SeriesEntity(entry: entry))
            } else if let media = try? await TMDBService.shared.fetchSeriesDetails(id: id) {
                resolved.append(SeriesEntity(media: media))
            }
        }
        return resolved
    }

    /// Every analysed series, best bundled Plotline Score first. These also
    /// seed the App Shortcut phrases that name a series.
    func suggestedEntities() async throws -> [SeriesEntity] {
        let entries = await DatasetStore.shared.entries
        return SeriesEntityRanking.suggested(entries.map(SeriesEntity.init(entry:)))
    }

    func entities(matching string: String) async throws -> [SeriesEntity] {
        let query = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return try await suggestedEntities() }

        let bundled = await DatasetStore.shared.entries.map(SeriesEntity.init(entry:))
        // A failed search still leaves the bundled matches; the dataset is
        // there precisely so Plotline has answers offline.
        let searched = (try? await TMDBService.shared.searchSeries(query: query)) ?? []

        return SeriesEntityRanking.rank(
            query: query,
            bundled: bundled,
            searched: searched.map(SeriesEntity.init(media:))
        )
    }
}

// MARK: - Ranking

/// Pure ordering rules for the entity query, testable without a network.
nonisolated enum SeriesEntityRanking {
    /// Highest bundled score first; ties broken by name so the order is stable.
    static func suggested(_ bundled: [SeriesEntity]) -> [SeriesEntity] {
        bundled.sorted(by: byScoreThenName)
    }

    /// Bundled series whose name matches come first — exact, then prefix, then
    /// anywhere in the name, best score first within each. Then any TMDB result
    /// that is a bundled series under a name the text did not match, then the
    /// rest of TMDB's results in TMDB's own order. No series appears twice.
    static func rank(query: String, bundled: [SeriesEntity], searched: [SeriesEntity]) -> [SeriesEntity] {
        let needle = normalized(query)
        guard !needle.isEmpty else { return suggested(bundled) }

        let matches: [(entity: SeriesEntity, quality: Int)] = bundled.compactMap { entity in
            let name = normalized(entity.name)
            if name == needle { return (entity, 0) }
            if name.hasPrefix(needle) { return (entity, 1) }
            if name.contains(needle) { return (entity, 2) }
            return nil
        }

        let bundledMatches = matches
            .sorted { lhs, rhs in
                if lhs.quality != rhs.quality { return lhs.quality < rhs.quality }
                return byScoreThenName(lhs.entity, rhs.entity)
            }
            .map(\.entity)

        let bundledById = Dictionary(bundled.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var seen = Set(bundledMatches.map(\.id))
        var promoted: [SeriesEntity] = []
        var remaining: [SeriesEntity] = []

        for result in searched where !seen.contains(result.id) {
            seen.insert(result.id)
            if let known = bundledById[result.id] {
                promoted.append(known)
            } else {
                remaining.append(result)
            }
        }

        return bundledMatches + promoted + remaining
    }

    /// Case- and diacritic-insensitive, so "pokemon" finds "Pokémon".
    static func normalized(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func byScoreThenName(_ lhs: SeriesEntity, _ rhs: SeriesEntity) -> Bool {
        let left = lhs.bundledScore ?? -1
        let right = rhs.bundledScore ?? -1
        if left != right { return left > right }
        return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }
}
