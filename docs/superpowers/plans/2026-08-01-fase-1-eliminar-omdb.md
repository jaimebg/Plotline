# Fase 1 — Eliminar OMDb y migrar episodios a TMDB

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminar por completo la dependencia de OMDb, pasando los ratings de episodios a TMDB y dejando la capa de datos lista para el motor de análisis de la Fase 2.

**Architecture:** `EpisodeMetric` deja de guardar el rating como `String` de IMDb y pasa a guardar `Double` + `voteCount` + `airDate`, que es lo que la Fase 2 necesita para ponderar por fiabilidad. `TMDBService` gana los métodos de temporada usando `/tv/{id}/season/{n}`, con caché en disco y concurrencia acotada. La caché genérica que hoy vive dentro de `OMDbService.swift` se extrae a `DiskCache` antes de borrar nada.

**Tech Stack:** Swift 6, SwiftUI, Swift Testing, iOS 26, TMDB API v3.

**Spec:** `docs/superpowers/specs/2026-08-01-app-store-4.2-design.md` (§3 y §4)

## Global Constraints

- `IPHONEOS_DEPLOYMENT_TARGET = 26.0`. No usar APIs deprecadas ni por debajo de ese suelo.
- Estado con `@Observable` (iOS 17+), nunca `@ObservableObject`.
- Nunca `.white` para texto: usar `.primary` / `.secondary`. Nunca fondos oscuros hardcodeados: usar `Color.plotlineBackground` / `Color.plotlineCard`.
- Todo cambio debe funcionar en modo claro y oscuro.
- Commits en formato Conventional Commits, en inglés.
- Tests con **Swift Testing** (`import Testing`, `@Test`, `#expect`), no XCTest.
- El proyecto debe compilar y arrancar al final de **cada** tarea.

**Comando de build de referencia** (usar tras cada tarea):

```bash
xcodebuild -project Plotline.xcodeproj -scheme Plotline \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath build build
```

**Comando de tests** (disponible a partir de la Tarea 1):

```bash
xcodebuild -project Plotline.xcodeproj -scheme Plotline \
  -destination 'platform=iOS Simulator,name=iPhone 17' test
```

## ⚠️ Aviso de release

Al terminar esta fase la ficha de detalle **pierde las notas de IMDb, Rotten Tomatoes y Metacritic, y los premios**, y todavía no tiene la compensación (motor de análisis y dataset llegan en Fases 2 y 3). **No enviar a App Store entre la Fase 1 y la Fase 3.**

---

## Estructura de archivos

| Archivo | Responsabilidad | Acción |
|---|---|---|
| `Plotline/Services/DiskCache.swift` | Caché genérica en disco con expiración | Crear (extraído de `OMDbService.swift`) |
| `Plotline/Models/EpisodeMetric.swift` | Modelo de episodio para gráfico y análisis | Modificar (nueva forma) |
| `Plotline/Models/APIResponses/TMDBSeasonResponse.swift` | Decodificación de `/tv/{id}/season/{n}` | Crear |
| `Plotline/Services/TMDBService.swift` | Añadir endpoints de temporada | Modificar |
| `Plotline/ViewModels/MediaDetailViewModel.swift` | Origen de episodios y limpieza de OMDb | Modificar |
| `Plotline/ViewModels/CompareViewModel.swift` | Origen de episodios y limpieza de ratings | Modificar |
| `Plotline/Views/Detail/ScorecardsView.swift` | Solo nota TMDB | Modificar |
| `Plotline/Views/Detail/RatingCard.swift` | Conservar `TMDBRatingCard`, borrar `RatingCard` | Modificar |
| `Plotline/Views/Stats/CompareView.swift` | Quitar fila de ratings externos | Modificar |
| `Plotline/Models/MediaItem.swift` | Quitar `imdbId`, `imdbURL`, `awards`, `externalRatings` | Modificar |
| `Plotline/Models/APIResponses/TMDBResponse.swift` | Quitar `ExternalIds` | Modificar |
| `Plotline/Models/AwardsData.swift` | Quitar el parser de OMDb, conservar el struct | Modificar |
| `Plotline/Services/OMDbService.swift` | — | **Borrar** |
| `Plotline/Models/APIResponses/OMDbResponse.swift` | — | **Borrar** |
| `Plotline/Models/RatingSource.swift` | — | **Borrar** |
| `PlotlineTests/` | Target de tests | Crear |

---

## Task 1: Crear el target de tests

Hoy el proyecto **no tiene ningún target de tests** (`xcodebuild -list` solo muestra `Plotline`). Sin él no se puede aplicar TDD en el resto del plan, así que esta tarea es prerrequisito de todas las demás.

**Files:**
- Create: `PlotlineTests/PlotlineTests.swift`
- Modify: `Plotline.xcodeproj` (nuevo target, vía Xcode)

**Interfaces:**
- Consumes: nada
- Produces: target `PlotlineTests` con `@testable import Plotline`, ejecutable con `xcodebuild ... test`

- [ ] **Step 1: Crear el target en Xcode**

El pbxproj no debe editarse a mano. En Xcode:

1. `open Plotline.xcodeproj`
2. File → New → Target…
3. iOS → **Unit Testing Bundle**
4. Product Name: `PlotlineTests`
5. Testing System: **Swift Testing with XCTest UI Tests**
6. Target to be Tested: `Plotline`
7. Finish

- [ ] **Step 2: Borrar el esquema huérfano de widgets**

Los widgets se eliminaron en el commit `36356f7` pero el esquema sigue ahí y `xcodebuild -list` lo sigue mostrando. En Xcode: Product → Scheme → Manage Schemes… → seleccionar `PlotlineWidgetsExtension` → botón `−` → Close.

- [ ] **Step 3: Escribir un test de humo**

Reemplazar el contenido de `PlotlineTests/PlotlineTests.swift`:

```swift
import Testing
@testable import Plotline

@Suite("Smoke")
struct SmokeTests {
    @Test("the test target can see the app module")
    func canImportAppModule() {
        let metric = EpisodeMetric.preview
        #expect(metric.seasonNumber == 1)
    }
}
```

- [ ] **Step 4: Ejecutar los tests**

Run: `xcodebuild -project Plotline.xcodeproj -scheme Plotline -destination 'platform=iOS Simulator,name=iPhone 17' test`
Expected: PASS, 1 test ejecutado.

- [ ] **Step 5: Commit**

```bash
git add Plotline.xcodeproj PlotlineTests
git commit -m "chore: add unit test target and remove orphan widget scheme"
```

---

## Task 2: Extraer DiskCache de OMDbService

`OMDbService.swift` contiene en las líneas 162-234 un `actor OMDbCache` que es una caché genérica sin nada específico de OMDb, más un `struct CacheEntry` privado. Si se borra el archivo sin extraerlo primero, se pierde. Se extrae ahora, con el nombre de directorio parametrizado para que los tests queden aislados.

