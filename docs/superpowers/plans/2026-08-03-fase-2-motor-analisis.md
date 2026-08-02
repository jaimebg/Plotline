# Fase 2 — Motor de análisis de series

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Construir un motor puro que, a partir de los episodios de una serie, derive análisis que no existe en ninguna API: punto de declive, consistencia, episodios imprescindibles y saltables, veredictos de arranque y cierre, y un Plotline Score propio.

**Architecture:** Una función pura `[EpisodeMetric] -> SeriesAnalysisResult`, sin red, sin UI y sin estado. Todos los tipos de resultado son `Codable`, porque la Fase 3 serializa exactamente estas estructuras al dataset del bundle. El motor no importa nada del proyecto salvo `EpisodeMetric`, de modo que la Fase 3 pueda moverlo a un paquete SPM sin tocar su código.

**Tech Stack:** Swift, Swift Testing, iOS 26. Sin dependencias externas.

**Spec:** `docs/superpowers/specs/2026-08-01-app-store-4.2-design.md` §5

## Global Constraints

- Deployment target iOS 26.0. El proyecto compila en **Swift 5 language mode** (`SWIFT_VERSION = 5.0`), sin `SWIFT_STRICT_CONCURRENCY`. No intentar una migración a Swift 6.
- Tests con **Swift Testing** (`import Testing`, `@Test`, `#expect`), nunca XCTest.
- Los archivos nuevos bajo `Plotline/` y `PlotlineTests/` entran solos en el target (`PBXFileSystemSynchronizedRootGroup`). **Nunca editar `Plotline.xcodeproj/project.pbxproj` ni `Plotline/Info.plist`.**
- El motor **no puede importar SwiftUI, UIKit ni Charts**, ni referenciar `TMDBService`, `NetworkManager` o `DiskCache`. Solo `Foundation` y `EpisodeMetric`.
- Commits en Conventional Commits, en inglés.
- El proyecto debe compilar y la suite pasar al final de **cada** tarea.
- **Nunca un veredicto sobre datos insuficientes.** Es el requisito que sostiene el argumento frente a la Guideline 4.2 y no es negociable.

**Comando de tests:**

```bash
xcodebuild -project Plotline.xcodeproj -scheme Plotline \
  -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Punto de partida: 21 tests en verde (5 `DiskCache`, 9 `EpisodeMetric`, 5 `TMDBSeasonResponse`, 1 smoke).

**Trampa de entorno:** si `xcodebuild test` falla con `Application failed preflight checks` o `Busy`, es el simulador en mal estado, no el código. Recuperar con `xcrun simctl uninstall booted com.jbgsoft.Plotline`, `xcrun simctl shutdown 026554CA-9BF1-449C-BE15-C728E981B633`, `xcrun simctl boot 026554CA-9BF1-449C-BE15-C728E981B633` y repetir. **Nunca modificar código por ese error.**

## Alcance

Esta fase construye **solo el motor y sus tipos**. No toca ninguna vista. La UI que muestra el análisis y el dataset del bundle son Fases 3 y 4. Al terminar, el motor estará completo y testeado pero todavía sin consumidor en la app — eso es intencionado y esperado.

---

## Estructura de archivos

| Archivo | Responsabilidad | Acción |
|---|---|---|
| `Plotline/Models/SeriesAnalysis.swift` | Tipos de resultado. Sin lógica de cálculo. | Crear (Tarea 1) |
| `Plotline/Services/Analysis/SeriesAnalysisEngine.swift` | La función pura y sus umbrales | Crear (Tarea 2), ampliar (3-5) |
| `Plotline/Models/EpisodeMetric.swift` | Añadir `hasAired(asOf:)` | Modificar (Tarea 2) |
| `PlotlineTests/Support/EpisodeFixtures.swift` | Constructores de datos de prueba compartidos | Crear (Tarea 1) |
| `PlotlineTests/SeriesAnalysisTests.swift` | Tipos de resultado | Crear (Tarea 1) |
| `PlotlineTests/SeriesAnalysisEngineTests.swift` | El motor | Crear (Tarea 2), ampliar (3-5) |

---

## Task 1: Tipos de resultado y fixtures de prueba

Los tipos van primero porque las cuatro tareas siguientes escriben dentro de ellos. Todo es `Codable` porque la Fase 3 serializa estas estructuras tal cual.

**Files:**
- Create: `Plotline/Models/SeriesAnalysis.swift`
- Create: `PlotlineTests/Support/EpisodeFixtures.swift`
- Create: `PlotlineTests/SeriesAnalysisTests.swift`

**Interfaces:**
- Consumes: `EpisodeMetric` (existente)
- Produces: `SeriesAnalysisResult`, `SeriesAnalysis`, `SeasonSummary`, `EpisodeReference`, `DeclinePoint`, `Consistency`, `ConsistencyRating`, `OpeningVerdict`, `EndingVerdict`, `PlotlineScore`, `InsufficientDataReason`, y los helpers `EpisodeFixtures.episode(...)` / `EpisodeFixtures.season(...)`

- [ ] **Step 1: Escribir los tests que fallan**

Crear `PlotlineTests/SeriesAnalysisTests.swift`:

```swift
import Foundation
import Testing
@testable import Plotline

@Suite("SeriesAnalysis types")
struct SeriesAnalysisTests {
    @Test("an episode reference formats its short code")
    func episodeReferenceShortCode() {
        let reference = EpisodeReference(id: 1, seasonNumber: 5, episodeNumber: 14, title: "Ozymandias", rating: 10.0)
        #expect(reference.shortCode == "S5E14")
    }

    @Test("a decline point derives its drop from the two averages")
    func declinePointDrop() {
        let decline = DeclinePoint(afterSeason: 3, averageBefore: 8.8, averageAfter: 7.9, seasonsAfter: [4, 5])
        #expect(abs(decline.drop - 0.9) < 0.0001)
    }

    @Test("the analyzed result round-trips through Codable")
    func analyzedRoundTrip() throws {
        let analysis = SeriesAnalysis(
            seasons: [
                SeasonSummary(
                    seasonNumber: 1,
                    weightedAverage: 8.4,
                    standardDeviation: 0.3,
                    reliableEpisodeCount: 7,
                    bestEpisode: EpisodeReference(id: 6, seasonNumber: 1, episodeNumber: 6, title: "Crazy Handful", rating: 8.9),
                    worstEpisode: EpisodeReference(id: 4, seasonNumber: 1, episodeNumber: 4, title: "Cancer Man", rating: 7.9)
                )
            ],
            bestSeason: 1,
            worstSeason: 1,
            declinePoint: nil,
            consistency: Consistency(rating: .steady, standardDeviation: 0.3, highestRated: nil, lowestRated: nil),
            essentialEpisodes: [],
            skippableEpisodes: [],
            openingVerdict: nil,
            endingVerdict: nil,
            score: PlotlineScore(value: 82, level: 84, consistency: 70, trajectory: 50),
            isOngoing: false
        )

        let data = try JSONEncoder().encode(SeriesAnalysisResult.analyzed(analysis))
        let decoded = try JSONDecoder().decode(SeriesAnalysisResult.self, from: data)

        guard case .analyzed(let decodedAnalysis) = decoded else {
            Issue.record("expected .analyzed")
            return
        }
        #expect(decodedAnalysis == analysis)
    }

