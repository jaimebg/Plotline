# Fase 4 — Arranque en frío

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Que ninguna de las cinco pestañas esté vacía en una instalación limpia y sin red, conectando el dataset del bundle.

**Architecture:** Un `DatasetStore` carga el JSON empaquetado una vez, fuera del hilo principal, y lo expone a las vistas. Los estantes curados salen de ahí — siempre disponibles, sin red, desde el primer segundo. Las secciones de trending siguen viniendo de TMDB como hasta ahora. Las pestañas que hoy muestran un `ContentUnavailableView` pasan a mostrar contenido real.

**Tech Stack:** SwiftUI, Swift Testing, iOS 26.

**Spec:** `docs/superpowers/specs/2026-08-01-app-store-4.2-design.md` §8

## Por qué existe esta fase

Es la corrección del defecto que causó el rechazo. El diagnóstico, del principio de todo este trabajo:

> App Review evalúa sobre una instalación limpia. `StatsView.swift` envuelve la pestaña entera en `if viewModel.isEmpty`, así que el revisor vio "No Stats Yet" y **nunca alcanzó** Compare, Career Profiles ni Trends — todo el valor que se había construido precisamente para superar el 4.2. Tres de cinco pestañas vacías.

**Ese código sigue exactamente igual.** Las fases 1 a 3 construyeron los datos; esta los pone donde se ven.

## Global Constraints

- Deployment target iOS 26.0. El proyecto compila en **Swift 5 language mode**. No intentar migración a Swift 6.
- Los **view models** usan `@Observable`, nunca `@ObservableObject`. `DatasetStore` (Tarea 1) es la excepción deliberada y no es observable: sus getters mutan una caché, lo que bajo observación sería una mutación durante la evaluación del body de una vista, y su contenido no cambia nunca tras la primera lectura.
- **Nunca `.white` para texto** — `.primary` / `.secondary`. **Nunca fondos oscuros hardcodeados** — `Color.plotlineBackground` / `Color.plotlineCard`. Todo debe funcionar en claro y oscuro.
- **Todo el texto de UI en inglés.** La app no tiene catálogo de localización y sus vistas son íntegramente inglesas.
- **Nunca editar `Plotline.xcodeproj/project.pbxproj` ni `Plotline/Info.plist`.** Los archivos nuevos bajo `Plotline/` entran solos al target.
- Cuatro archivos de `Plotline/` los compila también el generador: `Models/EpisodeMetric.swift`, `Models/SeriesAnalysis.swift`, `Models/PlotlineDataset.swift` y `Services/Analysis/SeriesAnalysisEngine.swift`. **Los originales están aquí**; los symlinks viven en `Tools/DatasetGenerator/Sources/DatasetGeneratorCore/Shared/` y apuntan hacia ellos. Pueden leerse y usarse con normalidad, pero si hay que modificarlos, **solo pueden importar `Foundation`**: una referencia a `TMDBService`, `NetworkManager` o `DiskCache` rompe el build del generador.
- Commits en Conventional Commits, en inglés.
- La app debe compilar y su suite pasar al final de **cada** tarea. Punto de partida: **74** tests.

**Comando de tests:**

```bash
xcodebuild -project Plotline.xcodeproj -scheme Plotline \
  -destination 'platform=iOS Simulator,name=iPhone 17' test 2>/dev/null
```

Contar con `grep -cE "Test case '.*' passed"` — la forma **sin ancla**, porque la anclada subcuenta por uno de vez en cuando por interleaving de la salida de xcodebuild. Si sale uno corto, confirmar contra el bundle `.xcresult` antes de concluir que algo falla.

**Trampa de entorno:** si `xcodebuild test` falla con `Application failed preflight checks` o `Busy`, es el simulador, no el código. `xcrun simctl uninstall booted com.jbgsoft.Plotline` y repetir una vez. **Nunca modificar código por ese error.**

## Alcance

Esta fase hace **solo el arranque en frío**. Mostrar el análisis de series en la ficha de detalle y el "dónde verlo" (§7 del spec) van a una fase posterior — son superficie nueva, no la corrección del defecto.

## El dataset que se consume

`Plotline/Resources/PlotlineDataset.json`, ya en el bundle: **122 series analizadas**, 983 KB, y cinco listas curadas con esta membresía actual:

| id | títulos |
|---|---|
| `never-decline` | 27 |
| `perfect-ending` | 23 |
| `slow-burn` | 14 |
| `falls-off` | 5 |
| `rollercoaster` | 3 |

