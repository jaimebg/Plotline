# Residuos de la Fase 6 — iPad nativo

**Fecha:** 2026-08-04
**Estado:** fase completa. `TEST SUCCEEDED`, 0 fallos. Compila para iPhone e iPad; verificada en pantalla en iPad Air 11", iPhone 17 (402 pt) e iPhone 17e (390 pt).
**Origen:** revisión de rama completa más verificación visual del controlador.

---

## Lo que esta fase cierra

Plotline **era una app de iPhone**. `TARGETED_DEVICE_FAMILY` valía `1`, así que App Review la ejecutó en modo compatibilidad sobre un iPad Air 11": una ventana de tamaño teléfono en una pantalla grande, donde cualquier app parece escasa. Todo lo construido en las Fases 4 y 5 le llegó encogido al revisor.

Ahora es una app de iPad: las rejillas eligen sus columnas por el ancho disponible, la ficha acota su columna de lectura, y la navegación adopta la barra lateral. También cierra el residuo nº 4 de la Fase 4 —`ScrollView` anidados del mismo eje en Stats— que llevaba abierto desde entonces.

---

## 1. Un fallo de iPhone escondido entre dos niveles de padding

**Severidad: era crítico. Arreglado en `5e48617`.**

`TrendsView` solo se renderiza dentro de `StatsView`, que ya aporta el `ScrollView`, el `.padding()`, el fondo y el título de navegación. Llevaba su propia copia de los cuatro. Con el padding acumulado a 64 pt, su rejilla disponía de 64 pt menos que la pantalla, y al pasar de dos columnas fijas a columnas por ancho eso la dejaba **en una sola columna en todo iPhone por debajo de 402 pt** — es decir, en el 15, el 16, el SE y los mini.

Lo que hace este caso instructivo es **por qué sobrevivió a todo**:

- Los tests calculaban con 32 pt de padding, el de un solo nivel. La aritmética era correcta para cinco de los seis sitios.
- El iPhone 17, dispositivo de build, mide 402 pt y **libraba por 6 pt**.
- Mi verificación visual se hizo en ese mismo iPhone 17.

Tres comprobaciones independientes y las tres miraban justo por encima del umbral. Lo encontró la revisión de rama completa, haciendo la aritmética **sitio por sitio** en vez de confiar en el número compartido. Es la segunda fase seguida cuyo único fallo grave vive en una costura que ninguna tarea tocó.

De regalo, el `.navigationTitle("Trend Explorer")` de esa vista embebida estaba pisando el título "Stats" de su propia pestaña.

## 2. Tres constantes que codificaban una sola regla

Arreglado en `d6b57e2`. El plan definía `posterMinimumWidth`, `bannerMinimumWidth` y `cardMinimumWidth` como si fueran tres decisiones. Al hacer los números, las tres estaban atadas al mismo techo —dos columnas en el iPhone más estrecho que soporta iOS 26— y por debajo de él producían **layouts idénticos** en todos los anchos probados: 375, 402, 820 y 1024 pt. Tres nombres que siempre se comportan igual son precisión falsa.

Quedaron en una sola, `minimumColumnWidth = 160`, con la regla real documentada donde vive.

Antes de eso, mi valor original de 220 habría dejado la rejilla de géneros **a una columna en iPhone**, y el 175 que lo sustituyó fallaba igual a 375 pt. Hicieron falta tres pasadas para acertar un número.

---

## Lo que queda abierto

### 3. Con Display Zoom activado, las rejillas caen a una columna

**Aceptado a sabiendas, no arreglado.**

Display Zoom renderiza el iPhone SE 3 a 320 pt y el 15/16 a 320 pt. A ese ancho, con 32 pt de padding, `minimumColumnWidth = 160` da una sola columna. Antes de esta fase eran siempre dos, porque estaban fijas.

Se acepta porque Display Zoom es un ajuste de accesibilidad: quien lo activa pide contenido más grande, y una columna a 320 pt cumple esa petición mejor que dos de 140 pt. Pero conviene tenerlo escrito: **es un cambio de comportamiento**, no una consecuencia neutra, y `AdaptiveLayoutTests.narrowSplitFallsBackToOneColumn` lo fija como requisito, así que bajar la constante en el futuro exige revisar ese test primero.

### 4. La barra lateral esconde Settings tras un chevron

Con `.tabViewStyle(.sidebarAdaptable)`, el iPad muestra cuatro secciones y un chevron; antes se veían las cinco. Settings pasa de un toque a dos.

Es el patrón adaptativo estándar de iPadOS y todas las secciones siguen siendo alcanzables, pero es un intercambio y no una mejora limpia. Si en algún momento pesa más el acceso directo que el aspecto nativo, se revierte con una línea.

### 5. El estante de recomendaciones queda acotado en la ficha

`.readableWidth()` envuelve toda la columna de contenido de la ficha, así que "You Might Also Like" queda limitado a unos 636 pt en iPad, mientras que los estantes de Discover usan el ancho completo. El plan decía que los estantes horizontales debían conservar el ancho total y su propia instrucción decía envolver el `VStack` entero: se contradecía a sí mismo, y el código siguió la instrucción.

En pantalla se ve bien —un estante centrado bajo una columna centrada es más coherente que uno a sangre bajo un texto estrecho—, así que se deja. Queda anotado porque es una desviación del plan, no un descuido.

### 6. Lo que §9 pedía y esta fase no hizo

- **`NavigationSplitView` en Favorites, Watchlist y Detail.** Es una reestructuración grande de navegación con riesgo real para el iPhone, y las rejillas adaptables más el ancho de lectura ya resuelven la impresión de app estirada. Se reevalúa con el resultado delante.
- **Capturas de iPad para App Store Connect.** Van cuando el layout esté aprobado.
- **Alturas de gráfico por size class.** Los 200 y 300 pt fijos de `Stats/` se ven aceptables en iPad; no hay evidencia de que molesten.

---

## Para la fase siguiente

Queda el "dónde verlo" del spec §7, con sus dos correcciones ya registradas: TMDB no devuelve deep links por plataforma, y la atribución a JustWatch se exige en cada ficha bajo pena de revocar el acceso a la API.

Y una guarda de proceso que esta fase confirma por segunda vez consecutiva: **cuando una constante compartida cambia el layout, hay que hacer la aritmética en cada punto de uso, no una vez.** Un solo número correcto en cinco sitios y equivocado en el sexto pasa los tests, pasa el build y pasa una revisión visual si el dispositivo de prueba está del lado bueno del umbral.
