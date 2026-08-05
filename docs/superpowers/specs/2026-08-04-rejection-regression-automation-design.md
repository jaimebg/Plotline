# Automatizar la regresión del rechazo y el preflight de release

**Fecha:** 2026-08-04
**Estado:** diseño aprobado, sin implementar.
**Origen:** el §11 del spec 4.2 pide un test de regresión del rechazo que nunca se escribió, y preparar una release depende hoy de que alguien se acuerde de mirar.

---

## Por qué

El §11 del spec 4.2 pide, literalmente: *"Test de regresión del rechazo: instalación limpia, sin red, recorrer las cinco pestañas y verificar que ninguna está vacía."* No existe.

Lo que existe es `ColdStartTests`, y prueba otra cosa: que `DatasetStore` tiene entradas, cinco listas, y que resuelven. Es un test de los **datos**, no de las **pantallas**. El defecto que provocó el rechazo —`StatsView` envolviendo Compare, Career Profiles y Trends, ninguno de los cuales necesita datos de usuario, en un check de favoritos guardados— **pasaría hoy en verde**. El arreglo vive en `StatsView.swift:51`; nada afirma que siga ahí mañana.

Es la misma forma exacta del residuo nº 5 de la Fase 7: un test que no puede fallar. Con la diferencia de que este protege la causa directa de tres rechazos encadenados.

Y alrededor, cuatro huecos que salieron al mirar:

- **`ShippedDatasetTests` no los ejecuta `xcodebuild test`.** Viven en el paquete SwiftPM de `Tools/DatasetGenerator`, y son los únicos que abren `Plotline/Resources/PlotlineDataset.json` **como fichero en disco** —vía `#filePath`— y los únicos que afirman sus invariantes cruzadas entre listas y su barrido de secretos. `ColdStartTests` y `DatasetStoreTests` sí leen ese mismo fichero, pero la copia que va dentro del bundle construido, vía `Bundle.main`, y ninguno de los dos comprueba nada de eso. Una release puede llevar un dataset que viole las cinco invariantes con la suite de la app entera en verde.
- **`PlotlineDataset` no guarda fecha de generación.** "Cómo de viejo es esto" no tiene respuesta en ninguna parte del repositorio.
- **El repo no tiene ni un tag.** No hay ancla contra la que comparar una versión.
- **No hay CI.** Todo lo que no se ejecute a mano, no se ejecuta.

El dataset, en cambio, **sí entra en el bundle solo**: el grupo sincronizado incluye todo `Plotline/` y la única excepción es `Info.plist`. Meterlo no es el riesgo. Que esté podrido, sí.

---

## Alcance

**Entra:** el test de regresión del rechazo como test de UI, y un script de preflight de release.

**No entra, y sigue abierto:**

- Los tres tests infalsificables de la Fase 7 (`selectionPersists`, `regionKeysAreUntouched`, `regionlessLocaleYieldsNil`). El residuo nº 5 de esa fase queda como estaba. Nota para quien lo retome: `selectionPersists` es peor de lo que dice aquel documento — `WatchRegionStore` lee `UserDefaults` **solo en `private init()`** y es un singleton, así que no existe ninguna secuencia de llamadas, desde ningún test, capaz de observar un arranque en frío. No es un test débil: es un límite inalcanzable.
- Los textos de App Store Connect, que se siguen pegando a mano **a propósito**. El `docs/app-review/README.md` lo argumenta y el argumento sigue en pie.
- CI. Nada de esto asume una máquina que lo ejecute sola.

---

## 1. El test de regresión del rechazo

### 1.1 La condición que importa es la instalación limpia, no la red

La causa del rechazo no tuvo nada que ver con la red. TMDB funcionaba. La pestaña se veía vacía porque condicionaba su contenido a datos de usuario que un revisor recién instalado no tiene.

`FavoritesManager` y `WatchlistManager` persisten con **SwiftData**, dentro del contenedor de la app. El truco de `NSArgumentDomain` —lanzar con `-clave valor` para sobrescribir `UserDefaults` sin cooperación de la app— no alcanza un almacén de SwiftData. Borrar el contenedor es la única forma honesta de conseguir el estado que se quiere probar:

```
xcrun simctl uninstall booted com.jbgsoft.Plotline
```

### 1.2 El test verifica su propia precondición

Un test que depende de que el runner haya hecho el `uninstall` es un test que pasa en verde cuando el runner se lo salta — precisamente el modo de fallo que este trabajo existe para eliminar.

Por eso la primera aserción del suite no es sobre contenido: **si la pestaña Favorites muestra filas guardadas, el test falla** con un mensaje que dice que el contenedor no estaba limpio y cómo dejarlo limpio. Un contenedor sucio se ve en rojo, no en verde por el motivo equivocado.

### 1.3 Dos pasadas del mismo suite

Las mismas anclas y los mismos mínimos, ejecutados en dos condiciones. Ninguna de las dos cubre a la otra:

| Pasada | Clave TMDB | Qué protege | Dónde corre |
|---|---|---|---|
| **Hambrienta** | `TMDB_API_KEY=""` | Que el dataset empaquetado sostiene las cinco pestañas por sí solo. Determinista: no depende de la red, de una clave válida ni del límite de peticiones. | En el `xcodebuild test` de siempre. Por defecto. |
| **Viva** | la real, del plist | La sesión del revisor tal cual. El camino en vivo es el único que puede vaciar una pantalla que el dataset había llenado. | Solo desde el preflight de release. |

Las dos direcciones importan, y por eso están las dos:

- Con TMDB vivo, el test pasa en verde **aunque el dataset empaquetado se haya podrido**, porque los datos en vivo tapan el agujero. La pasada hambrienta es lo único que lo ve.
- Con TMDB muerto, el camino de recomputación en vivo **nunca se ejecuta**. El contrato del dataset en `CLAUDE.md` avisa justo de ese riesgo: que un resultado en vivo parcial sustituya un análisis completo por un fragmento. La pasada viva es lo único que lo ve.

La selección se hace con una variable de entorno leída por el suite, `PLOTLINE_UITEST_MODE`, con valor por defecto `starved`. `xcodebuild` reenvía al proceso runner cualquier variable prefijada con `TEST_RUNNER_`, quitándole el prefijo, así que el preflight lanza la pasada viva con `TEST_RUNNER_PLOTLINE_UITEST_MODE=live`.

### 1.4 Cómo se deja a la app sin TMDB, sin código de test en el binario

`Secrets.swift:22` da hoy prioridad al plist empaquetado sobre las variables de entorno:

```swift
plistSecrets["TMDB_API_KEY"] ?? environment["TMDB_API_KEY"] ?? ""
```

Se invierte. Una variable puesta explícitamente debe ganar a un fichero empaquetado por defecto, que es lo que espera cualquiera que la ponga — y `CLAUDE.md` ya documenta las dos vías como alternativas, así que no contradice nada escrito.

Hecho eso, la pasada hambrienta solo tiene que lanzar con `TMDB_API_KEY=""` en `launchEnvironment`. **Cero código que exista solo para los tests dentro del binario que se envía**, y ninguna configuración de build aparte.

*Efecto colateral a tener presente:* en una máquina donde `TMDB_API_KEY` ya esté exportada en el entorno, esa variable pasa a ganarle al plist. Es el comportamiento esperado y es el motivo del cambio, pero es un cambio de comportamiento en producción y va anotado como tal.

### 1.5 Limitación registrada: 401 no es lo mismo que estar sin red

La pasada hambrienta prueba **"TMDB no devuelve nada"** —un 401 inmediato— y no **"la radio está apagada"**, que son timeouts largos y otro perfil de latencia.

Para lo que el test afirma, que las pestañas se llenen del dataset empaquetado, el observable es idéntico. Para la experiencia de alguien realmente sin cobertura, no lo es: los spinners viven mucho más. Es una aproximación consciente, del mismo tipo que `WatchAttributionSourceTests` leyendo su propio fuente, y se acepta por la misma razón: la alternativa era no tener nada. Queda escrito para que nadie la lea como más de lo que es.

### 1.6 Anclas y mínimos