**Files:**
- Create: `Plotline/Services/DiskCache.swift`
- Create: `PlotlineTests/DiskCacheTests.swift`
- Modify: `Plotline/Services/OMDbService.swift:13` y `:162-234`

**Interfaces:**
- Consumes: nada
- Produces: `actor DiskCache` con `static let shared`, `init(name:maxAge:)`, `func get<T: Decodable>(for key: String) -> T?`, `func set<T: Encodable>(_ value: T, for key: String)`, `func clearAll()`

- [ ] **Step 1: Escribir los tests que fallan**

Crear `PlotlineTests/DiskCacheTests.swift`:

```swift
import Foundation
import Testing
@testable import Plotline

@Suite("DiskCache")
struct DiskCacheTests {
    /// Cada test usa su propio directorio para no pisarse con los demás.
    private func makeCache(maxAge: TimeInterval = 7 * 24 * 3600) -> DiskCache {
        DiskCache(name: "tests-\(UUID().uuidString)", maxAge: maxAge)
    }

    @Test("stores and retrieves a value")
    func roundTrip() async {
        let cache = makeCache()
        await cache.set([1, 2, 3], for: "numbers")
        let result: [Int]? = await cache.get(for: "numbers")
        #expect(result == [1, 2, 3])
    }

    @Test("returns nil for a key that was never written")
    func missingKey() async {
        let cache = makeCache()
        let result: [Int]? = await cache.get(for: "absent")
        #expect(result == nil)
    }

    @Test("returns nil once the entry is older than maxAge")
    func expiredEntry() async {
        // maxAge negativo: cualquier entrada está expirada en el instante siguiente.
        let cache = makeCache(maxAge: -1)
        await cache.set([1], for: "numbers")
        let result: [Int]? = await cache.get(for: "numbers")
        #expect(result == nil)
    }

    @Test("clearAll removes every entry")
    func clearAllEmptiesCache() async {
        let cache = makeCache()
        await cache.set([1], for: "a")
        await cache.set([2], for: "b")
        await cache.clearAll()
        let a: [Int]? = await cache.get(for: "a")
        let b: [Int]? = await cache.get(for: "b")
        #expect(a == nil)
        #expect(b == nil)
    }

    @Test("keys with unsafe filesystem characters are handled")
    func sanitizesKeys() async {
        let cache = makeCache()
        await cache.set(["ok"], for: "v2/tmdb 1396:S1")
        let result: [String]? = await cache.get(for: "v2/tmdb 1396:S1")
        #expect(result == ["ok"])
    }
}
```

- [ ] **Step 2: Ejecutar para verificar que falla**

Run: `xcodebuild -project Plotline.xcodeproj -scheme Plotline -destination 'platform=iOS Simulator,name=iPhone 17' test`
Expected: FAIL de compilación, `cannot find 'DiskCache' in scope`.

- [ ] **Step 3: Crear DiskCache**

Crear `Plotline/Services/DiskCache.swift`:

```swift
import Foundation

/// Actor-based persistent cache using FileManager.
/// Stores JSON files in Caches/<name>/ with a configurable expiration.
actor DiskCache {
    static let shared = DiskCache(name: "plotline")

    private let cacheDir: URL
    private let maxAge: TimeInterval
    private var memoryCache: [String: Data] = [:]

    init(name: String, maxAge: TimeInterval = 7 * 24 * 3600) {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.cacheDir = caches.appendingPathComponent(name, isDirectory: true)
        self.maxAge = maxAge
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }

    func get<T: Decodable>(for key: String) -> T? {
        let safeKey = sanitizedKey(key)

        if let data = memoryCache[safeKey] {
            return try? JSONDecoder().decode(T.self, from: data)
        }

        let fileURL = fileURL(for: safeKey)
        guard let wrapper = try? Data(contentsOf: fileURL),
              let entry = try? JSONDecoder().decode(CacheEntry.self, from: wrapper) else {
            return nil
        }

        guard Date().timeIntervalSince(entry.timestamp) < maxAge else {
            try? FileManager.default.removeItem(at: fileURL)
            return nil
        }

        memoryCache[safeKey] = entry.data
        return try? JSONDecoder().decode(T.self, from: entry.data)
    }

    func set<T: Encodable>(_ value: T, for key: String) {
        let safeKey = sanitizedKey(key)
        guard let data = try? JSONEncoder().encode(value) else { return }

        memoryCache[safeKey] = data

        let entry = CacheEntry(data: data, timestamp: Date())
        guard let wrapper = try? JSONEncoder().encode(entry) else { return }
        try? wrapper.write(to: fileURL(for: safeKey))
    }

    func clearAll() {
        memoryCache.removeAll()
        let files = (try? FileManager.default.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: nil)) ?? []
        for file in files {
            try? FileManager.default.removeItem(at: file)
        }
    }

    // MARK: - Private Helpers

    private func sanitizedKey(_ key: String) -> String {
        key.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? key
    }

    private func fileURL(for safeKey: String) -> URL {
        cacheDir.appendingPathComponent(safeKey)
    }
}

private struct CacheEntry: Codable {
    let data: Data
    let timestamp: Date
}
```

- [ ] **Step 4: Borrar el código extraído de OMDbService y repuntar la referencia**

En `Plotline/Services/OMDbService.swift`, borrar todo desde el comentario `// MARK: - OMDb Disk Cache` (línea 162) hasta el final del archivo, es decir el `actor OMDbCache` y el `struct CacheEntry`. Después, en la línea 13, cambiar:

```swift
    private let cache = OMDbCache.shared
```

por:

```swift
    private let cache = DiskCache.shared
```

`OMDbService` se borrará entero en la Tarea 7; este cambio solo mantiene el build verde mientras tanto.

- [ ] **Step 5: Ejecutar los tests**

Run: `xcodebuild -project Plotline.xcodeproj -scheme Plotline -destination 'platform=iOS Simulator,name=iPhone 17' test`
Expected: PASS, 5 tests de `DiskCache` + el de humo.

- [ ] **Step 6: Commit**

```bash
git add Plotline/Services/DiskCache.swift Plotline/Services/OMDbService.swift PlotlineTests/DiskCacheTests.swift
git commit -m "refactor: extract generic DiskCache out of OMDbService"
```

---

## Task 3: Remodelar EpisodeMetric para datos de TMDB

`EpisodeMetric` guarda hoy `imdbRating: String` e `imdbId: String?`. La Fase 2 necesita el rating como `Double` y, sobre todo, el **`voteCount`** para poder ponderar por fiabilidad, más `airDate` para excluir episodios no emitidos.

El cambio está muy contenido: `EpisodeMetric(...)` solo se construye en un sitio fuera del modelo (`OMDbResponse.swift:104`), y las vistas solo tocan `imdbURL` en dos líneas. Todo lo demás usa propiedades computadas que se conservan.