    @Test("the insufficient-data result round-trips through Codable")
    func insufficientDataRoundTrip() throws {
        let data = try JSONEncoder().encode(SeriesAnalysisResult.insufficientData(.tooFewReliableEpisodes))
        let decoded = try JSONDecoder().decode(SeriesAnalysisResult.self, from: data)
        #expect(decoded == .insufficientData(.tooFewReliableEpisodes))
    }
}
```

- [ ] **Step 2: Ejecutar para verificar que falla**

Run: `xcodebuild -project Plotline.xcodeproj -scheme Plotline -destination 'platform=iOS Simulator,name=iPhone 17' test`
Expected: FAIL de compilación, `cannot find 'EpisodeReference' in scope`.

- [ ] **Step 3: Crear los tipos de resultado**

Crear `Plotline/Models/SeriesAnalysis.swift`:

```swift
import Foundation

/// Outcome of analysing a series' episode ratings.
///
/// The engine never emits a verdict it cannot support, so callers must handle
/// `insufficientData` explicitly rather than reading a half-filled analysis.
enum SeriesAnalysisResult: Codable, Hashable {
    case analyzed(SeriesAnalysis)
    case insufficientData(InsufficientDataReason)
}

/// Why a series could not be analysed. Surfaced so the UI can say something
/// truthful instead of showing an empty panel.
enum InsufficientDataReason: String, Codable, Hashable {
    /// Nothing has aired yet.
    case noAiredEpisodes
    /// Episodes aired, but none carries enough votes to trust.
    case noReliableEpisodes
    /// Some episodes are reliable, but too small a share of what aired.
    case tooFewReliableEpisodes
}

/// Derived analysis of a series. Every verdict carries the data that supports
/// it, so the UI can show its reasoning rather than an unexplained badge.
struct SeriesAnalysis: Codable, Hashable {
    let seasons: [SeasonSummary]
    let bestSeason: Int?
    let worstSeason: Int?
    let declinePoint: DeclinePoint?
    let consistency: Consistency
    let essentialEpisodes: [EpisodeReference]
    let skippableEpisodes: [EpisodeReference]
    let openingVerdict: OpeningVerdict?
    let endingVerdict: EndingVerdict?
    let score: PlotlineScore
    /// True when the series still has unaired episodes. Suppresses the ending verdict.
    let isOngoing: Bool
}

/// Per-season roll-up.
struct SeasonSummary: Codable, Hashable, Identifiable {
    var id: Int { seasonNumber }

    let seasonNumber: Int
    let weightedAverage: Double
    let standardDeviation: Double
    let reliableEpisodeCount: Int
    let bestEpisode: EpisodeReference?
    let worstEpisode: EpisodeReference?
}

/// A pointer back to a specific episode, so a verdict can name its evidence.
struct EpisodeReference: Codable, Hashable, Identifiable {
    let id: Int
    let seasonNumber: Int
    let episodeNumber: Int
    let title: String
    let rating: Double

    var shortCode: String { "S\(seasonNumber)E\(episodeNumber)" }
}

/// The season boundary after which quality drops and stays down.
struct DeclinePoint: Codable, Hashable {
    /// Quality falls from the season after this one onward.
    let afterSeason: Int
    let averageBefore: Double
    let averageAfter: Double
    let seasonsAfter: [Int]

    var drop: Double { averageBefore - averageAfter }
}

/// How evenly a series holds its quality.
struct Consistency: Codable, Hashable {
    let rating: ConsistencyRating
    let standardDeviation: Double
    let highestRated: EpisodeReference?
    let lowestRated: EpisodeReference?
}

enum ConsistencyRating: String, Codable, Hashable {
    case verySteady
    case steady
    case uneven
    case rollercoaster
}

/// Whether the series grabs you immediately or takes a while.
struct OpeningVerdict: Codable, Hashable {
    enum Kind: String, Codable, Hashable {
        case hooksEarly
        case slowStart
        case even
    }

    let kind: Kind
    let openingAverage: Double
    let remainderAverage: Double
    let episodesConsidered: [EpisodeReference]
    /// For `slowStart`, the first season that clears the opening average by the threshold.
    let improvesAtSeason: Int?
}

/// Whether the series lands its final season or limps out.
struct EndingVerdict: Codable, Hashable {
    enum Kind: String, Codable, Hashable {
        case endsStrong
        case endsSteady
        case fadesOut
    }

    let kind: Kind
    let finalSeason: Int
    let finalSeasonAverage: Double
    let peakSeason: Int
    let peakSeasonAverage: Double
}

/// Plotline's own 0-100 score, with its three components exposed so the UI can
/// show the breakdown instead of an opaque number.
struct PlotlineScore: Codable, Hashable {
    let value: Int
    let level: Int
    let consistency: Int
    let trajectory: Int
}
```

- [ ] **Step 4: Crear los fixtures compartidos**

Crear `PlotlineTests/Support/EpisodeFixtures.swift`:

```swift
import Foundation
@testable import Plotline

/// Builders for analysis test data.
///
/// Air dates default to a fixed date well in the past so `hasAired(asOf:)` is
/// deterministic; pass a future date explicitly to model an unaired episode.
enum EpisodeFixtures {
    static let pastAirDate = "2010-01-01"
    static let futureAirDate = "2999-01-01"

    /// A reference "now" for the engine. Fixed so tests never depend on the clock.
    static let now: Date = {
        var components = DateComponents()
        components.year = 2020
        components.month = 1
        components.day = 1
        components.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: components)!
    }()

    static func episode(
        season: Int,
        number: Int,
        rating: Double,
        votes: Int = 100,
        airDate: String? = pastAirDate,
        title: String? = nil
    ) -> EpisodeMetric {
        EpisodeMetric(
            episodeNumber: number,
            seasonNumber: season,
            title: title ?? "S\(season)E\(number)",
            rating: rating,
            voteCount: votes,
            airDate: airDate
        )
    }

    /// A whole season from a list of ratings, numbered from 1.
    static func season(_ season: Int, ratings: [Double], votes: Int = 100) -> [EpisodeMetric] {
        ratings.enumerated().map { index, rating in
            episode(season: season, number: index + 1, rating: rating, votes: votes)
        }
    }
}
```

- [ ] **Step 5: Ejecutar los tests**

Run: `xcodebuild -project Plotline.xcodeproj -scheme Plotline -destination 'platform=iOS Simulator,name=iPhone 17' test`
Expected: PASS, 25 tests (los 21 previos + 4 nuevos).

- [ ] **Step 6: Commit**

```bash
git add Plotline/Models/SeriesAnalysis.swift PlotlineTests/Support/EpisodeFixtures.swift PlotlineTests/SeriesAnalysisTests.swift
git commit -m "feat: add series analysis result types"
```

---

## Task 2: Fiabilidad, estadística ponderada y resúmenes por temporada

El corazón del motor. La puerta de fiabilidad va antes que cualquier cálculo: si no se pasa, no hay análisis.

**Files:**
- Create: `Plotline/Services/Analysis/SeriesAnalysisEngine.swift`
- Create: `PlotlineTests/SeriesAnalysisEngineTests.swift`
- Modify: `Plotline/Models/EpisodeMetric.swift`

**Interfaces:**
- Consumes: los tipos de la Tarea 1, `EpisodeFixtures`
- Produces:
  - `EpisodeMetric.hasAired(asOf: Date) -> Bool`
  - `SeriesAnalysisEngine.analyze(episodes: [EpisodeMetric], asOf: Date = Date()) -> SeriesAnalysisResult`
  - Umbrales `minimumVotesPerEpisode`, `minimumReliableShare`
  - Helpers internos `weightedMean(_:)`, `weightedStandardDeviation(_:)`

**Nota sobre pureza:** `EpisodeMetric.hasAired` usa `Date()`, lo que haría el motor dependiente del reloj. Esta tarea añade `hasAired(asOf:)` y deja `hasAired` como `hasAired(asOf: Date())`, de modo que el motor reciba su "ahora" explícitamente y los tests sean deterministas.

- [ ] **Step 1: Escribir los tests que fallan**

Crear `PlotlineTests/SeriesAnalysisEngineTests.swift`:

```swift
import Foundation
import Testing
@testable import Plotline

