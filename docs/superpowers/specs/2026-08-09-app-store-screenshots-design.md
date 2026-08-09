# Capturas de App Store — rehacer el set entero, iPhone e iPad

**Fecha:** 2026-08-09
**Estado:** diseño validado, sin implementar.
**Origen:** §9 y §12 del spec 4.2 (`2026-08-01-app-store-4.2-design.md`) — el pase de capturas de iPad
que la Fase 6 aplazó «hasta que el layout esté aprobado», y las capturas que §12 exige que muestren
el análisis y no pósters. El layout de iPad se aprobó en la Task 4 de la Fase 6; el aplazamiento ya no
tiene motivo.

---

## 1. Por qué se rehacen, y no se retocan

Las capturas que hay hoy en `screenshots/framed/` **venden una app que ya no existe**, y venden la
lectura que provocó tres rechazos.

Tres de ellas anuncian funciones retiradas: «Multi-Source Ratings» con insignias de IMDb 6.2 y
Metacritic 59/100 —OMDb salió en la Fase 1— y «Awards data», que sigue en el código pero no se dibuja:
`MediaDetailView.swift:346` lo dice literalmente. Enseñar en la ficha una función que la app no tiene
no es solo desactualización, es un desajuste entre metadatos y binario.

Y ninguna de las ocho enseña el análisis. El titular de cada una repite el nombre de la pestaña
—«Save Your Favorites», «Track Your Watchlist», «Browse by Genre»—, que es exactamente el retrato de
visor de catálogo ajeno. La descripción reescrita para 1.4.0 gira entera alrededor del análisis
derivado; el set de capturas la contradice.

`koubou.yaml` tampoco puede construir el diseño nuevo: sabe colocar **una** imagen y texto por lienzo,
y no sabe hacer escenas compartidas entre capturas.

## 2. Qué se entrega

16 PNG en `screenshots/<MARKETING_VERSION>/`:

| Familia | Tamaño | Orientación | Nº |
|---|---|---|---|
| iPhone 6.9" | 1320×2868 | vertical | 8 |
| iPad 13" | 2752×2064 | apaisado | 8 |

1320×2868 es el tamaño nativo del iPhone 17 Pro Max y 2064×2752 el del iPad Pro 13" (M5), los dos
comprobados con `simctl io screenshot`. Capturar y componer en el tamaño nativo evita cualquier
reescalado entre la captura y el fichero que se sube.

## 3. El sistema visual

Decidido sobre maquetas HTML+CSS renderizadas con capturas reales, no descrito sobre el papel.

- **Lienzo:** degradado lineal a 175°, `#0E0E12 → #17110B`. Idéntico en las 16.
- **La curva:** una única trayectoria determinista de valoraciones por episodio recorre las ocho
  capturas de una familia; cada captura enseña su ventana mediante el `viewBox` de un SVG sobre el
  mismo `path`. Trazo `#E8A33D`, relleno degradado del 13% al 0%. No es adorno: es el motivo que hace
  que el set no se pueda confundir con el de un catálogo.
- **Escenas compartidas:** dos composiciones de dispositivos ladeados que sangran por los bordes.
  La primera abarca las capturas **1·2·3**, la segunda las **6·7·8**. La 4 y la 5 llevan un solo
  dispositivo, como respiro.
  La panorámica está en 1·2·3 y no en otro sitio porque los resultados de búsqueda de la App Store
  enseñan las tres primeras capturas juntas: ahí la escena se ve entera.
- **Capturas de la app en modo oscuro**, sobre lienzo oscuro.
- **Titular:** `system-ui` (SF) peso 800, tracking −0.025em, interlineado 1.04, blanco, con una palabra
  en `#E8A33D`.
- **Pastilla de evidencia:** `ui-monospace`, sobre `rgba(12,12,14,.6)` con borde `rgba(232,163,61,.42)`,
  radio completo.
- **Biseles:** `#2A2A2E`, radio 9%/4.1% en iPhone y 3.4%/2.6% en iPad.
- **iPad:** el titular va en **banda superior** a todo el ancho, con los dispositivos entrando por
  debajo. En un lienzo 4:3 la columna lateral y el texto superpuesto se probaron y se descartaron:
  la columna parte el titular en demasiadas líneas y el superpuesto depende de que debajo haya zona
  oscura, lo que deja de ser cierto en cuanto una captura tenga un póster claro justo ahí.

