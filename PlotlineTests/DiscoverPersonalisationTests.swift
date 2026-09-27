import Foundation
import Testing
@testable import Plotline

/// The taste profile's genres end up as a `/discover/movie` query. They used
/// to get there by looking a display name back up in `GenreLookup`, which is
/// ambiguous for Action and War (a movie id and a TV id each) and has no movie
/// id at all for a TV-only genre.
@Suite("Discover personalisation")
@MainActor
struct DiscoverPersonalisationTests {
    private func favorite(_ id: Int, _ mediaType: String, genres: [Int]) -> FavoriteItem {
        FavoriteItem(
            tmdbId: id,
            mediaType: mediaType,
            title: "Title \(id)",
            genreIds: genres.map(String.init).joined(separator: ",")
        )
    }

    @Test("a series' genre ids are translated to their movie counterparts")
    func tvGenresMapToMovieGenres() {
        #expect(TasteProfileViewModel.movieGenreIds(for: 10759, isTVSeries: true) == [28])
        #expect(TasteProfileViewModel.movieGenreIds(for: 10768, isTVSeries: true) == [10752])
        #expect(TasteProfileViewModel.movieGenreIds(for: 10765, isTVSeries: true) == [14, 878])
        #expect(TasteProfileViewModel.movieGenreIds(for: 18, isTVSeries: true) == [18])
    }

    @Test("a TV-only genre has no movie id to query")
    func tvOnlyGenresMapToNothing() {
        #expect(TasteProfileViewModel.movieGenreIds(for: 10762, isTVSeries: true).isEmpty)
        #expect(TasteProfileViewModel.movieGenreIds(for: 10764, isTVSeries: true).isEmpty)
    }

    @Test("a movie's genre ids are already movie ids")
    func movieGenresPassThrough() {
        #expect(TasteProfileViewModel.movieGenreIds(for: 28, isTVSeries: false) == [28])
    }

    @Test("Action from a movie and from a series is one genre with one movie id")
    func actionMergesAcrossMediaTypes() {
        let shares = TasteProfileViewModel.genreDistribution(favorites: [
            favorite(1, "movie", genres: [28]),
            favorite(2, "tv", genres: [10759]),
            favorite(3, "tv", genres: [10762]),
        ])

        let action = shares.first { $0.name == "Action" }
        #expect(action?.movieGenreIds == [28])
        #expect(shares.first?.name == "Action")
        #expect(shares.first { $0.name == "Kids" }?.movieGenreIds == [])
    }

    @Test("equal shares rank the same way every time")
    func tiesAreDeterministic() {
        let favorites = [
            favorite(1, "movie", genres: [35]),
            favorite(2, "movie", genres: [18]),
            favorite(3, "movie", genres: [27]),
        ]
        let names = TasteProfileViewModel.genreDistribution(favorites: favorites).map(\.name)
        #expect(names == ["Comedy", "Drama", "Horror"])
    }

    @Test("the fingerprint ignores order and separates media types")
    func fingerprint() {
        let a = [favorite(1, "movie", genres: []), favorite(2, "tv", genres: [])]
        let b = [favorite(2, "tv", genres: []), favorite(1, "movie", genres: [])]
        let c = [favorite(1, "tv", genres: []), favorite(2, "tv", genres: [])]
        #expect(TasteProfileViewModel.fingerprint(of: a) == TasteProfileViewModel.fingerprint(of: b))
        #expect(TasteProfileViewModel.fingerprint(of: a) != TasteProfileViewModel.fingerprint(of: c))
    }

    @Test("'Because you liked' picks the same title for the same favourites")
    func stablePick() {
        let favorites = (1...8).map { favorite($0, $0.isMultiple(of: 2) ? "tv" : "movie", genres: []) }
        let fingerprint = TasteProfileViewModel.fingerprint(of: favorites)

        let first = SmartListsViewModel.stablePick(from: favorites, fingerprint: fingerprint)
        let reordered = SmartListsViewModel.stablePick(from: favorites.reversed(), fingerprint: fingerprint)

        #expect(first != nil)
        #expect(first?.tmdbId == reordered?.tmdbId)
        #expect(first?.mediaType == reordered?.mediaType)
    }
}
