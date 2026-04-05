# Plotline — Data Nerd Edition

**Date:** 2026-04-05
**Goal:** Pass App Store Guideline 4.2 by adding substantial analytical, comparative, and personalization features that provide unique value beyond API data browsing.
**Approach:** Expand Stats tab into an analytics hub, add smart personalization to Discovery. Remove Daily Pick and all widgets.

---

## Destructive Changes

### Remove Daily Pick
- Delete `DailyPickView`, `DailyPickViewModel`
- Remove UserDefaults cache keys (`dailyPickCache`, `dailyPickDate`)
- Remove Daily Pick section from Discovery tab
- Remove any references in `DiscoveryView`/`DiscoveryViewModel`

### Remove Widgets
- Delete the entire Widget extension target
- Remove WidgetKit dependencies from the project
- Remove shared app group data writing logic (widget data updates in `DiscoveryViewModel` and anywhere else)
- Remove widget-related URL scheme handling in deep links
- Keep Siri integration (not widget-dependent)

---

## Feature 1: Stats Tab → "Stats & Insights"

### Current State
Stats tab has a vertical scroll with: overview cards, movies vs series donut, rating distribution histogram, 12-week activity timeline, top 10 genres, average ratings.

### New Structure
Vertical scroll with 4 sections, each with a header. "My Stats" is inline (always visible). The other three show a compact preview card that navigates to a full-screen view.

1. **My Stats** — existing content, unchanged
2. **Compare** — preview card: "Compare movies & series side by side" with an icon and CTA. Taps to `CompareView`.
3. **Career Profiles** — search bar for people + horizontal scroll of recently viewed profiles. Taps to `CareerProfileView`.
4. **Trends** — 2x2 grid of cards (Genre Evolution, Best Years, Decade Battle, Franchise Tracker). Each taps to its respective sub-view.

### Data
No new data requirements. Section is organizational only.

### ViewModel Changes
`StatsViewModel` — add a `recentProfiles` array persisted to UserDefaults (just person IDs + names + photo paths, max 10). No other changes.

---

## Feature 2: Visual Comparator

### Access Points
- From Stats > Compare section
- From MediaDetailView via a "Compare" button (adds the current title to slot 1, navigates to CompareView)

### User Flow
1. CompareView shows 2-3 empty slots (rounded rect placeholders with "+" icon)
2. Tap a slot → search sheet (reuses existing search logic from `DiscoveryViewModel`)
3. Select a title → slot fills with poster thumbnail and title
4. When ≥2 slots filled, comparison renders below
5. Tap a filled slot to replace it. Swipe to remove.

### Comparison Sections (vertical scroll)

#### Header
- Posters side by side (equal width columns)
- Title, year, media type badge below each

#### Ratings Comparison
- One row per source: TMDB, IMDb, Rotten Tomatoes, Metacritic
- Horizontal bars with the score value at the end
- Color per source (reuse existing rating colors)
- If a title lacks a source, show "N/A" grayed out

#### Box Office (movies only, hidden if no movie selected)
- Budget bars side by side
- Revenue bars side by side
- ROI percentage displayed

#### Awards (movies only, hidden if no movie selected)
- Wins vs nominations as grouped bars

#### Metadata
- Runtime comparison
- Genre chips: shared genres highlighted, unique genres dimmed
- Original language

#### Series Episode Trends (series only, hidden if no series selected)
- Single Swift Charts LineChart with one line per series (different colors)
- X axis: episode number (sequential across seasons)
- Y axis: IMDb rating
- Legend with series names and colors
- Season divider vertical rules

### Data
- TMDB details + OMDb ratings (already fetched by `MediaDetailViewModel`)
- For series episode overlay: batch fetch all seasons per series (existing logic in `MediaDetailViewModel.fetchAllSeasonsEpisodes`)
- Fetch on selection, cache in ViewModel for the session

### New Files
- `CompareView.swift` — main comparison screen
- `CompareViewModel.swift` — manages slots, fetches data, computes comparison sections
- `ComparisonSlotView.swift` — individual slot component (empty/filled states)
- `RatingComparisonBar.swift` — horizontal bar component for rating rows

---

## Feature 3: Career Profiles

### Access Points
- From Stats > Career Profiles section (search or recent)
- From MediaDetailView credits — tap on any actor or director name

