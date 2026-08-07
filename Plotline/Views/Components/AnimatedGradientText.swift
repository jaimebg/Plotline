import SwiftUI

/// A text view with an animated gradient that flows through the text
struct AnimatedGradientText: View {
    let text: String
    var font: Font = .system(.largeTitle, design: .default, weight: .bold)

    // Gradient colors - gold (brightest) in center, surrounded by darker colors.
    // The ends take the fixed deep orange rather than the adaptive accent: in
    // dark mode the accent (#FF7A33) is close enough to plotlineSecondaryAccent
    // (#FF6500) that the ramp would collapse.
    private let gradientColors: [Color] = [
        .plotlineAccentDeep,
        .plotlineSecondaryAccent,
        .plotlineGold,
        .plotlineSecondaryAccent,
        .plotlineAccentDeep
    ]

    var body: some View {
        TimelineView(.animation) { timeline in
            let phase = calculatePhase(from: timeline.date)

            Text(text)
                .font(font)
                .foregroundStyle(
                    LinearGradient(
                        colors: gradientColors,
                        // Gradient is 2 units wide, moves 3 units total
                        // Starts off-screen left (text shows deep orange), gold
                        // sweeps through, ends off-screen right (deep orange again)
                        startPoint: UnitPoint(x: -2 + phase * 3, y: 0.5),
                        endPoint: UnitPoint(x: 0 + phase * 3, y: 0.5)
                    )
                )
        }
    }

    private func calculatePhase(from date: Date) -> Double {
        let seconds = date.timeIntervalSinceReferenceDate
        // Complete one cycle every 6 seconds
        return (seconds.truncatingRemainder(dividingBy: 6)) / 6
    }
}

#Preview {
    VStack(spacing: 20) {
        AnimatedGradientText(text: "Plotline")

        AnimatedGradientText(
            text: "Discover Movies",
            font: .system(.headline, design: .rounded, weight: .semibold)
        )
    }
    .padding()
    .background(Color.plotlineBackground)
}
