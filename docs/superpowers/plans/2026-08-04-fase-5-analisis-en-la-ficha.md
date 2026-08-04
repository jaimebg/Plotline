# Fase 5 — El análisis en la ficha

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Mostrar en la ficha de detalle el análisis que la app ya calcula y empaqueta, con la evidencia que lo sustenta.

**Architecture:** `MediaDetailViewModel` obtiene el análisis por dos vías con precedencia clara: del dataset del bundle **al instante y sin red** para las 122 series que lleva, y recalculado con el motor cuando llegan los episodios frescos de TMDB. La sección vive **fuera** de la compuerta de red que hoy envuelve el gráfico y la rejilla.

**Tech Stack:** SwiftUI, Swift Testing, iOS 26.

**Spec:** `docs/superpowers/specs/2026-08-01-app-store-4.2-design.md` §5, apartado "Auditabilidad".

## Por qué existe esta fase

El spec §5 lo dice sin rodeos:

> Cada veredicto guarda los episodios y temporadas que lo sustentan, y la UI permite verlos. Un badge "Montaña rusa" sin justificación es decoración; uno que despliega sus datos es análisis. **Esta distinción es el argumento central frente al 4.2 y es requisito, no adorno.**

Hoy ese requisito está a medias: el motor guarda la evidencia y **la ficha no muestra ni el veredicto ni la evidencia**. Verificado, no recordado — `MediaDetailView` y `MediaDetailViewModel` no contienen una sola referencia a `SeriesAnalysis`, y de los tres consumidores de `DatasetStore` ninguno está bajo `Views/Detail/`.

Es el mismo patrón que ya ha aparecido cuatro veces en este proyecto: funcionalidad construida que el usuario no puede alcanzar. `SeriesGraphView` llevaba desconectada desde `16f6c77`; el tab de Stats escondía Compare, Career Profiles y Trends; los deep links nunca se registraron. Esta fase cierra el último caso conocido, y es el que más pesa: **el análisis propio es la respuesta entera al 4.2.**

## Global Constraints

- Deployment target iOS 26.0. **Swift 5 language mode.** No intentar migración a Swift 6.
- Los **view models** usan `@Observable`. `DatasetStore` es `@MainActor` y no observable; toda suite de test que lo toque debe ser `@MainActor` o no compila.
- **Nunca `.white` para texto** — `.primary` / `.secondary`. **Nunca fondos oscuros hardcodeados** — `Color.plotlineBackground` / `Color.plotlineCard`. Claro y oscuro.
- **Todo el texto de UI en inglés.** La app no tiene catálogo de localización.
- **Nunca editar `Plotline.xcodeproj/project.pbxproj` ni `Plotline/Info.plist`.** Los archivos `.swift` nuevos bajo `Plotline/` y `PlotlineTests/` entran solos en el target.
- Cuatro archivos de `Plotline/` los compila también el generador de datasets vía symlink desde `Tools/DatasetGenerator/Sources/DatasetGeneratorCore/Shared/`: `Models/EpisodeMetric.swift`, `Models/SeriesAnalysis.swift`, `Models/PlotlineDataset.swift` y `Services/Analysis/SeriesAnalysisEngine.swift`. **Ninguna tarea de este plan los modifica.** Si crees necesitarlo, para y pregunta: solo pueden importar `Foundation`, y una referencia a `TMDBService` rompe el build del generador. `MediaItem.swift` y `TMDBResponse.swift` **no** son compartidos y sí se tocan aquí.
- Commits en Conventional Commits, en inglés.
- Punto de partida: **91** tests de app, 48 de generador.

**Comando de tests:**

```bash
xcodebuild -project Plotline.xcodeproj -scheme Plotline \
  -destination 'platform=iOS Simulator,name=iPhone 17' test 2>/dev/null
```

Contar con `grep -cE "Test case '.*' passed"` — la forma **sin ancla**. Si sale uno corto, confirmar contra el bundle `.xcresult` antes de concluir que algo falla: xcodebuild ha truncado una línea a mitad de palabra varias veces en este proyecto.

**Trampa de entorno:** si `xcodebuild test` falla con `Application failed preflight checks` o `Busy`, es el simulador. `xcrun simctl uninstall booted com.jbgsoft.Plotline` y repetir una vez. **Nunca modificar código por ese error.**

**Fixtures existentes — úsalas, no inventes literales.** `PlotlineTests/Support/EpisodeFixtures.swift` ofrece `EpisodeFixtures.episode(season:number:rating:votes:airDate:title:)`, `EpisodeFixtures.season(_:ratings:votes:)` y `EpisodeFixtures.now` (1 de enero de 2020, fijo para que ningún test dependa del reloj). Construir un `EpisodeMetric` a mano en un test nuevo es un error: la firma real no es la que aparenta.

## La lección de la fase anterior, aplicada por adelantado

En la Fase 4 inserté los estantes curados dentro de una de las tres ramas de `mainContentView` — esqueleto, error, contenido — y con TMDB caído la rama de error se llevó por delante contenido que no necesita red. Escribí un arreglo para "la app se ve vacía" y lo metí en la estructura que la vacía.

La ficha tiene hoy exactamente la misma forma. Su sección de series está envuelta en `if viewModel.shouldShowEpisodeGrid`, que es `!episodesBySeason.isEmpty`, y eso solo se llena tras una petición a TMDB.