Un identificador de accesibilidad por pestaña, sobre el contenedor que lleva el contenido sustantivo:

| Pestaña | Ancla | Aserción |
|---|---|---|
| Discover | contenedor de estantes curados | existe y muestra ≥ 2 estantes |
| Favorites | estante de sugerencias | existe y muestra ≥ 2 elementos |
| Watchlist | estante de sugerencias | existe y muestra ≥ 2 elementos |
| Stats | contenedor de las secciones que **no** dependen de datos de usuario | existe, y dentro están las anclas de Compare, Career Profiles y Trends |
| Settings | su lista | existe y muestra ≥ 2 filas |

**Los mínimos son deliberadamente bajos, y no por pereza.** Los estantes son `LazyHStack` dentro de un `ScrollView`: XCUITest solo ve las celdas que se han materializado, que son las visibles. Afirmar "12 elementos" contra un estante que enseña tres se pondría rojo siempre, y afirmarlo tras hacer scroll introduce fragilidad por una garantía que ya está cubierta mejor en otro sitio.

El reparto queda así, y es el que hace que las dos capas no se solapen:

- **El test de UI afirma que el contenedor existe y no está vacío.** Es lo único que puede ver, y es exactamente el defecto que provocó el rechazo: un contenedor que desaparece porque se condicionó a datos de usuario.
- **`ColdStartTests` afirma las cantidades exactas** —cinco listas, `topRated(limit: 12)`, ≥ 60 títulos— porque ve el dataset entero y no depende de qué esté en pantalla.

Las aserciones son sobre **estructura**, no sobre qué títulos concretos llegaron, así que no cambian entre la pasada viva y la hambrienta.

**Stats lleva dos aserciones, no una:** que aparezca el estado vacío de "tus stats" **y** que las secciones de debajo tengan contenido. El defecto original fue exactamente que lo segundo desaparecía junto con lo primero. Una sola aserción sobre el estado vacío lo dejaría pasar.

### 1.7 Dónde vive

Target nuevo, `PlotlineUITests`, con un solo suite. La pasada hambrienta entra en la acción de test del esquema, así que el `xcodebuild test` que documenta `CLAUDE.md` la ejecuta sin argumentos nuevos.

---

## 2. El preflight de release

`Scripts/release-preflight.sh`, ejecutable a mano y enganchado además a la pre-action de Archive del esquema.

**Aviso que va en el propio script y en el README:** una pre-action que devuelve error **no aborta el archive de forma fiable** en Xcode reciente. Avisa en el log en el momento exacto en que importa, pero no impide nada. Quien lo lea como una barrera se equivoca, y por eso está escrito aquí antes que su lista de comprobaciones.

Qué hace, en orden:

1. **Suite de la app.** `simctl uninstall`, luego `xcodebuild test`. Incluye la pasada hambrienta.
2. **Pasada viva.** Otro `uninstall` y el mismo suite con `TEST_RUNNER_PLOTLINE_UITEST_MODE=live` y la clave real. Es el único sitio donde corre.
3. **Suite del generador.** `cd Tools/DatasetGenerator && swift test`. Aquí viven los `ShippedDatasetTests`. Cerrar ese hueco no cuesta código nuevo: cuesta una línea de script.
4. **Frescura del dataset.** Falla si el fichero no declara cuándo se generó, o si declara una fecha de hace más de **90 días**. El número es un juicio, no un cálculo, y va marcado como tal en el script.
5. **Coherencia de versión.** `MARKETING_VERSION` del proyecto debe coincidir con la versión que nombran los ficheros de `docs/app-review/`. Es literalmente el "actualizar la info": subes el build y olvidas los textos, o al revés, y sale rojo. No hay otro ancla posible porque el repo no tiene tags.
6. **Sin rastro de OMDb.** Lo pide el §11. Hoy hay 0 referencias, así que es una guarda contra la reintroducción, no un arreglo.
7. **Imprime el checklist manual** de App Store Connect, el "orden que importa" del README. No lo automatiza — el propio README argumenta que no debe automatizarse, y el argumento se respeta. Lo recuerda.

### 2.1 `generatedAt`

