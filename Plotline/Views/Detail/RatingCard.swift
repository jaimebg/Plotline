import SwiftUI

// MARK: - TMDB Rating Card

/// Rating card for TMDB user scores
struct TMDBRatingCard: View {
    @Environment(\.openURL) private var openURL

    let score: Double
    let mediaId: Int
    let isTVSeries: Bool

    private var formattedScore: String {
        String(format: "%.1f", score)
    }

    private var tmdbURL: URL? {
        let mediaType = isTVSeries ? "tv" : "movie"
        return URL(string: "https://www.themoviedb.org/\(mediaType)/\(mediaId)")
    }

    var body: some View {
        VStack(spacing: 6) {
            // TMDB icon
            Image(systemName: "person.3.fill")
                .font(.title3)
                .foregroundStyle(Color.plotlineSecondaryAccent)

            // Value
            Text(formattedScore)
                .font(.system(.subheadline, design: .monospaced, weight: .bold))
                .foregroundStyle(.primary)

            // Source label
            Text("TMDB")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 70)
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Color.plotlineCard)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .contentShape(Rectangle())
        .onTapGesture {
            if let url = tmdbURL {
                openURL(url)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("TMDB user rating: \(formattedScore) out of 10")
    }
}

// MARK: - Preview

#Preview("TMDB Rating Card") {
    HStack(spacing: 12) {
        TMDBRatingCard(score: 8.4, mediaId: 1396, isTVSeries: true)
        TMDBRatingCard(score: 7.2, mediaId: 550, isTVSeries: false)
    }
    .padding()
    .background(Color.plotlineBackground)
}
