import Foundation
import Testing
@testable import Plotline

/// The seams the per-task reviews could not see, each having looked at one
/// diff: which media type the request is built from, and which regions the
/// picker offers.
@MainActor
@Suite("Watch availability seams")
struct WatchAvailabilitySeamTests {
    private func item(name: String?, title: String?) -> MediaItem {
        MediaItem(
            id: 1,
            overview: "",
            posterPath: nil,
            backdropPath: nil,
            voteAverage: 8.0,
            voteCount: 100,
            genreIds: nil,
            title: title,
            releaseDate: nil,
            name: name,
            firstAirDate: nil,
            // Absent, exactly as TMDB leaves it on /movie/top_rated,
            // /tv/top_rated and every /discover payload.
            mediaType: nil
        )
    }

    /// The request used to be guarded on `media.mediaType`, which TMDB sends
    /// only on /trending and /search/multi. Everywhere else it is nil, so the
    /// section silently never appeared — and the two paths it was checked on
    /// happened to be the ones that carry it.
    @Test("a series from a list without media_type still resolves as a series")
    func seriesWithoutMediaTypeResolves() {
        #expect(item(name: "Breaking Bad", title: nil).isTVSeries)
    }

    @Test("a movie from a list without media_type still resolves as a movie")
    func movieWithoutMediaTypeResolves() {
        #expect(item(name: nil, title: "Sicario").isTVSeries == false)
    }

    // MARK: - The picker's contents

    private func availability() -> RegionAvailability {
        RegionAvailability(link: nil, flatrate: nil, rent: nil, buy: nil, free: nil, ads: nil)
    }

    /// The response lists only regions the title is available in. Without the
    /// user's own region in the picker they could look anywhere except home,
    /// and the choice persists across every other title with no way back.
    @Test("the picker always offers the region the user is actually in")
    func ownRegionIsAlwaysOffered() {
        let usOnly = ["US": availability()]

        let regions = MediaDetailViewModel.selectableRegions(from: usOnly, including: "ES")

        #expect(regions.contains("ES"))
        #expect(regions.contains("US"))
    }

    @Test("a region already in the response is not duplicated")
    func presentRegionIsNotDuplicated() {
        let both = ["US": availability(), "ES": availability()]

        let regions = MediaDetailViewModel.selectableRegions(from: both, including: "ES")

        #expect(regions.filter { $0 == "ES" }.count == 1)
        #expect(regions == ["ES", "US"])
    }

    @Test("the list is sorted so the picker is navigable")
    func regionsAreSorted() {
        let scrambled = ["JP": availability(), "AR": availability(), "US": availability()]

        let regions = MediaDetailViewModel.selectableRegions(from: scrambled, including: "GB")

        #expect(regions == ["AR", "GB", "JP", "US"])
    }
}
