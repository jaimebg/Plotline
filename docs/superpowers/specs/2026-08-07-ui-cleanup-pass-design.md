# UI Cleanup Pass — Design

**Date:** 2026-08-07
**Status:** approved for planning

Six unrelated UI corrections, gathered into one pass because five of them are
deletions and the sixth is a colour sweep that touches the same screens.

Nothing here changes the analysis engine, the dataset, or what the app claims
about a series. Two changes do remove a feature and two trend explorers, so the
App Store copy that describes them has to come down with them.

---

## 1. Share buttons — delete

The detail screen's share sheet offered a themoviedb.org link. Sharing a TMDB
page is not sharing anything this app made, so the affordance goes.

- `Plotline/Views/Detail/MediaDetailView.swift` — delete the `ShareLink` block
  from the `.topBarTrailing` toolbar item. `watchlistMenuButton` and the
  favourite button stay, in that order.
- `Plotline/Models/MediaItem.swift` — delete `shareURL` and `shareText`. Both
  exist only for the deleted `ShareLink`; a grep confirms no other caller.

---

## 2. Ratings fold into the title metadata

`ScorecardsView` was built to hold a row of scorecards from several rating
sources. Since OMDb was removed there is one source, and a section heading over
a single 70pt tile reads as a leftover.

- Delete `Plotline/Views/Detail/ScorecardsView.swift`.
- Delete `Plotline/Views/Detail/RatingCard.swift` — it holds only
  `TMDBRatingCard`, whose one call site is `ScorecardsView`.
- Remove the `ScorecardsView(...)` call from `MediaDetailView`'s content stack.
- In `MediaDetailView.titleSection`, add the score to the existing metadata
  `HStack`, after year and season count, shown only when `voteAverage > 0`:

```
TV SERIES
Breaking Bad
📅 2008    🎬 5 Seasons    ⭐ 8.4 TMDB
```

The star glyph takes `Color.imdbYellow`, matching every other rating readout in
the app. The word **TMDB** stays beside the number as the source label.

**Two accepted consequences**, both stated when this option was chosen:

- The score is no longer tappable. `TMDBRatingCard` opened themoviedb.org on
  tap; the metadata row is plain text with no affordance.
- The "No ratings available" empty card disappears. An unrated title simply
  omits the item from the row.

Accessibility: the metadata row's rating reads as
`"rated 8.4 out of 10 on TMDB"`.

**Flagged, not in scope:** that "TMDB" label is the app's only on-screen
mention of the data source. TMDB's attribution statement currently appears in
the App Store description (`docs/app-review/app-store-description.md:79`) but
nowhere inside the app. Worth its own task; this change does not make it worse.

---

## 3. Subtitles move under their titles

Two places put an explanatory line *after* the content it explains.

### Home screen — curated shelves

`DiscoveryView.curatedShelves` wraps a `MediaSection` in a `VStack` and appends
the subtitle underneath the poster row, so the explanation of a shelf arrives
after the shelf.

- `Plotline/Views/Discovery/MediaSection.swift` — add
  `subtitle: String? = nil` to `MediaSection`, rendered inside the header
  `VStack` directly under the title and above the horizontal `ScrollView`,
  carrying the same `.padding(.horizontal)` as the title. Style stays
  `.subheadline` / `.secondary`.
- `Plotline/Views/Discovery/DiscoveryView.swift` — `curatedShelves` collapses to
  a single `MediaSection(title:subtitle:items:)` call. The existing
  `.accessibilityElement(children: .contain)`, `.accessibilityLabel(title)`,
  `.accessibilityHint(subtitle)` and `AccessibilityAnchors.discoverShelf`
  identifier all stay on the shelf.

`AccessibilityAnchors.discoverShelf` is load-bearing for the cold-start UI
suite — it must remain on the element that renders unconditionally.

### Detail screen — Plotline Score components

In `PlotlineScoreCard.component(...)` the caption sits below the progress bar.

