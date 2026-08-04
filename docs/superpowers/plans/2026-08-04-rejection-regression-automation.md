# Plan de implementación — Regresión del rechazo y preflight de release

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Automatizar el test de regresión que protege la causa del rechazo por Guideline 4.2, y quitar de la memoria humana los pasos que hoy se hacen a mano al preparar una release.

**Architecture:** Un target nuevo `PlotlineUITests` con un solo suite, ejecutado en dos condiciones (hambrienta por defecto, viva desde el preflight). La app se deja sin TMDB invirtiendo la prioridad de `Secrets`, sin una línea de código de test dentro del binario que se envía. Un `Scripts/release-preflight.sh` encadena las dos pasadas, la suite del generador que hoy nadie ejecuta, y tres comprobaciones de coherencia.

**Tech Stack:** Swift 6, Swift Testing (`@Test`/`#expect`) para los tests unitarios, **XCTest/XCUITest** para los de UI (Swift Testing no hace UI testing), SwiftPM para el generador, bash y `plutil` para el script.

**Spec:** `docs/superpowers/specs/2026-08-04-rejection-regression-automation-design.md`

## Global Constraints

- **iOS 26+**, iPhone y iPad. `TARGETED_DEVICE_FAMILY = "1,2"`.
- **`Plotline/Models/PlotlineDataset.swift` se comparte por symlink con el generador y solo puede importar `Foundation`.** Una referencia a `TMDBService`, `NetworkManager` o SwiftUI rompe el build del generador. Lo mismo aplica a `EpisodeMetric.swift`, `SeriesAnalysis.swift` y `SeriesAnalysisEngine.swift`.
- **Ninguna cadena puede afirmar más de lo que su predicado establece.** Aplica a mensajes de fallo de tests y a la salida del script igual que a la copy de la app.
- **Bundle id:** `com.jbgsoft.Plotline`. **Esquema compartido:** `Plotline.xcodeproj/xcshareddata/xcschemes/Plotline.xcscheme`.
- **Conventional Commits.** `feat:`, `fix:`, `test:`, `chore:`, `docs:`.
- Los tests unitarios existentes se ejecutan con:
  `xcodebuild -project Plotline.xcodeproj -scheme Plotline -destination 'platform=iOS Simulator,name=iPhone 17' test`
- La suite del generador con: `cd Tools/DatasetGenerator && swift test`

---

## Estructura de ficheros

| Fichero | Responsabilidad |
|---|---|
| `Plotline/Models/PlotlineDataset.swift` | + `generatedAt: String?` en el contrato |
| `Tools/DatasetGenerator/Sources/DatasetGeneratorCore/DatasetBuilder.swift` | Recibe el sello de tiempo por parámetro, sin leer el reloj |
| `Tools/DatasetGenerator/Sources/DatasetGenerator/main.swift` | Único sitio que lee el reloj |
| `Plotline/App/Secrets.swift` | Resolución pura y comprobable; entorno antes que plist |
| `PlotlineTests/SecretsTests.swift` | Nuevo. Los cuatro casos de la resolución |
| `Plotline/Support/AccessibilityAnchors.swift` | Nuevo. Los identificadores en un solo sitio del lado app |
| `Plotline/Views/Components/SuggestionsEmptyState.swift` | Acepta el identificador de su estante |
| `Plotline/Views/Discovery/MediaCard.swift` | Identificador por tarjeta |
| `Plotline/Views/Discovery/DiscoveryView.swift` | Identificador por estante curado |
| `Plotline/Views/Favorites/FavoritesView.swift`, `WatchlistView.swift` | Identificadores de sugerencias y de fila guardada |
| `Plotline/Views/Stats/StatsView.swift` | Identificadores de las tres secciones independientes de datos de usuario |
| `Plotline/Views/Settings/SettingsView.swift` | Identificadores de lista y fila |
| `PlotlineUITests/ColdStartUITests.swift` | Nuevo. El suite entero |
| `PlotlineUITests/UITestAnchors.swift` | Nuevo. Copia deliberada de los literales, lado test |
| `Scripts/release-preflight.sh` | Nuevo |
| `CLAUDE.md`, `docs/app-review/README.md` | Documentar el preflight y su límite |

**Sobre la copia deliberada de literales.** Los identificadores se escriben dos veces: una en `Plotline/Support/AccessibilityAnchors.swift` (target app) y otra en `PlotlineUITests/UITestAnchors.swift` (target de UI tests). No es un descuido y no se debe "arreglar" compartiendo el fichero entre targets. Un test de UI corre en otro proceso y no puede importar el módulo de la app; compartir el fichero exigiría cirugía sobre los grupos sincronizados del `.xcodeproj`. Y la duplicación tiene la propiedad que queremos: si alguien cambia el literal en la app, **el test se pone rojo**, que es exactamente lo que debe pasar cuando desaparece un ancla.

---

## Task 1: El dataset declara cuándo se generó

**Files:**
- Modify: `Plotline/Models/PlotlineDataset.swift:11-23`
- Modify: `Tools/DatasetGenerator/Sources/DatasetGeneratorCore/DatasetBuilder.swift:5-17`
- Modify: `Tools/DatasetGenerator/Sources/DatasetGenerator/main.swift`
- Test: `Tools/DatasetGenerator/Tests/DatasetGeneratorTests/DatasetBuilderTests.swift`

**Interfaces:**
- Produces: `PlotlineDataset.generatedAt: String?` (ISO8601). `DatasetBuilder.build(entries:skipped:generatedAt:) -> PlotlineDataset` con `generatedAt: String`.

- [ ] **Step 1: Escribir los tests que fallan**

Añadir al final de `DatasetBuilderTests.swift`, dentro del suite existente:

```swift
    @Test("the builder records the timestamp it was given")
    func buildRecordsGeneratedAt() {
        let dataset = DatasetBuilder.build(
            entries: [],
            skipped: [],
            generatedAt: "2026-08-04T12:00:00Z"
        )
        #expect(dataset.generatedAt == "2026-08-04T12:00:00Z")
    }

    /// The committed dataset predates this field. If it stopped decoding, the
    /// app would fall back to no bundled content at all — the exact emptiness
    /// this whole effort exists to prevent — so absence must decode to nil
    /// rather than throw. It is the release preflight that refuses an absent
    /// value, not the decoder.
    @Test("a dataset written before this field existed still decodes")
    func legacyFileDecodes() throws {
        let json = #"{"version":1,"entries":[],"lists":[],"skipped":[]}"#
        let dataset = try JSONDecoder().decode(PlotlineDataset.self, from: Data(json.utf8))
        #expect(dataset.generatedAt == nil)
    }

    /// The builder must stay a pure function of its inputs: same inputs, same
    /// file. A `Date()` read inside it would make every regeneration produce a
    /// different file and make this suite unable to assert anything exactly.
    @Test("the timestamp comes from the caller, not from a clock inside")
    func buildTakesTheTimestampAsInput() {
        let first = DatasetBuilder.build(entries: [], skipped: [], generatedAt: "A")
        let second = DatasetBuilder.build(entries: [], skipped: [], generatedAt: "A")
        #expect(first == second)
    }
```

