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
}
