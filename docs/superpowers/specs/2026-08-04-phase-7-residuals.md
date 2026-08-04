# Residuos de la Fase 7 — dónde verlo

**Fecha:** 2026-08-04
**Estado:** fase completa. `TEST SUCCEEDED`, 0 fallos, 146 tests. Verificada en simulador contra la API real.
**Origen:** revisión de rama completa más verificación visual del controlador.

---

## Lo que esta fase cierra

La ficha responde ahora a la primera pregunta que hace cualquiera: **dónde se puede ver**. Proveedores agrupados por suscripción, gratis, con anuncios, alquiler y compra; región resuelta del `Locale` con selector manual entre las 126 que devuelve TMDB; respuesta cacheada un día completa, así que cambiar de región no cuesta una petición.

Y cierra el §7 del spec con dos correcciones que hubo que hacerle antes de implementarlo, ambas verificadas contra la API y sus términos, no recordadas.

---

## 1. La atribución a JustWatch: cómo se protege y qué la protege de verdad

TMDB, literal: *"In order to use this data you must attribute the source of the data as JustWatch"* y *"If we find any usage not complying with these terms we will revoke access to the API."* Con toda la app corriendo sobre TMDB desde la Fase 1, esa revocación no degrada una función: apaga el producto.

La protección **estructural** es que el `Text` de la atribución vive en el mismo `VStack` que dibuja los proveedores, como hermano de la rama condicional, no dentro de ella. Ningún punto de uso puede obtener una mitad sin la otra: todos los subcomponentes son privados y la vista tiene un solo llamador.

Lo que merece registro es que **los tests no protegían eso**. `WatchAttributionTests` comprueba la constante; borrar la línea que la dibuja dejaba la suite entera en verde — verificado, no supuesto. Se añadió `WatchAttributionSourceTests`, que lee el propio fuente de la vista vía `#filePath` y comprueba que la línea existe y no está anidada en un condicional.

Es una técnica inusual y conviene ser honesto sobre sus límites, que el revisor identificó bien:

- Falla donde la ruta de compilación no exista en ejecución: un test en dispositivo físico, o un CI que compile y ejecute en checkouts distintos. En simulador sobre la máquina de build funciona.
- La heurística de indentación (`<= 12`) daría un falso fallo ante un refactor inocente, por ejemplo envolver el `VStack` en un `Group`.
- Es esquivable: un `.hidden()` en la misma línea la superaría.

Es una aproximación estructural, no una aserción sobre el árbol renderizado. Se acepta porque el requisito no admite una segunda oportunidad y la alternativa era no tener nada.

## 2. La sección no aparecía en la mayoría de los caminos

**Severidad: era crítico. Arreglado en `e548924`.**

`loadWatchProviders` empezaba con `guard let mediaType = media.mediaType else { return }`. TMDB envía `media_type` en `/trending` y `/search/multi`, y **lo omite** en `/movie/top_rated`, `/tv/top_rated` y todo `/discover`. Resultado: quien entrara desde Top Rated, un género, What to Watch, Trends, Best Years, Decade Battle, Smart Lists o Stats no veía la sección. Sin error, sin hueco, sin nada.

Lo instructivo es **por qué mi verificación visual no lo detectó**: la hice con una entrada del dataset empaquetado y con Trending, que son justo dos de las pocas rutas donde el campo sí viaja. Miré la pantalla, que es lo que en este proyecto ha encontrado más defectos que cualquier test, y aun así miré la pantalla equivocada.

El arreglo es la derivación que el código ya usaba dos veces: `media.isTVSeries ? .tv : .movie`.

## 3. La etiqueta de región podía mentir sobre su propio contenido

**Severidad: era importante. Mismo commit.**

La vista leía `WatchRegionStore.shared.selected` dentro de su `body` mientras los proveedores venían del view model. El store es un singleton corriente, no observable, así que cualquier reevaluación del body por otro motivo —un scroll, una pantalla hermana cambiando de región— redibujaba la etiqueta desde el store con los proveedores todavía de la región anterior. Un catálogo de un país rotulado con el nombre de otro.

La región vive ahora junto a los datos que describe.

## 4. El selector no ofrecía la región del propio usuario

**Severidad: era importante. Mismo commit.**

La respuesta solo lista regiones donde el título **está** disponible. Alguien en España abriendo un título solo de Estados Unidos leía "no disponible en España", abría el selector y **España no estaba**. Podía mirar en cualquier sitio menos en su casa, la elección se persistía para todos los demás títulos, y `reset()` no lo llama nadie: no había vuelta atrás.

Ahora la región propia se incluye siempre, aunque la respuesta que dé sea "aquí no".

---

## Lo que queda abierto

### 5. Tres tests no pueden fallar

El revisor los nombró y se registran en vez de arreglarse a medias:

- `regionKeysAreUntouched` construye su propio `JSONDecoder`, así que cambiar `NetworkManager` a `.useDefaultKeys` lo deja verde mientras todos los nombres de proveedor dejan de decodificar en producción.
- `regionlessLocaleYieldsNil` documenta una guarda (`!region.isEmpty`) que puede borrarse sin que el test se entere, porque `Locale("eo").region` ya es `nil`.
- `selectionPersists` lee del mismo singleton que escribe: borrar el `UserDefaults.standard.set` del setter lo deja verde, así que la pérdida silenciosa de la región al reiniciar viaja sin cobertura.

El tercero es el que más pesa. Los tres piden un test que cruce el límite real —el decoder de `NetworkManager`, el arranque en frío— y eso es trabajo, no un retoque.

### 6. Sin cobertura en el orden de grupos ni en la ordenación por prioridad

`categories(in:)` y `sortedByPriority` son privados y no los ejercita nada. Invertir el comparador o reordenar Stream/Free/Ads/Rent/Buy no pone nada en rojo. El comparador está verificado a mano como orden débil estricto válido, con los proveedores sin prioridad al final.

### 7. Un fallo de red no dice nada

Si la petición falla, `availableWatchRegions` queda vacío y la sección no se dibuja. No es una afirmación falsa —y es distinguible de "no disponible aquí", que sí muestra frase y selector— pero quien esté sin conexión no recibe explicación alguna.

### 8. `reset()` no lo llama nadie

Existe en `WatchRegionStore` y está probado, pero ningún punto de uso lo invoca: no hay entrada en Settings. Con el arreglo nº 4 el usuario ya puede volver a su región desde el propio selector, así que no bloquea nada. O se cablea o se borra.

### 9. Los nombres largos siguen recortándose

Dos líneas con espacio reservado en vez de una, así que "Netflix Standard With Ads" ya se lee a medias en vez de quedar en "Netflix Sta…". Con nombres aún más largos sigue habiendo puntos suspensivos. La etiqueta de accesibilidad lleva el nombre completo.

---

## Lo que el spec pedía y no se hizo, a propósito

- **Deep links a las apps de las plataformas.** El endpoint no los da. Solo devuelve un enlace a la página del título en TMDB.
- **Un ajuste de región en Settings.** El selector está donde se usa.

## Para la fase siguiente

Con el §7 cerrado, del spec quedan §12 (reenvío a App Review) y las capturas de iPad que la Fase 6 dejó pendientes. El trabajo de producto contra el 4.2 está hecho: análisis propio auditable, arranque en frío con contenido en las cinco pestañas, app nativa de iPad y disponibilidad de visionado.

Y la guarda de proceso que esta fase añade a las dos anteriores: **verificar en pantalla no basta si se verifica en el camino equivocado.** Tres fases seguidas con su único fallo grave en una costura, y esta vez la costura era qué campos trae cada endpoint de la lista de la que viene el usuario.
