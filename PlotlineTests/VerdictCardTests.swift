import Foundation
import Testing
import UIKit
@testable import Plotline

@MainActor
@Suite("Verdict card")
struct VerdictCardTests {
    private func analysis(
        decline: DeclinePoint? = nil,
        ending: EndingVerdict? = nil,
        isOngoing: Bool = false
    ) -> SeriesAnalysis {
        SeriesAnalysis(
            seasons: [
                SeasonSummary(seasonNumber: 1, weightedAverage: 8.6, standardDeviation: 0.3, reliableEpisodeCount: 10,
                              airedEpisodeCount: 10, bestEpisode: nil, worstEpisode: nil),
                SeasonSummary(seasonNumber: 2, weightedAverage: 8.4, standardDeviation: 0.3, reliableEpisodeCount: 9,
                              airedEpisodeCount: 10, bestEpisode: nil, worstEpisode: nil)
            ],
            bestSeason: 1,
            worstSeason: 2,
            declinePoint: decline,
            consistency: Consistency(rating: .steady, standardDeviation: 0.4, highestRated: nil, lowestRated: nil),
            standoutHighs: [],
            standoutLows: [],
            openingVerdict: nil,
            endingVerdict: ending,
            score: PlotlineScore(value: 81, level: 85, consistency: 66, trajectory: 48),
            isOngoing: isOngoing
        )
    }

    @Test("the basis counts the episodes and seasons the analysis rests on")
    func basisCounts() {
        #expect(VerdictCardContent.basis(for: analysis())
                == "Based on 19 episodes with enough votes to count, across 2 seasons.")
    }

    /// `isOngoing == false` means ended *or unknown*. With no known status the
    /// card must say nothing about the run at all.
    @Test("an unknown status never becomes 'Ended'")
    func unknownStatusSaysNothing() {
        for hasEnded in [nil, true] as [Bool?] {
            let content = VerdictCardContent(
                title: "Show",
                analysis: analysis(isOngoing: false),
                episodes: [],
                hasEnded: hasEnded,
                nextEpisodeDate: nil
            )
            #expect(content.status == nil)
            #expect(!content.allText.joined(separator: " ").localizedCaseInsensitiveContains("ended"))
        }
    }

    @Test("a returning series carries the detail screen's own status copy")
    func returningStatusMatchesScreen() {
        let content = VerdictCardContent(
            title: "Show",
            analysis: analysis(isOngoing: true),
            episodes: [],
            hasEnded: false,
            nextEpisodeDate: nil
        )
        let screen = SeriesVerdictsView.runStatus(hasEnded: false, nextEpisodeDate: nil)
        #expect(content.status?.title == screen?.title)
        #expect(content.status?.evidence == screen?.evidence)
    }

    @Test("decline and ending use the detail screen's strings verbatim")
    func verdictsMatchScreen() {
        let decline = DeclinePoint(afterSeason: 3, averageBefore: 8.4, averageAfter: 7.1, seasonsAfter: [4, 5])
        let ending = EndingVerdict(kind: .fadesOut, finalSeason: 5, finalSeasonAverage: 7.0, peakSeason: 2, peakSeasonAverage: 8.8)
        let content = VerdictCardContent(
            title: "Show",
            analysis: analysis(decline: decline, ending: ending),
            episodes: [],
            hasEnded: true,
            nextEpisodeDate: nil
        )
        #expect(content.decline?.title == SeriesVerdictsView.declineTitle(decline))
        #expect(content.decline?.evidence == SeriesVerdictsView.declineEvidence(decline))
        #expect(content.ending?.title == SeriesVerdictsView.endingTitle(ending))
        #expect(content.ending?.evidence == SeriesVerdictsView.endingEvidence(ending))
    }

    @Test("the curve uses rated, aired main-run episodes in broadcast order")
    func curveFromEpisodes() {
        let episodes = [
            EpisodeFixtures.episode(season: 2, number: 1, rating: 7.0),
            EpisodeFixtures.episode(season: 1, number: 2, rating: 8.0),
            EpisodeFixtures.episode(season: 1, number: 1, rating: 9.0),
            EpisodeFixtures.episode(season: 0, number: 1, rating: 5.0),
            EpisodeFixtures.episode(season: 2, number: 2, rating: 6.0, airDate: EpisodeFixtures.futureAirDate)
        ]
        let content = VerdictCardContent(
            title: "Show",
            analysis: analysis(),
            episodes: episodes,
            hasEnded: nil,
            nextEpisodeDate: nil,
            asOf: EpisodeFixtures.now
        )
        #expect(content.curve == [9.0, 8.0, 7.0])
        #expect(content.curveCaption == "Episode ratings in broadcast order")
    }

    @Test("with no episodes loaded the curve falls back to season averages, and says so")
    func curveFallsBackToSeasons() {
        let content = VerdictCardContent(title: "Show", analysis: analysis(), episodes: [], hasEnded: nil, nextEpisodeDate: nil)
        #expect(content.curve == [8.6, 8.4])
        #expect(content.curveCaption.contains("Season averages"))
    }

    @Test("the card carries the source credit and no recommendation words")
    func creditAndNoRecommendations() {
        let content = VerdictCardContent(title: "Show", analysis: analysis(), episodes: [], hasEnded: nil, nextEpisodeDate: nil)
        let text = content.allText.joined(separator: " ").lowercased()
        #expect(content.allText.contains("Ratings: TMDB · Analysis: Plotline"))
        for banned in ["essential", "must-watch", "must watch", "skip", "stop after"] {
            #expect(!text.contains(banned))
        }
    }

    @Test("the rendered card is 1080 pixels wide")
    func rendersAt1080() throws {
        let content = VerdictCardContent(
            title: "Show",
            analysis: analysis(),
            episodes: EpisodeMetric.breakingBadS1,
            hasEnded: false,
            nextEpisodeDate: nil
        )
        let image = try #require(VerdictCardRenderer.image(for: content))
        #expect(image.size.width * image.scale == 1080)
        #expect(VerdictCardRenderer.pngData(for: content) != nil)
    }
}