Entra en `PlotlineDataset` como **`String?` en ISO8601**. Dos decisiones, cada una con su motivo:

- **Opcional**, para que el fichero comprometido hoy siga decodificando en la app sin regenerarlo. Es el preflight quien lo rechaza por ausente, no el decodificador. Así la primera release posterior a este cambio obliga a regenerar, sin romper nada mientras tanto.
- **`String` y no `Date`**, para no acoplar la comprobación a la estrategia de fechas de un `JSONDecoder`. Ese acoplamiento invisible es exactamente lo que hace infalsificable a `regionKeysAreUntouched`, y no merece la pena repetirlo en un campo nuevo. `firstAirDate` ya sienta el precedente en el mismo fichero.

`PlotlineDataset.swift` se comparte por symlink con el generador y **solo puede importar Foundation**. `String` lo cumple sin discusión.

El generador pasa a escribir el campo siempre.

---

## 3. Ficheros que toca

| Fichero | Cambio |
|---|---|
| `PlotlineUITests/` | Target nuevo, un suite |
| `Scripts/release-preflight.sh` | Nuevo |
| `Plotline/App/Secrets.swift` | Invertir prioridad: entorno antes que plist |
| `Plotline/Models/PlotlineDataset.swift` | `generatedAt: String?` |
| `Tools/DatasetGenerator/` | Escribir `generatedAt` |
| Vistas de las cinco pestañas | Identificadores de accesibilidad en los contenedores de contenido |
| `Plotline.xcodeproj` | Target nuevo, pre-action de Archive |
| `CLAUDE.md`, `docs/app-review/README.md` | Documentar el preflight y su límite |

---

## 4. Modos de fallo del propio trabajo

- **La pre-action no aborta.** Cubierto en §2 y escrito en dos sitios más.
- **Contenedor sucio.** Rojo con mensaje explícito, §1.2.
- **Pasada viva roja por límite de peticiones de TMDB.** Debe distinguirse de un fallo real: el suite reporta el fallo de red como tal, con su código, en vez de como "pestaña vacía". Un rojo ambiguo en el paso previo a enviar enseña a ignorar los rojos.
- **Identificadores de accesibilidad que se borran en un refactor.** El test se pone rojo, que es el comportamiento correcto, pero el mensaje debe decir qué ancla falta y en qué vista.

---

## 5. Cómo se demuestra que estos tests sí pueden fallar

El tema de este trabajo es que hay tests que no pueden fallar. Sería absurdo cerrarlo añadiendo más.

**Cada aserción nueva se somete a una mutación deliberada, y se registra el resultado.** Como mínimo:

| Mutación | Debe ponerse en rojo |
|---|---|
| Volver a envolver el contenido de `StatsView` en un check de favoritos | Ancla de Stats |
| Borrar el `.accessibilityIdentifier` de un contenedor | Esa pestaña, con mensaje útil |
| Vaciar `lists` del dataset empaquetado | Discover, en la pasada hambrienta |
| Saltarse el `simctl uninstall` con favoritos guardados | La precondición de §1.2 |
| Borrar `generatedAt` del fichero | Paso 4 del preflight |
| Subir `MARKETING_VERSION` sin tocar `docs/app-review/` | Paso 5 del preflight |

Una mutación que no consiga poner nada en rojo es un test que sobra o que está mal escrito, y se arregla antes de dar la fase por cerrada.

---

## 6. Lo que este trabajo no protege

Escrito para que nadie le atribuya más alcance del que tiene:

- No prueba que la app se vea **bien**, solo que no se vea **vacía**. Un layout roto con contenido pasa en verde.
- No prueba iPad. Las anclas son independientes del tamaño, pero los mínimos se afirman en un destino de iPhone. Una regresión de columnas como la de la Fase 6 no la ve.
- No prueba la experiencia real sin cobertura, §1.5.
- No sustituye mirar la pantalla. Las tres últimas fases tuvieron su único fallo grave en una costura, y dos de las tres veces la verificación visual existía pero miraba el sitio equivocado. Esto automatiza un recorrido concreto; no automatiza el criterio.