**La sección de análisis va fuera de esa compuerta.** Para las 122 series del bundle está disponible al instante, sin red y sin datos del usuario. Meterla dentro repetiría el error con el argumento más importante de la app.

## Alcance

Esta fase hace **solo el análisis de series en la ficha**. El "dónde verlo" del spec §7 va a una fase posterior — es superficie nueva con su propia dependencia legal (atribución obligatoria a JustWatch, cuyo incumplimiento revoca el acceso a la API de TMDB).

No se toca la ficha de películas: el motor es solo para series.

---

## Estructura de archivos

| Archivo | Responsabilidad | Acción |
|---|---|---|
| `Plotline/Models/APIResponses/TMDBResponse.swift` | Decodificar `status` y traducirlo a un bool | Modificar (Tarea 1) |
| `Plotline/Models/MediaItem.swift` | Llevar `hasEnded` hasta el motor | Modificar (Tarea 1) |
| `Plotline/ViewModels/MediaDetailViewModel.swift` | Obtener el análisis, bundle primero y red después | Modificar (Tarea 2) |
| `Plotline/Views/Detail/Analysis/PlotlineScoreCard.swift` | El score y su desglose de tres componentes | Crear (Tarea 3) |
| `Plotline/Views/Detail/Analysis/SeriesVerdictsView.swift` | Declive, consistencia, arranque y cierre, con su evidencia | Crear (Tarea 4) |
| `Plotline/Views/Detail/Analysis/StandoutEpisodesView.swift` | Imprescindibles y saltables | Crear (Tarea 5) |
| `Plotline/Views/Detail/Analysis/SeriesAnalysisSection.swift` | Compone las tres y maneja `insufficientData` | Crear (Tarea 6) |
| `Plotline/Views/Detail/MediaDetailView.swift` | Colocar la sección fuera de la compuerta de red | Modificar (Tarea 6) |
| `PlotlineTests/SeriesStatusTests.swift` | El estado terminal de TMDB | Crear (Tarea 1) |
| `PlotlineTests/DetailAnalysisTests.swift` | Precedencia y disponibilidad offline | Crear (Tarea 2) |

---

## Task 1: El estado de la serie llega hasta el motor

**Files:**
- Modify: `Plotline/Models/APIResponses/TMDBResponse.swift`
- Modify: `Plotline/Models/MediaItem.swift`
- Create: `PlotlineTests/SeriesStatusTests.swift`

**Interfaces:**
- Produces: `MediaItem.hasEnded: Bool?` — `true` solo con un estado terminal confirmado de TMDB, `nil` cuando no se sabe.

**Por qué esta tarea va primero, y por qué no es opcional.** El motor ya acepta `hasEnded`, y **la app nunca se lo pasa**: hoy el único que lo calcula es el generador de datasets. Sin esta tarea, el recálculo en vivo de la Tarea 2 llamaría al motor con `nil`, y `SeriesAnalysisEngine` exige `hasEnded == true` para emitir veredicto de cierre (`SeriesAnalysisEngine.swift:391`). El resultado en pantalla sería una regresión visible: en una serie del bundle aparecería "Ends on a high" al abrir la ficha y **desaparecería** al terminar de cargar los episodios. El análisis fresco debe ser al menos tan informativo como el empaquetado.

**El criterio terminal se copia literalmente del generador** (`Tools/DatasetGenerator/Sources/DatasetGeneratorCore/TMDBClient.swift:81`), para que el mismo título no obtenga veredictos distintos según la vía:

```swift
let terminal: Set<String> = ["Ended", "Canceled", "Cancelled"]
```

Las dos grafías de "cancelado" son deliberadas: TMDB devuelve ambas.

- [ ] **Step 1: Escribir los tests que fallan**

Crear `PlotlineTests/SeriesStatusTests.swift`:

```swift
import Foundation
import Testing
@testable import Plotline

@Suite("Series status")
struct SeriesStatusTests {
    private func detailJSON(status: String?) -> Data {
        let statusField = status.map { "\"status\": \"\($0)\"," } ?? ""
        return Data("""
        {
            "id": 1396,
            \(statusField)
            "overview": "",
            "vote_average": 8.9,
            "vote_count": 100,
            "name": "Test Series",
            "number_of_seasons": 5
        }
        """.utf8)
    }

    private func decode(status: String?) throws -> MediaItem {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let response = try decoder.decode(TMDBDetailResponse.self, from: detailJSON(status: status))
        return response.toMediaItem(mediaType: .tv)
    }

    @Test("a terminal status counts as ended", arguments: ["Ended", "Canceled", "Cancelled"])
    func terminalStatuses(status: String) throws {
        #expect(try decode(status: status).hasEnded == true)
    }

    @Test("a running series is not ended", arguments: ["Returning Series", "In Production", "Planned"])
    func runningStatuses(status: String) throws {
        #expect(try decode(status: status).hasEnded == false)
    }

    /// An absent status is unknown, which is not the same as still running.
    /// The engine withholds the ending verdict on nil, and that is the point.
    @Test("an absent status stays unknown rather than guessing")
    func absentStatusIsUnknown() throws {
        #expect(try decode(status: nil).hasEnded == nil)
    }
}
```

