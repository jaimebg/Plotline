# Automatización de App Store — Fastlane, ASO y releases

**Fecha:** 2026-08-10
**Estado:** diseño validado, sin implementar.
**Origen:** petición directa — automatizar el envío a TestFlight y a producción, y llevar el
texto de la ficha (ASO) a archivos con presupuesto comprobado en vez de a copiar y pegar.

Este spec **revierte una decisión documentada**. `docs/app-review/README.md` decía: «No hay
automatización, y no debería haberla: cada texto conviene releerlo antes de enviarlo», y el paso
9/9 de `Scripts/release-preflight.sh` lo repetía. Esa postura se tomó en mitad de tres rechazos
4.2 seguidos. Se retira a propósito, no por descuido, y este documento la sustituye.

---

## 1. Decisiones tomadas

Todas son elección explícita del autor, no de este documento:

| Decisión | Elegido | Alternativa descartada |
|---|---|---|
| Alcance | Todo automatizado: build, TestFlight, metadatos, capturas, envío a revisión | Solo build + TestFlight |
| Publicación tras aprobación | **Automática** (`automatic_release: true`) | Manual, o por fases |
| Dónde corre | **Solo Mac local** | GitHub Actions |
| ASO | Metadatos como archivos + linter de presupuesto | Localizar la ficha; localizar la app; landing web |
| Capturas | Subir las que ya produce `Scripts/screenshots/make.sh` | `snapshot` / `frameit` de Fastlane |
| `fastlane/` en git | **Todo ignorado**, solo local | Versionar los `.txt` de la ficha |
| Fuente de verdad del texto | `fastlane/metadata/` (sin versionar) | Markdown versionado + generador |
| Orden con el Resolution Center | **Solo aviso impreso**, sin barrera | Confirmación interactiva, marcador en git, variable de entorno |

Dos de estas tienen coste conocido y aceptado; están en §10.

## 2. Estado de partida

- La app **no tiene Fastlane, ni CI, ni Gemfile**. Nada automatizado más allá del build local.
- `Scripts/release-preflight.sh` ya reúne nueve comprobaciones previas a una release, pero
  **avisa sin bloquear**: su propia cabecera explica que una pre-action de Archive que
  devuelve error no aborta el archive de forma fiable en Xcode reciente.
- 1.4.0 build 7 **está sin enviar**, con el hilo del Resolution Center abierto. El primer uso
  real de este pipeline es ese reenvío.
- La app es solo inglés (`knownRegions = en, Base`). El repo es **público**.

## 3. Layout en disco

```
Gemfile                      # versionado — fastlane
Gemfile.lock                 # versionado — la combinación que funciona
.ruby-version                # versionado
Scripts/aso-lint.swift       # versionado — presupuestos y desperdicio de keywords
Scripts/tests/aso-lint-tests.sh
Scripts/tests/fixtures/aso/  # versionado — metadatos de mentira, a propósito malos

fastlane/                    # ← CARPETA ENTERA IGNORADA POR GIT
  Appfile                    # bundle id y team
  Fastfile                   # bootstrap, aso, beta, release, metadata, screenshots, release_dry_run
  Deliverfile
  .env                       # key id, issuer id, ruta al .p8
  .keys/AuthKey_*.p8
  metadata/
    en-US/{name,subtitle,description,keywords,promotional_text,release_notes,
           support_url,marketing_url,privacy_url}.txt
    review_information/{notes,first_name,last_name,phone_number,email_address}.txt
    copyright.txt
```

Las capturas **no se copian** a `fastlane/screenshots/`. `Deliverfile` apunta
`screenshots_path` al árbol que ya existe, `screenshots/<version>/`, para que `make.sh` siga
siendo lo único que las escribe y no haya una segunda copia que pueda desincronizarse.

### Por qué `fastlane/` va entero fuera de git

El `.p8` y el `.env` son credenciales: obvio. Pero `metadata/review_information/` guarda
teléfono, email y credenciales de cuenta de prueba — datos personales que hoy no están en el
repo público y que no deberían acabar en él por efecto colateral de esta automatización.