- [ ] **Step 2: Ejecutar y verificar que fallan**

Run: `cd Tools/DatasetGenerator && swift test`
Expected: FAIL de compilación — `build(entries:skipped:generatedAt:)` no existe y `PlotlineDataset` no tiene `generatedAt`.

- [ ] **Step 3: Añadir el campo al contrato**

En `Plotline/Models/PlotlineDataset.swift`, dentro de `struct PlotlineDataset`, justo después de `let skipped: [SkippedSeries]`:

```swift
    /// When the generator produced this file, ISO8601.
    ///
    /// **Optional on purpose:** the file committed before this field existed
    /// must keep decoding, or the app loses its bundled content entirely. The
    /// release preflight is what refuses an absent value; the decoder accepts
    /// it.
    ///
    /// **A `String` and not a `Date`,** so no check anywhere depends on a
    /// `JSONDecoder` date strategy. That kind of invisible coupling is what
    /// makes `regionKeysAreUntouched` unfalsifiable, and it is not worth
    /// repeating in a new field. `firstAirDate` sets the same precedent in
    /// this file.
    let generatedAt: String?
```

- [ ] **Step 4: Pasar el sello de tiempo por parámetro**

En `DatasetBuilder.swift`, sustituir la firma y la construcción:

```swift
    static func build(
        entries: [DatasetEntry],
        skipped: [SkippedSeries] = [],
        generatedAt: String
    ) -> PlotlineDataset {
        let sorted = entries.sorted { $0.tmdbId < $1.tmdbId }
        // Sorted for the same reason as entries: so regenerating from
        // unchanged data reproduces an identical file.
        let sortedSkipped = skipped.sorted { $0.tmdbId < $1.tmdbId }

        return PlotlineDataset(
            version: PlotlineDataset.currentVersion,
            entries: sorted,
            lists: curatedLists(from: sorted),
            skipped: sortedSkipped,
            generatedAt: generatedAt
        )
    }
```

- [ ] **Step 5: Leer el reloj en el único sitio que debe**

En `Tools/DatasetGenerator/Sources/DatasetGenerator/main.swift`, localizar la llamada a `DatasetBuilder.build(` y pasarle el sello. Añadir justo antes:

```swift
// The only clock read in the whole generator. `DatasetBuilder` stays a pure
// function so that regenerating from unchanged data reproduces an identical
// file, which is what lets ShippedDatasetTests assert exact membership.
let generatedAt = ISO8601DateFormatter().string(from: Date())
```

y añadir `generatedAt: generatedAt` a la llamada.

- [ ] **Step 6: Ejecutar y verificar que pasan**

Run: `cd Tools/DatasetGenerator && swift test`
Expected: PASS, incluidos los tres nuevos. Si algún otro test construye un `PlotlineDataset` o llama a `build`, ajustarlo — el compilador los señala uno a uno.

- [ ] **Step 7: Verificar que la app sigue compilando y en verde**

Run: `xcodebuild -project Plotline.xcodeproj -scheme Plotline -destination 'platform=iOS Simulator,name=iPhone 17' test`
Expected: `TEST SUCCEEDED`. El dataset comprometido no tiene `generatedAt` y debe seguir decodificando — si `DatasetStoreTests` se pone rojo, el campo se declaró como no opcional.

- [ ] **Step 8: Commit**

```bash
git add Plotline/Models/PlotlineDataset.swift Tools/DatasetGenerator
git commit -m "feat: record in the dataset when the generator produced it

Optional and a String: the committed file predates the field and must
keep decoding, and no check should depend on a JSONDecoder date
strategy. The builder takes the timestamp as input so it stays a pure
function of its inputs."
```

---

## Task 2: Una variable de entorno gana al plist empaquetado

**Files:**
- Modify: `Plotline/App/Secrets.swift:1-24`
- Test: `PlotlineTests/SecretsTests.swift` (crear)

**Interfaces:**
- Consumes: nada de tareas anteriores.
- Produces: `Secrets.resolve(_ key: String, environment: [String: String], plist: [String: String]) -> String`, con visibilidad `internal` para que `@testable import Plotline` la alcance.

- [ ] **Step 1: Escribir los tests que fallan**

Crear `PlotlineTests/SecretsTests.swift`:

```swift
import Foundation
import Testing
@testable import Plotline

/// The resolution order is not a preference: it is the mechanism the starved
/// UI pass depends on. Launching the app with `TMDB_API_KEY=""` has to leave
/// it with no key, and that only works if an explicitly set environment
/// variable beats the plist committed into the bundle.
@Suite("Secrets resolution")
struct SecretsTests {
    @Test("an environment variable beats the bundled plist")
    func environmentWins() {
        let value = Secrets.resolve(
            "TMDB_API_KEY",
            environment: ["TMDB_API_KEY": "from-env"],
            plist: ["TMDB_API_KEY": "from-plist"]
        )
        #expect(value == "from-env")
    }

    /// The one case the UI test rides on. If an empty value fell through to
    /// the plist, the starved pass would silently run against live TMDB and
    /// assert nothing at all about the bundled dataset — green, and covering
    /// nothing.
    @Test("an empty environment value means no key, not fall through")
    func emptyEnvironmentValueStillWins() {
        let value = Secrets.resolve(
            "TMDB_API_KEY",
            environment: ["TMDB_API_KEY": ""],
            plist: ["TMDB_API_KEY": "from-plist"]
        )
        #expect(value == "")
    }

    @Test("the plist is used when the environment says nothing")
    func plistIsTheFallback() {
        let value = Secrets.resolve(
            "TMDB_API_KEY",
            environment: [:],
            plist: ["TMDB_API_KEY": "from-plist"]
        )
        #expect(value == "from-plist")
    }

    @Test("an unknown key resolves to an empty string, never nil")
    func unknownKeyIsEmpty() {
        #expect(Secrets.resolve("NOPE", environment: [:], plist: [:]) == "")
    }
}
```

