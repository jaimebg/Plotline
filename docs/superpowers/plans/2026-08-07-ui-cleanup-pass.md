# UI Cleanup Pass Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove four pieces of UI that no longer earn their place, move two
explanatory subtitles above the content they explain, and replace the brand red
throughout the interface with a theme-adaptive orange.

**Architecture:** Six independent changes to SwiftUI views, five of them
deletions. No change to the analysis engine, the dataset, the networking layer,
or any claim the app makes about a series. The one new mechanism is an
asset-catalog colour set, `PlotlineAccent`, which the target compiles into
`Color.plotlineAccent` automatically, plus a source-scanning test that keeps the
old red from creeping back.

**Tech Stack:** Swift 6, SwiftUI (iOS 26+), Swift Testing, Xcode asset catalogs,
`xcodebuild`.

Spec: `docs/superpowers/specs/2026-08-07-ui-cleanup-pass-design.md`

## Global Constraints

- **Light and dark mode are both supported.** Never `.white` for text — use
  `.primary`. Never a hardcoded dark background — use `Color.plotlineBackground`
  / `Color.plotlineCard`. Every change in this plan must be checked in both
  appearances.
- **No string may claim more than its predicate establishes.** Copy that
  describes a removed feature is removed with it, in the same commit.
- **Do not touch `WatchProvidersSection`'s JustWatch attribution.** TMDB revokes
  API access for showing that data uncredited, and every screen in this app is
  served by TMDB.
- **Shared with the dataset generator** — `Models/EpisodeMetric.swift`,
  `Models/SeriesAnalysis.swift`, `Models/PlotlineDataset.swift`,
  `Services/Analysis/SeriesAnalysisEngine.swift` may import only `Foundation`.
  No task here modifies them.
- **Grids size themselves from available width**, never a fixed column count.
- **Conventional Commits** for every commit message.
- The target uses a `PBXFileSystemSynchronizedRootGroup`, so **deleting a file
  needs no `.xcodeproj` edit** — `git rm` is sufficient.
- Test command, used at the end of every task:
  `xcodebuild -project Plotline.xcodeproj -scheme Plotline -destination 'platform=iOS Simulator,name=iPhone 17' test`

---

### Task 1: Delete the share button

The share sheet offered a themoviedb.org link, which is not this app's content.
`shareURL` and `shareText` exist only to feed it.

**Files:**
- Modify: `Plotline/Views/Detail/MediaDetailView.swift:125-134`
- Modify: `Plotline/Models/MediaItem.swift:79-91`

**Interfaces:**
- Consumes: nothing.
- Produces: nothing. `MediaItem.shareURL` and `MediaItem.shareText` cease to
  exist; no later task references them.

- [ ] **Step 1: Remove the `ShareLink` from the toolbar**

In `Plotline/Views/Detail/MediaDetailView.swift`, replace:

```swift
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 16) {
                    if let url = viewModel.media.shareURL {
                        ShareLink(item: url, subject: Text(viewModel.media.displayTitle),
                                  message: Text(viewModel.media.shareText)) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.primary)
                        }
                    }

                    watchlistMenuButton
```

with:

```swift
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 16) {
                    watchlistMenuButton
```

- [ ] **Step 2: Delete the two properties that fed it**

In `Plotline/Models/MediaItem.swift`, delete this block entirely:

```swift
    /// Shareable URL (TMDB)
    var shareURL: URL? {
        let path = isTVSeries ? "/tv/\(id)" : "/movie/\(id)"
        return URL(string: "https://www.themoviedb.org\(path)")
    }

    /// Text for sharing
    var shareText: String {
        if let year = year {
            return "Check out \(displayTitle) (\(year))"
        }
        return "Check out \(displayTitle)"
    }
```

- [ ] **Step 3: Build and run the suite**

Run:

```bash
xcodebuild -project Plotline.xcodeproj -scheme Plotline \
  -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Expected: build succeeds, all tests pass. If the compiler reports an unresolved
`shareURL` or `shareText`, a call site was missed — fix it before committing.

- [ ] **Step 4: Commit**

```bash
git add Plotline/Views/Detail/MediaDetailView.swift Plotline/Models/MediaItem.swift
git commit -m "refactor: drop the share button, which only linked to TMDB"
```

---

### Task 2: Fold the rating into the title metadata

`ScorecardsView` was built to hold several rating sources. Since OMDb was
removed there is one, and a section heading over a single 70pt tile reads as a
leftover of the layout it replaced.

**Files:**
- Modify: `Plotline/Views/Detail/MediaDetailView.swift:40-45` and `:258-272`
- Delete: `Plotline/Views/Detail/ScorecardsView.swift`
- Delete: `Plotline/Views/Detail/RatingCard.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: nothing. `ScorecardsView` and `TMDBRatingCard` cease to exist.
  `MediaItem.formattedRating` (`String`, `"%.1f"` of `voteAverage`) and
  `MediaItem.voteAverage` (`Double`) already exist and are used unchanged.

