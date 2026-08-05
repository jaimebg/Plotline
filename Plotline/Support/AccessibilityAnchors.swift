import Foundation

/// Identifiers the cold-start UI test looks for.
///
/// These are load-bearing, not decoration: each one marks a container that has
/// to be on screen on a clean install with no user data. Removing one, or
/// moving it inside a condition on saved favorites, is the shape of the defect
/// that got version 1.3.0 rejected under Guideline 4.2.
///
/// `PlotlineUITests/UITestAnchors.swift` carries the same literals. The copy is
/// deliberate — see the comment there.
enum AccessibilityAnchors {
    static let discoverShelf = "plotline.discover.shelf"
    static let favoritesSuggestions = "plotline.favorites.suggestions"
    static let favoritesSavedRow = "plotline.favorites.savedRow"
    static let watchlistSuggestions = "plotline.watchlist.suggestions"
    static let statsCompare = "plotline.stats.compare"
    static let statsCareerProfiles = "plotline.stats.careerProfiles"
    static let statsTrends = "plotline.stats.trends"
    static let statsYourStatsEmpty = "plotline.stats.yourStatsEmpty"
    static let settingsRow = "plotline.settings.row"
    static let mediaCard = "plotline.mediaCard"

    /// The two mutually exclusive outcomes of Discover's TMDB fetch. These are
    /// not part of the rejection guard: they are how the UI suite observes
    /// which of its two passes it is actually running, instead of trusting the
    /// launch environment to have arrived. Starved of a key the fetch fails
    /// with no content and `networkError` is what renders; with a working key
    /// the fetch does not fail, and `trendingMovies` is what renders instead
    /// — even a fetch that succeeds with zero results renders it, since
    /// `MediaSection` draws a placeholder rather than nothing when `items` is
    /// empty. The anchor proves the non-error branch ran, not that TMDB
    /// returned anything.
    static let discoverNetworkError = "plotline.discover.networkError"
    static let discoverTrendingMovies = "plotline.discover.trendingMovies"
}
