# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Plotline is an iOS app for exploring movies and TV series with analytical quality visualization. It aggregates ratings from multiple sources (IMDb, Rotten Tomatoes, Metacritic) and provides episode-by-episode rating graphs for TV series using Swift Charts.

**Target:** iOS 17+, iPhone, SwiftUI

## Build Commands

```bash
# Build the project
xcodebuild -project Plotline.xcodeproj -scheme Plotline -destination 'platform=iOS Simulator,name=iPhone 15' build

# Run tests (when added)
xcodebuild -project Plotline.xcodeproj -scheme Plotline -destination 'platform=iOS Simulator,name=iPhone 15' test

# Clean build
xcodebuild -project Plotline.xcodeproj -scheme Plotline clean
```

Open in Xcode: `open Plotline.xcodeproj`

## Architecture

### Dual API Strategy (Chained Fetching)
The app uses two APIs in sequence:

1. **TMDB (Primary)** - Visual data, metadata, trending/popular content
   - Provides `imdb_id` which links to OMDb
   - All image URLs come from TMDB

2. **OMDb (Secondary)** - Ratings and episode metrics
   - Called after TMDB to enrich with external ratings
   - Provides episode-by-episode ratings for TV series (for the SeriesGraph)

Flow: User action → TMDB fetch → Extract `imdb_id` → OMDb fetch → Merge data → Render

### Key Components

**Services Layer** (`Services/`)
- `NetworkManager` - Swift Actor for thread-safe async networking with `URLSession`
- `TMDBService` - TMDB API wrapper (trending, popular, search, details, credits)
- OMDbService (to be implemented) - Episode ratings and external scores

**Models** (`Models/`)
- `MediaItem` - Unified model for movies and TV series with computed properties for URLs and display values
- `RatingSource` - External rating with normalization logic and color coding
- `EpisodeMetric` - Episode data for Swift Charts visualization
- `APIResponses/` - TMDB and OMDb response wrappers with decoding

**Key Design Patterns:**
- Models use snake_case decoding via `JSONDecoder.keyDecodingStrategy = .convertFromSnakeCase`
- OMDb uses PascalCase keys (handled via explicit `CodingKeys`)
- Preview data is included in model extensions for SwiftUI previews

### State Management
Use `@Observable` macro (iOS 17+) for ViewModels, not `@ObservableObject`.

### Color System
Brand colors defined in `Extensions/Color+Plotline.swift`:
- Rating colors: `.imdbYellow`, `.rottenRed`, `.rottenGreen`, `.metacriticGreen/Yellow/Red`
- Chart colors: `.chartHigh`, `.chartMedium`, `.chartLow`
- Use `Color(hex:)` initializer for hex colors

## API Keys

API keys are loaded from environment variables:
- `TMDB_API_KEY` - Required for all content
- `OMDB_API_KEY` - Required for external ratings (to be implemented)

Set in Xcode scheme or export before building.

## SeriesGraph Feature

The star feature uses Swift Charts to visualize episode ratings:
- `LineMark` + `PointMark` with `.interpolationMethod(.catmullRom)` for smooth curves
- `.chartXSelection(value:)` for touch interaction
- Color gradient based on rating value
- Season picker with `Picker` (`.segmented` style)

## UI Guidelines

- Strictly dark mode (`.preferredColorScheme(.dark)`)
- Background: `#121212` or pure black `#000000` for OLED
- Use `AsyncImage` for all remote images with placeholder handling
- `LazyHStack`/`LazyVStack` for scrolling content lists
- `.searchable()` modifier for native search interface
