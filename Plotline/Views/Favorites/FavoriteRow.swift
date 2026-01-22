import SwiftData
import SwiftUI

/// Compact list row for displaying a favorite item
struct FavoriteRow: View {
    let favorite: FavoriteItem

    private var posterURL: URL? {
        guard let path = favorite.posterPath, !path.isEmpty else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w342\(path)")
    }

    var body: some View {
        HStack(spacing: 12) {
            CachedAsyncImage(url: posterURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.plotlineCard)
                    .overlay {
                        if posterURL == nil {
                            Image(systemName: favorite.isTVSeries ? "tv" : "film")
                                .foregroundStyle(.secondary)
                        } else {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                    }
            }
            .frame(width: 60, height: 90)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(favorite.title)
                    .font(.system(.headline, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text(favorite.isTVSeries ? "TV Series" : "Movie")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.plotlineCard)
                    .clipShape(Capsule())
                    .foregroundStyle(.secondary)

                if favorite.voteAverage > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(Color.imdbYellow)
                        Text(String(format: "%.1f", favorite.voteAverage))
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color.plotlineCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 12) {
        FavoriteRow(favorite: FavoriteItem(
            tmdbId: 1396,
            mediaType: "tv",
            title: "Breaking Bad",
            posterPath: "/ggFHVNu6YYI5L9pCfOacjizRGt.jpg",
            backdropPath: "/tsRy63Mu5cu8etL1X7ZLyf7UFy8.jpg",
            voteAverage: 8.9
        ))
        FavoriteRow(favorite: FavoriteItem(
            tmdbId: 550,
            mediaType: "movie",
            title: "Fight Club",
            posterPath: "/pB8BM7pdSp6B6Ih7QZ4DrQ3PmJK.jpg",
            backdropPath: "/rr7E0NoGKxvbkb89eR1GwfoYjpA.jpg",
            voteAverage: 8.4
        ))
    }
    .padding()
    .background(Color.plotlineBackground)
}
