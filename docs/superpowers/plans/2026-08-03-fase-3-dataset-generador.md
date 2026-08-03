# Fase 3 — Generador y dataset del bundle

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Producir un dataset empaquetable con el análisis ya calculado de un conjunto de series conocidas y sus premios, generado por una herramienta que ejecuta **el mismo motor** que la app.

**Architecture:** Un paquete SwiftPM en `Tools/DatasetGenerator` cuya librería contiene **symlinks** a los archivos del motor que ya compila la app. Los dos consumidores compilan las mismas fuentes: una implementación, dos consumidores, sin duplicar y sin tocar el proyecto de Xcode. Van en el mismo módulo que el código del generador para que la visibilidad `internal` siga funcionando y la app no necesite ni un `public`. El generador trae su propio cliente HTTP mínimo porque el de la app arrastra caché, secretos y manejo de errores de UI que una herramienta de línea de comandos no quiere.

**Tech Stack:** Swift, SwiftPM, Foundation, TMDB API v3, Wikidata SPARQL.

**Spec:** `docs/superpowers/specs/2026-08-01-app-store-4.2-design.md` §6

## Global Constraints

- El proyecto de la app compila en **Swift 5 language mode**. El paquete del generador declara `swift-tools-version: 6.0` y `swiftLanguageModes: [.v5]` para compilar las fuentes compartidas con la misma semántica.
- **Nunca editar `Plotline.xcodeproj/project.pbxproj` ni `Plotline/Info.plist`.** Esta fase no toca el proyecto de Xcode en absoluto.
- Los archivos compartidos por symlink deben seguir importando **solo Foundation**. Si el generador no compila por una referencia a `TMDBService`, `NetworkManager` o `DiskCache`, la solución es sacar esa referencia del archivo compartido, nunca añadir el tipo al paquete.
- El generador **nunca** forma parte del build de la app ni de su suite de tests.
- Ninguna clave de API se commitea. El generador lee `TMDB_API_KEY` del entorno.
- Commits en Conventional Commits, en inglés.
- La app debe seguir compilando y su suite pasando al final de **cada** tarea. El conteo es **75 al empezar y 74 a partir de la Tarea 1**, que borra `buildsStillURL` junto con la propiedad que probaba. Es la única bajada esperada en toda la fase: cualquier otra es una regresión.

**Comando de tests de la app** (regresión, tras cada tarea):

```bash
xcodebuild -project Plotline.xcodeproj -scheme Plotline \
  -destination 'platform=iOS Simulator,name=iPhone 17' test 2>/dev/null
```

Contar con `grep -cE "Test case '.*' passed"` — la forma sin ancla, porque la anclada subcuenta por uno de vez en cuando por interleaving de la salida de xcodebuild.

**Comando de tests del generador:**

```bash
swift test --package-path Tools/DatasetGenerator
```

**Trampa de entorno:** si `xcodebuild test` falla con `Application failed preflight checks` o `Busy`, es el simulador, no el código. `xcrun simctl uninstall booted com.jbgsoft.Plotline` y repetir una vez. **Nunca modificar código por ese error.**

## Alcance

Esta fase produce **la herramienta y el archivo**. La app **no lee el dataset todavía** — cargarlo, aplicar la precedencia red-sobre-bundle y llenar las pantallas es la Fase 4. Es la segunda fase seguida sin cambio visible para el usuario; se dice explícito para que no parezca trabajo a medias.

## Hechos verificados antes de escribir este plan

No son suposiciones. Se comprobaron contra los servicios reales:

- **Wikidata resuelve por ID de TMDB.** `P4947` es el ID de película de TMDB y `P4983` el de serie. Consultando `?film wdt:P4947 "872585"` sale Oppenheimer; `?show wdt:P4983 "1396"` sale Breaking Bad con 12 premios (Emmy a Mejor Drama, Globo de Oro, Peabody, SAG, Critics' Choice, Satellite).
- **El endpoint no necesita API key**, pero **sí exige un `User-Agent` identificable**. Sin él devuelve 403.
- **No hay que enumerar QIDs de premios.** El primer intento consultando por `wd:Q1364556` (adivinando el Emmy a Mejor Drama) devolvió cero filas porque el QID era incorrecto. Consultar por ID de TMDB y recoger lo que haya evita adivinar y es además lo que el generador necesita, porque ya parte de una lista semilla de IDs.
- **`EpisodeMetric.stillURL` es el único obstáculo a la pureza del modelo**, y no lo usa ninguna vista: su único consumidor en todo el repo es una aserción de test.

---

## Estructura de archivos

| Archivo | Responsabilidad | Acción |
|---|---|---|
| `Plotline/Models/EpisodeMetric.swift` | Quitar `stillURL` | Modificar (Tarea 1) |
| `Tools/DatasetGenerator/Package.swift` | Manifiesto | Crear (Tarea 2) |
| `.../Sources/DatasetGeneratorCore/Shared/` | Symlinks al motor de la app | Crear (Tareas 2 y 5) |
| `.../Sources/dataset-generator/main.swift` | Shell de una línea | Crear (Tarea 2) |
| `.../Sources/DatasetGeneratorCore/TMDBClient.swift` | Cliente HTTP mínimo de TMDB | Crear (Tarea 3) |
| `.../Sources/DatasetGeneratorCore/SeedList.swift` | IDs de TMDB de las series semilla | Crear (Tarea 3) |
| `.../Sources/DatasetGeneratorCore/WikidataClient.swift` | Premios vía SPARQL | Crear (Tarea 4) |
| `.../Sources/DatasetGeneratorCore/DatasetBuilder.swift` | Ensamblado y listas curadas | Crear (Tarea 5) |
| `.../Sources/DatasetGeneratorCore/Generator.swift` | Orquestación, llamada por el ejecutable | Crear (Tarea 5) |
| `Plotline/Models/PlotlineDataset.swift` | Tipo del dataset, compartido app↔generador | Crear (Tarea 5) |
| `Tools/DatasetGenerator/Tests/...` | Tests del generador | Crear (Tareas 3-5) |

---

## Task 1: Hacer `EpisodeMetric` puro

`stillURL` llama a `TMDBService.backdropURL`, lo que ata el modelo a la capa de red y **impide que el paquete del generador compile el archivo**. Ninguna vista lo usa.

**Files:**
- Modify: `Plotline/Models/EpisodeMetric.swift`
- Modify: `PlotlineTests/EpisodeMetricTests.swift`

**Interfaces:**
- Consumes: nada
- Produces: `EpisodeMetric` sin referencias fuera de `Foundation`; `stillPath` se conserva

- [ ] **Step 1: Comprobar que nadie más lo usa**

```bash
grep -rn "stillURL" Plotline PlotlineTests --include="*.swift"
```
Expected: exactamente dos resultados — la definición en `EpisodeMetric.swift` y la aserción en `EpisodeMetricTests.swift`. Si aparece cualquier otro, **para y avísame**: significa que una vista lo usa y hay que mover la construcción de la URL a esa vista en vez de borrarla.

- [ ] **Step 2: Borrar la propiedad**

En `Plotline/Models/EpisodeMetric.swift`, borrar:

```swift
    /// URL for the episode still image.
    var stillURL: URL? {
        TMDBService.backdropURL(path: stillPath, size: .small)
    }
```

**Conservar `stillPath`**: sigue siendo dato del episodio y el dataset lo serializa. Lo que se va es la construcción de la URL, que es responsabilidad de la capa de presentación. Cuando la Fase 4 muestre imágenes de episodio, llamará a `TMDBService.backdropURL(path:size:)` desde la vista.

- [ ] **Step 3: Borrar su test**

En `PlotlineTests/EpisodeMetricTests.swift`, borrar el test `buildsStillURL` completo.

- [ ] **Step 4: Verificar la pureza**

```bash
grep -n "TMDBService\|NetworkManager\|DiskCache\|SwiftUI\|UIKit\|Charts" Plotline/Models/EpisodeMetric.swift
```
Expected: sin resultados.

```bash
grep -n "^import" Plotline/Models/EpisodeMetric.swift
```
Expected: solo `import Foundation`.

- [ ] **Step 5: Ejecutar la suite**

Run: `xcodebuild -project Plotline.xcodeproj -scheme Plotline -destination 'platform=iOS Simulator,name=iPhone 17' test 2>/dev/null`
Expected: `** TEST SUCCEEDED **`, **74** tests (75 menos el borrado).

- [ ] **Step 6: Commit**

```bash
git add Plotline/Models/EpisodeMetric.swift PlotlineTests/EpisodeMetricTests.swift
git commit -m "refactor: drop stillURL so EpisodeMetric depends only on Foundation

The dataset generator compiles this file directly, and the TMDBService
reference blocked that. No view used the property; URL construction
belongs to the presentation layer."
```

---

## Task 2: El paquete del generador, compartiendo el motor por symlink

**Files:**
- Create: `Tools/DatasetGenerator/Package.swift`
- Create: `Tools/DatasetGenerator/Sources/dataset-generator/main.swift`
- Create: symlinks en `Tools/DatasetGenerator/Sources/DatasetGeneratorCore/Shared/`
- Create: `Tools/DatasetGenerator/Tests/DatasetGeneratorTests/SharedEngineTests.swift`
- Create: `Tools/DatasetGenerator/.gitignore`

**Interfaces:**
- Consumes: `SeriesAnalysisEngine`, `SeriesAnalysis`, `EpisodeMetric` (compilados desde `Plotline/` vía symlink)
- Produces: la librería `DatasetGeneratorCore` (con los symlinks al motor) y el ejecutable `dataset-generator`

**El mecanismo, verificado antes de escribir esto.** Se probaron las dos opciones obvias contra un paquete real:

- **`path:` + `sources:` apuntando fuera del paquete NO funciona.** SwiftPM **ignora en silencio** los archivos cuya ruta escapa del directorio del paquete: compila sin error y el tipo simplemente no existe (`cannot find 'EpisodeMetric' in scope`, con la salida mostrando un único archivo compilado). Es un fallo mudo, del peor tipo.
- **Los symlinks SÍ funcionan.** Un enlace simbólico dentro de `Sources/` se compila con normalidad. La prueba falló únicamente en la línea de `stillURL` que referencia `TMDBService` — es decir, el archivo entró y se compiló, y el único obstáculo es la impureza que elimina la Tarea 1.

**Y la visibilidad decide el layout.** Los archivos compartidos son `internal` porque la app los compila en su propio target. Si el generador los pusiera en un módulo aparte, ningún otro módulo vería nada. Por eso van **en el mismo módulo** que el código del generador: un único target `DatasetGeneratorCore` que contiene los symlinks y las clases del generador. Así `internal` funciona en ambas direcciones y **no hay que añadir `public` a una sola línea del código de la app**.

El ejecutable sí es un target aparte, así que solo ve lo `public` de `DatasetGeneratorCore`. La consecuencia es deliberada: **toda la orquestación vive en la librería** y `main.swift` es una sola línea. Así el ejecutable nunca necesita tocar un tipo compartido.

- [ ] **Step 1: Escribir el manifiesto**

Crear `Tools/DatasetGenerator/Package.swift`:

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DatasetGenerator",
    platforms: [.macOS(.v13)],
    targets: [
        // One module holding both the generator's own code and symlinks to the
        // app's engine sources. Same module means `internal` works across both,
        // so sharing costs the app nothing — not one `public` keyword.
        .target(
            name: "DatasetGeneratorCore",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        // A one-line shell. Everything worth testing lives in the library,
        // because a test target cannot `@testable import` an executable whose
        // main.swift carries top-level code.
        .executableTarget(
            name: "dataset-generator",
            dependencies: ["DatasetGeneratorCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "DatasetGeneratorTests",
            dependencies: ["DatasetGeneratorCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
```

- [ ] **Step 1b: Crear los symlinks a las fuentes compartidas**

```bash
mkdir -p Tools/DatasetGenerator/Sources/DatasetGeneratorCore/Shared
cd Tools/DatasetGenerator/Sources/DatasetGeneratorCore/Shared
ln -s ../../../../../Plotline/Models/EpisodeMetric.swift EpisodeMetric.swift
ln -s ../../../../../Plotline/Models/SeriesAnalysis.swift SeriesAnalysis.swift
ln -s ../../../../../Plotline/Services/Analysis/SeriesAnalysisEngine.swift SeriesAnalysisEngine.swift
cd -
```

Verificar que son enlaces y no copias, que es todo el punto:

```bash
ls -l Tools/DatasetGenerator/Sources/DatasetGeneratorCore/Shared/
```
Expected: tres entradas empezando por `l` y con `->` apuntando al archivo de la app. Si sale una `-` normal, se copió y hay que rehacerlo: una copia se desincroniza y anula la garantía de "una implementación, dos consumidores".

(`PlotlineDataset.swift` se enlaza en la Tarea 5, cuando exista.)

**Rutas de los archivos que siguen:**

- Librería: `Tools/DatasetGenerator/Sources/DatasetGeneratorCore/`
- Ejecutable: `Tools/DatasetGenerator/Sources/dataset-generator/main.swift`
- Tests: `Tools/DatasetGenerator/Tests/DatasetGeneratorTests/`

**Visibilidad:** dentro de `DatasetGeneratorCore` todo puede quedarse `internal`, incluidos los tipos compartidos — están en el mismo módulo. Lo único que necesita `public` es el punto de entrada que llama el ejecutable (`Generator.run()` en la Tarea 5). Los tests usan `@testable import DatasetGeneratorCore` y lo ven todo. **Nunca añadas `public` a los archivos de la app**: si algo no compila por visibilidad, la lógica va a la librería y el ejecutable solo la invoca.

- [ ] **Step 2: Escribir el punto de entrada**

Crear `Tools/DatasetGenerator/Sources/dataset-generator/main.swift`:

El ejecutable es un módulo aparte y solo ve lo `public` de la librería, así que ni siquiera este arranque provisional puede tocar el motor directamente. Añade primero el saludo a la librería, en `Tools/DatasetGenerator/Sources/DatasetGeneratorCore/Generator.swift`:

```swift
import Foundation

public enum Generator {
    /// Replaced by the real pipeline in Task 5. For now it only proves the
    /// executable can reach the library and the library can reach the engine.
    public static func run() async throws {
        print("dataset-generator: shared engine linked, \(SeriesAnalysisEngine.minimumVotesPerEpisode) vote floor")
    }
}
```

Y `Tools/DatasetGenerator/Sources/dataset-generator/main.swift`:

```swift
import DatasetGeneratorCore

// Run with: TMDB_API_KEY=... swift run --package-path Tools/DatasetGenerator dataset-generator
// This tool is never part of the app build. It is run by hand when preparing a
// release, and its output is committed as Plotline/Resources/PlotlineDataset.json.

try await Generator.run()
```

- [ ] **Step 3: Escribir el test que prueba que el motor compartido de verdad funciona fuera de la app**

Crear `Tools/DatasetGenerator/Tests/DatasetGeneratorTests/SharedEngineTests.swift`:

```swift
import Foundation
import Testing
@testable import DatasetGeneratorCore

@Suite("Shared engine")
struct SharedEngineTests {
    /// The point of this test is not the analysis — the app's own suite covers
    /// that exhaustively. It is that the engine links and runs from outside the
    /// app target at all, which is the whole premise of sharing by path.
    @Test("the app's analysis engine runs inside the generator package")
    func engineRunsOutsideTheApp() {
        let episodes = (1...6).map { number in
            EpisodeMetric(
                episodeNumber: number,
                seasonNumber: 1,
                title: "S1E\(number)",
                rating: 8.0 + Double(number) * 0.1,
                voteCount: 100,
                airDate: "2010-01-01"
            )
        }

        let reference = Date(timeIntervalSince1970: 1_577_836_800) // 2020-01-01 UTC
        let result = SeriesAnalysisEngine.analyze(episodes: episodes, asOf: reference)

        guard case .analyzed(let analysis) = result else {
            Issue.record("expected .analyzed, got \(result)")
            return
        }
        #expect(analysis.seasons.count == 1)
        #expect(analysis.score.value > 0)
    }
}
```

- [ ] **Step 4: Ignorar los artefactos de build**

Crear `Tools/DatasetGenerator/.gitignore`:

```
.build/
.swiftpm/
```

- [ ] **Step 5: Compilar y ejecutar los tests del paquete**

Run: `swift test --package-path Tools/DatasetGenerator`
Expected: compila y el test pasa.

Si falla por una referencia a `TMDBService`, `NetworkManager` o `DiskCache` en alguno de los tres archivos compartidos, **no añadas esos tipos al paquete**: saca la referencia del archivo compartido, como hizo la Tarea 1 con `stillURL`. El aislamiento del motor es un requisito, no un accidente.

- [ ] **Step 6: Ejecutar la suite de la app**

Run: `xcodebuild -project Plotline.xcodeproj -scheme Plotline -destination 'platform=iOS Simulator,name=iPhone 17' test 2>/dev/null`
Expected: `** TEST SUCCEEDED **`, 74 tests. El paquete vive fuera de `Plotline/`, así que no debe afectar al build de la app.

- [ ] **Step 7: Commit**

```bash
git add Tools/DatasetGenerator
git commit -m "feat: add dataset generator package sharing the engine by path

The generator target compiles the app's own engine sources rather than a
copy, so the bundled dataset can never be produced by a different
implementation than the one that runs on device."
```

---

## Task 3: Cliente de TMDB y lista semilla

**Files:**
- Create: `Tools/DatasetGenerator/Sources/DatasetGeneratorCore/TMDBClient.swift`
- Create: `Tools/DatasetGenerator/Sources/DatasetGeneratorCore/SeedList.swift`
- Create: `Tools/DatasetGenerator/Tests/DatasetGeneratorTests/TMDBClientTests.swift`

**Interfaces:**
- Consumes: `EpisodeMetric` del target compartido
- Produces:
  - `TMDBClient(apiKey:)` con `func seriesDetails(id: Int) async throws -> TMDBSeriesDetails` y `func episodes(seriesId: Int, seasonCount: Int) async throws -> [EpisodeMetric]`
  - `struct TMDBSeriesDetails { let id: Int; let name: String; let seasonCount: Int; let hasEnded: Bool; let posterPath: String? }`
  - `SeedList.seriesIds: [Int]`

**Nota de diseño:** el generador decodifica la respuesta de temporada con sus propios tipos en vez de compartir `TMDBSeasonResponse.swift`, porque ese archivo vive en `Models/APIResponses/` junto a tipos que sí dependen de la app. Compartir solo lo que es puro mantiene la frontera nítida.

- [ ] **Step 1: Escribir los tests que fallan**

Crear `Tools/DatasetGenerator/Tests/DatasetGeneratorTests/TMDBClientTests.swift`:

```swift
import Foundation
import Testing
@testable import DatasetGeneratorCore

@Suite("TMDB decoding")
struct TMDBClientTests {
    private let seasonJSON = """
    {
      "id": 3572,
      "season_number": 1,
      "episodes": [
        {"id": 62085, "name": "Pilot", "episode_number": 1, "season_number": 1,
         "air_date": "2008-01-20", "still_path": "/a.jpg", "vote_average": 8.9, "vote_count": 412},
        {"id": 62086, "name": "", "episode_number": 2, "season_number": 1,
         "air_date": null, "still_path": null, "vote_average": 0.0, "vote_count": 0}
      ]
    }
    """

    private let detailsJSON = """
    {"id": 1396, "name": "Breaking Bad", "number_of_seasons": 5,
     "status": "Ended", "poster_path": "/p.jpg"}
    """

    @Test("maps a season payload onto EpisodeMetric")
    func decodesSeason() throws {
        let episodes = try TMDBClient.decodeSeason(Data(seasonJSON.utf8))
        #expect(episodes.count == 2)
        #expect(episodes[0].id == 62085)
        #expect(episodes[0].rating == 8.9)
        #expect(episodes[0].voteCount == 412)
        #expect(episodes[0].title == "Pilot")
    }

    @Test("falls back to an episode code when TMDB returns an empty name")
    func fallsBackToEpisodeCode() throws {
        let episodes = try TMDBClient.decodeSeason(Data(seasonJSON.utf8))
        #expect(episodes[1].title == "Episode 2")
    }

    @Test("reads the season count and the ended flag from series details")
    func decodesDetails() throws {
        let details = try TMDBClient.decodeDetails(Data(detailsJSON.utf8))
        #expect(details.id == 1396)
        #expect(details.name == "Breaking Bad")
        #expect(details.seasonCount == 5)
        #expect(details.hasEnded)
    }

    @Test("treats a returning series as not ended")
    func detectsReturningSeries() throws {
        let json = #"{"id": 1, "name": "X", "number_of_seasons": 2, "status": "Returning Series", "poster_path": null}"#
        #expect(try TMDBClient.decodeDetails(Data(json.utf8)).hasEnded == false)
    }

    @Test("the seed list is non-empty and free of duplicates")
    func seedListIsSane() {
        #expect(SeedList.seriesIds.count >= 20)
        #expect(Set(SeedList.seriesIds).count == SeedList.seriesIds.count)
    }
}
```

- [ ] **Step 2: Ejecutar para verificar que falla**

Run: `swift test --package-path Tools/DatasetGenerator`
Expected: FAIL de compilación, `cannot find 'TMDBClient' in scope`.

- [ ] **Step 3: Escribir el cliente**

Crear `Tools/DatasetGenerator/Sources/DatasetGeneratorCore/TMDBClient.swift`:

```swift
import Foundation

struct TMDBSeriesDetails {
    let id: Int
    let name: String
    let seasonCount: Int
    /// TMDB's series-level status, reduced to the one bit the analysis engine
    /// needs. Anything other than a terminal status counts as not ended, so an
    /// ending verdict is never claimed about a show still in production.
    let hasEnded: Bool
    let posterPath: String?
}

enum TMDBClientError: Error {
    case badStatus(Int)
    case missingAPIKey
}

struct TMDBClient {
    private let apiKey: String
    private let session: URLSession
    private let baseURL = "https://api.themoviedb.org/3"

    init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    // MARK: - Requests

    func seriesDetails(id: Int) async throws -> TMDBSeriesDetails {
        let data = try await get("/tv/\(id)")
        return try Self.decodeDetails(data)
    }

    /// Fetches every season in sequence. Deliberately serial: this runs once per
    /// release against a couple of hundred series, so staying well under TMDB's
    /// rate limit matters more than wall-clock time.
    func episodes(seriesId: Int, seasonCount: Int) async throws -> [EpisodeMetric] {
        var all: [EpisodeMetric] = []
        guard seasonCount > 0 else { return all }

        for season in 1...seasonCount {
            let data = try await get("/tv/\(seriesId)/season/\(season)")
            all.append(contentsOf: try Self.decodeSeason(data))
            try await Task.sleep(nanoseconds: 120_000_000)
        }
        return all
    }

    private func get(_ path: String) async throws -> Data {
        var components = URLComponents(string: baseURL + path)!
        components.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "language", value: "en-US")
        ]

        let (data, response) = try await session.data(from: components.url!)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw TMDBClientError.badStatus((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        return data
    }

    // MARK: - Decoding

    static func decodeDetails(_ data: Data) throws -> TMDBSeriesDetails {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let raw = try decoder.decode(RawDetails.self, from: data)

        // TMDB uses "Ended" and "Canceled" for finished runs; everything else
        // ("Returning Series", "In Production", "Planned") means still going.
        let terminal: Set<String> = ["Ended", "Canceled", "Cancelled"]

        return TMDBSeriesDetails(
            id: raw.id,
            name: raw.name,
            seasonCount: raw.numberOfSeasons ?? 0,
            hasEnded: terminal.contains(raw.status ?? ""),
            posterPath: raw.posterPath
        )
    }

    static func decodeSeason(_ data: Data) throws -> [EpisodeMetric] {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let raw = try decoder.decode(RawSeason.self, from: data)

        return raw.episodes.map { episode in
            let name = episode.name?.trimmingCharacters(in: .whitespaces) ?? ""
            return EpisodeMetric(
                id: episode.id,
                episodeNumber: episode.episodeNumber,
                seasonNumber: episode.seasonNumber,
                title: name.isEmpty ? "Episode \(episode.episodeNumber)" : name,
                rating: episode.voteAverage,
                voteCount: episode.voteCount,
                airDate: episode.airDate,
                stillPath: episode.stillPath
            )
        }
    }

    private struct RawDetails: Decodable {
        let id: Int
        let name: String
        let numberOfSeasons: Int?
        let status: String?
        let posterPath: String?
    }

    private struct RawSeason: Decodable {
        let episodes: [RawEpisode]
    }

    private struct RawEpisode: Decodable {
        let id: Int
        let name: String?
        let episodeNumber: Int
        let seasonNumber: Int
        let airDate: String?
        let stillPath: String?
        let voteAverage: Double
        let voteCount: Int
    }
}
```

- [ ] **Step 4: Escribir la lista semilla**

**Desviación consciente del spec.** El spec §6 pide 150-200 series. Este plan arranca con **24**, deliberadamente: primero se prueba la tubería entera contra datos reales, y escalar la lista después es cambiar un array. Empezar por 200 significaría descubrir un fallo del generador tras mil peticiones a TMDB.

Pero 24 series repartidas en cinco listas es **poco contenido**, y "poca cantidad de contenido" es literalmente el rechazo que esta obra entera intenta revertir. Así que escalar no es opcional: cuando la Tarea 5 demuestre que el dataset sale bien, hay que subir la semilla hacia el rango del spec antes de la Fase 4. Queda anotado en la definición de terminado.

Crear `Tools/DatasetGenerator/Sources/DatasetGeneratorCore/SeedList.swift`. Empezar con estos 24 IDs de TMDB, elegidos para cubrir las formas que el análisis debe saber describir — series que se mantienen, que decaen, que remontan y que cierran en lo alto:

```swift
import Foundation

/// TMDB series ids baked into the dataset.
///
/// Chosen to span the shapes the analysis exists to describe, not merely the
/// most popular shows: runs that hold their level, runs that fall off, runs
/// that start slow and climb, and runs that land their finale.
enum SeedList {
    static let seriesIds: [Int] = [
        1396,   // Breaking Bad
        1398,   // The Sopranos
        1622,   // Supernatural
        1408,   // House
        1668,   // Friends
        1418,   // The Big Bang Theory
        60059,  // Better Call Saul
        1399,   // Game of Thrones
        66732,  // Stranger Things
        63174,  // Lucifer
        1438,   // The Wire
        4614,   // NCIS
        456,    // The Simpsons
        2316,   // The Office
        31917,  // Pretty Little Liars
        62286,  // Fear the Walking Dead
        1402,   // The Walking Dead
        71712,  // The Good Doctor
        60625,  // Rick and Morty
        82856,  // The Mandalorian
        87108,  // Chernobyl
        76479,  // The Boys
        94605,  // Arcane
        85271   // WandaVision
    ]
}
```

- [ ] **Step 5: Ejecutar los tests del paquete**

Run: `swift test --package-path Tools/DatasetGenerator`
Expected: pasan los 5 tests nuevos más el de la Tarea 2.

- [ ] **Step 6: Comprobar contra la API real, una vez**

```bash
TMDB_API_KEY=$(plutil -extract TMDB_API_KEY raw Plotline/Secrets.plist) \
  swift run --package-path Tools/DatasetGenerator dataset-generator
```

Todavía no descarga nada — solo confirma que el ejecutable arranca y enlaza el motor. La descarga real llega en la Tarea 5.

- [ ] **Step 7: Commit**

```bash
git add Tools/DatasetGenerator
git commit -m "feat: add TMDB client and seed list to the dataset generator"
```

---

## Task 4: Premios desde Wikidata

**Files:**
- Create: `Tools/DatasetGenerator/Sources/DatasetGeneratorCore/WikidataClient.swift`
- Create: `Tools/DatasetGenerator/Tests/DatasetGeneratorTests/WikidataClientTests.swift`

**Interfaces:**
- Consumes: nada del motor
- Produces: `WikidataClient` con `func awards(forSeriesIds: [Int]) async throws -> [Int: [String]]` y `static func decodeAwards(_ data: Data) throws -> [Int: [String]]`

**Hechos verificados** (contra el endpoint real, antes de escribir esto):

- `P4983` es el ID de serie de TMDB en Wikidata; `wdt:P4983 "1396"` resuelve a Breaking Bad.
- `P166` es "award received". Breaking Bad devuelve 12, incluyendo Emmy a Mejor Drama, Globo de Oro y Peabody.
- El endpoint **exige un `User-Agent` identificable**. Sin él responde 403.
- **No enumerar QIDs de premios.** Un intento previo consultando por un QID adivinado devolvió cero filas. Se consulta por ID de TMDB y se recoge lo que haya.

- [ ] **Step 1: Escribir los tests que fallan**

Crear `Tools/DatasetGenerator/Tests/DatasetGeneratorTests/WikidataClientTests.swift`:

```swift
import Foundation
import Testing
@testable import DatasetGeneratorCore

@Suite("Wikidata awards")
struct WikidataClientTests {
    /// Shape of a real SPARQL JSON response, trimmed.
    private let responseJSON = """
    {
      "head": { "vars": ["tmdbId", "awardLabel"] },
      "results": { "bindings": [
        {"tmdbId": {"type": "literal", "value": "1396"},
         "awardLabel": {"type": "literal", "value": "Primetime Emmy Award for Outstanding Drama Series"}},
        {"tmdbId": {"type": "literal", "value": "1396"},
         "awardLabel": {"type": "literal", "value": "Peabody Awards"}},
        {"tmdbId": {"type": "literal", "value": "1399"},
         "awardLabel": {"type": "literal", "value": "Primetime Emmy Award for Outstanding Drama Series"}}
      ]}
    }
    """

    @Test("groups awards by TMDB id")
    func groupsByTMDBId() throws {
        let awards = try WikidataClient.decodeAwards(Data(responseJSON.utf8))
        #expect(awards[1396]?.count == 2)
        #expect(awards[1399] == ["Primetime Emmy Award for Outstanding Drama Series"])
    }

    @Test("sorts each title's awards so the dataset is reproducible")
    func sortsAwards() throws {
        let awards = try WikidataClient.decodeAwards(Data(responseJSON.utf8))
        #expect(awards[1396] == ["Peabody Awards", "Primetime Emmy Award for Outstanding Drama Series"])
    }

    @Test("ignores rows whose TMDB id is not a number")
    func ignoresNonNumericIds() throws {
        let json = """
        {"head": {"vars": []}, "results": {"bindings": [
          {"tmdbId": {"type": "literal", "value": "not-a-number"},
           "awardLabel": {"type": "literal", "value": "Some Award"}}
        ]}}
        """
        #expect(try WikidataClient.decodeAwards(Data(json.utf8)).isEmpty)
    }

    @Test("an empty result set decodes to an empty map rather than throwing")
    func handlesEmptyResults() throws {
        let json = #"{"head": {"vars": []}, "results": {"bindings": []}}"#
        #expect(try WikidataClient.decodeAwards(Data(json.utf8)).isEmpty)
    }

    @Test("builds a query naming every requested id")
    func buildsQuery() {
        let query = WikidataClient.awardsQuery(forSeriesIds: [1396, 1399])
        #expect(query.contains("\"1396\""))
        #expect(query.contains("\"1399\""))
        #expect(query.contains("P4983"))
        #expect(query.contains("P166"))
    }
}
```

- [ ] **Step 2: Ejecutar para verificar que falla**

Run: `swift test --package-path Tools/DatasetGenerator`
Expected: FAIL de compilación, `cannot find 'WikidataClient' in scope`.

- [ ] **Step 3: Escribir el cliente**

Crear `Tools/DatasetGenerator/Sources/DatasetGeneratorCore/WikidataClient.swift`:

```swift
import Foundation

enum WikidataError: Error {
    case badStatus(Int)
}

/// Fetches awards from Wikidata's SPARQL endpoint.
///
/// Wikidata is queried **by TMDB id**, never by award identifier. An earlier
/// attempt that enumerated award QIDs returned nothing because the guessed QID
/// was wrong — and guessing was never necessary, since the generator already
/// starts from a list of TMDB ids. Asking "what did this show win?" is both
/// correct and simpler than asking "who won this award?".
struct WikidataClient {
    private let session: URLSession
    private let endpoint = "https://query.wikidata.org/sparql"

    /// Wikidata rejects anonymous traffic with 403. A contactable agent string
    /// is a hard requirement, not politeness.
    private let userAgent = "PlotlineDatasetGenerator/1.0 (https://github.com/jaimebg/Plotline)"

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// - Returns: TMDB series id → sorted award names. Titles with no awards are absent.
    func awards(forSeriesIds ids: [Int]) async throws -> [Int: [String]] {
        guard !ids.isEmpty else { return [:] }

        var components = URLComponents(string: endpoint)!
        components.queryItems = [URLQueryItem(name: "query", value: Self.awardsQuery(forSeriesIds: ids))]

        var request = URLRequest(url: components.url!)
        request.setValue("application/sparql-results+json", forHTTPHeaderField: "Accept")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw WikidataError.badStatus((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        return try Self.decodeAwards(data)
    }

    static func awardsQuery(forSeriesIds ids: [Int]) -> String {
        let values = ids.map { "\"\($0)\"" }.joined(separator: " ")
        return """
        SELECT ?tmdbId ?awardLabel WHERE {
          VALUES ?tmdbId { \(values) }
          ?show wdt:P4983 ?tmdbId .
          ?show wdt:P166 ?award .
          SERVICE wikibase:label { bd:serviceParam wikibase:language "en". }
        }
        """
    }

    static func decodeAwards(_ data: Data) throws -> [Int: [String]] {
        let response = try JSONDecoder().decode(SPARQLResponse.self, from: data)

        var grouped: [Int: Set<String>] = [:]
        for binding in response.results.bindings {
            guard let id = Int(binding.tmdbId.value) else { continue }
            grouped[id, default: []].insert(binding.awardLabel.value)
        }

        // Sorted so regenerating the dataset from unchanged data produces an
        // identical file, which keeps release diffs readable.
        return grouped.mapValues { $0.sorted() }
    }

    private struct SPARQLResponse: Decodable {
        let results: Results

        struct Results: Decodable {
            let bindings: [Binding]
        }

        struct Binding: Decodable {
            let tmdbId: Value
            let awardLabel: Value
        }

        struct Value: Decodable {
            let value: String
        }
    }
}
```

- [ ] **Step 4: Ejecutar los tests del paquete**

Run: `swift test --package-path Tools/DatasetGenerator`
Expected: pasan los 5 nuevos más los anteriores.

- [ ] **Step 5: Comprobar contra Wikidata de verdad**

```bash
curl -s -H 'User-Agent: PlotlineDatasetGenerator/1.0 (https://github.com/jaimebg/Plotline)' \
  -H 'Accept: application/sparql-results+json' --get 'https://query.wikidata.org/sparql' \
  --data-urlencode 'query=SELECT ?tmdbId ?awardLabel WHERE { VALUES ?tmdbId { "1396" } ?show wdt:P4983 ?tmdbId . ?show wdt:P166 ?award . SERVICE wikibase:label { bd:serviceParam wikibase:language "en". } }' \
  | head -c 400
```
Expected: JSON con premios de Breaking Bad. Si sale 403, falta el `User-Agent`. Anota en el informe cuántos premios devuelve.

- [ ] **Step 6: Commit**

```bash
git add Tools/DatasetGenerator
git commit -m "feat: fetch awards from Wikidata by TMDB id"
```

---

## Task 5: Ensamblar y emitir el dataset

**Files:**
- Create: `Plotline/Models/PlotlineDataset.swift`
- Create: `Tools/DatasetGenerator/Sources/DatasetGeneratorCore/DatasetBuilder.swift`
- Create: `Tools/DatasetGenerator/Tests/DatasetGeneratorTests/DatasetBuilderTests.swift`
- Create: symlink `Tools/DatasetGenerator/Sources/DatasetGeneratorCore/Shared/PlotlineDataset.swift`
- Modify: `Tools/DatasetGenerator/Sources/dataset-generator/main.swift`

**Interfaces:**
- Consumes: `TMDBClient`, `WikidataClient`, `SeriesAnalysisEngine`
- Produces: `PlotlineDataset`, `DatasetEntry`, `CuratedList`, y `DatasetBuilder.build(entries:)`

**Por qué `PlotlineDataset.swift` vive en `Plotline/Models/`:** es el contrato entre el generador y la app. Enlazarlo por symlink, igual que el motor, garantiza que la Fase 4 no pueda leer una forma distinta de la que se escribió.

- [ ] **Step 1: Escribir los tests que fallan**

Crear `Tools/DatasetGenerator/Tests/DatasetGeneratorTests/DatasetBuilderTests.swift`:

```swift
import Foundation
import Testing
@testable import DatasetGeneratorCore

@Suite("Dataset builder")
struct DatasetBuilderTests {
    private func entry(
        id: Int,
        name: String,
        ratings: [[Double]],
        awards: [String] = []
    ) -> DatasetEntry? {
        var episodes: [EpisodeMetric] = []
        for (index, season) in ratings.enumerated() {
            for (number, rating) in season.enumerated() {
                episodes.append(
                    EpisodeMetric(
                        episodeNumber: number + 1,
                        seasonNumber: index + 1,
                        title: "S\(index + 1)E\(number + 1)",
                        rating: rating,
                        voteCount: 100,
                        airDate: "2010-01-01"
                    )
                )
            }
        }

        let reference = Date(timeIntervalSince1970: 1_577_836_800)
        guard case .analyzed(let analysis) = SeriesAnalysisEngine.analyze(
            episodes: episodes, hasEnded: true, asOf: reference
        ) else { return nil }

        return DatasetEntry(
            tmdbId: id,
            name: name,
            posterPath: nil,
            analysis: analysis,
            awards: awards
        )
    }

    @Test("collects series that never decline")
    func buildsNeverDeclineList() throws {
        let steady = try #require(entry(id: 1, name: "Steady", ratings: [[8.5, 8.6, 8.4, 8.5], [8.5, 8.6, 8.5, 8.6], [8.6, 8.5, 8.6, 8.5]]))
        let faller = try #require(entry(id: 2, name: "Faller", ratings: [[8.8, 8.9, 8.7, 8.8], [8.9, 8.8, 8.9, 8.8], [7.2, 7.1, 7.3, 7.2], [7.0, 7.1, 6.9, 7.0]]))

        let dataset = DatasetBuilder.build(entries: [steady, faller])
        let list = try #require(dataset.lists.first { $0.id == "never-decline" })
        #expect(list.tmdbIds == [1])
    }

    @Test("collects series that fall off")
    func buildsFallsOffList() throws {
        let steady = try #require(entry(id: 1, name: "Steady", ratings: [[8.5, 8.6, 8.4, 8.5], [8.5, 8.6, 8.5, 8.6], [8.6, 8.5, 8.6, 8.5]]))
        let faller = try #require(entry(id: 2, name: "Faller", ratings: [[8.8, 8.9, 8.7, 8.8], [8.9, 8.8, 8.9, 8.8], [7.2, 7.1, 7.3, 7.2], [7.0, 7.1, 6.9, 7.0]]))

        let dataset = DatasetBuilder.build(entries: [steady, faller])
        let list = try #require(dataset.lists.first { $0.id == "falls-off" })
        #expect(list.tmdbIds == [2])
    }

    @Test("every curated list carries a title and is never emitted empty")
    func listsAreWellFormed() throws {
        let steady = try #require(entry(id: 1, name: "Steady", ratings: [[8.5, 8.6, 8.4, 8.5], [8.5, 8.6, 8.5, 8.6], [8.6, 8.5, 8.6, 8.5]]))
        let dataset = DatasetBuilder.build(entries: [steady])

        for list in dataset.lists {
            #expect(!list.title.isEmpty)
            #expect(!list.tmdbIds.isEmpty)
        }
    }

    @Test("entries come back sorted by id so regeneration is reproducible")
    func sortsEntries() throws {
        let a = try #require(entry(id: 9, name: "Nine", ratings: [[8.5, 8.6, 8.4, 8.5]]))
        let b = try #require(entry(id: 2, name: "Two", ratings: [[8.5, 8.6, 8.4, 8.5]]))

        #expect(DatasetBuilder.build(entries: [a, b]).entries.map(\.tmdbId) == [2, 9])
    }

    @Test("the dataset round-trips through Codable")
    func roundTrips() throws {
        let steady = try #require(entry(id: 1, name: "Steady", ratings: [[8.5, 8.6, 8.4, 8.5]], awards: ["Peabody Awards"]))
        let dataset = DatasetBuilder.build(entries: [steady])

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(dataset)
        let decoded = try JSONDecoder().decode(PlotlineDataset.self, from: data)

        #expect(decoded == dataset)
        #expect(decoded.entries[0].awards == ["Peabody Awards"])
    }
}
```

- [ ] **Step 2: Ejecutar para verificar que falla**

Run: `swift test --package-path Tools/DatasetGenerator`
Expected: FAIL de compilación, `cannot find 'DatasetEntry' in scope`.

- [ ] **Step 3: Escribir el tipo del dataset**

Crear `Plotline/Models/PlotlineDataset.swift`:

```swift
import Foundation

/// The contract between the dataset generator and the app.
///
/// Shared by path with the generator, exactly like the analysis engine, so the
/// file the tool writes and the file the app reads can never drift apart.
///
/// The bundled dataset is a **seed and a fallback, never the truth**: when the
/// network is available, freshly fetched data wins. That keeps the app useful
/// offline and on first launch without ever asserting something stale.
struct PlotlineDataset: Codable, Hashable {
    /// Bumped when the shape changes, so the app can refuse a file it cannot read.
    let version: Int
    let entries: [DatasetEntry]
    let lists: [CuratedList]

    static let currentVersion = 1
}

struct DatasetEntry: Codable, Hashable, Identifiable {
    var id: Int { tmdbId }

    let tmdbId: Int
    let name: String
    let posterPath: String?
    let analysis: SeriesAnalysis
    /// Award names as Wikidata labels them. Empty when the title has none.
    let awards: [String]
}

/// A list derived from the analysis, not hand-written. Regenerating the dataset
/// regenerates the lists, so they cannot go stale against the data behind them.
struct CuratedList: Codable, Hashable, Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let tmdbIds: [Int]
}
```

- [ ] **Step 4: Añadirlo a las fuentes compartidas**

Enlazar el nuevo archivo junto a los otros tres:

```bash
cd Tools/DatasetGenerator/Sources/DatasetGeneratorCore/Shared
ln -s ../../../../../Plotline/Models/PlotlineDataset.swift PlotlineDataset.swift
cd -
ls -l Tools/DatasetGenerator/Sources/DatasetGeneratorCore/Shared/
```

Expected: cuatro symlinks. El manifiesto no cambia — SwiftPM recoge todo lo que hay bajo `Sources/DatasetGeneratorCore/`.

- [ ] **Step 5: Escribir el ensamblador**

Crear `Tools/DatasetGenerator/Sources/DatasetGeneratorCore/DatasetBuilder.swift`:

```swift
import Foundation

/// Turns analysed entries into the file the app ships.
enum DatasetBuilder {
    static func build(entries: [DatasetEntry]) -> PlotlineDataset {
        let sorted = entries.sorted { $0.tmdbId < $1.tmdbId }

        return PlotlineDataset(
            version: PlotlineDataset.currentVersion,
            entries: sorted,
            lists: curatedLists(from: sorted)
        )
    }

    /// Every list is a query over the analysis. Nothing here is hand-picked,
    /// which is the point: the lists are Plotline's own reading of the data, and
    /// they are exactly as defensible as the engine that produced them.
    static func curatedLists(from entries: [DatasetEntry]) -> [CuratedList] {
        let candidates: [(id: String, title: String, subtitle: String, match: (DatasetEntry) -> Bool)] = [
            (
                "never-decline",
                "Series que nunca decaen",
                "Mantienen el nivel de principio a fin",
                { $0.analysis.declinePoint == nil && $0.analysis.consistency.rating != .rollercoaster }
            ),
            (
                "falls-off",
                "Las que se hunden",
                "Empiezan fuerte y no aguantan",
                { $0.analysis.declinePoint != nil }
            ),
            (
                "slow-burn",
                "Remontadas",
                "Arrancan flojas y mejoran mucho",
                { $0.analysis.openingVerdict?.kind == .slowStart }
            ),
            (
                "perfect-ending",
                "Cierres perfectos",
                "Terminan en su mejor momento",
                { $0.analysis.endingVerdict?.kind == .endsStrong }
            ),
            (
                "rollercoaster",
                "Montañas rusas",
                "Episodios brillantes junto a otros olvidables",
                { $0.analysis.consistency.rating == .rollercoaster }
            )
        ]

        return candidates.compactMap { candidate in
            let ids = entries.filter(candidate.match).map(\.tmdbId)
            // An empty list on a shelf is exactly the emptiness this whole
            // project is trying to remove from the app, so never emit one.
            guard !ids.isEmpty else { return nil }

            return CuratedList(
                id: candidate.id,
                title: candidate.title,
                subtitle: candidate.subtitle,
                tmdbIds: ids
            )
        }
    }
}
```

- [ ] **Step 6: Escribir la orquestación en la librería**

La lógica va en `DatasetGeneratorCore`, no en el ejecutable: el ejecutable es un módulo aparte y solo ve lo `public`, así que si orquestara él tendría que tocar tipos compartidos que son `internal`.

Crear `Tools/DatasetGenerator/Sources/DatasetGeneratorCore/Generator.swift`:

```swift
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

        print("Fetching awards for \(SeedList.seriesIds.count) series…")
        let awardsById = (try? await wikidata.awards(forSeriesIds: SeedList.seriesIds)) ?? [:]
        print("  \(awardsById.count) series carry at least one award")

        var entries: [DatasetEntry] = []

        for seriesId in SeedList.seriesIds {
            do {
                let details = try await tmdb.seriesDetails(id: seriesId)
                let episodes = try await tmdb.episodes(seriesId: seriesId, seasonCount: details.seasonCount)

                guard case .analyzed(let analysis) = SeriesAnalysisEngine.analyze(
                    episodes: episodes,
                    hasEnded: details.hasEnded
                ) else {
                    print("  skipped \(details.name) (\(seriesId)): insufficient data")
                    continue
                }

                entries.append(
                    DatasetEntry(
                        tmdbId: seriesId,
                        name: details.name,
                        posterPath: details.posterPath,
                        analysis: analysis,
                        awards: awardsById[seriesId] ?? []
                    )
                )
                print("  \(details.name): score \(analysis.score.value), \(analysis.seasons.count) seasons")
            } catch {
                print("  failed \(seriesId): \(error)")
            }
        }

        let dataset = DatasetBuilder.build(entries: entries)

        let encoder = JSONEncoder()
        // Sorted keys and pretty printing keep the committed file's diffs
        // readable across regenerations.
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]

        let output = URL(fileURLWithPath: "Plotline/Resources/PlotlineDataset.json")
        try FileManager.default.createDirectory(
            at: output.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try encoder.encode(dataset).write(to: output)

        print("\nWrote \(entries.count) entries and \(dataset.lists.count) lists to \(output.path)")
    }
}
```

Reemplazar `Tools/DatasetGenerator/Sources/dataset-generator/main.swift` por su forma final, una línea:

```swift
import DatasetGeneratorCore

// Run with:
//   TMDB_API_KEY=... swift run --package-path Tools/DatasetGenerator dataset-generator
//
// Writes Plotline/Resources/PlotlineDataset.json. Never part of the app build;
// run by hand when preparing a release.

try await Generator.run()
```

**El ejecutable se lanza desde la raíz del repo**, porque la ruta de salida es relativa. Si prefieres que no lo sea, pásala por argumento — pero entonces documenta el valor por defecto.

- [ ] **Step 7: Ejecutar los tests del paquete**

Run: `swift test --package-path Tools/DatasetGenerator`
Expected: pasan los 5 nuevos más los anteriores.

- [ ] **Step 8: Generar el dataset de verdad**

```bash
TMDB_API_KEY=$(plutil -extract TMDB_API_KEY raw Plotline/Secrets.plist) \
  swift run --package-path Tools/DatasetGenerator dataset-generator
```

Expected: descarga las 24 series y escribe `Plotline/Resources/PlotlineDataset.json`. Tarda unos minutos por el retardo deliberado entre temporadas.

Comprobar el resultado y **anotar todo esto en el informe**:

```bash
ls -lh Plotline/Resources/PlotlineDataset.json
python3 -c "
import json
d = json.load(open('Plotline/Resources/PlotlineDataset.json'))
print('version:', d['version'])
print('entries:', len(d['entries']))
print('with awards:', sum(1 for e in d['entries'] if e['awards']))
for l in d['lists']:
    print(f\"  {l['id']}: {len(l['tmdbIds'])}\")
"
```

**Criterios de aceptación, y si alguno falla dilo en vez de maquillarlo:**
- Al menos 18 de las 24 series producen entrada. Si se saltan muchas por `insufficientData`, informa de cuáles y por qué — puede indicar que los umbrales del motor son demasiado estrictos con datos reales, que es justo lo que el spec dijo que habría que calibrar.
- Al menos 3 listas curadas no vacías.
- El archivo pesa menos de 5 MB.
- Al menos la mitad de las entradas traen algún premio.

- [ ] **Step 9: Verificar reproducibilidad**

Ejecutar el generador una segunda vez y comprobar que el archivo no cambia:

```bash
cp Plotline/Resources/PlotlineDataset.json /tmp/dataset-first.json
TMDB_API_KEY=$(plutil -extract TMDB_API_KEY raw Plotline/Secrets.plist) \
  swift run --package-path Tools/DatasetGenerator dataset-generator
diff <(python3 -m json.tool /tmp/dataset-first.json) <(python3 -m json.tool Plotline/Resources/PlotlineDataset.json) && echo "REPRODUCIBLE"
```

Si difiere, la causa más probable es que TMDB haya actualizado algún `vote_average` entre ejecuciones, lo cual es legítimo. Distínguelo de un orden no determinista: si cambian *claves* o el *orden* de los arrays, es un bug del generador y hay que arreglarlo. Si solo cambian valores numéricos de rating, no lo es.

- [ ] **Step 10: Ejecutar la suite de la app**

Run: `xcodebuild -project Plotline.xcodeproj -scheme Plotline -destination 'platform=iOS Simulator,name=iPhone 17' test 2>/dev/null`
Expected: `** TEST SUCCEEDED **`, 74 tests. `PlotlineDataset.swift` entra en el target de la app automáticamente, así que debe compilar sin usarse todavía.

- [ ] **Step 11: Commit**

```bash
git add Tools/DatasetGenerator Plotline/Models/PlotlineDataset.swift Plotline/Resources/PlotlineDataset.json
git commit -m "feat: generate the bundled dataset with analysis and awards

The generator runs the app's own engine over a seed list of series and
bakes the result, plus Wikidata awards, into a JSON the app ships. The
curated lists are queries over the analysis rather than hand-picked, so
they cannot go stale against the data behind them.

The app does not read the file yet; Phase 4 wires it in."
```

---

## Definición de terminado

- [ ] `swift test --package-path Tools/DatasetGenerator` pasa
- [ ] La suite de la app pasa con 74 tests
- [ ] `Plotline/Resources/PlotlineDataset.json` existe, con ≥18 entradas y ≥3 listas
- [ ] Anotado explícitamente que la lista semilla debe escalar de 24 hacia las 150-200 del spec antes de la Fase 4, con el resultado de la primera pasada como evidencia de que la tubería aguanta
- [ ] El generador compila **los mismos archivos** del motor que la app, no copias
- [ ] `EpisodeMetric`, `SeriesAnalysis`, `SeriesAnalysisEngine` y `PlotlineDataset` importan solo `Foundation`
- [ ] `Plotline.xcodeproj/project.pbxproj` sin tocar
- [ ] Ninguna clave de API en ningún commit

## Notas para la Fase 4

- El dataset es **semilla y fallback, nunca verdad**. Con red, los datos frescos de TMDB ganan. Es lo que evita que la app afirme cosas obsoletas sobre series en emisión.
- `PlotlineDataset.version` existe para que la app rechace un archivo con forma que no entiende en vez de romperse.
- Los residuos de la Fase 2 (`docs/superpowers/specs/2026-08-03-phase-2-residuals.md`) incluyen dos que afectan a la presentación: `isOngoing == false` es ambiguo y no debe renderizarse como "Finalizada", y `bestSeason` puede coincidir con `worstSeason`.
