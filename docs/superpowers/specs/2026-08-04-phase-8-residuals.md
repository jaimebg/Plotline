# Residuos de la Fase 8 — que estos tests sí puedan fallar

**Fecha:** 2026-08-05
**Estado:** fase completa. Nueve commits, revisión limpia en las seis tareas. `TEST SUCCEEDED` con 0 fallos: 146 tests de Swift Testing y los 6 del suite de UI, en iPhone 17.
**Origen:** la ejecución del §5 del spec —siete mutaciones deliberadas, una a una— más el ledger del controlador.

---

## Lo que esta fase cierra

El §11 del spec 4.2 pedía un test de regresión del rechazo y no existía. Lo que existía, `ColdStartTests`, probaba los **datos**: que `DatasetStore` tiene entradas, cinco listas, y que resuelven. El defecto que provocó tres rechazos encadenados —`StatsView` envolviendo Compare, Career Profiles y Trends, ninguno de los cuales necesita datos de usuario, en un check de favoritos guardados— habría pasado en verde.

Ahora hay un suite de UI que recorre las cinco pestañas en instalación limpia y sin clave de TMDB, y un script que junta en un sitio las ocho precondiciones de una release.

Pero lo que de verdad cierra esta fase es otra cosa. Este trabajo entero nació de un residuo que decía *"tres tests no pueden fallar"*, y durante su propia planificación apareció un octavo: el paso 5 del preflight habría reportado verde para siempre, porque `grep -rq ""` con patrón vacío casa incondicionalmente. Cerrar una fase sobre tests que no pueden fallar añadiendo más habría sido absurdo. **Cada aserción nueva se rompió a propósito y se comprobó que se pone roja.**

---

## 1. La tabla de mutaciones, con el resultado observado

Cada mutación se aplicó sola, se ejecutó, y se revirtió con `git checkout` antes de la siguiente. El árbol quedó limpio entre todas y después de todas.

| # | Mutación | Qué se ejecutó | Resultado observado |
|---|---|---|---|
| 1 | Los tres `VStack` de Compare, Career Profiles y Trends de `StatsView.statsContent`, envueltos en `if !viewModel.isEmpty { }` | `testStatsKeepsItsUserIndependentSectionsWhenNothingIsSaved` | **Rojo.** `Stats is missing "plotline.stats.compare" with nothing saved. This section analyses TMDB, not the user's library, and gating it behind saved favorites is the defect that got 1.3.0 rejected.` |
| 2 | En `FavoritesView`, `shelfIdentifier: ""` en lugar de `AccessibilityAnchors.favoritesSuggestions` | los tests de Favorites y de Watchlist, juntos | **Rojo el de Favorites**, nombrando el ancla: `the Favorites tab is missing its content anchor "plotline.favorites.suggestions"`. El de Watchlist quedó **verde**, que es la prueba de que la mutación no se derramó. |
| 3 | `lists: []` en `Plotline/Resources/PlotlineDataset.json` | `testDiscoverShowsCuratedShelves` | **Rojo.** `Discover rendered no curated shelf at all` |
| 4 | Un favorito guardado y una segunda ejecución **sin** `simctl uninstall` | `testContainerIsClean` | **Rojo.** `("2") is not equal to ("0") - The simulator container carried 2 saved favorites, so this run is not testing a clean install.` |
| 5 | `Secrets.resolve` de vuelta a `plist[key] ?? environment[key] ?? ""` | el suite `SecretsTests` | **Rojo** `emptyEnvironmentValueStillWins`, y de paso `environmentWins`. `plistIsTheFallback` y `unknownKeyIsEmpty` siguieron verdes, que es lo correcto: no dependen del orden. |
| 6 | La línea `generatedAt` borrada del dataset | la lógica del paso 4 del preflight | **Rojo**, salida 1: `Plotline/Resources/PlotlineDataset.json declares no generatedAt — regenerate it with Tools/DatasetGenerator` |
| 7 | `MARKETING_VERSION` a `1.4.1` sin tocar `docs/app-review/` | la lógica del paso 5 del preflight | **Rojo**, salida 1: `project says 1.4.1 but no file in docs/app-review/ mentions it` |