### Profile Screen (vertical scroll)

#### Header
- Profile photo (TMDB `profile_path`), name, birth date/age, place of birth
- Biography text (collapsible, 3 lines default)

#### Career Score
- Weighted average of all their titles' `vote_average` from TMDB (weighted by `vote_count`)
- Displayed as a large number with a circular progress indicator

#### Career Timeline (Swift Charts)
- LineMark: X = year, Y = average rating of titles released that year
- PointMark on each year with ≥1 title
- Color gradient from low to high
- Tap on a point to see titles from that year in a popover/sheet

#### Top 10
- Horizontal scroll of MediaCards (existing component) showing their 10 highest-rated titles

#### Genre DNA
- Donut chart (Swift Charts SectorMark) showing genre distribution across their filmography
- Tap a sector to see titles in that genre

#### Quick Stats
- Total titles
- Most active decade
- Most frequent genre
- Best rated title (name + score)
- Worst rated title (name + score)

#### Filmography
- Full list grouped by decade (section headers: "2020s", "2010s", etc.)
- Each row: mini poster, title, year, rating badge
- Segmented picker filter: All / Movies / Series
- Sorted by year descending within each decade

#### Director Bonus: Box Office Track Record
- Only shown for directors
- Cumulative and average box office revenue across their directed films
- Bar chart of revenue per film (where data available)

### Data
- `TMDBService` — person details (`/person/{id}`), person combined credits (`/person/{id}/combined_credits`)
- Box office data for directors: individual movie details (already available)
- All TMDB endpoints, no new API integration needed

### New Files
- `CareerProfileView.swift` — main profile screen
- `CareerProfileViewModel.swift` — fetches person data, computes career stats, timeline, genre distribution
- `CareerTimelineChart.swift` — Swift Charts career timeline component
- `GenreDNAChart.swift` — donut chart component

---

## Feature 4: Trend Explorer

### Access Point
From Stats > Trends section (2x2 grid of cards).

### 4a. Genre Evolution

**Screen:** Genre picker at top (horizontal chips), line chart below.

**Chart:** LineMark with X = year (last 50 years), Y = average vote_average of top 20 movies per year in that genre.

**Data:** TMDB discover endpoint: `/discover/movie?with_genres={id}&primary_release_year={year}&sort_by=vote_count.desc&vote_count.gte=100` — iterate per year. Cache results in memory.

**Optimization:** Fetch in batches. Show loading skeleton per year range. Limit to decades if performance is an issue (5 points per decade instead of 50 per year).

### 4b. Best Years

**Screen:** Segmented picker for genre filter (All + top genres), bar chart below.

**Chart:** BarMark with X = year, Y = average rating. Highlight the best year. Show top 30 years.

**Data:** Same discover endpoint, aggregated differently. For "All": use top rated movies per year regardless of genre.

### 4c. Decade Battle

**Screen:** Grouped bar chart comparing decades (1970s through 2020s).

**Metrics per decade:**
- Average rating of top 50 movies
- Count of movies with rating ≥ 8.0
- Dominant genre (most frequent in top 50)

**Chart:** Grouped BarMark with decade on X, colored bars per metric.

**Data:** TMDB discover with `primary_release_date.gte` and `.lte` for decade ranges.

### 4d. Franchise Tracker

**Screen:** Search/browse for a franchise (TMDB collections). Line chart of the franchise.

**Chart:** LineMark with X = movie title (chronological), Y = rating. PointMark with labels.

**Data:** TMDB collection endpoint (`/collection/{id}`) — already used for `FranchiseTimelineView`. Reuse existing logic from `MediaDetailViewModel`. Extend to allow standalone search for collections.

**Collection Search:** TMDB `/search/collection?query=` endpoint. New addition to `TMDBService`.

### New Files
- `TrendsView.swift` — main view with 2x2 card grid
- `GenreEvolutionView.swift` + `GenreEvolutionViewModel.swift`
- `BestYearsView.swift` + `BestYearsViewModel.swift`
- `DecadeBattleView.swift` + `DecadeBattleViewModel.swift`
- `FranchiseTrackerView.swift` + `FranchiseTrackerViewModel.swift`

### API Rate Limiting
Trend views make many sequential API calls. Mitigation:
- Fetch with concurrency limit (max 5 concurrent requests via TaskGroup)
- Cache all results in-memory per session
- Show progressive loading (chart builds as data arrives)
- Use `vote_count.gte=100` to reduce noise and API abuse

