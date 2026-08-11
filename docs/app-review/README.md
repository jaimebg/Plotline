# Runbook de release — Plotline 1.4.0

Las releases están automatizadas con Fastlane, en local, desde un único Mac.

**`fastlane/` no está en control de versiones.** Ahí viven una credencial de subida de App
Store Connect y los datos de contacto de revisión, que no tienen sitio en un repo público. Este
archivo es, por tanto, el único registro versionado de cómo se ejecuta una release — y de cómo
reconstruir esa carpeta si esta máquina se pierde.

## Los lanes

| Comando | Qué hace |
|---|---|
| `bundle exec fastlane aso` | Lints del texto de la ficha contra los límites de Apple y el desperdicio de keywords. Sin red, sin build, sin credenciales. |
| `bundle exec fastlane bootstrap` | Descarga lo que ya está vivo en App Store Connect a `fastlane/metadata/`. Se niega a machacar un `en-US/` que ya tenga texto redactado, salvo que se pase `force:true`. |
| `bundle exec fastlane beta` | Preflight (modo beta) → build → sube a TestFlight. |
| `bundle exec fastlane metadata` | Sube solo el texto de la ficha, sin binario ni capturas. Sin build. |
| `bundle exec fastlane screenshots` | Regenera los dieciséis fotogramas de marketing (`make.sh`) y los sube. Sin build. |
| `bundle exec fastlane release_dry_run` | Preflight (modo release) → `stage_screenshots` (para ejercitar también el defecto Crítico de la Tarea 7, ver abajo) → `precheck` → build. No sube ni envía nada. |
| `bundle exec fastlane release` | Preflight (modo release) → `stage_screenshots` (barrera fail-fast: si el set de capturas no está completo, falla aquí y no gasta minutos archivando) → build → `deliver` sube binario, texto y capturas juntos, envía a revisión y publica automáticamente en cuanto Apple aprueba → etiqueta el commit `v1.4.0`. |

`release` envía a revisión **y** publica en cuanto se aprueba, sin que nadie lea la ficha entre
la aprobación y que los usuarios la vean. Es una decisión explícita del autor, no un descuido —
anotada en el spec, §10.

## Al subir de versión

El paso 5 del preflight busca `MARKETING_VERSION` en cualquier archivo de `docs/app-review/` —
uno solo le basta para pasar. Pero hay cinco sitios en esta carpeta que llevan el número
grabado, y una subida de versión que solo toque `project.pbxproj` deja cuatro desactualizados
sin que nada lo detecte:

- Este archivo, dos veces: el encabezado (línea 1) y el ejemplo de tag en la fila de `release`
  de la tabla de arriba. Esta lista no escribe el número a propósito: si lo hiciera, sería un
  tercer sitio que actualizar, y quedaría contradiciendo a la tabla en la siguiente subida.
- `app-store-description.md`, línea 1.
- `app-review-notes.md`, línea 1.
- `resolution-center-reply.md`, línea 17.

## Antes de la primera release de una versión

1. `bundle exec fastlane release_dry_run` — prueba el pipeline entero sin tocar la ficha ni el
   binario publicado.
2. Responder en el Resolution Center si hay un hilo abierto. **Antes de subir nada.** No existe
   API para esto y `release` no se detiene a esperarlo — solo lo avisa por pantalla y continúa
   (spec, §11).
3. Desplegar el contenedor CloudKit `iCloud.com.jbgsoft.Plotline` a Production.
4. Leer las dieciséis capturas. Nada comprueba que un titular siga siendo cierto sobre la
   captura que tiene debajo.
5. Leer `fastlane/metadata/en-US/release_notes.txt` a mano. El paso 5 del preflight solo
   comprueba que la versión actual aparece en algún archivo de `docs/app-review/` — nunca abre
   `release_notes.txt`. Nada, en ningún paso, comprueba que esas notas describan esta versión.

## Firma de código

Dos datos que costaron una hora en esta sesión y que, sin dejarlos escritos, le costarán otra a
quien venga después:

- **El perfil de aprovisionamiento de distribución solo se regenera cuando Xcode firma de
  verdad para distribución** — es decir, Organizer → Distribute App. Abrir Xcode o simplemente
  mirar Signing & Capabilities refresca el perfil de DESARROLLO y deja el de distribución
  obsoleto. La acción obvia no es la que funciona.
- **El certificado de distribución actual caduca el 2027-02-24.** Cuando rote, el perfil
  desactualizado fallará de la misma forma silenciosa, y el fallo solo aparece en el paso de
  exportación — unos 9 minutos dentro de una release, después del preflight y de un archive
  completo. Diagnóstico rápido: reejecutar `xcodebuild -exportArchive` contra un archive que ya
  existe, en vez de volver a compilar todo, para confirmarlo sin esperar otro archive entero.

## Reconstruir `fastlane/` en una máquina nueva

1. `bundle install`
2. Crear `fastlane/.keys/` y meter ahí el `.p8` de App Store Connect, `chmod 600`. Si se
   pierde, revocarlo en App Store Connect → Users and Access → Integrations y generar uno
   nuevo; el archivo se descarga una sola vez y no se puede volver a descargar.
3. Escribir `fastlane/.env` con `ASC_KEY_ID`, `ASC_ISSUER_ID` y `ASC_KEY_PATH`. El issuer id
   está en esa misma página de App Store Connect.
4. Escribir `fastlane/Appfile` con `app_identifier("com.jbgsoft.Plotline")` y
   `team_id("95PGC3PATF")`.