@Suite("SeriesAnalysisEngine — reliability and season summaries")
struct SeriesAnalysisEngineReliabilityTests {
    private func analyze(_ episodes: [EpisodeMetric]) -> SeriesAnalysisResult {
        SeriesAnalysisEngine.analyze(episodes: episodes, asOf: EpisodeFixtures.now)
    }

    @Test("an empty series has no aired episodes")
    func emptySeries() {
        #expect(analyze([]) == .insufficientData(.noAiredEpisodes))
    }

    @Test("a series whose episodes have all not aired yet")
    func unairedSeries() {
        let episodes = (1...5).map {
            EpisodeFixtures.episode(season: 1, number: $0, rating: 0, votes: 0, airDate: EpisodeFixtures.futureAirDate)
        }
        #expect(analyze(episodes) == .insufficientData(.noAiredEpisodes))
    }

    @Test("a series where every episode has zero votes")
    func zeroVotesEverywhere() {
        let episodes = (1...8).map {
            EpisodeFixtures.episode(season: 1, number: $0, rating: 8.0, votes: 0)
        }
        #expect(analyze(episodes) == .insufficientData(.noReliableEpisodes))
    }

    @Test("a series where fewer than 60% of aired episodes are reliable")
    func belowReliabilityShare() {
        // 10 aired, only 5 with enough votes → 50%, under the 60% floor.
        var episodes = (1...5).map { EpisodeFixtures.episode(season: 1, number: $0, rating: 8.0, votes: 50) }
        episodes += (6...10).map { EpisodeFixtures.episode(season: 1, number: $0, rating: 8.0, votes: 3) }
        #expect(analyze(episodes) == .insufficientData(.tooFewReliableEpisodes))
    }

    @Test("episodes below the vote floor are excluded but do not block the analysis")
    func excludesLowVoteEpisodes() {
        // 10 aired, 8 reliable → 80%, above the floor.
        var episodes = (1...8).map { EpisodeFixtures.episode(season: 1, number: $0, rating: 8.0, votes: 50) }
        episodes += (9...10).map { EpisodeFixtures.episode(season: 1, number: $0, rating: 1.0, votes: 2) }

        guard case .analyzed(let analysis) = analyze(episodes) else {
            Issue.record("expected .analyzed")
            return
        }
        // The two 1.0-rated episodes are excluded, so the average stays at 8.0.
        #expect(analysis.seasons.count == 1)
        #expect(abs(analysis.seasons[0].weightedAverage - 8.0) < 0.0001)
        #expect(analysis.seasons[0].reliableEpisodeCount == 8)
    }

    @Test("averages are weighted by vote count")
    func weightsByVoteCount() {
        let episodes = [
            EpisodeFixtures.episode(season: 1, number: 1, rating: 9.0, votes: 900),
            EpisodeFixtures.episode(season: 1, number: 2, rating: 6.0, votes: 100),
            EpisodeFixtures.episode(season: 1, number: 3, rating: 9.0, votes: 900),
            EpisodeFixtures.episode(season: 1, number: 4, rating: 9.0, votes: 900)
        ]
        guard case .analyzed(let analysis) = analyze(episodes) else {
            Issue.record("expected .analyzed")
            return
        }
        // Unweighted this would be 8.25; weighted it stays near 9.
        #expect(analysis.seasons[0].weightedAverage > 8.6)
    }

    @Test("season 0 specials are excluded")
    func excludesSeasonZero() {
        var episodes = EpisodeFixtures.season(0, ratings: [3.0, 3.0, 3.0])
        episodes += EpisodeFixtures.season(1, ratings: [8.0, 8.0, 8.0, 8.0, 8.0])

        guard case .analyzed(let analysis) = analyze(episodes) else {
            Issue.record("expected .analyzed")
            return
        }
        #expect(analysis.seasons.map(\.seasonNumber) == [1])
    }

    @Test("unaired episodes are excluded and mark the series ongoing")
    func marksOngoing() {
        var episodes = EpisodeFixtures.season(1, ratings: [8.0, 8.2, 8.4, 8.1, 8.3])
        episodes.append(EpisodeFixtures.episode(season: 1, number: 6, rating: 0, votes: 0, airDate: EpisodeFixtures.futureAirDate))

        guard case .analyzed(let analysis) = analyze(episodes) else {
            Issue.record("expected .analyzed")
            return
        }
        #expect(analysis.isOngoing)
        #expect(analysis.seasons[0].reliableEpisodeCount == 5)
    }

    @Test("season summaries name their best and worst episode")
    func summarisesSeasons() {
        let episodes = [
            EpisodeFixtures.episode(season: 1, number: 1, rating: 8.0, title: "One"),
            EpisodeFixtures.episode(season: 1, number: 2, rating: 9.5, title: "Two"),
            EpisodeFixtures.episode(season: 1, number: 3, rating: 7.0, title: "Three"),
            EpisodeFixtures.episode(season: 1, number: 4, rating: 8.5, title: "Four")
        ]
        guard case .analyzed(let analysis) = analyze(episodes) else {
            Issue.record("expected .analyzed")
            return
        }
        #expect(analysis.seasons[0].bestEpisode?.title == "Two")
        #expect(analysis.seasons[0].worstEpisode?.title == "Three")
    }

    @Test("best and worst seasons are identified across a multi-season run")
    func identifiesBestAndWorstSeason() {
        var episodes = EpisodeFixtures.season(1, ratings: [8.0, 8.0, 8.0, 8.0])
        episodes += EpisodeFixtures.season(2, ratings: [9.0, 9.0, 9.0, 9.0])
        episodes += EpisodeFixtures.season(3, ratings: [7.0, 7.0, 7.0, 7.0])

        guard case .analyzed(let analysis) = analyze(episodes) else {
            Issue.record("expected .analyzed")
            return
        }
        #expect(analysis.bestSeason == 2)
        #expect(analysis.worstSeason == 3)
    }

    @Test("episode numbering gaps do not break the analysis")
    func toleratesNumberingGaps() {
        let episodes = [
            EpisodeFixtures.episode(season: 1, number: 1, rating: 8.0),
            EpisodeFixtures.episode(season: 1, number: 2, rating: 8.2),
            EpisodeFixtures.episode(season: 1, number: 7, rating: 8.4),
            EpisodeFixtures.episode(season: 1, number: 12, rating: 8.1)
        ]
        guard case .analyzed(let analysis) = analyze(episodes) else {
            Issue.record("expected .analyzed")
            return
        }
        #expect(analysis.seasons[0].reliableEpisodeCount == 4)
    }
}
```

- [ ] **Step 2: Ejecutar para verificar que falla**

Run: `xcodebuild -project Plotline.xcodeproj -scheme Plotline -destination 'platform=iOS Simulator,name=iPhone 17' test`
Expected: FAIL de compilación, `cannot find 'SeriesAnalysisEngine' in scope`.

- [ ] **Step 3: Añadir `hasAired(asOf:)` a EpisodeMetric**

En `Plotline/Models/EpisodeMetric.swift`, reemplazar la propiedad computada `hasAired` por el par método + propiedad:

```swift
    /// Whether the episode has already aired. Episodes without an air date are
    /// treated as unaired so they never reach the analysis engine.
    var hasAired: Bool {
        hasAired(asOf: Date())
    }

    /// Air check against an explicit reference date, so the analysis engine
    /// stays a pure function of its inputs and its tests never depend on the clock.
    func hasAired(asOf date: Date) -> Bool {
        guard let airDate, let aired = Self.airDateFormatter.date(from: airDate) else {
            return false
        }
        return aired <= date
    }
