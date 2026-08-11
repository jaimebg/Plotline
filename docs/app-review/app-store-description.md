# App Store description — Plotline 1.4.0

> The strings themselves now live in `fastlane/metadata/en-US/*.txt`, which is
> **not** in version control — see
> `docs/superpowers/specs/2026-08-10-app-store-automation-design.md` §3 for why.
> What is kept here is the reasoning behind the copy, which is the part that
> stops it claiming more than the engine can support.

> §12 of the spec: the axis is the derived analysis, not the catalogue. A description that
> opens with "browse movies and TV series" invites exactly the reading that got us rejected.

---

## Why the app is named for the analysis, not the catalogue

The listing was `Plotline TV & Movies` through all three rejections. That name
describes a catalogue browser, in the field Apple weights most heavily and the
one a reviewer reads before anything else — the same reading §12 of the spec
warns the *description* must not invite. `Plotline: TV Show Analysis` commits
to the derived analysis in the same place.

It costs the `movies` token, which the keyword field buys back. The keyword
field also stopped paying twice for `tv`, `analysis`, `seasons` and `shows`,
all of which the name and subtitle now index on their own — eleven characters
that were buying nothing.

## Why no number of series appears in the store copy

The description used to open its offline section with a literal entry count,
and `release-preflight.sh` step 11 proved that count matched
`PlotlineDataset.json`. Both are gone, and step 11 now asserts the inverse: a
release fails if a count is put back.

A count is the one claim in that file that goes stale on its own. Every
dataset regeneration can change it, and nothing about regenerating the dataset
prompts anyone to reopen the store listing — so the claim decays silently
while the check that guarded it can only ever be as current as the last person
who remembered both. Removing the claim removes the decay. The same reasoning
took the number out of the App Review notes, the Resolution Center reply and
the README; it survives only in the historical plans and specs under
`docs/superpowers/`, which are records of what was decided when, not live
claims.

## A note on the required attributions

Two are not optional and both must appear where the data is shown:

- **TMDB**: "This product uses the TMDB API but is not endorsed or certified by TMDB." Included at the end of `fastlane/metadata/en-US/description.txt`. The TMDB logo requirement is **not** met in-app: `Assets.xcassets` contains no TMDB logo, and this branch removed the last on-screen appearance of the word "TMDB" from the detail screen. This remains outstanding.
- **JustWatch**: TMDB's terms for the watch-providers endpoint require crediting JustWatch as the source and state that non-compliance revokes API access. The app draws that credit in the same view as the providers; `fastlane/metadata/en-US/description.txt` also names them.
