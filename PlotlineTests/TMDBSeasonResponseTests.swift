import Foundation
import Testing
@testable import Plotline

@Suite("TMDBSeasonResponse")
struct TMDBSeasonResponseTests {
    /// Recorte real del endpoint /tv/{id}/season/{n}, con un episodio sin emitir
    /// y otro sin air_date para cubrir los casos límite.
    private let json = """
    {
      "id": 3572,
      "name": "Season 1",
      "season_number": 1,
      "episodes": [
        {
          "id": 62085,
          "name": "Pilot",
          "episode_number": 1,
          "season_number": 1,
          "air_date": "2008-01-20",
          "still_path": "/ydlY3iPfeOAvu8gVqrxPoMvzNCn.jpg",
          "vote_average": 8.9,
          "vote_count": 412,
          "overview": "Walter White is a chemistry teacher.",
          "runtime": 58
        },
        {
          "id": 62086,
          "name": "Cat's in the Bag...",
          "episode_number": 2,
          "season_number": 1,
          "air_date": "2999-01-27",
          "still_path": null,
          "vote_average": 0.0,
          "vote_count": 0,
          "overview": "",
          "runtime": 48
        },
        {
          "id": 62087,
          "name": "",
          "episode_number": 3,
          "season_number": 1,
          "air_date": null,
          "still_path": null,
          "vote_average": 0.0,
          "vote_count": 0,
          "overview": null,
          "runtime": null
        }
      ]
    }
    """

    private func decode() throws -> TMDBSeasonResponse {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(TMDBSeasonResponse.self, from: Data(json.utf8))
    }

    @Test("decodes the season payload")
    func decodesSeason() throws {
        let response = try decode()
        #expect(response.seasonNumber == 1)
        #expect(response.episodes.count == 3)
    }

    @Test("maps rating and vote count onto EpisodeMetric")
    func mapsRatingAndVotes() throws {
        let metrics = try decode().toEpisodeMetrics()
        #expect(metrics[0].rating == 8.9)
        #expect(metrics[0].voteCount == 412)
        #expect(metrics[0].title == "Pilot")
        #expect(metrics[0].hasValidRating)
    }

    @Test("keeps unaired episodes but marks them as unrated")
    func keepsUnairedEpisodes() throws {
        let metrics = try decode().toEpisodeMetrics()
        #expect(!metrics[1].hasAired)
        #expect(!metrics[1].hasValidRating)
    }

    @Test("falls back to the episode code when the title is missing")
    func fallsBackToEpisodeCode() throws {
        let metrics = try decode().toEpisodeMetrics()
        #expect(metrics[2].title == "Episode 3")
    }

    @Test("carries the season number from each episode")
    func carriesSeasonNumber() throws {
        let metrics = try decode().toEpisodeMetrics()
        #expect(metrics.allSatisfy { $0.seasonNumber == 1 })
    }
}