**Files:**
- Modify: `Plotline/Models/EpisodeMetric.swift` (archivo completo)
- Modify: `Plotline/Models/APIResponses/OMDbResponse.swift:104`
- Modify: `Plotline/Views/Detail/EpisodeRatingsGridView.swift:156`
- Modify: `Plotline/Views/Detail/SeriesGraphView.swift:234`
- Create: `PlotlineTests/EpisodeMetricTests.swift`

**Interfaces:**
- Consumes: nada
- Produces: `EpisodeMetric(id:episodeNumber:seasonNumber:title:rating:voteCount:airDate:stillPath:)`, con propiedades `rating: Double`, `voteCount: Int`, `airDate: String?`, `stillPath: String?` y computadas `formattedRating`, `shortCode`, `fullCode`, `hasValidRating`, `hasAired`, `stillURL`

- [ ] **Step 1: Escribir los tests que fallan**

Crear `PlotlineTests/EpisodeMetricTests.swift`:

```swift
import Foundation
import Testing
@testable import Plotline

@Suite("EpisodeMetric")
struct EpisodeMetricTests {
    private func make(
        rating: Double = 8.5,
        voteCount: Int = 100,
        airDate: String? = "2008-01-20",
        episodeNumber: Int = 5,
        seasonNumber: Int = 1
    ) -> EpisodeMetric {
        EpisodeMetric(
            episodeNumber: episodeNumber,
            seasonNumber: seasonNumber,
            title: "Gray Matter",
            rating: rating,
            voteCount: voteCount,
            airDate: airDate,
            stillPath: "/still.jpg"
        )
    }

    @Test("formats the rating to one decimal")
    func formatsRating() {
        #expect(make(rating: 8.46).formattedRating == "8.5")
    }

    @Test("shows a dash when there is no rating")
    func formatsMissingRating() {
        #expect(make(rating: 0, voteCount: 0).formattedRating == "—")
    }

    @Test("builds the short and full episode codes")
    func buildsCodes() {
        let episode = make(episodeNumber: 5, seasonNumber: 1)
        #expect(episode.shortCode == "S1E5")
        #expect(episode.fullCode == "Season 1, Episode 5")
    }

    @Test("a rating is valid only with a positive score and at least one vote")
    func validatesRating() {
        #expect(make(rating: 8.5, voteCount: 100).hasValidRating)
        #expect(!make(rating: 0, voteCount: 100).hasValidRating)
        #expect(!make(rating: 8.5, voteCount: 0).hasValidRating)
    }

    @Test("an episode with a past air date has aired")
    func detectsAiredEpisode() {
        #expect(make(airDate: "1999-01-01").hasAired)
    }

    @Test("an episode with a future air date has not aired")
    func detectsUnairedEpisode() {
        #expect(!make(airDate: "2999-01-01").hasAired)
    }

    @Test("an episode without an air date is treated as not aired")
    func treatsMissingAirDateAsUnaired() {
        #expect(!make(airDate: nil).hasAired)
    }

    @Test("builds the still image URL from the path")
    func buildsStillURL() {
        #expect(make().stillURL?.absoluteString == "https://image.tmdb.org/t/p/w300/still.jpg")
    }

    @Test("round-trips through Codable")
    func encodesAndDecodes() throws {
        let original = make()
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(EpisodeMetric.self, from: data)
        #expect(decoded == original)
    }
}
```

- [ ] **Step 2: Ejecutar para verificar que falla**

Run: `xcodebuild -project Plotline.xcodeproj -scheme Plotline -destination 'platform=iOS Simulator,name=iPhone 17' test`
Expected: FAIL de compilación, el inicializador no acepta `rating:`/`voteCount:`.

- [ ] **Step 3: Reescribir EpisodeMetric**

Reemplazar el contenido completo de `Plotline/Models/EpisodeMetric.swift`:

