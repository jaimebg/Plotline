import Foundation
import Testing
@testable import Plotline

@Suite("Series status")
struct SeriesStatusTests {
    private func detailJSON(status: String?) -> Data {
        let statusField = status.map { "\"status\": \"\($0)\"," } ?? ""
        return Data("""
        {
            "id": 1396,
            \(statusField)
            "overview": "",
            "vote_average": 8.9,
            "vote_count": 100,
            "name": "Test Series",
            "number_of_seasons": 5
        }
        """.utf8)
    }

    private func decode(status: String?) throws -> MediaItem {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let response = try decoder.decode(TMDBDetailResponse.self, from: detailJSON(status: status))
        return response.toMediaItem(mediaType: .tv)
    }

    @Test("a terminal status counts as ended", arguments: ["Ended", "Canceled", "Cancelled"])
    func terminalStatuses(status: String) throws {
        #expect(try decode(status: status).hasEnded == true)
    }

    @Test("a series confirmed in production is not ended", arguments: ["Returning Series", "In Production"])
    func runningStatuses(status: String) throws {
        #expect(try decode(status: status).hasEnded == false)
    }

    /// A pilot may never be picked up and a planned series may never air:
    /// neither is evidence the show is running, so neither may read as
    /// "ongoing" — `isOngoing == false` must stay reserved for "ended or
    /// unknown", and `hasEnded == false` for a confirmed running series.
    @Test("a status that confirms neither stays unknown", arguments: ["Pilot", "Planned", "Rumored", "", "ended"])
    func inconclusiveStatuses(status: String) throws {
        #expect(try decode(status: status).hasEnded == nil)
    }

    /// An absent status is unknown, which is not the same as still running.
    /// The engine withholds the ending verdict on nil, and that is the point.
    @Test("an absent status stays unknown rather than guessing")
    func absentStatusIsUnknown() throws {
        #expect(try decode(status: nil).hasEnded == nil)
    }

    @Test("the mapping itself, independent of decoding")
    func mapping() {
        #expect(SeriesStatus.hasEnded(forTMDBStatus: "Ended") == true)
        #expect(SeriesStatus.hasEnded(forTMDBStatus: "Canceled") == true)
        #expect(SeriesStatus.hasEnded(forTMDBStatus: "Cancelled") == true)
        #expect(SeriesStatus.hasEnded(forTMDBStatus: "Returning Series") == false)
        #expect(SeriesStatus.hasEnded(forTMDBStatus: "In Production") == false)
        #expect(SeriesStatus.hasEnded(forTMDBStatus: "Pilot") == nil)
        #expect(SeriesStatus.hasEnded(forTMDBStatus: "Planned") == nil)
        #expect(SeriesStatus.hasEnded(forTMDBStatus: nil) == nil)
    }

    /// The two sets must never overlap, or one status would be both.
    @Test("no status is both ended and running")
    func setsAreDisjoint() {
        #expect(SeriesStatus.ended.isDisjoint(with: SeriesStatus.running))
    }
}
