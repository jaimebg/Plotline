import SwiftUI

/// Layout values shared by every adaptive grid in the app.
///
/// Grids size themselves from the width they are given rather than from the
/// device or the size class. One minimum width yields two columns on a phone
/// and five or six on an iPad, and it stays right when the app is running in a
/// third of an iPad's screen — the case a size-class branch gets wrong, since
/// it would still call for four columns in a 320pt window.
enum AdaptiveLayout {
    /// Enough for a poster and its two lines of caption.
    static let posterMinimumWidth: CGFloat = 160

    /// Wide enough that a genre or mood banner still reads as a banner, while
    /// still resolving to two columns on an iPhone: at 12pt spacing, a phone
    /// gives a container width of 370pt, and 370pt only splits into two
    /// columns for minimums up to 179pt.
    static let bannerMinimumWidth: CGFloat = 175

    /// Statistics cards carry a number and a label.
    static let cardMinimumWidth: CGFloat = 180

    static let gridSpacing: CGFloat = 12

    /// Where a column of running text stops growing.
    ///
    /// Beyond roughly this width the eye loses the start of the next line. It
    /// sits well above any iPhone width so phones are never affected.
    static let readableMaximumWidth: CGFloat = 700
}

extension GridItem {
    /// Columns that fit the available width, rather than a fixed count.
    static func adaptiveColumns(
        minimumWidth: CGFloat,
        spacing: CGFloat = AdaptiveLayout.gridSpacing
    ) -> [GridItem] {
        [GridItem(.adaptive(minimum: minimumWidth), spacing: spacing)]
    }
}

extension View {
    /// Stops a column of text growing past a comfortable reading width and
    /// centres it in whatever space is left.
    ///
    /// A no-op on iPhone, where the screen is narrower than the maximum.
    func readableWidth(_ maximum: CGFloat = AdaptiveLayout.readableMaximumWidth) -> some View {
        frame(maxWidth: maximum, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
    }
}
