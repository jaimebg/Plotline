# Fase 7 — Dónde verlo

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Que la ficha diga en qué plataformas se puede ver un título, en la región del usuario y en cualquier otra que elija.

**Architecture:** Un endpoint de TMDB devuelve, por título, un diccionario de 126 regiones con los proveedores de cada una. La app resuelve la región del `Locale`, permite cambiarla, cachea la respuesta en disco y la muestra con la atribución que TMDB exige.

**Tech Stack:** SwiftUI, iOS 26, Swift Testing.

**Spec:** `docs/superpowers/specs/2026-08-01-app-store-4.2-design.md` §7.

## La restricción que manda sobre todo lo demás

TMDB lo dice literalmente en la referencia del endpoint:

> "In order to use this data you must attribute the source of the data as **JustWatch**."
>
> "If we find any usage not complying with these terms we will revoke access to the API."

Desde la Fase 1 **la app entera corre sobre TMDB**: sin esa API no hay catálogo, ni búsqueda, ni episodios, ni imágenes. Perder el acceso no degrada una función, apaga el producto.

Así que la atribución no es el remate de esta fase, es su requisito bloqueante. **La vista no puede renderizar un solo proveedor sin nombrar a JustWatch como fuente**, y eso se estructura en el código, no se recuerda: la atribución vive dentro de la misma vista que dibuja los proveedores, no en una llamada aparte que alguien pueda olvidar.

Corrección de lo que decía el spec: §7 afirmaba que la atribución se exige "en cada elemento". La exigencia real, citada arriba, es atribuir la fuente de los datos. Atribuir dentro de la sección que los muestra la cumple; decir "por elemento" era una exageración mía y no hay que diseñar contra ella.

## Lo que la API da y lo que no

Verificado contra la API real, no supuesto:

```
GET /tv/1396/watch/providers  →  { "id": 1396, "results": { "ES": {...}, "US": {...}, ... } }
```

- **126 regiones** en la respuesta de Breaking Bad; el endpoint de regiones lista **139** en total.
- Cada región trae `link` y, **opcionalmente**, `flatrate`, `rent`, `buy`, `free` y `ads`. España para Breaking Bad trae `link` y `flatrate` y nada más: las cinco listas son opcionales de verdad, no por precaución.
- Cada proveedor: `provider_id`, `provider_name`, `logo_path`, `display_priority`.
- **No hay deep links por plataforma.** El `link` de cada región apunta a la página de TMDB del título (`themoviedb.org/tv/1396-breaking-bad/watch?locale=ES`), no a la app de Netflix. El spec pedía "deep link a la plataforma correspondiente" y el endpoint no lo da: lo alcanzable es abrir esa página.
- `logo_path` se sirve desde `https://image.tmdb.org/t/p/w92{logo_path}`, la misma base que ya usa `MediaItem.posterURL`.

## Global Constraints

- Deployment target iOS 26.0. **Swift 5 language mode.** No migración a Swift 6.
- **La atribución a JustWatch es bloqueante.** Ninguna tarea puede entregar una vista que muestre proveedores sin ella.
- Los view models usan `@Observable`.
- **Nunca `.white` para texto** — `.primary` / `.secondary`. **Nunca fondos oscuros hardcodeados** — `Color.plotlineBackground` / `Color.plotlineCard`. Claro y oscuro.
- **Todo el texto de UI en inglés.**
- **Nunca editar `Plotline.xcodeproj/project.pbxproj` ni `Plotline/Info.plist`.** Los `.swift` nuevos bajo `Plotline/` y `PlotlineTests/` entran solos en el target.
- No modificar `Plotline/Models/EpisodeMetric.swift`, `Plotline/Models/SeriesAnalysis.swift`, `Plotline/Models/PlotlineDataset.swift` ni `Plotline/Services/Analysis/SeriesAnalysisEngine.swift` — los comparte por symlink el generador y solo pueden importar `Foundation`.
- **Nunca imprimir ni commitear la clave de TMDB.** `Plotline/Secrets.plist` está en `.gitignore`. Ninguna tarea necesita leerla.
- **Nada puede empeorar el iPhone**, que es el dispositivo principal. Se verifica en iPhone y en iPad.
- Commits en Conventional Commits, en inglés.
- Punto de partida: la suite está en verde, `TEST SUCCEEDED`, 0 fallos.