**Siete de siete.** Ninguna hubo que arreglarla: no apareció ningún test que no pudiera fallar.

### Tres desviaciones respecto a cómo estaba escrita la tabla

- **La mutación 2 ya no se puede hacer literalmente.** El brief decía "borrar el `.accessibilityIdentifier` del punto de llamada en `FavoritesView`", pero la Task 3 movió ese modificador dentro de `SuggestionsEmptyState` y el punto de llamada pasa ahora un `shelfIdentifier`. Vaciarlo tiene el mismo efecto —el ancla deja de existir en el árbol— y se queda en la vista que el brief nombraba, en vez de en el componente compartido, que habría puesto rojas dos pestañas y no habría distinguido nada.
- **La mutación 4 no se hizo a mano.** Un simulador no se toca. Se escribió un XCUITest temporal que abre Favorites, entra en la primera tarjeta del estante de sugerencias, pulsa "Add to favorites" y comprueba que el botón cambia a "Remove from favorites"; después se ejecutó `testContainerIsClean` contra ese mismo contenedor sin desinstalar. El test temporal se borró.
- **Las mutaciones 6 y 7 no ejecutaron el preflight entero.** Sus pasos 1 y 2 son dos suites completas de simulador. El corredor se ensambló con las **líneas propias del script** —la cabecera, el bloque del paso bajo prueba y el recuento final—, no reescribiendo la lógica a mano, así que lo que se ejecutó es lo que se envía.

### Una comprobación de más, fuera de las siete

El paso 5 del preflight tenía un falso verde que un revisor encontró **en el texto del plan**: si la extracción de `MARKETING_VERSION` devolvía cadena vacía, el `grep -rq ""` casaba con todo y una clave ausente se reportaba como coherencia. La Task 5 le puso una guarda explícita. Se ejercitó: renombrando la clave en `project.pbxproj` el paso dice `MARKETING_VERSION could not be read from Plotline.xcodeproj/project.pbxproj` y sale con 1. La guarda funciona.

---

## 2. La prueba que nadie planificó

Las siete mutaciones son roturas plantadas: se sabe qué se rompió y qué tiene que ponerse rojo. La comprobación que más vale de esta fase no la plantó nadie.

Terminadas las mutaciones y revertido todo, se lanzó el suite completo para dejar constancia de un árbol verde. Salió rojo, en tres tests exactos: `testContainerIsClean`, `testFavoritesOffersSuggestionsWithNothingSaved` y `testStatsKeepsItsUserIndependentSectionsWhenNothingIsSaved`. Todo lo demás pasó.

Esos tres son justo los que dependen de una biblioteca vacía, y fallaron por un favorito que había sobrevivido a un `simctl uninstall`. El diagnóstico está en el residuo nº 4. Lo que importa aquí es que **el suite detectó una ejecución sucia real, no una plantada, y dijo exactamente qué pasaba** — que es literalmente para lo que se escribió `testContainerIsClean` en el §1.2 del spec: *"un run que se saltara la desinstalación pasaría en verde probando un estado que ningún revisor ve"*.

Un test que se pone rojo en un ensayo es una promesa. Este cobró.

---

## 3. Lo que la ejecución le corrigió al plan

Cuatro cosas que el plan daba por buenas y no lo eran:

