# Residuos de la Fase 8 — que estos tests sí puedan fallar

**Fecha:** 2026-08-05
**Estado:** fase completa. Nueve commits, revisión limpia en las seis tareas. `TEST SUCCEEDED` con 0 fallos en iPhone 17. Los números, contados de la salida y no de memoria: **151 casos** de Swift Testing, de **147 funciones `@Test`** —dos están parametrizadas con tres argumentos cada una— más el suite de UI.
**Origen:** la ejecución del §5 del spec —siete mutaciones deliberadas, una a una— más el ledger del controlador.

---

## Lo que esta fase cierra

El §11 del spec 4.2 pedía un test de regresión del rechazo y no existía. Lo que existía, `ColdStartTests`, probaba los **datos**: que `DatasetStore` tiene entradas, cinco listas, y que resuelven. El defecto que provocó tres rechazos encadenados —`StatsView` envolviendo Compare, Career Profiles y Trends, ninguno de los cuales necesita datos de usuario, en un check de favoritos guardados— habría pasado en verde.

Ahora hay un suite de UI que recorre las cinco pestañas en instalación limpia y sin clave de TMDB, y un script que junta en un sitio **siete** comprobaciones de release. El paso 8/8 no es una octava: no comprueba nada, imprime el checklist de App Store Connect que sigue haciéndose a mano.

Pero lo que de verdad cierra esta fase es otra cosa. Este trabajo entero nació de un residuo que decía *"tres tests no pueden fallar"*, y durante su propia planificación apareció un octavo: el paso 5 del preflight habría reportado verde para siempre, porque `grep -rq ""` con patrón vacío casa incondicionalmente. Cerrar una fase sobre tests que no pueden fallar añadiendo más habría sido absurdo. **Cada aserción nueva se rompió a propósito y se comprobó que se pone roja.**

---

## 1. La tabla de mutaciones, con el resultado observado

Cada mutación se aplicó sola, se ejecutó, y se revirtió con `git checkout` antes de la siguiente. El árbol quedó limpio entre todas y después de todas.

| # | Mutación | Qué se ejecutó | Resultado observado |
|---|---|---|---|
| 1 | Los tres `VStack` de Compare, Career Profiles y Trends de `StatsView.statsContent`, envueltos en `if !viewModel.isEmpty { }` | `testStatsKeepsItsUserIndependentSectionsWhenNothingIsSaved` | **Rojo.** `Stats is missing "plotline.stats.compare" with nothing saved. This section analyses TMDB, not the user's library, and gating it behind saved favorites is the defect that got 1.3.0 rejected.` |
| 2 | En `FavoritesView`, `shelfIdentifier: ""` en lugar de `AccessibilityAnchors.favoritesSuggestions` | los tests de Favorites y de Watchlist, juntos | **Rojo el de Favorites**, nombrando el ancla: `the Favorites tab is missing its content anchor "plotline.favorites.suggestions"`. El de Watchlist quedó **verde**, que es la prueba de que la mutación no se derramó. |
| 3 | `lists: []` en `Plotline/Resources/PlotlineDataset.json` | `testDiscoverShowsCuratedShelves` | **Rojo.** `Discover rendered no curated shelf at all` |
| 4 | Un favorito guardado y una segunda ejecución **sin** `simctl uninstall` | `testContainerIsClean` | **Rojo**, `("2") is not equal to ("0")`, con el mensaje que llevaba entonces: *"The simulator container carried 2 saved favorites…"*. Ese `2` es el que destapó que el mensaje contaba elementos y no favoritos; la frase se reescribió después (§3). |
| 5 | `Secrets.resolve` de vuelta a `plist[key] ?? environment[key] ?? ""` | el suite `SecretsTests` | **Rojo** `emptyEnvironmentValueStillWins`, y de paso `environmentWins`. `plistIsTheFallback` y `unknownKeyIsEmpty` siguieron verdes, que es lo correcto: no dependen del orden. |
| 6 | La línea `generatedAt` borrada del dataset | la lógica del paso 4 del preflight | **Rojo**, salida 1: `Plotline/Resources/PlotlineDataset.json declares no generatedAt — regenerate it with Tools/DatasetGenerator` |
| 7 | `MARKETING_VERSION` a `1.4.1` sin tocar `docs/app-review/` | la lógica del paso 5 del preflight | **Rojo**, salida 1: `project says 1.4.1 but no file in docs/app-review/ mentions it` |