**Comandos:**

```bash
xcodebuild -project Plotline.xcodeproj -scheme Plotline \
  -destination 'platform=iOS Simulator,name=iPhone 17' test 2>/dev/null

xcodebuild -project Plotline.xcodeproj -scheme Plotline \
  -destination 'platform=iOS Simulator,name=iPad Air 11-inch (M4)' -derivedDataPath build build
```

El recuento de líneas `passed` se lee alto porque los tests parametrizados registran una línea por caso. **Lo que decide es `TEST SUCCEEDED` con cero líneas `failed`.**

**Trampa de entorno:** `Application failed preflight checks` o `Busy` es el simulador. `xcrun simctl uninstall booted com.jbgsoft.Plotline` y repetir una vez. **Nunca cambiar código por ese error.**

---

## Estructura de archivos

| Archivo | Responsabilidad | Acción |
|---|---|---|
| `Plotline/Models/APIResponses/WatchProvidersResponse.swift` | Decodificar el diccionario por región | Crear (Tarea 1) |
| `Plotline/Services/WatchRegionStore.swift` | Región efectiva: `Locale` con override persistido | Crear (Tarea 2) |
| `Plotline/Services/TMDBService.swift` | La petición y su caché | Modificar (Tarea 2) |
| `Plotline/Views/Detail/WatchProvidersSection.swift` | Proveedores, atribución, selector de región | Crear (Tarea 3) |
| `Plotline/ViewModels/MediaDetailViewModel.swift` | Cargar disponibilidad y reaccionar al cambio de región | Modificar (Tarea 4) |
| `Plotline/Views/Detail/MediaDetailView.swift` | Colocar la sección | Modificar (Tarea 4) |
| `PlotlineTests/WatchProvidersTests.swift` | Decodificación y regiones ausentes | Crear (Tarea 1) |
| `PlotlineTests/WatchRegionTests.swift` | Resolución y persistencia de región | Crear (Tarea 2) |
| `PlotlineTests/WatchAttributionTests.swift` | Que la atribución no se pueda perder | Crear (Tarea 3) |

---

## Task 1: El modelo de disponibilidad

**Files:**
- Create: `Plotline/Models/APIResponses/WatchProvidersResponse.swift`
- Create: `PlotlineTests/WatchProvidersTests.swift`

**Interfaces:**
- Produces: `WatchProvidersResponse` con `id: Int` y `results: [String: RegionAvailability]`; `RegionAvailability` con `link: String?`, `flatrate/rent/buy/free/ads: [WatchProvider]?` y `var isEmpty: Bool`; `WatchProvider` con `providerId: Int`, `providerName: String`, `logoPath: String?`, `displayPriority: Int?` y `var logoURL: URL?`

**Lo que hay que respetar del payload real.** Las cinco listas son opcionales y de verdad faltan: España para Breaking Bad trae solo `link` y `flatrate`. Un `[WatchProvider]` no opcional haría fallar la decodificación de la mayoría de regiones.

El decodificador de la app usa `keyDecodingStrategy = .convertFromSnakeCase`, así que `provider_name` llega como `providerName` sin `CodingKeys`. **Cuidado con `results`:** sus claves son códigos de región (`"ES"`, `"US"`, `"GB"`) y esa estrategia también las transformaría si no fueran mayúsculas — como lo son, pasan intactas. Añade un test que lo demuestre en vez de confiar en ello.

- [ ] **Step 1: Escribir los tests que fallan**

Crear `PlotlineTests/WatchProvidersTests.swift`:

```swift
import Foundation
import Testing
@testable import Plotline

@Suite("Watch providers")
struct WatchProvidersTests {
    /// Trimmed from the real response for Breaking Bad. Spain carries only
    /// `link` and `flatrate`; the United States adds `buy`. That asymmetry is
    /// the point — every category is genuinely optional.
    private let json = Data("""
    {
      "id": 1396,
      "results": {
        "ES": {
          "link": "https://www.themoviedb.org/tv/1396/watch?locale=ES",
          "flatrate": [
            {"logo_path": "/pbpMk2JmcoNnQwx5JGpXngfoWtp.jpg", "provider_id": 8, "provider_name": "Netflix", "display_priority": 0}
          ]
        },
        "US": {
          "link": "https://www.themoviedb.org/tv/1396/watch?locale=US",
          "flatrate": [
            {"logo_path": "/pbpMk2JmcoNnQwx5JGpXngfoWtp.jpg", "provider_id": 8, "provider_name": "Netflix", "display_priority": 0}
          ],
          "buy": [
            {"logo_path": "/seGSXajazLMCKGB5hnRCidtjay1.jpg", "provider_id": 2, "provider_name": "Apple TV", "display_priority": 3}
          ]
        }
      }
    }
    """.utf8)

    private func decoded() throws -> WatchProvidersResponse {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(WatchProvidersResponse.self, from: json)
    }

    /// Region codes are dictionary keys, not property names. If the snake-case
    /// strategy ever touched them, "ES" would stop resolving and every lookup
    /// would silently return nothing.
    @Test("region codes survive the snake-case decoding strategy")
    func regionKeysAreUntouched() throws {
        let response = try decoded()
        #expect(response.results["ES"] != nil)
        #expect(response.results["US"] != nil)
    }

    @Test("a region with only a subscription decodes without its other categories")
    func partialRegionDecodes() throws {
        let spain = try #require(try decoded().results["ES"])

        #expect(spain.flatrate?.count == 1)
        #expect(spain.flatrate?.first?.providerName == "Netflix")
        #expect(spain.rent == nil)
        #expect(spain.buy == nil)
    }

    @Test("a region with more than one category keeps them apart")
    func fullRegionDecodes() throws {
        let us = try #require(try decoded().results["US"])

        #expect(us.flatrate?.first?.providerName == "Netflix")
        #expect(us.buy?.first?.providerName == "Apple TV")
    }

    @Test("a region the title is not available in is simply absent")
    func unknownRegionIsAbsent() throws {
        #expect(try decoded().results["JP"] == nil)
    }

    /// A region can come back carrying a link and nothing else. Rendering that
    /// as a section with a heading and no rows would look broken.
    @Test("a region with a link but no providers reports itself empty")
    func linkOnlyRegionIsEmpty() throws {
        let bare = Data("""
        {"id": 1, "results": {"ES": {"link": "https://example.com"}}}
        """.utf8)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let response = try decoder.decode(WatchProvidersResponse.self, from: bare)

        #expect(try #require(response.results["ES"]).isEmpty)
    }

    @Test("a provider builds a logo URL from the same host as the posters")
    func logoURLIsBuilt() throws {
        let provider = try #require(try decoded().results["ES"]?.flatrate?.first)
        let url = try #require(provider.logoURL)

        #expect(url.absoluteString == "https://image.tmdb.org/t/p/w92/pbpMk2JmcoNnQwx5JGpXngfoWtp.jpg")
    }
}
```

- [ ] **Step 2: Ejecutar para verificar que falla**

Run: el comando de tests.
Expected: FAIL de compilación, `cannot find 'WatchProvidersResponse' in scope`.

- [ ] **Step 3: Escribir el modelo**

Crear `Plotline/Models/APIResponses/WatchProvidersResponse.swift`:

```swift
import Foundation

/// Where a title can be watched, by region.
///
/// TMDB returns one entry per region — 126 of them for a well-known series —
/// keyed by ISO 3166-1 code. The data behind it comes from JustWatch, which
/// TMDB requires be credited wherever it is shown; `WatchProvidersSection`
/// carries that credit.
struct WatchProvidersResponse: Decodable {
    let id: Int
    let results: [String: RegionAvailability]
}

/// What is on offer in one region.
///
/// Every category is optional and they genuinely go missing: Spain carries a
/// subscription entry for Breaking Bad and no purchase or rental at all.
struct RegionAvailability: Decodable, Hashable {
    /// TMDB's own watch page for this title and region.
    ///
    /// The only link the endpoint offers — there are no per-platform deep
    /// links, so this cannot open Netflix directly.
    let link: String?

    /// Included with a subscription.
    let flatrate: [WatchProvider]?
    let rent: [WatchProvider]?
    let buy: [WatchProvider]?
    /// Free, with no subscription required.
    let free: [WatchProvider]?
    /// Free with advertising.
    let ads: [WatchProvider]?

    /// True when the region carries no provider at all in any category.
    ///
    /// A region can come back with a link and nothing else, and a section with
    /// a heading and no rows reads as a broken screen rather than an answer.
    var isEmpty: Bool {
        [flatrate, rent, buy, free, ads].allSatisfy { $0?.isEmpty ?? true }
    }
}

/// One streaming service.
struct WatchProvider: Decodable, Hashable, Identifiable {
    var id: Int { providerId }

    let providerId: Int
    let providerName: String
    let logoPath: String?
    /// TMDB's own ordering hint, lowest first.
    let displayPriority: Int?

    var logoURL: URL? {
        guard let logoPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w92\(logoPath)")
    }
}
```

- [ ] **Step 4: Ejecutar los tests**

Run: el comando de tests.
Expected: `TEST SUCCEEDED`, 0 fallos, seis tests nuevos.

- [ ] **Step 5: Commit**

```bash
git add Plotline/Models/APIResponses/WatchProvidersResponse.swift PlotlineTests/WatchProvidersTests.swift
git commit -m "feat: model TMDB's per-region watch availability

Every category is optional and they genuinely go missing — Spain carries
a subscription entry for Breaking Bad and nothing else."
```

---

## Task 2: La región y la petición

**Files:**
- Create: `Plotline/Services/WatchRegionStore.swift`
- Modify: `Plotline/Services/TMDBService.swift`
- Create: `PlotlineTests/WatchRegionTests.swift`

**Interfaces:**
- Consumes: `WatchProvidersResponse` (Tarea 1), `TMDBService.baseURL`/`apiKey` privados existentes, `DiskCache`
- Produces: `WatchRegionStore` (`@MainActor final class`, `static let shared`, `var selected: String`, `static let fallbackRegion = "US"`, `static func systemRegion(from:) -> String?`, `func reset()`) y `TMDBService.fetchWatchProviders(mediaType:id:) async throws -> [String: RegionAvailability]`

**Por qué la región necesita un selector y no solo el `Locale`.** El spec lo dice y el rechazo lo respalda: el revisor puede estar en otra región que quien desarrolla. Un título disponible en España y no en Estados Unidos le mostraría una sección vacía, que es exactamente la impresión que hundió la versión 1.3.0.

**Reglas de resolución:**
1. Si el usuario eligió una región, esa manda.
2. Si no, la del `Locale` del sistema, **solo si TMDB la conoce**.
3. Si no, `US`, que es la región con más cobertura.

`WatchRegionStore` es `@MainActor final class` con `static let shared`, igual que `DatasetStore`: **no** `@Observable`. Toda suite de test que lo toque debe ser `@MainActor` o no compila.

**Sobre la caché.** La disponibilidad cambia, pero no cada hora. Usa una instancia propia de `DiskCache` con `maxAge` de **24 horas** y clave `"watch-providers-<mediaType>-<id>"`. Se cachea **la respuesta entera**, con sus 126 regiones, no la región seleccionada: cambiar de región no debe disparar otra petición.

- [ ] **Step 1: Escribir los tests que fallan**

Crear `PlotlineTests/WatchRegionTests.swift`:

```swift
import Foundation
import Testing
@testable import Plotline

@MainActor
@Suite("Watch region")
struct WatchRegionTests {
    @Test("a known system region is used as-is")
    func knownSystemRegionWins() {
        #expect(WatchRegionStore.systemRegion(from: Locale(identifier: "es_ES")) == "ES")
        #expect(WatchRegionStore.systemRegion(from: Locale(identifier: "en_GB")) == "GB")
    }

    /// A locale with no region at all must not produce an empty string, which
    /// would build a lookup key that matches nothing.
    @Test("a locale with no region yields nothing rather than an empty code")
    func regionlessLocaleYieldsNil() {
        #expect(WatchRegionStore.systemRegion(from: Locale(identifier: "eo")) == nil)
    }

    @Test("the fallback is a region TMDB actually covers")
    func fallbackIsCovered() {
        #expect(WatchRegionStore.fallbackRegion == "US")
    }

    @Test("a chosen region survives a new store")
    func selectionPersists() {
        let store = WatchRegionStore.shared
        let original = store.selected

        store.selected = "JP"
        #expect(WatchRegionStore.shared.selected == "JP")

        store.selected = original
    }

    @Test("resetting returns to the system region")
    func resetReturnsToSystem() {
        let store = WatchRegionStore.shared
        let original = store.selected

        store.selected = "JP"
        store.reset()
        #expect(store.selected != "JP" || WatchRegionStore.systemRegion(from: .current) == "JP")

        store.selected = original
    }
}
```

**Si `resetReturnsToSystem` te parece que no puede fallar de forma útil**, dilo en el informe y propón una forma mejor de expresarlo — su condición es defensiva porque la región del sistema del simulador es desconocida de antemano. No lo dejes pasando por casualidad.

- [ ] **Step 2: Ejecutar para verificar que falla**

Expected: FAIL de compilación, `cannot find 'WatchRegionStore' in scope`.

- [ ] **Step 3: Escribir el store**

Crear `Plotline/Services/WatchRegionStore.swift`:

```swift
import Foundation

/// Which region's streaming availability to show.
///
/// App Review runs from wherever App Review happens to be, which is not where
/// this app was built. A title available in Spain and not in the United States
/// would show a reviewer an empty section — the impression that got version
/// 1.3.0 rejected — so the region is both detected and selectable.
@MainActor
final class WatchRegionStore {
    static let shared = WatchRegionStore()

    /// Used when the system region is unknown or absent. The United States has
    /// the widest coverage in TMDB's data.
    static let fallbackRegion = "US"

    private static let storageKey = "watch_region_override"

    private(set) var selectedOverride: String?

    /// The region in force: the user's choice, else the system's, else the
    /// fallback.
    var selected: String {
        get { selectedOverride ?? Self.systemRegion(from: .current) ?? Self.fallbackRegion }
        set {
            selectedOverride = newValue
            UserDefaults.standard.set(newValue, forKey: Self.storageKey)
        }
    }

    /// The region of a locale, when it names one.
    ///
    /// Returns nil rather than an empty string for a locale with no region:
    /// an empty code would build a lookup key that matches no region at all,
    /// and the section would go blank with nothing to explain it.
    static func systemRegion(from locale: Locale) -> String? {
        guard let region = locale.region?.identifier, !region.isEmpty else { return nil }
        return region
    }

    /// Drops the user's choice and returns to the system region.
    func reset() {
        selectedOverride = nil
        UserDefaults.standard.removeObject(forKey: Self.storageKey)
    }

    private init() {
        selectedOverride = UserDefaults.standard.string(forKey: Self.storageKey)
    }
}
```

- [ ] **Step 4: Añadir la petición al servicio**

En `Plotline/Services/TMDBService.swift`, junto a los demás métodos de fetch. Sigue el patrón que ya usan `fetchSeasonEpisodes` y compañía para construir la URL — **no inventes uno nuevo**, y no dupliques la clave de API en el código:

```swift
    /// Where a title can be watched, by region.
    ///
    /// The whole response is cached, all 126 regions of it, so switching
    /// region costs nothing. Availability moves, but not by the hour, so a day
    /// is long enough.
    ///
    /// The data comes from JustWatch and TMDB requires it be credited wherever
    /// it is shown — see `WatchProvidersSection`.
    func fetchWatchProviders(mediaType: MediaType, id: Int) async throws -> [String: RegionAvailability] {
        let cacheKey = "watch-providers-\(mediaType.rawValue)-\(id)"

        if let cached: WatchProvidersResponse = Self.watchProvidersCache.get(for: cacheKey) {
            return cached.results
        }

        let response: WatchProvidersResponse = try await fetch(
            path: "/\(mediaType.rawValue)/\(id)/watch/providers"
        )
        Self.watchProvidersCache.set(response, for: cacheKey)
        return response.results
    }
```

Y la caché junto a las demás propiedades estáticas del servicio:

```swift
    private static let watchProvidersCache = DiskCache(name: "watch-providers", maxAge: 60 * 60 * 24)
```

**Adapta la llamada al helper de red real del archivo.** El nombre `fetch(path:)` de arriba es ilustrativo: usa el que exista (mira cómo lo hace `fetchSeasonEpisodes`) y di en el informe cuál era. `WatchProvidersResponse` debe ser `Encodable` además de `Decodable` para poder cachearse — si `DiskCache.set` lo exige, añade la conformidad y dilo.

- [ ] **Step 5: Ejecutar los tests**

Expected: `TEST SUCCEEDED`, 0 fallos, cinco tests nuevos.

- [ ] **Step 6: Commit**

```bash
git add Plotline/Services/WatchRegionStore.swift Plotline/Services/TMDBService.swift PlotlineTests/WatchRegionTests.swift
git commit -m "feat: resolve a watch region and fetch availability for it

The region is selectable, not just detected: App Review runs from
somewhere else, and a title available here and not there would show a
reviewer the empty section that got 1.3.0 rejected."
```

---

## Task 3: La sección, con la atribución dentro

**Files:**
- Create: `Plotline/Views/Detail/WatchProvidersSection.swift`
- Create: `PlotlineTests/WatchAttributionTests.swift`

**Interfaces:**
- Consumes: `RegionAvailability`, `WatchProvider` (Tarea 1), `WatchRegionStore` (Tarea 2)
- Produces: `WatchProvidersSection(availability:region:regions:onRegionChange:)` y `static let attribution: String`

**El requisito bloqueante, y cómo se estructura para que no se pueda perder.** La atribución vive **dentro del cuerpo de esta vista**, en la misma rama que dibuja los proveedores. No es un modificador que el punto de uso deba acordarse de aplicar, ni una vista hermana que otra tarea pueda colocar en otro sitio. Si hay proveedores en pantalla, la línea de JustWatch está en pantalla, porque las dibuja el mismo `VStack`.

El texto va en una constante estática para que un test pueda comprobar que nombra a JustWatch, y ese test es la red que impide que un cambio de copy la borre sin darse cuenta.

**Qué muestra:**

- Un grupo por categoría no vacía, en este orden: **Stream** (`flatrate`), **Free** (`free`), **With ads** (`ads`), **Rent** (`rent`), **Buy** (`buy`). Las vacías no se renderizan.
- Cada proveedor: logo (`AsyncImage`, con marcador mientras carga) y nombre.
- Dentro de cada categoría, ordenados por `displayPriority` ascendente; los que no lo traigan, al final. **No inventes un orden alfabético**: `displayPriority` es la señal que TMDB da.
- El selector de región, visible **siempre**, incluido cuando no hay nada disponible — es justo cuando más falta hace.
- Cuando la región no tiene proveedores: una frase que lo diga y el selector. **Nunca un hueco.**
- La atribución.

- [ ] **Step 1: Escribir el test de atribución**

Crear `PlotlineTests/WatchAttributionTests.swift`:

```swift
import Foundation
import Testing
@testable import Plotline

/// TMDB's terms for this endpoint: "In order to use this data you must
/// attribute the source of the data as JustWatch", and "if we find any usage
/// not complying with these terms we will revoke access to the API".
///
/// Every screen in this app is built on TMDB, so losing that access does not
/// degrade a feature — it turns the product off. This test is cheap insurance
/// against a copy edit quietly dropping the credit.
@Suite("Watch provider attribution")
struct WatchAttributionTests {
    @Test("the attribution names JustWatch")
    func attributionNamesJustWatch() {
        #expect(WatchProvidersSection.attribution.contains("JustWatch"))
    }

    @Test("the attribution says JustWatch is the source of the data")
    func attributionCreditsTheSource() {
        let text = WatchProvidersSection.attribution.lowercased()
        #expect(text.contains("justwatch"))
        // Naming them is required; naming them as the source is the point.
        #expect(text.contains("data") || text.contains("provided") || text.contains("source"))
    }
}
```

- [ ] **Step 2: Ejecutar para verificar que falla**

Expected: FAIL de compilación, `cannot find 'WatchProvidersSection' in scope`.

- [ ] **Step 3: Escribir la vista**

Crear `Plotline/Views/Detail/WatchProvidersSection.swift`. Estructura obligatoria — la atribución en el mismo `VStack` que los proveedores:

```swift
import SwiftUI

/// Where this title can be watched in one region.
///
/// The attribution below is not decoration. TMDB's terms for this endpoint
/// require JustWatch be credited as the source of the data, and state that
/// non-compliant usage has its API access revoked. Since every screen in this
/// app is served by TMDB, that would not degrade a feature — it would turn the
/// product off. The credit therefore lives in the same view that draws the
/// providers, not in a modifier a call site has to remember.
struct WatchProvidersSection: View {
    static let attribution = "Streaming data provided by JustWatch"

    let availability: RegionAvailability?
    let region: String
    let regions: [String]
    let onRegionChange: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if let availability, !availability.isEmpty {
                ForEach(categories(in: availability), id: \.title) { category in
                    group(title: category.title, providers: category.providers)
                }
            } else {
                unavailable
            }

            Text(Self.attribution)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // ... header with the region picker, group(title:providers:), unavailable,
    // and categories(in:) ordered flatrate, free, ads, rent, buy, each sorted
    // by displayPriority with unranked providers last.
}
```

Complétala siguiendo el estilo de `SeriesVerdictsView.swift` y `StandoutEpisodesView.swift`, que son las secciones hermanas de esta misma ficha: `Color.plotlineCard` de fondo, `RoundedRectangle(cornerRadius: 12)`, `.accessibilityElement(children: .combine)` con etiqueta por fila.

El selector de región: un `Menu` o `Picker` con los códigos de `regions`. Muestra el nombre de la región en inglés cuando puedas derivarlo (`Locale.current.localizedString(forRegionCode:)`), y el código si no.

- [ ] **Step 4: Compilar y ejecutar la suite**

Expected: `BUILD SUCCEEDED` en iPhone y iPad, `TEST SUCCEEDED`, dos tests nuevos.

- [ ] **Step 5: Commit**

```bash
git add Plotline/Views/Detail/WatchProvidersSection.swift PlotlineTests/WatchAttributionTests.swift
git commit -m "feat: show where a title can be watched, crediting JustWatch

TMDB revokes API access for using this data without crediting JustWatch,
and this app is entirely TMDB-backed, so the credit is drawn by the same
view as the providers rather than left to a call site."
```

---

## Task 4: Colocarla en la ficha

**Files:**
- Modify: `Plotline/ViewModels/MediaDetailViewModel.swift`
- Modify: `Plotline/Views/Detail/MediaDetailView.swift`

**Interfaces:**
- Consumes: `TMDBService.fetchWatchProviders(mediaType:id:)` (Tarea 2), `WatchProvidersSection` (Tarea 3), `WatchRegionStore.shared`
- Produces: `MediaDetailViewModel.watchAvailability: RegionAvailability?`, `.availableWatchRegions: [String]`, `func loadWatchProviders() async`, `func changeWatchRegion(_:)`

**Aplica a películas y a series**, a diferencia del análisis. Es la mitad del argumento del §7.