- **El generador no tiene `main.swift`.** El brief de la Task 1 apuntaba a `Tools/DatasetGenerator/Sources/DatasetGenerator/main.swift`. El target ejecutable se llama `dataset-generator` y el único punto de llamada de `DatasetBuilder.build` está en `Generator.swift`, dentro de `Generator.run()`. Ahí se puso la lectura del reloj, y de ahí sale que el comando de regeneración es `swift run dataset-generator`.
- **El esquema compartido estaba en `.gitignore`.** `xcshareddata/` se ignoraba entero desde `70a879b`, para mantener fuera de git una clave de API embebida en el esquema. Consecuencia no prevista: la entrada `<TestAction>` del target de UI y la pre-action de Archive **no habrían existido fuera de una máquina**. Todo el cableado de esta fase habría sido invisible para cualquier otro checkout. Se levantó la regla —`xcuserdata/` ya cubre el estado por usuario, y hoy el esquema no lleva ninguna clave; la clave vive en `Plotline/Secrets.plist`, que se sigue ignorando aparte— y se sustituyó por el paso 7 del preflight, que comprueba que el esquema no declare ninguna variable de entorno con valor. Una prohibición ciega a cambio de una comprobación visible.
- **El falso verde del paso 5**, arriba.
- **La nota de CLAUDE.md se escribió en castellano** en un fichero que está en inglés de principio a fin. Traducida en `7524ae4`. `docs/app-review/README.md` sigue en castellano a propósito: ese es su idioma.

---

## 4. Corrección a los residuos de la Fase 6

El residuo nº 4 de aquel documento dice que, con `.tabViewStyle(.sidebarAdaptable)`, el iPad esconde Settings **tras un chevron de barra lateral**. La Task 4 ejecutó el suite en un iPad Air 11" real y vio otra cosa: lo que hay es un botón de paginación **"Next Page"** en la barra flotante de pestañas, porque a ese ancho caben cuatro. La consecuencia es la misma —Settings pasa de un toque a dos— pero el mecanismo no, y `openTab` tuvo que aprender a pasar de página, no a abrir una barra lateral.

De la misma pasada salió un segundo dato: en iPad cada botón de pestaña aparece como **dos elementos anidados con la misma etiqueta y el mismo identificador**. No son dos pestañas, es cómo se materializa; pero resolverlo a un único elemento lanza "multiple matching elements found" al pulsar. Por eso `tabButton` usa un predicado explícito sobre `label` con `.firstMatch`. En iPhone hay un solo elemento y no cambia nada.

---

## Lo que queda abierto

### 5. La desinstalación del preflight puede no hacer nada, en silencio

**Es el residuo que más pesa de esta fase.** `run_suite()`, en `Scripts/release-preflight.sh`, empieza así:

```bash
xcrun simctl uninstall booted "$BUNDLE_ID" 2>/dev/null
```

El código de salida se descarta y el error se manda a `/dev/null`. Si en ese momento no hay ningún simulador arrancado, `simctl` responde `Unable to lookup in current state: Shutdown` con código 149, no se ve nada, y el suite corre a continuación **contra el contenedor que ya hubiera**.

No es teoría. Es lo que ocurrió al cerrar esta tarea, y se comprobó después paso a paso:

- Con el dispositivo **apagado**: `uninstall` sale 149 y el almacén de favoritos sigue en disco.
- Con el dispositivo **arrancado**: sale 0 y el almacén desaparece.

El script arranca el dispositivo (`simctl boot` + `bootstatus`) **una vez, al principio**, antes del paso 1. Pero el paso 2 llama a `run_suite` por segunda vez, y `xcodebuild` puede haber dejado el simulador apagado entretanto — que es exactamente la secuencia que lo reprodujo. La pasada viva, la que corre contra TMDB real justo antes de enviar una build, es la que se lo come.

Hay una segunda forma de que la misma línea falle sin decirlo, y también se observó: `booted` no apunta al dispositivo que se está probando. Durante esta tarea hubo dos simuladores arrancados —un iPhone 17 y un iPad Air 11"— y `xcrun simctl getenv booted SIMULATOR_UDID` devolvió el **iPad**. `xcodebuild` recibe un `-destination` explícito; `simctl uninstall booted` no, así que puede desinstalar limpiamente de un dispositivo que nadie va a probar y dejar sucio el que sí.

