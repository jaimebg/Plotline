import SwiftUI

// MARK: - Skeleton Card

/// Skeleton placeholder for media cards
struct SkeletonCard: View {
    let style: MediaCard.CardStyle

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Image skeleton
            RoundedRectangle(cornerRadius: style.cornerRadius)
                .fill(Color.plotlineCard)
                .frame(width: style.width, height: style.height)
                .shimmering()

            // Title skeleton (only for poster style)
            if style == .poster {
                VStack(alignment: .leading, spacing: 6) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.plotlineCard)
                        .frame(width: style.width * 0.9, height: 14)
                        .shimmering()

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.plotlineCard)
                        .frame(width: style.width * 0.6, height: 12)
                        .shimmering()
                }
            }
        }
    }
}

// MARK: - Skeleton Featured Card

/// Skeleton placeholder for featured/hero cards
struct SkeletonFeaturedCard: View {
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Image skeleton
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.plotlineCard)
                .frame(width: 320, height: 180)
                .shimmering()

            // Title overlay skeleton
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.plotlineCardSecondary)
                    .frame(width: 180, height: 16)

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.plotlineCardSecondary)
                    .frame(width: 120, height: 12)
            }
            .padding(12)
        }
        .frame(width: 320, height: 180)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Skeleton Section

/// Skeleton placeholder for a media section with title and horizontal scroll
struct SkeletonSection: View {
    let style: MediaCard.CardStyle
    let itemCount: Int

    init(style: MediaCard.CardStyle = .poster, itemCount: Int = 5) {
        self.style = style
        self.itemCount = itemCount
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section title skeleton
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.plotlineCard)
                .frame(width: 160, height: 22)
                .shimmering()
                .padding(.horizontal)

            // Horizontal scroll of skeleton cards
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(0..<itemCount, id: \.self) { _ in
                        SkeletonCard(style: style)
                    }
                }
                .padding(.horizontal)
            }
            .disabled(true)
        }
    }
}

// MARK: - Skeleton Featured Section

/// Skeleton placeholder for featured section with large cards
struct SkeletonFeaturedSection: View {
    let itemCount: Int

    init(itemCount: Int = 3) {
        self.itemCount = itemCount
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section title skeleton
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.plotlineCard)
                .frame(width: 140, height: 22)
                .shimmering()
                .padding(.horizontal)

            // Horizontal scroll of skeleton featured cards
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(0..<itemCount, id: \.self) { _ in
                        SkeletonFeaturedCard()
                    }
                }
                .padding(.horizontal)
            }
            .disabled(true)
        }
    }
}

// MARK: - Discovery Skeleton View

/// Full skeleton view matching DiscoveryView layout
struct DiscoverySkeletonView: View {
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 28) {
                // Featured section skeleton
                SkeletonFeaturedSection(itemCount: 3)

                // Trending Movies skeleton
                SkeletonSection(style: .poster, itemCount: 5)

                // Trending Series skeleton
                SkeletonSection(style: .poster, itemCount: 5)

                // Top Rated Movies skeleton
                SkeletonSection(style: .poster, itemCount: 5)
            }
            .padding(.vertical)
        }
        .scrollIndicators(.hidden)
        .disabled(true)
    }
}

// MARK: - Search Result Skeleton Row

/// Skeleton placeholder for search result rows
struct SkeletonSearchResultRow: View {
    var body: some View {
        HStack(spacing: 12) {
            // Poster thumbnail skeleton
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.plotlineCard)
                .frame(width: 60, height: 90)
                .shimmering()

            // Info skeleton
            VStack(alignment: .leading, spacing: 8) {
                // Title
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.plotlineCard)
                    .frame(width: 180, height: 16)
                    .shimmering()

                // Year and type
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.plotlineCard)
                        .frame(width: 50, height: 14)
                        .shimmering()

                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.plotlineCard)
                        .frame(width: 60, height: 20)
                        .shimmering()
                }

                // Rating
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.plotlineCard)
                    .frame(width: 60, height: 14)
                    .shimmering()
            }

            Spacer()
        }
        .padding()
        .background(Color.plotlineCard.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Search Results Skeleton View

/// Skeleton view for search results
struct SearchResultsSkeletonView: View {
    let rowCount: Int

    init(rowCount: Int = 6) {
        self.rowCount = rowCount
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(0..<rowCount, id: \.self) { _ in
                    SkeletonSearchResultRow()
                }
            }
            .padding()
        }
        .disabled(true)
    }
}

// MARK: - Color Extension

extension Color {
    /// Secondary card color for nested skeleton elements
    static let plotlineCardSecondary = Color(white: 0.15)
}

// MARK: - Previews

#Preview("Skeleton Card") {
    HStack(spacing: 16) {
        SkeletonCard(style: .poster)
        SkeletonCard(style: .backdrop)
        SkeletonCard(style: .compact)
    }
    .padding()
    .background(Color.plotlineBackground)
}

#Preview("Skeleton Featured Card") {
    SkeletonFeaturedCard()
        .padding()
        .background(Color.plotlineBackground)
}

#Preview("Skeleton Section") {
    VStack(spacing: 24) {
        SkeletonSection(style: .poster)
        SkeletonSection(style: .backdrop)
    }
    .padding(.vertical)
    .background(Color.plotlineBackground)
}

#Preview("Discovery Skeleton") {
    DiscoverySkeletonView()
        .background(Color.plotlineBackground)
        .preferredColorScheme(.dark)
}

#Preview("Search Skeleton") {
    SearchResultsSkeletonView()
        .background(Color.plotlineBackground)
        .preferredColorScheme(.dark)
}