- [ ] **Step 2: Ejecutar para verificar que falla**

Run: el comando de tests.
Expected: FAIL de compilación, `value of type 'MediaItem' has no member 'hasEnded'`.

- [ ] **Step 3: Decodificar el estado**

En `Plotline/Models/APIResponses/TMDBResponse.swift`, en la sección `// TV-specific` de `TMDBDetailResponse`, junto a `numberOfEpisodes`:

```swift
    /// TMDB's series-level status verbatim ("Ended", "Returning Series", …).
    /// Kept raw; the terminal reading lives in `hasEnded` below.
    let status: String?
```

Y justo encima de `toMediaItem(mediaType:)`:

```swift
    /// TMDB's status reduced to the one bit the analysis engine needs.
    ///
    /// `nil` means TMDB did not say, which is not the same as still running:
    /// the engine refuses to judge an ending without a confirmed one, and an
    /// absent status must not be flattened into `false`.
    ///
    /// The terminal set matches the dataset generator's exactly
    /// (`Tools/DatasetGenerator/…/TMDBClient.swift`) so the same series cannot
    /// get one verdict from the bundle and another from the network. Both
    /// spellings of "cancelled" are deliberate — TMDB returns each.
    var hasEnded: Bool? {
        guard let status else { return nil }
        return ["Ended", "Canceled", "Cancelled"].contains(status)
    }
```

Y añadir el argumento a la llamada de `MediaItem(...)` dentro de `toMediaItem`, **al final de la lista**, tras `collectionName`:

```swift
            collectionName: belongsToCollection?.name,
            hasEnded: hasEnded
```

- [ ] **Step 4: Llevarlo a `MediaItem`**

En `Plotline/Models/MediaItem.swift`, tras `var collectionName: String?`:

```swift
    /// Whether the series has finished, when TMDB says so. `nil` means unknown.
    ///
    /// Declared `var` and optional on purpose: `MediaItem` is cached to disk,
    /// and an entry written before this property existed must still decode.
    var hasEnded: Bool?
```

**Importante:** debe ir **después** de las propiedades existentes y ser `var` opcional. Así el inicializador por miembros lo recibe con valor por defecto `nil`, ninguna de las llamadas existentes se rompe, y `DiskCache` sigue decodificando las entradas antiguas.

- [ ] **Step 5: Ejecutar los tests**

Run: el comando de tests.
Expected: PASS, **98** tests (91 + 7: tres estados terminales, tres en marcha, uno ausente).

Si el conteo no cuadra por cómo se expanden los `arguments:`, confirmar contra el `.xcresult` antes de tocar nada.

- [ ] **Step 6: Commit**

```bash
git add Plotline/Models/APIResponses/TMDBResponse.swift Plotline/Models/MediaItem.swift PlotlineTests/SeriesStatusTests.swift
git commit -m "feat: carry TMDB's series status through to MediaItem

The analysis engine has always accepted hasEnded and the app never
supplied it, so only the dataset generator could produce an ending
verdict. The terminal set matches the generator's exactly."
```

---

## Task 2: El análisis llega al view model

**Files:**
- Modify: `Plotline/ViewModels/MediaDetailViewModel.swift`
- Create: `PlotlineTests/DetailAnalysisTests.swift`

**Interfaces:**
- Consumes: `DatasetStore.shared.entry(forTMDBId: Int) -> DatasetEntry?`, `SeriesAnalysisEngine.analyze(episodes:hasEnded:asOf:) -> SeriesAnalysisResult`, `DatasetEntry.analysis: SeriesAnalysis`, `MediaItem.hasEnded` (Tarea 1)
- Produces: `MediaDetailViewModel.analysis: SeriesAnalysisResult?`, `MediaDetailViewModel.analysisSource: AnalysisSource` con casos `.bundled` y `.live`, y los métodos `loadBundledAnalysis()` y `recomputeAnalysis(asOf:)`

**La regla de precedencia, que es el corazón de la tarea.** El dataset del bundle es **semilla y respaldo, nunca verdad**. Al abrir la ficha:

1. Si la serie está en el bundle, su análisis se muestra **de inmediato**, sin esperar a nada. Eso da contenido en el primer fotograma y funciona sin conexión.
2. Cuando los episodios frescos llegan de TMDB, el motor recalcula y **el resultado fresco sustituye al empaquetado**.
3. Si la serie no está en el bundle, solo aparece tras el recálculo.

El orden de carga ya existente hace que esto funcione sin coordinación extra: `loadDetails()` espera a `fetchTMDBDetails()` (línea 66) **antes** de lanzar `fetchAllSeasons()` (línea 72), así que cuando toca recalcular, `media.hasEnded` ya está poblado.

- [ ] **Step 1: Escribir los tests que fallan**

Crear `PlotlineTests/DetailAnalysisTests.swift`:

