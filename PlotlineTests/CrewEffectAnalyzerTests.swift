import Foundation
import Testing
@testable import Plotline

@Suite("CrewEffectAnalyzer")
struct CrewEffectAnalyzerTests {
    private func episode(
        _ season: Int,
        _ number: Int,
        _ rating: Double,
        votes: Int = 100,
        directors: [String]? = [],
        writers: [String]? = []
    ) -> EpisodeMetric {
        EpisodeMetric(
            episodeNumber: number,
            seasonNumber: season,
            title: "S\(season)E\(number)",
            rating: rating,
            voteCount: votes,
            airDate: EpisodeFixtures.pastAirDate,
            directors: directors,
            writers: writers
        )
    }

    /// Season 1 averages 8.5: three episodes at 8.0 directed by "Low", three
    /// at 9.0 directed by "High".
    private var seasonOne: [EpisodeMetric] {
        [
            episode(1, 1, 8.0, directors: ["Low"], writers: ["Solo", "Three"]),
            episode(1, 2, 8.0, directors: ["Low"], writers: ["Solo", "Three"]),
            episode(1, 3, 8.0, directors: ["Low"], writers: ["Solo"]),
            episode(1, 4, 9.0, directors: ["High"], writers: ["Solo", "Two", "Three"]),
            episode(1, 5, 9.0, directors: ["High"], writers: ["Solo", "Two"]),
            episode(1, 6, 9.0, directors: ["High"], writers: ["Solo"])
        ]
    }

    private func compare(_ episodes: [EpisodeMetric]) -> CrewComparison {
        CrewEffectAnalyzer.compare(episodes: episodes, asOf: EpisodeFixtures.now)
    }

    @Test("episodes above their season land above, below land below")
    func signFollowsTheSeason() {
        let result = compare(seasonOne)
        #expect(result.directorsAbove.map(\.name) == ["High"])
        #expect(result.directorsBelow.map(\.name) == ["Low"])
        #expect(result.directorsAbove.first?.roundedDelta == 0.5)
        #expect(result.directorsBelow.first?.roundedDelta == -0.5)
        #expect(result.directorsAbove.first?.episodeCount == 3)
    }

    @Test("fewer than three reliable episodes is not enough")
    func requiresThreeEpisodes() {
        let result = compare(seasonOne)
        let writers = (result.writersAbove + result.writersBelow).map(\.name)
        #expect(!writers.contains("Two"))
        // "Three": 8.0, 8.0, 9.0 against 8.5 → -0.17, shown as -0.2.
        #expect(result.writersBelow.map(\.name) == ["Three"])
        #expect(result.writersBelow.first?.roundedDelta == -0.2)
    }

    @Test("someone credited on every counted episode of their seasons is left out")
    func soleCreditIsExcluded() {
        let result = compare(seasonOne)
        #expect(!(result.writersAbove + result.writersBelow).map(\.name).contains("Solo"))
    }

    @Test("a person on every episode of one season but not another is still compared")
    func partialCoverageIsCompared() {
        let seasonTwo = [
            episode(2, 1, 7.0, directors: ["Everywhere"]),
            episode(2, 2, 7.0, directors: ["Everywhere"]),
            episode(2, 3, 8.0, directors: ["Someone"]),
            episode(2, 4, 8.0, directors: ["Someone"])
        ]
        let seasonThree = [
            episode(3, 1, 8.0, directors: ["Everywhere"]),
            episode(3, 2, 8.0, directors: ["Everywhere"])
        ]
        let result = compare(seasonTwo + seasonThree)
        let everywhere = (result.directorsAbove + result.directorsBelow).first { $0.name == "Everywhere" }
        // Season 2 average 7.5: two at -0.5. Season 3 is all theirs: 0, 0.
        #expect(everywhere?.roundedDelta == -0.3)
        #expect(everywhere?.seasonCount == 2)
    }

    @Test("episodes without enough votes neither count nor move the average")
    func unreliableEpisodesAreIgnored() {
        let noisy = seasonOne + [episode(1, 7, 1.0, votes: 2, directors: ["High"])]
        let result = compare(noisy)
        #expect(result.directorsAbove.first?.roundedDelta == 0.5)
        #expect(result.directorsAbove.first?.episodeCount == 3)
    }

    @Test("an episode with no crew data is not evidence of anyone's absence")
    func unknownCrewDoesNotBreakSoleCredit() {
        // "Solo" wrote every episode whose crew is known; the extra episode
        // has no crew data at all, so it cannot make Solo a partial credit.
        let withUnknown = seasonOne + [episode(1, 7, 6.0, directors: nil, writers: nil)]
        let result = compare(withUnknown)
        #expect(!(result.writersAbove + result.writersBelow).map(\.name).contains("Solo"))
    }

    @Test("a delta that rounds to zero is listed on neither side")
    func roundsToZeroIsHidden() {
        let season = [
            episode(4, 1, 8.02, directors: ["Flat"]),
            episode(4, 2, 8.02, directors: ["Flat"]),
            episode(4, 3, 8.02, directors: ["Flat"]),
            episode(4, 4, 7.94, directors: ["Other"])
        ]
        let result = compare(season)
        #expect(result.isEmpty)
    }

