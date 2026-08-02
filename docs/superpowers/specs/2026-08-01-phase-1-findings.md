# Hallazgos de la Fase 1 — funcionalidad desconectada

**Fecha:** 2026-08-01
**Contexto:** descubierto durante la ejecución de la Fase 1 (eliminación de OMDb). Ninguno entra en el alcance de esa fase, pero los tres afectan al rechazo por Guideline 4.2 y condicionan las Fases 2-4.

---

## El patrón

El rechazo de Apple decía:

> the app primarily offers content for users to view or use, but there isn't enough of this content currently available in the app

El diagnóstico inicial fue que `StatsView` escondía Compare, Career Profiles y Trends detrás de un `ContentUnavailableView` cuando el usuario no tenía favoritos, de modo que el revisor nunca los vio.

Durante la Fase 1 aparecieron **dos casos más del mismo patrón**. No es un fallo aislado: es sistemático. Hay funcionalidad construida, commiteada y descrita en la documentación que el usuario no puede alcanzar.

---

## Hallazgo 1 — `SeriesGraphView` es código muerto *(resuelto)*

**Severidad: alta. Reconectado en el commit `af8d82e`.**

Reconectarlo destapó un bug latente en la propia vista: los marks del eje Y estaban fijados a `[0, 2.5, 5, 7.5, 10]` mientras la escala usa un dominio ajustado al rango real de la temporada (~7,4–9,4 en Breaking Bad T1). Los valores fuera de dominio se dibujaban fuera del área del plot y se desbordaban sobre las vistas contiguas. Ahora los valores se derivan del dominio. Es justo el tipo de defecto que solo aparece al usar la vista de verdad — llevaba escrito y sin ver desde `16f6c77`.

El diagnóstico original, que se mantiene como registro:

`Plotline/Views/Detail/SeriesGraphView.swift` solo se instancia desde sus propios `#Preview` (líneas 543 y 553). No lo referencia ninguna vista viva.

Historia:
- Entró en `MediaDetailView` en `7393ec2` ("feat: add media detail view with ratings and episode graph")
- Salió en `16f6c77` ("feat: add settings with light/dark theme support"), al parecer sin querer
- Lleva desconectado desde entonces, también en `main`

Por qué importa:
- `README.md` lo encabeza como *"Episode Quality Graphs — Visualize TV series episode ratings with interactive Swift Charts"*
- `CLAUDE.md` lo llama literalmente *"The star feature"*
- Es el gráfico interactivo que diferencia a Plotline de cualquier catálogo de películas

Agravante introducido por la Fase 1: al quitar los enlaces a IMDb de cada celda, la rejilla de episodios se quedó **sin ninguna interacción**. La sección de episodios de la ficha es hoy una tabla de colores inerte. Es justo la pantalla que App Review mira para juzgar si la app hace algo más que listar películas.

Reconectarlo son pocas líneas en `MediaDetailView`: la vista ya acepta `episodes: [EpisodeMetric]` y `seasonNumber: Int`, y `episodesBySeason` tiene ambos. Además daría consumidor legítimo a `episodes`, `selectedSeason` y `selectSeason(_:)`, que la Fase 1 conservó a propósito para esto.

**Recomendación: primer punto de la Fase 2, no de la Fase 4.**

---

## Hallazgo 2 — Los deep links nunca funcionan *(resuelto)*

**Severidad: media. Vía muerta eliminada en el commit `af8d82e`.**

Se borró `DeepLinkManager.handleURL(_:)`, el `.onOpenURL` de `PlotlineApp` y `pendingMediaItem`, que se quedaba sin productor. **`DeepLinkManager` sobrevive**: no era solo para deep links, es el bus de navegación que usan los App Intents de Siri (`SearchPlotlineIntent` escribe en el App Group `group.com.jbgsoft.Plotline` y `PlotlineApp.handleSiriSearchQuery` lo recoge al activarse). Borrarlo entero habría roto Siri, que sí funciona.

El diagnóstico original:

`Plotline/Info.plist` no declara `CFBundleURLTypes`, así que el esquema `plotline://` no está registrado. iOS nunca entregará esas URLs a la app.

Sin embargo existe toda la maquinaria:
- `Plotline/App/DeepLinkManager.swift` parsea `plotline://` y filtra con `guard url.scheme == "plotline"`
- `Plotline/App/PlotlineApp.swift:57` tiene `.onOpenURL`
- Se envió en `d232f00` ("feat: add deep linking and Siri shortcuts")

Los App Intents de `Plotline/Intents/` no dependen del esquema de URL, así que los atajos de Siri pueden seguir funcionando; lo que está muerto es la ruta de deep link.

Decisión pendiente: registrar el esquema y aprovechar la funcionalidad, o borrar `DeepLinkManager` y su cableado. Mantener código muerto que promete una feature es lo peor de las dos opciones.

---

## Hallazgo 3 — Modo de fondo declarado y no usado *(resuelto)*

**Severidad: alta como vector de rechazo independiente. Ya corregido.**

`Info.plist` declaraba `UIBackgroundModes = ["remote-notification"]` mientras la app no contenía **nada** de notificaciones push: ni `UNUserNotificationCenter`, ni `registerForRemoteNotifications`, ni `didReceiveRemoteNotification`.

Declarar un modo de fondo que no se usa incumple la Guideline 2.5.4 y es motivo de rechazo por sí solo, al margen del 4.2.

Corregido en el commit `94141b9`: la clave se eliminó por completo.

---

## Lo que esto implica para el plan

El spec de la Fase 4 asume que hay que *añadir* contenido para que la app no se vea vacía. Estos hallazgos dicen que una parte del trabajo no es añadir sino **reconectar lo que ya existe**. Antes de construir nada nuevo conviene auditar qué más está escrito pero inalcanzable — el patrón ya se ha repetido tres veces.

Los tres están resueltos, pero la auditoría sigue pendiente y es el primer punto de la Fase 2: por cada vista de `Plotline/Views/`, comprobar que tiene al menos un consumidor fuera de sus propios `#Preview`. Candidatos que ya se han visto de pasada y no se han comprobado: `CompactSeriesGraphView` y `AllSeasonsGraphView`, ambos en `SeriesGraphView.swift`.

Lección transversal: un defecto de layout como el del eje Y **no lo detecta ni el compilador, ni los tests, ni una revisión de código**. Solo aparece ejecutando la vista. Conviene que cada fase termine con una comprobación visual real, no solo con la suite en verde.
