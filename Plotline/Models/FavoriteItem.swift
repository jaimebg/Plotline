import Foundation
import SwiftData

/// SwiftData model for storing favorite movies and TV series
/// Note: Unique constraint removed for CloudKit compatibility - duplicates prevented in FavoritesManager
///
/// Every stored property below is optional or carries a default **on its own
/// declaration**. CloudKit reaches SwiftData through
/// `NSPersistentCloudKitContainer`, which rejects a schema where a
/// non-optional attribute has no default — a record arriving from the server
/// without that field would have nothing to become. The defaults in `init`
/// below do not satisfy that: the requirement is about the generated schema,
/// not about how Swift constructs an instance. Getting this wrong does not
/// fail loudly — `PlotlineApp` catches the throw and silently drops to
/// local-only storage, so favorites keep saving and simply never sync.
/// `CloudKitSchemaSourceTests` guards it.
@Model
final class FavoriteItem {
    /// TMDB ID of the media item (uniqueness enforced in FavoritesManager)
    var tmdbId: Int = 0

    /// Media type: "movie" or "tv"
    var mediaType: String = ""

    /// Display title
    var title: String = ""

    /// Poster path for thumbnail display
    var posterPath: String?

    /// Backdrop path for featured display
    var backdropPath: String?

    /// TMDB vote average at time of favoriting
    var voteAverage: Double = 0

    /// Comma-separated TMDB genre IDs (CloudKit-safe string storage)
    var genreIds: String = ""

    /// Date when the item was favorited.
    /// Spelled out rather than `.distantPast`: the `@Model` macro expands the
    /// default into a context with no contextual type, where implicit member
    /// syntax resolves against `Any?` and fails to compile.
    var addedAt: Date = Date.distantPast

    /// Parsed genre IDs from the comma-separated string
    var genreIdArray: [Int] {
        genreIds.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
    }

    init(
        tmdbId: Int,
        mediaType: String,
        title: String,
        posterPath: String? = nil,
        backdropPath: String? = nil,
        voteAverage: Double = 0,
        genreIds: String = "",
        addedAt: Date = .now
    ) {
        self.tmdbId = tmdbId
        self.mediaType = mediaType
        self.title = title
        self.posterPath = posterPath
        self.backdropPath = backdropPath
        self.voteAverage = voteAverage
        self.genreIds = genreIds
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
            voteAverage: media.voteAverage,
            genreIds: media.genreIds?.map(String.init).joined(separator: ",") ?? ""
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
