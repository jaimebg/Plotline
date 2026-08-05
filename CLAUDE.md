# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Plotline is an iOS app for exploring movies and TV series. It sources all metadata and ratings from TMDB, and its own analysis engine derives things TMDB does not publish: where a series declines, how consistent it is, which episodes stand out, and a 0-100 Plotline Score. Every verdict is shown with the numbers behind it.

That distinction matters when working here. The app is not a TMDB catalogue browser; the derived analysis is the product, and it is the standing answer to three App Store rejections under Guideline 4.2. Changes that bury it, or that state more than the engine can support, undo the point.

**Target:** iOS 26+, iPhone and iPad, SwiftUI

### Notable SwiftUI Features Used
- **Tab struct** - Modern tab navigation with `Tab("Title", systemImage:value:)` syntax
- **Symbol effects** - `.symbolEffect(.pulse)`, `.symbolEffect(.bounce)`, `.symbolEffect(.rotate)`
- **Type-safe tab selection** - `AppTab` enum with `TabView(selection:)`

## Build Commands

```bash
# Build and run in simulator (no Xcode needed)
xcodebuild -project Plotline.xcodeproj -scheme Plotline -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath build build && \
xcrun simctl install booted build/Build/Products/Debug-iphonesimulator/Plotline.app && \
xcrun simctl launch booted com.jbgsoft.Plotline

# Run tests — Swift Testing, 147 of them
xcodebuild -project Plotline.xcodeproj -scheme Plotline -destination 'platform=iOS Simulator,name=iPhone 17' test

# Build for iPad — the device App Review used
xcodebuild -project Plotline.xcodeproj -scheme Plotline -destination 'platform=iOS Simulator,name=iPad Air 11-inch (M4)' -derivedDataPath build build

# The dataset generator's own suite
cd Tools/DatasetGenerator && swift test

# Everything that has to be true before a release
./Scripts/release-preflight.sh

# Clean build
xcodebuild -project Plotline.xcodeproj -scheme Plotline clean && rm -rf build
```

Open in Xcode: `open Plotline.xcodeproj`

## Architecture

### TMDB: Single Source of Data
The app sources all metadata, images, and ratings from a single API:

**TMDB** - Visual data, metadata, trending/popular content, vote averages, and episode-by-episode ratings (via the season endpoint, used for the SeriesGraph)

Flow: User action → TMDB fetch → Render

Episode payloads are cached on disk (`DiskCache`) because a long-running series burns a lot of requests against TMDB's rate limit.

### Key Components

**Services Layer** (`Services/`)
- `NetworkManager` - Swift Actor for thread-safe async networking with `URLSession`
- `TMDBService` - TMDB API wrapper (trending, popular, search, details, credits, season episodes, watch providers)
- `DiskCache` - Generic on-disk cache used to avoid redundant network calls
- `Analysis/SeriesAnalysisEngine` - Pure function over episode ratings. Foundation only, no networking, no I/O
- `DatasetStore` - Reads the bundled dataset. `@MainActor`, deliberately not `@Observable`
- `WatchRegionStore` - Which region's streaming availability to show. `@MainActor`, same shape as `DatasetStore`

