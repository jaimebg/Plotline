import Foundation

extension DatasetEntry {
    /// Presents a dataset entry through the app's existing media type, so the
    /// bundled content reuses the same cards, sections and navigation as
    /// everything fetched from the network.
    ///
    /// `voteCount` is zero because the dataset does not carry a series-level
    /// count — it is only used for display ordering, never for the analysis,
    /// which does its own vote weighting per episode.
    var asMediaItem: MediaItem {
        MediaItem(
            id: tmdbId,
            overview: overview,
            posterPath: posterPath,
            backdropPath: backdropPath,
            voteAverage: voteAverage,
            voteCount: 0,
            genreIds: genreIds,
            title: nil,
            releaseDate: nil,
            name: name,
            firstAirDate: firstAirDate,
            mediaType: .tv
        )
    }
}