```swift
import Foundation
import Testing
@testable import Plotline

@MainActor
@Suite("Detail analysis")
struct DetailAnalysisTests {
    /// Breaking Bad — in the bundled dataset, so its analysis must be on hand
    /// before a single request is made.
    private let bundledSeriesId = 1396

    private func media(id: Int, type: MediaType) -> MediaItem {
        MediaItem(
            id: id,
            overview: "",
            posterPath: nil,
            backdropPath: nil,
            voteAverage: 0,
            voteCount: 0,
            genreIds: nil,
            title: type == .movie ? "Test Movie" : nil,
            releaseDate: nil,
            name: type == .tv ? "Test Series" : nil,
            firstAirDate: nil,
            mediaType: type
        )
    }

    @Test("a bundled series has its analysis before any network call")
    func bundledAnalysisIsImmediate() {
        let viewModel = MediaDetailViewModel(media: media(id: bundledSeriesId, type: .tv))
        viewModel.loadBundledAnalysis()

        guard case .analyzed = viewModel.analysis else {
            Issue.record("expected a bundled analysis, got \(String(describing: viewModel.analysis))")
            return
        }
        #expect(viewModel.analysisSource == .bundled)
    }

    @Test("a bundled series is analysable with no episodes loaded at all")
    func bundledAnalysisNeedsNoEpisodes() {
        let viewModel = MediaDetailViewModel(media: media(id: bundledSeriesId, type: .tv))
        viewModel.loadBundledAnalysis()

        // Nothing has been fetched: this is the offline first-frame case.
        #expect(viewModel.episodesBySeason.isEmpty)

        guard case .analyzed(let analysis) = viewModel.analysis else {
            Issue.record("expected an analysis with no episodes loaded")
            return
        }
        #expect(analysis.score.value > 0)
        #expect(!analysis.seasons.isEmpty)
    }

    @Test("a series absent from the bundle has no analysis until episodes arrive")
    func unbundledSeriesHasNothingYet() {
        let viewModel = MediaDetailViewModel(media: media(id: -1, type: .tv))
        viewModel.loadBundledAnalysis()

        #expect(viewModel.analysis == nil)
    }

    @Test("a movie never gets an analysis")
    func moviesAreNotAnalysed() {
        let viewModel = MediaDetailViewModel(media: media(id: bundledSeriesId, type: .movie))
        viewModel.loadBundledAnalysis()

        #expect(viewModel.analysis == nil)
    }

    @Test("recomputing from fresh episodes replaces the bundled analysis")
    func freshEpisodesWin() {
        let viewModel = MediaDetailViewModel(media: media(id: bundledSeriesId, type: .tv))
        viewModel.loadBundledAnalysis()
        #expect(viewModel.analysisSource == .bundled)

        // A flat, unremarkable run — nothing like the bundled Breaking Bad.
        let episodes = (1...3).flatMap { season in
            EpisodeFixtures.season(season, ratings: Array(repeating: 7.0, count: 6))
        }
        viewModel.episodesBySeason = Dictionary(grouping: episodes, by: \.seasonNumber)
        viewModel.recomputeAnalysis(asOf: EpisodeFixtures.now)

        guard case .analyzed(let analysis) = viewModel.analysis else {
            Issue.record("expected an analysis")
            return
        }
        #expect(viewModel.analysisSource == .live)
        #expect(analysis.seasons.count == 3)
    }

    /// The regression Task 1 exists to prevent: a bundled series shows an
    /// ending verdict, and the live recomputation must not silently drop it.
    @Test("a confirmed ended status survives the live recomputation")
    func endedStatusReachesTheEngine() {
        var ended = media(id: -1, type: .tv)
        ended.hasEnded = true

        let viewModel = MediaDetailViewModel(media: ended)
        let episodes = EpisodeFixtures.season(1, ratings: [6.0, 6.1, 6.0, 6.2, 6.1, 6.0])
            + EpisodeFixtures.season(2, ratings: [8.8, 8.9, 9.0, 8.7, 8.9, 9.1])
        viewModel.episodesBySeason = Dictionary(grouping: episodes, by: \.seasonNumber)
        viewModel.recomputeAnalysis(asOf: EpisodeFixtures.now)

        guard case .analyzed(let analysis) = viewModel.analysis else {
            Issue.record("expected an analysis")
            return
        }
        #expect(analysis.endingVerdict != nil)
    }

    @Test("too little data yields insufficientData rather than a made-up verdict")
    func thinDataIsRefused() {
        let viewModel = MediaDetailViewModel(media: media(id: -1, type: .tv))
        viewModel.episodesBySeason = [1: [EpisodeFixtures.episode(season: 1, number: 1, rating: 8.0)]]
        viewModel.recomputeAnalysis(asOf: EpisodeFixtures.now)

        guard case .insufficientData = viewModel.analysis else {
            Issue.record("expected .insufficientData, got \(String(describing: viewModel.analysis))")
            return
        }
    }
}
```

**Sobre `endedStatusReachesTheEngine`:** las dos temporadas son deliberadas — el motor exige mínimos de episodios fiables y de temporadas antes de emitir veredictos, y una sola temporada plana no basta. Si el veredicto no sale con estos datos, **no ajustes el test a lo que salga**: lee los umbrales en `SeriesAnalysisEngine.swift`, corrige los *datos* para superarlos de forma honesta, y di en el informe qué cambiaste. Un test doblado hasta pasar es peor que ninguno; en este proyecto ya hubo cinco que no podían fallar.

- [ ] **Step 2: Ejecutar para verificar que falla**

Run: el comando de tests.
Expected: FAIL de compilación, `value of type 'MediaDetailViewModel' has no member 'analysis'`.