```swift
import Foundation

/// Represents episode rating data for the SeriesGraph and the analysis engine.
///
/// Ratings come from TMDB's season endpoint. `voteCount` is kept because the
/// analysis engine weights episodes by how many votes back them up.
struct EpisodeMetric: Identifiable, Codable, Hashable {
    let id: UUID
    let episodeNumber: Int
    let seasonNumber: Int
    let title: String
    let rating: Double
    let voteCount: Int
    let airDate: String?
    let stillPath: String?

    // MARK: - Computed Properties

    /// Formatted rating string (e.g., "8.5"), or an em dash when unrated.
    var formattedRating: String {
        rating > 0 ? String(format: "%.1f", rating) : "—"
    }

    /// Display string for episode (e.g., "S1E5")
    var shortCode: String {
        "S\(seasonNumber)E\(episodeNumber)"
    }

    /// Full display string (e.g., "Season 1, Episode 5")
    var fullCode: String {
        "Season \(seasonNumber), Episode \(episodeNumber)"
    }

    /// A rating only counts when it is positive and backed by at least one vote.
    var hasValidRating: Bool {
        rating > 0 && voteCount > 0
    }

    /// Whether the episode has already aired. Episodes without an air date are
    /// treated as unaired so they never reach the analysis engine.
    var hasAired: Bool {
        guard let airDate, let date = Self.airDateFormatter.date(from: airDate) else {
            return false
        }
        return date <= Date()
    }

    /// URL for the episode still image.
    var stillURL: URL? {
        TMDBService.backdropURL(path: stillPath, size: .small)
    }

    // MARK: - Initializers

    init(
        id: UUID = UUID(),
        episodeNumber: Int,
        seasonNumber: Int,
        title: String,
        rating: Double,
        voteCount: Int,
        airDate: String? = nil,
        stillPath: String? = nil
    ) {
        self.id = id
        self.episodeNumber = episodeNumber
        self.seasonNumber = seasonNumber
        self.title = title
        self.rating = rating
        self.voteCount = voteCount
        self.airDate = airDate
        self.stillPath = stillPath
    }

    // MARK: - Private

    private static let airDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}

// MARK: - Preview Data

extension EpisodeMetric {
    static let preview = EpisodeMetric(
        episodeNumber: 1,
        seasonNumber: 1,
        title: "Pilot",
        rating: 8.9,
        voteCount: 412,
        airDate: "2008-01-20"
    )

    /// Sample data for Breaking Bad Season 1
    static let breakingBadS1: [EpisodeMetric] = [
        EpisodeMetric(episodeNumber: 1, seasonNumber: 1, title: "Pilot", rating: 9.0, voteCount: 412, airDate: "2008-01-20"),
        EpisodeMetric(episodeNumber: 2, seasonNumber: 1, title: "Cat's in the Bag...", rating: 8.5, voteCount: 305, airDate: "2008-01-27"),
        EpisodeMetric(episodeNumber: 3, seasonNumber: 1, title: "...And the Bag's in the River", rating: 8.7, voteCount: 291, airDate: "2008-02-10"),
        EpisodeMetric(episodeNumber: 4, seasonNumber: 1, title: "Cancer Man", rating: 8.2, voteCount: 274, airDate: "2008-02-17"),
        EpisodeMetric(episodeNumber: 5, seasonNumber: 1, title: "Gray Matter", rating: 8.3, voteCount: 268, airDate: "2008-02-24"),
        EpisodeMetric(episodeNumber: 6, seasonNumber: 1, title: "Crazy Handful of Nothin'", rating: 9.2, voteCount: 289, airDate: "2008-03-02"),
        EpisodeMetric(episodeNumber: 7, seasonNumber: 1, title: "A No-Rough-Stuff-Type Deal", rating: 8.8, voteCount: 271, airDate: "2008-03-09")
    ]

    /// Sample data for Breaking Bad Season 5
    static let breakingBadS5: [EpisodeMetric] = [
        EpisodeMetric(episodeNumber: 1, seasonNumber: 5, title: "Live Free or Die", rating: 9.1, voteCount: 251, airDate: "2012-07-15"),
        EpisodeMetric(episodeNumber: 2, seasonNumber: 5, title: "Madrigal", rating: 8.7, voteCount: 233, airDate: "2012-07-22"),
        EpisodeMetric(episodeNumber: 3, seasonNumber: 5, title: "Hazard Pay", rating: 8.8, voteCount: 228, airDate: "2012-07-29"),
        EpisodeMetric(episodeNumber: 4, seasonNumber: 5, title: "Fifty-One", rating: 8.8, voteCount: 224, airDate: "2012-08-05"),
        EpisodeMetric(episodeNumber: 5, seasonNumber: 5, title: "Dead Freight", rating: 9.7, voteCount: 246, airDate: "2012-08-12"),
        EpisodeMetric(episodeNumber: 6, seasonNumber: 5, title: "Buyout", rating: 9.1, voteCount: 221, airDate: "2012-08-19"),
        EpisodeMetric(episodeNumber: 7, seasonNumber: 5, title: "Say My Name", rating: 9.4, voteCount: 239, airDate: "2012-08-26"),
        EpisodeMetric(episodeNumber: 8, seasonNumber: 5, title: "Gliding Over All", rating: 9.6, voteCount: 244, airDate: "2012-09-02"),
        EpisodeMetric(episodeNumber: 9, seasonNumber: 5, title: "Blood Money", rating: 9.3, voteCount: 258, airDate: "2013-08-11"),
        EpisodeMetric(episodeNumber: 10, seasonNumber: 5, title: "Buried", rating: 9.2, voteCount: 241, airDate: "2013-08-18"),
        EpisodeMetric(episodeNumber: 11, seasonNumber: 5, title: "Confessions", rating: 9.5, voteCount: 249, airDate: "2013-08-25"),
        EpisodeMetric(episodeNumber: 12, seasonNumber: 5, title: "Rabid Dog", rating: 9.0, voteCount: 236, airDate: "2013-09-01"),
        EpisodeMetric(episodeNumber: 13, seasonNumber: 5, title: "To'hajiilee", rating: 9.8, voteCount: 279, airDate: "2013-09-08"),
        EpisodeMetric(episodeNumber: 14, seasonNumber: 5, title: "Ozymandias", rating: 10.0, voteCount: 412, airDate: "2013-09-15"),
        EpisodeMetric(episodeNumber: 15, seasonNumber: 5, title: "Granite State", rating: 9.6, voteCount: 268, airDate: "2013-09-22"),
        EpisodeMetric(episodeNumber: 16, seasonNumber: 5, title: "Felina", rating: 9.9, voteCount: 355, airDate: "2013-09-29")
    ]
}
```

- [ ] **Step 4: Arreglar el mapper de OMDb para mantener el build verde**

En `Plotline/Models/APIResponses/OMDbResponse.swift`, dentro de `toEpisodeMetrics()`, reemplazar la construcción de `EpisodeMetric` por:

```swift
            return EpisodeMetric(
                episodeNumber: episodeNumber,
                seasonNumber: seasonNum,
                title: episode.title,
                rating: Double(episode.imdbRating.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0,
                voteCount: 0,
                airDate: nil,
                stillPath: nil
            )
```

OMDb no expone número de votos, así que `voteCount: 0` hace que `hasValidRating` sea `false` para todos sus episodios. Es correcto: esta ruta solo tiene que compilar hasta que se borre en la Tarea 7.

- [ ] **Step 5: Quitar los dos usos de imdbURL en las vistas**

`imdbURL` ya no existe. En `Plotline/Views/Detail/EpisodeRatingsGridView.swift:156` y en `Plotline/Views/Detail/SeriesGraphView.swift:234`, eliminar el bloque `if let url = episode.imdbURL { ... }` completo, junto con el botón o `Link` que contenga y cualquier import o estado que quede sin uso.

- [ ] **Step 6: Ejecutar los tests**

Run: `xcodebuild -project Plotline.xcodeproj -scheme Plotline -destination 'platform=iOS Simulator,name=iPhone 17' test`
Expected: PASS, 9 tests de `EpisodeMetric` más los anteriores.

- [ ] **Step 7: Commit**

```bash
git add Plotline/Models/EpisodeMetric.swift Plotline/Models/APIResponses/OMDbResponse.swift Plotline/Views/Detail/EpisodeRatingsGridView.swift Plotline/Views/Detail/SeriesGraphView.swift PlotlineTests/EpisodeMetricTests.swift
git commit -m "refactor: reshape EpisodeMetric around TMDB rating and vote count"
```

---

## Task 4: Endpoints de temporada en TMDBService

**Files:**
- Create: `Plotline/Models/APIResponses/TMDBSeasonResponse.swift`
- Create: `PlotlineTests/TMDBSeasonResponseTests.swift`
- Modify: `Plotline/Services/TMDBService.swift` (añadir sección tras `// MARK: - Details`)

**Interfaces:**
- Consumes: `EpisodeMetric` (Tarea 3), `DiskCache` (Tarea 2)
- Produces:
  - `TMDBSeasonResponse` con `func toEpisodeMetrics() -> [EpisodeMetric]`
  - `TMDBService.fetchSeasonEpisodes(seriesId: Int, season: Int) async throws -> [EpisodeMetric]`
  - `TMDBService.fetchAllSeasons(seriesId: Int, totalSeasons: Int) async -> [Int: [EpisodeMetric]]`

**Nota sobre decodificación:** `NetworkManager` usa `keyDecodingStrategy = .convertFromSnakeCase` (ver `NetworkManager.swift:50`), así que `vote_average` llega como `voteAverage` sin necesidad de `CodingKeys`.

- [ ] **Step 1: Escribir los tests que fallan**

Crear `PlotlineTests/TMDBSeasonResponseTests.swift`:

```swift
import Foundation
import Testing
@testable import Plotline

@Suite("TMDBSeasonResponse")
struct TMDBSeasonResponseTests {
    /// Recorte real del endpoint /tv/{id}/season/{n}, con un episodio sin emitir
    /// y otro sin air_date para cubrir los casos límite.
    private let json = """
    {
      "id": 3572,
      "name": "Season 1",
      "season_number": 1,
      "episodes": [
        {
          "id": 62085,
          "name": "Pilot",
          "episode_number": 1,
          "season_number": 1,
          "air_date": "2008-01-20",
          "still_path": "/ydlY3iPfeOAvu8gVqrxPoMvzNCn.jpg",
          "vote_average": 8.9,
          "vote_count": 412,
          "overview": "Walter White is a chemistry teacher.",
          "runtime": 58
        },
        {
          "id": 62086,
          "name": "Cat's in the Bag...",
          "episode_number": 2,
          "season_number": 1,
          "air_date": "2999-01-27",
          "still_path": null,
          "vote_average": 0.0,
          "vote_count": 0,
          "overview": "",
          "runtime": 48
        },
        {
          "id": 62087,
          "name": "",
          "episode_number": 3,
          "season_number": 1,
          "air_date": null,
          "still_path": null,
          "vote_average": 0.0,
          "vote_count": 0,
          "overview": null,
          "runtime": null
        }
      ]
    }
    """

    private func decode() throws -> TMDBSeasonResponse {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(TMDBSeasonResponse.self, from: Data(json.utf8))
    }

    @Test("decodes the season payload")
    func decodesSeason() throws {
        let response = try decode()
        #expect(response.seasonNumber == 1)
        #expect(response.episodes.count == 3)
    }

    @Test("maps rating and vote count onto EpisodeMetric")
    func mapsRatingAndVotes() throws {
        let metrics = try decode().toEpisodeMetrics()
        #expect(metrics[0].rating == 8.9)
        #expect(metrics[0].voteCount == 412)
        #expect(metrics[0].title == "Pilot")
        #expect(metrics[0].hasValidRating)
    }

    @Test("keeps unaired episodes but marks them as unrated")
    func keepsUnairedEpisodes() throws {
        let metrics = try decode().toEpisodeMetrics()
        #expect(!metrics[1].hasAired)
        #expect(!metrics[1].hasValidRating)
    }

    @Test("falls back to the episode code when the title is missing")
    func fallsBackToEpisodeCode() throws {
        let metrics = try decode().toEpisodeMetrics()
        #expect(metrics[2].title == "Episode 3")
    }

    @Test("carries the season number from each episode")
    func carriesSeasonNumber() throws {
        let metrics = try decode().toEpisodeMetrics()
        #expect(metrics.allSatisfy { $0.seasonNumber == 1 })
    }
}
```

- [ ] **Step 2: Ejecutar para verificar que falla**

Run: `xcodebuild -project Plotline.xcodeproj -scheme Plotline -destination 'platform=iOS Simulator,name=iPhone 17' test`
Expected: FAIL de compilación, `cannot find 'TMDBSeasonResponse' in scope`.

- [ ] **Step 3: Crear el modelo de respuesta**

Crear `Plotline/Models/APIResponses/TMDBSeasonResponse.swift`:

```swift
import Foundation

/// Response for /tv/{series_id}/season/{season_number}
struct TMDBSeasonResponse: Codable {
    let id: Int
    let name: String?
    let seasonNumber: Int
    let episodes: [TMDBEpisode]

    /// Maps the payload onto the app's episode model.
    /// Unaired and unrated episodes are kept so the UI can show the full season;
    /// the analysis engine filters them out via `hasValidRating` / `hasAired`.
    func toEpisodeMetrics() -> [EpisodeMetric] {
        episodes.map { episode in
            EpisodeMetric(
                episodeNumber: episode.episodeNumber,
                seasonNumber: episode.seasonNumber,
                title: episode.displayTitle,
                rating: episode.voteAverage,
                voteCount: episode.voteCount,
                airDate: episode.airDate,
                stillPath: episode.stillPath
            )
        }
    }
}

struct TMDBEpisode: Codable {
    let id: Int
    let name: String?
    let episodeNumber: Int
    let seasonNumber: Int
    let airDate: String?
    let stillPath: String?
    let voteAverage: Double
    let voteCount: Int
    let overview: String?
    let runtime: Int?

    /// TMDB sometimes returns an empty name for unaired episodes.
    var displayTitle: String {
        guard let name, !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            return "Episode \(episodeNumber)"
        }
        return name
    }
}
```

- [ ] **Step 4: Ejecutar los tests de decodificación**

Run: `xcodebuild -project Plotline.xcodeproj -scheme Plotline -destination 'platform=iOS Simulator,name=iPhone 17' test`
Expected: PASS, 5 tests de `TMDBSeasonResponse`.

- [ ] **Step 5: Añadir los métodos a TMDBService**

En `Plotline/Services/TMDBService.swift`, insertar esta sección justo después del método `fetchDetails(for:)` (línea 126), antes de `// MARK: - Search`:

```swift
    // MARK: - Seasons

    /// Cache version for episode payloads. Bump to invalidate stored data.
    private static let episodeCacheVersion = "v1"

    /// Fetch episode metrics for a single season.
    /// Results are cached on disk because a long-running series burns a lot of
    /// requests against TMDB's ~40 requests / 10 seconds budget.
    func fetchSeasonEpisodes(seriesId: Int, season: Int) async throws -> [EpisodeMetric] {
        let cacheKey = "\(Self.episodeCacheVersion)_tmdb_\(seriesId)_S\(season)"
        if let cached: [EpisodeMetric] = await DiskCache.shared.get(for: cacheKey) {
            return cached
        }

        guard let url = buildURL(path: "/tv/\(seriesId)/season/\(season)") else {
            throw NetworkError.invalidURL
        }

        let response: TMDBSeasonResponse = try await networkManager.fetch(
            TMDBSeasonResponse.self,
            from: url
        )
        let episodes = response.toEpisodeMetrics()

        await DiskCache.shared.set(episodes, for: cacheKey)

        return episodes
    }

    /// Fetch every season of a series, keyed by season number.
    ///
    /// Season 0 (TMDB specials) is deliberately excluded: specials are not part
    /// of the main run and would distort the analysis engine.
    /// Concurrency is capped so a 20-season show cannot exhaust the rate limit
    /// in one burst. Seasons that fail are simply absent from the result.
    func fetchAllSeasons(
        seriesId: Int,
        totalSeasons: Int,
        maxConcurrent: Int = 5
    ) async -> [Int: [EpisodeMetric]] {
        guard totalSeasons > 0 else { return [:] }

        var result: [Int: [EpisodeMetric]] = [:]

        await withTaskGroup(of: (Int, [EpisodeMetric]).self) { group in
            var nextSeason = 1

            func addTask(for season: Int) {
                group.addTask {
                    let episodes = (try? await self.fetchSeasonEpisodes(
                        seriesId: seriesId,
                        season: season
                    )) ?? []
                    return (season, episodes)
                }
            }

            for _ in 0..<min(maxConcurrent, totalSeasons) {
                addTask(for: nextSeason)
                nextSeason += 1
            }

            while let (season, episodes) = await group.next() {
                if !episodes.isEmpty {
                    result[season] = episodes
                }
                if nextSeason <= totalSeasons {
                    addTask(for: nextSeason)
                    nextSeason += 1
                }
            }
        }

        return result
    }
```