Se acepta el coste (§10): el texto de la ficha deja de tener historial en git.

### El identificador de emisor no va en ningún archivo versionado

Ni el issuer id ni el key id aparecen en este spec, en `CLAUDE.md`, ni en ningún archivo
seguido por git. Viven solo en `fastlane/.env`. El paso 9 del preflight (§6) falla justamente
si ese UUID aparece en un archivo versionado, así que escribirlo aquí rompería la comprobación
que este mismo documento define.

## 4. Autenticación y firma

**Clave de App Store Connect (`.p8`)**, no Apple ID con contraseña de aplicación: es lo único
que sobrevive al 2FA sin intervención, y es lo que esperan `deliver` y `pilot`. La clave ya
existe y está generada; se mueve de `~/Downloads` a `fastlane/.keys/`, porque una credencial
capaz de subir builds a la cuenta no debería quedarse en la carpeta de descargas.

**Sin `match`.** Con un solo Mac, el llavero y los perfiles que gestiona Xcode ya funcionan;
`match` añadiría un segundo repo privado y una rotación de certificados para resolver un
problema que aquí no existe.

**El team estaba en conflicto y se cierra.** `project.pbxproj` declara
`DEVELOPMENT_TEAM = 8BXWAL9PV5` a nivel de proyecto (línea 320) y `95PGC3PATF` en el target de
la app (línea 409). El llavero tiene un único certificado de distribución,
`Apple Distribution: Jaime Barreto (95PGC3PATF)`, así que el override del target es el correcto
y el valor de proyecto es residuo. Se igualan los dos para que no puedan volver a discrepar.

## 5. Los lanes

| Lane | Qué hace |
|---|---|
| `bootstrap` | `deliver download_metadata` + `download_screenshots`. Trae lo que ya hay vivo en App Store Connect. |
| `aso` | Solo linter. Sin red, sin build, sin firma. |
| `beta` | Preflight (modo beta) → número de build → `gym` → `pilot`. |
| `release` | Preflight completo → `precheck` → `gym` → `deliver` con envío a revisión y publicación automática → tag. |
| `metadata` | Solo textos, `skip_binary_upload`. Para corregir una errata sin build. |
| `screenshots` | `make.sh` y luego subir solo imágenes. |
| `release_dry_run` | Todo lo de `release` menos subir y enviar. |

**`bootstrap` existe porque el primer `deliver` es el peligroso.** `deliver` empuja el árbol de
metadatos como autoritativo; contra una ficha viva con un árbol incompleto puede vaciar campos
que nadie escribió — `support_url`, `privacy_url`, `copyright`, categorías. Esos campos ya están
rellenos en App Store Connect. `bootstrap` los descarga primero y el texto redactado se aplica
encima, en vez de partir de un árbol en blanco.

**El número de build sale de App Store Connect**, `latest_testflight_build_number + 1`, no del
repo: así no puede chocar con algo subido desde otro sitio.

## 6. El preflight pasa de 9 pasos a 12, y empieza a bloquear

El cambio de más valor de todo este diseño cuesta una línea: **un `sh()` que devuelve distinto
de cero aborta el lane**. Nueve comprobaciones que hoy solo avisan pasan a impedir la release.
Es exactamente lo que la cabecera del script dice que no puede hacer como pre-action.

Necesita una opción `--for=beta|release`: el paso 8 exige las dieciséis capturas de la versión
actual, y un build de TestFlight de una versión en curso legítimamente aún no las tiene.

Pasos 1–8: sin cambios. Tres nuevos, y la lista manual reescrita:

- **9 — Ninguna credencial de App Store Connect filtrada.** Falla si git sigue un `.p8`, un
  `fastlane/.env`, o si el UUID de emisor aparece en un archivo versionado. Mismo espíritu que
  el paso 7 (escaneo de esquemas), apuntado a la credencial nueva que ahora vive al lado de un
  repo público.