- [ ] **Step 1: Remove the ratings section from the content stack**

In `Plotline/Views/Detail/MediaDetailView.swift`, delete:

```swift
                    // Ratings section
                    ScorecardsView(
                        tmdbScore: viewModel.media.voteAverage,
                        mediaId: viewModel.media.id,
                        isTVSeries: viewModel.media.isTVSeries
                    )

```

`titleSection` and `overviewSection` become adjacent in the `VStack`.

- [ ] **Step 2: Add the rating to the metadata row**

In the same file, in `titleSection`, replace:

```swift
            // Metadata row
            HStack(spacing: 12) {
                if let year = viewModel.media.year {
                    Label(year, systemImage: "calendar")
                        .font(.subheadline)
                        .foregroundStyle(.primary.opacity(0.9))
                }

                if let totalSeasons = viewModel.media.totalSeasons, viewModel.media.isTVSeries {
                    Label("\(totalSeasons) Seasons", systemImage: "film.stack")
                        .font(.subheadline)
                        .foregroundStyle(.primary.opacity(0.9))
                }
            }
            .labelStyle(.titleAndIcon)
```

with:

```swift
            // Metadata row. The rating lives here rather than in a section of
            // its own: TMDB is the only source this app has, and a heading over
            // a single tile was the leftover of a two-source layout. "TMDB"
            // stays beside the number — it is the only place on this screen
            // that names where the figure came from.
            HStack(spacing: 12) {
                if let year = viewModel.media.year {
                    Label(year, systemImage: "calendar")
                        .font(.subheadline)
                        .foregroundStyle(.primary.opacity(0.9))
                }

                if let totalSeasons = viewModel.media.totalSeasons, viewModel.media.isTVSeries {
                    Label("\(totalSeasons) Seasons", systemImage: "film.stack")
                        .font(.subheadline)
                        .foregroundStyle(.primary.opacity(0.9))
                }

                if viewModel.media.voteAverage > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .foregroundStyle(Color.imdbYellow)

                        Text(viewModel.media.formattedRating)
                            .foregroundStyle(.primary.opacity(0.9))

                        Text("TMDB")
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Rated \(viewModel.media.formattedRating) out of 10 on TMDB")
                }
            }
            .labelStyle(.titleAndIcon)
```

Note what this deliberately does **not** do: there is no tap gesture and no
chevron. The score used to open themoviedb.org on tap; that affordance is gone
by decision, not by oversight.

- [ ] **Step 3: Delete the two files**

```bash
git rm Plotline/Views/Detail/ScorecardsView.swift Plotline/Views/Detail/RatingCard.swift
```

`TMDBRatingCard` lives in `RatingCard.swift` and its only call site was
`ScorecardsView`.

- [ ] **Step 4: Build and run the suite**

Run:

```bash
xcodebuild -project Plotline.xcodeproj -scheme Plotline \
  -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Expected: build succeeds, all tests pass.

- [ ] **Step 5: Check it on screen, in both appearances**

```bash
xcodebuild -project Plotline.xcodeproj -scheme Plotline \
  -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath build build && \
xcrun simctl install booted build/Build/Products/Debug-iphonesimulator/Plotline.app && \
xcrun simctl launch booted com.jbgsoft.Plotline
```

Open any series from a Discover shelf. Confirm the metadata row reads
`📅 year · 🎬 n Seasons · ⭐ 8.4 TMDB` on one line, that no "Ratings" heading
remains, and that the row wraps rather than clips on the narrowest phone. Then
switch appearance in Settings → Appearance and confirm both.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "refactor: fold the TMDB rating into the title metadata row"
```

---

### Task 3: Move subtitles above the content they explain

Two places print an explanatory line *after* the thing it explains.

**Files:**
- Modify: `Plotline/Views/Discovery/MediaSection.swift:4-56`
- Modify: `Plotline/Views/Discovery/DiscoveryView.swift:203-226`
- Modify: `Plotline/Views/Detail/Analysis/PlotlineScoreCard.swift:44-65`

**Interfaces:**
- Consumes: nothing.
- Produces: `MediaSection.init(title: String, subtitle: String? = nil,
  items: [MediaItem], style: MediaCard.CardStyle = .poster)`. The `subtitle`
  parameter is new and defaulted, so every existing call site compiles
  unchanged.

- [ ] **Step 1: Give `MediaSection` an optional subtitle**

In `Plotline/Views/Discovery/MediaSection.swift`, replace the stored properties,
the initialiser and the section header — that is, everything from
`let title: String` through the closing brace of the header `HStack` and its
`.padding(.horizontal)`:

```swift
struct MediaSection: View {
    let title: String
    let subtitle: String?
    let items: [MediaItem]
    let style: MediaCard.CardStyle

    @Environment(\.navigationNamespace) private var namespace

    init(
        title: String,
        subtitle: String? = nil,
        items: [MediaItem],
        style: MediaCard.CardStyle = .poster
    ) {
        self.title = title
        self.subtitle = subtitle
        self.items = items
        self.style = style
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header. The subtitle explains the shelf, so it renders
            // above the shelf. It used to sit under the poster row, where the
            // explanation arrived after the thing being explained.
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(.title2, weight: .bold))
                    .foregroundStyle(.primary)

                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
```

The `HStack` that held the title existed only to carry a `Spacer()` and a
commented-out "See All" button; both go with it. The rest of the body — the
`if items.isEmpty` branch, the `ScrollView`, and the trailing accessibility
modifiers — is unchanged.

- [ ] **Step 2: Pass the shelf subtitle through**

In `Plotline/Views/Discovery/DiscoveryView.swift`, replace `curatedShelves`:

```swift
    @ViewBuilder
    private var curatedShelves: some View {
        ForEach(DatasetStore.shared.lists) { list in
            if let title = CuratedListCopy.title(for: list.id) {
                VStack(alignment: .leading, spacing: 0) {
                    MediaSection(
                        title: title,
                        subtitle: CuratedListCopy.subtitle(for: list.id),
                        items: DatasetStore.shared.entries(for: list).map(\.asMediaItem)
                    )
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel(title)
                .accessibilityHint(CuratedListCopy.subtitle(for: list.id) ?? "")
                .accessibilityIdentifier(AccessibilityAnchors.discoverShelf)
            }
        }
    }
```

Keep the wrapping `VStack` even though it now has one child. The four
accessibility modifiers are applied to it, not to `MediaSection`, which carries
its own `.accessibilityElement(children: .contain)` internally — collapsing the
two would change which label wins. `AccessibilityAnchors.discoverShelf` is read
by the cold-start UI suite and must stay on an element that always renders.

- [ ] **Step 3: Move the score component captions above their bars**

In `Plotline/Views/Detail/Analysis/PlotlineScoreCard.swift`, replace the
`component` function:

```swift
    private func component(_ name: String, value: Int, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(name)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(value)")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            // The caption explains the component, so it sits under the
            // component's name rather than under the bar it describes.
            Text(caption)
                .font(.caption2)
                .foregroundStyle(.secondary)

            ProgressView(value: Double(value), total: 100)
                .tint(Color.plotlineGold)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name): \(value) out of 100. \(caption)")
    }
```

The accessibility label is unchanged — it already reads name, then value, then
caption.

- [ ] **Step 4: Build and run the suite**

Run:

```bash
xcodebuild -project Plotline.xcodeproj -scheme Plotline \
  -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Expected: build succeeds, all tests pass. `ColdStartTests.everyShelfIsRenderable`
exercises the shelf copy and must stay green.

- [ ] **Step 5: Check both screens on device, in both appearances**

Launch as in Task 2, Step 5. On Discover, confirm each curated shelf reads
title → explanation → posters, with the explanation no longer stranded under
the poster row. On any series detail, confirm each Plotline Score component
reads name/value → explanation → bar.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "fix: render section subtitles under their titles, not under the content"
```

---

### Task 4: Delete the Standout Episodes section

**Files:**
- Delete: `Plotline/Views/Detail/Analysis/StandoutEpisodesView.swift`
- Delete: `PlotlineTests/StandoutCopyTests.swift`
- Modify: `Plotline/Views/Detail/Analysis/SeriesAnalysisSection.swift:14-19`
- Modify: `docs/app-review/app-review-notes.md:23` and `:28`
- Modify: `docs/app-review/app-store-description.md:54`, `:64` and `:95`

**Interfaces:**
- Consumes: nothing.
- Produces: nothing. `StandoutEpisodesView` and its two static copy constants
  cease to exist.

**Deliberately kept:** `SeriesAnalysis.essentialEpisodes` /
`.skippableEpisodes`, `SeriesAnalysisEngine.standoutEpisodes(from:)`,
`SeriesAnalysisEngineStandoutTests`, and the corresponding fields in
`Resources/PlotlineDataset.json`. `Models/SeriesAnalysis.swift` is symlinked
into `Tools/DatasetGenerator/`, so removing the fields would change the shared
contract and force a full regeneration of the 122-entry dataset over the TMDB
API. Do not touch them in this task.

- [ ] **Step 1: Stop rendering the section**

In `Plotline/Views/Detail/Analysis/SeriesAnalysisSection.swift`, replace:

```swift
        case .analyzed(let analysis):
            VStack(alignment: .leading, spacing: 16) {
                PlotlineScoreCard(score: analysis.score)
                SeriesVerdictsView(analysis: analysis)
                StandoutEpisodesView(analysis: analysis)
            }
```

with:

```swift
        case .analyzed(let analysis):
            VStack(alignment: .leading, spacing: 16) {
                PlotlineScoreCard(score: analysis.score)
                SeriesVerdictsView(analysis: analysis)
            }
```

- [ ] **Step 2: Delete the view and its copy test**

```bash
git rm Plotline/Views/Detail/Analysis/StandoutEpisodesView.swift \
       PlotlineTests/StandoutCopyTests.swift
```

`StandoutCopyTests` has two tests. One reads
`StandoutEpisodesView.weakestTitle`, which no longer compiles. The other
asserts that a "weak" episode in the bundled dataset still rates above 8 —
a guard on copy that is being removed with it. Both go.

- [ ] **Step 3: Correct the App Store review notes**

In `docs/app-review/app-review-notes.md`, delete this line from the numbered
list under step 2:

```
   - **Standout Episodes** — episodes rated far above or far below their own season's average, judged within each season so a high point of a weaker season still surfaces.
```

Then replace:

```
**Works with no network and no account.** 122 fully analysed series ship inside the app. Turn off Wi-Fi and cellular, install, and open any title from the Discover shelves — the score, the verdicts and the standout episodes are all there. There is no sign-up, no paywall and no account of any kind.
```

with:

```
**Works with no network and no account.** 122 fully analysed series ship inside the app. Turn off Wi-Fi and cellular, install, and open any title from the Discover shelves — the score and the verdicts are both there. There is no sign-up, no paywall and no account of any kind.
```

- [ ] **Step 4: Correct the App Store description**

In `docs/app-review/app-store-description.md`, delete this bullet and the blank
line that follows it:

```
• Standout episodes — the ones far above their own season, and the ones far below. Judged within each season, so a high point of a weaker year still shows up.
```

Replace:

```
122 fully analysed series ship inside the app. No account, no sign-up, no subscription. Open it on a plane and the scores, verdicts and standout episodes are all there.
```

with:

```
122 fully analysed series ship inside the app. No account, no sign-up, no subscription. Open it on a plane and the scores and the verdicts are there.
```

Replace:

```
Plotline now shows its analysis on every series screen: a Plotline Score with its three components, a decline point, consistency, opening and ending verdicts, and the standout episodes of each season — each with the episode ratings behind it.
```

with:

```
Plotline now shows its analysis on every series screen: a Plotline Score with its three components, a decline point, consistency, and opening and ending verdicts — each with the episode ratings behind it.
```

- [ ] **Step 5: Build and run the suite**

Run:

```bash
xcodebuild -project Plotline.xcodeproj -scheme Plotline \
  -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Expected: build succeeds; the suite passes with two fewer tests than before.
`SeriesAnalysisEngineStandoutTests` must still be present and green — the engine
was not touched.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "refactor: remove the Standout Episodes section and the copy describing it"
```

---

### Task 5: Delete Genre Evolution and Best Years

Both views average `vote_average` across TMDB's twenty highest-scoring movies
for each of the last 30–50 years. That produces a near-flat line, and the titles
claim more than the measurement supports — averaging twenty TMDB scores does not
identify the best years for film. Each also fires 30–50 concurrent requests per
open against a rate limit the rest of the app manages carefully.

**Files:**
- Delete: `Plotline/Views/Stats/GenreEvolutionView.swift`
- Delete: `Plotline/Views/Stats/BestYearsView.swift`
- Delete: `Plotline/ViewModels/GenreEvolutionViewModel.swift`
- Delete: `Plotline/ViewModels/BestYearsViewModel.swift`
- Modify: `Plotline/Views/Stats/TrendsView.swift:3-45`
- Modify: `docs/app-review/app-review-notes.md:26`
- Modify: `docs/app-review/app-store-description.md:71`

**Interfaces:**
- Consumes: nothing.
- Produces: nothing. `GenreEvolutionView`, `BestYearsView`,
  `GenreEvolutionViewModel`, `BestYearsViewModel`, `GenreYearPoint`,
  `YearRating`, `GenreEvolutionAccessibility` and `BestYearsAccessibility` all
  cease to exist. `TMDBService.discoverMovies` and `CuratedGenre` have other
  callers and stay.

- [ ] **Step 1: Delete the four files**

```bash
git rm Plotline/Views/Stats/GenreEvolutionView.swift \
       Plotline/Views/Stats/BestYearsView.swift \
       Plotline/ViewModels/GenreEvolutionViewModel.swift \
       Plotline/ViewModels/BestYearsViewModel.swift
```

- [ ] **Step 2: Drop the two cards from the Trends grid**

In `Plotline/Views/Stats/TrendsView.swift`, replace the doc comment's first
line and the whole of `body`:

```swift
/// Grid of links to the two trend explorer sub-features.
///
/// Rendered only inside `StatsView`, which supplies the scroll view, the
/// padding, the background and the navigation title. This view used to carry
/// its own copy of all four: the padding stacked with the parent's to 64pt,
/// which left too little room for a second column on any iPhone narrower than
/// 402pt, and the navigation title overrode "Stats" on the tab it lives in.
struct TrendsView: View {
    var body: some View {
        LazyVGrid(columns: GridItem.adaptiveColumns(minimumWidth: AdaptiveLayout.minimumColumnWidth), spacing: 16) {
            trendCard(
                icon: "chart.bar.xaxis.ascending",
                title: "Decade Battle",
                subtitle: "Compare eras head to head",
                color: .plotlinePrimary,
                destination: DecadeBattleView()
            )

            trendCard(
                icon: "square.stack.3d.up",
                title: "Franchise Tracker",
                subtitle: "Track franchise quality",
                color: .rottenGreen,
                destination: FranchiseTrackerView()
            )
        }
    }
```

`trendCard` itself, and everything below it, is unchanged. Its `color: .plotlinePrimary`
argument is corrected in Task 6 — leave it alone here so this task stays a pure
deletion.

- [ ] **Step 3: Correct the App Store review notes**

In `docs/app-review/app-review-notes.md`, replace:

```
3. Tap the **Stats** tab. Compare, Career Profiles and Trends all work on first launch with no saved data: side-by-side comparison of any two titles, a filmography analysis for any actor or director, and four trend explorers.
```

with:

```
3. Tap the **Stats** tab. Compare, Career Profiles and Trends all work on first launch with no saved data: side-by-side comparison of any two titles, a filmography analysis for any actor or director, and two trend explorers.
```

- [ ] **Step 4: Correct the App Store description**

In `docs/app-review/app-store-description.md`, replace:

```
• Trend explorers: genre evolution, best years, decade battles, franchise tracking
```

with:

```
• Trend explorers: decade battles and franchise tracking
```

- [ ] **Step 5: Build and run the suite**

Run:

```bash
xcodebuild -project Plotline.xcodeproj -scheme Plotline \
  -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Expected: build succeeds, all tests pass. If the compiler reports an unresolved
`YearRating` or `GenreYearPoint`, something outside these four files referenced
them — find it before committing.

- [ ] **Step 6: Check the grid still fills, on both devices**

Launch on iPhone 17 as in Task 2, Step 5, open Stats and scroll to Trends:
two cards, two columns, no stranded single column. Then build for iPad, which
is the device App Review used:

```bash
xcodebuild -project Plotline.xcodeproj -scheme Plotline \
  -destination 'platform=iOS Simulator,name=iPad Air 11-inch (M4)' -derivedDataPath build build
```

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "refactor: remove the Genre Evolution and Best Years trend explorers"
```

---

### Task 6: Replace the brand red with a theme-adaptive accent

`plotlinePrimary` (`#C40C0C`) tinted glyphs, chips and chart marks across the
app and read as an error state everywhere it appeared. It is replaced by
`Color.plotlineAccent`, which adapts to the appearance, under two rules:

1. Red on a **glyph, fill, chip background, swipe tint or chart mark** becomes
   `Color.plotlineAccent`.
2. Red on **body text** becomes `.primary` or `.secondary` — never the accent.

The one approved exception to rule 2 is the app's own brand type: the tab bar
tint colours the selected tab's label, and the "Plotline" wordmark is text drawn
in a gradient. Both take the accent.

**Files:**
- Create: `Plotline/Assets.xcassets/PlotlineAccent.colorset/Contents.json`
- Create: `PlotlineTests/AccentColorSourceTests.swift`
- Modify: `Plotline/Extensions/Color+Plotline.swift:18-20`
- Modify: 16 view and app files, listed in Step 4 and Step 5

**Interfaces:**
- Consumes: nothing.
- Produces: `Color.plotlineAccent` — generated by the asset catalog compiler
  from the colour set's name, exactly as `Color.plotlineCard` and
  `Color.plotlineBackground` already are. And
  `Color.plotlineAccentDeep: Color` — a static `#B33A00` declared in
  `Color+Plotline.swift`, for gradient start points only.

- [ ] **Step 1: Create the colour set**

Create `Plotline/Assets.xcassets/PlotlineAccent.colorset/Contents.json`:

```json
{
  "colors" : [
    {
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "alpha" : "1.000",
          "blue" : "0.000",
          "green" : "0.227",
          "red" : "0.702"
        }
      },
      "idiom" : "universal"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "dark"
        }
      ],
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "alpha" : "1.000",
          "blue" : "0.200",
          "green" : "0.478",
          "red" : "1.000"
        }
      },
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

That is `#B33A00` in light and `#FF7A33` in dark. Both sit deeper than
`plotlineSecondaryAccent` (`#FF6500`), which matters because the two appear side
by side in the Stats overview row.

- [ ] **Step 2: Declare the fixed gradient value and note the generated symbol**

In `Plotline/Extensions/Color+Plotline.swift`, replace:

