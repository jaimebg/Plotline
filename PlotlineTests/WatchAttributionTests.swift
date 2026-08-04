import Foundation
import Testing
@testable import Plotline

/// TMDB's terms for this endpoint: "In order to use this data you must
/// attribute the source of the data as JustWatch", and "if we find any usage
/// not complying with these terms we will revoke access to the API".
///
/// Every screen in this app is built on TMDB, so losing that access does not
/// degrade a feature — it turns the product off. This test is cheap insurance
/// against a copy edit quietly dropping the credit.
@Suite("Watch provider attribution")
struct WatchAttributionTests {
    @Test("the attribution names JustWatch")
    func attributionNamesJustWatch() {
        #expect(WatchProvidersSection.attribution.contains("JustWatch"))
    }

    @Test("the attribution says JustWatch is the source of the data")
    func attributionCreditsTheSource() {
        let text = WatchProvidersSection.attribution.lowercased()
        #expect(text.contains("justwatch"))
        // Naming them is required; naming them as the source is the point.
        #expect(text.contains("data") || text.contains("provided") || text.contains("source"))
    }
}