- [ ] **Step 2: Ejecutar y verificar que falla**

Run: `xcodebuild -project Plotline.xcodeproj -scheme Plotline -destination 'platform=iOS Simulator,name=iPhone 17' test`
Expected: FAIL de compilación — `Secrets.resolve` no existe.

- [ ] **Step 3: Extraer la resolución e invertir la prioridad**

Sustituir el cuerpo completo de `Plotline/App/Secrets.swift`:

```swift
import Foundation

/// Helper to read API keys from environment variables or a bundled plist.
///
/// Priority: Environment Variables → Secrets.plist (bundle)
///
/// The plist is a default compiled into the build; an environment variable is
/// a deliberate act by whoever launched the process, so it wins. That order is
/// also what lets the cold-start UI test starve the app of TMDB by launching
/// it with `TMDB_API_KEY=""`, without a single line of test-only code inside
/// the binary that ships.
///
/// For command-line builds (xcodebuild): Add keys to Plotline/Secrets.plist
/// For Xcode builds: Either use plist or set environment variables in scheme
enum Secrets {
    private static let environment = ProcessInfo.processInfo.environment
    private static let plistSecrets: [String: String] = {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String]
        else {
            return [:]
        }
        return dict
    }()

    /// Pure so the order can be asserted without a bundle or a process
    /// environment to stand in the way.
    ///
    /// An empty environment value counts as **set**: `TMDB_API_KEY=""` means
    /// "no key", not "fall through to the plist".
    static func resolve(
        _ key: String,
        environment: [String: String],
        plist: [String: String]
    ) -> String {
        environment[key] ?? plist[key] ?? ""
    }

    static var tmdbAPIKey: String {
        resolve("TMDB_API_KEY", environment: environment, plist: plistSecrets)
    }
}
```

- [ ] **Step 4: Ejecutar y verificar que pasan**

Run: `xcodebuild -project Plotline.xcodeproj -scheme Plotline -destination 'platform=iOS Simulator,name=iPhone 17' test`
Expected: `TEST SUCCEEDED`, con los cuatro tests nuevos en verde.

- [ ] **Step 5: Verificar a mano que la app sigue teniendo clave**

Run:
```bash
xcodebuild -project Plotline.xcodeproj -scheme Plotline -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath build build && \
xcrun simctl install booted build/Build/Products/Debug-iphonesimulator/Plotline.app && \
xcrun simctl launch booted com.jbgsoft.Plotline
```
Expected: Discover muestra los estantes de red (Trending, Top Rated), no solo los curados. Si solo se ven los curados, hay un `TMDB_API_KEY` exportado en el entorno de la shell que ahora gana al plist — que es el efecto colateral anotado en el spec §1.4. Comprobar con `echo $TMDB_API_KEY`.

- [ ] **Step 6: Commit**

```bash
git add Plotline/App/Secrets.swift PlotlineTests/SecretsTests.swift
git commit -m "feat: let an environment variable beat the bundled secrets plist

A plist compiled into the build is a default; an environment variable
is a deliberate act by whoever launched the process. The order is also
what lets a UI test starve the app of TMDB with no test-only code in
the shipped binary. Resolution is extracted into a pure function so
the order is asserted rather than assumed."
```

---

## Task 3: El target de UI tests, la precondición y la primera pestaña

Esta tarea monta toda la maquinaria y la demuestra con una sola pestaña. Las otras cuatro son Task 4.

**Files:**
- Create: `PlotlineUITests/UITestAnchors.swift`
- Create: `PlotlineUITests/ColdStartUITests.swift`
- Create: `Plotline/Support/AccessibilityAnchors.swift`
- Modify: `Plotline/Views/Components/SuggestionsEmptyState.swift`
- Modify: `Plotline/Views/Discovery/MediaCard.swift`
- Modify: `Plotline/Views/Favorites/FavoritesView.swift`
- Modify: `Plotline/Views/Favorites/FavoriteRow.swift`
- Modify: `Plotline.xcodeproj` (target nuevo + esquema)

**Interfaces:**
- Consumes: `Secrets.resolve` de la Task 2 — la pasada hambrienta solo funciona si el entorno gana al plist.
- Produces: `enum AccessibilityAnchors` (app) y `enum UITestAnchors` (test) con los mismos literales; `SuggestionsEmptyState(title:message:systemImage:shelfIdentifier:)`.

- [ ] **Step 1: Crear el target en Xcode**

Esto se hace en la UI de Xcode, no editando `project.pbxproj` a mano: genera los UUID, la dependencia y la configuración correctas de una vez.

```bash
open Plotline.xcodeproj
```

File → New → Target → **UI Testing Bundle**. Valores exactos:

| Campo | Valor |
|---|---|
| Product Name | `PlotlineUITests` |
| Team / Organization | los del proyecto |
| Bundle Identifier | `com.jbgsoft.PlotlineUITests` |
| Target to be Tested | `Plotline` |

Borrar los ficheros de plantilla que Xcode cree (`PlotlineUITests.swift`, `PlotlineUITestsLaunchTests.swift`) — el suite se escribe entero abajo.

Verificar que quedó bien:
```bash
grep -c "com.apple.product-type.bundle.ui-testing" Plotline.xcodeproj/project.pbxproj
grep -n "PlotlineUITests" Plotline.xcodeproj/xcshareddata/xcschemes/Plotline.xcscheme
```
Expected: `1` en el primero, y al menos una coincidencia en el segundo. Si el esquema no lo menciona, añadirlo desde Product → Scheme → Edit Scheme → Test → `+`.

- [ ] **Step 2: Escribir los identificadores del lado test**

Crear `PlotlineUITests/UITestAnchors.swift`:

```swift
import Foundation

/// The identifiers this suite looks for, written out again on purpose.
///
/// A UI test runs in a separate process and cannot import the app module, so
/// these literals are a deliberate second copy of
/// `Plotline/Support/AccessibilityAnchors.swift`. Do not "fix" the duplication
/// by sharing the file across targets: the duplication is what makes an anchor
/// that disappears from the app show up red here, which is the whole point of
/// this suite.
enum UITestAnchors {
    static let discoverShelf = "plotline.discover.shelf"
    static let favoritesSuggestions = "plotline.favorites.suggestions"
    static let favoritesSavedRow = "plotline.favorites.savedRow"
    static let watchlistSuggestions = "plotline.watchlist.suggestions"
    static let statsCompare = "plotline.stats.compare"
    static let statsCareerProfiles = "plotline.stats.careerProfiles"
    static let statsTrends = "plotline.stats.trends"
    static let statsYourStatsEmpty = "plotline.stats.yourStatsEmpty"
    static let settingsRow = "plotline.settings.row"
    static let mediaCard = "plotline.mediaCard"
}
```