```

- [ ] **Step 4: Crear el motor**

Crear `Plotline/Services/Analysis/SeriesAnalysisEngine.swift`:

```swift
import Foundation

/// Derives Plotline's own analysis from a series' episode ratings.
///
/// A pure function of its inputs: no networking, no UI, no stored state, and no
/// reliance on the current clock. That keeps it directly testable and lets the
/// Phase 3 dataset generator run the very same code the app runs.
enum SeriesAnalysisEngine {

    // MARK: - Thresholds
    //
    // Initial values, to be tuned against real data. The behaviour they guard
    // is not negotiable: the engine never emits a verdict it cannot support.

    /// An episode needs at least this many votes before it counts.
    static let minimumVotesPerEpisode = 10

    /// At least this share of the aired episodes must be reliable.
    static let minimumReliableShare = 0.6

    // MARK: - Entry Point

    static func analyze(episodes: [EpisodeMetric], asOf now: Date = Date()) -> SeriesAnalysisResult {
        // Season 0 is TMDB's specials bucket. Specials are not part of the main
        // run and would distort every average, so they never enter the analysis.
        let mainRun = episodes.filter { $0.seasonNumber > 0 }

        let aired = mainRun.filter { $0.hasAired(asOf: now) }
        guard !aired.isEmpty else {
            return .insufficientData(.noAiredEpisodes)
        }

        let reliable = aired.filter(isReliable)
        guard !reliable.isEmpty else {
            return .insufficientData(.noReliableEpisodes)
        }

        let share = Double(reliable.count) / Double(aired.count)
        guard share >= minimumReliableShare else {
            return .insufficientData(.tooFewReliableEpisodes)
        }

        let isOngoing = mainRun.contains { !$0.hasAired(asOf: now) }
        let seasons = seasonSummaries(from: reliable)

        return .analyzed(
            SeriesAnalysis(
                seasons: seasons,
                bestSeason: seasons.max(by: { $0.weightedAverage < $1.weightedAverage })?.seasonNumber,
                worstSeason: seasons.min(by: { $0.weightedAverage < $1.weightedAverage })?.seasonNumber,
                declinePoint: nil,
                consistency: Consistency(rating: .steady, standardDeviation: 0, highestRated: nil, lowestRated: nil),
                essentialEpisodes: [],
                skippableEpisodes: [],
                openingVerdict: nil,
                endingVerdict: nil,
                score: PlotlineScore(value: 0, level: 0, consistency: 0, trajectory: 0),
                isOngoing: isOngoing
            )
        )
    }

    // MARK: - Reliability

    static func isReliable(_ episode: EpisodeMetric) -> Bool {
        episode.hasValidRating && episode.voteCount >= minimumVotesPerEpisode
    }

    // MARK: - Season Summaries

    static func seasonSummaries(from reliable: [EpisodeMetric]) -> [SeasonSummary] {
        Dictionary(grouping: reliable, by: \.seasonNumber)
            .sorted { $0.key < $1.key }
            .map { seasonNumber, episodes in
                SeasonSummary(
                    seasonNumber: seasonNumber,
                    weightedAverage: weightedMean(episodes),
                    standardDeviation: weightedStandardDeviation(episodes),
                    reliableEpisodeCount: episodes.count,
                    bestEpisode: episodes.max(by: { $0.rating < $1.rating }).map(reference),
                    worstEpisode: episodes.min(by: { $0.rating < $1.rating }).map(reference)
                )
            }
    }

    // MARK: - Statistics

    /// Mean rating weighted by vote count, so a 9.8 backed by 12 votes cannot
    /// outweigh an 8.9 backed by 4,000.
    static func weightedMean(_ episodes: [EpisodeMetric]) -> Double {
        let totalWeight = episodes.reduce(0) { $0 + $1.voteCount }
        guard totalWeight > 0 else { return 0 }

        let weightedSum = episodes.reduce(0.0) { $0 + $1.rating * Double($1.voteCount) }
        return weightedSum / Double(totalWeight)
    }

    static func weightedStandardDeviation(_ episodes: [EpisodeMetric]) -> Double {
        let totalWeight = episodes.reduce(0) { $0 + $1.voteCount }
        guard totalWeight > 0, episodes.count > 1 else { return 0 }

        let mean = weightedMean(episodes)
        let variance = episodes.reduce(0.0) { partial, episode in
            let delta = episode.rating - mean
            return partial + delta * delta * Double(episode.voteCount)
        } / Double(totalWeight)

        return variance.squareRoot()
    }

    // MARK: - Helpers

    static func reference(_ episode: EpisodeMetric) -> EpisodeReference {
        EpisodeReference(
            id: episode.id,
            seasonNumber: episode.seasonNumber,
            episodeNumber: episode.episodeNumber,
            title: episode.title,
            rating: episode.rating
        )
    }
}
```

- [ ] **Step 5: Ejecutar los tests**

Run: `xcodebuild -project Plotline.xcodeproj -scheme Plotline -destination 'platform=iOS Simulator,name=iPhone 17' test`
Expected: PASS, 36 tests (25 previos + 11 nuevos).

- [ ] **Step 6: Commit**

```bash
git add Plotline/Services/Analysis/SeriesAnalysisEngine.swift Plotline/Models/EpisodeMetric.swift PlotlineTests/SeriesAnalysisEngineTests.swift
git commit -m "feat: add series analysis engine with reliability gate and season summaries"
```

---

## Task 3: Punto de declive y consistencia

**Files:**
- Modify: `Plotline/Services/Analysis/SeriesAnalysisEngine.swift`
- Modify: `PlotlineTests/SeriesAnalysisEngineTests.swift` (añadir un `@Suite` nuevo al final)

**Interfaces:**
- Consumes: `weightedMean(_:)`, `weightedStandardDeviation(_:)`, `reference(_:)`, `seasonSummaries(from:)` (Tarea 2)
- Produces: `declinePoint(from:)`, `consistency(from:)`, y los umbrales `minimumDeclineDrop`, `minimumSeasonsAfterDecline`

- [ ] **Step 1: Escribir los tests que fallan**

Añadir al final de `PlotlineTests/SeriesAnalysisEngineTests.swift`:

```swift
@Suite("SeriesAnalysisEngine — decline and consistency")
struct SeriesAnalysisEngineDeclineTests {
    private func analysis(_ episodes: [EpisodeMetric]) -> SeriesAnalysis? {
        guard case .analyzed(let value) = SeriesAnalysisEngine.analyze(episodes: episodes, asOf: EpisodeFixtures.now) else {
            return nil
        }
        return value
    }

    @Test("a series that falls off after season 3 reports that boundary")
    func detectsDecline() {
        var episodes = EpisodeFixtures.season(1, ratings: [8.8, 8.9, 8.7, 8.8])
        episodes += EpisodeFixtures.season(2, ratings: [8.9, 9.0, 8.8, 8.9])
        episodes += EpisodeFixtures.season(3, ratings: [8.7, 8.8, 8.6, 8.7])
        episodes += EpisodeFixtures.season(4, ratings: [7.4, 7.3, 7.5, 7.2])
        episodes += EpisodeFixtures.season(5, ratings: [7.1, 7.0, 7.2, 7.1])

        guard let result = analysis(episodes) else {
            Issue.record("expected .analyzed")
            return
        }
        #expect(result.declinePoint?.afterSeason == 3)
        #expect(result.declinePoint?.seasonsAfter == [4, 5])
        #expect((result.declinePoint?.drop ?? 0) > 0.5)
    }