5. Recrear `fastlane/Fastfile` y `fastlane/Deliverfile` a mano. Tienen que existir los dos
   **antes** del paso siguiente: sin `Fastfile` no hay lanes que ejecutar, y `bootstrap` carga
   `Deliverfile` (`config.load_configuration_file("Deliverfile")`) antes de tocar la red. El
   spec, `docs/superpowers/specs/2026-08-10-app-store-automation-design.md` §5, es el punto de
   partida — pero implementarlo demostró que se equivoca en tres sitios. Léase «Correcciones al
   spec §5» más abajo antes de copiarlo literalmente; sin ellas, `bootstrap` y `release` fallan
   de formas ya conocidas.
6. `bundle exec fastlane bootstrap` para repoblar `fastlane/metadata/`.
7. `./Scripts/release-preflight.sh --for=release` — el paso 9 confirma que no se ha filtrado
   ninguna credencial a git, los pasos 10 y 11 confirman que el texto de la ficha está presente
   y es cierto.

### Correcciones al spec §5

El spec está marcado «diseño validado, sin implementar», y tres de sus afirmaciones no
sobrevivieron a la implementación real. Reconstruir `Fastfile`/`Deliverfile` copiando el spec
tal cual reproduce el primer borrador con fallos ya conocidos, no la implementación real:

- **`bootstrap`** (spec `:105`) dice que es «`deliver download_metadata`». `download_metadata`
  es un verbo solo de la CLI de `deliver` (`fastlane deliver download_metadata`) — no es una
  opción de la ACCIÓN `deliver`/`upload_to_app_store` que se llama desde un Fastfile;
  `Deliver::Options` no la reconoce y pasarla lanza un error antes de tocar la red. Esa acción
  solo tiene un punto de entrada, `Deliver::Runner#run`, y siempre SUBE el árbol local — nunca lo
  descarga. El lane real en cambio reproduce a mano lo que hace ese verbo de la CLI: construye la
  API key, carga `Deliverfile` en una `Deliver::Configuration`, llama a `Deliver::Runner.new`
  solo para autenticar y detectar la app (nunca `.run`, así que la ruta de subida nunca es
  alcanzable desde este lane), y escribe la ficha viva a disco con
  `Deliver::Setup#generate_metadata_files`.
- **`Deliverfile`** (spec `:65-67`) dice que `screenshots_path` apunta a `screenshots/<version>/`.
  Ese fue el defecto Crítico de la Tarea 7: `Deliver::Loader` exige que cada carpeta
  directamente bajo `screenshots_path` sea un código de idioma (`en-US`, `ja`, ...); una carpeta
  por familia de dispositivo (`iphone-69/`, `ipad-13/`) no lo es, y con la validación
  desactivada la carga falla en silencio con CERO capturas. El `Deliverfile` real no fija
  `screenshots_path`. En su lugar, el lane privado `stage_screenshots` construye una vista
  desechable de symlinks en `fastlane/screenshots/en-US/` a partir del árbol real por familia de
  dispositivo. `stage_screenshots` corre en los tres lanes (`screenshots`, `release_dry_run`,
  `release`), y por eso `release_dry_run` sí ejercita el defecto de la Tarea 7 — pero solo
  `screenshots` y `release` llegan a llamar a `deliver`, y son los únicos dos que pasan
  `screenshots_path: STAGED_SCREENSHOTS` en su propia llamada. `release_dry_run` termina en
  `precheck`, que no toma `screenshots_path`.
- **`release`** (spec `:108`) dice que llama a la acción `precheck`. El lane real en cambio pasa
  `run_precheck_before_submit: true` a `deliver`, que ejecuta precheck como parte de su propio
  envío y sí lee `precheck_include_in_app_purchases(false)` del `Deliverfile`. La acción
  `precheck` sí se llama, pero solo desde `release_dry_run`, con
  `include_in_app_purchases: false` pasado directamente ahí — esa acción no tiene `Deliverfile`
  propio que leer, así que el ajuste no se hereda y hay que repetirlo.

Tampoco aparecen en ningún documento versionado: la instantánea de bytes de `project.pbxproj`
que `beta` y `release` leen entera antes de `increment_build_number` y restauran tal cual en un
`ensure` (en vez de `git checkout --`, que descartaría un cambio sin commitear de la sesión de
Claude que comparte este checkout); `overwrite_screenshots: true` (sin él, `deliver` nunca borra
lo que ya está subido y tapa cada dispositivo en 10 imágenes, descartando el resto en silencio);
`include_in_app_purchases: false`; `output_directory: "build"`; y `export_team_id`. Este
apartado corrige lo que el spec afirma mal; no sustituye leer el `Fastfile` real si hace falta
el detalle exacto.

## Dos asuntos abiertos, sin decidir todavía

- `support_url` y `privacy_url` en la ficha apuntan hoy a la misma URL, la de la política de
  privacidad. No es un fallo de la automatización — es una decisión de producto pendiente del
  autor.
- El linter ASO avisa de que `seasons` y `tv` están comprados dos veces cada uno en el campo de
  keywords (95/100 caracteres usados) — pero no por el mismo campo: `seasons` ya está en el
  subtítulo (`subtitle.txt` = «Which seasons are worth it»); `tv` no está ahí, está en el nombre
  de la app (`name.txt` = «Plotline TV & Movies»). El linter compara contra el nombre O el
  subtítulo, no solo el subtítulo — su propio mensaje lo dice así. `bundle exec fastlane aso` lo
  marca como warning, no como fallo, y nadie lo ha resuelto todavía.

## Lo que se sigue pegando a mano

Clasificación por edades, etiquetas de privacidad, categoría, precio, y cualquier mensaje del
Resolution Center.