- [ ] **Step 3: Escribir el test que falla**

Crear `PlotlineUITests/ColdStartUITests.swift`:

```swift
import XCTest

/// The session an App Store reviewer has: a clean install, nothing saved.
///
/// Version 1.3.0 was rejected under Guideline 4.2 because `StatsView` wrapped
/// Compare, Career Profiles and Trends — none of which need user data — in a
/// check for saved favorites, so a reviewer with an empty library concluded
/// the app had nothing in it. `ColdStartTests` covers the dataset behind those
/// screens; nothing covered the screens. This does.
///
/// Two conditions, neither covering the other. Starved of TMDB this proves the
/// bundled dataset carries all five tabs on its own; live it is the only pass
/// that exercises the recomputation path, which can empty a screen the dataset
/// had filled.
final class ColdStartUITests: XCTestCase {
    private var app: XCUIApplication!

    /// `live` runs against real TMDB and is launched only by the release
    /// preflight. Anything else — including the variable being absent — starves
    /// the app, which is the deterministic default the normal test loop uses.
    private var isLiveMode: Bool {
        ProcessInfo.processInfo.environment["PLOTLINE_UITEST_MODE"] == "live"
    }

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        if !isLiveMode {
            // Beats the bundled Secrets.plist since Task 2. An empty value
            // counts as set, so the app runs with no key and TMDB yields
            // nothing.
            app.launchEnvironment["TMDB_API_KEY"] = ""
        }
        app.launch()
    }

    /// Asserts the suite's own precondition instead of trusting the runner.
    ///
    /// Favorites and the watchlist persist in SwiftData, inside the app
    /// container, so no launch argument can clear them — only uninstalling
    /// can. A run that skipped the uninstall would otherwise pass green while
    /// testing a state no reviewer ever sees.
    func testContainerIsClean() {
        openTab("Favorites")
        let savedRows = app.descendants(matching: .any)
            .matching(identifier: UITestAnchors.favoritesSavedRow)
        XCTAssertEqual(
            savedRows.count, 0,
            """
            The simulator container carried \(savedRows.count) saved favorites, \
            so this run is not testing a clean install. Run \
            `xcrun simctl uninstall booted com.jbgsoft.Plotline` first, or use \
            Scripts/release-preflight.sh which does it for you.
            """
        )
    }

    func testFavoritesOffersSuggestionsWithNothingSaved() {
        openTab("Favorites")
        assertShelf(UITestAnchors.favoritesSuggestions, tab: "Favorites")
    }

    // MARK: - Helpers

    private func openTab(_ name: String) {
        // The tab bar on iPhone, the sidebar on iPad under .sidebarAdaptable.
        let button = app.buttons[name]
        XCTAssertTrue(
            button.waitForExistence(timeout: 10),
            "no way to reach the \(name) tab"
        )
        button.tap()
    }

    /// A shelf must exist and show something. The exact counts — five lists,
    /// twelve suggestions, sixty titles — stay in `ColdStartTests`, which sees
    /// the whole dataset. XCUITest only sees what materialised on screen, and
    /// these shelves are `LazyHStack`s, so asserting a full count here would
    /// go red for a reason that has nothing to do with the defect.
    private func assertShelf(_ identifier: String, tab: String, minimumCards: Int = 2) {
        let shelf = app.descendants(matching: .any)[identifier]
        XCTAssertTrue(
            shelf.waitForExistence(timeout: 10),
            "the \(tab) tab is missing its content anchor \"\(identifier)\""
        )

        let cards = shelf.descendants(matching: .any)
            .matching(identifier: UITestAnchors.mediaCard)
        XCTAssertGreaterThanOrEqual(
            cards.count, minimumCards,
            "the \(tab) tab rendered its container but only \(cards.count) cards in it"
        )
    }
}
```

- [ ] **Step 4: Ejecutar y verificar que falla por el motivo correcto**

```bash
xcrun simctl boot "iPhone 17" 2>/dev/null || true
xcrun simctl uninstall booted com.jbgsoft.Plotline 2>/dev/null || true
xcodebuild -project Plotline.xcodeproj -scheme Plotline \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:PlotlineUITests test
```
Expected: `testContainerIsClean` PASA (no hay nada guardado) y `testFavoritesOffersSuggestionsWithNothingSaved` FALLA con *"the Favorites tab is missing its content anchor"*. Ese es el rojo correcto: el ancla todavía no existe.

- [ ] **Step 5: Escribir los identificadores del lado app**

Crear `Plotline/Support/AccessibilityAnchors.swift`:

```swift
import Foundation

/// Identifiers the cold-start UI test looks for.
///
/// These are load-bearing, not decoration: each one marks a container that has
/// to be on screen on a clean install with no user data. Removing one, or
/// moving it inside a condition on saved favorites, is the shape of the defect
/// that got version 1.3.0 rejected under Guideline 4.2.
///
/// `PlotlineUITests/UITestAnchors.swift` carries the same literals. The copy is
/// deliberate — see the comment there.
enum AccessibilityAnchors {
    static let discoverShelf = "plotline.discover.shelf"
    static let favoritesSuggestions = "plotline.favorites.suggestions"
    static let favoritesSavedRow = "plotline.favorites.savedRow"
    static let watchlistSuggestions = "plotline.watchlist.suggestions"
    static let statsCompare = "plotline.stats.compare"
    static let statsCareerProfiles = "plotline.stats.careerProfiles"
    static let statsTrends = "plotline.stats.trends"
    static let statsYourStatsEmpty = "plotline.stats.yourStatsEmpty"
    static let settingsRow = "plotline.settings.row"
    static let mediaCard = "plotline.mediaCard"
}
```

- [ ] **Step 6: Marcar las tarjetas**

En `Plotline/Views/Discovery/MediaCard.swift`, localizar el `var body: some View` y añadir el modificador al final de la vista raíz que devuelve, **sin tocar la etiqueta de accesibilidad que ya tenga**:

```swift
        .accessibilityIdentifier(AccessibilityAnchors.mediaCard)
```