**Models** (`Models/`)
- `MediaItem` - Unified model for movies and TV series with computed properties for URLs and display values
- `EpisodeMetric` - Episode data (sourced from TMDB's season endpoint) for Swift Charts visualization
- `SeriesAnalysis` - The engine's output: decline point, consistency, standout episodes, opening and ending verdicts, Plotline Score
- `PlotlineDataset` - The contract between the app and the dataset generator
- `APIResponses/` - TMDB response wrappers with decoding

### The Analysis Engine

`SeriesAnalysisEngine.analyze(episodes:hasEnded:asOf:)` is a pure function: same inputs, same output, no clock, no network. It refuses to judge rather than guess — an unreliable series yields `.insufficientData` with a reason, and the UI states that reason rather than inventing a softer verdict.

**Two rules that have each caused a shipped defect:**
- `isOngoing == false` means "ended **or** unknown". It must never render as "Ended".
- **No string may claim more than its predicate establishes.** Six pieces of copy have been rewritten for breaking this. The decline point proves a relative fall that does not recover; it proves nothing about how good the show was before. An episode far below its season's average is not "safe to skip".

### Shared With the Dataset Generator

Four files under `Plotline/` are also compiled by the SwiftPM tool in `Tools/DatasetGenerator/`, via symlinks in `Sources/DatasetGeneratorCore/Shared/`:

`Models/EpisodeMetric.swift`, `Models/SeriesAnalysis.swift`, `Models/PlotlineDataset.swift`, `Services/Analysis/SeriesAnalysisEngine.swift`

**They may import only `Foundation`.** A reference to `TMDBService`, `NetworkManager` or SwiftUI in any of them breaks the generator's build. The originals live in `Plotline/`; the copies in `Tools/` are symlinks.

### The Bundled Dataset

`Resources/PlotlineDataset.json` ships 122 pre-analysed series and five curated lists. It is a **seed and a fallback, never the truth**: the app shows it in the first frame and offline, and a live recomputation replaces it as soon as fresher episodes arrive — but only when the live result is at least as complete, so a partial fetch cannot replace a full analysis with a fragment.

Regenerate with the tool in `Tools/DatasetGenerator/`. It has its own test suite (`swift test`).

### Watch Providers — a blocking legal requirement

TMDB's terms for the watch-providers endpoint: *"In order to use this data you must attribute the source of the data as JustWatch"* and *"If we find any usage not complying with these terms we will revoke access to the API."*

Every screen in this app is served by TMDB. Losing that access does not degrade a feature, it ends the product. `WatchProvidersSection` draws the credit in the same `VStack` as the providers so no call site can separate them, and `WatchAttributionSourceTests` reads that view's own source to confirm the line survives. Do not move, wrap, or condition it.

**Key Design Patterns:**
- Models use snake_case decoding via `JSONDecoder.keyDecodingStrategy = .convertFromSnakeCase`
- Preview data is included in model extensions for SwiftUI previews

### State Management
Use `@Observable` macro (iOS 17+) for ViewModels, not `@ObservableObject`.

### Color System
Brand colors defined in `Extensions/Color+Plotline.swift`:
- Rating colors: `.imdbYellow`, `.rottenRed`, `.rottenGreen`, `.metacriticGreen/Yellow/Red`
- Chart colors: `.chartHigh`, `.chartMedium`, `.chartLow`
- Use `Color(hex:)` initializer for hex colors

## API Keys

API keys are loaded from `Plotline/Secrets.plist` (bundled) or environment variables (fallback).

**For command-line builds (xcodebuild/xcrun):**
Edit `Plotline/Secrets.plist` with your keys:
```xml
<dict>
    <key>TMDB_API_KEY</key>
    <string>your_tmdb_key</string>
</dict>
```

**For Xcode builds:**
Either use the plist above, or set environment variables in the scheme (Product → Scheme → Edit Scheme → Run → Arguments → Environment Variables).

Keys:
- `TMDB_API_KEY` - Required for all content

Note: `Secrets.plist` is gitignored to protect API keys.

## SeriesGraph Feature

The star feature uses Swift Charts to visualize episode ratings:
- Ratings come from TMDB's `vote_average` per episode (season endpoint)
- `LineMark` + `PointMark` with `.interpolationMethod(.catmullRom)` for smooth curves
- `.chartXSelection(value:)` for touch interaction
- Color gradient based on rating value
- Season picker with `Picker` (`.segmented` style)

## UI Guidelines

### Theme Support
- **Both light and dark mode are supported** - defaults to system appearance
- User can override via Settings > Appearance (Light/Dark)
- Theme managed by `ThemeManager` in `App/ThemeManager.swift`

### Adaptive Colors
- Use `.primary` for text instead of `.white` - adapts automatically
- Use `.secondary` for subdued text
- Background colors use Asset Catalog color sets that adapt:
  - `Color.plotlineBackground` - light gray (#F5F5F5) / dark (#121212)
  - `Color.plotlineCard` - white / dark gray (#1E1E1E)
  - `Color.plotlineSecondary` - adapts for both modes
- Brand accent colors (`.plotlinePrimary`, `.plotlineGold`, etc.) remain constant

### All Changes Must Support Light Mode
- **Never use `.white` for text** - use `.primary` instead
- **Never use hardcoded dark backgrounds** - use adaptive `Color.plotlineBackground`
- Test UI changes in both light and dark mode before committing
- Shadows can remain `.black.opacity()` as they work in both modes

### iPad

The app targets iPhone **and** iPad (`TARGETED_DEVICE_FAMILY = "1,2"`). App Review rejected 1.3.0 on an iPad Air 11-inch while it was iPhone-only, so it ran letterboxed and everything looked sparse.

- **Grids size themselves from available width**, never a fixed column count: `GridItem.adaptiveColumns(minimumWidth: AdaptiveLayout.minimumColumnWidth)`. One constant gives two columns on the narrowest supported iPhone (375pt) and five or six on an iPad, and stays right in a multitasking split — which a size-class branch gets wrong.
- **Text columns are capped** with `.readableWidth()`. Full-bleed images stay outside it.
- When a shared layout constant changes, **do the arithmetic at every call site**, not once. A grid nested inside an already-padded parent has less room than the number assumes; that shipped a one-column regression on every iPhone below 402pt.
- Verify on iPhone **and** iPad. Nothing may make the iPhone worse — it is the primary device.

### Other Guidelines
- Use `AsyncImage` for all remote images with placeholder handling
- `LazyHStack`/`LazyVStack` for scrolling content lists
- `.searchable()` modifier for native search interface

## Workflow Rules

- **Use Conventional Commits**: Follow the conventional commits specification for commit messages:
  - `feat:` for new features
  - `fix:` for bug fixes
  - `refactor:` for code refactoring
  - `style:` for formatting/style changes
  - `docs:` for documentation
  - `chore:` for maintenance tasks
  - Example: `feat: add episode ratings grid for TV series`
- **When building features**: Use the `apple-docs` MCP tools to check Apple Developer Documentation for correct API usage, best practices, and platform compatibility

### Before a Release

`Scripts/release-preflight.sh` gathers the two cold-start suite passes, the
generator suite — which `xcodebuild test` **never** runs, and is the only one
that reads the dataset that actually ships — dataset freshness, the coherence
between `MARKETING_VERSION` and `docs/app-review/`, and the absence of OMDb.

It is wired to the Archive pre-action, **and that does not make it a
barrier**: a pre-action that returns an error does not reliably abort an
archive in recent Xcode. It warns at the right moment; it does not prevent.
