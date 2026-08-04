import Foundation
import Testing
@testable import Plotline

/// A guard on the one requirement in this app whose breach is unrecoverable.
///
/// TMDB's terms for the watch-providers endpoint: *"In order to use this data
/// you must attribute the source of the data as JustWatch"*, and *"if we find
/// any usage not complying with these terms we will revoke access to the API"*.
/// Every screen in Plotline is served by TMDB, so that revocation would not
/// degrade a feature — it would end the product.
///
/// `WatchAttributionTests` checks the attribution *string*. It cannot check
/// that the string is ever drawn: deleting `Text(Self.attribution)` from the
/// view body leaves it green. Asserting on a rendered SwiftUI tree needs
/// infrastructure this project does not have, so this suite reads the view's
/// own source instead. Unusual, and proportionate to a requirement that has no
/// second chance.
@Suite("Watch attribution is rendered")
struct WatchAttributionSourceTests {
    /// The view's source, located relative to this file's compile-time path.
    private func sectionSource() throws -> String {
        let testFile = URL(fileURLWithPath: #filePath)
        let repoRoot = testFile
            .deletingLastPathComponent()   // PlotlineTests/
            .deletingLastPathComponent()   // repo root
        let source = repoRoot
            .appendingPathComponent("Plotline/Views/Detail/WatchProvidersSection.swift")

        return try String(contentsOf: source, encoding: .utf8)
    }

    @Test("the section's body draws the attribution")
    func attributionIsDrawn() throws {
        let source = try sectionSource()

        #expect(
            source.contains("Text(Self.attribution)"),
            "WatchProvidersSection must draw its JustWatch credit. TMDB revokes API access for showing this data without it, and this app has no other data source."
        )
    }

    /// The credit must not sit inside a conditional. It is drawn whenever the
    /// section is, or the guarantee is only as good as the branch taken.
    @Test("the attribution is not nested inside a conditional")
    func attributionIsUnconditional() throws {
        let source = try sectionSource()
        let lines = source.split(separator: "\n", omittingEmptySubsequences: false)

        let line = try #require(
            lines.first { $0.contains("Text(Self.attribution)") },
            "the attribution line should exist — see attributionIsDrawn"
        )

        // Inside `body`'s VStack the credit sits at three levels of
        // indentation. Any deeper means a branch wraps it.
        let indent = line.prefix { $0 == " " }.count
        #expect(
            indent <= 12,
            "the attribution is indented \(indent) spaces, which suggests it moved inside a conditional"
        )
    }
}
