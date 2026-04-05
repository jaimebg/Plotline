# Plotline — Data Nerd Edition Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **REQUIRED SKILLS per task:**
> - `swift-concurrency-expert` — for every ViewModel and Service file
> - `swiftui-ui-patterns` — for every View file
> - `swiftui-view-refactor` — when modifying existing views
> - `swiftui-performance-audit` — for views with charts or heavy data
> - `swiftui-liquid-glass` — for all new views (iOS 26+ styling)
>
> **Apple Docs MCP:** Use `apple-docs` MCP tools to verify Swift Charts APIs, SwiftData patterns, and iOS 18+ APIs before implementation.

**Goal:** Add 7 major features (comparator, career profiles, trend explorer, taste profile, "what to watch", smart lists) and remove widgets + daily pick, to pass App Store Guideline 4.2.

**Architecture:** Extend existing `@Observable` ViewModel pattern. All new features use TMDB/OMDb APIs via existing service layer (extended with new endpoints). Local computation from SwiftData for personalization. No new persistence beyond UserDefaults for caching.

**Tech Stack:** SwiftUI, Swift Charts, SwiftData, TMDB API, OMDb API, `@Observable`, `@MainActor`, `async/await`

**Spec:** `docs/superpowers/specs/2026-04-05-data-nerd-edition-design.md`

**No test target exists.** Verification is done via `xcodebuild` build checks after each task.

**Build command:**
```bash
xcodebuild -project Plotline.xcodeproj -scheme Plotline -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath build build 2>&1 | tail -5
```

---

## File Structure

### Files to Delete
- `Plotline/Views/Discovery/DailyPickView.swift`
- `Plotline/ViewModels/DailyPickViewModel.swift`
- `Plotline/Services/WidgetDataManager.swift`
- `PlotlineWidgets/` (entire directory)
- Widget target from `Plotline.xcodeproj`

### Files to Modify
- `Plotline/Services/TMDBService.swift` — add person details, person combined credits, search collections, flexible discover
- `Plotline/Models/APIResponses/TMDBResponse.swift` — add TMDBPersonResponse, TMDBPersonCombinedCreditsResponse, TMDBCollectionSearchResponse, PersonCombinedCastCredit, PersonCombinedCrewCredit
- `Plotline/Services/FavoritesManager.swift` — remove WidgetKit import and widget update calls
- `Plotline/Services/WatchlistManager.swift` — remove WidgetKit import and widget update calls
- `Plotline/ViewModels/DiscoveryViewModel.swift` — remove widget update, remove daily pick references
- `Plotline/Views/Discovery/DiscoveryView.swift` — remove DailyPickView, add taste profile card, what-to-watch button, smart lists
- `Plotline/Views/Stats/StatsView.swift` — add Compare, Career Profiles, Trends sections below My Stats
- `Plotline/Views/Detail/MediaDetailView.swift` — add "Compare" button to toolbar, make cast/crew names tappable to career profiles

### Files to Create
- `Plotline/Models/TasteTag.swift`
- `Plotline/Models/MoodFilter.swift`
- `Plotline/ViewModels/TasteProfileViewModel.swift`
- `Plotline/ViewModels/WhatToWatchViewModel.swift`
- `Plotline/ViewModels/SmartListsViewModel.swift`
- `Plotline/ViewModels/CompareViewModel.swift`
- `Plotline/ViewModels/CareerProfileViewModel.swift`
- `Plotline/ViewModels/GenreEvolutionViewModel.swift`
- `Plotline/ViewModels/BestYearsViewModel.swift`
- `Plotline/ViewModels/DecadeBattleViewModel.swift`
- `Plotline/ViewModels/FranchiseTrackerViewModel.swift`
- `Plotline/Views/Discovery/TasteProfileCard.swift`
- `Plotline/Views/Discovery/TasteProfileView.swift`
- `Plotline/Views/Discovery/WhatToWatchView.swift`
- `Plotline/Views/Discovery/MoodSelectionView.swift`
- `Plotline/Views/Discovery/RecommendationCard.swift`
- `Plotline/Views/Discovery/SmartListsView.swift`
- `Plotline/Views/Stats/CompareView.swift`
- `Plotline/Views/Stats/ComparisonSlotView.swift`
- `Plotline/Views/Stats/RatingComparisonBar.swift`
- `Plotline/Views/Stats/CareerProfileView.swift`
- `Plotline/Views/Stats/CareerSearchView.swift`
- `Plotline/Views/Stats/CareerTimelineChart.swift`
- `Plotline/Views/Stats/GenreDNAChart.swift`
- `Plotline/Views/Stats/TrendsView.swift`
- `Plotline/Views/Stats/GenreEvolutionView.swift`
- `Plotline/Views/Stats/BestYearsView.swift`
- `Plotline/Views/Stats/DecadeBattleView.swift`
- `Plotline/Views/Stats/FranchiseTrackerView.swift`

---

## Task 1: Remove Widget Target and Daily Pick

**Files:**
- Delete: `PlotlineWidgets/` (entire directory)
- Delete: `Plotline/Services/WidgetDataManager.swift`
- Delete: `Plotline/Views/Discovery/DailyPickView.swift`
- Delete: `Plotline/ViewModels/DailyPickViewModel.swift`
- Modify: `Plotline.xcodeproj/project.pbxproj`
- Modify: `Plotline/Services/FavoritesManager.swift`
- Modify: `Plotline/Services/WatchlistManager.swift`
- Modify: `Plotline/ViewModels/DiscoveryViewModel.swift`
- Modify: `Plotline/Views/Discovery/DiscoveryView.swift`

- [ ] **Step 1: Remove the widget target from the Xcode project**

Open the Xcode project file and remove the PlotlineWidgetsExtension target. This is best done by removing the PlotlineWidgets directory and all references from the pbxproj:

```bash
rm -rf PlotlineWidgets
```

Then use Xcode or a script to remove the target. Alternatively, remove all references to `PlotlineWidgets` from the `project.pbxproj` file — every `PBXBuildFile`, `PBXFileReference`, `PBXGroup`, `PBXNativeTarget`, and `PBXTargetDependency` entry referencing PlotlineWidgets or the widget extension.

- [ ] **Step 2: Delete WidgetDataManager.swift**

```bash
rm Plotline/Services/WidgetDataManager.swift
```

Remove its reference from `project.pbxproj`.

- [ ] **Step 3: Delete DailyPickView.swift and DailyPickViewModel.swift**

```bash
rm Plotline/Views/Discovery/DailyPickView.swift
rm Plotline/ViewModels/DailyPickViewModel.swift
```

Remove their references from `project.pbxproj`.

- [ ] **Step 4: Clean up FavoritesManager.swift**

Remove WidgetKit import and the `updateWidgetSnapshot()` method and its call:

In `Plotline/Services/FavoritesManager.swift`:
- Remove `import WidgetKit` line
- Remove the entire `private func updateWidgetSnapshot()` method (lines 129-144)
- Remove the call `updateWidgetSnapshot()` from `fetchFavorites()` (line 120)

The `fetchFavorites()` method should end with:

```swift
            favorites = uniqueFavorites
            favoriteIds = seenIds
        } catch {
```

- [ ] **Step 5: Clean up WatchlistManager.swift**

In `Plotline/Services/WatchlistManager.swift`:
- Remove `import WidgetKit` line
- Remove the entire `private func updateWidgetStats()` method (lines 146-157)
- Remove the call `updateWidgetStats()` from `fetchWatchlist()` (line 137)

The `fetchWatchlist()` method should end with:

```swift
            watchlistItems = uniqueItems
            watchlistIds = seenIds
        } catch {
```

- [ ] **Step 6: Clean up DiscoveryViewModel.swift**

In `Plotline/ViewModels/DiscoveryViewModel.swift`:
- Remove the `private func updateWidgetTrending()` method entirely
- Remove any calls to `updateWidgetTrending()` (in `loadContent()` or `refresh()`)
- Remove any import of WidgetKit if present

- [ ] **Step 7: Remove DailyPickView from DiscoveryView.swift**

In `Plotline/Views/Discovery/DiscoveryView.swift`:
- Remove the `DailyPickView(...)` section from the `mainContentView`
- Remove any `@State` or property for `DailyPickViewModel` if declared in DiscoveryView
- Remove any `import` or reference to DailyPickView/DailyPickViewModel
- Keep everything else (genre browse card, media sections) intact

- [ ] **Step 8: Build verification**

```bash
xcodebuild -project Plotline.xcodeproj -scheme Plotline -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath build build 2>&1 | tail -5
```

Expected: **BUILD SUCCEEDED**. Fix any remaining references to deleted files.

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "chore: remove widget target and daily pick feature"
```

---

## Task 2: Extend TMDBService with New API Endpoints

**Files:**
- Modify: `Plotline/Services/TMDBService.swift`
- Modify: `Plotline/Models/APIResponses/TMDBResponse.swift`

- [ ] **Step 1: Add new response models to TMDBResponse.swift**

Append to the end of `Plotline/Models/APIResponses/TMDBResponse.swift`:

```swift
// MARK: - Person Models

/// Response for TMDB /person/{id}
struct TMDBPersonResponse: Codable {
    let id: Int
    let name: String
    let biography: String?
    let birthday: String?
    let deathday: String?
    let placeOfBirth: String?
    let profilePath: String?
    let knownForDepartment: String?

    var profileURL: URL? {
        TMDBService.profileURL(path: profilePath, size: .large)
    }

    var birthYear: Int? {
        guard let birthday, birthday.count >= 4 else { return nil }
        return Int(String(birthday.prefix(4)))
    }

    var age: Int? {
        guard let birthYear else { return nil }
        let currentYear = Calendar.current.component(.year, from: Date())
        if let deathday, deathday.count >= 4, let deathYear = Int(String(deathday.prefix(4))) {
            return deathYear - birthYear
        }
        return currentYear - birthYear
    }
}

/// Response for TMDB /person/{id}/combined_credits
struct TMDBPersonCombinedCreditsResponse: Codable {
    let id: Int
    let cast: [PersonCombinedCastCredit]
    let crew: [PersonCombinedCrewCredit]
}

/// Cast credit from combined credits (movies + TV)
struct PersonCombinedCastCredit: Codable, Identifiable, Hashable {
    let id: Int
    let mediaType: MediaType
    let title: String?
    let name: String?
    let character: String?
    let releaseDate: String?
    let firstAirDate: String?
    let voteAverage: Double
    let voteCount: Int
    let posterPath: String?
    let popularity: Double
    let genreIds: [Int]?

    var displayTitle: String { title ?? name ?? "Unknown" }

    var displayDate: String? { releaseDate ?? firstAirDate }

    var year: String? {
        guard let date = displayDate, date.count >= 4 else { return nil }
        return String(date.prefix(4))
    }

    var yearInt: Int? { year.flatMap { Int($0) } }

    var posterURL: URL? {
        TMDBService.posterURL(path: posterPath, size: .medium)
    }

    var formattedRating: String {
        String(format: "%.1f", voteAverage)
    }

    func toMediaItem() -> MediaItem {
        MediaItem(
            id: id,
            overview: "",
            posterPath: posterPath,
            backdropPath: nil,
            voteAverage: voteAverage,
            voteCount: voteCount,
            genreIds: genreIds,
            title: title,
            releaseDate: releaseDate,
            name: name,
            firstAirDate: firstAirDate,
            mediaType: mediaType
        )
    }
}

/// Crew credit from combined credits (movies + TV)
struct PersonCombinedCrewCredit: Codable, Identifiable, Hashable {
    let id: Int
    let mediaType: MediaType
    let title: String?
    let name: String?
    let job: String?
    let department: String?
    let releaseDate: String?
    let firstAirDate: String?
    let voteAverage: Double
    let voteCount: Int
    let posterPath: String?
    let popularity: Double
    let genreIds: [Int]?

    var displayTitle: String { title ?? name ?? "Unknown" }

    var displayDate: String? { releaseDate ?? firstAirDate }

    var year: String? {
        guard let date = displayDate, date.count >= 4 else { return nil }
        return String(date.prefix(4))
    }

    var yearInt: Int? { year.flatMap { Int($0) } }

    var isDirector: Bool { job?.lowercased() == "director" }

    var posterURL: URL? {
        TMDBService.posterURL(path: posterPath, size: .medium)
    }

    var formattedRating: String {
        String(format: "%.1f", voteAverage)
    }

    func toMediaItem() -> MediaItem {
        MediaItem(
            id: id,
            overview: "",
            posterPath: posterPath,
            backdropPath: nil,
            voteAverage: voteAverage,
            voteCount: voteCount,
            genreIds: genreIds,
            title: title,
            releaseDate: releaseDate,
            name: name,
            firstAirDate: firstAirDate,
            mediaType: mediaType
        )
    }
}

// MARK: - Collection Search

/// Response for TMDB /search/collection
struct TMDBCollectionSearchResponse: Codable {
    let page: Int
    let results: [TMDBCollectionSearchResult]
    let totalPages: Int
    let totalResults: Int
}

struct TMDBCollectionSearchResult: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let posterPath: String?
    let backdropPath: String?

    var posterURL: URL? {
        TMDBService.posterURL(path: posterPath, size: .medium)
    }
}
```

- [ ] **Step 2: Add new endpoints to TMDBService.swift**

Add these methods to `TMDBService` before the `// MARK: - Private Helpers` section:

