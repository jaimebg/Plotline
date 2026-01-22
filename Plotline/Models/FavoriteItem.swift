import Foundation
import SwiftData

/// SwiftData model for storing favorite movies and TV series
/// Note: Unique constraint removed for CloudKit compatibility - duplicates prevented in FavoritesManager
@Model
final class FavoriteItem {
    /// TMDB ID of the media item (uniqueness enforced in FavoritesManager)
    var tmdbId: Int

    /// Media type: "movie" or "tv"
    var mediaType: String

    /// Display title
    var title: String

    /// Poster path for thumbnail display
    var posterPath: String?

    /// Backdrop path for featured display
    var backdropPath: String?

    /// TMDB vote average at time of favoriting
    var voteAverage: Double

    /// Date when the item was favorited
    var addedAt: Date

    init(
        tmdbId: Int,
        mediaType: String,
        title: String,
        posterPath: String? = nil,
        backdropPath: String? = nil,
        voteAverage: Double = 0,
        addedAt: Date = .now
    ) {
        self.tmdbId = tmdbId
        self.mediaType = mediaType
        self.title = title
        self.posterPath = posterPath
        self.backdropPath = backdropPath
        self.voteAverage = voteAverage
        self.addedAt = addedAt
    }

    /// Convenience initializer from MediaItem
    convenience init(from media: MediaItem) {
        self.init(
            tmdbId: media.id,
            mediaType: media.isTVSeries ? "tv" : "movie",
            title: media.displayTitle,
            posterPath: media.posterPath,
            backdropPath: media.backdropPath,
            voteAverage: media.voteAverage
        )
    }

    /// Whether this is a TV series
    var isTVSeries: Bool {
        mediaType == "tv"
    }

    /// Poster URL for display
    var posterURL: URL? {
        guard let path = posterPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w500\(path)")
    }

    /// Backdrop URL for display
    var backdropURL: URL? {
        guard let path = backdropPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/original\(path)")
    }

    /// Convert to MediaItem for navigation to detail view
    func toMediaItem() -> MediaItem {
        MediaItem(
            id: tmdbId,
            overview: "",
            posterPath: posterPath,
            backdropPath: backdropPath,
            voteAverage: voteAverage,
            voteCount: 0,
            genreIds: nil,
            title: isTVSeries ? nil : title,
            releaseDate: nil,
            name: isTVSeries ? title : nil,
            firstAirDate: nil,
            mediaType: isTVSeries ? .tv : .movie
        )
    }
}