- **10 — Presupuestos ASO y desperdicio de keywords.** Pasarse del límite **falla**; el
  desperdicio **avisa**.
- **11 — El texto de la ficha concuerda con el dataset.** El «122 series» y los cinco nombres
  de estantería, contra `PlotlineDataset.json`. Es la misma comprobación que `render.sh` ya hace
  para su pastilla de marketing, extendida al texto de la tienda: una regeneración del dataset
  que cambie la cuenta no puede dejar en silencio un número falso en la ficha.
- **12 — Lo que sigue siendo manual.** Era el 9. Casi toda su lista pasa a estar automatizada.

### Los pasos 10 y 11 fallan, no se saltan

`fastlane/metadata/` no está en git, así que en un clon limpio no existe. Saltar el paso en
silencio sería exactamente el fail-open que cerró el commit `f90d8fe`. Como las releases son
solo locales, que falte ese árbol **en la máquina que publica** significa que la release no
puede seguir: los pasos fallan con un mensaje accionable, «ejecuta `bundle exec fastlane
bootstrap`».

Las fixtures del linter sí están versionadas, así que `aso-lint` se puede probar en cualquier
clon aunque no haya metadatos reales.

### El paso 5 no cambia, y conviene decir qué no demuestra

Sigue haciendo `grep -rq "$version" docs/app-review/`, y el runbook reescrito mantiene la
versión en su encabezado, así que sigue funcionando. Lo que **no** establece es que
`release_notes.txt` describa de verdad esta versión. Nada mecánico puede establecerlo. Se queda
como lectura humana, y este spec lo dice en vez de aparentar una cobertura que no tiene.

## 7. El linter ASO

Comprueba dos cosas distintas, con dos severidades distintas:

- **Presupuestos** — nombre ≤30, subtítulo ≤30, keywords ≤100, promocional ≤170, descripción
  ≤4000, novedades ≤4000. Pasarse es un hecho: **falla**.
- **Desperdicio** — un término comprado dos veces entre nombre, subtítulo y keywords; espacios
  rellenando el campo de keywords; un plural junto a su singular. Es un juicio: **avisa**.

Sobre el estado actual ya tiene un hallazgo real. El campo de keywords está a **95/100**, con
solo 5 caracteres libres, y `seasons` aparece a la vez en el subtítulo y en las keywords.
Apple indexa nombre y subtítulo junto con el campo de keywords, así que ese término está pagado
dos veces: quitarlo devuelve 8 caracteres y sube el margen de 5 a 13. Es la clase de error que
una revisión a ojo no ve y una comprobación mecánica sí.

## 8. Qué cambia en los archivos existentes

| Archivo | Cambio |
|---|---|
| `Scripts/release-preflight.sh` | Opción `--for`, tres pasos nuevos, renumerado a 12, paso manual reescrito |
| `docs/app-review/app-store-description.md` | Los bloques pegables se van a `fastlane/metadata/`. **Se queda el razonamiento**: la nota de §12 sobre encabezar con el análisis y no con el catálogo, y la nota de atribuciones que marca que el logo de TMDB sigue sin cumplirse |
| `docs/app-review/app-review-notes.md` | Igual: el bloque a `review_information/notes.txt`, el razonamiento se queda |
| `docs/app-review/README.md` | Pasa a ser el runbook de release: los lanes, el orden, y **cómo reconstruir `fastlane/` desde cero** |
| `docs/app-review/resolution-center-reply.md` | Sin cambios. Sigue siendo enteramente manual |
| `.gitignore` | `fastlane/` entero, más `Gemfile.lock` explícitamente **no** ignorado |
| `project.pbxproj` | `DEVELOPMENT_TEAM` de proyecto igualado a `95PGC3PATF` |
| `CLAUDE.md` | Sección nueva con los lanes; «Before a Release» actualizado — hoy describe 9 pasos y dice que App Store Connect no está automatizado |

Los textos se mueven; el razonamiento que los mantiene honestos no se tira con ellos.