```swift
    // MARK: - Adaptive Background Colors
    // Note: plotlineBackground, plotlineBlack, plotlineCard, plotlineSecondary
    // are auto-generated from Asset Catalog color sets
```

with:

```swift
    // MARK: - Adaptive Colors
    // Note: plotlineAccent, plotlineBackground, plotlineBlack, plotlineCard,
    // plotlineSecondary are auto-generated from Asset Catalog color sets

    /// Fixed deep orange for gradients that used to start at `plotlinePrimary`.
    ///
    /// `plotlineAccent` adapts to the appearance, and its dark value (#FF7A33)
    /// sits close enough to `plotlineSecondaryAccent` (#FF6500) that a ramp
    /// between the two collapses to a flat fill. Gradients take this fixed
    /// value instead, so they keep their range in both appearances.
    static let plotlineAccentDeep = Color(hex: "B33A00")
```

- [ ] **Step 3: Write the failing guard test**

Create `PlotlineTests/AccentColorSourceTests.swift`:

```swift
import Foundation
import Testing
@testable import Plotline

/// The brand red is out of the interface, and this keeps it out.
///
/// `plotlinePrimary` (#C40C0C) used to tint glyphs, chips and chart marks all
/// over the app, and read as an error state everywhere it appeared. It was
/// replaced by `plotlineAccent`, which adapts to light and dark. The red now
/// survives in exactly one role: as the value behind `chartLow`, the low end of
/// the episode rating scale, where it is drawn as a mark with white numerals on
/// top of it and never as text.
///
/// Nothing in a rendered SwiftUI tree can assert that, so this suite reads the
/// view sources from disk — the same technique, and for the same reason, as
/// `WatchAttributionSourceTests`.
@Suite("The brand red stays out of the views")
struct AccentColorSourceTests {
    /// Every symbol that resolves to #C40C0C. `chartLow` is deliberately
    /// absent: it is how the rating scale names its low end.
    private static let forbidden = ["plotlinePrimary", "rottenRed", "metacriticRed"]

    private static let scannedDirectories = ["Plotline/Views", "Plotline/App"]

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // PlotlineTests/
            .deletingLastPathComponent()   // repo root
    }

    private static func swiftFiles() -> [URL] {
        scannedDirectories.flatMap { directory -> [URL] in
            let root = repoRoot.appendingPathComponent(directory)
            guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else {
                return []
            }
            return walker.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
        }
    }

    @Test("no view or app file reaches for the brand red")
    func viewsDoNotUseTheBrandRed() throws {
        let files = Self.swiftFiles()

        // A source scan that finds nothing passes for the wrong reason. There
        // are around 49 files under these two directories.
        #expect(
            files.count > 40,
            "the scan found \(files.count) Swift files, which means the paths are wrong rather than that the app shrank"
        )

        var offenders: [String] = []
        for file in files {
            let source = try String(contentsOf: file, encoding: .utf8)
            for symbol in Self.forbidden where source.contains(symbol) {
                offenders.append("\(file.lastPathComponent) uses \(symbol)")
            }
        }

        #expect(
            offenders.isEmpty,
            "the brand red is meant to survive only as chartLow, the low end of the rating scale: \(offenders.joined(separator: ", "))"
        )
    }
}
```

- [ ] **Step 4: Run the test and watch it fail**

Run:

```bash
xcodebuild -project Plotline.xcodeproj -scheme Plotline \
  -destination 'platform=iOS Simulator,name=iPhone 17' test 2>&1 | grep -A 3 "brand red"
```

Expected: FAIL, listing every file in the table below. If it passes at this
point, the scan is not finding the sources — fix `scannedDirectories` before
going further, because a vacuous pass is worse than no test.

- [ ] **Step 5: Apply rule 1 — red on glyphs, fills and marks**

Replace `Color.plotlinePrimary` / `.plotlinePrimary` with `Color.plotlineAccent`
/ `.plotlineAccent` in each of these, and `Color.rottenRed` with
`Color.plotlineAccent` in `BoxOfficeView`'s revenue `MetricBar`.

**The line numbers below are as of the start of this plan.** Tasks 1, 2 and 5
edit `MediaDetailView.swift` and `TrendsView.swift`, so those two will have
moved. Locate each site by symbol rather than by line:

```bash
grep -rn "plotlinePrimary\|rottenRed\|metacriticRed" Plotline/Views Plotline/App --include="*.swift"
```

That list and the table below should agree; if the grep turns up a site the
table does not name, decide it against rules 1 and 2 rather than skipping it.