    @Test("a consistently good series reports no decline")
    func noDeclineWhenSteady() {
        var episodes = EpisodeFixtures.season(1, ratings: [8.5, 8.6, 8.4, 8.5])
        episodes += EpisodeFixtures.season(2, ratings: [8.6, 8.5, 8.7, 8.5])
        episodes += EpisodeFixtures.season(3, ratings: [8.5, 8.6, 8.5, 8.6])
        episodes += EpisodeFixtures.season(4, ratings: [8.6, 8.5, 8.6, 8.5])

        #expect(analysis(episodes)?.declinePoint == nil)
    }

    @Test("a dip in the final season alone is not a decline point")
    func requiresTwoSeasonsAfter() {
        var episodes = EpisodeFixtures.season(1, ratings: [8.8, 8.9, 8.7, 8.8])
        episodes += EpisodeFixtures.season(2, ratings: [8.9, 8.8, 8.9, 8.8])
        episodes += EpisodeFixtures.season(3, ratings: [8.8, 8.9, 8.8, 8.7])
        episodes += EpisodeFixtures.season(4, ratings: [6.5, 6.4, 6.6, 6.5])

        // Only one season sits after the boundary, so the rule does not fire.
        #expect(analysis(episodes)?.declinePoint == nil)
    }

    @Test("a drop smaller than the threshold is not a decline point")
    func requiresMinimumDrop() {
        var episodes = EpisodeFixtures.season(1, ratings: [8.5, 8.5, 8.5, 8.5])
        episodes += EpisodeFixtures.season(2, ratings: [8.5, 8.5, 8.5, 8.5])
        episodes += EpisodeFixtures.season(3, ratings: [8.3, 8.3, 8.3, 8.3])
        episodes += EpisodeFixtures.season(4, ratings: [8.2, 8.2, 8.2, 8.2])

        #expect(analysis(episodes)?.declinePoint == nil)
    }

    @Test("a single-season series has no decline point")
    func singleSeasonHasNoDecline() {
        let episodes = EpisodeFixtures.season(1, ratings: [8.0, 8.5, 7.5, 8.2, 8.1])
        #expect(analysis(episodes)?.declinePoint == nil)
    }

    @Test("a flat series is rated very steady")
    func ratesVerySteady() {
        let episodes = EpisodeFixtures.season(1, ratings: [8.4, 8.5, 8.4, 8.5, 8.4, 8.5])
        #expect(analysis(episodes)?.consistency.rating == .verySteady)
    }

    @Test("a wildly swinging series is rated a rollercoaster")
    func ratesRollercoaster() {
        let episodes = EpisodeFixtures.season(1, ratings: [9.8, 5.5, 9.5, 5.2, 9.7, 5.0, 9.6, 5.4])
        #expect(analysis(episodes)?.consistency.rating == .rollercoaster)
    }

    @Test("consistency names the highest and lowest rated episodes")
    func consistencyCitesEvidence() {
        let episodes = [
            EpisodeFixtures.episode(season: 1, number: 1, rating: 8.0, title: "One"),
            EpisodeFixtures.episode(season: 1, number: 2, rating: 9.9, title: "Peak"),
            EpisodeFixtures.episode(season: 1, number: 3, rating: 5.1, title: "Trough"),
            EpisodeFixtures.episode(season: 1, number: 4, rating: 8.2, title: "Four")
        ]
        let consistency = analysis(episodes)?.consistency
        #expect(consistency?.highestRated?.title == "Peak")
        #expect(consistency?.lowestRated?.title == "Trough")
    }
}
```

- [ ] **Step 2: Ejecutar para verificar que falla**

Run: `xcodebuild -project Plotline.xcodeproj -scheme Plotline -destination 'platform=iOS Simulator,name=iPhone 17' test`
Expected: FAIL — `declinePoint` es siempre `nil` y `consistency.rating` siempre `.steady`.

- [ ] **Step 3: Implementar declive y consistencia**

En `Plotline/Services/Analysis/SeriesAnalysisEngine.swift`, añadir los dos umbrales bajo los existentes:

```swift
    /// A decline must cost at least this much to count as one.
    static let minimumDeclineDrop = 0.5

    /// And at least this many seasons must follow it, so a single weak final
    /// season reads as a weak ending rather than a decline.
    static let minimumSeasonsAfterDecline = 2
```

Añadir las dos funciones antes de `// MARK: - Statistics`:

```swift
    // MARK: - Decline

    /// The season boundary that costs the series the most, provided the drop is
    /// big enough and enough seasons follow it to call the fall sustained.
    ///
    /// Deliberately simple: the result has to be explainable to a user in one
    /// sentence ("it falls off after season 5"), which rules out fitting curves.
    static func declinePoint(from reliable: [EpisodeMetric]) -> DeclinePoint? {
        let seasons = Set(reliable.map(\.seasonNumber)).sorted()
        guard seasons.count > minimumSeasonsAfterDecline else { return nil }

        var best: DeclinePoint?

        for boundary in seasons.dropLast(minimumSeasonsAfterDecline) {
            let before = reliable.filter { $0.seasonNumber <= boundary }
            let after = reliable.filter { $0.seasonNumber > boundary }
            guard !before.isEmpty, !after.isEmpty else { continue }

            let averageBefore = weightedMean(before)
            let averageAfter = weightedMean(after)
            guard averageBefore - averageAfter >= minimumDeclineDrop else { continue }

            // The fall has to START here. Without this, one catastrophic final
            // season drags the "after" average down at every earlier boundary
            // too, and the engine would report a decline three seasons before
            // anything actually went wrong.
            let nextSeason = reliable.filter { $0.seasonNumber == boundary + 1 }
            guard !nextSeason.isEmpty,
                  averageBefore - weightedMean(nextSeason) >= minimumDeclineDrop else { continue }

            let candidate = DeclinePoint(
                afterSeason: boundary,
                averageBefore: averageBefore,
                averageAfter: averageAfter,
                seasonsAfter: seasons.filter { $0 > boundary }
            )

            if candidate.drop > (best?.drop ?? 0) {
                best = candidate
            }
        }

        return best
    }

    // MARK: - Consistency

    static func consistency(from reliable: [EpisodeMetric]) -> Consistency {
        let deviation = weightedStandardDeviation(reliable)

        let rating: ConsistencyRating
        switch deviation {
        case ..<0.35: rating = .verySteady
        case ..<0.60: rating = .steady
        case ..<0.90: rating = .uneven
        default: rating = .rollercoaster
        }

        return Consistency(
            rating: rating,
            standardDeviation: deviation,
            highestRated: reliable.max(by: { $0.rating < $1.rating }).map(reference),
            lowestRated: reliable.min(by: { $0.rating < $1.rating }).map(reference)
        )
    }
```

Y sustituir las dos líneas correspondientes dentro de `analyze`:

```swift
                declinePoint: declinePoint(from: reliable),
```

```swift
                consistency: consistency(from: reliable),
```

- [ ] **Step 4: Ejecutar los tests**

Run: `xcodebuild -project Plotline.xcodeproj -scheme Plotline -destination 'platform=iOS Simulator,name=iPhone 17' test`
Expected: PASS, 44 tests (36 previos + 8 nuevos).

- [ ] **Step 5: Commit**

```bash
git add Plotline/Services/Analysis/SeriesAnalysisEngine.swift PlotlineTests/SeriesAnalysisEngineTests.swift
git commit -m "feat: detect decline point and rate consistency"
```

---

## Task 4: Episodios imprescindibles y saltables

**Files:**
- Modify: `Plotline/Services/Analysis/SeriesAnalysisEngine.swift`
- Modify: `PlotlineTests/SeriesAnalysisEngineTests.swift` (añadir un `@Suite` nuevo al final)

