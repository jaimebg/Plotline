import SwiftUI

/// Horizontal bars comparing a single rating source across 2-3 titles
struct RatingComparisonBar: View {
    let sourceName: String
    let items: [(index: Int, item: MediaItem)]
    let normalizedValue: (String, MediaItem) -> Double?
    let displayValue: (String, MediaItem) -> String?

    /// Colors assigned per slot index for visual distinction
    private let slotColors: [Color] = [.plotlineGold, .plotlineSecondaryAccent, .plotlinePrimary]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Source header
            Text(displaySourceName)
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
                        let value = normalizedValue(sourceName, item) ?? 0
                        let barWidth = max(0, geometry.size.width * (value / 100))

                        RoundedRectangle(cornerRadius: 4)
                            .fill(slotColors[index % slotColors.count].gradient)
                            .frame(width: barWidth, height: 20)
                            .animation(.easeOut(duration: 0.4), value: value)
                    }
                    .frame(height: 20)

                    // Score text
                    if let display = displayValue(sourceName, item) {
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
            }
        }
    }

    private var displaySourceName: String {
        switch sourceName {
        case "Internet Movie Database": return "IMDb"
        case "Rotten Tomatoes": return "Rotten Tomatoes"
        case "Metacritic": return "Metacritic"
        case "TMDB": return "TMDB"
        default: return sourceName
        }
    }
}

// MARK: - Preview

#Preview {
    RatingComparisonBar(
        sourceName: "TMDB",
        items: [
            (0, .moviePreview),
            (1, .preview)
        ],
        normalizedValue: { _, item in
            item.voteAverage * 10
        },
        displayValue: { _, item in
            item.formattedRating
        }
    )
    .padding()
    .background(Color.plotlineBackground)
}