**Siete de siete.** Ninguna hubo que arreglarla: no apareció ningún test que no pudiera fallar.

### Tres desviaciones respecto a cómo estaba escrita la tabla

- **La mutación 2 ya no se puede hacer literalmente.** El brief decía "borrar el `.accessibilityIdentifier` del punto de llamada en `FavoritesView`", pero la Task 3 movió ese modificador dentro de `SuggestionsEmptyState` y el punto de llamada pasa ahora un `shelfIdentifier`. Vaciarlo tiene el mismo efecto —el ancla deja de existir en el árbol— y se queda en la vista que el brief nombraba, en vez de en el componente compartido, que habría puesto rojas dos pestañas y no habría distinguido nada.
- **La mutación 4 no se hizo a mano.** Un simulador no se toca. Se escribió un XCUITest temporal que abre Favorites, entra en la primera tarjeta del estante de sugerencias, pulsa "Add to favorites" y comprueba que el botón cambia a "Remove from favorites"; después se ejecutó `testContainerIsClean` contra ese mismo contenedor sin desinstalar. El test temporal se borró.
- **Las mutaciones 6 y 7 no ejecutaron el preflight entero.** Sus pasos 1 y 2 son dos suites completas de simulador. El corredor se ensambló con las **líneas propias del script** —la cabecera, el bloque del paso bajo prueba y el recuento final—, no reescribiendo la lógica a mano, así que lo que se ejecutó es lo que se envía.

### Una comprobación de más, fuera de las siete

El paso 5 del preflight tenía un falso verde que un revisor encontró **en el texto del plan**: si la extracción de `MARKETING_VERSION` devolvía cadena vacía, el `grep -rq ""` casaba con todo y una clave ausente se reportaba como coherencia. Se le puso una guarda explícita. Se ejercitó: renombrando la clave en `project.pbxproj` el paso dijo `MARKETING_VERSION could not be read from Plotline.xcodeproj/project.pbxproj` y salió con 1. La guarda funciona.

*Nota posterior:* la guarda sigue, pero ni la extracción ni ese mensaje son ya los de entonces. `MARKETING_VERSION` aparece seis veces en `project.pbxproj` —una por configuración de cada target— y el `grep -m1` acertaba con la de la app solo porque los UUID que genera Xcode la ordenaban primero. Ahora se le pregunta al sistema de build, `xcodebuild -showBuildSettings -target Plotline -configuration Release`, y el mensaje nombra el target y la configuración en vez del fichero.

---

## 2. La prueba que nadie planificó

Las siete mutaciones son roturas plantadas: se sabe qué se rompió y qué tiene que ponerse rojo. La comprobación que más vale de esta fase no la plantó nadie.

Terminadas las mutaciones y revertido todo, se lanzó el suite completo para dejar constancia de un árbol verde. Salió rojo, en tres tests exactos: `testContainerIsClean`, `testFavoritesOffersSuggestionsWithNothingSaved` y `testStatsKeepsItsUserIndependentSectionsWhenNothingIsSaved`. Todo lo demás pasó.

Esos tres son justo los que dependen de una biblioteca vacía, y fallaron por un favorito que había sobrevivido a un `simctl uninstall`. El diagnóstico está en el §3, en la entrada de la desinstalación. Lo que importa aquí es que **el suite detectó una ejecución sucia real, no una plantada, y dijo exactamente qué pasaba** — que es literalmente para lo que se escribió `testContainerIsClean`, según su propio docstring: *"A run that skipped the uninstall would otherwise pass green while testing a state no reviewer ever sees."* El §1.2 del spec dice lo mismo con otras palabras; la frase citada es del test.

Un test que se pone rojo en un ensayo es una promesa. Este cobró.

---

## 3. Lo que la ejecución le corrigió al plan

Cuatro cosas que el plan daba por buenas y no lo eran:

- **El generador no tiene `main.swift`.** El brief de la Task 1 apuntaba a `Tools/DatasetGenerator/Sources/DatasetGenerator/main.swift`. El target ejecutable se llama `dataset-generator` y el único punto de llamada de `DatasetBuilder.build` está en `Generator.swift`, dentro de `Generator.run()`. Ahí se puso la lectura del reloj, y de ahí sale que el comando de regeneración es `swift run dataset-generator`.
- **El esquema compartido estaba en `.gitignore`.** `xcshareddata/` se ignoraba entero desde `70a879b`, para mantener fuera de git una clave de API embebida en el esquema. Consecuencia no prevista: la entrada `<TestAction>` del target de UI y la pre-action de Archive **no habrían existido fuera de una máquina**. Todo el cableado de esta fase habría sido invisible para cualquier otro checkout. Se levantó la regla —`xcuserdata/` ya cubre el estado por usuario, y hoy el esquema no lleva ninguna clave; la clave vive en `Plotline/Secrets.plist`, que se sigue ignorando aparte— y se sustituyó por el paso 7 del preflight, que comprueba que el esquema no declare ninguna variable de entorno con valor. Una prohibición ciega a cambio de una comprobación visible.
- **El falso verde del paso 5**, arriba.
- **La nota de CLAUDE.md se escribió en castellano** en un fichero que está en inglés de principio a fin. Traducida en `7524ae4`. `docs/app-review/README.md` sigue en castellano a propósito: ese es su idioma.

### Y cuatro cosas corregidas después de escribir este documento, en la misma rama

Se anotan aquí, y no en "lo que queda abierto", porque ya no están abiertas. Quien lea este documento a la vez que el código encontrará el código por delante.

- **`simctl uninstall booted` desinstalaba de cualquier sitio, y en silencio.** `run_suite` empezaba con `xcrun simctl uninstall booted "$BUNDLE_ID" 2>/dev/null`: el código de salida se descartaba y el error se mandaba a `/dev/null`. Dos formas de fallar sin decirlo, las dos observadas. Con el dispositivo **apagado**, `uninstall` sale 149 (`Unable to lookup in current state: Shutdown`), el almacén de favoritos sigue en disco y el suite corre contra el contenedor que hubiera. Y `booted` no apunta necesariamente al dispositivo que se prueba: durante esta fase hubo dos simuladores arrancados —un iPhone 17 y un iPad Air 11"— y `xcrun simctl getenv booted SIMULATOR_UDID` devolvió el **iPad**, mientras `xcodebuild` recibía un `-destination` explícito al iPhone. Corregido en `62a4fc5`: el `uninstall` nombra `"$DEVICE"`, se comprueba su resultado y un fallo llama a `fail()` y salta el suite en vez de ejecutarlo sucio. Lo que queda de aquí es el §5.
- **El mensaje de `testContainerIsClean` contaba elementos y decía favoritos.** La mutación 4 lo destapó: se guardó **un** favorito —Chernobyl— y el test reportó `2`. Se confirmó por dos vías: un XCUITest temporal de diagnóstico listó las etiquetas y salieron dos idénticas, `["Chernobyl, TV Series, rated 8.7 out of 10", "Chernobyl, TV Series, rated 8.7 out of 10"]`; y un `SELECT COUNT(*) FROM ZFAVORITEITEM` sobre el almacén devolvió `1`. Es la misma duplicación anidada que la Task 4 documentó para los botones de pestaña en iPad, aquí en iPhone y para una fila de `List`. La aserción nunca estuvo mal —es `== 0`, y cero elementos siguen siendo cero favoritos—; lo que afirmaba de más era la frase. Reescrita en `62a4fc5` para decir lo que cuenta: elementos de accesibilidad que llevan el identificador de fila guardada. El mismo commit le quitó el `xcrun simctl uninstall booted` que recetaba, que era justo el comando que podía no hacer nada.
- **El mismo docstring decía que el almacén está *"inside the app container"*.** No está. Se volvió a comprobar, en un contenedor recién instalado: `Library/Application Support/` del contenedor de datos de la app está vacío, y `default.store` —con su `-wal` y su `-shm`— vive en el contenedor de grupo compartido, `group.com.jbgsoft.Plotline`. La conclusión que el comentario sacaba —que solo desinstalar puede limpiarlo— se sostiene, pero se sostiene porque el simulador retira también el contenedor de grupo, y solo **con el dispositivo arrancado**; no porque el dato viva donde decía. Reescrito para nombrar el contenedor real y ese "con el dispositivo arrancado", que es justo lo que hace que el §5 importe.
- **Ninguna de las dos pasadas comprobaba estar en el modo que decía.** Era el agujero más grande que dejó esta fase, y estaba justo debajo de su afirmación central. Toda la pasada hambrienta descansaba en que `launchEnvironment["TMDB_API_KEY"] = ""` llegara a `Secrets`: si no llegaba, los seis tests corrían contra TMDB real y salían verdes sin haber probado nada del dataset empaquetado — que es la defensa entera del 4.2. La mutación 3 no lo cubría: `curatedShelves` recorre `DatasetStore.shared.lists` sin condición, así que se pone roja con clave o sin ella. Ahora `testDiscoverMatchesTheModeThisPassClaims` afirma, según el modo, el ancla del estado de error de Discover o la de su sección de tendencias, que son excluyentes. Y por el lado de la pasada viva, el modo llega en `PLOTLINE_UITEST_MODE` porque `xcodebuild` le quita el prefijo `TEST_RUNNER_`: si eso se rompiera, la variable faltaría, el suite se iría a su modo hambriento por defecto y el paso 2 imprimiría "live pass green" sobre una segunda pasada hambrienta. Ninguna aserción de dentro puede verlo —leería la misma variable ausente—, así que `setUp` imprime el modo observado y el paso 2 lo lee de la salida y falla si no dice `live`. Ambas cosas se ejercitaron: el ancla de error en la pasada por defecto, la de tendencias en la viva, y el paso 2 sin la variable, que se pone rojo.

