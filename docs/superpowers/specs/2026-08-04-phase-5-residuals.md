# Residuos de la Fase 5 — el análisis en la ficha

**Fecha:** 2026-08-04
**Estado:** fase completa. 120 tests, 0 fallos. Verificada en simulador contra la API real y con la API inalcanzable.
**Origen:** revisión de rama completa más verificación visual del controlador.

---

## Lo que esta fase cierra

El análisis propio de Plotline —score con su desglose, punto de declive, consistencia, veredictos de arranque y cierre, episodios destacados— **se ve en la ficha de la serie**, cada afirmación con los números que la sustentan. Era el último caso conocido del patrón que ha marcado todo el proyecto: funcionalidad construida que el usuario no podía alcanzar.

También cierra el residuo nº 2 de la Fase 4: tocar un póster de un estante curado ya no lleva a una pantalla que no carga. Para las 122 series del bundle la ficha tiene contenido propio **sin una sola petición**.

---

## 1. El estado de la serie no llegaba al motor, y nadie lo habría visto

**Severidad: era crítico. Arreglado en `e5b9751`. Se registra porque explica cómo se cuela un fallo así.**

`SeriesAnalysisEngine` acepta `hasEnded` desde la Fase 2. La Fase 5 lo conectó en `TMDBDetailResponse.toMediaItem()` (Tarea 1) y lo pasó al motor (Tarea 2). Ambas tareas eran correctas **por separado**. Entre ellas quedaba `fetchTMDBDetails()`, que no fusiona el payload entero: copia campo a campo, y nadie añadió `hasEnded` a esa lista.

Resultado en pantalla: en 52 de las 122 series del bundle aparecía "Ends on a high" al abrir la ficha y **desaparecía** unos segundos después, al completarse la descarga de episodios. Justo la regresión que la Tarea 1 existía para evitar.

Lo que importa no es el fallo, es **dónde vivía**: en la costura entre dos tareas, en código que ninguna de las dos modificó. Seis revisiones por tarea no podían verlo — cada revisor recibe un diff. Lo encontró la revisión de rama completa, que es la única que ve los diez commits a la vez.

**Guarda añadida:** la fusión se extrajo a `applyDetails(_:)`, interno precisamente para que un test pueda ejercitarla. `TMDBService` es un `struct`, así que no hay costura para inyectar un doble; sin la extracción, esa ruta seguiría sin cobertura.

## 2. Un fetch parcial podía borrar un análisis completo

**Severidad: era importante. Arreglado en `e5b9751`.**

`recomputeAnalysis()` asignaba sin condiciones. `TMDBService.fetchAllSeasons` se traga los fallos por temporada, y `totalSeasons` se queda en 1 si la petición de detalles falla. Con conexión inestable: se pide solo la temporada 1, `DiskCache` la sirve, y un análisis de cinco temporadas queda sustituido por uno de una — o por "Not Enough Ratings Yet" en una serie cuyo análisis completo viaja dentro de la app.

Es la lección de la Fase 4 un nivel más abajo: allí una **rama de error** escondía contenido propio; aquí un **resultado de red** lo destruía.

`isAtLeastAsComplete(_:)` deja pasar el resultado en vivo solo cuando no hay nada empaquetado que proteger o cuando cubre al menos tantas temporadas.

## 3. Dos textos afirmaban más de lo que el motor demuestra

**Arreglados en `20690ec` y `6b2e728`. Los encontré mirando la pantalla, no leyendo el diff.**

- **"Season 5 averaged 9.0; its best, season 5, averaged 9.0."** Cuando la temporada final es la mejor —el caso *normal* de `endsStrong`— la evidencia se comparaba consigo misma.
- **"Safe to skip"** sobre episodios de 7.9 a 8.4. El motor establece distancia respecto a la media de **su propia temporada**, nada más. En una serie que promedia 9, su peor hora sigue siendo buena, y recomendar saltarla es un consejo que el análisis no sostiene.

Con estos van **seis** textos corregidos en el proyecto por la misma razón. Ningún test los detectó, y no por descuido: un test de copy compara una cadena con otra cadena. Lo que falla no es la cadena, es la distancia entre lo que el predicado prueba y lo que la frase promete — y eso solo se ve leyéndola sobre datos reales.

