import Foundation
import Testing
@testable import Plotline

@Suite("Curated list ids")
struct CuratedListIDTests {
    @Test("a main shelf id has no genre")
    func mainShelf() throws {
        let id = try #require(CuratedListID("never-decline"))
        #expect(id.base == "never-decline")
        #expect(id.genreId == nil)
    }

    @Test("a genre shelf id carries its base and its genre")
    func genreShelf() throws {
        let id = try #require(CuratedListID("falls-off/18"))
        #expect(id.base == "falls-off")
        #expect(id.genreId == 18)
    }

    @Test("a malformed id does not parse", arguments: [
        "", "/18", "never-decline/", "never-decline/drama", "never-decline/18/35",
        "never-decline/+18", "never-decline/-18", "never-decline/0", "never-decline/١٨",
    ])
    func malformed(raw: String) {
        #expect(CuratedListID(raw) == nil)
    }
}
