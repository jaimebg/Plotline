import SwiftUI
import Testing
@testable import Plotline

@Suite("Adaptive layout")
struct AdaptiveLayoutTests {
    /// The count SwiftUI will settle on for a given container width, mirrored
    /// here so the chosen minimums can be checked against real device widths
    /// without rendering anything.
    private func columnCount(width: CGFloat, minimum: CGFloat, spacing: CGFloat) -> Int {
        max(1, Int((width + spacing) / (minimum + spacing)))
    }

    @Test("poster grids give two columns on an iPhone and more on an iPad")
    func posterGridAdapts() {
        let minimum = AdaptiveLayout.posterMinimumWidth
        let spacing = AdaptiveLayout.gridSpacing

        // iPhone 17 portrait, minus the 16pt padding on each side.
        #expect(columnCount(width: 402 - 32, minimum: minimum, spacing: spacing) == 2)
        // iPad Air 11" portrait — the review device.
        #expect(columnCount(width: 820 - 32, minimum: minimum, spacing: spacing) >= 4)
    }

    @Test("banner grids stay readable rather than stretching")
    func bannerGridAdapts() {
        let minimum = AdaptiveLayout.bannerMinimumWidth
        let spacing = AdaptiveLayout.gridSpacing

        #expect(columnCount(width: 402 - 32, minimum: minimum, spacing: spacing) == 2)
        #expect(columnCount(width: 820 - 32, minimum: minimum, spacing: spacing) >= 3)
    }

    /// Multitasking is where a size-class branch would go wrong: an iPad in a
    /// one-third split is a compact width and must fall back to two columns.
    @Test("a narrow multitasking split falls back to two columns")
    func narrowSplitStaysCompact() {
        let minimum = AdaptiveLayout.posterMinimumWidth
        let spacing = AdaptiveLayout.gridSpacing

        #expect(columnCount(width: 320, minimum: minimum, spacing: spacing) <= 2)
    }

    @Test("the readable width does not constrain a phone")
    func readableWidthLeavesPhonesAlone() {
        #expect(AdaptiveLayout.readableMaximumWidth > 402)
    }
}
