# Residuos de la Fase 4 — arranque en frío

**Fecha:** 2026-08-04
**Estado:** fase completa y fusionable. 91 tests, las cinco pestañas con contenido en instalación limpia.
**Origen:** revisión final de rama.

Ninguno bloquea el merge. Se recogen porque la fase siguiente construye sobre estas mismas pantallas.

---

## 1. Una desviación del spec que se perdió entre el plan y las tareas

**Severidad: media. Registrarla como consciente, no como olvido.**

El spec §8 pedía, para Favorites y Watchlist, sugerencias del dataset **"con acción de añadir en un toque"**. Lo entregado es un `MediaSection` cuyas tarjetas son `NavigationLink` a la ficha: añadir son dos toques y una navegación.

Lo relevante no es el gesto, es **cómo se perdió**. La Tarea 5 del plan nunca reformuló ese requisito, así que ninguno de los seis revisores lo tuvo delante — cada uno recibe un brief de tarea, no la sección del spec. Es la segunda vez en el proyecto que un requisito se evapora en ese salto.

**Guarda propuesta por el revisor, barata:** que cada brief de tarea **cite la frase del spec que implementa**.

## 2. Queda un camino a pantalla vacía, un nivel por debajo

**Severidad: media. Es el mejor argumento para la fase siguiente.**

Tocar un póster de un estante curado empuja `MediaDetailView`, que es **íntegramente de red**. `DatasetStore` se referencia en solo dos archivos y ninguno está bajo `Views/Detail/`.

Sin conexión, el revisor toca contenido propio de Plotline y aterriza en una pantalla que no carga. No es regresión —la ficha nunca funcionó sin red— y el plan la excluyó explícitamente. Pero el `SeriesAnalysis` de esa serie **ya está en memoria**, a una llamada de `DatasetStore.shared.entry(forTMDBId:)` de llenar esa pantalla.

## 3. El orden del estante de sugerencias sigue sin ser visible

El estante se retituló a "Analysed by Plotline" porque el anterior, "Highest Rated by Plotline", atribuía a esta app el número de TMDB. El **orden** sigue siendo por `analysis.score.value`, que es correcto, pero invisible: la tarjeta muestra `voteAverage`.

Se resuelve solo cuando la fase siguiente ponga el Plotline Score en la tarjeta. Entonces conviene recuperar "Highest Rated by Plotline", que pasará a ser cierto.

## 4. Dos `ScrollView` del mismo eje anidados, en el camino del revisor

`TrendsView` es un `ScrollView` dentro del `ScrollView` de `statsContent`. El código es preexistente, pero **hasta esta fase `statsContent` era inalcanzable en instalación limpia** — esta rama lo pone delante del revisor por primera vez.

El caso análogo de Discover (`DiscoverySkeletonView`) se probó apuntando TMDB a una IP no enrutable y **no colapsa**. El de Trends no se ha comprobado y, a diferencia del esqueleto, no está deshabilitado. **Verificar, no arreglar a ciegas.**

## 5. Colisiones de `matchedTransitionSource` ahora sistemáticas

Los cinco estantes suman 72 huecos que resuelven a **45 títulos distintos**: `never-decline ∩ perfect-ending` son 17, y Avatar, Friends, Adventure Time y My Hero Academia salen en tres estantes cada uno.

`MediaSection` registra `.matchedTransitionSource(id: item.id, in: namespace)` por tarjeta, así que el mismo id queda registrado hasta tres veces en el mismo namespace. Ya era posible antes (una película puede ser trending y top-rated); esta rama lo vuelve rutinario. Merece una mirada a la transición de zoom desde un estante que comparte título con otro.

Dato asociado que conviene tener presente: **"72 títulos en todos los estantes" sobrestima lo que ve el usuario en un 60 %.**

## 6. Un estante cuyos ids dejen de resolver se ve como carga infinita

`MediaSection` cae a cinco rectángulos con shimmer cuando `items` está vacío. `curatedShelves` comprueba que exista el copy, no que resuelvan los items. Un dataset regenerado con una lista de ids obsoleta daría al revisor un estante titulado que parpadea para siempre — peor que si no estuviera.

`everyShelfIsRenderable` lo caza en tiempo de test, que es por lo que no bloquea, pero el fallback en tiempo de ejecución es el equivocado para este punto de uso.

## 7. Ninguna ruta de fallo de `DatasetStore` está bajo test

`static let shared`, `private init()`, `Bundle.main` cableado. No hay forma de inyectar, así que nada ejercita: recurso ausente, JSON indecodificable, versión que no cuadra, ni la rama `uniquingKeysWith` que sustituyó al `Dictionary(uniqueKeysWithValues:)` que abortaba el proceso.

`entryIdsAreUnique` afirma que la **condición** que disparaba el crash no ocurre; no ejercita el arreglo. Siendo el tema de la fase "que nunca haya una pantalla vacía", la rama que produce vacío es la única sin cobertura. Un `init(bundle:)` junto al singleton haría testeables las cuatro.

## 8. Watchlist muestra su filtro sobre el estado vacío

Favorites oculta su selector cuando no hay nada; Watchlist mantiene el segmentado All / Want to Watch / Watched encima de un estante de sugerencias que ninguno de los tres filtra. Estructura preexistente, más visible ahora que debajo hay contenido.

---

## Lo que sí quedó cerrado

- **Las cinco pestañas muestran contenido en instalación limpia**, verificado pantalla a pantalla, incluida una comprobación con la API de TMDB deliberadamente inaccesible.
- **`StatsView` ya no envuelve la pestaña en una comprobación de datos del usuario.** Compare, Career Profiles y Trends son alcanzables desde el primer segundo, y se verificó que la frase "Everything below works right now" es literalmente cierta: ninguna de esas tres vistas toca favoritos ni watchlist.
- **La estructura de `DiscoveryView` ya no admite un estado en el que falte el contenido propio.** El arreglo es estructural, no un parche: `ScrollView` y `LazyVStack` incondicionales, y solo las secciones dependientes de red cargan sus estados de carga y error.
- Modo oscuro verificado.