---

## 4. Corrección a los residuos de la Fase 6

El residuo nº 4 de aquel documento dice que, con `.tabViewStyle(.sidebarAdaptable)`, el iPad esconde Settings **tras un chevron de barra lateral**. La Task 4 ejecutó el suite en un iPad Air 11" real y vio otra cosa: lo que hay es un botón de paginación **"Next Page"** en la barra flotante de pestañas, porque a ese ancho caben cuatro. La consecuencia es la misma —Settings pasa de un toque a dos— pero el mecanismo no, y `openTab` tuvo que aprender a pasar de página, no a abrir una barra lateral.

De la misma pasada salió un segundo dato: en iPad cada botón de pestaña aparece como **dos elementos anidados con la misma etiqueta y el mismo identificador**. No son dos pestañas, es cómo se materializa; pero resolverlo a un único elemento lanza "multiple matching elements found" al pulsar. Por eso `tabButton` usa un predicado explícito sobre `label` con `.firstMatch`. En iPhone hay un solo elemento y no cambia nada.

---

## Lo que queda abierto

### 5. El simulador se arranca una sola vez, fuera de `run_suite`

`Scripts/release-preflight.sh` arranca el dispositivo (`simctl boot` + `bootstatus`) **una vez, al principio**, antes del paso 1. Pero `run_suite` se llama dos veces, y `xcodebuild` puede haber dejado el simulador apagado al terminar el paso 1 — que es exactamente la secuencia que reprodujo el fallo descrito en el §3. Con el dispositivo apagado, el `uninstall` del paso 2 sale 149.

Ya no es silencioso: desde `62a4fc5` ese fallo se comprueba, se reporta y el suite no se ejecuta. Pero eso convierte el problema en otro, no lo elimina: la que se queda sin correr es **la pasada viva**, la única que ejercita el camino de recomputación contra TMDB real, justo antes de enviar una build.

Quien lo retome: mover el arranque dentro de `run_suite`, para que cada pasada se garantice su propio dispositivo arrancado en vez de heredar el estado que dejó la anterior.

### 6. El residuo nº 5 de la Fase 7 sigue abierto, y uno de los tres es peor de lo que decía

Los tres tests infalsificables de `WatchRegionStore` siguen como estaban; esta fase no los tocó. Lo que sí aporta es un dato sobre el que más pesaba:

`selectionPersists` **no es un test débil, es un límite inalcanzable**. `WatchRegionStore` lee `UserDefaults` únicamente en su `private init()`, y es un singleton. No existe ninguna secuencia de llamadas, desde ningún test, capaz de observar un arranque en frío: el `init` ocurre una vez por proceso y ya ha ocurrido antes de que el test empiece. Escribirlo mejor no arregla nada. Quien lo retome tiene que **hacer inyectable el almacenamiento**, y eso es un cambio de diseño, no un retoque de test.

### 7. La pasada hambrienta prueba un 401, no la ausencia de red

Lanzar la app con `TMDB_API_KEY=""` hace que TMDB no devuelva **nada**, de inmediato y con un código de error. No es lo mismo que estar sin cobertura, donde lo que hay son timeouts, reintentos y estados a medias. Es la limitación registrada en el §1.5 del spec y sigue registrada: lo que el suite prueba es que el dataset empaquetado llena las cinco pestañas él solo, no que la app se comporte bien en un tren.

