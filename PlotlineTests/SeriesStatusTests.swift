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

    @Test("a running series is not ended", arguments: ["Returning Series", "In Production", "Planned"])
    func runningStatuses(status: String) throws {
        #expect(try decode(status: status).hasEnded == false)
    }

    /// An absent status is unknown, which is not the same as still running.
    /// The engine withholds the ending verdict on nil, and that is the point.
    @Test("an absent status stays unknown rather than guessing")
    func absentStatusIsUnknown() throws {
        #expect(try decode(status: nil).hasEnded == nil)
    }
}