| File | Line | What it colours |
|---|---|---|
| `Plotline/Views/Stats/TrendsView.swift` | 33 | Decade Battle glyph and circle |
| `Plotline/Views/Settings/SettingsView.swift` | 79 | selected-theme checkmark |
| `Plotline/Views/Favorites/FavoritesView.swift` | 95 | sort menu glyph |
| `Plotline/Views/Favorites/WatchlistView.swift` | 152 | sort menu glyph |
| `Plotline/Views/Favorites/WatchlistView.swift` | 118 | leading swipe action tint |
| `Plotline/Views/Discovery/GenreResultsView.swift` | 105 | sort menu glyph |
| `Plotline/Views/Detail/MediaDetailView.swift` | 201 | watchlist toolbar glyph when saved |
| `Plotline/App/ThemeManager.swift` | 29 | dark-appearance moon glyph |
| `Plotline/Views/Stats/StatsView.swift` | 175 | Favorites `StatCard` glyph + 15% circle |
| `Plotline/Views/Stats/StatsView.swift` | 412 | Favorites rating pill background + border |
| `Plotline/Views/Stats/StatCard.swift` | 39 | `#Preview` argument |
| `Plotline/Views/Stats/CareerProfileView.swift` | 239 | "Worst Rated" glyph + 10% background |
| `Plotline/Views/Stats/RatingComparisonBar.swift` | 10 | third comparison slot's bar |
| `Plotline/Views/Stats/CompareView.swift` | 140 | third chart line |
| `Plotline/Views/Stats/GenreDNAChart.swift` | 16 | third donut sector and legend swatch |
| `Plotline/Views/Detail/SeriesGraphView.swift` | 417 | third season's line colour |
| `Plotline/Views/Detail/MovieFeatures/BoxOfficeView.swift` | 31 | revenue bar fill when unprofitable |
| `Plotline/Views/MainTabView.swift` | 41 | tab bar tint (the rule 2 exception) |

`StatCard`, `CareerProfileView.quickStatItem` and `StatsView.ratingPill` each
apply their `color` only to a glyph and a tinted background — their value and
label text is already `.primary` / `.secondary`, so rule 2 needs nothing there.

Do **not** change: `chartLow` in `SeriesGraphView:301`, `ratingBad` in
`EpisodeRatingsGridView:18`, the `"0-2"` case in `StatsView.barColor:462`, the
`role: .destructive` swipe button in `WatchlistView:121`, or the system `.red`
heart in `MediaDetailView:146`.

- [ ] **Step 6: Apply rule 1a — gradients take the fixed value**

In `Plotline/Views/Components/AnimatedGradientText.swift`, replace:

```swift
    // Gradient colors - gold (brightest) in center, surrounded by darker colors
    private let gradientColors: [Color] = [
        .plotlinePrimary,
        .plotlineSecondaryAccent,
        .plotlineGold,
        .plotlineSecondaryAccent,
        .plotlinePrimary
    ]
```

with:

```swift
    // Gradient colors - gold (brightest) in center, surrounded by darker colors.
    // The ends take the fixed deep orange rather than the adaptive accent: in
    // dark mode the accent (#FF7A33) is close enough to plotlineSecondaryAccent
    // (#FF6500) that the ramp would collapse.
    private let gradientColors: [Color] = [
        .plotlineAccentDeep,
        .plotlineSecondaryAccent,
        .plotlineGold,
        .plotlineSecondaryAccent,
        .plotlineAccentDeep
    ]
```

Also update the stale comment inside `body`, which says the text shows red at
the ends:

```swift
                        // Gradient is 2 units wide, moves 3 units total
                        // Starts off-screen left (text shows deep orange), gold
                        // sweeps through, ends off-screen right (deep orange again)
```

In `Plotline/Views/Discovery/DiscoveryView.swift`, in `GenreBrowseCard`,
replace:

```swift
                            colors: [Color.plotlinePrimary, Color.plotlineSecondaryAccent],
```

with:

```swift
                            colors: [Color.plotlineAccentDeep, Color.plotlineSecondaryAccent],
```

- [ ] **Step 7: Apply rule 2 — red on text becomes neutral**

In `Plotline/Views/Detail/MovieFeatures/BoxOfficeView.swift`, replace both
occurrences of:

```swift
                        .foregroundStyle(boxOffice.isProfitable ? Color.rottenGreen : Color.rottenRed)
```

with:

```swift
                        .foregroundStyle(boxOffice.isProfitable ? Color.rottenGreen : .primary)
```

Note the indentation differs between the two sites — line 51 sits inside the
ROI `HStack`, line 66 modifies the profit `Text` directly. Match each one's
existing indentation. The direction is still carried by the
`arrow.up.right` / `arrow.down.right` glyph, so nothing is lost.

In `Plotline/Views/Favorites/WatchlistView.swift`, replace:

```swift
                        .foregroundStyle(item.watchStatus == "watched" ? .green : Color.plotlinePrimary)
```

with:

```swift
                        .foregroundStyle(item.watchStatus == "watched" ? .green : .secondary)
```

- [ ] **Step 8: Run the test and watch it pass**

Run:

```bash
xcodebuild -project Plotline.xcodeproj -scheme Plotline \
  -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Expected: PASS, including `AccentColorSourceTests`. If it still fails, the
message names the file and symbol it found; work through the list.

- [ ] **Step 9: Check the colour on screen, in both appearances**

Launch as in Task 2, Step 5. This step is the point of the whole task, so do not
skip it: an asset-catalog colour that is wrong in one appearance compiles and
tests clean.

Check in **light** and then in **dark** (Settings → Appearance):

1. Tab bar — the selected tab's icon and label.
2. Discover — the animated "Plotline" wordmark still ramps through gold rather
   than reading as one flat orange, and the Genre Browse card's circle likewise.
3. Stats — overview cards (Favorites next to Watchlist: the two oranges must
   stay distinguishable), rating pills, the Trends grid, Genre DNA legend.
4. Detail — watchlist toolbar glyph when saved, Box Office on an unprofitable
   film (values in `.primary`, arrow pointing down), the episode grid legend
   with its red "Bad" swatch deliberately unchanged.
5. Watchlist — the sort glyph, a "want to watch" row's status label in
   `.secondary`, and swipe left to confirm the toggle action's tint.

- [ ] **Step 10: Commit**

```bash
git add -A
git commit -m "style: replace the brand red with a theme-adaptive accent"
```

---

### Task 7: Reconcile the recorded test counts and run the release gates

Tasks 4 and 6 changed how many tests exist. `CLAUDE.md` records that number in
two places, and `Scripts/release-preflight.sh` is the standing check that
everything a release depends on still holds.

**Files:**
- Modify: `CLAUDE.md` — the "Run tests" comment under Build Commands

**Interfaces:**
- Consumes: the final test count, observed in Step 1.
- Produces: nothing.

- [ ] **Step 1: Count what actually exists**

Run:

```bash
grep -rc "@Test" PlotlineTests/*.swift | awk -F: '{s+=$2} END {print "test functions:", s}'
```

Expected: **146** — 147 today, minus two from the deleted `StandoutCopyTests`,
plus one from `AccentColorSourceTests`. Two of them are parameterised, so the
case count is **150**.

If the number differs, use the observed one. The point of this step is that
`CLAUDE.md` matches reality, not that it matches this plan.

- [ ] **Step 2: Update `CLAUDE.md`**

Replace:

```markdown
# Run tests — 147 Swift Testing functions, 151 cases (two are parameterised),
# plus the 7-method cold-start UI suite, which runs starved of a TMDB key
```

with the observed numbers:

```markdown
# Run tests — 146 Swift Testing functions, 150 cases (two are parameterised),
# plus the 7-method cold-start UI suite, which runs starved of a TMDB key
```

- [ ] **Step 3: Run the generator's own suite**

`xcodebuild test` never runs it, and nothing in this plan touched the engine —
which is exactly why it is worth confirming.

```bash
cd Tools/DatasetGenerator && swift test && cd ../..
```

Expected: PASS. `ShippedDatasetTests` still opens
`Plotline/Resources/PlotlineDataset.json` and asserts its cross-list invariants;
the standout fields are still in that file by design.

- [ ] **Step 4: Run the release preflight**

```bash
./Scripts/release-preflight.sh
```

Expected: every check passes, including the coherence check between
`MARKETING_VERSION` and `docs/app-review/` — Tasks 4 and 5 edited files in that
directory, and the version string must still appear in at least one of them.

- [ ] **Step 5: Build for iPad**

```bash
xcodebuild -project Plotline.xcodeproj -scheme Plotline \
  -destination 'platform=iOS Simulator,name=iPad Air 11-inch (M4)' -derivedDataPath build build
```

Expected: build succeeds. iPad is the device App Review used; nothing in this
plan may make it worse.

- [ ] **Step 6: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: bring the recorded test counts back in line with the suite"
```

---

## What this plan deliberately does not do

Recorded so a reviewer does not read them as oversights:

1. **The standout episode data stays** in `SeriesAnalysis`, the engine, the
   engine's tests and the bundled dataset. Only the UI and its copy test go.
2. **The rating in the metadata row is not tappable** and has no chevron.
3. **The two gradients take a fixed deep orange**, not the adaptive accent, so
   their ramp survives dark mode.
4. **The episode rating scale keeps its red** — there it encodes a low rating,
   is legend-backed, and is drawn as a mark with white numerals on top rather
   than as text.
5. **`MediaHeaderView` and `ParallaxHeaderView`** in
   `Plotline/Views/Detail/MediaHeaderView.swift` are unreferenced dead code that
   predates this work. `MediaHeaderView` also renders a rating in its own title
   overlay, which will look inconsistent with Task 2 if it is ever revived.
   Deleting it is out of scope here; worth its own commit.
6. **The app has no on-screen TMDB attribution.** The statement lives in
   `docs/app-review/app-store-description.md:79` only. Task 2 keeps the word
   "TMDB" beside the score, so this is no worse than before, but it is a real
   gap and deserves its own task.