Si el compilador de Swift 6 se queja de captura de `self` en el grupo de tareas, declarar `struct TMDBService: Sendable`. Todas sus propiedades son `let` de tipos `Sendable`, así que la conformidad es segura.

- [ ] **Step 6: Verificar que compila**

Run: `xcodebuild -project Plotline.xcodeproj -scheme Plotline -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath build build`
Expected: BUILD SUCCEEDED

- [ ] **Step 7: Commit**

```bash
git add Plotline/Models/APIResponses/TMDBSeasonResponse.swift Plotline/Services/TMDBService.swift PlotlineTests/TMDBSeasonResponseTests.swift
git commit -m "feat: fetch episode ratings from TMDB season endpoint"
```

---

## Task 5: Migrar MediaDetailViewModel a TMDB

**Files:**
- Modify: `Plotline/ViewModels/MediaDetailViewModel.swift`
- Modify: `Plotline/Views/Detail/MediaDetailView.swift:41-50`
- Modify: `Plotline/Views/Detail/ScorecardsView.swift`
- Modify: `Plotline/Views/Detail/RatingCard.swift`

**Interfaces:**
- Consumes: `TMDBService.fetchSeasonEpisodes(seriesId:season:)`, `TMDBService.fetchAllSeasons(seriesId:totalSeasons:)` (Tarea 4)
- Produces: `MediaDetailViewModel` sin `omdbService`, sin `ratings`, sin `awardsData`; `ScorecardsView(tmdbScore:mediaId:isTVSeries:)`

- [ ] **Step 1: Quitar el servicio y el estado de OMDb del ViewModel**

En `Plotline/ViewModels/MediaDetailViewModel.swift`:

1. Borrar la propiedad `var ratings: [RatingSource] = []` (línea 16), `var isLoadingRatings = false` (22) y `var ratingsError: String?` (25).
2. Borrar `var awardsData: AwardsData?` (43).
3. Borrar `private let omdbService: OMDbService` (55) y el parámetro `omdbService: OMDbService = .shared` del `init` (62), junto con `self.omdbService = omdbService` (66).
4. Borrar los métodos `fetchRatings()` (96-116) y `fetchOMDbDetailsForFeatures()` (365-378).
5. Borrar las propiedades computadas `hasRatings` (397-399), `imdbRating` (415-418), `rottenTomatoesRating` (420-423) y `metacriticRating` (425-428).

- [ ] **Step 2: Reescribir fetchEpisodes para TMDB**

Reemplazar el método `fetchEpisodes()` (líneas 118-143) por:

```swift
    /// Fetch episodes for current season (TV series only)
    @MainActor
    func fetchEpisodes() async {
        guard media.isTVSeries else { return }

        isLoadingEpisodes = true
        episodesError = nil

        do {
            episodes = try await tmdbService.fetchSeasonEpisodes(
                seriesId: media.id,
                season: selectedSeason
            )
        } catch {
            episodesError = (error as? NetworkError)?.errorDescription ?? "Couldn't load episodes. Pull to refresh."
            #if DEBUG
            debugPrint("Failed to fetch episodes: \(error)")
            #endif
        }

        isLoadingEpisodes = false
    }
```

- [ ] **Step 3: Reescribir fetchAllSeasons para TMDB**

Reemplazar el método `fetchAllSeasons()` (líneas 153-215) por:

```swift
    /// Fetch all seasons' episodes for the grid view
    @MainActor
    func fetchAllSeasons() async {
        guard media.isTVSeries else { return }

        isLoadingAllSeasons = true
        episodesError = nil

        episodesBySeason = await tmdbService.fetchAllSeasons(
            seriesId: media.id,
            totalSeasons: totalSeasons
        )

        isLoadingAllSeasons = false
    }
```

El conteo de temporadas ahora sale de `totalSeasons`, que `fetchTMDBDetails()` ya rellena desde `details.totalSeasons` (línea 253). Desaparece la llamada extra a OMDb que solo servía para contrastar el número de temporadas.

- [ ] **Step 4: Quitar las tareas de ratings de loadDetails y fetchMovieFeatures**

En `loadDetails()` (73-93), eliminar `async let ratingsTask: () = fetchRatings()` de ambas ramas y sacarla de las tuplas `await`:

```swift
    /// Load all detail data (TMDB details + movie features)
    @MainActor
    func loadDetails() async {
        // First, get TMDB details for season count and movie-specific data
        await fetchTMDBDetails()

        if media.isTVSeries {
            async let episodesTask: () = fetchEpisodesIfSeries()
            async let allSeasonsTask: () = fetchAllSeasons()
            async let recsTask: () = fetchRecommendations()
            _ = await (episodesTask, allSeasonsTask, recsTask)
        } else {
            async let movieFeaturesTask: () = fetchMovieFeatures()
            async let recsTask: () = fetchRecommendations()
            _ = await (movieFeaturesTask, recsTask)
        }
    }
```

En `fetchMovieFeatures()` (271-280), eliminar `async let omdbTask: () = fetchOMDbDetailsForFeatures()` y sacarla de la tupla:

```swift
    /// Fetch all movie-specific features
    @MainActor
    private func fetchMovieFeatures() async {
        guard !media.isTVSeries else { return }

        async let collectionTask: () = fetchCollectionIfAvailable()
        async let creditsTask: () = fetchCreditsAndFilmography()

        _ = await (collectionTask, creditsTask)
    }
```

- [ ] **Step 5: Actualizar hasAwards y shouldShowEpisodeGrid**

`hasAwards` (497-499) pasa a devolver `false` hasta que la Fase 3 traiga los premios del dataset:

```swift
    /// Awards return in Phase 3, sourced from the bundled dataset.
    var hasAwards: Bool { false }
```

`shouldShowEpisodeGrid` (408-413) ya no necesita el guardarraíl de los 100 episodios, que existía solo por el límite de OMDb:

```swift
    /// Check if episode grid should be shown
    var shouldShowEpisodeGrid: Bool {
        !episodesBySeason.isEmpty
    }
```

- [ ] **Step 6: Actualizar los previews del ViewModel**

En la extensión `MediaDetailViewModel` del final del archivo (523-577), borrar todas las líneas `vm.ratings = RatingSource.previewRatings` y `vm.awardsData = .oscarWinnerPreview`.

- [ ] **Step 7: Simplificar ScorecardsView**

En `Plotline/Views/Detail/ScorecardsView.swift`, reemplazar las líneas 1-119 por:

