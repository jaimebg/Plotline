import SwiftUI

extension Color {
    // MARK: - Brand Colors

    /// Primary accent - dark red
    static let plotlinePrimary = Color(hex: "C40C0C")

    /// Secondary accent - orange
    nonisolated static let plotlineSecondaryAccent = Color(hex: "FF6500")

    /// Tertiary accent - burnt orange
    static let plotlineTertiary = Color(hex: "CC561E")

    /// Highlight - golden yellow. A fill and stroke colour only: as text on a
    /// light background it measures about 1.5:1. Text and glyphs take the
    /// adaptive `plotlineGoldText` instead.
    nonisolated static let plotlineGold = Color(hex: "F6CE71")

    // MARK: - Adaptive Colors
    // Note: plotlineAccent, plotlineBackground, plotlineBlack, plotlineCard,
    // plotlineSecondary and plotlineGoldText are auto-generated from Asset
    // Catalog color sets. plotlineGoldText is #7D5A00 in light mode (at least
    // 5.4:1 on white, #F5F5F5 and a 20% gold tint) and the brand gold #F6CE71
    // in dark mode.

    /// Fixed deep orange for gradients that used to start at `plotlinePrimary`.
    ///
    /// `plotlineAccent` adapts to the appearance, and its dark value (#FF7A33)
    /// sits close enough to `plotlineSecondaryAccent` (#FF6500) that a ramp
    /// between the two collapses to a flat fill. Gradients take this fixed
    /// value instead, so they keep their range in both appearances.
    nonisolated static let plotlineAccentDeep = Color(hex: "B33A00")

    // MARK: - Rating Colors (Industry Standard)

    /// IMDb yellow (same as plotlineGold)
    static let imdbYellow = plotlineGold

    /// Rotten Tomatoes red (same as plotlinePrimary)
    static let rottenRed = plotlinePrimary

    /// Rotten Tomatoes green (fresh)
    static let rottenGreen = Color(hex: "0AC855")

    /// Metacritic green (favorable)
    static let metacriticGreen = Color(hex: "66CC33")

    /// Metacritic yellow (same as plotlineGold)
    static let metacriticYellow = plotlineGold

    /// Metacritic red (same as plotlinePrimary)
    static let metacriticRed = plotlinePrimary

    // MARK: - Chart Gradient Colors

    /// High rating color for charts (same as plotlineGold)
    static let chartHigh = plotlineGold

    /// Medium rating color for charts (same as plotlineSecondaryAccent)
    static let chartMedium = plotlineSecondaryAccent

    /// Low rating color for charts (same as plotlinePrimary)
    static let chartLow = plotlinePrimary

    // MARK: - Episode Rating Grid Colors

    /// Awesome: 9.0+ (bright green)
    static let ratingAwesome = Color(hex: "4CAF50")

    /// Great: 8.0-8.9 (light green)
    static let ratingGreat = Color(hex: "8BC34A")

    /// Good: 7.0-7.9 (yellow)
    static let ratingGood = Color(hex: "FFEB3B")

    /// Regular: 6.0-6.9 (orange)
    static let ratingRegular = Color(hex: "FF9800")

    /// Bad: 5.0-5.9 (red)
    static let ratingBad = Color(hex: "F44336")

    /// Garbage: < 5.0 (purple)
    static let ratingGarbage = Color(hex: "9C27B0")

    // MARK: - Hex Initializer

    nonisolated init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Gradient Extensions

extension LinearGradient {
    /// Brand gradient (deep orange to gold). Fixed rather than adaptive: see
    /// `plotlineAccentDeep`.
    static let plotlineGradient = LinearGradient(
        colors: [.plotlineAccentDeep, .plotlineSecondaryAccent, .plotlineGold],
        startPoint: .leading,
        endPoint: .trailing
    )
}
