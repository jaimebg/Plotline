import SwiftUI

/// Manages deep link navigation state from widgets and Siri
@Observable
final class DeepLinkManager {
    var pendingTab: AppTab?
    var pendingMediaItem: MediaItem?
    var pendingSearchQuery: String?

    /// Parse a plotline:// URL and set pending navigation state
    func handleURL(_ url: URL) {
        guard url.scheme == "plotline" else { return }

        let host = url.host()
        let pathComponents = url.pathComponents.filter { $0 != "/" }

        switch host {
        case "detail":
            guard pathComponents.count >= 2,
                  let tmdbId = Int(pathComponents[1]) else { return }

            let mediaType: MediaType = pathComponents[0] == "tv" ? .tv : .movie

            pendingMediaItem = MediaItem(
                id: tmdbId,
                overview: "",
                posterPath: nil,
                backdropPath: nil,
                voteAverage: 0,
                voteCount: 0,
                genreIds: nil,
                title: mediaType == .movie ? "Loading..." : nil,
                releaseDate: nil,
                name: mediaType == .tv ? "Loading..." : nil,
                firstAirDate: nil,
                mediaType: mediaType
            )
            pendingTab = .discover

        case "watchlist":
            pendingTab = .watchlist

        case "stats":
            pendingTab = .stats

        case "search":
            // plotline://search?q=query
            if let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "q" })?.value {
                pendingSearchQuery = query
                pendingTab = .discover
            }

        default:
            break
        }
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
