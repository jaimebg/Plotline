import SwiftUI

/// Layout values shared by every adaptive grid in the app.
///
/// Grids size themselves from the width they are given rather than from the
/// device or the size class. One minimum width yields two columns on a phone
/// and five or six on an iPad, and it stays right when the app is running in a
/// third of an iPad's screen — the case a size-class branch gets wrong, since
/// it would still call for four columns in a 320pt window.
enum AdaptiveLayout {
    /// The one number every adaptive grid in the app is built from.
    ///
    /// What actually binds this value: iOS 26 still ships iPhone SE and
    /// iPhone 12/13 mini at 375pt logical width, which is 343pt of content
    /// once a 32pt padding is removed. Two columns there requires a minimum
    /// no larger than 165.5pt — `(343 + 12) / (m + 12) >= 2` — so 160 is the
    /// ceiling with a little room to spare. Below that ceiling a poster grid,
    /// a banner grid, and a stats-card grid all resolve to the exact same
    /// column count at every width that matters here — 375pt, 402pt, 820pt
    /// (iPad Air 11"), 1024pt (iPad Pro 13") — so one constant is what the
    /// three separately named ones actually were, and the rest is as many
    /// columns as fit on anything wider.
    static let minimumColumnWidth: CGFloat = 160

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
