# Residuos de la Fase 2 — motor de análisis

**Fecha:** 2026-08-03
**Estado de la fase:** completa y fusionable. 75 tests, motor cerrado, sin regresiones.
**Origen:** revisión final de rama y re-revisión de la tanda de correcciones.

Ninguno de estos puntos bloquea el merge. Todos son reales y se descubrieron ejecutando el motor contra formas de serie que los tests no cubrían. Se dejan aquí porque la Fase 3 congela las estructuras serializadas y la Fase 4 escribe el copy que las muestra — los dos momentos en que salen caros.

---

## 1. La forma en W todavía contradice al mejor temporada

**Severidad: media. Es el defecto que la revisión final marcó como crítico, en su versión más estrecha.**

El motor exige ahora tres condiciones para declarar un declive: caída agregada suficiente, que la caída **empiece** en esa frontera, y que la última temporada **siga abajo**. Eso mata el caso "cae y se recupera".

No mata la forma en W. Con temporadas 9.0 / 9.0 / 9.0 / 7.0 / 9.2 / 9.2 / 7.0 el motor sigue devolviendo `afterSeason: 3` con `seasonsAfter: [4,5,6,7]` mientras `bestSeason` es la 5. La ficha diría "cae a partir de la T3, temporadas 4 a 7" junto a "mejor temporada: 5", con la 5 listada dentro de la caída.

La guarda comprueba solo la temporada final, no todas las posteriores. Fue exactamente lo que especifiqué, así que es un residuo del plan, no de la implementación.

Opción de arreglo para la Fase 3: añadir que ninguna temporada posterior a la frontera supere `averageBefore`. Mata la W sin suprimir un declive genuino que tenga una temporada decente en la cola.

## 2. `declinePoint` es el único veredicto sin suelo por temporada

La tanda de correcciones puso suelos de episodios fiables a `bestSeason`, `worstSeason` y al veredicto de cierre. `declinePoint` se quedó fuera, y la asimetría produce salidas raras:

- Tres temporadas de un episodio fiable cada una (9.0 / 7.0 / 7.0) devuelve `bestSeason: nil` y `worstSeason: nil` — el motor se niega a nombrar la mejor temporada — pero **sí** declara un declive a partir de la T1, con los mismos tres datos.
- Con las temporadas 1-4 completas y la 5 reducida a dos episodios fiables, la prueba de "sigue abajo" se apoya en la media de esa temporada mientras el veredicto de cierre se niega a juzgar esa misma temporada.

No es una regresión: se comportaba igual antes. Pero la incoherencia es nueva y visible.

## 3. `seasons.last` es la última temporada **fiable**, no la última

Si una serie confirmada como terminada tiene su finale sin episodios fiables, el veredicto de cierre nombra como `finalSeason` una temporada anterior. Más alcanzable ahora que `hasEnded` viene de TMDB en vez de inferirse.

## 4. `isOngoing == false` es ambiguo

Significa "terminada" **o** "no lo sabemos y no hay nada programado". El comentario del campo lo dice. **La UI de la Fase 4 no debe renderizarlo como "Finalizada"** sin consultar `hasEnded`.

## 5. Las sumas siguen recorriendo arrays sin ordenar

La tanda hizo deterministas las *selecciones* (mejor episodio, peor episodio) ordenando antes de `max`/`min`. No hizo deterministas las *sumas*: la suma en coma flotante no es asociativa, así que `weightedMean` y `weightedStandardDeviation` pueden diferir en el último ulp según el orden de entrada.

Importa porque la Fase 3 serializa estos valores en el dataset del bundle y la Fase 4 puede recalcularlos en vivo. Una diferencia de un ulp puede cruzar un umbral y hacer que el dataset y el runtime discrepen. Se cierra barato reduciendo sobre el array ya ordenado.

## 6. `bestSeason` y `worstSeason` pueden ser la misma temporada

Con el suelo por temporada, si solo una temporada califica, ambas la nombran. "Mejor temporada 3 / Peor temporada 3" en una serie de cinco temporadas se lee como una contradicción.

Es correcto como afirmación factual — "la temporada mejor valorada de las que tienen datos suficientes" sigue siendo cierta — pero es una decisión de presentación para la Fase 3: suprimir el par cuando coinciden, o cuando solo hay una temporada que califica.

---

## Lo que sí quedó sólido

Merece constar, porque la lista de arriba no da la imagen completa. La revisión final verificó a mano:

- La guarda de "sigue abajo" **no** suprime un declive parcialmente recuperado: con 9/9/9/6/6/6/8.3 la última temporada está muy por encima del valle pero aún 0,7 por debajo de la base, y el declive se sigue detectando.
- Todos los cambios de la tanda mueven en una sola dirección: de afirmar a abstenerse. Ningún input produce una afirmación *distinta y errónea*; producen ausencia de afirmación.
- Ningún test preexistente se debilitó para encajar los suelos. Se reescribió exactamente uno (`singleEpisodeHasZeroStandardDeviation`), y su nueva expectativa es la correcta: una serie de un episodio ya no se declara "muy estable".
- El aislamiento se mantiene: `Foundation` y nada más, sin referencias a red ni UI. La única impureza sigue siendo `EpisodeMetric.stillURL`, ya marcada para la Fase 3.