- [ ] **Step 3: Añadir el análisis al view model**

En `Plotline/ViewModels/MediaDetailViewModel.swift`, junto al resto del estado de series (cerca de `var episodesBySeason`):

```swift
    /// Where the analysis on screen came from. The bundled copy appears
    /// instantly and offline; a live recomputation replaces it as soon as
    /// TMDB's episodes arrive.
    enum AnalysisSource: Equatable {
        case bundled
        case live
    }

    var analysis: SeriesAnalysisResult?
    private(set) var analysisSource: AnalysisSource = .bundled
```

Y los dos métodos, en una sección propia:

```swift
    // MARK: - Analysis

    /// Reads the analysis shipped in the app bundle, if this series is one of
    /// the titles it covers.
    ///
    /// This runs before any request, so a bundled series shows its analysis in
    /// the first frame and keeps showing it with no connection at all. It is a
    /// seed and a fallback, never the truth: `recomputeAnalysis` overwrites it
    /// the moment fresher episodes arrive.
    @MainActor
    func loadBundledAnalysis() {
        guard media.isTVSeries else { return }
        guard let entry = DatasetStore.shared.entry(forTMDBId: media.id) else { return }

        analysis = .analyzed(entry.analysis)
        analysisSource = .bundled
    }

    /// Recomputes from the episodes currently held, replacing anything the
    /// bundle provided.
    ///
    /// `media.hasEnded` is read at call time rather than passed in: by the time
    /// episodes exist, `fetchTMDBDetails()` has already populated it. It stays
    /// optional all the way down — the engine treats an unknown status as
    /// grounds to withhold the ending verdict, not as proof the show is still
    /// running.
    ///
    /// - Parameter now: explicit so the result never depends on the clock.
    @MainActor
    func recomputeAnalysis(asOf now: Date = Date()) {
        guard media.isTVSeries else { return }

        let episodes = episodesBySeason.values.flatMap { $0 }
        guard !episodes.isEmpty else { return }

        analysis = SeriesAnalysisEngine.analyze(
            episodes: episodes,
            hasEnded: media.hasEnded,
            asOf: now
        )
        analysisSource = .live
    }
```

- [ ] **Step 4: Llamarlos desde el ciclo de carga**

En `loadDetails()`, como **primera línea del cuerpo**, antes de `await fetchTMDBDetails()`:

```swift
        loadBundledAnalysis()
```

Esa posición es deliberada: tras un `await`, la ficha pasaría tiempo sin análisis aunque lo tenga empaquetado, y sin conexión no lo mostraría nunca.

En `fetchAllSeasons()`, justo antes de `isLoadingAllSeasons = false`:

```swift
        recomputeAnalysis()
```

- [ ] **Step 5: Ejecutar los tests**

Run: el comando de tests.
Expected: PASS, **105** tests (98 + 7).

- [ ] **Step 6: Commit**

```bash
git add Plotline/ViewModels/MediaDetailViewModel.swift PlotlineTests/DetailAnalysisTests.swift
git commit -m "feat: bring the series analysis into the detail view model

The bundled copy loads before any request, so a covered series shows its
analysis in the first frame and with no connection; a live recomputation
replaces it as soon as TMDB's episodes arrive."
```

---

## Task 3: La tarjeta del Plotline Score

**Files:**
- Create: `Plotline/Views/Detail/Analysis/PlotlineScoreCard.swift`

**Interfaces:**
- Consumes: `PlotlineScore` con `value: Int`, `level: Int`, `consistency: Int`, `trajectory: Int`
- Produces: `PlotlineScoreCard(score: PlotlineScore)`

**El desglose no es decoración.** El spec §5 exige que el score muestre sus tres componentes. Un número solo es una opinión; un número que enseña de qué está hecho es un análisis, y esa diferencia es literalmente el argumento contra el 4.2.

- [ ] **Step 1: Escribir la tarjeta**

Crear `Plotline/Views/Detail/Analysis/PlotlineScoreCard.swift`:

```swift
import SwiftUI

/// Plotline's own 0-100 score, with the three components it is made of.
///
/// The breakdown is the point. A bare number is an opinion; a number that
/// shows its working is an analysis, and that distinction is what this app
/// offers over a catalogue listing.
struct PlotlineScoreCard: View {
    let score: PlotlineScore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(score.value)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.plotlineGold)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Plotline Score")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("Out of 100")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 10) {
                component("Level", value: score.level, caption: "How highly its episodes rate")
                component("Consistency", value: score.consistency, caption: "How evenly it holds that level")
                component("Trajectory", value: score.trajectory, caption: "Whether it climbs or slides")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.plotlineCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Plotline Score \(score.value) out of 100. Level \(score.level), consistency \(score.consistency), trajectory \(score.trajectory)."
        )
    }

    private func component(_ name: String, value: Int, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(name)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(value)")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: Double(value), total: 100)
                .tint(Color.plotlineGold)

            Text(caption)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name): \(value) out of 100. \(caption)")
    }
}

#Preview {
    PlotlineScoreCard(score: PlotlineScore(value: 82, level: 88, consistency: 74, trajectory: 61))
        .padding()
}
```

- [ ] **Step 2: Compilar**