`StandoutCopyTests.relativeWeaknessIsNotAbsoluteWeakness` es el intento de convertir eso en algo comprobable: afirma sobre el dataset que se distribuye que un episodio "flojo" puede pasar de 8.

## 4. Un test codificaba el comportamiento defectuoso

`DetailAnalysisTests.freshEpisodesWin` daba tres temporadas planas a una serie empaquetada de cinco y afirmaba que la sustitución era correcta. Pasaba, y describía exactamente el defecto nº 2.

Se corrigió, no se borró. Merece registro porque **un test verde puede ser la documentación de un fallo**, y este pasó por su propia revisión de tarea sin que nadie lo notara: aislado, parecía razonable.

---

## Lo que queda abierto

### 5. Dos afirmaciones blandas que no se han tocado

- `"Holds its level to the end"` se emite con un déficit respecto al pico de hasta 0.49. Con 0.4 sigue siendo defendible, pero es la frase más generosa del conjunto.
- `"First %d episodes"` cuenta los primeros seis episodios **fiables**, no los primeros seis emitidos. Con episodios iniciales poco votados, el número mostrado no es el que el lector supone.

Ambas imprimen sus cifras debajo, así que ninguna es falsa en pantalla. Se dejan anotadas, no arregladas.

### 6. La ficha sigue sin ser verificable a mano de forma cómoda

Los clics sintéticos vía AppleScript están bloqueados por permisos de accesibilidad y no hay `idb` instalado, así que no se puede desplazar la ficha real en el simulador. La verificación se hizo con una sonda temporal que renderiza la sección y muestra el estado interno del view model tras la carga real — y luego se revirtió.

Funcionó, pero significa que **nadie ha visto la sección en su sitio real dentro de la ficha, desplazándose**. La colocación se verificó leyendo las llaves del archivo, dos veces. Para la fase siguiente conviene resolver esto: es la clase de verificación que en este proyecto ha encontrado más defectos que cualquier test.

### 7. La guarda nueva protege en una sola dirección

`isAtLeastAsComplete` solo interviene mientras `analysisSource == .bundled`. En cuanto un resultado en vivo entra, la guarda deja pasar cualquier cosa después, incluido un `.insufficientData`.

Hoy no es alcanzable: la única reentrada, el botón "Try Again" de la ficha, solo aparece con `episodesBySeason` vacío, que es justo el estado en el que `recomputeAnalysis` nunca llegó a mover el origen. Pero es una guarda que se desactiva sola, y la primera ruta de refresco que llame dos veces la atravesará sin avisar.

Segunda concesión de la misma guarda: compara **número** de temporadas, no identidad. Una descarga en vivo genuinamente completa que produzca una temporada analizable menos que el bundle —por ejemplo si los votos de una temporada caen bajo el umbral de fiabilidad— queda bloqueada de forma permanente, sin manera de forzar la actualización desde la UI.

Ambas se aceptan a sabiendas: el fallo que evitan es visible y frecuente, y el que introducen es raro y silencioso. Conviene revisarlas cuando exista una ruta de refresco real.

### 8. `analysisSource` no lo lee ninguna vista

Existe para distinguir lo empaquetado de lo recalculado y hoy solo lo consumen `isAtLeastAsComplete` y los tests. Se justifica por eso, pero si la Fase 6 no le da uso en UI, conviene revisarlo.

### 9. Residuos menores heredados, conscientes

- `component()` en `PlotlineScoreCard` pone una `accessibilityLabel` que la etiqueta combinada de la tarjeta anula. Inofensivo.
- La rama de respaldo de `consistencyEvidence` (sin episodio más alto ni más bajo) es inalcanzable: el motor siempre los rellena cuando hay análisis.

---

## Para la Fase 6

El "dónde verlo" del spec §7, con las dos correcciones ya registradas en el propio spec: TMDB **no** devuelve deep links por plataforma, y la atribución a JustWatch se exige **en cada ficha** bajo pena de revocar el acceso a la API — con toda la app corriendo sobre TMDB, eso es riesgo existencial, no un remate.

Y una guarda de proceso que esta fase ha ganado a pulso: **las costuras entre tareas necesitan su propio test**. Las dos únicas cosas graves de esta rama vivían en código que ninguna tarea tocó.
