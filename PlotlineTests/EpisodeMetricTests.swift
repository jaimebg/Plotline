import Foundation
import Testing
@testable import Plotline

@Suite("EpisodeMetric")
struct EpisodeMetricTests {
    private func make(
        id: Int? = 62089,
        rating: Double = 8.5,
        voteCount: Int = 100,
        airDate: String? = "2008-01-20",
        episodeNumber: Int = 5,
        seasonNumber: Int = 1
    ) -> EpisodeMetric {
        EpisodeMetric(
            id: id,
            episodeNumber: episodeNumber,
            seasonNumber: seasonNumber,
            title: "Gray Matter",
            rating: rating,
            voteCount: voteCount,
            airDate: airDate,
            stillPath: "/still.jpg"
        )
    }

    @Test("formats the rating to one decimal")
    func formatsRating() {
        #expect(make(rating: 8.46).formattedRating == "8.5")
    }

    @Test("shows a dash when there is no rating")
    func formatsMissingRating() {
        #expect(make(rating: 0, voteCount: 0).formattedRating == "—")
    }

    @Test("builds the short and full episode codes")
    func buildsCodes() {
        let episode = make(episodeNumber: 5, seasonNumber: 1)
        #expect(episode.shortCode == "S1E5")
        #expect(episode.fullCode == "Season 1, Episode 5")
    }

    @Test("a rating is valid only with a positive score and at least one vote")
    func validatesRating() {
        #expect(make(rating: 8.5, voteCount: 100).hasValidRating)
        #expect(!make(rating: 0, voteCount: 100).hasValidRating)
        #expect(!make(rating: 8.5, voteCount: 0).hasValidRating)
    }

    @Test("an episode with a past air date has aired")
    func detectsAiredEpisode() {
        #expect(make(airDate: "1999-01-01").hasAired)
    }

    @Test("an episode with a future air date has not aired")
    func detectsUnairedEpisode() {
        #expect(!make(airDate: "2999-01-01").hasAired)
    }

    @Test("an episode without an air date is treated as not aired")
    func treatsMissingAirDateAsUnaired() {
        #expect(!make(airDate: nil).hasAired)
    }

    @Test("only a known future air date counts as scheduled")
    func detectsScheduledEpisode() {
        let reference = Date(timeIntervalSince1970: 1_577_836_800) // 2020-01-01
        #expect(make(airDate: "2999-01-01").airsAfter(reference))
        #expect(!make(airDate: "1999-01-01").airsAfter(reference))
        // Not the inverse of `hasAired`: a missing date has neither aired nor
        // been scheduled, so it is evidence of nothing either way.
        #expect(!make(airDate: nil).airsAfter(reference))
        #expect(!make(airDate: nil).hasAired)
    }

    @Test("builds the still image URL from the path")
    func buildsStillURL() {
        #expect(make().stillURL?.absoluteString == "https://image.tmdb.org/t/p/w300/still.jpg")
    }

    @Test("round-trips through Codable keeping the same id")
    func encodesAndDecodes() throws {
        let original = make(id: 62089)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(EpisodeMetric.self, from: data)
        #expect(decoded == original)
        // La identidad debe sobrevivir al ciclo de caché, no regenerarse.
        #expect(decoded.id == 62089)
    }
}