```swift
    // MARK: - Person

    /// Fetch person details (biography, birthday, etc.)
    func fetchPersonDetails(id: Int) async throws -> TMDBPersonResponse {
        guard let url = buildURL(path: "/person/\(id)") else {
            throw NetworkError.invalidURL
        }
        return try await networkManager.fetch(TMDBPersonResponse.self, from: url)
    }

    /// Fetch all movie + TV credits for a person
    func fetchPersonCombinedCredits(personId: Int) async throws -> TMDBPersonCombinedCreditsResponse {
        guard let url = buildURL(path: "/person/\(personId)/combined_credits") else {
            throw NetworkError.invalidURL
        }
        return try await networkManager.fetch(TMDBPersonCombinedCreditsResponse.self, from: url)
    }

    // MARK: - Collection Search

    /// Search for movie collections/franchises
    func searchCollections(query: String, page: Int = 1) async throws -> TMDBCollectionSearchResponse {
        guard !query.isEmpty else {
            return TMDBCollectionSearchResponse(page: 1, results: [], totalPages: 0, totalResults: 0)
        }
        guard let url = buildURL(
            path: "/search/collection",
            additionalParams: ["query": query, "page": "\(page)"]
        ) else {
            throw NetworkError.invalidURL
        }
        return try await networkManager.fetch(TMDBCollectionSearchResponse.self, from: url)
    }

    // MARK: - Flexible Discover

    /// Discover movies with arbitrary parameters
    func discoverMovies(params: [String: String], page: Int = 1) async throws -> TMDBResponse {
        var allParams = params
        allParams["page"] = "\(page)"
        guard let url = buildURL(path: "/discover/movie", additionalParams: allParams) else {
            throw NetworkError.invalidURL
        }
        return try await networkManager.fetch(TMDBResponse.self, from: url)
    }

    /// Discover TV series with arbitrary parameters
    func discoverSeries(params: [String: String], page: Int = 1) async throws -> TMDBResponse {
        var allParams = params
        allParams["page"] = "\(page)"
        guard let url = buildURL(path: "/discover/tv", additionalParams: allParams) else {
            throw NetworkError.invalidURL
        }
        return try await networkManager.fetch(TMDBResponse.self, from: url)
    }
```

- [ ] **Step 3: Build verification**

```bash
xcodebuild -project Plotline.xcodeproj -scheme Plotline -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath build build 2>&1 | tail -5
```

Expected: **BUILD SUCCEEDED**

- [ ] **Step 4: Commit**

```bash
git add Plotline/Services/TMDBService.swift Plotline/Models/APIResponses/TMDBResponse.swift
git commit -m "feat: add person details, combined credits, collection search, and flexible discover endpoints"
```

---

## Task 3: Taste Profile — Models and ViewModel

**Files:**
- Create: `Plotline/Models/TasteTag.swift`
- Create: `Plotline/ViewModels/TasteProfileViewModel.swift`

- [ ] **Step 1: Create TasteTag.swift**

```swift
import Foundation

/// A generated taste tag based on user's favorites/watchlist patterns
struct TasteTag: Identifiable, Hashable {
    let id: String
    let label: String
    let score: Double // 0-1, used for ranking

    /// Generate taste tags from favorites analysis
    static func generate(
        genrePercentages: [(genre: String, percentage: Double)],
        preferredEra: String?,
        directorAppearances: Int,
        seriesRatio: Double,
        avgPopularity: Double,
        medianPopularity: Double,
        avgRating: Double
    ) -> [TasteTag] {
        var tags: [TasteTag] = []

        // Genre-based tags (if any genre >30%)
        for (genre, pct) in genrePercentages where pct > 0.30 {
            tags.append(TasteTag(id: "genre_\(genre)", label: "\(genre) Lover", score: pct))
        }

        // Era-based tag
        if let era = preferredEra {
            tags.append(TasteTag(id: "era", label: "\(era) Cinephile", score: 0.5))
        }

        // Auteur fan (director appears 3+ times)
        if directorAppearances >= 3 {
            tags.append(TasteTag(id: "auteur", label: "Auteur Fan", score: Double(directorAppearances) / 10.0))
        }

        // Binge watcher (>50% series)
        if seriesRatio > 0.50 {
            tags.append(TasteTag(id: "binge", label: "Binge Watcher", score: seriesRatio))
        }

        // Popularity-based tags
        if avgPopularity < medianPopularity * 0.5 {
            tags.append(TasteTag(id: "hidden_gem", label: "Hidden Gem Hunter", score: 0.7))
        } else if avgPopularity > medianPopularity * 1.5 {
            tags.append(TasteTag(id: "blockbuster", label: "Blockbuster Fan", score: 0.6))
        }

        // Rating snob (avg >8.0)
        if avgRating > 8.0 {
            tags.append(TasteTag(id: "snob", label: "Rating Snob", score: avgRating / 10.0))
        }

        // Genre hopper (no genre >25%)
        if genrePercentages.allSatisfy({ $0.percentage <= 0.25 }) && genrePercentages.count >= 4 {
            tags.append(TasteTag(id: "hopper", label: "Genre Hopper", score: 0.6))
        }

        // Sort by score descending, take top 4
        return Array(tags.sorted { $0.score > $1.score }.prefix(4))
    }
}
```

- [ ] **Step 2: Create TasteProfileViewModel.swift**

```swift
import Foundation
import SwiftUI

@Observable
final class TasteProfileViewModel {
    var topGenres: [(genre: String, percentage: Double)] = []
    var favoriteDirector: (name: String, count: Int)?
    var favoriteActor: (name: String, count: Int)?
    var ratingSweetSpot: (low: Double, high: Double) = (0, 10)
    var preferredEra: String?
    var tasteTags: [TasteTag] = []
    var moviesCount = 0
    var seriesCount = 0
    var isLoading = false
    var hasEnoughData = false

    private let tmdbService = TMDBService.shared
    private let minimumFavorites = 5

    @MainActor
    func computeProfile(favorites: [FavoriteItem], watchlistItems: [WatchlistItem]) async {
        guard favorites.count >= minimumFavorites else {
            hasEnoughData = false
            return
        }

        hasEnoughData = true
        isLoading = true

        let allItems = favorites

        // Genre distribution
        computeGenres(from: allItems)

        // Media type split
        moviesCount = allItems.filter { $0.mediaType == "movie" }.count
        seriesCount = allItems.filter { $0.mediaType == "tv" }.count

        // Rating sweet spot (IQR)
        computeRatingSweetSpot(from: allItems)

        // Preferred era
        computePreferredEra(from: allItems)

        // Director and actor frequency (needs API calls)
        await computeTopPeople(from: allItems)

        // Generate taste tags
        let seriesRatio = Double(seriesCount) / Double(allItems.count)
        let avgRating = allItems.map(\.voteAverage).reduce(0, +) / Double(allItems.count)
        // Use voteAverage as a proxy for popularity since FavoriteItem doesn't store popularity
        let avgPop = allItems.map(\.voteAverage).reduce(0, +) / Double(allItems.count)
        let medianPop = allItems.map(\.voteAverage).sorted()[allItems.count / 2]
        let directorMax = favoriteDirector?.count ?? 0

        tasteTags = TasteTag.generate(
            genrePercentages: topGenres,
            preferredEra: preferredEra,
            directorAppearances: directorMax,
            seriesRatio: seriesRatio,
            avgPopularity: avgPop,
            medianPopularity: medianPop,
            avgRating: avgRating
        )

        isLoading = false
    }

    private func computeGenres(from items: [FavoriteItem]) {
        var genreCounts: [String: Int] = [:]
        var totalGenres = 0
        for item in items {
            for genreId in item.genreIdArray {
                if let name = GenreLookup.name(for: genreId) {
                    genreCounts[name, default: 0] += 1
                    totalGenres += 1
                }
            }
        }
        guard totalGenres > 0 else {
            topGenres = []
            return
        }
        topGenres = genreCounts
            .map { (genre: $0.key, percentage: Double($0.value) / Double(totalGenres)) }
            .sorted { $0.percentage > $1.percentage }
            .prefix(3)
            .map { $0 }
    }

    private func computeRatingSweetSpot(from items: [FavoriteItem]) {
        let sorted = items.map(\.voteAverage).sorted()
        guard sorted.count >= 4 else {
            ratingSweetSpot = (sorted.first ?? 0, sorted.last ?? 10)
            return
        }
        let q1Index = sorted.count / 4
        let q3Index = (sorted.count * 3) / 4
        ratingSweetSpot = (sorted[q1Index], sorted[q3Index])
    }

    private func computePreferredEra(from items: [FavoriteItem]) {
        var decadeCounts: [String: Int] = [:]
        for item in items {
            let media = item.toMediaItem()
            if let yearStr = media.year, let year = Int(yearStr) {
                let decade = "\(year / 10 * 10)s"
                decadeCounts[decade, default: 0] += 1
            }
        }
        preferredEra = decadeCounts.max(by: { $0.value < $1.value })?.key
    }

    @MainActor
    private func computeTopPeople(from items: [FavoriteItem]) async {
        var directorCounts: [String: Int] = [:]
        var actorCounts: [String: Int] = [:]

        // Fetch credits for each favorite (with concurrency limit)
        await withTaskGroup(of: (directors: [String], actors: [String])?.self) { group in
            for item in items {
                group.addTask {
                    do {
                        let credits: TMDBCreditsResponse
                        if item.isTVSeries {
                            credits = try await self.tmdbService.fetchSeriesCredits(id: item.tmdbId)
                        } else {
                            credits = try await self.tmdbService.fetchMovieCredits(id: item.tmdbId)
                        }
                        let directors = credits.crew.filter { $0.job == "Director" }.map(\.name)
                        let actors = credits.cast.prefix(3).map(\.name)
                        return (directors: directors, actors: Array(actors))
                    } catch {
                        return nil
                    }
                }
            }

            for await result in group {
                guard let result else { continue }
                for name in result.directors {
                    directorCounts[name, default: 0] += 1
                }
                for name in result.actors {
                    actorCounts[name, default: 0] += 1
                }
            }
        }

        if let top = directorCounts.max(by: { $0.value < $1.value }), top.value >= 2 {
            favoriteDirector = (name: top.key, count: top.value)
        }
        if let top = actorCounts.max(by: { $0.value < $1.value }), top.value >= 2 {
            favoriteActor = (name: top.key, count: top.value)
        }
    }
}
```

- [ ] **Step 3: Build verification**

```bash
xcodebuild -project Plotline.xcodeproj -scheme Plotline -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath build build 2>&1 | tail -5
```

Expected: **BUILD SUCCEEDED**

- [ ] **Step 4: Commit**

```bash
git add Plotline/Models/TasteTag.swift Plotline/ViewModels/TasteProfileViewModel.swift
git commit -m "feat: add TasteTag model and TasteProfileViewModel"
```

---

## Task 4: Taste Profile — Views

**Files:**
- Create: `Plotline/Views/Discovery/TasteProfileCard.swift`
- Create: `Plotline/Views/Discovery/TasteProfileView.swift`

- [ ] **Step 1: Create TasteProfileCard.swift**

This is the compact preview card shown in Discovery. Tapping navigates to the full TasteProfileView.

```swift
import SwiftUI

/// Compact taste profile preview card for Discovery tab
struct TasteProfileCard: View {
    let topGenres: [(genre: String, percentage: Double)]
    let tasteTags: [TasteTag]
    let hasEnoughData: Bool

    var body: some View {
        if hasEnoughData {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .foregroundStyle(Color.plotlineGold)
                    Text("Your Taste Profile")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !tasteTags.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(tasteTags.prefix(3)) { tag in
                            Text(tag.label)
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.plotlineGold.opacity(0.15))
                                .foregroundStyle(Color.plotlineGold)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            .padding()
            .background(Color.plotlineCard)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}
```

- [ ] **Step 2: Create TasteProfileView.swift**

Full taste profile screen:

```swift
import SwiftUI
import Charts

/// Full taste profile view showing user's viewing preferences
struct TasteProfileView: View {
    let viewModel: TasteProfileViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                tasteTagsSection
                topGenresSection
                peopleSections
                ratingSweetSpotSection
                eraSection
                mediaTypeSplitSection
            }
            .padding()
        }
        .navigationTitle("Taste Profile")
        .background(Color.plotlineBackground)
    }

    // MARK: - Taste Tags

    @ViewBuilder
    private var tasteTagsSection: some View {
        if !viewModel.tasteTags.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("You Are")
                    .font(.headline)
                    .foregroundStyle(.primary)

                FlowLayout(spacing: 8) {
                    ForEach(viewModel.tasteTags) { tag in
                        Text(tag.label)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.plotlineGold.opacity(0.15))
                            .foregroundStyle(Color.plotlineGold)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding()
            .background(Color.plotlineCard)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Top Genres

    @ViewBuilder
    private var topGenresSection: some View {
        if !viewModel.topGenres.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Top Genres")
                    .font(.headline)
                    .foregroundStyle(.primary)

                ForEach(Array(viewModel.topGenres.enumerated()), id: \.offset) { index, genre in
                    HStack {
                        Text(genre.genre)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .frame(width: 100, alignment: .leading)

                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 4)
                                .fill(barColor(for: index))
                                .frame(width: geo.size.width * genre.percentage)
                        }
                        .frame(height: 20)

                        Text("\(Int(genre.percentage * 100))%")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                            .frame(width: 40, alignment: .trailing)
                    }
                }
            }
            .padding()
            .background(Color.plotlineCard)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Director & Actor

    @ViewBuilder
    private var peopleSections: some View {
        if viewModel.favoriteDirector != nil || viewModel.favoriteActor != nil {
            VStack(alignment: .leading, spacing: 12) {
                Text("Your Favorites")
                    .font(.headline)
                    .foregroundStyle(.primary)

                if let director = viewModel.favoriteDirector {
                    HStack {
                        Image(systemName: "megaphone.fill")
                            .foregroundStyle(Color.plotlineSecondaryAccent)
                        VStack(alignment: .leading) {
                            Text("Favorite Director")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(director.name)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                        }
                        Spacer()
                        Text("\(director.count) titles")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let actor = viewModel.favoriteActor {
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundStyle(Color.plotlineGold)
                        VStack(alignment: .leading) {
                            Text("Favorite Actor")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(actor.name)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                        }
                        Spacer()
                        Text("\(actor.count) titles")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
            .background(Color.plotlineCard)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Rating Sweet Spot

    private var ratingSweetSpotSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Rating Sweet Spot")
                .font(.headline)
                .foregroundStyle(.primary)

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.15))
                    .frame(height: 24)

                GeometryReader { geo in
                    let low = viewModel.ratingSweetSpot.low / 10.0
                    let high = viewModel.ratingSweetSpot.high / 10.0
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.plotlineGradient)
                        .frame(width: geo.size.width * (high - low))
                        .offset(x: geo.size.width * low)
                }
                .frame(height: 24)
            }

            HStack {
                Text(String(format: "%.1f", viewModel.ratingSweetSpot.low))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "%.1f", viewModel.ratingSweetSpot.high))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color.plotlineCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Preferred Era

    @ViewBuilder
    private var eraSection: some View {
        if let era = viewModel.preferredEra {
            HStack {
                Image(systemName: "calendar")
                    .foregroundStyle(Color.plotlineSecondaryAccent)
                Text("Your era:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(era)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding()
            .background(Color.plotlineCard)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Media Split

    private var mediaTypeSplitSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Movies vs Series")
                .font(.headline)
                .foregroundStyle(.primary)

            HStack(spacing: 24) {
                VStack {
                    Text("\(viewModel.moviesCount)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.plotlineSecondaryAccent)
                    Text("Movies")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack {
                    Text("\(viewModel.seriesCount)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.plotlineGold)
                    Text("Series")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(Color.plotlineCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Helpers

    private func barColor(for index: Int) -> Color {
        switch index {
        case 0: return .plotlineGold
        case 1: return .plotlineSecondaryAccent
        default: return .plotlinePrimary
        }
    }
}

/// Simple flow layout for taste tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (positions, CGSize(width: maxWidth, height: y + rowHeight))
    }
}
```

