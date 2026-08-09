# Browse by Genre moves into the search state — Design

**Date:** 2026-08-09
**Status:** approved for planning

`GenreBrowseCard` is pinned to the top of Discover's feed, above the curated
shelves, on every launch. It is the first thing between the reviewer and
Plotline's own analysis, and it is a signpost rather than content — a card whose
whole job is to say "there is a grid of genres one tap away".

It moves to where a signpost belongs: the search screen, before the user has
typed anything. Discover's feed then opens on the curated shelves.

Nothing here changes the analysis engine, the dataset, what the app claims about
a series, or the genre grid itself.

---

## 1. Detecting that search is active

`DiscoveryView` gains `@State private var isSearchPresented = false` and passes
it to `.searchable(text:isPresented:prompt:)` (iOS 17+). Apple's contract:
the value becomes `true` when the user first taps the search field and `false`
when they cancel.

`@Environment(\.isSearching)` reports the same thing and is the more obvious
reach, but it is only readable from a view *below* the one carrying the
`searchable` modifier. `content` is a computed property inside `DiscoveryView`,
so reading it there would mean extracting the whole content tree into its own
`struct` and threading `viewModel`, `tasteProfileVM`, `smartListsVM`, the
`namespace` and the `showWhatToWatch` binding through the initialiser. The
binding buys the same signal for one line.

## 2. The card moves

`Plotline/Views/Discovery/DiscoveryView.swift`

- Delete the `NavigationLink(value: DiscoveryRoute.genreBrowse)` block and its
  `.buttonStyle(.plain)` / `.padding(.horizontal)` from `mainContentView`, so
  that view begins with `curatedShelves`.
- Add `searchIdleView`: a `ScrollView` holding the same `NavigationLink`, same
  `GenreBrowseCard`, same modifiers, `.padding()` to match `searchResultsView`.
- `GenreBrowseCard`, `DiscoveryRoute.genreBrowse`, the `.navigationDestination`
  and `GenreBrowseView` are untouched. The card keeps its accessibility label
  and `.isButton` trait.

## 3. `content` becomes three branches

```
if isSearchPresented || viewModel.isSearchActive {
    if viewModel.isSearchActive { searchResultsView } else { searchIdleView }
} else {
    mainContentView
}
```

| Search field | Query | Renders |
| --- | --- | --- |
| idle | empty | `mainContentView` — curated shelves, then network sections |
| active | empty | `searchIdleView` — the Browse by Genre card |
| either | non-empty | `searchResultsView` — skeleton → results or "No Results" |

**The condition is `isSearchPresented || viewModel.isSearchActive`, not
`isSearchPresented` alone.** The deep-link handler (`DiscoveryView.swift:82-88`)
writes `viewModel.searchText` and calls `search()` without ever presenting the
search field. Gating on the binding alone would land a deep-linked search on the
main feed with results it never shows. The second term keeps every non-empty
query behaving exactly as it does today; the binding only decides what an
*empty* query looks like.

## 4. The comment at `DiscoveryView.swift:108-110`

> Needs no network, no API key and no saved data, so it must never sit behind a
> fetch that can fail. An empty screen behind an error is what got this app
> rejected.

It explains a placement that will no longer exist, so it goes with the block it
annotates. The claim it makes stays true of the new placement — the search-empty
state is local, reached without a request — but it is no longer the reason the
first screen survives a failed fetch. `curatedShelves` is, and it renders from
the bundled dataset above `networkSections` either way.

---

## Verification

- `xcodebuild ... -destination 'platform=iOS Simulator,name=iPhone 17' test` —
  the full Swift Testing suite plus `ColdStartUITests`, unchanged.
- Run on **iPhone 17** and on **iPad Air 11-inch (M4)**: launch, confirm Discover
  opens on a curated shelf with no genre card; tap the search field, confirm the
  card appears; tap it, confirm the grid pushes; cancel search, confirm the feed
  returns.

**The iPad run is the one that can fail.** Under `.sidebarAdaptable` the search
field can sit permanently in the toolbar, and if `isPresented` never flips there,
the card becomes unreachable on iPad rather than merely relocated. If that
happens, fall back to §1's rejected option: extract the content tree into a child
view and read `@Environment(\.isSearching)`.

## No test changes

Nothing in `ColdStartUITests`, `UITestAnchors` or the Swift Testing suites
references `GenreBrowseCard`, `DiscoveryRoute` or the card's accessibility label
— a grep across `PlotlineTests/` and `PlotlineUITests/` returns nothing. The card
carries no accessibility identifier, only a label.

`testDiscoverShowsCuratedShelves` already asserts what removing the card from the
feed could plausibly break: that Discover's first screen renders at least two
curated shelves with no TMDB key. That assertion gets stronger here, not weaker,
since the shelves move up to where the card was.

## Assumptions carried into implementation

- The empty-search screen shows the card and nothing else. No recent searches, no
  suggestions, no inline genre grid — those were considered and declined; the
  chosen shape is the existing card, relocated.
- `GenreBrowseView` remains reachable only through this card. It is not promoted
  to a tab or a toolbar item.