Y hay una tercera, más incómoda: el mensaje de fallo de `testContainerIsClean` **receta ese mismo comando** —"Run `xcrun simctl uninstall booted com.jbgsoft.Plotline` first"— que es el que puede no hacer nada.

Nada de esto rompe la guarda: el suite se puso rojo y dijo la verdad. Lo que está roto es la limpieza que la precede. Quien lo retome: arrancar el dispositivo dentro de `run_suite`, dirigir el `uninstall` al mismo dispositivo que el `-destination` en vez de a `booted`, y comprobar el código de salida.

### 6. El mensaje de `testContainerIsClean` cuenta elementos, no favoritos

La mutación 4 lo dejó a la vista. Se guardó **un** favorito —Chernobyl— y el test reportó `2`. Se confirmó por dos vías: un XCUITest temporal de diagnóstico listó las etiquetas y salieron dos idénticas, `["Chernobyl, TV Series, rated 8.7 out of 10", "Chernobyl, TV Series, rated 8.7 out of 10"]`; y un `SELECT COUNT(*) FROM ZFAVORITEITEM` sobre el almacén devolvió `1`. Es la misma duplicación anidada que la Task 4 documentó para los botones de pestaña en iPad, aquí en iPhone y para una fila de `List`.

La aserción no se ve afectada: es `== 0`, y cero elementos siguen siendo cero favoritos. Lo que falla es la frase. "The simulator container carried 2 saved favorites" afirma un número de favoritos que su predicado no establece — cuenta elementos del árbol de accesibilidad. Es exactamente la regla que este proyecto ha reescrito seis veces, y se anota en vez de arreglarse porque esta tarea no comprometía código.

### 7. El almacén de favoritos no está donde dice su propio comentario

El docstring de `testContainerIsClean` dice que favoritos y watchlist persisten en SwiftData *"inside the app container"*. No es ahí. El fichero está en el contenedor de grupo compartido, `group.com.jbgsoft.Plotline`; el `Library/Application Support/` del contenedor de la app está vacío.

La conclusión del comentario —que solo desinstalar puede limpiarlo— se verificó y se sostiene. Pero se sostiene porque el simulador retira también el contenedor de grupo **cuando el dispositivo está arrancado**, no porque el dato viva donde el comentario dice. La frase describe mal el mecanismo del que depende, y ese mecanismo es justo el que falla en el residuo nº 5.

### 8. El residuo nº 5 de la Fase 7 sigue abierto, y uno de los tres es peor de lo que decía

Los tres tests infalsificables de `WatchRegionStore` siguen como estaban; esta fase no los tocó. Lo que sí aporta es un dato sobre el que más pesaba:

`selectionPersists` **no es un test débil, es un límite inalcanzable**. `WatchRegionStore` lee `UserDefaults` únicamente en su `private init()`, y es un singleton. No existe ninguna secuencia de llamadas, desde ningún test, capaz de observar un arranque en frío: el `init` ocurre una vez por proceso y ya ha ocurrido antes de que el test empiece. Escribirlo mejor no arregla nada. Quien lo retome tiene que **hacer inyectable el almacenamiento**, y eso es un cambio de diseño, no un retoque de test.

### 9. La pasada hambrienta prueba un 401, no la ausencia de red

Lanzar la app con `TMDB_API_KEY=""` hace que TMDB no devuelva **nada**, de inmediato y con un código de error. No es lo mismo que estar sin cobertura, donde lo que hay son timeouts, reintentos y estados a medias. Es la limitación registrada en el §1.5 del spec y sigue registrada: lo que el suite prueba es que el dataset empaquetado llena las cinco pestañas él solo, no que la app se comporte bien en un tren.

### 10. La pre-action de Archive avisa, no aborta

El preflight está cableado a la pre-action de Archive del esquema compartido, pero una pre-action que sale con código distinto de cero **no aborta el archivado de forma fiable** en las versiones recientes de Xcode. Te lo dice en el momento correcto; no te para. Está escrito en la cabecera del propio script, en CLAUDE.md y aquí, y sigue sin ser una barrera.

