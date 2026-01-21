import SwiftUI

extension Color {
    // MARK: - Brand Colors

    /// Primary accent - dark red
    static let plotlinePrimary = Color(hex: "C40C0C")

    /// Secondary accent - orange
    static let plotlineSecondaryAccent = Color(hex: "FF6500")

    /// Tertiary accent - burnt orange
    static let plotlineTertiary = Color(hex: "CC561E")

    /// Highlight - golden yellow
    static let plotlineGold = Color(hex: "F6CE71")

    // MARK: - Adaptive Background Colors
    // Note: plotlineBackground, plotlineBlack, plotlineCard, plotlineSecondary
    // are auto-generated from Asset Catalog color sets

    // MARK: - Fallback Colors (for programmatic use)

    /// Dark mode background
    static let plotlineBackgroundDark = Color(hex: "121212")

    /// Light mode background
    static let plotlineBackgroundLight = Color(hex: "F5F5F5")

    /// Dark mode card
    static let plotlineCardDark = Color(hex: "1E1E1E")

    /// Light mode card
    static let plotlineCardLight = Color(hex: "FFFFFF")

    /// Dark mode secondary text
    static let plotlineSecondaryDark = Color(hex: "A0A0A0")

    /// Light mode secondary text
    static let plotlineSecondaryLight = Color(hex: "666666")

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

    init(hex: String) {
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
    /// Gradient for chart lines based on rating
    static let ratingGradient = LinearGradient(
        colors: [.chartLow, .chartMedium, .chartHigh],
        startPoint: .bottom,
        endPoint: .top
    )

    /// Brand gradient (red to gold)
    static let plotlineGradient = LinearGradient(
        colors: [.plotlinePrimary, .plotlineSecondaryAccent, .plotlineGold],
        startPoint: .leading,
        endPoint: .trailing
    )

    /// Vertical fade to black (for backdrop overlays)
    static let fadeToBlack = LinearGradient(
        colors: [.clear, .black],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Horizontal fade to black (for horizontal images)
    static let horizontalFadeToBlack = LinearGradient(
        colors: [.clear, .black.opacity(0.8)],
        startPoint: .leading,
        endPoint: .trailing
    )
}