## 4. Las ocho capturas

| # | Pantalla | Titular | Pastilla |
|---|---|---|---|
| 1 | Ficha · `PlotlineScoreCard` | A 0–100 score, and the arithmetic behind it | `LEVEL · CONSISTENCY · TRAJECTORY` |
| 2 | Ficha · `SeriesVerdictsView` («What the Numbers Say») | It tells you where a series falls off | medias antes y después de la caída |
| 3 | `SeriesGraphView`, gráfico por temporada | Every episode, every season, plotted | — |
| 4 | `EpisodeRatingsGridView` | Every rated episode, at a glance | — |
| 5 | Discover · estantes derivados | Shelves you won't find anywhere else | `122 SERIES · SHIPPED INSIDE THE APP` |
| 6 | `WatchProvidersSection` con el crédito a JustWatch | Where to watch it, in your region | — |
| 7 | `CompareView` | Any two titles, side by side | — |
| 8 | `TrendsView` | Genres and decades, charted | — |

La pastilla de la nº 5 dice lo que esa pantalla demuestra y nada más: los estantes que se ven salen del
dataset empaquetado, y son 122 entradas comprobadas en `PlotlineDataset.json`. No dice «offline»,
porque la captura se toma con red y esa imagen no lo demuestra; el argumento de que funciona sin red
vive en la descripción, que sí puede sostenerlo.

**Regla de copy, heredada de la app:** ninguna frase puede afirmar más de lo que la captura que tiene
debajo demuestra. Es la misma regla que ha obligado a reescribir seis textos dentro del producto.
El punto de decline demuestra una caída relativa que no se recupera; no demuestra que la serie fuera
buena antes, y el titular no puede insinuarlo.

**Los números de las pastillas se transcriben de la captura, no del dataset.** La app recalcula en vivo
cuando llegan episodios más frescos, así que el valor de la pantalla y el del JSON empaquetado pueden
diferir. Escribir la pastilla desde `PlotlineDataset.json` produciría un número que la imagen de al lado
contradice. Se lee de la captura ya tomada y se verifica mirándola.

**Deriva registrada.** Este set se diseñó sobre capturas del 7 de agosto y el 9 ya había cambiado dos
cosas. `StandoutEpisodesView` se retiró: la sección de análisis es hoy `PlotlineScoreCard` +
`SeriesVerdictsView`, y la captura nº 4 pasó de «Standout Episodes» a la rejilla de episodios.
Y la rejilla de géneros pasó a aparecer al abrir la búsqueda en vez de como tarjeta sobre el feed,
así que la captura nº 5 cambia de aspecto. **Todas las capturas crudas se vuelven a tomar en
implementación; ninguna de las tomadas durante el diseño se reutiliza.**

## 5. La captura

`PlotlineUITests/ScreenshotCaptureTests.swift`. Navega por `AccessibilityAnchors`, que existen
precisamente para esto, y no por coordenadas.

- **Se excluye de la ejecución normal.** Cada método llama a `XCTSkipUnless` sobre
  `PLOTLINE_SCREENSHOT_CAPTURE=1`, que el script anfitrión pasa como
  `TEST_RUNNER_PLOTLINE_SCREENSHOT_CAPTURE=1` — `xcodebuild` solo reenvía al runner del simulador las
  variables con ese prefijo, que es el mismo mecanismo que ya usa `PLOTLINE_UITEST_MODE`. Sin ella el
  suite se salta entero, para que `xcodebuild test` no lo arrastre en cada pasada ni lo haga fallar la
  falta de clave de TMDB. `ColdStartUITests` corre hambriento a propósito; éste necesita red.
- **La orientación de iPad la fija `XCUIDevice.shared.orientation = .landscapeLeft`.** Durante el
  diseño se intentó rotar el simulador por automatización de menús —atajo de teclado, Device › Rotate
  Right y Device › Orientation › Landscape Left— y las tres veces el menú respondió y el framebuffer
  se quedó en vertical; la última falló con error de accesibilidad −25204. La orientación desde dentro
  del test es la única vía que no depende de eso.