**Interfaces:**
- Consumes: `weightedMean(_:)`, `weightedStandardDeviation(_:)`, `reference(_:)` (Tarea 2)
- Produces: `standoutEpisodes(from:)` devolviendo `(essential: [EpisodeReference], skippable: [EpisodeReference])`, y los umbrales `standoutZScoreThreshold`, `minimumEpisodesForZScore`

- [ ] **Step 1: Escribir los tests que fallan**

Añadir al final de `PlotlineTests/SeriesAnalysisEngineTests.swift`:

```swift
@Suite("SeriesAnalysisEngine — standout episodes")
struct SeriesAnalysisEngineStandoutTests {
    private func analysis(_ episodes: [EpisodeMetric]) -> SeriesAnalysis? {
        guard case .analyzed(let value) = SeriesAnalysisEngine.analyze(episodes: episodes, asOf: EpisodeFixtures.now) else {
            return nil
        }
        return value
    }

    @Test("an episode far above its season is essential")
    func findsEssentialEpisode() {
        let episodes = [
            EpisodeFixtures.episode(season: 1, number: 1, rating: 8.0),
            EpisodeFixtures.episode(season: 1, number: 2, rating: 8.1),
            EpisodeFixtures.episode(season: 1, number: 3, rating: 7.9),
            EpisodeFixtures.episode(season: 1, number: 4, rating: 8.0),
            EpisodeFixtures.episode(season: 1, number: 5, rating: 9.9, title: "Ozymandias"),
            EpisodeFixtures.episode(season: 1, number: 6, rating: 8.1)
        ]
        #expect(analysis(episodes)?.essentialEpisodes.map(\.title) == ["Ozymandias"])
    }

    @Test("an episode far below its season is skippable")
    func findsSkippableEpisode() {
        let episodes = [
            EpisodeFixtures.episode(season: 1, number: 1, rating: 8.0),
            EpisodeFixtures.episode(season: 1, number: 2, rating: 8.1),
            EpisodeFixtures.episode(season: 1, number: 3, rating: 7.9),
            EpisodeFixtures.episode(season: 1, number: 4, rating: 8.0),
            EpisodeFixtures.episode(season: 1, number: 5, rating: 5.5, title: "Filler"),
            EpisodeFixtures.episode(season: 1, number: 6, rating: 8.1)
        ]
        #expect(analysis(episodes)?.skippableEpisodes.map(\.title) == ["Filler"])
    }

    @Test("a flat season has neither essential nor skippable episodes")
    func flatSeasonHasNoStandouts() {
        let episodes = EpisodeFixtures.season(1, ratings: [8.0, 8.0, 8.1, 8.0, 7.9, 8.0])
        let result = analysis(episodes)
        #expect(result?.essentialEpisodes.isEmpty == true)
        #expect(result?.skippableEpisodes.isEmpty == true)
    }

    @Test("standouts are judged within their own season, not across the series")
    func judgesWithinSeason() {
        // Season 2 is uniformly weaker, but its own peak still stands out locally.
        var episodes = EpisodeFixtures.season(1, ratings: [9.0, 9.1, 8.9, 9.0, 9.1, 9.0])
        episodes += [
            EpisodeFixtures.episode(season: 2, number: 1, rating: 6.0),
            EpisodeFixtures.episode(season: 2, number: 2, rating: 6.1),
            EpisodeFixtures.episode(season: 2, number: 3, rating: 5.9),
            EpisodeFixtures.episode(season: 2, number: 4, rating: 6.0),
            EpisodeFixtures.episode(season: 2, number: 5, rating: 7.6, title: "Local Peak"),
            EpisodeFixtures.episode(season: 2, number: 6, rating: 6.1)
        ]
        let essential = analysis(episodes)?.essentialEpisodes.map(\.title) ?? []
        #expect(essential.contains("Local Peak"))
    }

    @Test("a season too short for a meaningful z-score yields no standouts")
    func skipsShortSeasons() {
        var episodes = EpisodeFixtures.season(1, ratings: [8.0, 8.0, 8.0, 8.0, 8.0, 8.0])
        episodes += [
            EpisodeFixtures.episode(season: 2, number: 1, rating: 9.9),
            EpisodeFixtures.episode(season: 2, number: 2, rating: 5.0)
        ]
        let standouts = (analysis(episodes)?.essentialEpisodes ?? []) + (analysis(episodes)?.skippableEpisodes ?? [])
        #expect(standouts.allSatisfy { $0.seasonNumber != 2 })
    }

    @Test("standouts come back in season and episode order")
    func ordersStandouts() {
        var episodes = EpisodeFixtures.season(1, ratings: [8.0, 8.0, 8.0, 8.0, 8.0])
        episodes.append(EpisodeFixtures.episode(season: 1, number: 6, rating: 9.8, title: "S1 peak"))
        episodes += EpisodeFixtures.season(2, ratings: [8.0, 8.0, 8.0, 8.0, 8.0])
        episodes.append(EpisodeFixtures.episode(season: 2, number: 6, rating: 9.8, title: "S2 peak"))

        #expect(analysis(episodes)?.essentialEpisodes.map(\.title) == ["S1 peak", "S2 peak"])
    }
}
```

- [ ] **Step 2: Ejecutar para verificar que falla**

Run: `xcodebuild -project Plotline.xcodeproj -scheme Plotline -destination 'platform=iOS Simulator,name=iPhone 17' test`
Expected: FAIL — `essentialEpisodes` y `skippableEpisodes` están siempre vacíos.

- [ ] **Step 3: Implementar los standouts**

Añadir los umbrales bajo los existentes:

```swift
    /// How far from its season's mean an episode must sit to stand out.
    static let standoutZScoreThreshold = 1.5

    /// Below this many reliable episodes a season's spread is too noisy to
    /// draw a z-score from, so it contributes no standouts.
    static let minimumEpisodesForZScore = 4

    /// An episode must also sit this far from its season's mean in absolute
    /// terms. In a very flat season the standard deviation collapses, so a
    /// 0.1-point wobble clears the z-score threshold while meaning nothing.
    static let minimumStandoutDelta = 0.4
```

Añadir la función antes de `// MARK: - Statistics`:

```swift
    // MARK: - Standout Episodes

    /// Episodes that sit far from their own season's mean.
    ///
    /// Judged per season rather than across the series, so a strong episode of a
    /// weak season still registers — which is what a viewer deciding whether to
    /// skip ahead actually wants to know.
    static func standoutEpisodes(
        from reliable: [EpisodeMetric]
    ) -> (essential: [EpisodeReference], skippable: [EpisodeReference]) {
        var essential: [EpisodeReference] = []
        var skippable: [EpisodeReference] = []

        let bySeason = Dictionary(grouping: reliable, by: \.seasonNumber)

        for seasonNumber in bySeason.keys.sorted() {
            let episodes = bySeason[seasonNumber] ?? []
            guard episodes.count >= minimumEpisodesForZScore else { continue }

            let mean = weightedMean(episodes)
            let deviation = weightedStandardDeviation(episodes)
            guard deviation > 0 else { continue }

            for episode in episodes.sorted(by: { $0.episodeNumber < $1.episodeNumber }) {
                let delta = episode.rating - mean
                guard abs(delta) >= minimumStandoutDelta else { continue }

                let zScore = delta / deviation

                if zScore >= standoutZScoreThreshold {
                    essential.append(reference(episode))
                } else if zScore <= -standoutZScoreThreshold {
                    skippable.append(reference(episode))
                }
            }
        }

        return (essential, skippable)
    }
```

Y en `analyze`, sustituir las dos líneas vacías. Calcular una sola vez antes de construir el resultado:

```swift
        let standouts = standoutEpisodes(from: reliable)
```