**Dónde va:** dentro del `VStack(alignment: .leading, spacing: 24)` de la ficha, **después** de `overviewSection` y **antes** del bloque `if viewModel.isTVSeries`. Razonamiento: responde "¿puedo verlo?", que es la pregunta inmediata, mientras que el análisis responde "¿me va a gustar?". El análisis sigue por delante de las recomendaciones de TMDB, que es lo que la Fase 6 dejó establecido.

**Cambiar de región no dispara red.** La respuesta cacheada trae las 126 regiones; `changeWatchRegion` solo reindexa el diccionario que ya está en memoria. Si tu implementación acaba haciendo otra petición, párate y dilo: significa que la caché de la Tarea 2 quedó mal.

**Estado inicial.** `watchAvailability` empieza en `nil` y la sección **no se renderiza** hasta que la carga termine. Un hueco con "not available here" mientras aún se está pidiendo sería mentira. Esto no contradice lo de la Fase 5 —allí el análisis venía del bundle y estaba disponible sin red—; aquí no hay nada empaquetado que mostrar.

- [ ] **Step 1: Añadir el estado y la carga al view model**

```swift
    var watchAvailability: RegionAvailability?
    private(set) var availableWatchRegions: [String] = []
    private var allWatchRegions: [String: RegionAvailability] = [:]

    @MainActor
    func loadWatchProviders() async {
        guard let mediaType = media.mediaType else { return }

        guard let results = try? await tmdbService.fetchWatchProviders(mediaType: mediaType, id: media.id) else {
            return
        }

        allWatchRegions = results
        availableWatchRegions = results.keys.sorted()
        watchAvailability = results[WatchRegionStore.shared.selected]
    }

    /// Reindexes the response already in memory. The cached payload carries
    /// every region, so switching costs no request.
    @MainActor
    func changeWatchRegion(_ region: String) {
        WatchRegionStore.shared.selected = region
        watchAvailability = allWatchRegions[region]
    }
```

Llámala desde `loadDetails()`, en paralelo con las tareas que ya lanza, siguiendo el patrón `async let` que el método ya usa.

- [ ] **Step 2: Colocar la sección**

```swift
                    if !viewModel.availableWatchRegions.isEmpty {
                        WatchProvidersSection(
                            availability: viewModel.watchAvailability,
                            region: WatchRegionStore.shared.selected,
                            regions: viewModel.availableWatchRegions,
                            onRegionChange: { viewModel.changeWatchRegion($0) }
                        )
                    }
```

- [ ] **Step 3: Compilar y ejecutar la suite**

Expected: `BUILD SUCCEEDED` en iPhone y iPad, `TEST SUCCEEDED`, 0 fallos, sin tests nuevos.

- [ ] **Step 4: Commit**

```bash
git add Plotline/ViewModels/MediaDetailViewModel.swift Plotline/Views/Detail/MediaDetailView.swift
git commit -m "feat: put watch availability on the detail screen

Answers 'can I watch this' before the analysis answers 'will I like
it'. Switching region reindexes the cached response rather than
fetching again."
```

---

## Definición de terminado

- [ ] `TEST SUCCEEDED`, cero fallos
- [ ] Compila para iPhone 17 y para iPad Air 11-inch
- [ ] **Ningún proveedor aparece en pantalla sin la atribución a JustWatch** — verificado en pantalla, no solo por test
- [ ] Una región sin disponibilidad muestra una frase y el selector, nunca un hueco
- [ ] Cambiar de región no dispara una petición
- [ ] Funciona en películas y en series
- [ ] El iPhone no ha empeorado
- [ ] Verificado en claro y oscuro
- [ ] Ningún texto de UI en español

## Lo que queda fuera a propósito

- **Deep links a las apps de las plataformas.** El endpoint no los da; el único enlace disponible es la página de TMDB del título.
- **Un ajuste de región en Settings.** El selector va en la propia sección, donde se ve y se usa. Si más adelante conviene duplicarlo en Settings, se hace entonces.
- **Filtrar por proveedores contratados.** Sería otra funcionalidad, con su propio almacenamiento y su propia UI.