- **El script anfitrión fija antes de lanzar:**
  - `xcrun simctl status_bar <device> override --time 9:41 --batteryState charged --batteryLevel 100 --wifiBars 3 --cellularBars 4`
  - la configuración regional en inglés, vía argumentos de lanzamiento. La captura de iPad tomada
    durante el diseño lleva «Viernes 7 de agosto» en la barra de estado sobre una app en inglés:
    ese es el defecto exacto que esto evita.
  - `xcrun simctl ui <device> appearance dark`
- **Los PNG salen por `XCTAttachment`** con `lifetime = .keepAlways`, y el script los extrae del
  `.xcresult` con `xcrun xcresulttool`. La disponibilidad exacta del subcomando de extracción se
  verifica en el primer paso de la implementación; si no está, la alternativa es escribir desde el
  test al contenedor del runner y sacarlo con `simctl get_app_container`.

Salida: `screenshots/raw/iphone-69/01..08.png` y `screenshots/raw/ipad-13/01..08.png`.

## 6. La composición

**HTML estático, sin generador ni plantillas.** `Scripts/screenshots/iphone.html` referencia
`../../screenshots/raw/iphone-69/01.png` … `08.png` por nombre fijo. No hay paso de generación de HTML
porque no hace falta: los nombres son estables y el manifiesto es el propio documento.

**Un lienzo panorámico, renderizado de una vez, y luego cortado.** La continuidad de la escena y de la
curva pasa a ser física en vez de calculada: no puede desalinearse porque nunca estuvo separada.

```
iphone.html   →  10560×2868   (8 × 1320)   → corte ×8
ipad.html     →  22016×2064   (8 × 2752)   → corte ×8
```

**Una hoja por familia, medido y no supuesto.** El diseño llegó a especificar el iPad partido en dos
hojas de cuatro, por miedo a que 8 × 2752 = 22016 px superara el límite de textura de 16384 que tienen
muchas GPU. Se probó: Chrome headless con `--disable-gpu` renderiza 22016×2064 completo, y el octavo
frame sale entero, comprobado recortándolo y mirándolo. También se comprobó 10560×2868 para iPhone.
La suposición era falsa y el spec la llevaba escrita como hecho.

La partición se queda documentada como **respaldo**, no como diseño: si en otra máquina una hoja
volviera corta o en blanco, se parte en dos de cuatro capturas, y la frontera cae entre la 4 y la 5,
que es justo donde no hay escena compartida — la composición elegida hace que la partición salga
gratis. La curva sí cruza esa frontera y sigue cuadrando, porque cada hoja windowea el mismo `path`
global con su desplazamiento en vez de recalcularlo.

Render con Chrome headless: `--headless --screenshot --window-size=W,H
--force-device-scale-factor=1 --hide-scrollbars --default-background-color=0`.

**El corte lo hace `Scripts/screenshots/slice.swift`**, ejecutado con `swift`, recortando con
CoreGraphics. No se usa `sips` porque no sabe recortar con desplazamiento, y no se añade ImageMagick
porque meter una dependencia de Homebrew en un repo Swift para cortar un PNG no compensa.

Todo lo orquesta `Scripts/screenshots/make.sh`, con las dos familias como argumento opcional.

## 7. Verificación

- **Dimensiones exactas** de cada PNG de salida, comprobadas con `sips -g pixelWidth -g pixelHeight`.
  El script falla si una sola no cuadra.
- **Recuento:** 8 por familia. Falla si falta o sobra.
- **Las fuentes cargaron.** Un render sin SF cae a una tipografía sustituta y el resultado sigue
  pareciendo válido a simple vista. Se comprueba midiendo el ancho renderizado de una cadena patrón
  contra un valor esperado, con tolerancia; si la fuente no es la que se pidió, falla.
- **Mirarlas.** Las tres últimas fases tuvieron su único fallo grave en una costura que ningún test
  miraba, y dos de las tres veces la verificación visual existía y miraba el sitio equivocado.
