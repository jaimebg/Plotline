<p align="center">
  <img src="app-icon.png" alt="Plotline App Icon" width="128" height="128">
</p>

<h1 align="center">Plotline</h1>

<p align="center">
  <strong>Explore the audiovisual universe with analytical quality visualization</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/iOS-17%2B-blue" alt="iOS 17+">
  <img src="https://img.shields.io/badge/Swift-5.9-orange" alt="Swift 5.9">
  <img src="https://img.shields.io/badge/SwiftUI-darkblue" alt="SwiftUI">
  <img src="https://img.shields.io/badge/License-MIT-green" alt="MIT License">
</p>

---

## About

**Plotline** goes beyond a simple movie catalog. It provides analytical visualization of quality for both movies and TV series, consolidating critical data from multiple sources (IMDb, Rotten Tomatoes, Metacritic) into a unified, elegant interface.

Most apps tell you *what a series is about*. **Plotline** shows you *how its quality evolves* visually.

## Features

- **Trending Discovery** — Browse trending and popular movies & TV series
- **Multi-Source Ratings** — Aggregated scores from IMDb, Rotten Tomatoes, and Metacritic
- **Episode Quality Graphs** — Visualize TV series episode ratings with interactive Swift Charts
- **Immersive Design** — Cinema-inspired dark mode UI with smooth animations
- **Smart Search** — Find any movie or series instantly

## Screenshots

*Coming soon*

## Tech Stack

| Technology | Purpose |
|------------|---------|
| **SwiftUI** | Declarative UI framework |
| **Swift Charts** | Episode rating visualization |
| **@Observable** | iOS 17+ state management |
| **async/await** | Modern concurrency |
| **TMDB API** | Visual data & metadata |
| **OMDb API** | Ratings & episode metrics |

## Architecture

Plotline uses a **dual API strategy** (chained fetching):

1. **TMDB** provides visual assets, trending content, and the `imdb_id` bridge
2. **OMDb** enriches with external ratings and episode-by-episode metrics

```
User Action → TMDB Fetch → Extract imdb_id → OMDb Fetch → Merge & Render
```

## Requirements

- iOS 17.0+
- Xcode 15+
- TMDB API Key ([Get one here](https://www.themoviedb.org/settings/api))
- OMDb API Key ([Get one here](https://www.omdbapi.com/apikey.aspx))

## Getting Started

1. Clone the repository
   ```bash
   git clone https://github.com/yourusername/Plotline.git
   ```

2. Open the project in Xcode
   ```bash
   cd Plotline
   open Plotline.xcodeproj
   ```

3. Add your API keys to the Xcode scheme environment variables:
   - `TMDB_API_KEY`
   - `OMDB_API_KEY`

4. Build and run on a simulator or device

## Project Structure

```
Plotline/
├── App/                    # App entry point
├── Models/                 # Data models & API responses
├── ViewModels/             # @Observable view models
├── Views/
│   ├── Discovery/          # Home screen & media cards
│   ├── Detail/             # Media detail & scorecards
│   ├── Graph/              # Series episode charts
│   └── Components/         # Reusable UI components
├── Services/               # Network layer & API services
├── Extensions/             # Swift & SwiftUI extensions
└── Resources/              # Assets & configuration
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

<p align="center">
  Made with SwiftUI
</p>
