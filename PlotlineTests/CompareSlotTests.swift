import Foundation
import Testing
@testable import Plotline

/// Compare's charts group their marks by a string, so two slots must never
/// produce the same one.
@Suite("Compare slots")
@MainActor
struct CompareSlotTests {
    private func movie(_ id: Int, _ title: String, _ date: String) -> MediaItem {
        MediaItem(
            id: id, overview: "", posterPath: nil, backdropPath: nil,
            voteAverage: 7, voteCount: 100, genreIds: [],
            title: title, releaseDate: date, name: nil, firstAirDate: nil,
            mediaType: .movie, totalSeasons: nil
        )
    }

    @Test("two films with the same title are told apart by year")
    func sameTitleGetsYear() {
        let viewModel = CompareViewModel()
        viewModel.slots = [movie(841, "Dune", "1984-12-14"), movie(438631, "Dune", "2021-09-15"), nil]

        #expect(viewModel.chartLabel(forSlot: 0) == "Dune (1984)")
        #expect(viewModel.chartLabel(forSlot: 1) == "Dune (2021)")
    }

    @Test("a unique title keeps its plain name")
    func uniqueTitleUnchanged() {
        let viewModel = CompareViewModel()
        viewModel.slots = [movie(1, "Heat", "1995-12-15"), movie(2, "Ronin", "1998-09-25"), nil]
        #expect(viewModel.chartLabel(forSlot: 0) == "Heat")
    }

    @Test("a title already in one slot cannot be added to another")
    func duplicateSlotIsRejected() {
        let viewModel = CompareViewModel()
        let heat = movie(1, "Heat", "1995-12-15")
        viewModel.slots = [heat, nil, nil]

        #expect(viewModel.isInAnotherSlot(heat, excluding: 1))
        #expect(!viewModel.isInAnotherSlot(heat, excluding: 0))

        viewModel.selectItem(heat, for: 1)
        #expect(viewModel.slots[1] == nil)
        #expect(viewModel.isLoadingSlot[1] != true)
    }
}
