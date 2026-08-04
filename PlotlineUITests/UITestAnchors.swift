import Foundation

/// The identifiers this suite looks for, written out again on purpose.
///
/// A UI test runs in a separate process and cannot import the app module, so
/// these literals are a deliberate second copy of
/// `Plotline/Support/AccessibilityAnchors.swift`. Do not "fix" the duplication
/// by sharing the file across targets: the duplication is what makes an anchor
/// that disappears from the app show up red here, which is the whole point of
/// this suite.
enum UITestAnchors {
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
}
