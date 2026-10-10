import Foundation
import Testing

/// Keeps the featured card out of the screenshot suite's label matches.
/// Source-level for the same reason as the other *SourceTests: the failure is
/// in a run these tests never perform.
@Suite("Featured card stays out of capture matches")
struct FeaturedCardSourceTests {
    private var source: String {
        get throws {
            let url = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Plotline/Views/Discovery/FeaturedSeriesCard.swift")
            return try String(contentsOf: url, encoding: .utf8)
        }
    }

    @Test("children are combined under one label that starts with \"Featured series\"")
    func combinedLabel() throws {
        let text = try source
        #expect(text.contains(".accessibilityElement(children: .ignore)"))
        #expect(text.contains(".accessibilityLabel(\"Featured series"))
    }

    @Test("the score caption is never the literal \"Plotline Score\"")
    func noPlotlineScoreText() throws {
        #expect(!(try source).contains("Text(\"Plotline Score\")"))
    }
}
