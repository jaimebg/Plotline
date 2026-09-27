import SwiftUI

/// Horizontal scrolling section for media items
struct MediaSection: View {
    let title: String
    let subtitle: String?
    let items: [MediaItem]
    let style: MediaCard.CardStyle

    @Environment(\.navigationNamespace) private var namespace

    init(
        title: String,
        subtitle: String? = nil,
        items: [MediaItem],
        style: MediaCard.CardStyle = .poster
    ) {
        self.title = title
        self.subtitle = subtitle
        self.items = items
        self.style = style
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header. The subtitle explains the shelf, so it renders
            // above the shelf. It used to sit under the poster row, where the
            // explanation arrived after the thing being explained.
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(.title2, weight: .bold))
                    .foregroundStyle(.primary)

                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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
                            }
                            .if(namespace != nil) { view in
                                view.matchedTransitionSource(id: item.id, in: namespace!)
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