- [ ] **Step 3: Build verification**

```bash
xcodebuild -project Plotline.xcodeproj -scheme Plotline -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath build build 2>&1 | tail -5
```

Expected: **BUILD SUCCEEDED**

- [ ] **Step 4: Commit**

```bash
git add Plotline/Views/Discovery/TasteProfileCard.swift Plotline/Views/Discovery/TasteProfileView.swift
git commit -m "feat: add taste profile card and full profile view"
```

---

## Task 5: "What Should I Watch?" — Models and ViewModel

**Files:**
- Create: `Plotline/Models/MoodFilter.swift`
- Create: `Plotline/ViewModels/WhatToWatchViewModel.swift`

- [ ] **Step 1: Create MoodFilter.swift**

```swift
import Foundation

/// Maps mood selections to TMDB API parameters
struct MoodFilter: Identifiable, Hashable {
    let id: String
    let label: String
    let icon: String
    let genreIds: [Int] // TMDB movie genre IDs
    let minRating: Double?
    let minVoteCount: Int?
    let maxVoteCount: Int?

    static let all: [MoodFilter] = [
        MoodFilter(
            id: "light",
            label: "Something Light",
            icon: "sun.max.fill",
            genreIds: [35, 16, 10751], // Comedy, Animation, Family
            minRating: nil,
            minVoteCount: nil,
            maxVoteCount: nil
        ),
        MoodFilter(
            id: "mind_bending",
            label: "Mind-Bending",
            icon: "brain.head.profile",
            genreIds: [878, 9648, 53], // Sci-Fi, Mystery, Thriller
            minRating: 7.5,
            minVoteCount: nil,
            maxVoteCount: nil
        ),
        MoodFilter(
            id: "emotional",
            label: "Emotional",
            icon: "heart.fill",
            genreIds: [18, 10749], // Drama, Romance
            minRating: nil,
            minVoteCount: nil,
            maxVoteCount: nil
        ),
        MoodFilter(
            id: "action",
            label: "Action-Packed",
            icon: "flame.fill",
            genreIds: [28, 12], // Action, Adventure
            minRating: nil,
            minVoteCount: nil,
            maxVoteCount: nil
        ),
        MoodFilter(
            id: "acclaimed",
            label: "Critically Acclaimed",
            icon: "trophy.fill",
            genreIds: [], // Any genre
            minRating: 8.0,
            minVoteCount: 1000,
            maxVoteCount: nil
        ),
        MoodFilter(
            id: "hidden_gem",
            label: "Hidden Gem",
            icon: "sparkle",
            genreIds: [], // Any genre
            minRating: 7.0,
            minVoteCount: 100,
            maxVoteCount: 1000
        ),
    ]
}

enum WatchTimeChoice: String, CaseIterable {
    case movie = "Movie (~2h)"
    case series = "Start a Series"

    var icon: String {
        switch self {
        case .movie: return "film"
        case .series: return "tv"
        }
    }
}
```

- [ ] **Step 2: Create WhatToWatchViewModel.swift**

```swift
import Foundation

@Observable
final class WhatToWatchViewModel {
    // Flow state
    var currentStep = 1
    var selectedMoods: [MoodFilter] = []
    var selectedTime: WatchTimeChoice?
    var results: [MediaItem] = []
    var whyLines: [Int: String] = [:] // mediaId -> why text
    var isLoading = false

    private let tmdbService = TMDBService.shared
    private var fetchedResults: [MediaItem] = [] // full pool for shuffling

    var canProceedFromStep1: Bool { !selectedMoods.isEmpty }
    var canProceedFromStep2: Bool { selectedTime != nil }

    func toggleMood(_ mood: MoodFilter) {
        if selectedMoods.contains(mood) {
            selectedMoods.removeAll { $0 == mood }
        } else if selectedMoods.count < 2 {
            selectedMoods.append(mood)
        }
    }

    func isMoodSelected(_ mood: MoodFilter) -> Bool {
        selectedMoods.contains(mood)
    }

    func reset() {
        currentStep = 1
        selectedMoods = []
        selectedTime = nil
        results = []
        whyLines = [:]
        fetchedResults = []
        isLoading = false
    }

    @MainActor
    func fetchResults(
        favoriteIds: Set<Int>,
        watchlistIds: Set<Int>,
        topGenreIds: [Int]
    ) async {
        guard let time = selectedTime else { return }
        isLoading = true

        var params: [String: String] = [
            "sort_by": "vote_average.desc",
            "vote_count.gte": "100"
        ]

        // Combine genre IDs from moods
        let moodGenreIds = selectedMoods.flatMap(\.genreIds)
        if !moodGenreIds.isEmpty {
            let uniqueIds = Array(Set(moodGenreIds))
            params["with_genres"] = uniqueIds.map(String.init).joined(separator: "|")
        }

        // Apply rating filters (use highest minRating from selected moods)
        let maxMinRating = selectedMoods.compactMap(\.minRating).max()
        if let minRating = maxMinRating {
            params["vote_average.gte"] = String(format: "%.1f", minRating)
        }

        // Apply vote count filters
        let maxMinVotes = selectedMoods.compactMap(\.minVoteCount).max()
        if let minVotes = maxMinVotes {
            params["vote_count.gte"] = "\(minVotes)"
        }
        let minMaxVotes = selectedMoods.compactMap(\.maxVoteCount).min()
        if let maxVotes = minMaxVotes {
            params["vote_count.lte"] = "\(maxVotes)"
        }

        do {
            let response: TMDBResponse
            if time == .movie {
                response = try await tmdbService.discoverMovies(params: params)
            } else {
                response = try await tmdbService.discoverSeries(params: params)
            }

            // Filter out favorites and watchlist
            let excludeIds = favoriteIds.union(watchlistIds)
            fetchedResults = response.results.filter { item in
                !excludeIds.contains(item.id) && item.posterPath != nil
            }

            pickRandomResults()
        } catch {
            fetchedResults = []
            results = []
        }

        isLoading = false
    }

    func shuffle(favoriteIds: Set<Int>, watchlistIds: Set<Int>) {
        pickRandomResults()
    }

    private func pickRandomResults() {
        let picked = Array(fetchedResults.shuffled().prefix(3))
        results = picked

        // Generate "why" lines
        whyLines = [:]
        let moodLabels = selectedMoods.map(\.label)
        let moodText = moodLabels.joined(separator: " + ")
        for item in picked {
            whyLines[item.id] = "Matches: \(moodText)"
        }
    }
}
```

- [ ] **Step 3: Build verification**

```bash
xcodebuild -project Plotline.xcodeproj -scheme Plotline -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath build build 2>&1 | tail -5
```

Expected: **BUILD SUCCEEDED**

- [ ] **Step 4: Commit**

```bash
git add Plotline/Models/MoodFilter.swift Plotline/ViewModels/WhatToWatchViewModel.swift
git commit -m "feat: add MoodFilter model and WhatToWatchViewModel"
```

---

## Task 6: "What Should I Watch?" — Views

**Files:**
- Create: `Plotline/Views/Discovery/MoodSelectionView.swift`
- Create: `Plotline/Views/Discovery/RecommendationCard.swift`
- Create: `Plotline/Views/Discovery/WhatToWatchView.swift`

- [ ] **Step 1: Create MoodSelectionView.swift**

```swift
import SwiftUI

/// Mood chip grid for "What Should I Watch?" step 1
struct MoodSelectionView: View {
    let moods: [MoodFilter]
    let selectedMoods: [MoodFilter]
    let onToggle: (MoodFilter) -> Void

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(moods) { mood in
                let isSelected = selectedMoods.contains(mood)
                Button {
                    onToggle(mood)
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: mood.icon)
                            .font(.title2)
                        Text(mood.label)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(isSelected ? Color.plotlineGold.opacity(0.2) : Color.plotlineCard)
                    .foregroundStyle(isSelected ? Color.plotlineGold : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.plotlineGold : Color.clear, lineWidth: 2)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}
```

- [ ] **Step 2: Create RecommendationCard.swift**

```swift
import SwiftUI

/// A single recommendation result card
struct RecommendationCard: View {
    let item: MediaItem
    let whyLine: String?

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: item.posterURL) { image in
                image
                    .resizable()
                    .aspectRatio(2/3, contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.2))
            }
            .frame(width: 80, height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 6) {
                Text(item.displayTitle)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                if let year = item.year {
                    Text(year)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(Color.plotlineGold)
                    Text(item.formattedRating)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                }

                if let why = whyLine {
                    Text(why)
                        .font(.caption)
                        .foregroundStyle(Color.plotlineSecondaryAccent)
                        .lineLimit(2)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color.plotlineCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
```

- [ ] **Step 3: Create WhatToWatchView.swift**

```swift
import SwiftUI

/// 3-step interactive recommendation flow
struct WhatToWatchView: View {
    @Environment(\.favoritesManager) private var favoritesManager
    @Environment(\.watchlistManager) private var watchlistManager
    @State private var viewModel = WhatToWatchViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Step indicator
                stepIndicator
                    .padding(.top, 8)

                // Content
                TabView(selection: $viewModel.currentStep) {
                    step1MoodView.tag(1)
                    step2TimeView.tag(2)
                    step3ResultsView.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: viewModel.currentStep)
            }
            .navigationTitle("What Should I Watch?")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color.plotlineBackground)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        viewModel.reset()
                    }
                }
            }
        }
    }

    // MARK: - Step Indicator

    private var stepIndicator: some View {
        HStack(spacing: 8) {
            ForEach(1...3, id: \.self) { step in
                Capsule()
                    .fill(step <= viewModel.currentStep ? Color.plotlineGold : Color.secondary.opacity(0.2))
                    .frame(height: 4)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Step 1: Mood

    private var step1MoodView: some View {
        VStack(spacing: 24) {
            Text("How are you feeling?")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.primary)

            Text("Pick up to 2 moods")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            MoodSelectionView(
                moods: MoodFilter.all,
                selectedMoods: viewModel.selectedMoods,
                onToggle: { viewModel.toggleMood($0) }
            )
            .padding(.horizontal)

            Spacer()

            Button {
                withAnimation { viewModel.currentStep = 2 }
            } label: {
                Text("Next")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(viewModel.canProceedFromStep1 ? Color.plotlineGold : Color.secondary.opacity(0.3))
                    .foregroundStyle(viewModel.canProceedFromStep1 ? .black : .secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(!viewModel.canProceedFromStep1)
            .padding(.horizontal)
            .padding(.bottom)
        }
        .padding(.top, 24)
    }

    // MARK: - Step 2: Time

    private var step2TimeView: some View {
        VStack(spacing: 24) {
            Text("What do you have time for?")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.primary)

            VStack(spacing: 12) {
                ForEach(WatchTimeChoice.allCases, id: \.self) { choice in
                    let isSelected = viewModel.selectedTime == choice
                    Button {
                        viewModel.selectedTime = choice
                    } label: {
                        HStack {
                            Image(systemName: choice.icon)
                                .font(.title2)
                            Text(choice.rawValue)
                                .font(.headline)
                            Spacer()
                        }
                        .padding()
                        .background(isSelected ? Color.plotlineGold.opacity(0.2) : Color.plotlineCard)
                        .foregroundStyle(isSelected ? Color.plotlineGold : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isSelected ? Color.plotlineGold : Color.clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)

            Spacer()

            Button {
                withAnimation { viewModel.currentStep = 3 }
                Task {
                    await viewModel.fetchResults(
                        favoriteIds: favoritesManager.favoriteIds,
                        watchlistIds: watchlistManager.watchlistIds,
                        topGenreIds: []
                    )
                }
            } label: {
                Text("Find Something")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(viewModel.canProceedFromStep2 ? Color.plotlineGold : Color.secondary.opacity(0.3))
                    .foregroundStyle(viewModel.canProceedFromStep2 ? .black : .secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(!viewModel.canProceedFromStep2)
            .padding(.horizontal)
            .padding(.bottom)
        }
        .padding(.top, 24)
    }

    // MARK: - Step 3: Results

    private var step3ResultsView: some View {
        VStack(spacing: 16) {
            if viewModel.isLoading {
                Spacer()
                ProgressView()
                    .tint(Color.plotlineGold)
                Text("Finding your perfect match...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            } else if viewModel.results.isEmpty {
                Spacer()
                ContentUnavailableView(
                    "No Matches",
                    systemImage: "film.stack",
                    description: Text("Try different moods or time preference")
                )
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(viewModel.results) { item in
                            NavigationLink(value: item) {
                                RecommendationCard(
                                    item: item,
                                    whyLine: viewModel.whyLines[item.id]
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
                .navigationDestination(for: MediaItem.self) { item in
                    MediaDetailView(media: item)
                }

                Button {
                    viewModel.shuffle(
                        favoriteIds: favoritesManager.favoriteIds,
                        watchlistIds: watchlistManager.watchlistIds
                    )
                } label: {
                    Label("Shuffle", systemImage: "shuffle")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.plotlineCard)
                        .foregroundStyle(Color.plotlineGold)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
        .padding(.top, 16)
    }
}
```