`CuratedList` lleva solo `id` y `tmdbIds`: **el copy es responsabilidad de la app** y se añade en la Tarea 2. Se quitó del dataset a propósito, porque estaba en español en una app inglesa y porque el texto de UI no pertenece a un archivo de datos.

---

## Estructura de archivos

| Archivo | Responsabilidad | Acción |
|---|---|---|
| `Plotline/Services/DatasetStore.swift` | Cargar y decodificar el JSON del bundle una sola vez | Crear (Tarea 1) |
| `Plotline/Models/CuratedListCopy.swift` | Título y subtítulo en inglés por id de lista | Crear (Tarea 2) |
| `Plotline/Models/DatasetEntry+MediaItem.swift` | Conversión a `MediaItem` para reutilizar las vistas existentes | Crear (Tarea 2) |
| `Plotline/Views/Discovery/DiscoveryView.swift` | Estantes curados del dataset | Modificar (Tarea 3) |
| `Plotline/Views/Stats/StatsView.swift` | Invertir el gating que causó el rechazo | Modificar (Tarea 4) |
| `Plotline/Views/Favorites/FavoritesView.swift` | Estado vacío con sugerencias reales | Modificar (Tarea 5) |
| `Plotline/Views/Favorites/WatchlistView.swift` | Estado vacío con sugerencias reales | Modificar (Tarea 5) |
| `PlotlineTests/DatasetStoreTests.swift` | El store y la conversión | Crear (Tareas 1-2) |
| `PlotlineTests/ColdStartTests.swift` | La regresión del rechazo | Crear (Tarea 6) |

---

## Task 1: `DatasetStore`

**Files:**
- Create: `Plotline/Services/DatasetStore.swift`
- Create: `PlotlineTests/DatasetStoreTests.swift`

**Interfaces:**
- Consumes: `PlotlineDataset`, `DatasetEntry`, `CuratedList` (ya en el target, symlinkados desde el generador)
- Produces:
  - `DatasetStore.shared`
  - `func load() -> PlotlineDataset?` (síncrona, cachea, devuelve `nil` si falta o no decodifica)
  - `var entries: [DatasetEntry]`, `var lists: [CuratedList]`
  - `func entry(forTMDBId id: Int) -> DatasetEntry?`
  - `func entries(for list: CuratedList) -> [DatasetEntry]`

**Nota de diseño:** el store es síncrono y cachea en una `lazy`. Decodificar ~1 MB tarda milisegundos y ocurre una vez; una API asíncrona obligaría a todas las vistas a manejar un estado de carga para datos que **siempre** están ahí, que es exactamente la complejidad que esta fase quiere eliminar. Si el perfilado demostrara lo contrario, se cambia entonces y con datos.

- [ ] **Step 1: Escribir los tests que fallan**

Crear `PlotlineTests/DatasetStoreTests.swift`:

```swift
import Foundation
import Testing
@testable import Plotline

@Suite("DatasetStore")
struct DatasetStoreTests {
    @Test("the bundled dataset loads")
    func loadsBundledDataset() {
        #expect(DatasetStore.shared.load() != nil)
    }

    @Test("the dataset ships a usable number of series")
    func shipsEnoughSeries() {
        // The whole point of this dataset is that the app is not empty on a
        // clean install, so a handful of entries would defeat it.
        #expect(DatasetStore.shared.entries.count >= 50)
    }

    @Test("every entry carries what a MediaItem needs")
    func entriesAreComplete() {
        for entry in DatasetStore.shared.entries {
            #expect(!entry.name.isEmpty)
            #expect(entry.posterPath != nil)
            #expect(!entry.genreIds.isEmpty)
        }
    }

    @Test("curated lists resolve to real entries")
    func listsResolve() {
        let store = DatasetStore.shared
        #expect(!store.lists.isEmpty)

        for list in store.lists {
            let resolved = store.entries(for: list)
            #expect(resolved.count == list.tmdbIds.count)
        }
    }

    @Test("an entry can be found by its TMDB id")
    func findsEntryById() throws {
        let first = try #require(DatasetStore.shared.entries.first)
        #expect(DatasetStore.shared.entry(forTMDBId: first.tmdbId)?.name == first.name)
    }

    @Test("an unknown id returns nil rather than crashing")
    func unknownIdIsNil() {
        #expect(DatasetStore.shared.entry(forTMDBId: -1) == nil)
    }

    @Test("loading twice returns the same cached value")
    func cachesAfterFirstLoad() {
        let a = DatasetStore.shared.load()
        let b = DatasetStore.shared.load()
        #expect(a == b)
    }
}
```