```swift
import SwiftUI

/// Horizontal row of rating scorecards
struct ScorecardsView: View {
    let tmdbScore: Double?
    let mediaId: Int
    let isTVSeries: Bool

    init(tmdbScore: Double? = nil, mediaId: Int = 0, isTVSeries: Bool = false) {
        self.tmdbScore = tmdbScore
        self.mediaId = mediaId
        self.isTVSeries = isTVSeries
    }

    private var hasAnyRating: Bool {
        (tmdbScore ?? 0) > 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ratings")
                .font(.system(.headline, weight: .semibold))
                .foregroundStyle(.primary)

            if hasAnyRating, let score = tmdbScore {
                TMDBRatingCard(score: score, mediaId: mediaId, isTVSeries: isTVSeries)
            } else {
                emptyView
            }
        }
    }

    // MARK: - Empty View

    private var emptyView: some View {
        HStack(spacing: 8) {
            Image(systemName: "chart.bar")
                .foregroundStyle(.secondary)

            Text("No ratings available")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.plotlineCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No ratings available")
    }
}
```

Borrar además `struct CompactScorecardsView` (líneas 123 en adelante) — solo se usaba en su propio preview — y cualquier `#Preview` del archivo que referencie `RatingSource`.

- [ ] **Step 8: Borrar RatingCard conservando TMDBRatingCard**

En `Plotline/Views/Detail/RatingCard.swift`, borrar `struct RatingCard` (línea 4 hasta justo antes de la 214) y conservar `struct TMDBRatingCard` (214 en adelante). Borrar también los `#Preview` que referencien `RatingSource`.

- [ ] **Step 9: Actualizar la llamada en MediaDetailView**

En `Plotline/Views/Detail/MediaDetailView.swift`, reemplazar las líneas 41-50 por:

```swift
                    ScorecardsView(
                        tmdbScore: viewModel.media.voteAverage,
                        mediaId: viewModel.media.id,
                        isTVSeries: viewModel.media.isTVSeries
                    )
```

- [ ] **Step 10: Compilar y verificar en el simulador**

Run:
```bash
xcodebuild -project Plotline.xcodeproj -scheme Plotline -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath build build && \
xcrun simctl install booted build/Build/Products/Debug-iphonesimulator/Plotline.app && \
xcrun simctl launch booted com.jbgsoft.Plotline
```
Expected: BUILD SUCCEEDED, la app arranca. Abrir una serie con varias temporadas (por ejemplo Breaking Bad) y comprobar que el gráfico de episodios y la rejilla se rellenan. Comprobar en modo claro y oscuro.

- [ ] **Step 11: Commit**

```bash
git add Plotline/ViewModels/MediaDetailViewModel.swift Plotline/Views/Detail/MediaDetailView.swift Plotline/Views/Detail/ScorecardsView.swift Plotline/Views/Detail/RatingCard.swift
git commit -m "refactor: source detail episodes from TMDB and drop OMDb ratings"
```

---

## Task 6: Migrar CompareViewModel

**Files:**
- Modify: `Plotline/ViewModels/CompareViewModel.swift`
- Modify: `Plotline/Views/Stats/CompareView.swift`

**Interfaces:**
- Consumes: `TMDBService.fetchSeasonEpisodes(seriesId:season:)` (Tarea 4)
- Produces: `CompareViewModel` sin `ratingsData` ni `allRatingSources`

- [ ] **Step 1: Sustituir el fetch de OMDb por TMDB**

En `Plotline/ViewModels/CompareViewModel.swift`, reemplazar el bloque de las líneas 93-113 (desde `// Fetch OMDb ratings if we have an IMDb ID` hasta el cierre de ese `if let imdbId`) por:

```swift
            // Episode metrics come from TMDB, keyed by the series' TMDB id.
            if detailed.isTVSeries, let totalSeasons = detailed.totalSeasons, totalSeasons > 0 {
                episodesData[detailed.id] = await TMDBService.shared.fetchAllSeasons(
                    seriesId: detailed.id,
                    totalSeasons: totalSeasons
                )
            }
```

Esto además arregla un problema que traía el código anterior: las temporadas se pedían en un bucle secuencial (`for season in 1...totalSeasons`), mientras que `fetchAllSeasons` las trae con concurrencia acotada y caché.

Nótese que `var detailed` deja de necesitar ser mutable, porque desaparece `detailed.externalRatings = ratings`. Cambiar la línea 88 a `let detailed = try await TMDBService.shared.fetchDetails(for: item)` y borrar la reasignación `slots[slotIndex] = detailed` de la línea 98.

- [ ] **Step 2: Borrar el estado y los helpers de ratings externos**

En el mismo archivo:

1. Borrar `var ratingsData: [Int: [RatingSource]] = [:]` (línea 9).
2. Borrar la propiedad computada `allRatingSources` completa (líneas 46-62).
3. En `removeSlot(_:)` (líneas 121-128), borrar `ratingsData.removeValue(forKey: item.id)`.
4. Simplificar `normalizedRating(for:item:)` y `displayRating(for:item:)`, que ahora solo tienen que resolver TMDB:

```swift
    /// Normalized rating value (0-100) for an item
    func normalizedRating(for item: MediaItem) -> Double? {
        item.voteAverage > 0 ? item.voteAverage * 10 : nil
    }

    /// Display value for an item's rating
    func displayRating(for item: MediaItem) -> String? {
        item.voteAverage > 0 ? item.formattedRating : nil
    }
```

- [ ] **Step 3: Actualizar CompareView**

En `Plotline/Views/Stats/CompareView.swift`:

1. Eliminar la fila comparativa que itera sobre `viewModel.allRatingSources` y su cabecera de sección de ratings externos.
2. Actualizar las llamadas a `normalizedRating(for:item:)` y `displayRating(for:item:)` a las nuevas firmas de un solo parámetro: `viewModel.normalizedRating(for: item)` y `viewModel.displayRating(for: item)`.
3. Conservar intacto el resto de la comparación: pósters, nota TMDB, géneros, año y la curva de episodios.

- [ ] **Step 4: Compilar y verificar en el simulador**

Run:
```bash
xcodebuild -project Plotline.xcodeproj -scheme Plotline -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath build build && \
xcrun simctl install booted build/Build/Products/Debug-iphonesimulator/Plotline.app && \
xcrun simctl launch booted com.jbgsoft.Plotline
```
Expected: BUILD SUCCEEDED. Ir a Stats → Compare, elegir dos series y comprobar que la comparación se rellena sin la fila de ratings externos. Comprobar en modo claro y oscuro.

- [ ] **Step 5: Commit**

```bash
git add Plotline/ViewModels/CompareViewModel.swift Plotline/Views/Stats/CompareView.swift
git commit -m "refactor: source compare episodes from TMDB"
```

---

## Task 7: Borrar OMDb del proyecto

Última tarea: a estas alturas nada llama ya a OMDb, así que el borrado es puramente mecánico.

