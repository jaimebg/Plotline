import Testing
@testable import Plotline

@Suite("Smoke")
struct SmokeTests {
    @Test("the test target can see the app module")
    func canImportAppModule() {
        let metric = EpisodeMetric.preview
        #expect(metric.seasonNumber == 1)
    }
}