- [ ] **Step 2: Ejecutar para verificar que falla**

Run: `xcodebuild -project Plotline.xcodeproj -scheme Plotline -destination 'platform=iOS Simulator,name=iPhone 17' test 2>/dev/null`
Expected: FAIL de compilación, `cannot find 'DatasetStore' in scope`.

- [ ] **Step 3: Escribir el store**

Crear `Plotline/Services/DatasetStore.swift`:

```swift
import Foundation

/// Reads the analysis dataset that ships inside the app bundle.
///
/// The bundled data is a **seed and a fallback, never the truth**: it exists so
/// the app has its own content on a clean install, offline, before the user has
/// done anything. Where the app can fetch something fresher from TMDB, the
/// fresh data wins.
///
/// Deliberately **not** `@Observable`: the getters below call `load()`, which
/// mutates the cache, and under observation that is a mutation during a view's
/// body evaluation. Nothing here ever changes after the first read, so there is
/// nothing for a view to observe.
final class DatasetStore {
    static let shared = DatasetStore()

    private var cached: PlotlineDataset?
    private var didAttemptLoad = false
    private var index: [Int: DatasetEntry] = [:]

    private init() {}

    /// Decodes the bundled dataset, once. Returns nil when the file is missing
    /// or unreadable, which the callers treat as "no curated content" rather
    /// than as an error worth surfacing — the rest of the app still works.
    @discardableResult
    func load() -> PlotlineDataset? {
        if didAttemptLoad { return cached }
        didAttemptLoad = true

        guard let url = Bundle.main.url(forResource: "PlotlineDataset", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(PlotlineDataset.self, from: data) else {
            #if DEBUG
            print("⚠️ DatasetStore: bundled dataset missing or unreadable")
            #endif
            return nil
        }

        guard decoded.version == PlotlineDataset.currentVersion else {
            #if DEBUG
            print("⚠️ DatasetStore: dataset version \(decoded.version) is not \(PlotlineDataset.currentVersion)")
            #endif
            return nil
        }

        cached = decoded
        index = Dictionary(uniqueKeysWithValues: decoded.entries.map { ($0.tmdbId, $0) })
        return decoded
    }

    var entries: [DatasetEntry] {
        load()?.entries ?? []
    }

    var lists: [CuratedList] {
        load()?.lists ?? []
    }

    func entry(forTMDBId id: Int) -> DatasetEntry? {
        load()
        return index[id]
    }

    /// Resolves a list's ids to entries, preserving the list's order.
    func entries(for list: CuratedList) -> [DatasetEntry] {
        load()
        return list.tmdbIds.compactMap { index[$0] }
    }
}
```

- [ ] **Step 4: Ejecutar los tests**

Run: `xcodebuild -project Plotline.xcodeproj -scheme Plotline -destination 'platform=iOS Simulator,name=iPhone 17' test 2>/dev/null`
Expected: PASS, **81** tests (74 + 7).

- [ ] **Step 5: Commit**

```bash
git add Plotline/Services/DatasetStore.swift PlotlineTests/DatasetStoreTests.swift
git commit -m "feat: read the bundled analysis dataset"
```

---

## Task 2: Copy en inglés y conversión a `MediaItem`

Las vistas existentes (`MediaSection`, `MediaCard`, la navegación a detalle) hablan `MediaItem`. Convertir en vez de duplicar vistas mantiene una sola ruta de presentación.

**Files:**
- Create: `Plotline/Models/CuratedListCopy.swift`
- Create: `Plotline/Models/DatasetEntry+MediaItem.swift`
- Modify: `PlotlineTests/DatasetStoreTests.swift` (añadir un `@Suite` al final)

**Interfaces:**
- Consumes: `DatasetEntry`, `CuratedList`, `MediaItem`
- Produces:
  - `CuratedListCopy.title(for id: String) -> String?` y `.subtitle(for id: String) -> String?`
  - `DatasetEntry.asMediaItem: MediaItem`

- [ ] **Step 1: Escribir los tests que fallan**

Añadir al final de `PlotlineTests/DatasetStoreTests.swift`:

```swift
@Suite("Dataset presentation")
struct DatasetPresentationTests {
    @Test("every shipped list has English copy")
    func everyListHasCopy() {
        // A shelf with no title cannot be rendered, so a dataset id with no
        // copy is a shipping defect, not a fallback case.
        for list in DatasetStore.shared.lists {
            #expect(CuratedListCopy.title(for: list.id) != nil, "no title for \(list.id)")
            #expect(CuratedListCopy.subtitle(for: list.id) != nil, "no subtitle for \(list.id)")
        }
    }

    @Test("an unknown list id has no copy")
    func unknownIdHasNoCopy() {
        #expect(CuratedListCopy.title(for: "not-a-list") == nil)
    }

    @Test("an entry converts to a MediaItem the existing views can render")
    func convertsToMediaItem() throws {
        let entry = try #require(DatasetStore.shared.entries.first)
        let item = entry.asMediaItem

        #expect(item.id == entry.tmdbId)
        #expect(item.displayTitle == entry.name)
        #expect(item.isTVSeries)
        #expect(item.posterPath == entry.posterPath)
        #expect(item.voteAverage == entry.voteAverage)
    }

    @Test("converted items carry the genres the taste profile needs")
    func conversionKeepsGenres() throws {
        let entry = try #require(DatasetStore.shared.entries.first { !$0.genreIds.isEmpty })
        #expect(entry.asMediaItem.genreIds == entry.genreIds)
    }
}
```

- [ ] **Step 2: Ejecutar para verificar que falla**

Run: `xcodebuild -project Plotline.xcodeproj -scheme Plotline -destination 'platform=iOS Simulator,name=iPhone 17' test 2>/dev/null`
Expected: FAIL de compilación, `cannot find 'CuratedListCopy' in scope`.

- [ ] **Step 3: Escribir el copy**

Crear `Plotline/Models/CuratedListCopy.swift`:

```swift
import Foundation

/// English copy for the dataset's curated list ids.
///
/// The dataset carries ids and members, never words: UI copy belongs to the
/// app, and keeping it here leaves the door open to real localisation later.
enum CuratedListCopy {
    private static let copy: [String: (title: String, subtitle: String)] = [
        "never-decline": (
            "Shows That Never Slip",
            "They hold their level from first season to last"
        ),
        "perfect-ending": (
            "They Stick the Landing",
            "Series that finish at their very best"
        ),
        "slow-burn": (
            "Worth the Wait",
            "Slow to start, and then they take off"
        ),
        "falls-off": (
            "Knows When It Peaked",
            "Great early on, and the numbers show where it turned"
        ),
        "rollercoaster": (
            "Brilliant and Baffling",
            "Unforgettable episodes sitting next to forgettable ones"
        )
    ]

    static func title(for id: String) -> String? { copy[id]?.title }
    static func subtitle(for id: String) -> String? { copy[id]?.subtitle }
}
```

- [ ] **Step 4: Escribir la conversión**

Crear `Plotline/Models/DatasetEntry+MediaItem.swift`:

```swift
import Foundation

extension DatasetEntry {
    /// Presents a dataset entry through the app's existing media type, so the
    /// bundled content reuses the same cards, sections and navigation as
    /// everything fetched from the network.
    ///
    /// `voteCount` is zero because the dataset does not carry a series-level
    /// count — it is only used for display ordering, never for the analysis,
    /// which does its own vote weighting per episode.
    var asMediaItem: MediaItem {
        MediaItem(
            id: tmdbId,
            overview: overview,
            posterPath: posterPath,
            backdropPath: backdropPath,
            voteAverage: voteAverage,
            voteCount: 0,
            genreIds: genreIds,
            title: nil,
            releaseDate: nil,
            name: name,
            firstAirDate: firstAirDate,
            mediaType: .tv
        )
    }
}
```

- [ ] **Step 5: Ejecutar los tests**

Run: `xcodebuild -project Plotline.xcodeproj -scheme Plotline -destination 'platform=iOS Simulator,name=iPhone 17' test 2>/dev/null`
Expected: PASS, **85** tests (81 + 4).

- [ ] **Step 6: Commit**

```bash
git add Plotline/Models/CuratedListCopy.swift Plotline/Models/DatasetEntry+MediaItem.swift PlotlineTests/DatasetStoreTests.swift
git commit -m "feat: add English copy and MediaItem conversion for dataset entries"
```

---

## Task 3: Estantes curados en Discover

**Files:**
- Modify: `Plotline/Views/Discovery/DiscoveryView.swift`

**Interfaces:**
- Consumes: `DatasetStore.shared`, `CuratedListCopy`, `DatasetEntry.asMediaItem`, `MediaSection(title:items:style:)`
- Produces: nada que consuman otras tareas