### 11. Los mínimos del suite de UI son bajos a propósito

`assertShelf` pide dos tarjetas, no doce; Discover pide dos estantes, no cinco. XCUITest solo ve lo que se ha materializado, y estos estantes son `LazyHStack`. Las cantidades exactas —cinco listas, doce sugerencias, sesenta títulos— viven en `ColdStartTests`, que ve el dataset entero. Subir los mínimos aquí produciría rojos por scroll, no por defectos.

### 12. Los 90 días de frescura son un juicio

`MAX_DATASET_AGE_DAYS=90` no sale de ningún cálculo. Es una opinión sobre cuánto puede envejecer un análisis de series antes de que valga la pena regenerarlo, escrita donde se cambia. No hay nada que la respalde salvo que un número tenía que haber.

### 13. Menores aplazados, del ledger

Ninguno bloquea nada; se anotan para que no se redescubran:

- `DatasetBuilderTests` repite el literal `"2026-01-01T00:00:00Z"` en catorce puntos. Un `private static let` lo secaría. Cosmético.
- El suite de UI no tiene `tearDown()` que termine la app entre métodos. Cada `setUp()` construye un `XCUIApplication` nuevo y no se observó ningún efecto de aislamiento. Estilo.
- En el bucle de Stats de `ColdStartUITests`, el `if !section.exists { app.swipeUp() }` es código muerto: `statsContent` es un `VStack` dentro de un `ScrollView`, no es perezoso, así que los tres identificadores ya están en el árbol. Lo pedía el plan y el `waitForExistence` sigue siendo la aserción real.
- El commit de la Task 6 es `docs:` para un cambio que también toca el esquema; `chore:` encajaba igual de bien.
- El bloque de Build Commands de CLAUDE.md quedó tras el del generador y no tras el de los tests, como decía el brief. Colocación, nada más.

Y uno que ya no lo es: el mensaje de fallo de `ColdStartUITests` apuntaba a `Scripts/release-preflight.sh` antes de que ese fichero existiera. La Task 5 lo creó.

---

## Lo que nada de esto protege

Escrito para que nadie le atribuya más alcance del que tiene:

- **No prueba que la app se vea bien, solo que no se vea vacía.** Un layout roto con contenido dentro pasa en verde. Lo que estas anclas afirman es que los contenedores existen y tienen algo dentro; ni una sola aserción mira una posición, un tamaño o un color.
- **No prueba iPad más allá de la pasada de la Task 4.** Las anclas son independientes del tamaño, pero los mínimos se afirman en un destino de iPhone y el bucle normal corre en iPhone. Una regresión de columnas como la de la Fase 6 no la vería.
- **No prueba la experiencia real sin cobertura**, por el residuo nº 9.
- **No sustituye mirar la pantalla.** Las tres fases anteriores tuvieron su único fallo grave en una costura, y dos de las tres veces la verificación visual existía y miraba el sitio equivocado. Esto automatiza un recorrido concreto; no automatiza el criterio.

---

## Para la fase siguiente

Del spec 4.2 queda el §12: el reenvío a App Review, que sigue siendo trabajo a mano y a propósito —el paso 8 del preflight lo enumera en orden y `docs/app-review/README.md` argumenta por qué. Y las capturas de iPad que la Fase 6 dejó pendientes.

Antes de usar el preflight para enviar nada, el residuo nº 5.

Y la guarda de proceso que esta fase añade, que no es sobre el producto sino sobre cómo se comprueba: **un test que no se ha visto fallar no es evidencia de nada.** Esta fase encontró un falso verde en el texto de su propio plan, antes de escribir una línea; otro en un mensaje de fallo que se creía exacto y contaba otra cosa; y una limpieza que llevaba desde la Task 5 sin hacer su trabajo cuando el simulador estaba apagado. Ninguno de los tres habría aparecido leyendo el código con atención. Aparecieron al romperlo, y el último apareció solo.
