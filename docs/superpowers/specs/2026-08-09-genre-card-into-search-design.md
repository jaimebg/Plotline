# Browse by Genre moves into the search state — Design

**Date:** 2026-08-09
**Status:** implemented

`GenreBrowseCard` was pinned to the top of Discover's feed, above the curated
shelves, on every launch. It was the first thing between the reviewer and
Plotline's own analysis, and it was a signpost rather than content — a card whose
whole job was to say "there is a grid of genres one tap away".

The genres move to where that belongs: the search screen, before the user has
typed anything, as the grid itself rather than a card pointing at it. Discover's
feed now opens on the curated shelves.

Nothing here changes the analysis engine, the dataset, what the app claims about
a series, or the genre cards themselves.

---

## 1. Detecting that search is active

`DiscoveryView` gains `@State private var isSearchPresented = false`, passed to
`.searchable(text:isPresented:prompt:)` (iOS 17+). Apple's contract: the value
becomes `true` when the user first taps the search field and `false` when they
cancel.

`@Environment(\.isSearching)` reports the same thing, but it is only readable
from a view *below* the one carrying the `searchable` modifier. `content` is a
computed property inside `DiscoveryView`, so reading it there would mean
extracting the whole content tree into its own `struct` and threading three view
models, the namespace and a binding through the initialiser. The binding buys the
same signal for one line.

## 2. The grid renders inline, and three things go away

`GenreGrid` (renamed from `GenreBrowseView.swift`, which held the same grid as a
pushed screen) is now a reusable view taking `genres` and an `onSelect` closure.
Discover's empty-search state renders it under a "Browse by Genre" heading.

With the grid inline, nothing reached the old indirection, so it is deleted:
`GenreBrowseCard`, the `GenreBrowseView` screen, and the `DiscoveryRoute` enum
with its `.navigationDestination`. `GenreCard` and the colour palette are
unchanged. `.navigationDestination(for: CuratedGenre.self)` stays — that is what
a selected genre pushes.

## 3. `content` has three branches

| Search field | Query | Renders |
| --- | --- | --- |
| idle | empty | `mainContentView` — curated shelves, then network sections |
| active | empty | `searchIdleView` — the genre grid |
| either | non-empty | `searchResultsView` — skeleton → results or "No Results" |

**The condition is `isSearchPresented || viewModel.isSearchActive`, not
`isSearchPresented` alone.** The deep-link handler writes `viewModel.searchText`
and calls `search()` without ever presenting the search field. Gating on the
binding alone would land a deep-linked search on the main feed with results it
never shows. The second term keeps every non-empty query behaving exactly as it
did; the binding only decides what an *empty* query looks like.

## 4. The iPad push, and how it was found

Selecting a genre from the search state did nothing on iPad. The cause was
established by measurement, and the sequence is worth keeping because three
plausible readings were each wrong:

- The button is **hittable and its action fires** — an action writing to
  `searchText` instead of navigating produced its change on screen. So the tap
  was never the problem.
- Pushing the **same `CuratedGenre` from the feed works** on iPad, so neither the
  destination registration nor `NavigationPath` is at fault.
- Tapping a search **result** pushes on iPad. The difference is that a non-empty
  query keeps that branch mounted; an empty one does not.

Three fixes were tried against the wrong model and all failed: replacing the
`NavigationLink` with a path append, wrapping the branches in a stable `ZStack`,
and holding the search branch mounted for the life of the push. What they ruled
out is that the branch swap matters at all.

What is actually happening: on iPad the tap collapses the tab-bar search field,
and a push issued while that collapse is in flight is lost. The entry stays in
`navigationPath` — a retry guarded on `navigationPath.isEmpty` never fires,
which is how this was pinned down — but the stack never renders it.

`DiscoveryView.pushAfterSearchCloses(_:)` therefore pushes **once, after the
collapse**. 300ms was measured as too short and 600ms as enough. iPhone keeps its
field inline, has no collapse to wait for, and pushes immediately; the idiom
check exists so the primary device never pays for the iPad workaround.

## Verification

- Full suite on iPhone 17: 7/7 UI tests and the Swift Testing suite green.
  `ColdStartUITests` requires a clean container — uninstall by name against a
  **booted** device, or `testContainerIsClean` and three others fail on leftover
  saved data rather than on anything in the code.
- Genre selection from search pushes its results on **iPhone 17** and on **iPad
  Air 11-inch (M4)**, each confirmed by a temporary UI test that has since been
  removed.

## Not covered by a test

No permanent test guards the iPad ordering. It took several wrong models to find
and would regress silently — a UI test tapping search, tapping a genre, and
asserting the push would catch it, at the cost of one more slow UI test in the
default plan.

## Assumptions carried into implementation

- The empty-search screen shows the genre grid and nothing else. No recent
  searches, no suggestions.
- `GenreResultsView` remains reachable only by selecting a genre from that grid.