**Dónde van.** En el `LazyVStack` del cuerpo principal, **antes** de `MediaSection(title: "Trending Movies", ...)`. Esa es la decisión que importa: los estantes curados son contenido propio de Plotline y aparecen sin red; el trending viene de TMDB y puede tardar o fallar. Poner lo propio primero es lo que hace que la app tenga algo que enseñar en el primer segundo.

- [ ] **Step 1: Añadir la sección de estantes curados**

En `Plotline/Views/Discovery/DiscoveryView.swift`, dentro del `LazyVStack(alignment: .leading, spacing: 28)`, insertar justo **antes** de la línea `MediaSection(title: "Trending Movies", items: viewModel.trendingMovies)`:

```swift
                    curatedShelves
```

Y añadir la propiedad, junto a las demás secciones privadas de la vista:

```swift
    // MARK: - Curated Shelves

    /// Plotline's own analysis, shipped in the bundle. These render instantly,
    /// with no network and no user data, which is what keeps the first launch
    /// from being an empty screen.
    @ViewBuilder
    private var curatedShelves: some View {
        ForEach(DatasetStore.shared.lists) { list in
            if let title = CuratedListCopy.title(for: list.id) {
                VStack(alignment: .leading, spacing: 4) {
                    MediaSection(
                        title: title,
                        items: DatasetStore.shared.entries(for: list).map(\.asMediaItem)
                    )

                    if let subtitle = CuratedListCopy.subtitle(for: list.id) {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel(title)
                .accessibilityHint(CuratedListCopy.subtitle(for: list.id) ?? "")
            }
        }
    }
```

**Nota:** la lista sin copy se omite en silencio en vez de renderizar un estante sin título. La Tarea 2 tiene un test que garantiza que toda lista publicada tiene copy, así que en la práctica no ocurre — el `if let` es la red por si el dataset se regenera con un id nuevo antes de que alguien añada su texto.

- [ ] **Step 2: Compilar y verificar en el simulador**

```bash
xcodebuild -project Plotline.xcodeproj -scheme Plotline -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath build build && \
xcrun simctl install booted build/Build/Products/Debug-iphonesimulator/Plotline.app && \
xcrun simctl launch booted com.jbgsoft.Plotline
```

Expected: BUILD SUCCEEDED, y Discover muestra los estantes curados por encima del trending. Comprobar en modo claro **y** oscuro.

**Comprobar además con el modo avión activado** en el simulador (Settings → Airplane Mode, o `xcrun simctl status_bar booted override --dataNetwork hide`): los estantes curados deben seguir apareciendo, porque no dependen de la red. Si desaparecen, algo los ató a una petición y hay que deshacerlo — es el punto entero de la fase.

- [ ] **Step 3: Ejecutar la suite**

Run: `xcodebuild -project Plotline.xcodeproj -scheme Plotline -destination 'platform=iOS Simulator,name=iPhone 17' test 2>/dev/null`
Expected: `** TEST SUCCEEDED **`, 85 tests, sin cambio.

- [ ] **Step 4: Commit**

```bash
git add Plotline/Views/Discovery/DiscoveryView.swift
git commit -m "feat: show the bundled curated shelves on Discover

They render with no network and no user data, so the first launch has
Plotline's own content before anything is fetched."
```

---

## Task 4: Invertir el gating de Stats

**Este es el defecto que causó el rechazo.** `StatsView` envuelve la pestaña entera en `if viewModel.isEmpty`, de modo que Compare, Career Profiles y Trends — que **no dependen de datos del usuario**, son análisis sobre TMDB — quedan inalcanzables hasta que el usuario añade un favorito. El revisor de App Store nunca los vio.

**Files:**
- Modify: `Plotline/Views/Stats/StatsView.swift`

**Interfaces:**
- Consumes: nada nuevo
- Produces: nada que consuman otras tareas

- [ ] **Step 1: Quitar el gating de nivel pestaña**

En `Plotline/Views/Stats/StatsView.swift`, reemplazar el `Group` del `body`:

```swift
            Group {
                if viewModel.isEmpty {
                    emptyState
                } else {
                    statsContent
                }
            }
```

por:

```swift
            statsContent
```

- [ ] **Step 2: Convertir el estado vacío en una sección más**

`statsContent` empieza con `overviewCards`, `mediaTypeSplit` y `ratingDistribution`, que sí necesitan datos del usuario. Envolverlos y ofrecer la invitación en su lugar. Reemplazar el principio del `VStack` dentro de `statsContent`:

```swift
            VStack(spacing: 20) {
                overviewCards
                mediaTypeSplit
                ratingDistribution
```

por:

```swift
            VStack(spacing: 20) {
                if viewModel.isEmpty {
                    myStatsInvitation
                } else {
                    overviewCards
                    mediaTypeSplit
                    ratingDistribution
                }
```

- [ ] **Step 3: Reescribir el estado vacío como invitación compacta**

Reemplazar la propiedad `emptyState` completa:

```swift
    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView(
            "No Stats Yet",
            systemImage: "chart.bar.fill",
            description: Text("Add favorites and watchlist items to see your personal analytics.")
        )
    }
```

por:

```swift
    // MARK: - My Stats Invitation

    /// Shown in place of the personal charts until the user has saved anything.
    ///
    /// It is one section, not the whole tab. Everything below it — Compare,
    /// Career Profiles, Trends — analyses TMDB rather than the user's library
    /// and works from the very first launch. Hiding all of it behind an empty
    /// state is what made an App Store reviewer conclude the app had nothing in
    /// it.
    private var myStatsInvitation: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Stats")
                .font(.headline)
                .foregroundStyle(.primary)

            HStack(spacing: 12) {
                Image(systemName: "chart.bar.fill")
                    .font(.title2)
                    .foregroundStyle(Color.plotlineSecondaryAccent)

                Text("Save a few favorites and this fills up with your own viewing patterns. Everything below works right now.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.plotlineCard)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Your stats are empty. Save favorites to fill this section. The rest of the tab works now.")
    }
```

- [ ] **Step 4: Comprobar que nada más dependía del gating**

```bash
grep -n "viewModel.isEmpty\|emptyState" Plotline/Views/Stats/StatsView.swift
```
Expected: una sola referencia a `viewModel.isEmpty`, la de la Tarea 2. Ninguna a `emptyState`. Si queda alguna, se olvidó una ruta.

- [ ] **Step 5: Compilar y verificar en el simulador**

```bash
xcodebuild -project Plotline.xcodeproj -scheme Plotline -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath build build && \
xcrun simctl install booted build/Build/Products/Debug-iphonesimulator/Plotline.app && \
xcrun simctl launch booted com.jbgsoft.Plotline
```

**Con la app recién instalada y sin ningún favorito**, abrir la pestaña Stats y comprobar que se ven Compare, Career Profiles y Trends, con la invitación compacta arriba en lugar de la pantalla vacía. Comprobar en claro y oscuro.

Si hay favoritos de una instalación anterior, desinstalar primero con `xcrun simctl uninstall booted com.jbgsoft.Plotline`. **Comprobar esto sobre una instalación con datos no verifica nada**: el defecto solo aparece en frío.

- [ ] **Step 6: Ejecutar la suite y commitear**

Run: `xcodebuild -project Plotline.xcodeproj -scheme Plotline -destination 'platform=iOS Simulator,name=iPhone 17' test 2>/dev/null`
Expected: `** TEST SUCCEEDED **`, 85 tests.

```bash
git add Plotline/Views/Stats/StatsView.swift
git commit -m "fix: stop hiding the whole Stats tab behind an empty state

Compare, Career Profiles and Trends analyse TMDB, not the user's
library, and worked from the first launch — but the tab wrapped all of
them in a check for saved favorites, so an App Store reviewer on a clean
install saw only 'No Stats Yet'. The personal charts now yield to a
compact invitation and everything else stays visible."
```

---

## Task 5: Estados vacíos con sugerencias reales

**Files:**
- Modify: `Plotline/Views/Favorites/FavoritesView.swift`
- Modify: `Plotline/Views/Favorites/WatchlistView.swift`
- Create: `Plotline/Views/Components/SuggestionsEmptyState.swift`

**Interfaces:**
- Consumes: `DatasetStore.shared`, `DatasetEntry.asMediaItem`, `MediaSection(title:items:style:)`
- Produces: `SuggestionsEmptyState(title:message:systemImage:)`

**La idea.** Una pantalla vacía que sugiere títulos reales deja de ser una pantalla vacía. Las sugerencias salen del dataset, así que aparecen sin red y sin datos del usuario.

- [ ] **Step 1: Escribir el componente compartido**

Crear `Plotline/Views/Components/SuggestionsEmptyState.swift`:

```swift
import SwiftUI

/// An empty state that offers something to look at instead of an apology.
///
/// The suggestions come from the bundled dataset, so this renders with no
/// network and no saved data — which is the difference between a screen that
/// looks broken and one that looks like it has content.
struct SuggestionsEmptyState: View {
    let title: String
    let message: String
    let systemImage: String

    private var suggestions: [MediaItem] {
        // Highest-scoring series first: if we are going to suggest anything
        // unprompted, suggest what the analysis rates best.
        DatasetStore.shared.entries
            .sorted { $0.analysis.score.value > $1.analysis.score.value }
            .prefix(12)
            .map(\.asMediaItem)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(spacing: 12) {
                    Image(systemName: systemImage)
                        .font(.system(size: 44))
                        .foregroundStyle(.secondary)

                    Text(title)
                        .font(.system(.title3, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
                .padding(.horizontal)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(title). \(message)")

                if !suggestions.isEmpty {
                    MediaSection(title: "Highest Rated by Plotline", items: suggestions)
                }
            }
            .padding(.vertical)
        }
    }
}
```

- [ ] **Step 2: Usarlo en Favorites**

En `Plotline/Views/Favorites/FavoritesView.swift`, reemplazar el cuerpo de la propiedad `emptyStateView` por:

```swift
    private var emptyStateView: some View {
        SuggestionsEmptyState(
            title: "No Favorites Yet",
            message: "Tap the heart on anything you love and it lands here.",
            systemImage: "heart"
        )
    }
```

Conservar el nombre `emptyStateView` para no tocar su punto de uso.

- [ ] **Step 3: Usarlo en Watchlist**

En `Plotline/Views/Favorites/WatchlistView.swift`, reemplazar el cuerpo de `emptyStateView` (línea 157) por:

```swift
    private var emptyStateView: some View {
        SuggestionsEmptyState(
            title: "Nothing on Your List",
            message: "Add anything you mean to get to, and track what you have finished.",
            systemImage: "eye"
        )
    }
```

**No tocar `filteredEmptyStateView`** (línea 198). Ese es un caso distinto: el usuario sí tiene elementos, pero ninguno coincide con el filtro activo. "No Watched Items" ahí es la respuesta correcta, y sugerir series nuevas sería contestar a una pregunta que nadie hizo. El defecto que arregla esta fase es la pestaña **realmente** vacía.

- [ ] **Step 4: Compilar y verificar en el simulador**

```bash
xcrun simctl uninstall booted com.jbgsoft.Plotline
xcodebuild -project Plotline.xcodeproj -scheme Plotline -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath build build && \
xcrun simctl install booted build/Build/Products/Debug-iphonesimulator/Plotline.app && \
xcrun simctl launch booted com.jbgsoft.Plotline
```

**Con la app recién instalada**, abrir Favorites y Watchlist: las dos deben mostrar sugerencias reales con póster, no un icono y una frase. Comprobar en claro y oscuro.

- [ ] **Step 5: Ejecutar la suite y commitear**

Run: `xcodebuild -project Plotline.xcodeproj -scheme Plotline -destination 'platform=iOS Simulator,name=iPhone 17' test 2>/dev/null`
Expected: `** TEST SUCCEEDED **`, 85 tests.

```bash
git add Plotline/Views/Components/SuggestionsEmptyState.swift Plotline/Views/Favorites/FavoritesView.swift Plotline/Views/Favorites/WatchlistView.swift
git commit -m "feat: suggest real titles instead of empty states

Favorites and Watchlist opened on an icon and an apology. They now offer
the highest-scoring series from the bundled dataset, which needs neither
network nor saved data."
```

---

## Task 6: El test de regresión del rechazo

Ninguna de las 85 pruebas actuales habría detectado el defecto original. Este es el que sí.

**Files:**
- Create: `PlotlineTests/ColdStartTests.swift`

**Interfaces:**
- Consumes: `DatasetStore`, `CuratedListCopy`
- Produces: nada

**Lo que puede y no puede cubrir.** El proyecto no tiene target de UI tests, así que esto no pulsa pestañas. Cubre la condición que **hace posible** que una pestaña esté vacía: que el contenido que no depende del usuario esté realmente disponible sin red y sin datos. El recorrido visual sigue siendo manual y está en la definición de terminado.

- [ ] **Step 1: Escribir los tests**

Crear `PlotlineTests/ColdStartTests.swift`:

```swift
import Foundation
import Testing
@testable import Plotline

/// Guards the defect that got the app rejected under Guideline 4.2.
///
/// App Review evaluates a clean install. The Stats tab wrapped everything —
/// including Compare, Career Profiles and Trends, none of which need user data
/// — in a check for saved favorites, so the reviewer saw an empty screen and
/// concluded the app had nothing in it. These assert the conditions that make
/// a first launch non-empty.
@Suite("Cold start")
struct ColdStartTests {
    @Test("curated content is available with no user data and no network")
    func curatedContentExistsOnAFreshInstall() {
        let store = DatasetStore.shared

        #expect(!store.entries.isEmpty)
        #expect(!store.lists.isEmpty)
    }

    @Test("every shelf that ships is renderable")
    func everyShelfIsRenderable() {
        let store = DatasetStore.shared

        for list in store.lists {
            // A shelf needs copy, and members that resolve, or it renders as
            // nothing — which is the emptiness this whole effort removes.
            #expect(CuratedListCopy.title(for: list.id) != nil, "\(list.id) has no title")
            #expect(!store.entries(for: list).isEmpty, "\(list.id) resolves to nothing")
        }
    }

    @Test("suggestions for the empty Favorites and Watchlist screens exist")
    func suggestionsExist() {
        let ranked = DatasetStore.shared.entries
            .sorted { $0.analysis.score.value > $1.analysis.score.value }
            .prefix(12)

        #expect(ranked.count == 12)
        #expect(ranked.allSatisfy { $0.posterPath != nil })
    }

    @Test("the shelves carry enough titles between them to fill a screen")
    func shelvesCarryEnoughTitles() {
        let total = DatasetStore.shared.lists.reduce(0) { $0 + $1.tmdbIds.count }
        #expect(total >= 40, "only \(total) titles across all shelves")
    }
}
```

- [ ] **Step 2: Ejecutar los tests**

Run: `xcodebuild -project Plotline.xcodeproj -scheme Plotline -destination 'platform=iOS Simulator,name=iPhone 17' test 2>/dev/null`
Expected: PASS, **89** tests (85 + 4).

- [ ] **Step 3: El recorrido manual completo**

Esto es lo que de verdad cierra la fase, y no lo puede hacer la suite.

```bash
xcrun simctl uninstall booted com.jbgsoft.Plotline
xcodebuild -project Plotline.xcodeproj -scheme Plotline -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath build build && \
xcrun simctl install booted build/Build/Products/Debug-iphonesimulator/Plotline.app && \
xcrun simctl launch booted com.jbgsoft.Plotline
```

Sobre esa instalación limpia, **sin añadir nada**, recorrer las cinco pestañas y anotar qué se ve en cada una:

| Pestaña | Debe verse |
|---|---|
| Discover | Estantes curados por encima del trending |
| Favorites | Sugerencias con póster |
| Watchlist | Sugerencias con póster |
| Stats | Compare, Career Profiles y Trends, con la invitación arriba |
| Settings | Los ajustes |

Repetir **en modo oscuro** y **con el modo avión activado**. Sin red, las cuatro primeras deben seguir mostrando contenido: es el escenario exacto del revisor si la red del edificio de Apple se porta mal, y el que convierte "no hay suficiente contenido" en una afirmación falsa.

Anotar el resultado real en el informe, incluido cualquier hueco. **Si alguna pestaña sigue vacía, la fase no está hecha**, por muchos tests que pasen.

- [ ] **Step 4: Commit**

```bash
git add PlotlineTests/ColdStartTests.swift
git commit -m "test: guard the cold-start emptiness that caused the 4.2 rejection"
```

---

## Definición de terminado

- [ ] 89 tests pasando
- [ ] Las cinco pestañas muestran contenido en una instalación limpia **sin red**
- [ ] Verificado en modo claro y oscuro
- [ ] `StatsView` ya no envuelve la pestaña en una comprobación de datos del usuario
- [ ] Ningún texto de UI nuevo en español
- [ ] `project.pbxproj` e `Info.plist` sin tocar

## Notas para la fase siguiente

- El análisis por serie (punto de declive, consistencia, episodios imprescindibles, Plotline Score) **sigue sin mostrarse en ninguna parte**. Está en el dataset y lo calcula el motor, pero la ficha de detalle no lo pinta. Ese es el argumento más fuerte contra el 4.2 y le toca a la fase siguiente, junto con el "dónde verlo" del spec §7.
- Al mostrar el veredicto de cierre, recordar dos residuos de la Fase 2 (`docs/superpowers/specs/2026-08-03-phase-2-residuals.md`): `isOngoing == false` significa "terminada **o** desconocida" y no debe renderizarse como "Ended"; y `bestSeason` puede coincidir con `worstSeason`.
- Con las reglas actuales Los Simpson **no** salen como decaídos: cayeron y se recuperaron parcialmente, y la regla exige que la caída se mantenga. La ficha ganaría mostrando ambas cosas — punto de caída y recuperación — en vez de obligar a elegir.