Run: `xcodebuild -project Plotline.xcodeproj -scheme Plotline -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath build build`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Ejecutar la suite**

Expected: PASS, 105 tests, sin cambio.

- [ ] **Step 4: Commit**

```bash
git add Plotline/Views/Detail/Analysis/PlotlineScoreCard.swift
git commit -m "feat: add the Plotline Score card with its three components"
```

---

## Task 4: Los veredictos, con su evidencia

**Files:**
- Create: `Plotline/Views/Detail/Analysis/SeriesVerdictsView.swift`

**Interfaces:**
- Consumes: `SeriesAnalysis` (`declinePoint: DeclinePoint?`, `consistency: Consistency`, `openingVerdict: OpeningVerdict?`, `endingVerdict: EndingVerdict?`, `bestSeason: Int?`, `worstSeason: Int?`, `isOngoing: Bool`)
- Produces: `SeriesVerdictsView(analysis: SeriesAnalysis)`

**Tres reglas de honestidad que vienen de defectos ya documentados. No son sugerencias.**

1. **`isOngoing == false` significa "terminada **o** desconocida".** El propio modelo lo advierte en `SeriesAnalysis.swift:40-45`. Nunca renderizarlo como "Ended". Solo se dice algo cuando `isOngoing` es `true`.
2. **`bestSeason` puede coincidir con `worstSeason`** cuando solo una temporada tiene datos suficientes. Si coinciden, no mostrar el par: "mejor temporada 3 / peor temporada 3" se lee como una contradicción.
3. **El copy no puede afirmar más de lo que el motor comprueba.** Este proyecto ya ha corregido tres textos por esto. `declinePoint` demuestra una caída relativa que no se recupera — no dice nada sobre lo buena que era la serie antes.

- [ ] **Step 1: Escribir la vista**

Crear `Plotline/Views/Detail/Analysis/SeriesVerdictsView.swift`:

```swift
import SwiftUI

/// The engine's verdicts, each shown with the data that supports it.
///
/// Every string here is written against what the engine actually proves. The
/// decline point establishes a relative fall that never recovers; it says
/// nothing about how good the show was beforehand, so neither does the copy.
struct SeriesVerdictsView: View {
    let analysis: SeriesAnalysis

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What the Numbers Say")
                .font(.system(.headline, weight: .semibold))
                .foregroundStyle(.primary)

            VStack(spacing: 10) {
                if let decline = analysis.declinePoint {
                    verdict(
                        icon: "arrow.down.right",
                        title: "Falls off after season \(decline.afterSeason)",
                        evidence: String(
                            format: "Averaged %.1f up to then, %.1f across seasons %@.",
                            decline.averageBefore,
                            decline.averageAfter,
                            decline.seasonsAfter.map(String.init).joined(separator: ", ")
                        )
                    )
                }

                verdict(
                    icon: consistencyIcon,
                    title: consistencyTitle,
                    evidence: consistencyEvidence
                )

                if let opening = analysis.openingVerdict {
                    verdict(
                        icon: "play.circle",
                        title: openingTitle(opening),
                        evidence: String(
                            format: "First %d episodes averaged %.1f against %.1f for the rest.",
                            opening.episodesConsidered.count,
                            opening.openingAverage,
                            opening.remainderAverage
                        )
                    )
                }

                if let ending = analysis.endingVerdict {
                    verdict(
                        icon: "flag.checkered",
                        title: endingTitle(ending),
                        evidence: String(
                            format: "Season %d averaged %.1f; its best, season %d, averaged %.1f.",
                            ending.finalSeason,
                            ending.finalSeasonAverage,
                            ending.peakSeason,
                            ending.peakSeasonAverage
                        )
                    )
                }

                if let best = analysis.bestSeason, let worst = analysis.worstSeason, best != worst {
                    verdict(
                        icon: "chart.bar",
                        title: "Best season \(best), weakest season \(worst)",
                        evidence: "Measured across the seasons with enough rated episodes to judge."
                    )
                }

                // Only the positive case is stated: `isOngoing == false` also
                // covers "status unknown", which is no evidence of an ending.
                if analysis.isOngoing {
                    verdict(
                        icon: "dot.radiowaves.up.forward",
                        title: "Still running",
                        evidence: "More episodes are on the way, so there is no ending to judge yet."
                    )
                }
            }
        }
    }

    // MARK: - Rows

    private func verdict(icon: String, title: String, evidence: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(Color.plotlineSecondaryAccent)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)

                Text(evidence)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.plotlineCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(evidence)")
    }

    // MARK: - Copy

    private var consistencyIcon: String {
        switch analysis.consistency.rating {
        case .verySteady, .steady: "equal.circle"
        case .uneven: "waveform.path"
        case .rollercoaster: "waveform.path.ecg"
        }
    }

    private var consistencyTitle: String {
        switch analysis.consistency.rating {
        case .verySteady: "Remarkably even"
        case .steady: "Holds a steady level"
        case .uneven: "Uneven episode to episode"
        case .rollercoaster: "A rollercoaster"
        }
    }

    private var consistencyEvidence: String {
        guard let high = analysis.consistency.highestRated,
              let low = analysis.consistency.lowestRated else {
            return String(format: "Episode ratings vary by %.2f on average.", analysis.consistency.standardDeviation)
        }
        return String(
            format: "Ranges from %@ at %.1f down to %@ at %.1f.",
            high.shortCode, high.rating, low.shortCode, low.rating
        )
    }

    private func openingTitle(_ opening: OpeningVerdict) -> String {
        switch opening.kind {
        case .hooksEarly: "Hooks you early"
        case .slowStart:
            if let season = opening.improvesAtSeason {
                return "Slow start, better from season \(season)"
            }
            return "Slow start, better later on"
        case .even: "Even from the start"
        }
    }

    private func endingTitle(_ ending: EndingVerdict) -> String {
        switch ending.kind {
        case .endsStrong: "Ends on a high"
        case .endsSteady: "Holds its level to the end"
        case .fadesOut: "Fades out at the end"
        }
    }
}
```

