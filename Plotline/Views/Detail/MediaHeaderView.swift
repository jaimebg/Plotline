import SwiftUI

/// Immersive header with backdrop image for media detail
struct MediaHeaderView: View {
    let media: MediaItem
    let height: CGFloat

    @Environment(\.dismiss) private var dismiss

    init(media: MediaItem, height: CGFloat = 300) {
        self.media = media
        self.height = height
    }

    var body: some View {
        GeometryReader { geometry in
            let minY = geometry.frame(in: .global).minY
            let isScrolledUp = minY < 0

            ZStack(alignment: .bottomLeading) {
                // Backdrop image
                backdropImage
                    .frame(
                        width: geometry.size.width,
                        height: isScrolledUp ? height : height + minY
                    )
                    .offset(y: isScrolledUp ? 0 : -minY)

                // Gradient overlay
                LinearGradient(
                    colors: [
                        .clear,
                        .clear,
                        Color.plotlineBackground.opacity(0.5),
                        Color.plotlineBackground
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Title and metadata overlay
                titleOverlay
                    .padding(.horizontal)
                    .padding(.bottom, 16)
            }
        }
        .frame(height: height)
    }

    // MARK: - Backdrop Image

    @ViewBuilder
    private var backdropImage: some View {
        AsyncImage(url: media.backdropURL) { phase in
            switch phase {
            case .empty:
                Rectangle()
                    .fill(Color.plotlineCard)
                    .overlay {
                        ProgressView()
                            .tint(.primary.opacity(0.5))
                    }

            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)

            case .failure:
                fallbackView

            @unknown default:
                Rectangle().fill(Color.plotlineCard)
            }
        }
    }

    // MARK: - Fallback View (no backdrop)

    private var fallbackView: some View {
        ZStack {
            // Use poster as fallback with blur
            if let posterURL = media.posterURL {
                AsyncImage(url: posterURL) { phase in
                    if case .success(let image) = phase {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .blur(radius: 20)
                            .overlay(Color.black.opacity(0.3))
                    } else {
                        Color.plotlineCard
                    }
                }
            } else {
                Color.plotlineCard
            }

            // Icon
            Image(systemName: media.isTVSeries ? "tv" : "film")
                .font(.system(size: 60))
                .foregroundStyle(.primary.opacity(0.3))
        }
    }

    // MARK: - Title Overlay

    private var titleOverlay: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Media type badge
            Text(media.isTVSeries ? "TV SERIES" : "MOVIE")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Color.plotlineGold)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.plotlineCard.opacity(0.8))
                .clipShape(Capsule())

            // Title
            Text(media.displayTitle)
                .font(.system(.title, weight: .bold))
                .foregroundStyle(.primary)
                .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)

            // Metadata row
            HStack(spacing: 12) {
                if let year = media.year {
                    Label(year, systemImage: "calendar")
                        .font(.subheadline)
                        .foregroundStyle(.primary.opacity(0.9))
                }

                if media.voteAverage > 0 {
                    Label(media.formattedRating, systemImage: "star.fill")
                        .font(.subheadline)
                        .foregroundStyle(Color.imdbYellow)
                }

                if let totalSeasons = media.totalSeasons, media.isTVSeries {
                    Label("\(totalSeasons) Seasons", systemImage: "film.stack")
                        .font(.subheadline)
                        .foregroundStyle(.primary.opacity(0.9))
                }
            }
            .labelStyle(.titleAndIcon)
        }
    }
}

// MARK: - Parallax Header (Alternative)

struct ParallaxHeaderView: View {
    let media: MediaItem
    let height: CGFloat
    let minHeight: CGFloat

    init(media: MediaItem, height: CGFloat = 350, minHeight: CGFloat = 100) {
        self.media = media
        self.height = height
        self.minHeight = minHeight
    }

    var body: some View {
        GeometryReader { geometry in
            let minY = geometry.frame(in: .global).minY
            let progress = min(max(-minY / (height - minHeight), 0), 1)

            ZStack(alignment: .bottom) {
                // Backdrop with parallax
                AsyncImage(url: media.backdropURL) { phase in
                    if case .success(let image) = phase {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .scaleEffect(1 + max(minY, 0) / 500)
                    } else {
                        Color.plotlineCard
                    }
                }
                .frame(height: height + max(minY, 0))
                .offset(y: -max(minY, 0))

                // Gradient
                LinearGradient.fadeToBlack
                    .frame(height: height * 0.6)

                // Content
                VStack(alignment: .leading, spacing: 8) {
                    Text(media.displayTitle)
                        .font(.system(size: 28 - (progress * 8), weight: .bold))
                        .foregroundStyle(.primary)

                    if progress < 0.5 {
                        metadataRow
                            .opacity(Double(1 - (progress * 2)))
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: max(height - minY, minHeight))
            .offset(y: minY > 0 ? 0 : minY)
        }
        .frame(height: height)
    }

    private var metadataRow: some View {
        HStack(spacing: 12) {
            if let year = media.year {
                Text(year)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if media.voteAverage > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(Color.imdbYellow)
                    Text(media.formattedRating)
                        .foregroundStyle(.primary)
                }
                .font(.subheadline)
            }
        }
    }
}

// MARK: - Preview

#Preview("Media Header - Series") {
    ScrollView {
        VStack(spacing: 0) {
            MediaHeaderView(media: .preview)
            Color.plotlineBackground.frame(height: 500)
        }
    }
    .ignoresSafeArea()
    .preferredColorScheme(.dark)
}

#Preview("Media Header - Movie") {
    ScrollView {
        VStack(spacing: 0) {
            MediaHeaderView(media: .moviePreview)
            Color.plotlineBackground.frame(height: 500)
        }
    }
    .ignoresSafeArea()
    .preferredColorScheme(.dark)
}
