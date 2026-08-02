# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Plotline is an iOS app for exploring movies and TV series with analytical quality visualization. It sources all metadata and ratings from TMDB and provides episode-by-episode rating graphs for TV series using Swift Charts.

**Target:** iOS 26+, iPhone, SwiftUI

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

# Run tests (when added)
xcodebuild -project Plotline.xcodeproj -scheme Plotline -destination 'platform=iOS Simulator,name=iPhone 17' test

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
- `TMDBService` - TMDB API wrapper (trending, popular, search, details, credits, season episodes)
- `DiskCache` - Generic on-disk cache used to avoid redundant network calls

**Models** (`Models/`)
- `MediaItem` - Unified model for movies and TV series with computed properties for URLs and display values
- `EpisodeMetric` - Episode data (sourced from TMDB's season endpoint) for Swift Charts visualization
- `APIResponses/` - TMDB response wrappers with decoding

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