- [ ] **Step 2: Compilar y ejecutar la suite**

Expected: `** BUILD SUCCEEDED **` y 105 tests sin cambio.

- [ ] **Step 3: Commit**

```bash
git add Plotline/Views/Detail/Analysis/SeriesVerdictsView.swift
git commit -m "feat: show each analysis verdict with the data behind it"
```

---

## Task 5: Episodios imprescindibles y saltables

**Files:**
- Create: `Plotline/Views/Detail/Analysis/StandoutEpisodesView.swift`

**Interfaces:**
- Consumes: `SeriesAnalysis.essentialEpisodes: [EpisodeReference]`, `.skippableEpisodes: [EpisodeReference]`; `EpisodeReference` con `id: Int`, `shortCode: String`, `title: String`, `rating: Double`
- Produces: `StandoutEpisodesView(analysis: SeriesAnalysis)`

- [ ] **Step 1: Escribir la vista**

Crear `Plotline/Views/Detail/Analysis/StandoutEpisodesView.swift`:

```swift
import SwiftUI

/// Episodes that sit far from their own season's average, in either direction.
///
/// Judged within each season rather than across the run, so a high point of a
/// weaker season still shows up — which is what someone deciding whether to
/// skip ahead actually wants to know.
struct StandoutEpisodesView: View {
    let analysis: SeriesAnalysis

    private var hasAnything: Bool {
        !analysis.essentialEpisodes.isEmpty || !analysis.skippableEpisodes.isEmpty
    }

    var body: some View {
        if hasAnything {
            VStack(alignment: .leading, spacing: 12) {
                Text("Standout Episodes")
                    .font(.system(.headline, weight: .semibold))
                    .foregroundStyle(.primary)

                if !analysis.essentialEpisodes.isEmpty {
                    group(
                        title: "Don't miss",
                        caption: "Rated far above their own season",
                        episodes: analysis.essentialEpisodes,
                        tint: Color.chartHigh
                    )
                }

                if !analysis.skippableEpisodes.isEmpty {
                    group(
                        title: "Safe to skip",
                        caption: "Rated far below their own season",
                        episodes: analysis.skippableEpisodes,
                        tint: Color.chartLow
                    )
                }
            }
        }
    }

    private func group(
        title: String,
        caption: String,
        episodes: [EpisodeReference],
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            ForEach(episodes) { episode in
                HStack(spacing: 10) {
                    Text(episode.shortCode)
                        .font(.system(.caption, design: .monospaced, weight: .semibold))
                        .foregroundStyle(tint)
                        .frame(width: 52, alignment: .leading)

                    Text(episode.title)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer()

                    Text(String(format: "%.1f", episode.rating))
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(episode.shortCode), \(episode.title), rated \(String(format: "%.1f", episode.rating))")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.plotlineCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
```

`Color.chartHigh` y `Color.chartLow` existen en `Extensions/Color+Plotline.swift` (líneas 65 y 71) y son alias de colores de marca. **No sustituir por `.green` / `.red` literales:** rompen el modo oscuro.

- [ ] **Step 2: Compilar y ejecutar la suite**

Expected: `** BUILD SUCCEEDED **` y 105 tests sin cambio.

- [ ] **Step 3: Commit**

```bash
git add Plotline/Views/Detail/Analysis/StandoutEpisodesView.swift
git commit -m "feat: list the episodes that stand out within their season"
```

---

## Task 6: Componer y colocar la sección

**Files:**
- Create: `Plotline/Views/Detail/Analysis/SeriesAnalysisSection.swift`
- Modify: `Plotline/Views/Detail/MediaDetailView.swift`

**Interfaces:**
- Consumes: `PlotlineScoreCard`, `SeriesVerdictsView`, `StandoutEpisodesView`, `SeriesAnalysisResult`, `InsufficientDataReason`
- Produces: `SeriesAnalysisSection(result: SeriesAnalysisResult?)`

**Dónde va, que es la decisión que importa.** Fuera de `if viewModel.shouldShowEpisodeGrid`. Esa condición es `!episodesBySeason.isEmpty`, que solo se cumple tras una petición a TMDB — y para las 122 series del bundle el análisis está disponible sin ninguna. Meterlo dentro repetiría el error que la Fase 4 tuvo que corregir en Discover.

**Sobre `insufficientData`:** el modelo declara la razón *precisamente* para que la UI diga algo cierto (`SeriesAnalysis.swift:12-13`). Un texto único para los cuatro casos sería falso en al menos uno: `noAiredEpisodes` significa que **no se ha emitido nada**, no que haya pocas valoraciones. Cada caso tiene su frase.