- [ ] **Step 4: Build verification**

```bash
xcodebuild -project Plotline.xcodeproj -scheme Plotline -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath build build 2>&1 | tail -5
```

Expected: **BUILD SUCCEEDED**. `MediaDetailView(media:)` must match the existing initializer — check the actual init signature and adjust if needed.

- [ ] **Step 5: Commit**

```bash
git add Plotline/Views/Discovery/MoodSelectionView.swift Plotline/Views/Discovery/RecommendationCard.swift Plotline/Views/Discovery/WhatToWatchView.swift
git commit -m "feat: add 'What Should I Watch?' interactive recommendation flow"
```

---

## Task 7: Smart Lists — ViewModel and View

**Files:**
- Create: `Plotline/ViewModels/SmartListsViewModel.swift`
- Create: `Plotline/Views/Discovery/SmartListsView.swift`

- [ ] **Step 1: Create SmartListsViewModel.swift**

```swift
import Foundation

@Observable
final class SmartListsViewModel {
    var becauseYouLiked: [MediaItem] = []
    var becauseYouLikedTitle: String = ""
    var directorsToKnow: [(item: MediaItem, directorName: String, fromTitle: String)] = []
    var topInYourGenres: [MediaItem] = []

    var isLoadingBecause = false
    var isLoadingDirectors = false
    var isLoadingTopGenres = false
    var hasEnoughData = false

    private let tmdbService = TMDBService.shared
    private let minimumFavorites = 5

    @MainActor
    func loadLists(
        favorites: [FavoriteItem],
        favoriteIds: Set<Int>,
        watchlistIds: Set<Int>,
        topGenreIds: [Int]
    ) async {
        guard favorites.count >= minimumFavorites else {
            hasEnoughData = false
            return
        }
        hasEnoughData = true

        // Load all three lists concurrently
        async let becauseTask: () = loadBecauseYouLiked(
            favorites: favorites,
            excludeIds: favoriteIds.union(watchlistIds)
        )
        async let directorsTask: () = loadDirectorsToKnow(
            favorites: favorites,
            excludeIds: favoriteIds.union(watchlistIds)
        )
        async let topGenresTask: () = loadTopInGenres(
            genreIds: topGenreIds,
            excludeIds: favoriteIds.union(watchlistIds)
        )

        await (becauseTask, directorsTask, topGenresTask)
    }

    @MainActor
    private func loadBecauseYouLiked(favorites: [FavoriteItem], excludeIds: Set<Int>) async {
        isLoadingBecause = true
        guard let randomFav = favorites.randomElement() else {
            isLoadingBecause = false
            return
        }

        becauseYouLikedTitle = randomFav.title

        do {
            let recs = try await tmdbService.fetchRecommendations(forFavorite: randomFav)
            becauseYouLiked = Array(
                recs.filter { !excludeIds.contains($0.id) && $0.posterPath != nil }.prefix(10)
            )
        } catch {
            becauseYouLiked = []
        }
        isLoadingBecause = false
    }

    @MainActor
    private func loadDirectorsToKnow(favorites: [FavoriteItem], excludeIds: Set<Int>) async {
        isLoadingDirectors = true

        // Get top 10 highest-rated favorites
        let topFavs = favorites.sorted { $0.voteAverage > $1.voteAverage }.prefix(10)

        var directorEntries: [(item: MediaItem, directorName: String, fromTitle: String)] = []

        await withTaskGroup(of: (directorName: String, bestTitle: MediaItem, fromTitle: String)?.self) { group in
            for fav in topFavs {
                group.addTask {
                    do {
                        let credits: TMDBCreditsResponse
                        if fav.isTVSeries {
                            credits = try await self.tmdbService.fetchSeriesCredits(id: fav.tmdbId)
                        } else {
                            credits = try await self.tmdbService.fetchMovieCredits(id: fav.tmdbId)
                        }

                        guard let director = credits.crew.first(where: { $0.job == "Director" }) else { return nil }

                        // Get director's other top work
                        let personCredits = try await self.tmdbService.fetchPersonMovieCredits(personId: director.id)
                        let bestOther = personCredits.crew
                            .filter { $0.isDirector && $0.id != fav.tmdbId && !excludeIds.contains($0.id) }
                            .sorted { $0.voteAverage > $1.voteAverage }
                            .first

                        guard let best = bestOther else { return nil }
                        return (directorName: director.name, bestTitle: best.toMediaItem(), fromTitle: fav.title)
                    } catch {
                        return nil
                    }
                }
            }

            for await result in group {
                guard let result else { continue }
                // Skip if director already added
                if !directorEntries.contains(where: { $0.directorName == result.directorName }) {
                    directorEntries.append((item: result.bestTitle, directorName: result.directorName, fromTitle: result.fromTitle))
                }
            }
        }

        directorsToKnow = Array(directorEntries.prefix(10))
        isLoadingDirectors = false
    }

    @MainActor
    private func loadTopInGenres(genreIds: [Int], excludeIds: Set<Int>) async {
        isLoadingTopGenres = true

        guard let primaryGenre = genreIds.first else {
            isLoadingTopGenres = false
            return
        }

        do {
            let params: [String: String] = [
                "with_genres": "\(primaryGenre)",
                "sort_by": "vote_average.desc",
                "vote_count.gte": "500"
            ]
            let response = try await tmdbService.discoverMovies(params: params)
            topInYourGenres = Array(
                response.results.filter { !excludeIds.contains($0.id) && $0.posterPath != nil }.prefix(10)
            )
        } catch {
            topInYourGenres = []
        }
        isLoadingTopGenres = false
    }
}
```

- [ ] **Step 2: Create SmartListsView.swift**

```swift
import SwiftUI

/// Renders smart list sections in Discovery
struct SmartListsView: View {
    let viewModel: SmartListsViewModel

    var body: some View {
        if viewModel.hasEnoughData {
            VStack(alignment: .leading, spacing: 24) {
                // Because You Liked
                if !viewModel.becauseYouLiked.isEmpty {
                    MediaSection(
                        title: "Because you liked \(viewModel.becauseYouLikedTitle)",
                        items: viewModel.becauseYouLiked
                    )
                } else if viewModel.isLoadingBecause {
                    sectionPlaceholder(title: "Because you liked...")
                }

                // Directors You Should Know
                if !viewModel.directorsToKnow.isEmpty {
                    directorsSection
                } else if viewModel.isLoadingDirectors {
                    sectionPlaceholder(title: "Directors You Should Know")
                }

                // Top in Your Genres
                if !viewModel.topInYourGenres.isEmpty {
                    MediaSection(
                        title: "Top in Your Genres",
                        items: viewModel.topInYourGenres
                    )
                } else if viewModel.isLoadingTopGenres {
                    sectionPlaceholder(title: "Top in Your Genres")
                }
            }
        }
    }

    private var directorsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Directors You Should Know")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(viewModel.directorsToKnow, id: \.item.id) { entry in
                        NavigationLink(value: entry.item) {
                            VStack(alignment: .leading, spacing: 6) {
                                AsyncImage(url: entry.item.posterURL) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(2/3, contentMode: .fill)
                                } placeholder: {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.secondary.opacity(0.2))
                                }
                                .frame(width: 120, height: 180)
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                                Text(entry.item.displayTitle)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)

                                Text("Dir. \(entry.directorName)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            .frame(width: 120)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func sectionPlaceholder(title: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(0..<5, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.secondary.opacity(0.1))
                            .frame(width: 120, height: 180)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}
```

- [ ] **Step 3: Build verification**

```bash
xcodebuild -project Plotline.xcodeproj -scheme Plotline -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath build build 2>&1 | tail -5
```

Expected: **BUILD SUCCEEDED**. The `MediaSection(title:items:)` initializer must match the existing one — check `MediaSection.swift` for exact init parameters and adjust if needed.

- [ ] **Step 4: Commit**

```bash
git add Plotline/ViewModels/SmartListsViewModel.swift Plotline/Views/Discovery/SmartListsView.swift
git commit -m "feat: add smart lists with personalized recommendations"
```

---

## Task 8: Restructure Discovery Tab

**Files:**
- Modify: `Plotline/Views/Discovery/DiscoveryView.swift`
- Modify: `Plotline/ViewModels/DiscoveryViewModel.swift`

- [ ] **Step 1: Read current DiscoveryView.swift and DiscoveryViewModel.swift**

Read both files completely to understand the current state after Task 1 modifications.

- [ ] **Step 2: Add state properties to DiscoveryView**

In `DiscoveryView.swift`, add these `@State` properties:

```swift
@State private var tasteProfileVM = TasteProfileViewModel()
@State private var smartListsVM = SmartListsViewModel()
@State private var showWhatToWatch = false
```

- [ ] **Step 3: Replace the mainContentView body**

In the `mainContentView` (or whatever the main scrollable body is called), restructure the sections in this order:

1. Taste Profile card → navigates to TasteProfileView
2. "What Should I Watch?" button → opens sheet
3. Smart Lists sections
4. Existing: Trending Movies
5. Existing: Trending Series
6. Existing: Top Rated Movies
7. Existing: Top Rated Series

Add the taste profile card before the genre browse card:

```swift
// Taste Profile
if tasteProfileVM.hasEnoughData {
    NavigationLink {
        TasteProfileView(viewModel: tasteProfileVM)
    } label: {
        TasteProfileCard(
            topGenres: tasteProfileVM.topGenres,
            tasteTags: tasteProfileVM.tasteTags,
            hasEnoughData: tasteProfileVM.hasEnoughData
        )
    }
    .buttonStyle(.plain)
    .padding(.horizontal)
}

// What Should I Watch?
if tasteProfileVM.hasEnoughData {
    Button {
        showWhatToWatch = true
    } label: {
        HStack {
            Image(systemName: "sparkle.magnifyingglass")
                .font(.title3)
            Text("What Should I Watch?")
                .font(.headline)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
        }
        .padding()
        .background(Color.plotlineCard)
        .foregroundStyle(Color.plotlineGold)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    .buttonStyle(.plain)
    .padding(.horizontal)
}

// Smart Lists
SmartListsView(viewModel: smartListsVM)
```

- [ ] **Step 4: Add the sheet and data loading**

Add to the DiscoveryView's body modifiers:

```swift
.sheet(isPresented: $showWhatToWatch) {
    WhatToWatchView()
}
```