    @Test("rounding is to one decimal, halves away from zero, never negative zero")
    func rounding() {
        #expect(CrewEffectAnalyzer.roundedToTenth(0.06) == 0.1)
        #expect(CrewEffectAnalyzer.roundedToTenth(0.04) == 0)
        #expect(CrewEffectAnalyzer.roundedToTenth(0.25) == 0.3)
        #expect(CrewEffectAnalyzer.roundedToTenth(-0.25) == -0.3)
        #expect(CrewEffectAnalyzer.roundedToTenth(-0.04).sign == .plus)
    }

    @Test("at most three per side, largest first")
    func capsAndOrders() {
        var episodes: [EpisodeMetric] = []
        // Five directors, three episodes each, at increasing distances above
        // a season held down by a sixth.
        for (index, name) in ["A", "B", "C", "D", "E"].enumerated() {
            for number in 0..<3 {
                episodes.append(episode(1, index * 3 + number + 1, 8.0 + Double(index) * 0.2, directors: [name]))
            }
        }
        for number in 16...30 {
            episodes.append(episode(1, number, 6.0, directors: ["Anchor"]))
        }
        let result = compare(episodes)
        #expect(result.directorsAbove.map(\.name) == ["E", "D", "C"])
        #expect(result.directorsBelow.map(\.name) == ["Anchor"])
    }

    // MARK: - Copy

    @Test("the copy states the relation and the sample")
    func copy() {
        let one = CrewComparison.Entry(name: "Vince Gilligan", role: .director, meanDelta: 0.58, roundedDelta: 0.6,
                                       episodeCount: 5, seasonCount: 1)
        #expect(CrewEffectAnalyzer.subject(for: one) == "Episodes directed by Vince Gilligan")
        #expect(CrewEffectAnalyzer.comparison(for: one) == "+0.6 vs. their season's average (5 episodes)")

        let many = CrewComparison.Entry(name: "Peter Gould", role: .writer, meanDelta: -0.34, roundedDelta: -0.3,
                                        episodeCount: 4, seasonCount: 3)
        #expect(CrewEffectAnalyzer.subject(for: many) == "Episodes written by Peter Gould")
        #expect(CrewEffectAnalyzer.comparison(for: many) == "-0.3 vs. their seasons' averages (4 episodes)")
    }

    @MainActor
    @Test("nothing in the section reads as cause and effect")
    func noCausalLanguage() {
        let entry = CrewComparison.Entry(name: "X", role: .director, meanDelta: 1, roundedDelta: 1, episodeCount: 3, seasonCount: 1)
        let text = [
            CrewComparisonSection.methodNote,
            CrewEffectAnalyzer.subject(for: entry),
            CrewEffectAnalyzer.comparison(for: entry),
            "Directors & Writers vs. Their Seasons"
        ].joined(separator: " ").lowercased()
        for banned in ["because", "made it", "behind", "responsible", "thanks to", "caused", "better"] {
            #expect(!text.contains(banned), "found \(banned)")
        }
    }
}

@Suite("Episode crew decoding")
struct EpisodeCrewDecodingTests {
    private let json = """
    {
      "id": 1, "name": "Season 1", "season_number": 1,
      "episodes": [
        {
          "id": 10, "name": "Pilot", "episode_number": 1, "season_number": 1,
          "air_date": "2008-01-20", "still_path": null, "vote_average": 8.9, "vote_count": 412,
          "overview": "", "runtime": 58,
          "crew": [
            {"id": 1, "name": "Vince Gilligan", "job": "Director", "department": "Directing"},
            {"id": 1, "name": "Vince Gilligan", "job": "Writer", "department": "Writing"},
            {"id": 2, "name": "Peter Gould", "job": "Story", "department": "Writing"},
            {"id": 2, "name": "Peter Gould", "job": "Teleplay", "department": "Writing"},
            {"id": 3, "name": "Someone", "job": "Director of Photography", "department": "Camera"}
          ]
        },
        {
          "id": 11, "name": "Two", "episode_number": 2, "season_number": 1,
          "air_date": "2008-01-27", "still_path": null, "vote_average": 8.5, "vote_count": 300,
          "overview": "", "runtime": null
        }
      ]
    }
    """

    private func metrics() throws -> [EpisodeMetric] {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(TMDBSeasonResponse.self, from: Data(json.utf8)).toEpisodeMetrics()
    }

    @Test("directors and writers are read from the episode's crew, each name once")
    func readsCrew() throws {
        let first = try metrics()[0]
        #expect(first.directors == ["Vince Gilligan"])
        #expect(first.writers == ["Vince Gilligan", "Peter Gould"])
    }

    @Test("an episode without a crew key has unknown crew, not an empty one")
    func missingCrewIsUnknown() throws {
        let second = try metrics()[1]
        #expect(second.directors == nil)
        #expect(second.writers == nil)
    }

    /// Season payloads cached before crew was decoded must still read.
    @Test("an episode encoded before the crew fields existed still decodes")
    func legacyCachedEpisodeDecodes() throws {
        let legacy = """
        {"id": 5, "episodeNumber": 1, "seasonNumber": 1, "title": "Pilot", "rating": 8.9,
         "voteCount": 412, "airDate": "2008-01-20", "stillPath": null}
        """
        let decoded = try JSONDecoder().decode(EpisodeMetric.self, from: Data(legacy.utf8))
        #expect(decoded.title == "Pilot")
        #expect(decoded.directors == nil)
        #expect(decoded.writers == nil)
    }
}