- `Plotline/Views/Detail/Analysis/PlotlineScoreCard.swift` — move
  `Text(caption)` above the `ProgressView`.

```
Level                         88
How highly its episodes rate
▓▓▓▓▓▓▓▓▓▓▓░░░
```

The combined accessibility label is unchanged.

---

## 4. Standout Episodes — delete

- Delete `Plotline/Views/Detail/Analysis/StandoutEpisodesView.swift`.
- `Plotline/Views/Detail/Analysis/SeriesAnalysisSection.swift` — remove the
  `StandoutEpisodesView(analysis:)` call. The `.analyzed` branch keeps
  `PlotlineScoreCard` and `SeriesVerdictsView`.
- Delete `PlotlineTests/StandoutCopyTests.swift`. One of its two tests reads
  `StandoutEpisodesView.weakestTitle`, which no longer exists; the other guards
  the honesty of copy that is being removed with it.

### What is deliberately kept

`SeriesAnalysis.essentialEpisodes` / `.skippableEpisodes`, the engine's
`standoutEpisodes(from:)`, `SeriesAnalysisEngineStandoutTests`, and the
corresponding fields in `Resources/PlotlineDataset.json` all stay.

Removing them changes `Models/SeriesAnalysis.swift`, which is one of the four
files symlinked into `Tools/DatasetGenerator/`, and would force a full
regeneration of the 122-entry dataset over the TMDB API. That is
disproportionate to removing a UI section and belongs in its own task. The cost
of keeping them is an unread field in a bundled JSON file.

### App Store copy that must come down

- `docs/app-review/app-review-notes.md:23` — delete the **Standout Episodes**
  bullet from the "what you will find" list.
- `docs/app-review/app-review-notes.md:28` — "the score, the verdicts and the
  standout episodes are all there" → drop the third item.
- `docs/app-review/app-store-description.md:54` — delete the standout episodes
  bullet.
- `docs/app-review/app-store-description.md:64` — "the scores, verdicts and
  standout episodes are all there" → drop the third item.
- `docs/app-review/app-store-description.md:95` — remove "and the standout
  episodes of each season" from the What's New paragraph.

---

## 5. Genre Evolution and Best Years — delete

Both views average `vote_average` over TMDB's top 20 movies for each of the
last 30–50 years and plot the result. That produces a near-flat line, and the
titles claim more than the measurement establishes: averaging twenty TMDB
scores does not identify the best years for film. It is also the opposite of
what the rest of the app does — every other verdict is derived by Plotline's own
engine and printed with the figures behind it.

Each view also fires 30–50 concurrent `discoverMovies` requests per open,
against a rate limit the app already manages with an on-disk cache elsewhere.

Delete four files:

- `Plotline/Views/Stats/GenreEvolutionView.swift` (also removes
  `GenreEvolutionAccessibility`)
- `Plotline/Views/Stats/BestYearsView.swift` (also removes
  `BestYearsAccessibility`)
- `Plotline/ViewModels/GenreEvolutionViewModel.swift` (also removes
  `GenreYearPoint`)
- `Plotline/ViewModels/BestYearsViewModel.swift` (also removes `YearRating`)

`Plotline/Views/Stats/TrendsView.swift` drops the two corresponding
`trendCard(...)` calls, leaving Decade Battle and Franchise Tracker. The
adaptive grid still fills — two columns on iPhone, more on iPad — and
`AccessibilityAnchors.statsTrends` stays on the enclosing section in
`StatsView`, so the cold-start UI suite is unaffected.

`TMDBService.discoverMovies` and `CuratedGenre` both have other callers and
stay.

### App Store copy that must be narrowed

- `docs/app-review/app-review-notes.md:26` — "four trend explorers" → two.
- `docs/app-review/app-store-description.md:71` — "Trend explorers: genre
  evolution, best years, decade battles, franchise tracking" → "Trend
  explorers: decade battles and franchise tracking".

---

## 6. Red

### The colour

