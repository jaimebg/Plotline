import SwiftUI

/// Horizontal bars comparing the TMDB rating across 2-3 titles
struct RatingComparisonBar: View {
    let items: [(index: Int, item: MediaItem)]
    let normalizedValue: (MediaItem) -> Double?
    let displayValue: (MediaItem) -> String?

    /// Colors assigned per slot index for visual distinction
    private let slotColors: [Color] = [.plotlineGold, .plotlineSecondaryAccent, .plotlinePrimary]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Source header
            Text("TMDB")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)

            ForEach(items, id: \.item.id) { index, item in
                HStack(spacing: 8) {
                    // Title label
                    Text(item.displayTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .frame(width: 80, alignment: .trailing)

                    // Colored bar
                    GeometryReader { geometry in
                        let value = normalizedValue(item) ?? 0
                        let barWidth = max(0, geometry.size.width * (value / 100))

                        RoundedRectangle(cornerRadius: 4)
                            .fill(slotColors[index % slotColors.count].gradient)
                            .frame(width: barWidth, height: 20)
                            .animation(.easeOut(duration: 0.4), value: value)
                    }
                    .frame(height: 20)

                    // Score text
                    if let display = displayValue(item) {
                        Text(display)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                            .frame(width: 44, alignment: .leading)
                    } else {
                        Text("--")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 44, alignment: .leading)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(item.displayTitle): \(displayValue(item) ?? "no rating") on TMDB")
            }
        }
    }
}

// MARK: - Preview

#Preview {
    RatingComparisonBar(
        items: [
            (0, .moviePreview),
            (1, .preview)
        ],
        normalizedValue: { item in
            item.voteAverage * 10
        },
        displayValue: { item in
            item.formattedRating
        }
    )
    .padding()
    .background(Color.plotlineBackground)
}