- **Opcional, y marcado como tal:** un paso en `release-preflight.sh` que falle si
  `screenshots/<MARKETING_VERSION>/` no tiene los 16 PNG a su tamaño. Encaja con el paso 5, que ya
  comprueba la coherencia entre `MARKETING_VERSION` y `docs/app-review/`.

## 8. Qué se borra

- `.asc/screenshots.json` — el plan de toques por coordenadas fijas sobre 402×874. Se rompe con
  cualquier cambio de layout, es solo para iPhone, y necesita un runner externo que no está en el repo.
- `screenshots/koubou.yaml` y `screenshots/framed/` — el pipeline que no puede construir este diseño.
- Los ocho PNG sueltos que hoy cuelgan de `screenshots/raw/` (`01_discover_home.png` …
  `08_stats.png`) — capturas de la app con OMDb dentro. La carpeta se queda: el pipeline nuevo escribe
  en `screenshots/raw/iphone-69/` y `screenshots/raw/ipad-13/`, un subdirectorio por familia.
- Los PNG sueltos de `screenshots/` (`discover.png`, `detail.png`, `favorites.png`, `genres.png`,
  `watchlist.png`, `detail-scroll.png`) y `screenshots/1.4.0/`, que son las dos capturas manuales
  irreproducibles del envío anterior.

Se borran en el mismo commit que introduce el reemplazo, no antes.

## 9. Riesgos y puntos abiertos

- **La licencia de SF.** El acuerdo de Apple permite usar las fuentes del sistema para maquetas de
  interfaz; usarlas como tipografía de titular de marketing es zona gris. Se elige SF por coherencia
  con la app, y queda anotado como riesgo asumido, no como resuelto. La alternativa es Inter, de
  licencia inequívoca y métricamente parecida.
- **Los pósters de TMDB aparecen dentro de las capturas.** La atribución a TMDB va en la descripción de
  la App Store y dentro de la app; la de JustWatch va dentro de la captura nº 6, que es donde los datos
  de proveedores se muestran. No se recorta ni se tapa.
- **La captura nº 8 es la más débil de las ocho.** «Genres and decades, charted» cierra el set con
  material que no es análisis de series. La alternativa que preferiría —la ruta `insufficientData`,
  «when it can't back a verdict, it says so», que es lo más distintivo que hace esta app y está en la
  descripción— no se puede capturar de forma determinista: **ninguna de las 122 series del dataset la
  dispara**, comprobado, así que exigiría una serie fina traída en vivo y dependería de qué devuelva
  TMDB ese día. Queda anotada como mejora si alguna vez se le da una entrada estable.
- **El ancho de render de Chrome ya no es un riesgo abierto: se midió.** 10560×2868 y 22016×2064
  renderizan completos con `--disable-gpu`, y el `slice.swift` de CoreGraphics devuelve ocho recortes
  del tamaño exacto en los dos casos. Lo que queda es que la medición es de **una** máquina; por eso
  el respaldo de la partición se documenta en §6 en vez de borrarse.
- **`--default-background-color=0` no vale**, aunque aparezca así en muchos ejemplos: Chrome exige un
  valor hexadecimal RGB o RGBA y aborta el render con `Expected a hex RGB or RGBA value`. El lienzo ya
  pinta su propio fondo, así que la bandera sobra y no se usa.

## 10. Lo que esto no hace

- **No sube nada a App Store Connect.** Sigue siendo manual y a propósito: §12 del spec 4.2 y el
  paso 8/8 del preflight lo enumeran en orden.
- **No juzga si una captura afirma de más.** El script comprueba tamaños, cantidad y fuente. Que un
  titular no prometa lo que la pantalla no enseña lo decide un humano mirándolo.
- **No toca la app.** Ni una línea de `Plotline/`, más allá de leer los identificadores de
  accesibilidad que ya existen. Si alguna pantalla resultara inalcanzable por identificador, se añade
  el ancla que falte y se anota; no se navega por coordenadas.
- **No cubre el 6.5".** App Store Connect deriva los tamaños menores del set de 6.9". Si en algún
  momento hiciera falta un set propio, es otra ejecución del mismo script con otro destino.