- [ ] **Step 7: Dejar que el estante de sugerencias reciba su identificador**

En `Plotline/Views/Components/SuggestionsEmptyState.swift`, añadir la propiedad y aplicarla. La vista la usan dos pantallas y cada una necesita su propio identificador, así que se pasa desde fuera en vez de fijarlo dentro:

```swift
struct SuggestionsEmptyState: View {
    let title: String
    let message: String
    let systemImage: String
    /// Set by the caller so Favorites and Watchlist are told apart on screen.
    let shelfIdentifier: String
```

y sustituir el bloque de sugerencias:

```swift
                if !suggestions.isEmpty {
                    MediaSection(title: "Analysed by Plotline", items: suggestions)
                        .accessibilityIdentifier(shelfIdentifier)
                }
```

- [ ] **Step 8: Pasar el identificador desde Favorites y marcar la fila guardada**

En `Plotline/Views/Favorites/FavoritesView.swift`, localizar la llamada a `SuggestionsEmptyState(` y añadir el argumento:

```swift
                    shelfIdentifier: AccessibilityAnchors.favoritesSuggestions
```

En `Plotline/Views/Favorites/FavoriteRow.swift`, al final de la vista raíz de `body`:

```swift
        .accessibilityIdentifier(AccessibilityAnchors.favoritesSavedRow)
```

`WatchlistView.swift` también llama a `SuggestionsEmptyState` y ahora no compilará. Añadirle ya el argumento, aunque su test llegue en la Task 4:

```swift
                    shelfIdentifier: AccessibilityAnchors.watchlistSuggestions
```

- [ ] **Step 9: Ejecutar y verificar que pasa**

```bash
xcrun simctl uninstall booted com.jbgsoft.Plotline 2>/dev/null || true
xcodebuild -project Plotline.xcodeproj -scheme Plotline \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:PlotlineUITests test
```
Expected: los dos tests en verde.

Si `assertShelf` falla contando tarjetas pese a verse el estante, el contenedor de `MediaSection` está agregando a sus hijos: quitar cualquier `.accessibilityElement(children: .combine)` del camino y volver a ejecutar. `.contain` sí deja ver los hijos.

- [ ] **Step 10: Ejecutar la suite entera para no haber roto nada**

Run: `xcodebuild -project Plotline.xcodeproj -scheme Plotline -destination 'platform=iOS Simulator,name=iPhone 17' test`
Expected: `TEST SUCCEEDED`.

- [ ] **Step 11: Commit**

```bash
git add Plotline.xcodeproj PlotlineUITests Plotline/Support/AccessibilityAnchors.swift \
        Plotline/Views/Components/SuggestionsEmptyState.swift \
        Plotline/Views/Discovery/MediaCard.swift Plotline/Views/Favorites
git commit -m "test: cover the reviewer's session with a cold-start UI suite

ColdStartTests covers the dataset behind the five tabs; nothing covered
the tabs. This target does, starting with Favorites and with the suite
asserting its own precondition: favorites persist in SwiftData, so only
uninstalling clears them, and a run that skipped the uninstall now goes
red instead of passing green against a state no reviewer sees."
```

---

## Task 4: Las otras cuatro pestañas

**Files:**
- Modify: `PlotlineUITests/ColdStartUITests.swift`
- Modify: `Plotline/Views/Discovery/DiscoveryView.swift:195-215`
- Modify: `Plotline/Views/Favorites/WatchlistView.swift`
- Modify: `Plotline/Views/Stats/StatsView.swift:40-64, 88-160`
- Modify: `Plotline/Views/Settings/SettingsView.swift:9-28`

**Interfaces:**
- Consumes: `AccessibilityAnchors` y `UITestAnchors` de la Task 3, y el helper `assertShelf`.

- [ ] **Step 1: Escribir los cuatro tests que fallan**

Añadir a `ColdStartUITests.swift`, después de `testFavoritesOffersSuggestionsWithNothingSaved`:

```swift
    func testDiscoverShowsCuratedShelves() {
        openTab("Discover")
        let shelves = app.descendants(matching: .any)
            .matching(identifier: UITestAnchors.discoverShelf)
        XCTAssertTrue(
            shelves.firstMatch.waitForExistence(timeout: 10),
            "Discover rendered no curated shelf at all"
        )
        // Only the shelves scrolled into view have materialised. The dataset
        // ships five; ColdStartTests is what asserts that number exactly.
        XCTAssertGreaterThanOrEqual(
            shelves.count, 2,
            "Discover showed only \(shelves.count) curated shelves on first screen"
        )
    }

    func testWatchlistOffersSuggestionsWithNothingSaved() {
        openTab("Watchlist")
        assertShelf(UITestAnchors.watchlistSuggestions, tab: "Watchlist")
    }

    /// Two assertions, not one, and that is the whole point.
    ///
    /// The rejected build showed the empty-state invitation *instead of* the
    /// rest of the tab. A suite that only checked the invitation was there
    /// would have passed on the build that got rejected.
    func testStatsKeepsItsUserIndependentSectionsWhenNothingIsSaved() {
        openTab("Stats")

        let invitation = app.descendants(matching: .any)[UITestAnchors.statsYourStatsEmpty]
        XCTAssertTrue(
            invitation.waitForExistence(timeout: 10),
            "Stats did not show the empty-state invitation with nothing saved"
        )

        for anchor in [
            UITestAnchors.statsCompare,
            UITestAnchors.statsCareerProfiles,
            UITestAnchors.statsTrends,
        ] {
            let section = app.descendants(matching: .any)[anchor]
            if !section.exists {
                app.swipeUp()
            }
            XCTAssertTrue(
                section.waitForExistence(timeout: 5),
                """
                Stats is missing \"\(anchor)\" with nothing saved. This section \
                analyses TMDB, not the user's library, and gating it behind \
                saved favorites is the defect that got 1.3.0 rejected.
                """
            )
        }
    }

    func testSettingsIsReachableAndPopulated() {
        openTab("Settings")
        let rows = app.descendants(matching: .any)
            .matching(identifier: UITestAnchors.settingsRow)
        XCTAssertTrue(
            rows.firstMatch.waitForExistence(timeout: 10),
            "Settings rendered no rows"
        )
        XCTAssertGreaterThanOrEqual(rows.count, 2, "Settings showed only \(rows.count) rows")
    }
```

- [ ] **Step 2: Ejecutar y verificar que fallan**

