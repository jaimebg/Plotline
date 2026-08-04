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

En `screenshots/1.4.0/`, con las medidas exactas que acepta App Store Connect:

| Archivo | Medida | Dispositivo |
|---|---|---|
| `iphone-69-analysis.png` | 1320 × 2868 | iPhone 6.9" |
| `ipad-13-analysis.png` | 2064 × 2752 | iPad 13" |

Las dos muestran lo que pide §12 del spec: **el análisis, no pósters**. Se ve el Plotline Score con sus tres componentes, los cuatro veredictos con las cifras que los sustentan, los episodios destacados y el inicio del gráfico por episodio.

**Cómo se hicieron, para que conste:** la app se arrancó temporalmente en la ficha de Breaking Bad y se desplazó el `ScrollView` con un anclaje, de forma que la captura muestra la pantalla real a media altura en lugar de tener que hacer scroll a mano. Ambos cambios se revirtieron; no están en el repositorio. Las pantallas son las de verdad, con datos reales de TMDB.

**Faltan capturas** para completar el envío. Estas dos son las que defienden el argumento; conviene añadir al menos Discover con los estantes curados y la pestaña Stats, y App Store Connect admite hasta diez. Como no puedo simular toques en el simulador desde aquí, esas requieren una pasada manual.

## El orden que importa

1. **Responder en el Resolution Center antes de subir nada.** Reenviar en silencio es lo que convirtió un rechazo en tres: cada revisor nuevo abría la misma app con la misma primera impresión y ningún motivo para mirar más.
2. Subir el build 1.4.0 (7).
3. Actualizar descripción, subtítulo, promocional, keywords y novedades.
4. Sustituir las capturas.
5. Pegar las App Review Notes.
6. **Pedir la llamada** desde el Resolution Center. Con tres 4.2 encadenados, una conversación aclara más que un cuarto envío a ciegas.

## Qué NO decir

El spec lo avisa y conviene repetirlo: no discutir el criterio. La impresión del revisor era **acertada sobre lo que vio** — la pestaña de Stats se abría vacía en instalación limpia, el gráfico de episodios llevaba desconectado desde `16f6c77`, y la app corría encajonada en su iPad. Lo que cambió es la app, no el argumento.
