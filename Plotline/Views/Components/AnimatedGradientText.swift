import SwiftUI

/// A text view with an animated gradient that flows through the text
struct AnimatedGradientText: View {
    let text: String
    var font: Font = .system(size: 34, weight: .bold, design: .default)

    // Gradient colors - gold (brightest) in center, surrounded by darker colors
    private let gradientColors: [Color] = [
        .plotlinePrimary,
        .plotlineSecondaryAccent,
        .plotlineGold,
        .plotlineSecondaryAccent,
        .plotlinePrimary
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
                        // Starts off-screen left (text shows red), gold sweeps through, ends off-screen right (text shows red)
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