```swift
                essentialEpisodes: standouts.essential,
                skippableEpisodes: standouts.skippable,
```

- [ ] **Step 4: Ejecutar los tests**

Run: `xcodebuild -project Plotline.xcodeproj -scheme Plotline -destination 'platform=iOS Simulator,name=iPhone 17' test`
Expected: PASS, 50 tests (44 previos + 6 nuevos).

- [ ] **Step 5: Commit**

```bash
git add Plotline/Services/Analysis/SeriesAnalysisEngine.swift PlotlineTests/SeriesAnalysisEngineTests.swift
git commit -m "feat: identify essential and skippable episodes by season z-score"
```

---

## Task 5: Veredictos de arranque y cierre, y Plotline Score

Cierra el motor. Al terminar esta tarea `analyze` no devuelve ningún campo por rellenar.

**Files:**
- Modify: `Plotline/Services/Analysis/SeriesAnalysisEngine.swift`
- Modify: `PlotlineTests/SeriesAnalysisEngineTests.swift` (añadir un `@Suite` nuevo al final)

**Interfaces:**
- Consumes: todo lo anterior
- Produces: `openingVerdict(from:)`, `endingVerdict(from:isOngoing:)`, `plotlineScore(from:)`, y los umbrales `openingEpisodeCount`, `openingVerdictThreshold`, `endingStrongTolerance`, `endingFadeThreshold`

- [ ] **Step 1: Escribir los tests que fallan**

Añadir al final de `PlotlineTests/SeriesAnalysisEngineTests.swift`:

```swift
@Suite("SeriesAnalysisEngine — verdicts and score")
struct SeriesAnalysisEngineVerdictTests {
    private func analysis(_ episodes: [EpisodeMetric]) -> SeriesAnalysis? {
        guard case .analyzed(let value) = SeriesAnalysisEngine.analyze(episodes: episodes, asOf: EpisodeFixtures.now) else {
            return nil
        }
        return value
    }

    @Test("a series that starts strong and settles down hooks early")
    func detectsStrongOpening() {
        var episodes = EpisodeFixtures.season(1, ratings: [9.2, 9.3, 9.1, 9.2, 9.3, 9.1])
        episodes += EpisodeFixtures.season(2, ratings: [8.0, 8.1, 7.9, 8.0, 8.1, 8.0])

        #expect(analysis(episodes)?.openingVerdict?.kind == .hooksEarly)
    }

    @Test("a series that starts weak and improves reports a slow start")
    func detectsSlowStart() {
        var episodes = EpisodeFixtures.season(1, ratings: [7.0, 7.1, 6.9, 7.0, 7.1, 7.0])
        episodes += EpisodeFixtures.season(2, ratings: [8.8, 8.9, 8.7, 8.8, 8.9, 8.8])
        episodes += EpisodeFixtures.season(3, ratings: [8.9, 9.0, 8.8, 8.9, 9.0, 8.9])

        let verdict = analysis(episodes)?.openingVerdict
        #expect(verdict?.kind == .slowStart)
        #expect(verdict?.improvesAtSeason == 2)
    }

    @Test("a level series reports an even opening")
    func detectsEvenOpening() {
        var episodes = EpisodeFixtures.season(1, ratings: [8.4, 8.5, 8.4, 8.5, 8.4, 8.5])
        episodes += EpisodeFixtures.season(2, ratings: [8.5, 8.4, 8.5, 8.4, 8.5, 8.4])

        #expect(analysis(episodes)?.openingVerdict?.kind == .even)
    }

    @Test("the opening verdict names the episodes it looked at")
    func openingCitesEvidence() {
        var episodes = EpisodeFixtures.season(1, ratings: [9.2, 9.3, 9.1, 9.2, 9.3, 9.1])
        episodes += EpisodeFixtures.season(2, ratings: [8.0, 8.1, 7.9, 8.0, 8.1, 8.0])

        #expect(analysis(episodes)?.openingVerdict?.episodesConsidered.count == 6)
    }

    @Test("a series peaking in its final season ends strong")
    func detectsStrongEnding() {
        var episodes = EpisodeFixtures.season(1, ratings: [8.0, 8.1, 7.9, 8.0])
        episodes += EpisodeFixtures.season(2, ratings: [8.4, 8.5, 8.3, 8.4])
        episodes += EpisodeFixtures.season(3, ratings: [9.2, 9.3, 9.1, 9.2])

        let verdict = analysis(episodes)?.endingVerdict
        #expect(verdict?.kind == .endsStrong)
        #expect(verdict?.finalSeason == 3)
    }

    @Test("a series collapsing in its final season fades out")
    func detectsFadeOut() {
        var episodes = EpisodeFixtures.season(1, ratings: [9.0, 9.1, 8.9, 9.0])
        episodes += EpisodeFixtures.season(2, ratings: [9.1, 9.2, 9.0, 9.1])
        episodes += EpisodeFixtures.season(3, ratings: [6.5, 6.4, 6.6, 6.5])

        let verdict = analysis(episodes)?.endingVerdict
        #expect(verdict?.kind == .fadesOut)
        #expect(verdict?.peakSeason == 2)
    }

    @Test("an ongoing series gets no ending verdict")
    func suppressesEndingWhileOngoing() {
        var episodes = EpisodeFixtures.season(1, ratings: [8.0, 8.1, 7.9, 8.0])
        episodes += EpisodeFixtures.season(2, ratings: [8.4, 8.5, 8.3, 8.4])
        episodes.append(
            EpisodeFixtures.episode(season: 3, number: 1, rating: 0, votes: 0, airDate: EpisodeFixtures.futureAirDate)
        )

        #expect(analysis(episodes)?.endingVerdict == nil)
    }

    @Test("a single-season series gets no ending verdict")
    func suppressesEndingForSingleSeason() {
        let episodes = EpisodeFixtures.season(1, ratings: [8.0, 8.1, 7.9, 8.0, 8.2, 8.1])
        #expect(analysis(episodes)?.endingVerdict == nil)
    }

    @Test("a great, steady, rising series scores higher than a mediocre erratic one")
    func scoresRelatively() {
        var great = EpisodeFixtures.season(1, ratings: [8.8, 8.9, 8.7, 8.8, 8.9, 8.8])
        great += EpisodeFixtures.season(2, ratings: [9.2, 9.3, 9.1, 9.2, 9.3, 9.2])

        var poor = EpisodeFixtures.season(1, ratings: [7.5, 5.0, 7.8, 4.9, 7.6, 5.1])
        poor += EpisodeFixtures.season(2, ratings: [6.0, 4.5, 6.2, 4.4, 6.1, 4.6])

        let greatScore = analysis(great)?.score.value ?? 0
        let poorScore = analysis(poor)?.score.value ?? 0
        #expect(greatScore > poorScore)
    }

    @Test("the score and its three components stay within 0...100")
    func scoreStaysInRange() {
        var episodes = EpisodeFixtures.season(1, ratings: [10.0, 10.0, 10.0, 10.0, 10.0, 10.0])
        episodes += EpisodeFixtures.season(2, ratings: [1.0, 1.0, 1.0, 1.0, 1.0, 1.0])
        episodes += EpisodeFixtures.season(3, ratings: [10.0, 1.0, 10.0, 1.0, 10.0, 1.0])

        guard let score = analysis(episodes)?.score else {
            Issue.record("expected .analyzed")
            return
        }
        #expect((0...100).contains(score.value))
        #expect((0...100).contains(score.level))
        #expect((0...100).contains(score.consistency))
        #expect((0...100).contains(score.trajectory))
    }
}
```

- [ ] **Step 2: Ejecutar para verificar que falla**

