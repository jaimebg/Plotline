import Foundation
import Testing
@testable import Plotline

@Suite("SeriesAnalysis types")
struct SeriesAnalysisTests {
    @Test("an episode reference formats its short code")
    func episodeReferenceShortCode() {
        let reference = EpisodeReference(id: 1, seasonNumber: 5, episodeNumber: 14, title: "Ozymandias", rating: 10.0)
        #expect(reference.shortCode == "S5E14")
    }

    @Test("a decline point derives its drop from the two averages")
    func declinePointDrop() {
        let decline = DeclinePoint(afterSeason: 3, averageBefore: 8.8, averageAfter: 7.9, seasonsAfter: [4, 5])
        #expect(abs(decline.drop - 0.9) < 0.0001)
    }

    @Test("the analyzed result round-trips through Codable")
    func analyzedRoundTrip() throws {
        let analysis = SeriesAnalysis(
            seasons: [
                SeasonSummary(
                    seasonNumber: 1,
                    weightedAverage: 8.4,
                    standardDeviation: 0.3,
                    reliableEpisodeCount: 7,
                    airedEpisodeCount: 9,
                    bestEpisode: EpisodeReference(id: 6, seasonNumber: 1, episodeNumber: 6, title: "Crazy Handful", rating: 8.9),
                    worstEpisode: EpisodeReference(id: 4, seasonNumber: 1, episodeNumber: 4, title: "Cancer Man", rating: 7.9)
                )
            ],
            bestSeason: 1,
            worstSeason: 1,
            declinePoint: nil,
            consistency: Consistency(rating: .steady, standardDeviation: 0.3, highestRated: nil, lowestRated: nil),
            essentialEpisodes: [],
            skippableEpisodes: [],
            openingVerdict: nil,
            endingVerdict: nil,
            score: PlotlineScore(value: 82, level: 84, consistency: 70, trajectory: 50),
            isOngoing: false
        )

        let data = try JSONEncoder().encode(SeriesAnalysisResult.analyzed(analysis))
        let decoded = try JSONDecoder().decode(SeriesAnalysisResult.self, from: data)

        guard case .analyzed(let decodedAnalysis) = decoded else {
            Issue.record("expected .analyzed")
            return
        }
        #expect(decodedAnalysis == analysis)
    }

    @Test("the insufficient-data result round-trips through Codable")
    func insufficientDataRoundTrip() throws {
        let data = try JSONEncoder().encode(SeriesAnalysisResult.insufficientData(.tooFewReliableEpisodes))
        let decoded = try JSONDecoder().decode(SeriesAnalysisResult.self, from: data)
        #expect(decoded == .insufficientData(.tooFewReliableEpisodes))
    }
}