A new asset-catalog colour set, `Plotline/Assets.xcassets/PlotlineAccent.colorset`:

| Appearance | Hex | sRGB components |
|---|---|---|
| light (universal) | `#B33A00` | r 0.702, g 0.227, b 0.000 |
| dark | `#FF7A33` | r 1.000, g 0.478, b 0.200 |

The target generates Swift symbols from colour sets — that is how
`Color.plotlineCard` and `Color.plotlineBackground` exist without a declaration
— so `PlotlineAccent.colorset` yields `Color.plotlineAccent` with no code
change. A comment in the "Adaptive Background Colors" section of
`Extensions/Color+Plotline.swift` notes it alongside the others.

The hue is deliberately deeper than `plotlineSecondaryAccent` (`#FF6500`) in
both modes, because the two sit side by side in the Stats overview row.

### The two rules

1. Red on a **glyph, fill, chip background, swipe tint or chart mark** becomes
   `Color.plotlineAccent`.
2. Red on **body text** becomes `.primary` or `.secondary` — never the accent.

**The one exception to rule 2**, approved explicitly: the app's own brand type.
The tab bar tint colours the selected tab's *label* as well as its icon, and
the "Plotline" wordmark is text drawn in a gradient. Both take the accent
rather than a neutral. The point of rule 2 is to get the red off text, and
these two are the brand's identity rather than content.

### Rule 1 — red becomes `plotlineAccent`

| File | Line | What it colours |
|---|---|---|
| `Views/Stats/TrendsView.swift` | 33 | Decade Battle glyph and its circle |
| `Views/Settings/SettingsView.swift` | 79 | theme-selected checkmark glyph |
| `Views/Favorites/FavoritesView.swift` | 95 | sort menu glyph |
| `Views/Favorites/WatchlistView.swift` | 152 | sort menu glyph |
| `Views/Favorites/WatchlistView.swift` | 118 | leading swipe action tint |
| `Views/Discovery/GenreResultsView.swift` | 105 | sort menu glyph |
| `Views/Detail/MediaDetailView.swift` | 201 | watchlist toolbar glyph when saved |
| `App/ThemeManager.swift` | 29 | dark-appearance moon glyph |
| `Views/Stats/StatsView.swift` | 175 | Favorites `StatCard` glyph + 15% circle |
| `Views/Stats/StatsView.swift` | 412 | Favorites rating pill background + border |
| `Views/Stats/CareerProfileView.swift` | 239 | "Worst Rated" glyph + 10% background |
| `Views/Stats/RatingComparisonBar.swift` | 10 | third comparison slot's bar |
| `Views/Stats/CompareView.swift` | 140 | third chart line |
| `Views/Stats/GenreDNAChart.swift` | 16 | third donut sector and its legend swatch |
| `Views/Detail/SeriesGraphView.swift` | 417 | third season's line colour |
| `Views/Detail/MovieFeatures/BoxOfficeView.swift` | 31 | revenue `MetricBar` fill when unprofitable |
| `Views/MainTabView.swift` | 41 | tab bar tint (see the rule 2 exception) |
| `Views/Stats/StatCard.swift` | 39 | `#Preview` argument — otherwise the invariant test below fails on it |

`StatCard`, `quickStatItem` and `ratingPill` each apply their `color` only to a
glyph and a tinted background — their value and label text is already
`.primary` / `.secondary`, so rule 2 is already satisfied there.

### Rule 1a — gradients keep a fixed start

Two gradients ramp from the red into `plotlineSecondaryAccent` (`#FF6500`). In
dark mode the adaptive accent is `#FF7A33`, close enough to `#FF6500` that the
ramp would collapse to two stops. Both take a **fixed** `#B33A00` as their
first stop in both appearances, not the adaptive value:

- `Views/Components/AnimatedGradientText.swift` lines 10 and 14 — the "Plotline"
  wordmark.
- `Views/Discovery/DiscoveryView.swift` line 382 — the Genre Browse card's
  circle.