---

## Feature 5: Taste Profile

### Access Point
New card in Discovery tab (first section if user has ≥5 favorites). Taps to full `TasteProfileView`.

### Preview Card (in Discovery)
Compact card showing top 3 genre icons and the primary taste tag. "See your full taste profile →"

### Full Taste Profile Screen

#### Top 3 Genres
- Genre name, percentage, horizontal progress bar
- Calculated from genre frequency across all FavoriteItems

#### Favorite Director & Actor
- Most frequently appearing director/actor across favorites
- Show name + photo + count ("appears in 7 of your favorites")
- Requires: for each FavoriteItem, fetch credits from TMDB (cache aggressively)

#### Rating Sweet Spot
- Interquartile range (25th–75th percentile) of ratings from favorites
- Display as a range bar on a 1-10 scale with the range highlighted

#### Preferred Era
- Decade with most favorites
- Show as "You're a 90s cinephile" or similar label

#### Taste Tags
Generated from rules:
- "Thriller Lover" — if >30% of favorites are thriller genre
- "90s Kid" / "2000s Native" / etc. — based on preferred era
- "Auteur Fan" — if any director appears 3+ times in favorites
- "Binge Watcher" — if >50% of favorites are TV series
- "Blockbuster Fan" — if average popularity score of favorites is in top quartile
- "Hidden Gem Hunter" — if average popularity score is in bottom quartile
- "Rating Snob" — if average rating of favorites is >8.0
- "Genre Hopper" — if no genre exceeds 25% of favorites
- Max 4 tags displayed, most relevant first (highest percentage/score)

#### Movies vs Series Ratio
- Reuse donut chart logic from StatsViewModel

### Data
- All computed from local SwiftData (FavoriteItems + WatchlistItems)
- Director/actor frequency requires TMDB credits per favorite — fetch lazily on profile open, cache in UserDefaults (just person ID + name + count per favorite)
- Recalculated each time the profile is opened

### Minimum Threshold
- Less than 5 favorites: show motivational empty state ("Add 5 favorites to unlock your Taste Profile")

### New Files
- `TasteProfileView.swift` — full profile screen
- `TasteProfileCard.swift` — compact preview for Discovery
- `TasteProfileViewModel.swift` — computes all taste metrics from local data
- `TasteTag.swift` — model for taste tags with rules engine

---

## Feature 6: "What Should I Watch?"

### Access Point
Prominent button/card in Discovery, below the Taste Profile card.

### User Flow (3-step interactive sheet)

#### Step 1: Mood Selection
Full-screen sheet with mood chips (multi-select allowed, max 2):
- "Something Light" → Comedy, Animation, Family
- "Mind-Bending" → Sci-Fi, Mystery, Thriller (rating ≥ 7.5)
- "Emotional" → Drama, Romance
- "Action-Packed" → Action, Adventure
- "Critically Acclaimed" → Any genre, rating ≥ 8.0, vote_count ≥ 1000
- "Hidden Gem" → Any genre, rating ≥ 7.0, vote_count between 100–1000

#### Step 2: Time
Two large buttons:
- "Movie (~2h)" → filters to movies
- "Start a Series" → filters to TV series

#### Step 3: Results
- 3 recommendation cards with poster, title, year, rating, and a "why" line
- "Why" line is generated from matching criteria: "Matches your love for thrillers + critically acclaimed" (composed from mood + taste profile overlap)
- "Shuffle" button to re-fetch with same filters
- Tap a card → navigate to MediaDetailView
- "Add to Watchlist" button on each card

### Algorithm
1. Map mood selections to TMDB genre IDs and filter parameters
2. Cross-reference with user's taste profile top genres (boost matching genres in sort)
3. Call TMDB discover with combined filters, sorted by vote_average
4. Filter out titles already in favorites or watchlist (local check)
5. Take top 20 results, randomly pick 3 (for variety on shuffle)

### Data
- TMDB discover endpoint with genre + rating + vote_count filters
- Local SwiftData for exclusion list
- TasteProfile data for genre boosting