**El `Fastfile` no está en git, así que la receta sí.** `docs/app-review/README.md` documenta
los lanes y cómo rehacer `fastlane/` en una máquina nueva. Sin secretos, solo el procedimiento:
si el Mac muere, el pipeline es reconstruible.

## 9. Cómo se verifica el propio pipeline

Un pipeline que solo se puede probar publicando no es comprobable:

- **`Scripts/tests/aso-lint-tests.sh`**, siguiendo el patrón de
  `Scripts/screenshots/tests/run-tests.sh` — fixtures con un subtítulo de 34 caracteres, una
  keyword duplicada del subtítulo y un campo relleno de espacios, comprobando que el linter
  **efectivamente** falla o avisa. Un linter que aprueba todo es peor que ninguno.
- **`precheck`** y `deliver --verify_only` validan los metadatos contra Apple sin subir nada.
- **`release_dry_run`** hace preflight, `gym` y verificación de `deliver`, sin subir ni enviar.
  Es como se prueba el pipeline **antes** de apuntarlo al reenvío de 1.4.0.

### Un detalle de `deliver` que parece un fallo y no lo es

Las dos medidas están soportadas, pero bajo nombres heredados
(`deliver/lib/deliver/app_screenshot.rb`):

- `1320×2868` → `APP_IPHONE_67` (línea 58) — Apple metió la ranura de 6,9" en la vieja de 6,7"
- `2752×2064` → `APP_IPAD_PRO_3GEN_129` (línea 137) — igual, la de 13" dentro de la de 12,9"

`deliver` lee el árbol de capturas actual tal cual. Imprimirá «iPhone 14 Pro Max», y eso es
correcto.

## 10. Riesgos, y las dos decisiones con coste aceptado

1. **Ruby 4.0.2 con fastlane 2.237.0 no está probado.** El requisito es `>= 2.7` sin tope
   superior, pero Ruby 4.0 es reciente y fastlane tiene mucha superficie de gemas nativas.
   Mitigación: **instalar y ejecutar `fastlane --version` como primerísima tarea**, antes de
   escribir una línea de configuración. Si rompe, fijar Ruby 3.3 con rbenv — barato si se
   descubre primero, caro si se descubre con todo ya escrito.
2. **Publicación automática sin lectura humana.** Decisión consciente: una versión puede salir
   viva a las 3 de la madrugada sin que nadie haya visto cómo queda la ficha. Queda anotado
   como elección, no como descuido.
3. **El texto de la ficha pierde historial en git.** Consecuencia de ignorar `fastlane/`
   entero. Es texto que `CLAUDE.md` dice que se ha reescrito seis veces por afirmar más de lo
   que el predicado sostiene, y a partir de ahora esas reescrituras no dejan rastro versionado.
   Mitigación parcial: el paso 11 del preflight sigue comprobando mecánicamente las
   afirmaciones que sí son comprobables contra el dataset.
4. **CloudKit puede no estar desplegado a producción.** `Plotline.entitlements` declara el
   contenedor `iCloud.com.jbgsoft.Plotline`. Si sigue solo en desarrollo, la sincronización de
   favoritos y watchlist falla para usuarios reales de una build aprobada. No es comprobable
   desde el repo: va al runbook.
5. **`aps-environment` vale `development`** en los entitlements que se compilan. Conviene
   revisarlo antes del envío.

## 11. Lo que sigue sin automatizarse

- **La respuesta en el Resolution Center.** No existe API. El lane `release` imprime el orden
  correcto y **continúa igualmente**: se eligió aviso sin barrera. El orden que imprime es el
  que ya estaba documentado — responder antes de subir nada, porque reenviar en silencio es lo
  que convirtió un rechazo en tres.
- Clasificación por edades, etiquetas de privacidad, categoría y precio.
- Despliegue del contenedor de CloudKit a producción.
- Leer las dieciséis capturas antes de subirlas, y comprobar que el titular de cada una sigue
  siendo cierto sobre lo que muestra.