This needs one static constant; `Color.plotlineTertiary` (`#CC561E`) is close
but not the chosen value, so a new `plotlineAccentDeep` is declared in
`Color+Plotline.swift` beside the other static brand colours.

### Rule 2 — red text becomes neutral

| File | Line | Change |
|---|---|---|
| `Views/Detail/MovieFeatures/BoxOfficeView.swift` | 51 | ROI arrow + value: `isProfitable ? .rottenGreen : .primary` |
| `Views/Detail/MovieFeatures/BoxOfficeView.swift` | 66 | profit/loss value: same |
| `Views/Favorites/WatchlistView.swift` | 224 | status `Label`: `watchStatus == "watched" ? .green : .secondary` |

In Box Office the direction is already carried by the `arrow.up.right` /
`arrow.down.right` glyph, so dropping the red loses no information.

### Deliberately unchanged

- **The episode rating scale** — `ratingBad` (`#F44336`), `chartLow`, and the
  `"0-2"` bar in `StatsView.barColor`. Red means *low rating* there, the scale
  is legend-backed in `EpisodeRatingsGridView`, the numbers are drawn in white
  *on top of* it rather than in it, and recolouring to orange would collide
  with `ratingRegular` (`#FF9800`).
- **`Button(role: .destructive)`** in the watchlist's trailing swipe action.
  iOS colours it; overriding the platform's delete convention is a different
  decision.
- **The favourite heart** in `MediaDetailView:146`. System `.red` on a filled
  heart, an iOS-wide convention, and confirmed as out of scope.

### The invariant this leaves

After the sweep, no file under `Plotline/Views/` or `Plotline/App/` references
`plotlinePrimary`, `rottenRed` or `metacriticRed`. The red survives only inside
`Extensions/Color+Plotline.swift`, as the value behind `chartLow` and the two
aliases, for the rating scale above.

That is worth a guard, because the failure mode is a future edit quietly
reaching for the brand red again. A new suite,
`PlotlineTests/AccentColorSourceTests.swift`, reads the view sources from disk
via `#filePath` — the technique `WatchAttributionSourceTests` already
establishes for claims that cannot be asserted against a rendered SwiftUI tree
— and fails if any of the three symbols appears there.

Scope note: `chartLow` remains permitted, since it is how the rating scale
names its low end.

---

## Verification

| Check | Command |
|---|---|
| Unit + cold-start suites | `xcodebuild -project Plotline.xcodeproj -scheme Plotline -destination 'platform=iOS Simulator,name=iPhone 17' test` |
| iPad — the device App Review used | same, `-destination 'platform=iOS Simulator,name=iPad Air 11-inch (M4)'` |
| Release gates incl. doc coherence | `./Scripts/release-preflight.sh` |

Test count moves from 147 `@Test` functions / 151 cases to **146 / 150**:
`StandoutCopyTests` removes two, `AccentColorSourceTests` adds one. The counts
are recorded in `CLAUDE.md` under "Build Commands" and must be updated with
them.

Two checks that no suite can make, and that must be done by eye in **both light
and dark**, since item 6 is entirely about colour:

1. Stats tab — overview cards, rating pills, Trends grid, Career Profile quick
   stats.
2. Detail screen — title metadata row with the folded-in rating, Plotline Score
   captions, Box Office on an unprofitable film.

Deleting files needs no project edits: the target uses a
`PBXFileSystemSynchronizedRootGroup`.

---

## Assumptions carried into implementation

1. The standout episode **data** stays in the model, the engine and the dataset;
   only the UI and its copy test are removed (§4).
2. The rating in the metadata row is **not tappable** and has no chevron (§2).
3. The two gradients take a **fixed** deep orange rather than the adaptive
   accent, to keep their ramp in dark mode (§6, rule 1a).
4. The **rating scale keeps red**, since red there encodes a value and never
   appears as text (§6).

Any of the four can be reversed cheaply; none of them blocks the rest.