In the `.task` modifier (or create one if it doesn't exist), add loading for taste profile and smart lists:

```swift
.task {
    await tasteProfileVM.computeProfile(
        favorites: favoritesManager.favorites,
        watchlistItems: watchlistManager.watchlistItems
    )
}
.task {
    let genreIds = tasteProfileVM.topGenres.compactMap { genre -> Int? in
        GenreLookup.genres.first(where: { $0.value == genre.genre })?.key
    }
    await smartListsVM.loadLists(
        favorites: favoritesManager.favorites,
        favoriteIds: favoritesManager.favoriteIds,
        watchlistIds: watchlistManager.watchlistIds,
        topGenreIds: genreIds
    )
}
```

- [ ] **Step 5: Add navigation destination for TasteProfileView**

Ensure `.navigationDestination` is registered for any new types if needed (TasteProfileView is pushed via NavigationLink with a closure, so no Hashable route needed).

- [ ] **Step 6: Build verification**

```bash
xcodebuild -project Plotline.xcodeproj -scheme Plotline -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath build build 2>&1 | tail -5
```

Expected: **BUILD SUCCEEDED**

- [ ] **Step 7: Commit**

```bash
git add Plotline/Views/Discovery/DiscoveryView.swift Plotline/ViewModels/DiscoveryViewModel.swift
git commit -m "feat: restructure Discovery tab with taste profile, what to watch, and smart lists"
```

---

## Task 9: Visual Comparator — ViewModel and Views

**Files:**
- Create: `Plotline/ViewModels/CompareViewModel.swift`
- Create: `Plotline/Views/Stats/CompareView.swift`
- Create: `Plotline/Views/Stats/ComparisonSlotView.swift`
- Create: `Plotline/Views/Stats/RatingComparisonBar.swift`

- [ ] **Step 1: Create CompareViewModel.swift**

```swift
import Foundation

@Observable
final class CompareViewModel {
    var slots: [MediaItem?] = [nil, nil, nil]
    var ratingsData: [Int: [RatingSource]] = [:] // mediaId -> ratings
    var episodesData: [Int: [Int: [EpisodeMetric]]] = [:] // mediaId -> seasonNum -> episodes
    var isLoadingSlot: [Int: Bool] = [:]
    var showSearch = false
    var searchSlotIndex = 0

    private let tmdbService = TMDBService.shared
    private let omdbService = OMDbService.shared

    var filledSlotCount: Int {
        slots.compactMap { $0 }.count
    }

    var canCompare: Bool {
        filledSlotCount >= 2
    }

    var filledSlots: [MediaItem] {
        slots.compactMap { $0 }
    }

    var hasAnyMovie: Bool {
        filledSlots.contains { !$0.isTVSeries }
    }

    var hasAnySeries: Bool {
        filledSlots.contains { $0.isTVSeries }
    }

    func openSearch(for index: Int) {
        searchSlotIndex = index
        showSearch = true
    }

    @MainActor
    func selectItem(_ item: MediaItem, for index: Int) async {
        guard index >= 0 && index < slots.count else { return }
        isLoadingSlot[index] = true

        do {
            // Fetch full details
            let detailed = try await tmdbService.fetchDetails(for: item)
            slots[index] = detailed

            // Fetch ratings if has IMDb ID
            if let imdbId = detailed.imdbId {
                let ratings = try await omdbService.fetchRatings(imdbId: imdbId)
                ratingsData[detailed.id] = ratings
            }

            // Fetch episodes if TV series
            if detailed.isTVSeries, let totalSeasons = detailed.totalSeasons, let imdbId = detailed.imdbId {
                var seasonEpisodes: [Int: [EpisodeMetric]] = [:]
                for season in 1...totalSeasons {
                    let episodes = try await omdbService.fetchSeasonEpisodes(imdbId: imdbId, season: season)
                    seasonEpisodes[season] = episodes
                }
                episodesData[detailed.id] = seasonEpisodes
            }
        } catch {
            slots[index] = item // Use basic item on error
        }

        isLoadingSlot[index] = false
    }

    func removeSlot(_ index: Int) {
        guard index >= 0 && index < slots.count else { return }
        if let item = slots[index] {
            ratingsData.removeValue(forKey: item.id)
            episodesData.removeValue(forKey: item.id)
        }
        slots[index] = nil
    }

    func allEpisodesFlat(for item: MediaItem) -> [EpisodeMetric] {
        guard let seasonData = episodesData[item.id] else { return [] }
        return seasonData.keys.sorted().flatMap { seasonData[$0] ?? [] }
    }
}
```

- [ ] **Step 2: Create ComparisonSlotView.swift**

```swift
import SwiftUI

/// A single slot in the comparator (empty or filled)
struct ComparisonSlotView: View {
    let item: MediaItem?
    let isLoading: Bool
    let onTap: () -> Void
    let onRemove: () -> Void

    var body: some View {
        if let item {
            VStack(spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    AsyncImage(url: item.posterURL) { image in
                        image.resizable().aspectRatio(2/3, contentMode: .fill)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.secondary.opacity(0.2))
                    }
                    .frame(height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    Button(action: onRemove) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white, .black.opacity(0.6))
                    }
                    .padding(4)
                }

                Text(item.displayTitle)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                if let year = item.year {
                    Text(year)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .onTapGesture(perform: onTap)
        } else if isLoading {
            VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.1))
                    .frame(height: 150)
                    .overlay(ProgressView().tint(Color.plotlineGold))
                Text("Loading...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else {
            VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8]))
                    .foregroundStyle(Color.secondary.opacity(0.3))
                    .frame(height: 150)
                    .overlay {
                        Image(systemName: "plus.circle.fill")
                            .font(.title)
                            .foregroundStyle(Color.plotlineGold)
                    }

                Text("Add title")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .onTapGesture(perform: onTap)
        }
    }
}
```

- [ ] **Step 3: Create RatingComparisonBar.swift**

```swift
import SwiftUI

/// Horizontal bar for comparing a single rating source across titles
struct RatingComparisonBar: View {
    let sourceName: String
    let values: [(item: MediaItem, rating: RatingSource?)]
    let colors: [Color]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(sourceName)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            ForEach(Array(values.enumerated()), id: \.element.item.id) { index, entry in
                HStack(spacing: 8) {
                    Text(entry.item.displayTitle)
                        .font(.caption2)
                        .foregroundStyle(.primary)
                        .frame(width: 80, alignment: .trailing)
                        .lineLimit(1)

                    if let rating = entry.rating {
                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(colors[index % colors.count])
                                .frame(width: geo.size.width * (rating.normalizedValue / 100))
                        }
                        .frame(height: 16)

                        Text(rating.displayValue)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                            .frame(width: 40, alignment: .leading)
                    } else {
                        Text("N/A")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }
}
```

- [ ] **Step 4: Create CompareView.swift**

```swift
import SwiftUI
import Charts

/// Main comparison screen
struct CompareView: View {
    @State private var viewModel = CompareViewModel()
    @State private var searchText = ""
    @State private var searchResults: [MediaItem] = []
    @State private var isSearching = false

    private let tmdbService = TMDBService.shared
    private let barColors: [Color] = [.plotlineGold, .plotlineSecondaryAccent, .plotlinePrimary]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                slotsRow
                if viewModel.canCompare {
                    ratingsComparison
                    if viewModel.hasAnyMovie {
                        boxOfficeComparison
                    }
                    if viewModel.hasAnySeries {
                        seriesEpisodeOverlay
                    }
                    metadataComparison
                }
            }
            .padding()
        }
        .navigationTitle("Compare")
        .background(Color.plotlineBackground)
        .sheet(isPresented: $viewModel.showSearch) {
            searchSheet
        }
    }

    // MARK: - Slots

    private var slotsRow: some View {
        HStack(spacing: 12) {
            ForEach(0..<3, id: \.self) { index in
                ComparisonSlotView(
                    item: viewModel.slots[index],
                    isLoading: viewModel.isLoadingSlot[index] ?? false,
                    onTap: { viewModel.openSearch(for: index) },
                    onRemove: { viewModel.removeSlot(index) }
                )
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Ratings

    @ViewBuilder
    private var ratingsComparison: some View {
        let items = viewModel.filledSlots
        VStack(alignment: .leading, spacing: 16) {
            Text("Ratings")
                .font(.headline)
                .foregroundStyle(.primary)

            ForEach(["TMDB", "IMDb", "Rotten Tomatoes", "Metacritic"], id: \.self) { source in
                let values = items.map { item -> (item: MediaItem, rating: RatingSource?) in
                    if source == "TMDB" {
                        let tmdbRating = RatingSource(
                            source: "TMDB",
                            value: item.formattedRating + "/10",
                            normalizedValue: item.voteAverage * 10
                        )
                        return (item: item, rating: tmdbRating)
                    }
                    let rating = viewModel.ratingsData[item.id]?.first(where: {
                        $0.source.contains(source) || source.contains($0.source)
                    })
                    return (item: item, rating: rating)
                }
                RatingComparisonBar(sourceName: source, values: values, colors: barColors)
            }
        }
        .padding()
        .background(Color.plotlineCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Box Office

    @ViewBuilder
    private var boxOfficeComparison: some View {
        let movies = viewModel.filledSlots.filter { !$0.isTVSeries && $0.boxOffice != nil }
        if !movies.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Box Office")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Chart {
                    ForEach(movies) { movie in
                        if let bo = movie.boxOffice {
                            if bo.budget > 0 {
                                BarMark(
                                    x: .value("Amount", bo.budget),
                                    y: .value("Title", movie.displayTitle)
                                )
                                .foregroundStyle(by: .value("Type", "Budget"))
                            }
                            if bo.revenue > 0 {
                                BarMark(
                                    x: .value("Amount", bo.revenue),
                                    y: .value("Title", movie.displayTitle)
                                )
                                .foregroundStyle(by: .value("Type", "Revenue"))
                            }
                        }
                    }
                }
                .chartForegroundStyleScale([
                    "Budget": Color.plotlineSecondaryAccent,
                    "Revenue": Color.plotlineGold
                ])
                .frame(height: CGFloat(movies.count) * 60 + 40)
            }
            .padding()
            .background(Color.plotlineCard)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Series Episode Overlay

    @ViewBuilder
    private var seriesEpisodeOverlay: some View {
        let seriesList = viewModel.filledSlots.filter { $0.isTVSeries }
        let hasEpisodes = seriesList.contains { !viewModel.allEpisodesFlat(for: $0).isEmpty }
        if hasEpisodes {
            VStack(alignment: .leading, spacing: 12) {
                Text("Episode Ratings")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Chart {
                    ForEach(seriesList) { series in
                        let episodes = viewModel.allEpisodesFlat(for: series)
                            .filter { $0.imdbRating > 0 }
                        ForEach(Array(episodes.enumerated()), id: \.offset) { index, ep in
                            LineMark(
                                x: .value("Episode", index + 1),
                                y: .value("Rating", ep.imdbRating)
                            )
                            .foregroundStyle(by: .value("Series", series.displayTitle))
                            .interpolationMethod(.catmullRom)
                        }
                    }
                }
                .chartYScale(domain: 0...10)
                .chartForegroundStyleScale(
                    domain: seriesList.map(\.displayTitle),
                    range: barColors
                )
                .frame(height: 200)
            }
            .padding()
            .background(Color.plotlineCard)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Metadata

    private var metadataComparison: some View {
        let items = viewModel.filledSlots
        VStack(alignment: .leading, spacing: 12) {
            Text("Details")
                .font(.headline)
                .foregroundStyle(.primary)

            // Genre overlap
            let allGenres = items.flatMap { $0.genreIds ?? [] }
            let genreCounts = Dictionary(allGenres.map { ($0, 1) }, uniquingKeysWith: +)
            let shared = genreCounts.filter { $0.value > 1 }.keys
            let sharedNames = shared.compactMap { GenreLookup.name(for: $0) }
            if !sharedNames.isEmpty {
                HStack {
                    Text("Shared genres:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(sharedNames.joined(separator: ", "))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.plotlineGold)
                }
            }
        }
        .padding()
        .background(Color.plotlineCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Search Sheet

    private var searchSheet: some View {
        NavigationStack {
            List(searchResults) { item in
                Button {
                    viewModel.showSearch = false
                    Task {
                        await viewModel.selectItem(item, for: viewModel.searchSlotIndex)
                    }
                } label: {
                    HStack {
                        AsyncImage(url: item.posterURL) { image in
                            image.resizable().aspectRatio(2/3, contentMode: .fill)
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.2))
                        }
                        .frame(width: 40, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 4))

                        VStack(alignment: .leading) {
                            Text(item.displayTitle)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                            if let year = item.year {
                                Text(year)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search movies and series")
            .onChange(of: searchText) { _, newValue in
                guard !newValue.isEmpty else {
                    searchResults = []
                    return
                }
                Task {
                    try? await Task.sleep(for: .milliseconds(500))
                    guard !Task.isCancelled else { return }
                    do {
                        searchResults = try await tmdbService.searchMulti(query: newValue)
                    } catch {
                        searchResults = []
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { viewModel.showSearch = false }
                }
            }
        }
    }
}
```

- [ ] **Step 5: Build verification**

```bash
xcodebuild -project Plotline.xcodeproj -scheme Plotline -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath build build 2>&1 | tail -5
```

Expected: **BUILD SUCCEEDED**. Check that `RatingSource` has `source`, `displayValue`, and `normalizedValue` properties — read `Plotline/Models/RatingSource.swift` to confirm and adjust property names.

- [ ] **Step 6: Commit**

```bash
git add Plotline/ViewModels/CompareViewModel.swift Plotline/Views/Stats/CompareView.swift Plotline/Views/Stats/ComparisonSlotView.swift Plotline/Views/Stats/RatingComparisonBar.swift
git commit -m "feat: add visual comparator for side-by-side movie and series comparison"
```

---

## Task 10: Career Profiles — ViewModel and Views

**Files:**
- Create: `Plotline/ViewModels/CareerProfileViewModel.swift`
- Create: `Plotline/Views/Stats/CareerProfileView.swift`
- Create: `Plotline/Views/Stats/CareerTimelineChart.swift`
- Create: `Plotline/Views/Stats/GenreDNAChart.swift`

- [ ] **Step 1: Create CareerProfileViewModel.swift**

```swift
import Foundation

@Observable
final class CareerProfileViewModel {
    var person: TMDBPersonResponse?
    var allCredits: [PersonCombinedCastCredit] = []
    var allCrewCredits: [PersonCombinedCrewCredit] = []
    var careerScore: Double = 0
    var timelinePoints: [(year: Int, avgRating: Double, titles: [String])] = []
    var topTen: [MediaItem] = []
    var genreDistribution: [(genre: String, count: Int)] = []
    var totalTitles = 0
    var mostActiveDecade: String?
    var mostFrequentGenre: String?
    var bestTitle: (name: String, rating: Double)?
    var worstTitle: (name: String, rating: Double)?
    var directorBoxOffice: [(title: String, revenue: Int)] = []
    var filmography: [(decade: String, items: [PersonCombinedCastCredit])] = []
    var filmographyFilter: FilmographyFilter = .all

    var isLoading = false
    var isDirector: Bool { person?.knownForDepartment == "Directing" }

    enum FilmographyFilter: String, CaseIterable {
        case all = "All"
        case movies = "Movies"
        case series = "Series"
    }

    private let tmdbService = TMDBService.shared

    var filteredFilmography: [(decade: String, items: [PersonCombinedCastCredit])] {
        switch filmographyFilter {
        case .all: return filmography
        case .movies:
            return filmography.compactMap { decade in
                let filtered = decade.items.filter { $0.mediaType == .movie }
                return filtered.isEmpty ? nil : (decade: decade.decade, items: filtered)
            }
        case .series:
            return filmography.compactMap { decade in
                let filtered = decade.items.filter { $0.mediaType == .tv }
                return filtered.isEmpty ? nil : (decade: decade.decade, items: filtered)
            }
        }
    }

    @MainActor
    func loadProfile(personId: Int) async {
        isLoading = true

        do {
            // Fetch person details and credits concurrently
            async let personTask = tmdbService.fetchPersonDetails(id: personId)
            async let creditsTask = tmdbService.fetchPersonCombinedCredits(personId: personId)

            let (personData, creditsData) = try await (personTask, creditsTask)
            person = personData

            // Process credits based on department
            if personData.knownForDepartment == "Directing" {
                processDirectorCredits(creditsData)
            } else {
                processActorCredits(creditsData)
            }
        } catch {
            person = nil
        }

        isLoading = false
    }

    private func processActorCredits(_ credits: TMDBPersonCombinedCreditsResponse) {
        // Filter to substantial credits (with vote count)
        let meaningful = credits.cast.filter { $0.voteCount > 10 }
        allCredits = meaningful

        totalTitles = meaningful.count

        // Career score (weighted average)
        let totalWeight = meaningful.map { Double($0.voteCount) }.reduce(0, +)
        if totalWeight > 0 {
            careerScore = meaningful.map { $0.voteAverage * Double($0.voteCount) }.reduce(0, +) / totalWeight
        }

        // Timeline
        computeTimeline(from: meaningful)

        // Top 10
        topTen = meaningful.sorted { $0.voteAverage > $1.voteAverage }
            .prefix(10)
            .map { $0.toMediaItem() }

        // Genre distribution
        computeGenreDistribution(from: meaningful.flatMap { $0.genreIds ?? [] })

        // Stats
        computeQuickStats(from: meaningful)

        // Filmography grouped by decade
        computeFilmography(from: meaningful)
    }

    private func processDirectorCredits(_ credits: TMDBPersonCombinedCreditsResponse) {
        let directorCredits = credits.crew.filter { $0.isDirector && $0.voteCount > 10 }
        allCrewCredits = directorCredits

        // Also include acting credits for the filmography
        let actingCredits = credits.cast.filter { $0.voteCount > 10 }
        allCredits = actingCredits

        let combined = directorCredits

        totalTitles = combined.count

        // Career score from directed work
        let totalWeight = combined.map { Double($0.voteCount) }.reduce(0, +)
        if totalWeight > 0 {
            careerScore = combined.map { $0.voteAverage * Double($0.voteCount) }.reduce(0, +) / totalWeight
        }

        // Timeline from directed work
        computeDirectorTimeline(from: combined)

        // Top 10
        topTen = combined.sorted { $0.voteAverage > $1.voteAverage }
            .prefix(10)
            .map { $0.toMediaItem() }

        // Genre distribution
        computeGenreDistribution(from: combined.flatMap { $0.genreIds ?? [] })

        // Stats from directed work
        computeDirectorQuickStats(from: combined)

        // Filmography — use combined cast credits for display
        computeFilmography(from: actingCredits)
    }

    private func computeTimeline(from credits: [PersonCombinedCastCredit]) {
        var yearData: [Int: [Double]] = [:]
        var yearTitles: [Int: [String]] = [:]
        for credit in credits {
            guard let year = credit.yearInt else { continue }
            yearData[year, default: []].append(credit.voteAverage)
            yearTitles[year, default: []].append(credit.displayTitle)
        }
        timelinePoints = yearData.keys.sorted().map { year in
            let ratings = yearData[year]!
            let avg = ratings.reduce(0, +) / Double(ratings.count)
            return (year: year, avgRating: avg, titles: yearTitles[year] ?? [])
        }
    }

    private func computeDirectorTimeline(from credits: [PersonCombinedCrewCredit]) {
        var yearData: [Int: [Double]] = [:]
        var yearTitles: [Int: [String]] = [:]
        for credit in credits {
            guard let year = credit.yearInt else { continue }
            yearData[year, default: []].append(credit.voteAverage)
            yearTitles[year, default: []].append(credit.displayTitle)
        }
        timelinePoints = yearData.keys.sorted().map { year in
            let ratings = yearData[year]!
            let avg = ratings.reduce(0, +) / Double(ratings.count)
            return (year: year, avgRating: avg, titles: yearTitles[year] ?? [])
        }
    }

    private func computeGenreDistribution(from genreIds: [Int]) {
        var counts: [String: Int] = [:]
        for id in genreIds {
            if let name = GenreLookup.name(for: id) {
                counts[name, default: 0] += 1
            }
        }
        genreDistribution = counts.sorted { $0.value > $1.value }.map { ($0.key, $0.value) }
        mostFrequentGenre = genreDistribution.first?.genre
    }

    private func computeQuickStats(from credits: [PersonCombinedCastCredit]) {
        // Most active decade
        var decadeCounts: [String: Int] = [:]
        for credit in credits {
            if let year = credit.yearInt {
                let decade = "\(year / 10 * 10)s"
                decadeCounts[decade, default: 0] += 1
            }
        }
        mostActiveDecade = decadeCounts.max(by: { $0.value < $1.value })?.key

        // Best and worst
        let sorted = credits.sorted { $0.voteAverage > $1.voteAverage }
        if let best = sorted.first {
            bestTitle = (name: best.displayTitle, rating: best.voteAverage)
        }
        if let worst = sorted.last, sorted.count > 1 {
            worstTitle = (name: worst.displayTitle, rating: worst.voteAverage)
        }
    }

    private func computeDirectorQuickStats(from credits: [PersonCombinedCrewCredit]) {
        var decadeCounts: [String: Int] = [:]
        for credit in credits {
            if let year = credit.yearInt {
                let decade = "\(year / 10 * 10)s"
                decadeCounts[decade, default: 0] += 1
            }
        }
        mostActiveDecade = decadeCounts.max(by: { $0.value < $1.value })?.key

        let sorted = credits.sorted { $0.voteAverage > $1.voteAverage }
        if let best = sorted.first {
            bestTitle = (name: best.displayTitle, rating: best.voteAverage)
        }
        if let worst = sorted.last, sorted.count > 1 {
            worstTitle = (name: worst.displayTitle, rating: worst.voteAverage)
        }
    }

    private func computeFilmography(from credits: [PersonCombinedCastCredit]) {
        var grouped: [String: [PersonCombinedCastCredit]] = [:]
        for credit in credits {
            let decade: String
            if let year = credit.yearInt {
                decade = "\(year / 10 * 10)s"
            } else {
                decade = "Unknown"
            }
            grouped[decade, default: []].append(credit)
        }

        filmography = grouped.keys.sorted(by: >).map { decade in
            let items = grouped[decade]!.sorted { ($0.yearInt ?? 0) > ($1.yearInt ?? 0) }
            return (decade: decade, items: items)
        }
    }
}
```

- [ ] **Step 2: Create CareerTimelineChart.swift**

```swift
import SwiftUI
import Charts

/// Line chart showing average rating per year across career
struct CareerTimelineChart: View {
    let points: [(year: Int, avgRating: Double, titles: [String])]
    @State private var selectedYear: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Career Timeline")
                .font(.headline)
                .foregroundStyle(.primary)

            if points.isEmpty {
                Text("Not enough data")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(height: 180)
            } else {
                Chart {
                    ForEach(points, id: \.year) { point in
                        LineMark(
                            x: .value("Year", point.year),
                            y: .value("Rating", point.avgRating)
                        )
                        .foregroundStyle(Color.plotlineGold)
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 2))

                        PointMark(
                            x: .value("Year", point.year),
                            y: .value("Rating", point.avgRating)
                        )
                        .foregroundStyle(
                            point.year == selectedYear ? Color.plotlinePrimary : Color.plotlineGold
                        )
                        .symbolSize(point.year == selectedYear ? 80 : 30)
                    }
                }
                .chartYScale(domain: 0...10)
                .chartXSelection(value: $selectedYear)
                .frame(height: 180)

                if let year = selectedYear,
                   let point = points.first(where: { $0.year == year }) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(year) — Avg: \(String(format: "%.1f", point.avgRating))")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                        Text(point.titles.prefix(3).joined(separator: ", "))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
    }
}
```

- [ ] **Step 3: Create GenreDNAChart.swift**

```swift
import SwiftUI
import Charts

/// Donut chart showing genre distribution
struct GenreDNAChart: View {
    let distribution: [(genre: String, count: Int)]

    private let colors: [Color] = [
        .plotlineGold, .plotlineSecondaryAccent, .plotlinePrimary,
        .rottenGreen, .metacriticGreen, .cyan, .purple, .orange
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Genre DNA")
                .font(.headline)
                .foregroundStyle(.primary)

            if distribution.isEmpty {
                Text("Not enough data")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                HStack(spacing: 16) {
                    Chart {
                        ForEach(Array(distribution.prefix(8).enumerated()), id: \.element.genre) { index, item in
                            SectorMark(
                                angle: .value("Count", item.count),
                                innerRadius: .ratio(0.6),
                                angularInset: 2
                            )
                            .foregroundStyle(colors[index % colors.count])
                        }
                    }
                    .frame(width: 140, height: 140)

                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(distribution.prefix(6).enumerated()), id: \.element.genre) { index, item in
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(colors[index % colors.count])
                                    .frame(width: 8, height: 8)
                                Text(item.genre)
                                    .font(.caption)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text("\(item.count)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }
}
```

- [ ] **Step 4: Create CareerProfileView.swift**

```swift
import SwiftUI
import Charts

/// Full career profile view for an actor or director
struct CareerProfileView: View {
    let personId: Int
    let personName: String
    @State private var viewModel = CareerProfileViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
                    .tint(Color.plotlineGold)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let person = viewModel.person {
                ScrollView {
                    VStack(spacing: 24) {
                        headerSection(person)
                        careerScoreSection
                        CareerTimelineChart(points: viewModel.timelinePoints)
                            .padding()
                            .background(Color.plotlineCard)
                            .clipShape(RoundedRectangle(cornerRadius: 16))

                        topTenSection
                        GenreDNAChart(distribution: viewModel.genreDistribution)
                            .padding()
                            .background(Color.plotlineCard)
                            .clipShape(RoundedRectangle(cornerRadius: 16))

                        quickStatsSection
                        filmographySection
                    }
                    .padding()
                }
            } else {
                ContentUnavailableView("Profile not found", systemImage: "person.crop.circle.badge.xmark")
            }
        }
        .navigationTitle(personName)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.plotlineBackground)
        .task {
            await viewModel.loadProfile(personId: personId)
            saveToRecentProfiles()
        }
    }

    /// Save this person to recent profiles in UserDefaults
    private func saveToRecentProfiles() {
        let profile = RecentCareerProfile(id: personId, name: personName, profilePath: viewModel.person?.profilePath)
        var recents: [RecentCareerProfile] = []
        if let data = UserDefaults.standard.data(forKey: "recentCareerProfiles"),
           let existing = try? JSONDecoder().decode([RecentCareerProfile].self, from: data) {
            recents = existing.filter { $0.id != personId }
        }
        recents.insert(profile, at: 0)
        recents = Array(recents.prefix(10))
        if let data = try? JSONEncoder().encode(recents) {
            UserDefaults.standard.set(data, forKey: "recentCareerProfiles")
        }
    }

    // MARK: - Header

    private func headerSection(_ person: TMDBPersonResponse) -> some View {
        HStack(alignment: .top, spacing: 16) {
            AsyncImage(url: person.profileURL) { image in
                image.resizable().aspectRatio(2/3, contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.2))
            }
            .frame(width: 100, height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 6) {
                Text(person.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)

                if let age = person.age {
                    Text(person.deathday != nil ? "Lived to \(age)" : "Age \(age)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let place = person.placeOfBirth {
                    Text(place)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                if let bio = person.biography, !bio.isEmpty {
                    Text(bio)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }
        }
        .padding()
        .background(Color.plotlineCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Career Score

    private var careerScoreSection: some View {
        HStack {
            VStack {
                Text(String(format: "%.1f", viewModel.careerScore))
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(Color.plotlineGold)
                Text("Career Score")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)

            VStack {
                Text("\(viewModel.totalTitles)")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(Color.plotlineSecondaryAccent)
                Text("Total Titles")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(Color.plotlineCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Top 10

    @ViewBuilder
    private var topTenSection: some View {
        if !viewModel.topTen.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Top 10")
                    .font(.headline)
                    .foregroundStyle(.primary)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(viewModel.topTen) { item in
                            NavigationLink(value: item) {
                                VStack(spacing: 4) {
                                    AsyncImage(url: item.posterURL) { image in
                                        image.resizable().aspectRatio(2/3, contentMode: .fill)
                                    } placeholder: {
                                        RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.2))
                                    }
                                    .frame(width: 90, height: 135)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))

                                    Text(item.displayTitle)
                                        .font(.caption2)
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)

                                    HStack(spacing: 2) {
                                        Image(systemName: "star.fill")
                                            .font(.system(size: 8))
                                            .foregroundStyle(Color.plotlineGold)
                                        Text(item.formattedRating)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .frame(width: 90)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding()
            .background(Color.plotlineCard)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Quick Stats

    private var quickStatsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick Stats")
                .font(.headline)
                .foregroundStyle(.primary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                statRow(label: "Most Active", value: viewModel.mostActiveDecade ?? "—")
                statRow(label: "Top Genre", value: viewModel.mostFrequentGenre ?? "—")
                if let best = viewModel.bestTitle {
                    statRow(label: "Best Rated", value: "\(best.name) (\(String(format: "%.1f", best.rating)))")
                }
                if let worst = viewModel.worstTitle {
                    statRow(label: "Lowest Rated", value: "\(worst.name) (\(String(format: "%.1f", worst.rating)))")
                }
            }
        }
        .padding()
        .background(Color.plotlineCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func statRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Filmography

    private var filmographySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Filmography")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Picker("Filter", selection: $viewModel.filmographyFilter) {
                    ForEach(CareerProfileViewModel.FilmographyFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }

            ForEach(viewModel.filteredFilmography, id: \.decade) { group in
                Section {
                    ForEach(group.items) { credit in
                        NavigationLink(value: credit.toMediaItem()) {
                            HStack(spacing: 10) {
                                AsyncImage(url: credit.posterURL) { image in
                                    image.resizable().aspectRatio(2/3, contentMode: .fill)
                                } placeholder: {
                                    RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.2))
                                }
                                .frame(width: 36, height: 54)
                                .clipShape(RoundedRectangle(cornerRadius: 4))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(credit.displayTitle)
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                    if let year = credit.year {
                                        Text(year)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()

                                HStack(spacing: 2) {
                                    Image(systemName: "star.fill")
                                        .font(.caption2)
                                        .foregroundStyle(Color.plotlineGold)
                                    Text(credit.formattedRating)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text(group.decade)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.plotlineSecondaryAccent)
                }
            }
        }
        .padding()
        .background(Color.plotlineCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
```

- [ ] **Step 5: Build verification**

```bash
xcodebuild -project Plotline.xcodeproj -scheme Plotline -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath build build 2>&1 | tail -5
```

Expected: **BUILD SUCCEEDED**

- [ ] **Step 6: Commit**

```bash
git add Plotline/ViewModels/CareerProfileViewModel.swift Plotline/Views/Stats/CareerProfileView.swift Plotline/Views/Stats/CareerTimelineChart.swift Plotline/Views/Stats/GenreDNAChart.swift
git commit -m "feat: add career profiles with timeline, genre DNA, filmography, and stats"
```

---

## Task 11: Trend Explorer — All Four Sub-Features

**Files:**
- Create: `Plotline/ViewModels/GenreEvolutionViewModel.swift`
- Create: `Plotline/ViewModels/BestYearsViewModel.swift`
- Create: `Plotline/ViewModels/DecadeBattleViewModel.swift`
- Create: `Plotline/ViewModels/FranchiseTrackerViewModel.swift`
- Create: `Plotline/Views/Stats/GenreEvolutionView.swift`
- Create: `Plotline/Views/Stats/BestYearsView.swift`
- Create: `Plotline/Views/Stats/DecadeBattleView.swift`
- Create: `Plotline/Views/Stats/FranchiseTrackerView.swift`
- Create: `Plotline/Views/Stats/TrendsView.swift`

- [ ] **Step 1: Create GenreEvolutionViewModel.swift**

```swift
import Foundation

@Observable
final class GenreEvolutionViewModel {
    var points: [(year: Int, avgRating: Double)] = []
    var selectedGenreId: Int?
    var isLoading = false

    private let tmdbService = TMDBService.shared
    private var cache: [Int: [(year: Int, avgRating: Double)]] = [:]

    @MainActor
    func loadEvolution(genreId: Int) async {
        selectedGenreId = genreId

        if let cached = cache[genreId] {
            points = cached
            return
        }

        isLoading = true
        points = []

        let currentYear = Calendar.current.component(.year, from: Date())
        let startYear = currentYear - 49
        var results: [(year: Int, avgRating: Double)] = []

        // Fetch in batches of 10 years concurrently
        await withTaskGroup(of: (Int, Double)?.self) { group in
            for year in stride(from: startYear, through: currentYear, by: 1) {
                group.addTask {
                    let params: [String: String] = [
                        "with_genres": "\(genreId)",
                        "primary_release_year": "\(year)",
                        "sort_by": "vote_count.desc",
                        "vote_count.gte": "100"
                    ]
                    do {
                        let response = try await self.tmdbService.discoverMovies(params: params)
                        let ratings = response.results.prefix(20).map(\.voteAverage)
                        guard !ratings.isEmpty else { return nil }
                        let avg = ratings.reduce(0, +) / Double(ratings.count)
                        return (year, avg)
                    } catch {
                        return nil
                    }
                }
            }

            for await result in group {
                if let result { results.append(result) }
            }
        }

        let sorted = results.sorted { $0.year < $1.year }
        points = sorted
        cache[genreId] = sorted
        isLoading = false
    }
}
```

- [ ] **Step 2: Create BestYearsViewModel.swift**

```swift
import Foundation

@Observable
final class BestYearsViewModel {
    var yearRatings: [(year: Int, avgRating: Double)] = []
    var selectedGenreId: Int? // nil = all genres
    var isLoading = false

    private let tmdbService = TMDBService.shared
    private var cache: [String: [(year: Int, avgRating: Double)]] = [:]

    @MainActor
    func loadBestYears(genreId: Int? = nil) async {
        selectedGenreId = genreId
        let cacheKey = genreId.map(String.init) ?? "all"

        if let cached = cache[cacheKey] {
            yearRatings = cached
            return
        }

        isLoading = true
        yearRatings = []

        let currentYear = Calendar.current.component(.year, from: Date())
        let startYear = currentYear - 29
        var results: [(year: Int, avgRating: Double)] = []

        await withTaskGroup(of: (Int, Double)?.self) { group in
            for year in startYear...currentYear {
                group.addTask {
                    var params: [String: String] = [
                        "primary_release_year": "\(year)",
                        "sort_by": "vote_average.desc",
                        "vote_count.gte": "200"
                    ]
                    if let genreId {
                        params["with_genres"] = "\(genreId)"
                    }
                    do {
                        let response = try await self.tmdbService.discoverMovies(params: params)
                        let ratings = response.results.prefix(20).map(\.voteAverage)
                        guard !ratings.isEmpty else { return nil }
                        let avg = ratings.reduce(0, +) / Double(ratings.count)
                        return (year, avg)
                    } catch {
                        return nil
                    }
                }
            }

            for await result in group {
                if let result { results.append(result) }
            }
        }

        let sorted = results.sorted { $0.avgRating > $1.avgRating }
        yearRatings = sorted
        cache[cacheKey] = sorted
        isLoading = false
    }
}
```

- [ ] **Step 3: Create DecadeBattleViewModel.swift**

```swift
import Foundation

@Observable
final class DecadeBattleViewModel {
    var decades: [(decade: String, avgRating: Double, highRatedCount: Int, topGenre: String)] = []
    var isLoading = false

    private let tmdbService = TMDBService.shared

    @MainActor
    func loadDecades() async {
        isLoading = true

        let decadeRanges: [(String, Int, Int)] = [
            ("1970s", 1970, 1979),
            ("1980s", 1980, 1989),
            ("1990s", 1990, 1999),
            ("2000s", 2000, 2009),
            ("2010s", 2010, 2019),
            ("2020s", 2020, 2029),
        ]

        var results: [(decade: String, avgRating: Double, highRatedCount: Int, topGenre: String)] = []

        await withTaskGroup(of: (String, Double, Int, String)?.self) { group in
            for (name, start, end) in decadeRanges {
                group.addTask {
                    let params: [String: String] = [
                        "primary_release_date.gte": "\(start)-01-01",
                        "primary_release_date.lte": "\(end)-12-31",
                        "sort_by": "vote_average.desc",
                        "vote_count.gte": "500"
                    ]
                    do {
                        let response = try await self.tmdbService.discoverMovies(params: params)
                        let items = response.results.prefix(50)
                        guard !items.isEmpty else { return nil }

                        let avg = items.map(\.voteAverage).reduce(0, +) / Double(items.count)
                        let highRated = items.filter { $0.voteAverage >= 8.0 }.count

                        // Find top genre
                        var genreCounts: [Int: Int] = [:]
                        for item in items {
                            for gid in item.genreIds ?? [] {
                                genreCounts[gid, default: 0] += 1
                            }
                        }
                        let topGenreId = genreCounts.max(by: { $0.value < $1.value })?.key ?? 0
                        let topGenre = GenreLookup.name(for: topGenreId) ?? "Various"

                        return (name, avg, highRated, topGenre)
                    } catch {
                        return nil
                    }
                }
            }

            for await result in group {
                if let result { results.append(result) }
            }
        }

        decades = results.sorted { $0.decade < $1.decade }
        isLoading = false
    }
}
```

- [ ] **Step 4: Create FranchiseTrackerViewModel.swift**

```swift
import Foundation

@Observable
final class FranchiseTrackerViewModel {
    var searchText = ""
    var searchResults: [TMDBCollectionSearchResult] = []
    var selectedCollection: TMDBCollectionResponse?
    var movies: [CollectionMovie] = []
    var isSearching = false
    var isLoadingCollection = false

    private let tmdbService = TMDBService.shared
    private var searchTask: Task<Void, Never>?

    func search() {
        searchTask?.cancel()
        guard !searchText.isEmpty else {
            searchResults = []
            return
        }

        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            isSearching = true
            do {
                let response = try await tmdbService.searchCollections(query: searchText)
                if !Task.isCancelled {
                    await MainActor.run {
                        searchResults = response.results
                        isSearching = false
                    }
                }
            } catch {
                if !Task.isCancelled {
                    await MainActor.run {
                        searchResults = []
                        isSearching = false
                    }
                }
            }
        }
    }

    @MainActor
    func selectCollection(_ result: TMDBCollectionSearchResult) async {
        isLoadingCollection = true
        do {
            let collection = try await tmdbService.fetchCollection(id: result.id)
            selectedCollection = collection
            movies = collection.parts
                .filter { $0.releaseDate != nil }
                .sorted { ($0.yearInt ?? 0) < ($1.yearInt ?? 0) }
        } catch {
            selectedCollection = nil
            movies = []
        }
        isLoadingCollection = false
    }
}
```

- [ ] **Step 5: Create GenreEvolutionView.swift**

```swift
import SwiftUI
import Charts

struct GenreEvolutionView: View {
    @State private var viewModel = GenreEvolutionViewModel()
    private let genres = CuratedGenre.all

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Genre chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(genres) { genre in
                            let isSelected = viewModel.selectedGenreId == genre.movieGenreId
                            Button {
                                Task { await viewModel.loadEvolution(genreId: genre.movieGenreId) }
                            } label: {
                                Text(genre.name)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(isSelected ? Color.plotlineGold : Color.plotlineCard)
                                    .foregroundStyle(isSelected ? .black : .primary)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                if viewModel.isLoading {
                    ProgressView().tint(Color.plotlineGold).frame(height: 250)
                } else if !viewModel.points.isEmpty {
                    Chart {
                        ForEach(viewModel.points, id: \.year) { point in
                            LineMark(
                                x: .value("Year", point.year),
                                y: .value("Avg Rating", point.avgRating)
                            )
                            .foregroundStyle(Color.plotlineGold)
                            .interpolationMethod(.catmullRom)

                            PointMark(
                                x: .value("Year", point.year),
                                y: .value("Avg Rating", point.avgRating)
                            )
                            .foregroundStyle(Color.plotlineGold)
                            .symbolSize(20)
                        }
                    }
                    .chartYScale(domain: 4...9)
                    .frame(height: 250)
                    .padding()
                } else {
                    ContentUnavailableView("Select a genre", systemImage: "film.stack")
                        .frame(height: 250)
                }
            }
        }
        .navigationTitle("Genre Evolution")
        .background(Color.plotlineBackground)
    }
}
```

- [ ] **Step 6: Create BestYearsView.swift**

```swift
import SwiftUI
import Charts

struct BestYearsView: View {
    @State private var viewModel = BestYearsViewModel()
    private let genres = CuratedGenre.all

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Button {
                            Task { await viewModel.loadBestYears() }
                        } label: {
                            Text("All")
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(viewModel.selectedGenreId == nil ? Color.plotlineGold : Color.plotlineCard)
                                .foregroundStyle(viewModel.selectedGenreId == nil ? .black : .primary)
                                .clipShape(Capsule())
                        }

                        ForEach(genres) { genre in
                            let isSelected = viewModel.selectedGenreId == genre.movieGenreId
                            Button {
                                Task { await viewModel.loadBestYears(genreId: genre.movieGenreId) }
                            } label: {
                                Text(genre.name)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(isSelected ? Color.plotlineGold : Color.plotlineCard)
                                    .foregroundStyle(isSelected ? .black : .primary)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                if viewModel.isLoading {
                    ProgressView().tint(Color.plotlineGold).frame(height: 300)
                } else if !viewModel.yearRatings.isEmpty {
                    let sorted = viewModel.yearRatings.sorted { $0.year < $1.year }
                    Chart {
                        ForEach(sorted, id: \.year) { entry in
                            BarMark(
                                x: .value("Year", String(entry.year)),
                                y: .value("Rating", entry.avgRating)
                            )
                            .foregroundStyle(
                                entry == sorted.max(by: { $0.avgRating < $1.avgRating })
                                    ? Color.plotlineGold : Color.plotlineSecondaryAccent.opacity(0.7)
                            )
                        }
                    }
                    .chartYScale(domain: 5...9)
                    .frame(height: 300)
                    .padding()
                } else {
                    ContentUnavailableView("Select a filter", systemImage: "calendar")
                        .frame(height: 300)
                }
            }
        }
        .navigationTitle("Best Years")
        .background(Color.plotlineBackground)
        .task {
            await viewModel.loadBestYears()
        }
    }
}
```

- [ ] **Step 7: Create DecadeBattleView.swift**

```swift
import SwiftUI
import Charts

struct DecadeBattleView: View {
    @State private var viewModel = DecadeBattleViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if viewModel.isLoading {
                    ProgressView().tint(Color.plotlineGold).frame(height: 300)
                } else if !viewModel.decades.isEmpty {
                    // Rating comparison
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Average Rating")
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Chart {
                            ForEach(viewModel.decades, id: \.decade) { entry in
                                BarMark(
                                    x: .value("Decade", entry.decade),
                                    y: .value("Rating", entry.avgRating)
                                )
                                .foregroundStyle(Color.plotlineGold)
                            }
                        }
                        .chartYScale(domain: 5...9)
                        .frame(height: 200)
                    }
                    .padding()
                    .background(Color.plotlineCard)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    // High rated count
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Films Rated 8.0+")
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Chart {
                            ForEach(viewModel.decades, id: \.decade) { entry in
                                BarMark(
                                    x: .value("Decade", entry.decade),
                                    y: .value("Count", entry.highRatedCount)
                                )
                                .foregroundStyle(Color.plotlineSecondaryAccent)
                            }
                        }
                        .frame(height: 200)
                    }
                    .padding()
                    .background(Color.plotlineCard)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    // Dominant genres table
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Dominant Genre per Decade")
                            .font(.headline)
                            .foregroundStyle(.primary)

                        ForEach(viewModel.decades, id: \.decade) { entry in
                            HStack {
                                Text(entry.decade)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text(entry.topGenre)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(Color.plotlineCard)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding()
        }
        .navigationTitle("Decade Battle")
        .background(Color.plotlineBackground)
        .task {
            await viewModel.loadDecades()
        }
    }
}
```

- [ ] **Step 8: Create FranchiseTrackerView.swift**

```swift
import SwiftUI
import Charts

struct FranchiseTrackerView: View {
    @State private var viewModel = FranchiseTrackerViewModel()

    var body: some View {
        VStack(spacing: 0) {
            if let collection = viewModel.selectedCollection {
                // Show franchise chart
                ScrollView {
                    VStack(spacing: 16) {
                        Text(collection.name)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)

                        if viewModel.movies.count >= 2 {
                            Chart {
                                ForEach(viewModel.movies) { movie in
                                    LineMark(
                                        x: .value("Title", movie.title),
                                        y: .value("Rating", movie.voteAverage)
                                    )
                                    .foregroundStyle(Color.plotlineGold)
                                    .interpolationMethod(.catmullRom)

                                    PointMark(
                                        x: .value("Title", movie.title),
                                        y: .value("Rating", movie.voteAverage)
                                    )
                                    .foregroundStyle(Color.plotlineGold)
                                    .annotation(position: .top) {
                                        Text(movie.formattedRating)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .chartYScale(domain: 0...10)
                            .chartXAxis {
                                AxisMarks(values: .automatic) { value in
                                    AxisValueLabel {
                                        if let title = value.as(String.self) {
                                            Text(title)
                                                .font(.caption2)
                                                .lineLimit(1)
                                                .rotationEffect(.degrees(-45))
                                        }
                                    }
                                }
                            }
                            .frame(height: 250)
                            .padding()
                        }

                        // Movie list
                        ForEach(viewModel.movies) { movie in
                            NavigationLink(value: movie.toMediaItem()) {
                                HStack(spacing: 12) {
                                    AsyncImage(url: movie.posterURL) { image in
                                        image.resizable().aspectRatio(2/3, contentMode: .fill)
                                    } placeholder: {
                                        RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.2))
                                    }
                                    .frame(width: 50, height: 75)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(movie.title)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundStyle(.primary)
                                        Text(movie.year ?? "—")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    HStack(spacing: 2) {
                                        Image(systemName: "star.fill")
                                            .font(.caption)
                                            .foregroundStyle(Color.plotlineGold)
                                        Text(movie.formattedRating)
                                            .font(.subheadline)
                                            .foregroundStyle(.primary)
                                    }
                                }
                                .padding(.horizontal)
                            }
                            .buttonStyle(.plain)
                        }

                        Button("Search Another") {
                            viewModel.selectedCollection = nil
                            viewModel.movies = []
                        }
                        .padding()
                    }
                }
            } else {
                // Search view
                List(viewModel.searchResults) { result in
                    Button {
                        Task { await viewModel.selectCollection(result) }
                    } label: {
                        HStack {
                            AsyncImage(url: result.posterURL) { image in
                                image.resizable().aspectRatio(2/3, contentMode: .fill)
                            } placeholder: {
                                RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.2))
                            }
                            .frame(width: 40, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 4))

                            Text(result.name)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                        }
                    }
                }
                .overlay {
                    if viewModel.isLoadingCollection {
                        ProgressView().tint(Color.plotlineGold)
                    } else if viewModel.searchResults.isEmpty && !viewModel.searchText.isEmpty && !viewModel.isSearching {
                        ContentUnavailableView("No franchises found", systemImage: "film.stack")
                    } else if viewModel.searchText.isEmpty {
                        ContentUnavailableView("Search for a franchise", systemImage: "magnifyingglass",
                            description: Text("e.g. Marvel, Harry Potter, Star Wars"))
                    }
                }
            }
        }
        .navigationTitle("Franchise Tracker")
        .background(Color.plotlineBackground)
        .searchable(text: $viewModel.searchText, prompt: "Search franchises")
        .onChange(of: viewModel.searchText) { _, _ in
            viewModel.search()
        }
    }
}
```

- [ ] **Step 9: Create TrendsView.swift**

```swift
import SwiftUI

/// Hub view with 2x2 grid of trend exploration cards
struct TrendsView: View {
    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            NavigationLink {
                GenreEvolutionView()
            } label: {
                trendCard(
                    title: "Genre Evolution",
                    subtitle: "How genres change over time",
                    icon: "chart.line.uptrend.xyaxis",
                    color: .plotlineGold
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                BestYearsView()
            } label: {
                trendCard(
                    title: "Best Years",
                    subtitle: "Top years for cinema",
                    icon: "trophy.fill",
                    color: .plotlineSecondaryAccent
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                DecadeBattleView()
            } label: {
                trendCard(
                    title: "Decade Battle",
                    subtitle: "Compare decades head-to-head",
                    icon: "square.stack.3d.up.fill",
                    color: .plotlinePrimary
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                FranchiseTrackerView()
            } label: {
                trendCard(
                    title: "Franchise Tracker",
                    subtitle: "Track franchise quality",
                    icon: "film.stack",
                    color: .rottenGreen
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func trendCard(title: String, subtitle: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.plotlineCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
```

- [ ] **Step 10: Build verification**

```bash
xcodebuild -project Plotline.xcodeproj -scheme Plotline -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath build build 2>&1 | tail -5
```

Expected: **BUILD SUCCEEDED**

- [ ] **Step 11: Commit**

```bash
git add Plotline/ViewModels/GenreEvolutionViewModel.swift Plotline/ViewModels/BestYearsViewModel.swift Plotline/ViewModels/DecadeBattleViewModel.swift Plotline/ViewModels/FranchiseTrackerViewModel.swift Plotline/Views/Stats/GenreEvolutionView.swift Plotline/Views/Stats/BestYearsView.swift Plotline/Views/Stats/DecadeBattleView.swift Plotline/Views/Stats/FranchiseTrackerView.swift Plotline/Views/Stats/TrendsView.swift
git commit -m "feat: add trend explorer with genre evolution, best years, decade battle, and franchise tracker"
```

---

## Task 12: Restructure Stats Tab

**Files:**
- Modify: `Plotline/Views/Stats/StatsView.swift`
- Modify: `Plotline/Views/Detail/MediaDetailView.swift`

- [ ] **Step 1: Read current StatsView.swift**

Read the full current content to understand the existing layout.

- [ ] **Step 1b: Add recent profiles state to StatsView**

Add to StatsView:

```swift
@State private var recentProfiles: [RecentCareerProfile] = []

struct RecentCareerProfile: Codable, Identifiable {
    let id: Int
    let name: String
    let profilePath: String?
}
```

Load from UserDefaults on appear:

```swift
.onAppear {
    if let data = UserDefaults.standard.data(forKey: "recentCareerProfiles"),
       let profiles = try? JSONDecoder().decode([RecentCareerProfile].self, from: data) {
        recentProfiles = profiles
    }
}
```

- [ ] **Step 1c: Create CareerSearchView**

Create `Plotline/Views/Stats/CareerSearchView.swift` — a simple view with searchable people list that navigates to CareerProfileView. Uses TMDB `/search/person` (add this endpoint to TMDBService if not already present — use `searchMulti` filtered to `.person` type, or add a dedicated `searchPeople` method).

```swift
import SwiftUI

struct CareerSearchView: View {
    @State private var searchText = ""
    @State private var results: [CastMember] = [] // reuse CastMember as person result
    private let tmdbService = TMDBService.shared

    var body: some View {
        List(results) { person in
            NavigationLink {
                CareerProfileView(personId: person.id, personName: person.name)
            } label: {
                HStack {
                    AsyncImage(url: person.profileURL) { image in
                        image.resizable().aspectRatio(1, contentMode: .fill)
                    } placeholder: {
                        Circle().fill(Color.secondary.opacity(0.2))
                    }
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())

                    Text(person.name)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }
            }
        }
        .navigationTitle("Search People")
        .searchable(text: $searchText, prompt: "Actor or director name")
        .onChange(of: searchText) { _, newValue in
            Task {
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled, !newValue.isEmpty else { return }
                do {
                    let items = try await tmdbService.searchMulti(query: newValue)
                    // searchMulti filters to movies/TV — need person search
                    // Use a raw fetch or add searchPeople endpoint
                    // For now, use credits search as workaround
                } catch {}
            }
        }
    }
}
```

**Note:** Add `func searchPeople(query:) async throws -> [TMDBPersonSearchResult]` to TMDBService using `/search/person` endpoint. Create `TMDBPersonSearchResult` in TMDBResponse.swift:

```swift
struct TMDBPersonSearchResponse: Codable {
    let page: Int
    let results: [TMDBPersonSearchResult]
}

struct TMDBPersonSearchResult: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let profilePath: String?
    let knownForDepartment: String?

    var profileURL: URL? {
        TMDBService.profileURL(path: profilePath)
    }
}
```

And in TMDBService:
```swift
func searchPeople(query: String, page: Int = 1) async throws -> [TMDBPersonSearchResult] {
    guard !query.isEmpty else { return [] }
    guard let url = buildURL(path: "/search/person", additionalParams: ["query": query, "page": "\(page)"]) else {
        throw NetworkError.invalidURL
    }
    let response: TMDBPersonSearchResponse = try await networkManager.fetch(TMDBPersonSearchResponse.self, from: url)
    return response.results
}
```

- [ ] **Step 2: Add new sections to StatsView.swift**

After the existing stats sections (average ratings — the last current section), add three new sections:

```swift
// MARK: - Compare Section

VStack(alignment: .leading, spacing: 12) {
    Text("Compare")
        .font(.headline)
        .foregroundStyle(.primary)

    NavigationLink {
        CompareView()
    } label: {
        HStack {
            Image(systemName: "square.split.2x1.fill")
                .font(.title3)
                .foregroundStyle(Color.plotlineSecondaryAccent)
            VStack(alignment: .leading) {
                Text("Compare Movies & Series")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                Text("Side-by-side ratings, box office, and more")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color.plotlineCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    .buttonStyle(.plain)
}

// MARK: - Career Profiles Section

VStack(alignment: .leading, spacing: 12) {
    Text("Career Profiles")
        .font(.headline)
        .foregroundStyle(.primary)

    // People search bar
    NavigationLink {
        CareerSearchView()
    } label: {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            Text("Search actors and directors...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding()
        .background(Color.plotlineCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    .buttonStyle(.plain)

    // Recent profiles (from UserDefaults)
    if !recentProfiles.isEmpty {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(recentProfiles, id: \.id) { profile in
                    NavigationLink {
                        CareerProfileView(personId: profile.id, personName: profile.name)
                    } label: {
                        VStack(spacing: 4) {
                            AsyncImage(url: TMDBService.profileURL(path: profile.profilePath)) { image in
                                image.resizable().aspectRatio(1, contentMode: .fill)
                            } placeholder: {
                                Circle().fill(Color.secondary.opacity(0.2))
                            }
                            .frame(width: 56, height: 56)
                            .clipShape(Circle())
                            Text(profile.name)
                                .font(.caption2)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                        }
                        .frame(width: 70)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Trends Section

VStack(alignment: .leading, spacing: 12) {
    Text("Trends")
        .font(.headline)
        .foregroundStyle(.primary)

    TrendsView()
}
```

- [ ] **Step 3: Ensure NavigationStack wraps StatsView**

Confirm that StatsView is inside a `NavigationStack` (it should be, from the existing tab setup). If not, wrap the content. Add navigation destinations for `MediaItem` so that tapping items in career profiles or trends can navigate to detail views:

```swift
.navigationDestination(for: MediaItem.self) { item in
    MediaDetailView(media: item)
}
```

- [ ] **Step 4: Add career profile navigation from MediaDetailView**

In `MediaDetailView.swift`, find where cast members are displayed. Make actor and director names tappable to navigate to `CareerProfileView`. Look for where `CastMember` or `CrewMember` names are shown and wrap them in NavigationLinks:

For cast members, find the existing display and add:

```swift
NavigationLink {
    CareerProfileView(personId: castMember.id, personName: castMember.name)
} label: {
    // existing cast member display
}
```

For the director in FilmographyView, add similar navigation.

Also add a "Compare" button to the MediaDetailView toolbar (or action section):

```swift
// In toolbar or as a button in the detail view
Button {
    // Navigate to CompareView with this item pre-loaded
    // This can be implemented via a binding or environment
} label: {
    Image(systemName: "square.split.2x1")
}
```

- [ ] **Step 5: Build verification**

```bash
xcodebuild -project Plotline.xcodeproj -scheme Plotline -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath build build 2>&1 | tail -5
```

Expected: **BUILD SUCCEEDED**

- [ ] **Step 6: Commit**

```bash
git add Plotline/Views/Stats/StatsView.swift Plotline/Views/Detail/MediaDetailView.swift
git commit -m "feat: restructure Stats tab with Compare, Career Profiles, and Trends sections"
```

---

## Task 13: Final Build Verification and Cleanup

**Files:**
- Potentially any file with build errors

- [ ] **Step 1: Full clean build**

```bash
xcodebuild -project Plotline.xcodeproj -scheme Plotline clean 2>&1 | tail -3
xcodebuild -project Plotline.xcodeproj -scheme Plotline -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath build build 2>&1 | tail -20
```

Expected: **BUILD SUCCEEDED**

- [ ] **Step 2: Check for warnings**

```bash
xcodebuild -project Plotline.xcodeproj -scheme Plotline -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath build build 2>&1 | grep -i "warning:"
```

Fix any warnings in new files.

- [ ] **Step 3: Run the app in simulator to verify navigation**

```bash
xcodebuild -project Plotline.xcodeproj -scheme Plotline -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath build build && \
xcrun simctl install booted build/Build/Products/Debug-iphonesimulator/Plotline.app && \
xcrun simctl launch booted com.jbgsoft.Plotline
```

Verify:
1. Discovery tab shows taste profile card (if ≥5 favorites)
2. "What Should I Watch?" button is visible
3. Smart lists load below
4. Stats tab shows My Stats + Compare + Career Profiles + Trends
5. Compare flow works (search, select, compare)
6. Trends cards navigate to sub-views
7. No crashes on launch

- [ ] **Step 4: Final commit if any fixes were needed**

```bash
git add -A
git commit -m "fix: resolve build warnings and navigation issues"
```