```bash
xcrun simctl uninstall booted com.jbgsoft.Plotline 2>/dev/null || true
xcodebuild -project Plotline.xcodeproj -scheme Plotline \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:PlotlineUITests test
```
Expected: los cuatro nuevos en rojo por anclas ausentes; los dos de la Task 3 siguen en verde.

- [ ] **Step 3: Marcar los estantes curados de Discover**

En `DiscoveryView.swift`, dentro de `curatedShelves`, añadir el identificador al `VStack` que ya lleva los modificadores de accesibilidad, **sin envolver el `ForEach` en otro contenedor** — hacerlo desactivaría la pereza del `LazyVStack` y materializaría los cinco estantes de golpe:

```swift
                .accessibilityElement(children: .contain)
                .accessibilityLabel(title)
                .accessibilityHint(CuratedListCopy.subtitle(for: list.id) ?? "")
                .accessibilityIdentifier(AccessibilityAnchors.discoverShelf)
```

- [ ] **Step 4: Marcar las tres secciones de Stats y la invitación**

En `StatsView.swift`, al final de `myStatsInvitation`, tras `.accessibilityLabel(...)`:

```swift
        .accessibilityIdentifier(AccessibilityAnchors.statsYourStatsEmpty)
```

Y en `statsContent`, a cada uno de los tres `VStack` marcados con `// MARK: - Compare`, `// MARK: - Career Profiles` y el de Trends, añadir al cierre del `VStack` correspondiente:

```swift
                .accessibilityIdentifier(AccessibilityAnchors.statsCompare)
```
```swift
                .accessibilityIdentifier(AccessibilityAnchors.statsCareerProfiles)
```
```swift
                .accessibilityIdentifier(AccessibilityAnchors.statsTrends)
```

- [ ] **Step 5: Marcar las filas de Settings**

En `SettingsView.swift`, dentro del `List`, añadir a `ThemeOptionRow` en el `ForEach`:

```swift
                        .accessibilityIdentifier(AccessibilityAnchors.settingsRow)
```

y a `InfoRow(label: "Version", value: appVersion)`:

```swift
                        .accessibilityIdentifier(AccessibilityAnchors.settingsRow)
```

- [ ] **Step 6: Ejecutar y verificar que pasan**

```bash
xcrun simctl uninstall booted com.jbgsoft.Plotline 2>/dev/null || true
xcodebuild -project Plotline.xcodeproj -scheme Plotline \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:PlotlineUITests test
```
Expected: los seis tests en verde.

- [ ] **Step 7: Verificar también en iPad, donde la navegación es una barra lateral**

```bash
xcrun simctl boot "iPad Air 11-inch (M4)" 2>/dev/null || true
xcrun simctl uninstall booted com.jbgsoft.Plotline 2>/dev/null || true
xcodebuild -project Plotline.xcodeproj -scheme Plotline \
  -destination 'platform=iOS Simulator,name=iPad Air 11-inch (M4)' \
  -only-testing:PlotlineUITests test
```
Expected: verde. Con `.tabViewStyle(.sidebarAdaptable)` el iPad esconde Settings tras un chevron (residuo nº 4 de la Fase 6), así que si `openTab("Settings")` no encuentra el botón, ampliar el helper para desplegar la sección antes de buscar, y anotarlo.

- [ ] **Step 8: Commit**

```bash
git add PlotlineUITests Plotline/Views
git commit -m "test: cover the remaining four tabs on a clean install

Stats carries two assertions rather than one: the rejected build showed
the empty-state invitation instead of Compare, Career Profiles and
Trends, so a suite that only checked the invitation would have passed
on the build that got rejected."
```

---

## Task 5: El script de preflight

**Files:**
- Create: `Scripts/release-preflight.sh`

**Interfaces:**
- Consumes: `PLOTLINE_UITEST_MODE` de la Task 3, `generatedAt` de la Task 1.

- [ ] **Step 1: Escribir el script**

Crear `Scripts/release-preflight.sh`:

```bash
#!/bin/bash
# Everything that has to be true before a Plotline release, in one place.
#
# NOT A BARRIER. This is also wired to the scheme's Archive pre-action, and a
# pre-action that exits non-zero does not reliably abort an archive in recent
# Xcode. It tells you at the right moment; it does not stop you.
set -uo pipefail

cd "$(dirname "$0")/.." || exit 1

DEVICE="iPhone 17"
BUNDLE_ID="com.jbgsoft.Plotline"
DATASET="Plotline/Resources/PlotlineDataset.json"
MAX_DATASET_AGE_DAYS=90   # A judgement, not a calculation. Change it here.

failures=0
step()  { printf '\n\033[1m▸ %s\033[0m\n' "$1"; }
fail()  { printf '\033[31m  ✗ %s\033[0m\n' "$1"; failures=$((failures + 1)); }
pass()  { printf '\033[32m  ✓ %s\033[0m\n' "$1"; }

xcrun simctl boot "$DEVICE" 2>/dev/null
xcrun simctl bootstatus "$DEVICE" -b >/dev/null 2>&1

# $1 = extra env assignment, or empty. $2 = extra xcodebuild args, or empty.
# Both unquoted on purpose: empty expands to nothing rather than to an empty
# argument. Always uninstalls first — the UI suite asserts a clean container
# and would otherwise report the container, not the code.
run_suite() {
    xcrun simctl uninstall booted "$BUNDLE_ID" 2>/dev/null
    env $1 xcodebuild -project Plotline.xcodeproj -scheme Plotline \
        -destination "platform=iOS Simulator,name=$DEVICE" $2 test 2>&1 | tail -20
    return "${PIPESTATUS[0]}"
}

step "1/7  App suite, starved of TMDB"
if run_suite "" ""; then pass "starved pass green"; else fail "starved pass red"; fi

step "2/7  Cold-start suite, live against TMDB"
# The only place this runs, and only the UI suite: the unit tests neither touch
# the network nor change between the two passes. A red here can mean a real
# defect or a TMDB rate limit; read the failure before treating it as either.
if run_suite "TEST_RUNNER_PLOTLINE_UITEST_MODE=live" "-only-testing:PlotlineUITests"; then
    pass "live pass green"
else
    fail "live pass red — check whether TMDB rate-limited before blaming the code"
fi

step "3/7  Generator suite (the only tests that read the shipped dataset)"
if (cd Tools/DatasetGenerator && swift test 2>&1 | tail -10); then
    pass "shipped dataset invariants hold"
else
    fail "shipped dataset invariants broken"
fi

step "4/7  Dataset freshness"
generated=$(plutil -extract generatedAt raw -o - "$DATASET" 2>/dev/null)
if [ -z "$generated" ] || [ "$generated" = "null" ]; then
    fail "$DATASET declares no generatedAt — regenerate it with Tools/DatasetGenerator"
else
    gen_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$generated" +%s 2>/dev/null)
    if [ -z "$gen_epoch" ]; then
        fail "generatedAt is not ISO8601: $generated"
    else
        age_days=$(( ( $(date +%s) - gen_epoch ) / 86400 ))
        if [ "$age_days" -gt "$MAX_DATASET_AGE_DAYS" ]; then
            fail "dataset is $age_days days old (limit $MAX_DATASET_AGE_DAYS)"
        else
            pass "dataset is $age_days days old"
        fi
    fi
fi

step "5/7  Version coherence with the App Review artefacts"
version=$(grep -m1 'MARKETING_VERSION' Plotline.xcodeproj/project.pbxproj \
          | sed 's/.*= *//; s/;.*//' | tr -d ' ')
if grep -rq "$version" docs/app-review/; then
    pass "project and docs/app-review both say $version"
else
    fail "project says $version but no file in docs/app-review/ mentions it"
fi

step "6/7  No trace of OMDb"
if grep -rq "omdbapi" --include="*.swift" --include="*.plist" Plotline/ Tools/; then
    fail "a reference to omdbapi.com is back"
else
    pass "no reference to omdbapi.com"
fi

step "7/7  What still has to be done by hand"
cat <<'MANUAL'
  App Store Connect is not automated, on purpose — see docs/app-review/README.md.
  In this order:
    1. Reply in the existing Resolution Center thread. Before uploading anything.
    2. Upload the build.
    3. Update description, subtitle, promotional text, keywords, what's new.
    4. Replace the screenshots.
    5. Paste the App Review Notes.
    6. Request the call from the Resolution Center.
MANUAL

if [ "$failures" -eq 0 ]; then
    printf '\n\033[32mPreflight clean.\033[0m Nothing above blocks a release.\n'
    exit 0
fi
printf '\n\033[31m%s check(s) failed.\033[0m\n' "$failures"
exit 1
```