Run: `xcodebuild -project Plotline.xcodeproj -scheme Plotline -destination 'platform=iOS Simulator,name=iPhone 17' test`
Expected: FAIL — los veredictos son `nil` y el score es todo ceros.

- [ ] **Step 3: Implementar veredictos y score**

Añadir los umbrales bajo los existentes:

```swift
    /// How many opening episodes the opening verdict weighs.
    static let openingEpisodeCount = 6

    /// How far the opening must sit from the rest to be worth calling out.
    static let openingVerdictThreshold = 0.4

    /// A final season within this much of the peak still counts as ending strong.
    static let endingStrongTolerance = 0.2

    /// A final season this far below the peak counts as fading out.
    static let endingFadeThreshold = 0.5
```

Añadir las tres funciones antes de `// MARK: - Statistics`:

```swift
    // MARK: - Opening

    /// Compares the opening run against everything after it, which is the
    /// question a viewer actually asks: is it worth pushing through the start?
    static func openingVerdict(from reliable: [EpisodeMetric]) -> OpeningVerdict? {
        let ordered = reliable.sorted {
            ($0.seasonNumber, $0.episodeNumber) < ($1.seasonNumber, $1.episodeNumber)
        }
        guard ordered.count > openingEpisodeCount else { return nil }

        let opening = Array(ordered.prefix(openingEpisodeCount))
        let remainder = Array(ordered.dropFirst(openingEpisodeCount))
        guard !remainder.isEmpty else { return nil }

        let openingAverage = weightedMean(opening)
        let remainderAverage = weightedMean(remainder)
        let delta = openingAverage - remainderAverage

        let kind: OpeningVerdict.Kind
        var improvesAtSeason: Int?

        if delta >= openingVerdictThreshold {
            kind = .hooksEarly
        } else if -delta >= openingVerdictThreshold {
            kind = .slowStart
            improvesAtSeason = firstSeasonClearing(openingAverage, in: remainder)
        } else {
            kind = .even
        }

        return OpeningVerdict(
            kind: kind,
            openingAverage: openingAverage,
            remainderAverage: remainderAverage,
            episodesConsidered: opening.map(reference),
            improvesAtSeason: improvesAtSeason
        )
    }

    /// The first season whose average clears `baseline` by the opening threshold.
    private static func firstSeasonClearing(_ baseline: Double, in episodes: [EpisodeMetric]) -> Int? {
        let bySeason = Dictionary(grouping: episodes, by: \.seasonNumber)
        return bySeason.keys.sorted().first { season in
            weightedMean(bySeason[season] ?? []) - baseline >= openingVerdictThreshold
        }
    }

    // MARK: - Ending

    /// Only meaningful for a finished series with more than one season: an
    /// ongoing show has not ended, and a single season has no arc to land.
    static func endingVerdict(from seasons: [SeasonSummary], isOngoing: Bool) -> EndingVerdict? {
        guard !isOngoing, seasons.count > 1 else { return nil }
        guard let final = seasons.last,
              let peak = seasons.max(by: { $0.weightedAverage < $1.weightedAverage }) else {
            return nil
        }

        let shortfall = peak.weightedAverage - final.weightedAverage

        let kind: EndingVerdict.Kind
        if shortfall <= endingStrongTolerance {
            kind = .endsStrong
        } else if shortfall >= endingFadeThreshold {
            kind = .fadesOut
        } else {
            kind = .endsSteady
        }

        return EndingVerdict(
            kind: kind,
            finalSeason: final.seasonNumber,
            finalSeasonAverage: final.weightedAverage,
            peakSeason: peak.seasonNumber,
            peakSeasonAverage: peak.weightedAverage
        )
    }

    // MARK: - Plotline Score

    /// A 0-100 score built from three visible components, so the UI can show the
    /// breakdown rather than an unexplained number.
    ///
    /// - level: the weighted average, the single strongest signal, hence 60%.
    /// - consistency: how evenly the series holds that level.
    /// - trajectory: whether it climbs or slides across its run.
    static func plotlineScore(from reliable: [EpisodeMetric]) -> PlotlineScore {
        let mean = weightedMean(reliable)
        let level = clampToScore(mean * 10)

        let deviation = weightedStandardDeviation(reliable)
        let consistency = clampToScore(100 - deviation * 100)

        let ordered = reliable.sorted {
            ($0.seasonNumber, $0.episodeNumber) < ($1.seasonNumber, $1.episodeNumber)
        }
        let third = max(1, ordered.count / 3)
        let opening = weightedMean(Array(ordered.prefix(third)))
        let closing = weightedMean(Array(ordered.suffix(third)))
        let trajectory = clampToScore(50 + (closing - opening) * 25)

        let combined = Double(level) * 0.6 + Double(consistency) * 0.2 + Double(trajectory) * 0.2

        return PlotlineScore(
            value: clampToScore(combined),
            level: level,
            consistency: consistency,
            trajectory: trajectory
        )
    }

    private static func clampToScore(_ value: Double) -> Int {
        Int(min(100, max(0, value)).rounded())
    }
```

Y sustituir las tres líneas correspondientes en `analyze`:

```swift
                openingVerdict: openingVerdict(from: reliable),
                endingVerdict: endingVerdict(from: seasons, isOngoing: isOngoing),
                score: plotlineScore(from: reliable),
```

- [ ] **Step 4: Ejecutar los tests**

Run: `xcodebuild -project Plotline.xcodeproj -scheme Plotline -destination 'platform=iOS Simulator,name=iPhone 17' test`
Expected: PASS, 60 tests (50 previos + 10 nuevos).

- [ ] **Step 5: Verificar que no quedan campos sin rellenar**

```bash
grep -n "nil,\|PlotlineScore(value: 0" Plotline/Services/Analysis/SeriesAnalysisEngine.swift
```
Expected: sin resultados dentro del cuerpo de `analyze`. Todos los campos del `SeriesAnalysis` construido deben venir de una función de cálculo.

- [ ] **Step 6: Verificar el aislamiento del motor**

```bash
grep -n "^import" Plotline/Services/Analysis/SeriesAnalysisEngine.swift Plotline/Models/SeriesAnalysis.swift
```
Expected: solo `import Foundation` en ambos. Ningún `SwiftUI`, `UIKit` ni `Charts`.

```bash
grep -n "TMDBService\|NetworkManager\|DiskCache" Plotline/Services/Analysis/SeriesAnalysisEngine.swift Plotline/Models/SeriesAnalysis.swift
```
Expected: sin resultados. El motor debe poder moverse a un paquete SPM en la Fase 3 sin tocar su código.

- [ ] **Step 7: Commit**

```bash
git add Plotline/Services/Analysis/SeriesAnalysisEngine.swift PlotlineTests/SeriesAnalysisEngineTests.swift
git commit -m "feat: add opening and ending verdicts and the Plotline Score"
```

---

## Definición de terminado

- [ ] 60 tests pasando
- [ ] `analyze` no deja ningún campo sin calcular
- [ ] El motor solo importa `Foundation` y no referencia nada de la capa de red
- [ ] Ningún veredicto se emite sobre datos que no pasan la puerta de fiabilidad
- [ ] Cada veredicto lleva las referencias a episodios o temporadas que lo sustentan
- [ ] La app compila y arranca (el motor todavía no tiene consumidor en la UI: es lo esperado)

## Nota para la Fase 3

`EpisodeMetric.stillURL` referencia `TMDBService`, así que **el modelo no es puro** aunque el motor sí lo sea. Al extraer `PlotlineAnalysis` a un paquete SPM habrá que decidir: mover `stillURL` fuera del modelo, o que el paquete defina su propio tipo de entrada y la app haga la conversión. Es una decisión de la Fase 3, no de esta.
