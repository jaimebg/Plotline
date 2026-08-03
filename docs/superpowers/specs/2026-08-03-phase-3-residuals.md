# Residuos de la Fase 3 — generador y dataset

**Fecha:** 2026-08-03
**Estado:** fase completa y fusionable. 48 tests de paquete, 74 de app, dataset reproducible byte a byte.
**Origen:** revisión final de rama y re-revisión de su tanda de correcciones.

Ninguno bloquea el merge. Se dejan aquí porque la Fase 4 construye UI sobre este archivo y escalar la semilla toca casi todos.

---

## 1. Solo sobreviven dos estantes *(decisión pendiente antes de la Fase 4)*

**Severidad: alta como producto.**

Con predicados honestos y un mínimo de 3 títulos por lista, de las cinco listas curadas solo se publican dos: `never-decline` (8) y `perfect-ending` (6). Las otras tres — `falls-off`, `slow-burn`, `rollercoaster` — se quedan en 2, 2 y 1.

La causa no son los predicados. Se comprobó re-derivando cada uno con y sin las cláusulas nuevas: **la membresía no cambió en ninguno**. Los tres caen por el mínimo de 3 contra una semilla de 24 títulos.

**El arreglo es más semillas, no predicados más laxos.** Aflojar los predicados devolvería exactamente el defecto que la revisión final marcó como bloqueante: estantes que afirman lo contrario de lo que dicen sus propios datos.

Decidir antes de que la Fase 4 diseñe la pantalla: para una app rechazada por falta de contenido, dos estantes son pocos.

## 2. La Fase 4 debe aportar el copy en inglés

`CuratedList` ya no lleva `title` ni `subtitle` — se quitaron porque estaban escritos en español en una app cuyas vistas son íntegramente inglesas, y porque el copy de UI no pertenece a un archivo de datos.

La app posee ahora ese texto, indexado por `id`. Los dos ids que se publican son `never-decline` y `perfect-ending`. Mantenerlo fuera del dataset deja además la puerta abierta a localizar de verdad más adelante.

## 3. Calibración de umbrales del motor *(Fase 2, evidenciada aquí)*

Ejecutar contra datos reales es lo que produjo esta evidencia. Los umbrales viven en el motor de la Fase 2.

**El motor acierta pero dispara poco.** Solo 2 de 22 series obtienen punto de declive: Los Simpson tras la T10 y The Boys tras la T3, ambas correctas. Game of Thrones sale como "montaña rusa" porque su hundimiento se concentra en una sola temporada y `minimumSeasonsAfterDecline = 2` exige dos posteriores.

Propuesta medida sobre los datos del archivo (ponderando por `reliableEpisodeCount` en vez de por votos, así que es direccional):

- Bajar `minimumDeclineDrop` de 0,5 a ~0,35-0,40 **conservando** `minimumSeasonsAfterDecline = 2`. Añade The Walking Dead (T6), The Office (T7) y Supernatural (T13) — las tres consenso, ningún falso positivo.
- Añadir un segundo escalón para desplomes catastróficos de una sola temporada: caída ≥1,5 con ≥1 temporada posterior. A 1,5 solo califican Game of Thrones (−2,20) y The Boys (−1,57).

**Criterio de aceptación: cero falsos positivos**, no "más aciertos". Un declive equivocado es una afirmación falsa, y toda la propuesta de esta app es que sus afirmaciones abren su evidencia.

**El suelo de votos expulsa series enteras.** NCIS y Pretty Little Liars quedaron fuera: solo el 19,1 % y el 38,5 % de sus episodios emitidos superan los 10 votos, contra un `minimumReliableShare` del 60 %.

Dos cambios que medir, ambos en el motor:

1. Bajar `minimumVotesPerEpisode` de 10 a 5 y publicar la tasa de descarte antes y después sobre la semilla escalada.
2. Aplicar el test de cobertura **por temporada** en vez de globalmente, analizando solo las temporadas que lo pasan y reteniendo los veredictos de serie cuando las temporadas cubiertas no son contiguas. Eso mantiene intacto "nunca un veredicto sobre datos insuficientes" y a la vez conserva el título en el estante con su gráfico y una nota de cobertura — que es literalmente lo que el spec §5 prescribe ("la ficha muestra únicamente el gráfico, sin veredictos"), mientras que el generador hoy **borra el título entero**.

Para una app rechazada por falta de contenido, borrar títulos para no exagerar es el intercambio equivocado cuando el modelo ya sabe declarar su propia cobertura.

**Efecto de segundo orden:** al escalar de 24 a 150-200, los descartes se multiplicarán, y eso choca con el suelo del 50 % de la guarda de outage, que calcula sobre `entries.count`. Una ejecución normal podría cruzarlo y reportar una caída de servicio que no existe. La información para distinguirlo ya está en `skipped[].kind`.

## 4. Un `200` vacío de Wikidata todavía pasa

La guarda captura errores lanzados; no captura una respuesta correcta con cero filas. `entries` tiene suelo del 50 %; `awardsById` no tiene ninguno. Un `awardsById.count == 0` imprimiría "0 series carry at least one award" y escribiría tan tranquilo.

## 5. Las dos guardas de "no escribir" no están bajo test

Ambas llaman a `exit()`, así que no pueden ejecutarse en proceso. Extraer la decisión a una función pura (`shouldWrite(entryCount:seedCount:) -> Bool`) haría testeable justo el comportamiento que más importa, en vez de depender de que un HTTP 429 apareciera por suerte durante una regeneración.

## 6. `PlotlineDataset.version` no se subió pese a cambiar de forma

El comentario del campo dice que se sube cuando cambia la forma. La forma cambió de manera incompatible y siguió en 1.

Hoy es inocuo: el JSON viaja dentro del binario, así que un archivo viejo nunca se encuentra con un contrato nuevo, y se regeneró en el mismo commit. **Empieza a importar en cuanto la Fase 4 introduzca una copia cacheada o descargada.** Decidirlo entonces, deliberadamente.

## 7. Un renombrado del lado de la app rompe el generador en silencio *(mitigado)*

SwiftPM **descarta sin avisar** un symlink colgante, y el build de la app sigue en verde, así que la rotura no aparecería hasta que alguien ejecutara el generador meses después.

Mitigado: `Package.swift` comprueba los cuatro enlaces y hace `fatalError` nombrando el que falla. Verificado rompiendo un enlace a propósito. Queda anotado porque es el mismo tipo de fallo mudo por el que se descartó `path:`/`sources:`.

---

## Fuera de esta fase, pero antes de reenviar a App Store

**`CLAUDE.md` y `README.md` se copian dentro del bundle de la app.** Documentan la arquitectura interna y la estrategia de APIs, y se distribuyen a los usuarios. Es preexistente, no de esta rama, y conviene quitarlo antes de la reenvío.