- [ ] **Step 2: Hacerlo ejecutable y lanzarlo**

```bash
chmod +x Scripts/release-preflight.sh
./Scripts/release-preflight.sh
```
Expected: los pasos 1-3 y 5-6 en verde; **el paso 4 en rojo** con *"declares no generatedAt"*, porque el dataset comprometido es anterior al campo. Ese rojo es correcto y es la prueba de que la comprobación funciona.

- [ ] **Step 3: Regenerar el dataset para que declare su fecha**

Requiere `TMDB_API_KEY` y red. Consultar `Tools/DatasetGenerator/README.md` si existe, o el `main.swift`, para los argumentos exactos.

```bash
cd Tools/DatasetGenerator && swift run DatasetGenerator
```

- [ ] **Step 4: Verificar que el campo está y el preflight pasa**

```bash
plutil -extract generatedAt raw -o - Plotline/Resources/PlotlineDataset.json
./Scripts/release-preflight.sh
```
Expected: una fecha ISO8601, y el paso 4 en verde.

Si regenerar no es posible ahora (sin clave o sin red), **dejarlo en rojo y no tocar el umbral**: el rojo dice la verdad. Anotarlo en el commit.

- [ ] **Step 5: Commit**

```bash
git add Scripts/release-preflight.sh Plotline/Resources/PlotlineDataset.json
git commit -m "chore: gather every release precondition into one script

It also closes the gap where ShippedDatasetTests — the only tests that
read the file that actually ships — were never run by xcodebuild test.
The script is not a barrier and says so: it is wired to the Archive
pre-action, and a failing pre-action does not reliably abort an archive."
```

---

## Task 6: Engancharlo a Archive y documentarlo

**Files:**
- Modify: `Plotline.xcodeproj/xcshareddata/xcschemes/Plotline.xcscheme`
- Modify: `CLAUDE.md`
- Modify: `docs/app-review/README.md`

- [ ] **Step 1: Añadir la pre-action de Archive**

En Xcode: Product → Scheme → Edit Scheme → **Archive** → Pre-actions → `+` → New Run Script Action. Provide build settings from: `Plotline`. Script:

```bash
"$SRCROOT/Scripts/release-preflight.sh" 2>&1 | tee "$SRCROOT/build/preflight.log"
```

- [ ] **Step 2: Verificar que quedó en el esquema compartido**

Run: `grep -n "release-preflight" Plotline.xcodeproj/xcshareddata/xcschemes/Plotline.xcscheme`
Expected: una coincidencia. Si no aparece, el esquema se guardó en `xcuserdata`: marcar "Shared" en Manage Schemes y repetir.

- [ ] **Step 3: Documentarlo en CLAUDE.md**

Añadir a `CLAUDE.md`, en la sección de Build Commands, tras el bloque de tests:

```markdown
# Everything that has to be true before a release
./Scripts/release-preflight.sh
```

Y una subsección nueva bajo Workflow Rules:

```markdown
### Antes de una release

`Scripts/release-preflight.sh` reúne las dos pasadas del suite de cold start,
la suite del generador —que `xcodebuild test` **no** ejecuta, y es la única que
lee el dataset que de verdad se envía—, la frescura del dataset, la coherencia
entre `MARKETING_VERSION` y `docs/app-review/`, y la ausencia de OMDb.

Está enganchado a la pre-action de Archive, **y eso no lo convierte en una
barrera**: una pre-action que devuelve error no aborta el archive de forma
fiable en Xcode reciente. Avisa en el momento exacto; no impide.
```

- [ ] **Step 4: Documentarlo en el README de App Review**

En `docs/app-review/README.md`, añadir antes de la sección "El orden que importa":

```markdown
## Paso 0

`./Scripts/release-preflight.sh` antes de nada. No sustituye a la lista de
abajo —los textos se siguen pegando a mano a propósito— pero comprueba lo que
sí se puede comprobar, e imprime esa lista al terminar.
```

- [ ] **Step 5: Commit**

```bash
git add Plotline.xcodeproj CLAUDE.md docs/app-review/README.md
git commit -m "docs: wire the preflight to Archive and write down its limit"
```

---

## Task 7: Demostrar que estos tests sí pueden fallar