- [ ] **Step 1: Escribir el compositor**

Crear `Plotline/Views/Detail/Analysis/SeriesAnalysisSection.swift`:

```swift
import SwiftUI

/// Plotline's analysis of a series, or an honest silence.
///
/// Renders nothing at all when there is no result yet, and a reason when the
/// engine declined to judge. It never fills the gap with a softer verdict: the
/// engine's rule is that it says nothing it cannot support, and the UI keeps
/// that promise rather than papering over it.
struct SeriesAnalysisSection: View {
    let result: SeriesAnalysisResult?

    var body: some View {
        switch result {
        case .analyzed(let analysis):
            VStack(alignment: .leading, spacing: 16) {
                PlotlineScoreCard(score: analysis.score)
                SeriesVerdictsView(analysis: analysis)
                StandoutEpisodesView(analysis: analysis)
            }

        case .insufficientData(let reason):
            unavailable(reason: reason)

        case nil:
            EmptyView()
        }
    }

    private func unavailable(reason: InsufficientDataReason) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title(for: reason))
                .font(.system(.headline, weight: .semibold))
                .foregroundStyle(.primary)

            Text(explanation(for: reason))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.plotlineCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title(for: reason)). \(explanation(for: reason))")
    }

    /// One message per reason. A single catch-all would be wrong for at least
    /// one of them: "nothing has aired" is a different fact from "too few
    /// ratings", and saying the wrong one is exactly the failure this app is
    /// built to avoid.
    private func title(for reason: InsufficientDataReason) -> String {
        switch reason {
        case .noAiredEpisodes: "Nothing Has Aired Yet"
        case .noReliableEpisodes, .tooFewReliableEpisodes, .notEnoughEpisodesToAnalyse: "Not Enough Ratings Yet"
        }
    }

    private func explanation(for reason: InsufficientDataReason) -> String {
        switch reason {
        case .noAiredEpisodes:
            "We'll analyse this series once its episodes start airing."
        case .noReliableEpisodes:
            "Its episodes haven't collected enough ratings for us to say anything we'd stand behind."
        case .tooFewReliableEpisodes:
            "Only a small share of its episodes carry enough ratings to judge, so we'd rather not guess at the rest."
        case .notEnoughEpisodesToAnalyse:
            "There are too few rated episodes here to draw any conclusion from."
        }
    }
}
```

- [ ] **Step 2: Colocarla en la ficha**

En `Plotline/Views/Detail/MediaDetailView.swift`, dentro de `if viewModel.isTVSeries { ... }`, **antes** del `if viewModel.shouldShowEpisodeGrid`, de modo que quede así:

```swift
                    // Series-specific content
                    if viewModel.isTVSeries {
                        // Plotline's own analysis. Outside the grid's gate on
                        // purpose: for the series the bundle covers this needs
                        // no network at all, and hiding it behind a fetch would
                        // repeat a mistake this project already had to fix on
                        // Discover.
                        SeriesAnalysisSection(result: viewModel.analysis)

                        // Interactive quality curve, then the full-season grid
                        if viewModel.shouldShowEpisodeGrid {
                            seriesGraphSection
                            EpisodeRatingsGridView(
                                episodesBySeason: viewModel.episodesBySeason,
                                totalSeasons: viewModel.totalSeasons
                            )
                        } else if viewModel.isLoadingAllSeasons {
                            episodeGridLoadingView
                        } else if let message = viewModel.episodesError {
                            episodeGridUnavailableView(message: message)
                        }
                    }
```

- [ ] **Step 3: Compilar y ejecutar la suite**

Expected: `** BUILD SUCCEEDED **` y PASS, 105 tests.

- [ ] **Step 4: Commit**

```bash
git add Plotline/Views/Detail/Analysis/SeriesAnalysisSection.swift Plotline/Views/Detail/MediaDetailView.swift
git commit -m "feat: show Plotline's analysis on the series detail screen

Placed outside the episode grid's network gate: for the series the
bundle covers, the analysis is available with no connection, and hiding
it behind a fetch would repeat a mistake this project already fixed once."
```

---

## Definición de terminado

- [ ] 105 tests pasando
- [ ] La ficha de una serie del bundle muestra score, veredictos y episodios destacados **sin conexión**
- [ ] Cada veredicto muestra la evidencia numérica que lo sustenta
- [ ] El veredicto de cierre **no desaparece** al terminar de cargar los episodios
- [ ] Ningún veredicto se muestra sobre `insufficientData`, y cada razón tiene su propio texto
- [ ] `isOngoing == false` no se renderiza como "Ended" en ninguna parte
- [ ] `bestSeason` y `worstSeason` no se muestran cuando coinciden
- [ ] Verificado en claro y oscuro
- [ ] Ningún texto de UI en español

## Nota para la fase siguiente

El "dónde verlo" del spec §7 queda pendiente, con dos correcciones ya registradas en el propio spec: TMDB **no** devuelve deep links por plataforma, y la atribución a JustWatch se exige **en cada ficha** bajo pena de revocar el acceso a la API — lo que, con toda la app corriendo sobre TMDB, es un riesgo existencial y no un remate.
