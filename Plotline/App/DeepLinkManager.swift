import SwiftUI

/// Carries pending navigation from Siri App Intents into the view hierarchy.
///
/// `PlotlineApp.init()` registers the app's single instance as an App Intents
/// dependency, so `SearchPlotlineIntent` and `OpenSeriesIntent` write to it
/// directly. `MainTabView` and `DiscoveryView` consume a pending value both
/// when it changes and when they first appear, because on a cold launch the
/// intent can run before either view exists.
@Observable
final class DeepLinkManager {
    var pendingTab: AppTab?
    var pendingSearchQuery: String?
    /// A title whose detail screen should open — from a Spotlight result, or
    /// "Open in Plotline" on a Siri verdict. `DiscoveryView` pushes it.
    var pendingDetail: PendingDetail?
    /// Which half of the Library tab to show. `LibraryView` consumes it.
    var pendingLibrarySegment: LibrarySegment?

    /// Opens a title's detail screen on the Discover tab.
    func openDetail(_ detail: PendingDetail) {
        pendingDetail = detail
        pendingTab = .discover
    }

    /// Opens the Library tab on the given segment. The segment is set before
    /// the tab, so `LibraryView` finds it waiting whether it already exists or
    /// is about to appear for the first time.
    func openLibrary(_ segment: LibrarySegment) {
        pendingLibrarySegment = segment
        pendingTab = .library
    }
}

/// Enough to open a detail screen for a title the app may not have loaded.
nonisolated struct PendingDetail: Hashable, Sendable {
    let tmdbId: Int
    let mediaType: MediaType
    /// Shown until TMDB's details arrive, when known.
    var name: String?

    /// The item to push. A bundled series arrives whole, so its analysis is in
    /// the first frame; anything else is a stub `MediaDetailViewModel`
    /// recognises (no rating, no overview) and replaces with TMDB's details.
    @MainActor
    func mediaItem(bundled entry: DatasetEntry?) -> MediaItem {
        if mediaType == .tv, let entry, entry.tmdbId == tmdbId {
            return entry.asMediaItem
        }

        let title = name ?? "Loading..."
        return MediaItem(
            id: tmdbId,
            overview: "",
            posterPath: nil,
            backdropPath: nil,
            voteAverage: 0,
            voteCount: 0,
            genreIds: nil,
            title: mediaType == .movie ? title : nil,
            releaseDate: nil,
            name: mediaType == .tv ? title : nil,
            firstAirDate: nil,
            mediaType: mediaType
        )
    }
}

// MARK: - Environment Key

struct DeepLinkManagerKey: EnvironmentKey {
    static let defaultValue = DeepLinkManager()
}

extension EnvironmentValues {
    var deepLinkManager: DeepLinkManager {
        get { self[DeepLinkManagerKey.self] }
        set { self[DeepLinkManagerKey.self] = newValue }
    }
}