### 8. La pre-action de Archive avisa, no aborta

El preflight está cableado a la pre-action de Archive del esquema compartido, pero una pre-action que sale con código distinto de cero **no aborta el archivado de forma fiable** en las versiones recientes de Xcode. Te lo dice en el momento correcto; no te para. Está escrito en la cabecera del propio script, en CLAUDE.md y aquí, y sigue sin ser una barrera.

### 9. Los mínimos del suite de UI son bajos a propósito

`assertShelf` pide dos tarjetas, no doce; Discover pide dos estantes, no cinco. XCUITest solo ve lo que se ha materializado, y estos estantes son `LazyHStack`. Las cantidades exactas —cinco listas, doce sugerencias, sesenta títulos— viven en `ColdStartTests`, que ve el dataset entero. Subir los mínimos aquí produciría rojos por scroll, no por defectos.

### 10. Los 90 días de frescura son un juicio

`MAX_DATASET_AGE_DAYS=90` no sale de ningún cálculo. Es una opinión sobre cuánto puede envejecer un análisis de series antes de que valga la pena regenerarlo, escrita donde se cambia. No hay nada que la respalde salvo que un número tenía que haber.

### 11. Menores aplazados, del ledger

Ninguno bloquea nada; se anotan para que no se redescubran:

- `DatasetBuilderTests` repite el literal `"2026-01-01T00:00:00Z"` en catorce puntos. Un `private static let` lo secaría. Cosmético.
- El suite de UI no tiene `tearDown()` que termine la app entre métodos. Cada `setUp()` construye un `XCUIApplication` nuevo y no se observó ningún efecto de aislamiento. Estilo.
- El commit que cableó el preflight a la pre-action de Archive es `docs:` para un cambio que también toca el esquema; `chore:` encajaba igual de bien.
- El bloque de Build Commands de CLAUDE.md quedó tras el del generador y no tras el de los tests, como decía el brief. Colocación, nada más.

Y dos que ya no lo son: el mensaje de fallo de `ColdStartUITests` apuntaba a `Scripts/release-preflight.sh` antes de que ese fichero existiera, y el script se escribió después. Y el `if !section.exists { app.swipeUp() }` del bucle de Stats, que era código muerto —`statsContent` es un `VStack` dentro de un `ScrollView`, no es perezoso, así que los tres identificadores ya están en el árbol— se ha borrado, dejando el `waitForExistence`, que siempre fue la aserción real.

---

## Lo que nada de esto protege

Escrito para que nadie le atribuya más alcance del que tiene:

- **No prueba que la app se vea bien, solo que no se vea vacía.** Un layout roto con contenido dentro pasa en verde. Lo que estas anclas afirman es que los contenedores existen y tienen algo dentro; ni una sola aserción mira una posición, un tamaño o un color.
- **No prueba iPad más allá de la pasada de la Task 4.** Las anclas son independientes del tamaño, pero los mínimos se afirman en un destino de iPhone y el bucle normal corre en iPhone. Una regresión de columnas como la de la Fase 6 no la vería.
- **No prueba la experiencia real sin cobertura**, por el residuo nº 7.
- **No sustituye mirar la pantalla.** Las tres fases anteriores tuvieron su único fallo grave en una costura, y dos de las tres veces la verificación visual existía y miraba el sitio equivocado. Esto automatiza un recorrido concreto; no automatiza el criterio.

---

## Para la fase siguiente

Del spec 4.2 queda el §12: el reenvío a App Review, que sigue siendo trabajo a mano y a propósito —el paso 8 del preflight lo enumera en orden y `docs/app-review/README.md` argumenta por qué. Y las capturas de iPad que la Fase 6 dejó pendientes.

Antes de usar el preflight para enviar nada, mirar el residuo nº 5: el paso 2 puede saltarse entero si `xcodebuild` deja el simulador apagado, y lo dice, pero no lo arregla.

Y la guarda de proceso que esta fase añade, que no es sobre el producto sino sobre cómo se comprueba: **un test que no se ha visto fallar no es evidencia de nada.** Esta fase encontró un falso verde en el texto de su propio plan, antes de escribir una línea; otro en un mensaje de fallo que se creía exacto y contaba otra cosa; y una limpieza que llevaba desde que se escribió el script sin hacer su trabajo cuando el simulador estaba apagado. Ninguno de los tres habría aparecido leyendo el código con atención. Aparecieron al romperlo, y el último apareció solo.
