import Foundation
import Testing
@testable import DatasetGeneratorCore

/// Tests against the artifact that actually ships, not against a fixture.
///
/// The defect this suite exists for got through five green reviews because
/// every test looked at the builder in isolation. Nine titles whose own
/// analysis said `fadesOut` sat on a shelf called "never declines" in the
/// committed file, and nothing was reading the committed file.
@Suite("Shipped dataset")
struct ShippedDatasetTests {
    /// The repo root, derived from this file rather than from the working
    /// directory, which `swift test` does not promise.
    private static var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // DatasetGeneratorTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // DatasetGenerator
            .deletingLastPathComponent()  // Tools
            .deletingLastPathComponent()  // repo root
    }

    private static var datasetURL: URL {
        repositoryRoot.appendingPathComponent("Plotline/Resources/PlotlineDataset.json")
    }

    private func shippedDataset() throws -> PlotlineDataset {
        let url = Self.datasetURL
        try #require(
            FileManager.default.fileExists(atPath: url.path),
            "the bundled dataset is missing at \(url.path)"
        )
        return try JSONDecoder().decode(PlotlineDataset.self, from: Data(contentsOf: url))
    }

    @Test("the committed dataset decodes against the current contract")
    func decodes() throws {
        let dataset = try shippedDataset()
        #expect(dataset.version == PlotlineDataset.currentVersion)
        #expect(!dataset.entries.isEmpty)
    }

    @Test("no series on the never-decline list fades out")
    func neverDeclineNeverFadesOut() throws {
        let dataset = try shippedDataset()
        // Required, not optional: if this shelf ever stops shipping, the one
        // invariant the whole fix wave restored would go unguarded while the
        // suite stayed green. Its absence has to be red.
        let list = try #require(
            dataset.lists.first { $0.id == "never-decline" },
            "the never-decline list is not in the shipped dataset"
        )

        let byId = Dictionary(uniqueKeysWithValues: dataset.entries.map { ($0.tmdbId, $0) })
        for id in list.tmdbIds {
            let entry = try #require(byId[id])
            #expect(
                entry.analysis.endingVerdict?.kind != .fadesOut,
                "\(entry.name) is shelved as never declining while its own analysis says it fades out"
            )
        }
    }

    @Test("every shipped list agrees with the analysis of every member")
    func listsAgreeWithTheirMembers() throws {
        let dataset = try shippedDataset()
        // A dataset with no lists at all would pass every loop below without
        // checking anything, so make the empty case red rather than vacuous.
        try #require(!dataset.lists.isEmpty, "the shipped dataset carries no lists")

        let byId = Dictionary(uniqueKeysWithValues: dataset.entries.map { ($0.tmdbId, $0) })

        for list in dataset.lists {
            #expect(list.tmdbIds.count >= DatasetBuilder.minimumListSize)

            // Re-running the predicate over exactly the shipped membership has
            // to return exactly that membership: every member still qualifies.
            let members = try list.tmdbIds.map { try #require(byId[$0]) }
            let rebuilt = DatasetBuilder.curatedLists(from: members).first { $0.id == list.id }
            #expect(rebuilt?.tmdbIds == list.tmdbIds)
        }
    }

    @Test("every list member is an entry in the same file")
    func listsOnlyReferenceKnownEntries() throws {
        let dataset = try shippedDataset()
        try #require(!dataset.lists.isEmpty, "the shipped dataset carries no lists")

        let known = Set(dataset.entries.map(\.tmdbId))

        for list in dataset.lists {
            for id in list.tmdbIds {
                #expect(known.contains(id), "list \(list.id) points at unknown id \(id)")
            }
        }
    }

    @Test("no skip reason carries anything that could be a secret")
    func skipsCarryNoSecrets() throws {
        let dataset = try shippedDataset()
        for skip in dataset.skipped {
            guard let detail = skip.detail else { continue }
            #expect(!detail.lowercased().contains("api_key"))
            #expect(!detail.contains("://"))
        }
    }

    @Test("the raw file contains no API key and no award-shaped junk")
    func fileIsClean() throws {
        let text = try String(contentsOf: Self.datasetURL, encoding: .utf8)

        // The generator must never interpolate an error, whose userInfo carries
        // the failing URL, whose query carries the key.
        #expect(!text.contains("api_key"))
        #expect(!text.contains("themoviedb.org"))
        #expect(!text.contains("NSErrorFailingURL"))

        let dataset = try shippedDataset()
        for entry in dataset.entries {
            for award in entry.awards {
                #expect(!WikidataClient.isUnusableLabel(award), "\(entry.name) carries \"\(award)\" as an award")
            }
        }
    }
}
