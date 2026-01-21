import SwiftUI

/// Horizontal scrolling section for media items
struct MediaSection: View {
    let title: String
    let items: [MediaItem]
    let style: MediaCard.CardStyle

    @Environment(\.navigationNamespace) private var namespace

    init(title: String, items: [MediaItem], style: MediaCard.CardStyle = .poster) {
        self.title = title
        self.items = items
        self.style = style
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack {
                Text(title)
                    .font(.system(.title2, weight: .bold))
                    .foregroundStyle(.white)

                Spacer()

                // Optional "See All" button (for future use)
                // Button("See All") { }
                //     .font(.subheadline)
                //     .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            // Horizontal scroll
            if items.isEmpty {
                placeholderView
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 16) {
                        ForEach(items) { item in
                            NavigationLink(value: item) {
                                MediaCard(item: item, style: style)
                                    .if(namespace != nil) { view in
                                        view.matchedTransitionSource(id: item.id, in: namespace!)
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(title) section")
    }

    // MARK: - Placeholder

    @ViewBuilder
    private var placeholderView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 16) {
                ForEach(0..<5, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: style.cornerRadius)
                        .fill(Color.plotlineCard)
                        .frame(width: style.width, height: style.height)
                        .shimmering()
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Featured Section (Large Backdrop Style)

struct FeaturedSection: View {
    let title: String
    let items: [MediaItem]

    @Environment(\.navigationNamespace) private var namespace

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(.title2, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(items) { item in
                        NavigationLink(value: item) {
                            FeaturedCard(item: item)
                                .if(namespace != nil) { view in
                                    view.matchedTransitionSource(id: item.id, in: namespace!)
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

/// Large featured card for hero sections
struct FeaturedCard: View {
    let item: MediaItem

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Backdrop image
            AsyncImage(url: item.backdropURL) { phase in
                switch phase {
                case .empty:
                    Rectangle()
                        .fill(Color.plotlineCard)
                        .overlay { ProgressView().tint(.white.opacity(0.5)) }

                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)

                case .failure:
                    Rectangle()
                        .fill(Color.plotlineCard)
                        .overlay {
                            Image(systemName: "film")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                        }

                @unknown default:
                    Rectangle().fill(Color.plotlineCard)
                }
            }
            .frame(width: 320, height: 180)

            // Gradient overlay
            LinearGradient.fadeToBlack
                .frame(height: 100)

            // Title and info
            VStack(alignment: .leading, spacing: 4) {
                Text(item.displayTitle)
                    .font(.system(.headline, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                HStack(spacing: 8) {
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
                                .foregroundStyle(.white)
                        }
                    }

                    Text(item.isTVSeries ? "Series" : "Movie")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
        }
        .frame(width: 320, height: 180)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Preview

#Preview("Media Section") {
    NavigationStack {
        ScrollView {
            VStack(spacing: 24) {
                MediaSection(
                    title: "Trending Movies",
                    items: [.moviePreview, .moviePreview, .moviePreview]
                )

                MediaSection(
                    title: "Popular Series",
                    items: [.preview, .preview, .preview]
                )
            }
            .padding(.vertical)
        }
        .background(Color.plotlineBackground)
    }
    .preferredColorScheme(.dark)
}

#Preview("Featured Section") {
    NavigationStack {
        FeaturedSection(
            title: "Featured",
            items: [.preview, .moviePreview, .preview]
        )
        .padding(.vertical)
        .background(Color.plotlineBackground)
    }
    .preferredColorScheme(.dark)
}
