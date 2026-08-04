import SwiftUI
import Testing
@testable import Plotline

@Suite("Adaptive layout")
struct AdaptiveLayoutTests {
    /// The count SwiftUI will settle on for a given container width, mirrored
    /// here so the chosen minimum can be checked against real device widths
    /// without rendering anything.
    private func columnCount(width: CGFloat, minimum: CGFloat, spacing: CGFloat) -> Int {
        max(1, Int((width + spacing) / (minimum + spacing)))
    }

    @Test("grids give two columns on the narrowest supported iPhone and more on an iPad")
    func gridAdapts() {
        let minimum = AdaptiveLayout.minimumColumnWidth
        let spacing = AdaptiveLayout.gridSpacing

        // iPhone SE / mini portrait — the narrowest iPhone iOS 26 still
        // supports — minus the 16pt padding on each side.
        #expect(columnCount(width: 375 - 32, minimum: minimum, spacing: spacing) == 2)
        // iPhone 17 portrait, minus the 16pt padding on each side.
        #expect(columnCount(width: 402 - 32, minimum: minimum, spacing: spacing) == 2)
        // iPad Air 11" portrait — the review device.
        #expect(columnCount(width: 820 - 32, minimum: minimum, spacing: spacing) >= 4)
    }

    @Test("adaptiveColumns builds a single adaptive GridItem with the given minimum")
    func adaptiveColumnsBuildsAnAdaptiveItem() {
        let columns = GridItem.adaptiveColumns(minimumWidth: AdaptiveLayout.minimumColumnWidth)

        #expect(columns.count == 1)
        guard case .adaptive(let minimum, _) = columns[0].size else {
            Issue.record("Expected an .adaptive GridItem, got \(columns[0].size)")
            return
        }
        #expect(minimum == AdaptiveLayout.minimumColumnWidth)
    }

    /// Multitasking is where a size-class branch would go wrong: an iPad in a
    /// one-third split is a compact width and must still resolve to a usable
    /// column count rather than the four a size-class check would call for.
    @Test("a narrow multitasking split resolves to a single column")
    func narrowSplitFallsBackToOneColumn() {
        let minimum = AdaptiveLayout.minimumColumnWidth
        let spacing = AdaptiveLayout.gridSpacing

        #expect(columnCount(width: 320, minimum: minimum, spacing: spacing) == 1)
    }

    /// 440pt is the iPhone 17 Pro Max, the widest iPhone there is. Checking
    /// against a narrower one would leave the claim in this test's name
    /// unproven for the phones most likely to expose it.
    @Test("the readable width does not constrain even the widest phone")
    func readableWidthLeavesPhonesAlone() {
        #expect(AdaptiveLayout.readableMaximumWidth > 440)
    }

    /// The Stats tab nests Trends inside its own padded scroll view. Trends
    /// used to add a second `.padding()` of its own, so the grid ran on 64pt
    /// less than the screen and dropped to one column on every iPhone below
    /// 402pt — the build device cleared it by 6pt, which is why it survived
    /// both the tests and an on-screen check.
    @Test("a grid under two levels of padding still gets two columns on a narrow phone")
    func doublePaddingWouldBreakNarrowPhones() {
        let minimum = AdaptiveLayout.minimumColumnWidth
        let spacing = AdaptiveLayout.gridSpacing

        // What the nested layout used to leave for the grid on an iPhone 15.
        #expect(columnCount(width: 393 - 64, minimum: minimum, spacing: spacing) == 1)
        // What a single level of padding leaves, which is what it gets now.
        #expect(columnCount(width: 393 - 32, minimum: minimum, spacing: spacing) == 2)
    }
}
