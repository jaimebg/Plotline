import SwiftUI

extension Color {
    // MARK: - Brand Colors

    /// Main background color (dark)
    static let plotlineBackground = Color(hex: "121212")

    /// Pure black for OLED screens
    static let plotlineBlack = Color(hex: "000000")

    /// Card background color
    static let plotlineCard = Color(hex: "1E1E1E")

    /// Secondary text color
    static let plotlineSecondary = Color(hex: "A0A0A0")

    // MARK: - Rating Colors

    /// IMDb yellow
    static let imdbYellow = Color(hex: "F5C518")

    /// Rotten Tomatoes red (rotten)
    static let rottenRed = Color(hex: "FA320A")

    /// Rotten Tomatoes green (fresh)
    static let rottenGreen = Color(hex: "0AC855")

    /// Metacritic green (favorable)
    static let metacriticGreen = Color(hex: "66CC33")

    /// Metacritic yellow (mixed)
    static let metacriticYellow = Color(hex: "FFCC33")

    /// Metacritic red (unfavorable)
    static let metacriticRed = Color(hex: "FF0000")

    // MARK: - Chart Gradient Colors

    /// High rating color for charts
    static let chartHigh = Color(hex: "4CAF50")

    /// Medium rating color for charts
    static let chartMedium = Color(hex: "FFEB3B")

    /// Low rating color for charts
    static let chartLow = Color(hex: "F44336")

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
