# Reenvío a App Review — Plotline 1.4.0

Todo lo de esta carpeta va **pegado a mano en App Store Connect**. No hay automatización, y no debería haberla: cada texto conviene releerlo antes de enviarlo.

## Qué hay aquí

| Archivo | Dónde va |
|---|---|
| `resolution-center-reply.md` | El hilo existente del Resolution Center. **Primero esto**, antes de subir el build. |
| `app-review-notes.md` | App Store Connect → App Review Information → Notes |
| `app-store-description.md` | Descripción, subtítulo, texto promocional, keywords y novedades |

Los textos que se pegan están en inglés y marcados entre `## Paste from here` y `## Paste to here`. Lo de fuera de esas marcas es contexto para nosotros.

## Capturas

En `screenshots/1.4.0/`, con las medidas exactas que acepta App Store Connect — ocho archivos por familia, `01.png` a `08.png`:

| Carpeta | Archivos | Medida | Dispositivo |
|---|---|---|---|
| `screenshots/1.4.0/iphone-69/` | `01.png`–`08.png` | 1320 × 2868 | iPhone 6.9" |
| `screenshots/1.4.0/ipad-13/` | `01.png`–`08.png` | 2752 × 2064 (apaisado) | iPad 13" |

Cada archivo es un fotograma de marketing — titular, pastilla de evidencia y una captura real de la app compuestos en una sola imagen —, no una captura suelta de una pantalla. Las dieciséis muestran lo que pide §12 del spec: **el análisis, no pósters**. Entre las ocho de cada familia: el Plotline Score con sus tres componentes, el veredicto de caída con las cifras que lo sustentan, el gráfico por temporada, la rejilla de episodios, los estantes curados de Discover, Where to Watch, Compare y Decade Battle.

**Cómo se hicieron:** `Scripts/screenshots/make.sh` (o `capture.sh` seguido de `render.sh` por separado — ver `CLAUDE.md`, sección «App Store Screenshots»). `capture.sh` recorre la app de verdad en el simulador, con datos reales de TMDB, y guarda ocho capturas crudas por familia; `render.sh` las compone con el titular y la evidencia en una sola pasada de Chrome y las corta en los ocho archivos de la tabla de arriba. No hay paso manual ni anclaje de `ScrollView`: ese método, usado para el 1.4.0 original, quedó retirado en este branch junto con las dos capturas que produjo. `Scripts/release-preflight.sh` (paso 8/9) comprueba que las dieciséis existen con su tamaño exacto antes de cualquier release, pero no que el titular de cada una siga siendo cierto sobre lo que la captura muestra — eso se sigue mirando a mano.

## Paso 0

`./Scripts/release-preflight.sh` antes de nada. No sustituye a la lista de
abajo —los textos se siguen pegando a mano a propósito— pero comprueba lo que
sí se puede comprobar, e imprime esa lista al terminar.

## El orden que importa

1. **Responder en el Resolution Center antes de subir nada.** Reenviar en silencio es lo que convirtió un rechazo en tres: cada revisor nuevo abría la misma app con la misma primera impresión y ningún motivo para mirar más.
2. Subir el build 1.4.0 (7).
3. Actualizar descripción, subtítulo, promocional, keywords y novedades.
4. Sustituir las capturas.
5. Pegar las App Review Notes.
6. **Pedir la llamada** desde el Resolution Center. Con tres 4.2 encadenados, una conversación aclara más que un cuarto envío a ciegas.

## Qué NO decir

El spec lo avisa y conviene repetirlo: no discutir el criterio. La impresión del revisor era **acertada sobre lo que vio** — la pestaña de Stats se abría vacía en instalación limpia, el gráfico de episodios llevaba desconectado desde `16f6c77`, y la app corría encajonada en su iPad. Lo que cambió es la app, no el argumento.
