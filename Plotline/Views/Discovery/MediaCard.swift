import SwiftUI

/// Card component for displaying media items in carousels
struct MediaCard: View {
    let item: MediaItem
    let style: CardStyle

    enum CardStyle {
        case poster      // Vertical poster (2:3 ratio)
        case backdrop    // Horizontal backdrop (16:9 ratio)
        case compact     // Small compact card for search results

        var width: CGFloat {
            switch self {
            case .poster: return 140
            case .backdrop: return 280
            case .compact: return 100
            }
        }

        var height: CGFloat {
            switch self {
            case .poster: return 210
            case .backdrop: return 158
            case .compact: return 150
            }
        }

        var cornerRadius: CGFloat {
            switch self {
            case .poster: return 12
            case .backdrop: return 16
            case .compact: return 8
            }
        }
    }

    init(item: MediaItem, style: CardStyle = .poster) {
        self.item = item
        self.style = style
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Image
            imageView
                .frame(width: style.width, height: style.height)
                .clipShape(RoundedRectangle(cornerRadius: style.cornerRadius))
                .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 3)

            // Title and info (only for poster style)
            if style == .poster {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.displayTitle)
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 4) {
                        if let year = item.year {
                            Text(year)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if item.voteAverage > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "star.fill")
                                    .font(.caption2)
                                    .foregroundStyle(Color.imdbYellow)
                                Text(item.formattedRating)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .frame(width: style.width, alignment: .leading)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Double tap to view details")
    }

    // MARK: - Subviews

    @ViewBuilder
    private var imageView: some View {
        let imageURL = style == .backdrop ? item.backdropURL : item.posterURL

        AsyncImage(url: imageURL) { phase in
            switch phase {
            case .empty:
                placeholder
                    .shimmering()

            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)

            case .failure:
                placeholder
                    .overlay {
                        VStack(spacing: 4) {
                            Image(systemName: item.isTVSeries ? "tv" : "film")
                                .font(.title2)
                            Text(item.displayTitle)
                                .font(.caption2)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 4)
                        }
                        .foregroundStyle(.secondary)
                    }

            @unknown default:
                placeholder
            }
        }
    }

    private var placeholder: some View {
        Rectangle()
            .fill(Color.plotlineCard)
    }

    // MARK: - Accessibility

    private var accessibilityLabel: String {
        var label = item.displayTitle

        if let year = item.year {
            label += ", \(year)"
        }

        if item.voteAverage > 0 {
            label += ", rated \(item.formattedRating) out of 10"
        }

        if item.isTVSeries {
            label += ", TV series"
        } else {
            label += ", movie"
        }

        return label
    }
}

// MARK: - Preview

#Preview("Poster Style") {
    HStack(spacing: 16) {
        MediaCard(item: .preview, style: .poster)
        MediaCard(item: .moviePreview, style: .poster)
    }
    .padding()
    .background(Color.plotlineBackground)
}

#Preview("Backdrop Style") {
    VStack(spacing: 16) {
        MediaCard(item: .preview, style: .backdrop)
        MediaCard(item: .moviePreview, style: .backdrop)
    }
    .padding()
    .background(Color.plotlineBackground)
}

#Preview("Compact Style") {
    HStack(spacing: 12) {
        MediaCard(item: .preview, style: .compact)
        MediaCard(item: .moviePreview, style: .compact)
    }
    .padding()
    .background(Color.plotlineBackground)
}
