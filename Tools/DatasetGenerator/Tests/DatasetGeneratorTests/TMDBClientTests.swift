import Foundation
import Testing
@testable import DatasetGeneratorCore

@Suite("TMDB decoding")
struct TMDBClientTests {
    private let seasonJSON = """
    {
      "id": 3572,
      "season_number": 1,
      "episodes": [
        {"id": 62085, "name": "Pilot", "episode_number": 1, "season_number": 1,
         "air_date": "2008-01-20", "still_path": "/a.jpg", "vote_average": 8.9, "vote_count": 412},
        {"id": 62086, "name": "", "episode_number": 2, "season_number": 1,
         "air_date": null, "still_path": null, "vote_average": 0.0, "vote_count": 0}
      ]
    }
    """

    private let detailsJSON = """
    {"id": 1396, "name": "Breaking Bad", "number_of_seasons": 5,
     "status": "Ended", "poster_path": "/p.jpg"}
    """

    @Test("maps a season payload onto EpisodeMetric")
    func decodesSeason() throws {
        let episodes = try TMDBClient.decodeSeason(Data(seasonJSON.utf8))
        #expect(episodes.count == 2)
        #expect(episodes[0].id == 62085)
        #expect(episodes[0].rating == 8.9)
        #expect(episodes[0].voteCount == 412)
        #expect(episodes[0].title == "Pilot")
    }

    @Test("falls back to an episode code when TMDB returns an empty name")
    func fallsBackToEpisodeCode() throws {
        let episodes = try TMDBClient.decodeSeason(Data(seasonJSON.utf8))
        #expect(episodes[1].title == "Episode 2")
    }

    @Test("carries the air date and still path through unchanged when present")
    func decodesAirDateAndStillPath() throws {
        let episodes = try TMDBClient.decodeSeason(Data(seasonJSON.utf8))
        #expect(episodes[0].airDate == "2008-01-20")
        #expect(episodes[0].stillPath == "/a.jpg")
    }

    @Test("maps a null air date and still path to nil, not an empty string")
    func decodesNullAirDateAndStillPathAsNil() throws {
        let episodes = try TMDBClient.decodeSeason(Data(seasonJSON.utf8))
        #expect(episodes[1].airDate == nil)
        #expect(episodes[1].stillPath == nil)
    }

    @Test("the decoded air date is usable by the engine's hasAired check")
    func decodedAirDateDrivesHasAired() throws {
        let episodes = try TMDBClient.decodeSeason(Data(seasonJSON.utf8))
        let reference = Date(timeIntervalSince1970: 1_577_836_800) // 2020-01-01 UTC
        #expect(episodes[0].hasAired(asOf: reference))
        #expect(episodes[1].hasAired(asOf: reference) == false)
    }

    @Test("reads the season count and the ended flag from series details")
    func decodesDetails() throws {
        let details = try TMDBClient.decodeDetails(Data(detailsJSON.utf8))
        #expect(details.id == 1396)
        #expect(details.name == "Breaking Bad")
        #expect(details.seasonCount == 5)
        #expect(details.hasEnded)
    }

    @Test("treats a returning series as not ended")
    func detectsReturningSeries() throws {
        let json = #"{"id": 1, "name": "X", "number_of_seasons": 2, "status": "Returning Series", "poster_path": null}"#
        #expect(try TMDBClient.decodeDetails(Data(json.utf8)).hasEnded == false)
    }

    @Test("defaults the season count to zero when TMDB omits the field entirely")
    func missingSeasonCountDefaultsToZero() throws {
        let json = #"{"id": 1, "name": "X", "status": "Ended", "poster_path": null}"#
        #expect(try TMDBClient.decodeDetails(Data(json.utf8)).seasonCount == 0)
    }

    @Test("the seed list is non-empty and free of duplicates")
    func seedListIsSane() {
        #expect(SeedList.seriesIds.count >= 20)
        #expect(Set(SeedList.seriesIds).count == SeedList.seriesIds.count)
    }
}