**Files:**
- Delete: `Plotline/Services/OMDbService.swift`
- Delete: `Plotline/Models/APIResponses/OMDbResponse.swift`
- Delete: `Plotline/Models/RatingSource.swift`
- Modify: `Plotline/App/Secrets.swift:25-27`
- Modify: `Plotline/Secrets.plist`
- Modify: `Plotline/Models/MediaItem.swift`
- Modify: `Plotline/Models/AwardsData.swift`
- Modify: `CLAUDE.md`, `README.md`

**Interfaces:**
- Consumes: nada
- Produces: proyecto sin referencias a OMDb

- [ ] **Step 1: Borrar los archivos**

```bash
rm Plotline/Services/OMDbService.swift
rm Plotline/Models/APIResponses/OMDbResponse.swift
rm Plotline/Models/RatingSource.swift
```

- [ ] **Step 2: Quitar la clave de OMDb**

En `Plotline/App/Secrets.swift`, borrar las líneas 25-27:

```swift
    static var omdbAPIKey: String {
        plistSecrets["OMDB_API_KEY"] ?? environment["OMDB_API_KEY"] ?? ""
    }
```

Y borrar de `Plotline/Secrets.plist` la pareja `<key>OMDB_API_KEY</key>` con su `<string>`.

- [ ] **Step 3: Limpiar MediaItem**

En `Plotline/Models/MediaItem.swift`, borrar los tres campos que venían de OMDb — `awards: String?` (línea 37), `externalRatings` (el campo de tipo `[RatingSource]`) y `imdbId: String?` (línea 25) — junto con, para cada uno, su caso en `CodingKeys`, su línea de decodificación, su parámetro del `init` y su asignación. Borrar también la propiedad computada `imdbURL` (líneas 80-83) y actualizar el comentario de la línea 27 (`// Enriched data from OMDb (injected asynchronously)`).

**Sobre `imdbId`:** tras las tareas 5 y 6 queda completamente muerto. Su único consumidor restante era `MediaItem.imdbURL`, que no usa ninguna vista (`grep -rn "imdbURL"` solo devuelve el de `EpisodeMetric`, eliminado en la Tarea 3). Esto es el "quitar el puente `imdb_id`" del spec §3.

- [ ] **Step 3b: Quitar external_ids de las peticiones de detalle**

Con `imdbId` fuera, `append_to_response=external_ids` ya no aporta nada. En `Plotline/Services/TMDBService.swift`, en `fetchMovieDetails(id:)` (líneas 94-104) y `fetchSeriesDetails(id:)` (107-117), quitar el `additionalParams: ["append_to_response": "external_ids"]` dejando solo el path.

En `Plotline/Models/APIResponses/TMDBResponse.swift`, borrar `let externalIds: ExternalIds?` de `TMDBDetailResponse` (línea 36), el `struct ExternalIds` y la línea que pasa `imdbId` dentro de `toMediaItem(mediaType:)`.

En `Plotline/ViewModels/MediaDetailViewModel.swift`, dentro de `fetchTMDBDetails()`, borrar las líneas `details.imdbId = details.imdbId ?? media.imdbId` (228) y `media.imdbId = details.imdbId ?? media.imdbId` (236).

- [ ] **Step 4: Quitar el parser de premios de OMDb**

En `Plotline/Models/AwardsData.swift`, borrar el método `parse(from:)` que interpretaba el string de OMDb. **Conservar el `struct AwardsData` completo**: la Fase 3 lo rellenará desde el dataset del bundle.

- [ ] **Step 5: Verificar que no queda ninguna referencia**

```bash
grep -rn "omdb\|OMDb\|OMDB\|RatingSource\|imdbId\|externalIds" Plotline PlotlineTests --include="*.swift" --include="*.plist"
```
Expected: sin resultados.

- [ ] **Step 6: Actualizar la documentación**

En `CLAUDE.md`:
- Cambiar `**Target:** iOS 18+, iPhone, SwiftUI` por `**Target:** iOS 26+, iPhone, SwiftUI` (el proyecto tiene `IPHONEOS_DEPLOYMENT_TARGET = 26.0`).
- Sustituir toda la sección `### Dual API Strategy (Chained Fetching)` por una descripción de TMDB como fuente única, con el flujo `User action → TMDB fetch → Render`.
- En **Services Layer**, borrar la línea de `OMDbService` y añadir `DiskCache`.
- En **Models**, borrar la línea de `RatingSource` y actualizar la de `EpisodeMetric`.
- En **API Keys**, borrar todo lo relativo a `OMDB_API_KEY`.
- En **SeriesGraph Feature**, indicar que los ratings por episodio vienen de `vote_average` de TMDB.

En `README.md`:
- Quitar `**OMDb API** | Ratings & episode metrics` de la tabla de Tech Stack.
- Sustituir la sección `## Architecture` (dual API strategy) por el flujo de fuente única.
- Quitar el requisito de la OMDb API Key en `## Requirements` y su entrada en el `Secrets.plist` de ejemplo.
- Actualizar `**Multi-Source Ratings**` en Features.

- [ ] **Step 7: Ejecutar todos los tests y el build**

Run: `xcodebuild -project Plotline.xcodeproj -scheme Plotline -destination 'platform=iOS Simulator,name=iPhone 17' test`
Expected: PASS, todos los tests de las tareas 1-4.

Run:
```bash
xcodebuild -project Plotline.xcodeproj -scheme Plotline -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath build build && \
xcrun simctl install booted build/Build/Products/Debug-iphonesimulator/Plotline.app && \
xcrun simctl launch booted com.jbgsoft.Plotline
```
Expected: BUILD SUCCEEDED y la app arranca.

- [ ] **Step 8: Verificación manual final**

Recorrer con el simulador en modo claro **y** oscuro:

1. Discover carga contenido.
2. Abrir una serie larga (Breaking Bad, Los Simpson) → el gráfico de episodios se rellena, el selector de temporada funciona, la rejilla de episodios aparece.
3. Abrir una película → la ficha carga sin la sección de premios y sin ratings externos.
4. Stats → Compare con dos series → la comparación funciona.
5. Favoritos y Watchlist siguen funcionando.

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "refactor: remove OMDb dependency entirely

Episode ratings now come from TMDB's season endpoint, which removes the
1000 requests/day ceiling and the trademark exposure of redistributing
IMDb, Rotten Tomatoes and Metacritic scores.

Awards and the Plotline Score arrive in Phases 2 and 3; do not ship to
App Store before Phase 3 lands."
```

---

## Definición de terminado

- [ ] `grep -rn "omdb\|OMDb\|OMDB\|RatingSource" Plotline PlotlineTests` no devuelve nada
- [ ] Todos los tests pasan
- [ ] La app compila y arranca
- [ ] Una serie de más de 5 temporadas rellena el gráfico y la rejilla desde TMDB
- [ ] Verificado en modo claro y oscuro
- [ ] `CLAUDE.md` y `README.md` no mencionan OMDb ni iOS 18
