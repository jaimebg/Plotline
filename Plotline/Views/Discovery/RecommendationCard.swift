import SwiftUI

/// A horizontal card displaying a recommendation with poster, metadata, and "why" line
struct RecommendationCard: View {
    let item: MediaItem
    let whyLine: String?

    var body: some View {
        HStack(spacing: 14) {
            // Poster
            AsyncImage(url: item.posterURL) { phase in
                switch phase {
                case .empty:
                    Rectangle()
                        .fill(Color.plotlineCard)
                        .shimmering()

                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 120)
                        .clipped()

                case .failure:
                    Rectangle()
                        .fill(Color.plotlineCard)
                        .overlay {
                            Image(systemName: item.isTVSeries ? "tv" : "film")
                                .foregroundStyle(.secondary)
                        }

                @unknown default:
                    Rectangle()
                        .fill(Color.plotlineCard)
                }
            }
            .frame(width: 80, height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // Metadata
            VStack(alignment: .leading, spacing: 6) {
                Text(item.displayTitle)
                    .font(.system(.headline, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                if let year = item.year {
                    Text(year)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if item.voteAverage > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(Color.imdbYellow)
                        Text(item.formattedRating)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                    }
                }

                if let whyLine {
                    Text(whyLine)
                        .font(.caption)
                        .foregroundStyle(Color.plotlineSecondaryAccent)
                        .lineLimit(2)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
        .padding(14)
        .background(Color.plotlineCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(recommendationAccessibilityLabel)
    }

    private var recommendationAccessibilityLabel: String {
        var label = item.displayTitle
        if let year = item.year { label += ", \(year)" }
        if item.voteAverage > 0 { label += ", rated \(item.formattedRating) out of 10" }
        if let whyLine { label += ". \(whyLine)" }
        return label
    }
}

// MARK: - Preview

#Preview {
    RecommendationCard(
        item: MediaItem.preview,
        whyLine: "Matches your thrilling mood"
    )
    .padding()
    .background(Color.plotlineBackground)
}
