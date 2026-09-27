import Foundation
import Testing
@testable import Plotline

@Suite("Box office figures")
struct BoxOfficeDataTests {
    /// TMDB stores an unknown gross as 0. Read literally, that is a film that
    /// earned nothing — "-100%" on screen for a figure nobody reported.
    @Test("an unknown gross yields no return and no difference")
    func unknownRevenue() {
        let data = BoxOfficeData(budget: 50_000_000, revenue: 0)

        #expect(data.hasData)
        #expect(data.roi == nil)
        #expect(data.roiPercentage == nil)
        #expect(data.formattedROI == nil)
        #expect(data.profit == nil)
        #expect(data.formattedProfit == nil)
        #expect(!data.isProfitable)
    }

    @Test("an unknown budget yields no return and no difference")
    func unknownBudget() {
        let data = BoxOfficeData(budget: 0, revenue: 80_000_000)

        #expect(data.roi == nil)
        #expect(data.formattedProfit == nil)
    }

    @Test("a gross below budget keeps its minus sign")
    func lossKeepsItsSign() {
        let data = BoxOfficeData.flopPreview // 175M budget, 75M gross

        #expect(data.profit == -100_000_000)
        #expect(data.formattedProfit == "-$100M")
        #expect(data.formattedROI == "-57%")
    }

    @Test("a gross above budget is signed positive")
    func gainIsSignedPositive() {
        let data = BoxOfficeData.modestPreview // 50M budget, 150M gross

        #expect(data.formattedProfit == "+$100M")
        #expect(data.formattedROI == "3.0x")
        #expect(data.isProfitable)
    }
}