El §5 del spec. El tema de todo este trabajo es que hay tests que no pueden fallar; sería absurdo cerrarlo añadiendo más. **Cada mutación se aplica, se observa el rojo, y se revierte.** Nada de esta tarea se comprometa salvo el documento final.

**Files:**
- Create: `docs/superpowers/specs/2026-08-04-phase-8-residuals.md`

- [ ] **Step 1: Confirmar `git status` limpio**

Run: `git status --short`
Expected: sin salida. Si hay cambios sin comprometer, pararse: las mutaciones se revierten con `git checkout` y se llevarían por delante trabajo real.

- [ ] **Step 2: Aplicar las seis mutaciones, una a una**

Para cada fila: aplicar el cambio, ejecutar el comando, **anotar si sale rojo y con qué mensaje**, y revertir con `git checkout -- <fichero>` antes de la siguiente.

| # | Mutación | Comando | Debe salir rojo |
|---|---|---|---|
| 1 | En `StatsView.statsContent`, envolver los tres `VStack` de Compare, Career Profiles y Trends en `if !viewModel.isEmpty { }` | UI suite | `testStatsKeepsItsUserIndependentSectionsWhenNothingIsSaved` |
| 2 | Borrar `.accessibilityIdentifier(AccessibilityAnchors.favoritesSuggestions)` del punto de llamada en `FavoritesView` | UI suite | `testFavoritesOffersSuggestions...`, nombrando el ancla |
| 3 | Poner `lists: []` en el `PlotlineDataset` de `Plotline/Resources/PlotlineDataset.json` | UI suite | `testDiscoverShowsCuratedShelves` |
| 4 | Guardar un favorito a mano en la app y volver a lanzar **sin** `simctl uninstall` | UI suite | `testContainerIsClean` |
| 5 | En `Secrets.resolve`, volver a `plist[key] ?? environment[key] ?? ""` | suite de la app | `emptyEnvironmentValueStillWins` |
| 6 | Borrar la línea `generatedAt` del JSON del dataset | `./Scripts/release-preflight.sh` | paso 4 |
| 7 | Subir `MARKETING_VERSION` a `1.4.1` sin tocar `docs/app-review/` | `./Scripts/release-preflight.sh` | paso 5 |

Comando del suite de UI:
```bash
xcrun simctl uninstall booted com.jbgsoft.Plotline 2>/dev/null || true
xcodebuild -project Plotline.xcodeproj -scheme Plotline \
  -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:PlotlineUITests test
```

- [ ] **Step 3: Arreglar lo que no se pusiera rojo**

Una mutación que no consiga rojo es un test que sobra o está mal escrito. Arreglarlo **antes** de dar la fase por cerrada, y volver a ejecutar esa mutación. No anotarlo como residuo: es el trabajo de esta tarea.

- [ ] **Step 4: Verificar que el repositorio quedó como estaba**

Run: `git status --short && git stash list`
Expected: sin salida en ambos. Cualquier resto es una mutación sin revertir.

- [ ] **Step 5: Escribir los residuos de la fase**

Crear `docs/superpowers/specs/2026-08-04-phase-8-residuals.md`, siguiendo la forma de los anteriores: qué cierra la fase, la tabla de mutaciones **con el resultado real observado**, y lo que queda abierto. Como mínimo debe recoger:

- El residuo nº 5 de la Fase 7 sigue abierto, y el dato nuevo: `selectionPersists` no es un test débil sino un límite inalcanzable, porque `WatchRegionStore` lee `UserDefaults` solo en `private init()` y es un singleton. Quien lo retome necesita hacer inyectable el almacenamiento.
- La pasada hambrienta prueba "TMDB no devuelve nada" (401 inmediato), no "sin red" (timeouts). Spec §1.5.
- La pre-action de Archive avisa pero no aborta.
- Los mínimos del suite de UI son bajos a propósito: XCUITest solo ve lo materializado, y las cantidades exactas viven en `ColdStartTests`.
- Los 90 días de frescura son un juicio, no un cálculo.
- Qué no protege nada de esto: que la app se vea *bien*, iPad más allá de la pasada de la Task 4 Step 7, y la experiencia real sin cobertura.

- [ ] **Step 6: Commit**

```bash
git add docs/superpowers/specs/2026-08-04-phase-8-residuals.md
git commit -m "docs: record phase 8 residuals and the mutation results

Every new assertion was shown to go red under a deliberate mutation.
Closing a phase about tests that cannot fail by adding more would have
been absurd."
```

---

## Self-review

**Cobertura del spec:**

| Sección del spec | Tarea |
|---|---|
| §1.1 instalación limpia vía `simctl uninstall` | 3 (steps 4, 9), 5 (`run_suite`) |
| §1.2 precondición autoverificada | 3 (step 3, `testContainerIsClean`) |
| §1.3 dos pasadas y `PLOTLINE_UITEST_MODE` | 3 (`isLiveMode`), 5 (paso 2) |
| §1.4 inversión de prioridad en `Secrets` | 2 |
| §1.5 limitación 401 vs timeouts | 7 (step 5) |
| §1.6 anclas y mínimos | 3, 4 |
| §1.7 target nuevo en la acción de test | 3 (step 1) |
| §2 pasos 1-7 del preflight | 5 |
| §2.1 `generatedAt` | 1 |
| §3 ficheros que toca | todas |
| §4 modos de fallo | 3 (step 9), 5 (paso 2), 4 (step 7) |
| §5 mutaciones | 7 |
| §6 lo que no protege | 7 (step 5) |

**Sin placeholders.** Ningún paso dice "añadir manejo de errores" ni "tests para lo anterior": todos llevan el código o el comando exacto.

**Consistencia de tipos.** `AccessibilityAnchors` y `UITestAnchors` declaran los mismos diez literales con los mismos nombres de propiedad; `SuggestionsEmptyState` gana `shelfIdentifier` en la Task 3 step 7 y sus dos llamadores lo reciben en el mismo step 8; `DatasetBuilder.build` gana `generatedAt: String` en la Task 1 y el único llamador se actualiza en el mismo commit.

**Dos avisos para quien ejecute:**

- La Task 3 step 1 **se hace en la UI de Xcode**, no editando `project.pbxproj`. Un target de UI tests son varios UUID, una dependencia, un `TEST_TARGET_NAME` y una entrada de esquema; escribirlos a mano es más lento y más frágil que dos clics.
- La Task 5 step 3 **necesita `TMDB_API_KEY` y red**. Si no las hay, el paso 4 del preflight se queda en rojo diciendo la verdad. No subir el umbral de días para taparlo.
