# App Store description — Plotline 1.4.0

> The strings themselves now live in `fastlane/metadata/en-US/*.txt`, which is
> **not** in version control — see
> `docs/superpowers/specs/2026-08-10-app-store-automation-design.md` §3 for why.
> What is kept here is the reasoning behind the copy, which is the part that
> stops it claiming more than the engine can support.

> §12 of the spec: the axis is the derived analysis, not the catalogue. A description that
> opens with "browse movies and TV series" invites exactly the reading that got us rejected.

---

## A note on the required attributions

Two are not optional and both must appear where the data is shown:

- **TMDB**: "This product uses the TMDB API but is not endorsed or certified by TMDB." Included at the end of `fastlane/metadata/en-US/description.txt`. The TMDB logo requirement is **not** met in-app: `Assets.xcassets` contains no TMDB logo, and this branch removed the last on-screen appearance of the word "TMDB" from the detail screen. This remains outstanding.
- **JustWatch**: TMDB's terms for the watch-providers endpoint require crediting JustWatch as the source and state that non-compliance revokes API access. The app draws that credit in the same view as the providers; the description above also names them.
