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
| `bundle exec fastlane release_dry_run` | Preflight (modo release) → `precheck` → build. No sube ni envía nada. |
| `bundle exec fastlane release` | Preflight (modo release) → build → `deliver` sube binario, texto y capturas juntos, envía a revisión y publica automáticamente en cuanto Apple aprueba → etiqueta el commit `v1.4.0`. |

`release` envía a revisión **y** publica en cuanto se aprueba, sin que nadie lea la ficha entre
la aprobación y que los usuarios la vean. Es una decisión explícita del autor, no un descuido —
anotada en el spec, §10.

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
5. `bundle exec fastlane bootstrap` para repoblar `fastlane/metadata/`.
6. `./Scripts/release-preflight.sh --for=release` — el paso 9 confirma que no se ha filtrado
   ninguna credencial a git, los pasos 10 y 11 confirman que el texto de la ficha está presente
   y es cierto.

`Fastfile` y `Deliverfile` se recrean a partir del spec,
`docs/superpowers/specs/2026-08-10-app-store-automation-design.md` §5.

## Dos asuntos abiertos, sin decidir todavía

- `support_url` y `privacy_url` en la ficha apuntan hoy a la misma URL, la de la política de
  privacidad. No es un fallo de la automatización — es una decisión de producto pendiente del
  autor.
- El linter ASO avisa de que `seasons` y `tv` están comprados dos veces cada uno: aparecen tanto
  en el subtítulo como en el campo de keywords (95/100 caracteres usados). `bundle exec fastlane
  aso` lo marca como warning, no como fallo, y nadie lo ha resuelto todavía.

## Lo que se sigue pegando a mano

Clasificación por edades, etiquetas de privacidad, categoría, precio, y cualquier mensaje del
Resolution Center.