### New Files
- `WhatToWatchView.swift` — 3-step flow container
- `MoodSelectionView.swift` — mood chip selector
- `WhatToWatchViewModel.swift` — manages flow state, builds query, fetches results
- `MoodFilter.swift` — model mapping moods to API parameters
- `RecommendationCard.swift` — result card with "why" line

---

## Feature 7: Smart Lists

### Access Point
New sections in Discovery, below "What Should I Watch?" button, above the existing trending sections.

### Lists (horizontal scroll sections, like existing trending)

#### "Because you liked [Title]"
- Pick a random FavoriteItem
- Fetch TMDB recommendations for it (`/movie/{id}/recommendations` or `/tv/{id}/recommendations`)
- Filter out items already in favorites/watchlist
- Show up to 10 items
- Section title includes the source title name
- Refreshes on each app launch (different random favorite)

#### "Directors You Should Know"
- From user's top 10 highest-rated favorites, extract directors (via TMDB credits)
- Find directors that appear once (not yet a "favorite director")
- For each, pick their highest-rated other movie
- Show up to 10 items with subtitle "From the director of [favorite title]"

#### "Top in Your Genres"
- Take user's top 3 genres from taste profile
- TMDB discover: top rated in those genres, vote_count ≥ 500
- Filter out favorites/watchlist
- Show up to 10 items

### Minimum Threshold
- Less than 5 favorites: show only trending sections (no smart lists)
- Same threshold as Taste Profile

### Data
- TMDB recommendations + discover endpoints
- Local SwiftData for favorites/watchlist exclusion
- Director data from TMDB credits (cached)

### New Files
- `SmartListsView.swift` — container rendering all smart list sections
- `SmartListsViewModel.swift` — orchestrates fetching for all three lists

---

## Discovery Tab — New Layout (top to bottom)

1. **Search bar** (existing)
2. **Genre browse** (existing)
3. **Taste Profile card** (new, if ≥5 favorites)
4. **"What Should I Watch?"** button (new, if ≥5 favorites)
5. **Smart Lists** (new, if ≥5 favorites):
   - "Because you liked [X]"
   - "Directors You Should Know"
   - "Top in Your Genres"
6. **Trending Movies** (existing)
7. **Trending Series** (existing)
8. **Top Rated Movies** (existing)
9. **Top Rated Series** (existing)

---

## New Files Summary

### ViewModels (9 new)
- `CompareViewModel.swift`
- `CareerProfileViewModel.swift`
- `GenreEvolutionViewModel.swift`
- `BestYearsViewModel.swift`
- `DecadeBattleViewModel.swift`
- `FranchiseTrackerViewModel.swift`
- `TasteProfileViewModel.swift`
- `WhatToWatchViewModel.swift`
- `SmartListsViewModel.swift`

### Views (15+ new)
- `CompareView.swift`, `ComparisonSlotView.swift`, `RatingComparisonBar.swift`
- `CareerProfileView.swift`, `CareerTimelineChart.swift`, `GenreDNAChart.swift`
- `TrendsView.swift`, `GenreEvolutionView.swift`, `BestYearsView.swift`, `DecadeBattleView.swift`, `FranchiseTrackerView.swift`
- `TasteProfileView.swift`, `TasteProfileCard.swift`
- `WhatToWatchView.swift`, `MoodSelectionView.swift`, `RecommendationCard.swift`
- `SmartListsView.swift`

### Models (3 new)
- `TasteTag.swift` — taste tag definitions and rules
- `MoodFilter.swift` — mood to API parameter mapping
- `CareerData.swift` — career profile computed data structures

### Service Extensions
- `TMDBService` — add collection search endpoint, discover endpoint with configurable parameters

### Files to Delete
- `DailyPickView.swift`
- `DailyPickViewModel.swift`
- Widget extension target (entire folder)
- Widget-related code in `DiscoveryViewModel` and deep link handling

---

## Design Principles

- **All @Observable ViewModels** — consistent with existing codebase pattern
- **Swift Charts everywhere** — career timelines, genre evolution, decade battles, episode overlays
- **Adaptive colors** — all new views support light and dark mode using existing color system
- **Progressive loading** — skeleton views and progressive chart rendering for data-heavy screens
- **Reuse existing components** — MediaCard, MediaSection, rating colors, search logic
- **No new API dependencies** — everything from TMDB and OMDb
- **No new persistence beyond UserDefaults** — recent profiles cached simply, all analytics computed on-the-fly from SwiftData
