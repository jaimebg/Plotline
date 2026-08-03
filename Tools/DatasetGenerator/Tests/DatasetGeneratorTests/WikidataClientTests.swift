import Foundation
import Testing
@testable import DatasetGeneratorCore

@Suite("Wikidata awards")
struct WikidataClientTests {
    /// Shape of a real SPARQL JSON response, trimmed.
    private let responseJSON = """
    {
      "head": { "vars": ["tmdbId", "awardLabel"] },
      "results": { "bindings": [
        {"tmdbId": {"type": "literal", "value": "1396"},
         "awardLabel": {"type": "literal", "value": "Primetime Emmy Award for Outstanding Drama Series"}},
        {"tmdbId": {"type": "literal", "value": "1396"},
         "awardLabel": {"type": "literal", "value": "Peabody Awards"}},
        {"tmdbId": {"type": "literal", "value": "1399"},
         "awardLabel": {"type": "literal", "value": "Primetime Emmy Award for Outstanding Drama Series"}}
      ]}
    }
    """

    @Test("groups awards by TMDB id")
    func groupsByTMDBId() throws {
        let awards = try WikidataClient.decodeAwards(Data(responseJSON.utf8))
        #expect(awards[1396]?.count == 2)
        #expect(awards[1399] == ["Primetime Emmy Award for Outstanding Drama Series"])
    }

    @Test("sorts each title's awards so the dataset is reproducible")
    func sortsAwards() throws {
        let awards = try WikidataClient.decodeAwards(Data(responseJSON.utf8))
        #expect(awards[1396] == ["Peabody Awards", "Primetime Emmy Award for Outstanding Drama Series"])
    }

    @Test("ignores rows whose TMDB id is not a number")
    func ignoresNonNumericIds() throws {
        let json = """
        {"head": {"vars": []}, "results": {"bindings": [
          {"tmdbId": {"type": "literal", "value": "not-a-number"},
           "awardLabel": {"type": "literal", "value": "Some Award"}}
        ]}}
        """
        #expect(try WikidataClient.decodeAwards(Data(json.utf8)).isEmpty)
    }

    @Test("an empty result set decodes to an empty map rather than throwing")
    func handlesEmptyResults() throws {
        let json = #"{"head": {"vars": []}, "results": {"bindings": []}}"#
        #expect(try WikidataClient.decodeAwards(Data(json.utf8)).isEmpty)
    }

    @Test("builds a query naming every requested id")
    func buildsQuery() {
        let query = WikidataClient.awardsQuery(forSeriesIds: [1396, 1399])
        #expect(query.contains("\"1396\""))
        #expect(query.contains("\"1399\""))
        #expect(query.contains("P4983"))
        #expect(query.contains("P166"))
    }

    // MARK: - Label hygiene

    @Test("drops labels the label service could not resolve to a name")
    func dropsBareQIDs() throws {
        let json = """
        {"head": {"vars": []}, "results": {"bindings": [
          {"tmdbId": {"type": "literal", "value": "66732"},
           "awardLabel": {"type": "literal", "value": "Q3403230"}},
          {"tmdbId": {"type": "literal", "value": "66732"},
           "awardLabel": {"type": "literal", "value": "Peabody Awards"}}
        ]}}
        """
        #expect(try WikidataClient.decodeAwards(Data(json.utf8))[66732] == ["Peabody Awards"])
    }

    @Test("drops Wikidata's index articles, which are not awards")
    func dropsListArticles() throws {
        let json = """
        {"head": {"vars": []}, "results": {"bindings": [
          {"tmdbId": {"type": "literal", "value": "66732"},
           "awardLabel": {"type": "literal", "value": "list of awards and nominations received by Stranger Things"}}
        ]}}
        """
        #expect(try WikidataClient.decodeAwards(Data(json.utf8)).isEmpty)
    }

    @Test("keeps award names that merely look like the dropped shapes")
    func keepsLegitimateNames() {
        #expect(WikidataClient.isUnusableLabel("Queerty Award") == false)
        #expect(WikidataClient.isUnusableLabel("Q") == false)
        #expect(WikidataClient.isUnusableLabel("Q3403230"))
        #expect(WikidataClient.isUnusableLabel("List of awards received by X"))
    }

    // MARK: - Batching

    @Test("splits ids into batches the endpoint can answer inside its timeout")
    func batchesIds() {
        let ids = Array(1...120)
        let batches = WikidataClient.batches(of: ids, size: 50)

        #expect(batches.count == 3)
        #expect(batches.map(\.count) == [50, 50, 20])
        #expect(batches.flatMap { $0 } == ids, "batching must lose or reorder nothing")
        #expect(batches.allSatisfy { $0.count <= WikidataClient.maxIdsPerQuery })
    }

    @Test("a batch never exceeds the query limit for the real seed list")
    func batchesTheSeedList() {
        let batches = WikidataClient.batches(of: SeedList.seriesIds)
        #expect(batches.flatMap { $0 } == SeedList.seriesIds)
        #expect(batches.allSatisfy { $0.count <= WikidataClient.maxIdsPerQuery })
    }

    @Test("an empty id list produces no batches at all")
    func batchesNothing() {
        #expect(WikidataClient.batches(of: []).isEmpty)
    }
}
