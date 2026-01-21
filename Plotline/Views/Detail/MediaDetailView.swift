import SwiftUI

/// Detail view for movies and TV series
struct MediaDetailView: View {
    @Environment(\.themeManager) private var themeManager
    @State private var viewModel: MediaDetailViewModel
    @State private var scrollOffset: CGFloat = 0
    @State private var titleVisible: Bool = false

    private let headerHeight: CGFloat = 280
    private let titleCollapseThreshold: CGFloat = 180

    init(media: MediaItem) {
        _viewModel = State(initialValue: MediaDetailViewModel(media: media))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Immersive header (backdrop only)
                headerSection
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: ScrollOffsetKey.self,
                                value: geo.frame(in: .named("scroll")).minY
                            )
                        }
                    )

                // Content
                VStack(alignment: .leading, spacing: 24) {
                    // Title section (now in content, above ratings)
                    titleSection
                        .opacity(titleVisible ? 0 : 1)

                    // Ratings section
                    ScorecardsView(
                        ratings: viewModel.ratings,
                        isLoading: viewModel.isLoadingRatings,
                        error: viewModel.ratingsError
                    )

                    // Overview
                    overviewSection

                    // Series-specific content
                    if viewModel.isTVSeries {
                        // Episode ratings grid
                        if !viewModel.episodesBySeason.isEmpty {
                            EpisodeRatingsGridView(
                                episodesBySeason: viewModel.episodesBySeason,
                                totalSeasons: viewModel.totalSeasons
                            )
                        } else if viewModel.isLoadingAllSeasons {
                            episodeGridLoadingView
                        }
                    }
                }
                .padding()
                .padding(.top, -20) // Overlap with gradient for seamless transition
            }
        }
        .coordinateSpace(name: "scroll")
        .onPreferenceChange(ScrollOffsetKey.self) { value in
            scrollOffset = value
            withAnimation(.easeInOut(duration: 0.2)) {
                titleVisible = -value > titleCollapseThreshold
            }
        }
        .background(Color.plotlineBackground)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(titleVisible ? .visible : .hidden, for: .navigationBar)
        .toolbarBackground(Color.plotlineBackground, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(viewModel.media.displayTitle)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .opacity(titleVisible ? 1 : 0)
            }
        }
        .preferredColorScheme(themeManager.colorScheme)
        .task {
            await viewModel.loadDetails()
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        GeometryReader { geometry in
            let minY = geometry.frame(in: .global).minY
            let isScrolledUp = minY < 0

            ZStack(alignment: .bottom) {
                // Backdrop image
                backdropImage
                    .frame(
                        width: geometry.size.width,
                        height: isScrolledUp ? headerHeight : headerHeight + minY
                    )
                    .offset(y: isScrolledUp ? 0 : -minY)

                // Gradient overlay for smooth transition to content
                LinearGradient(
                    colors: [
                        .clear,
                        .clear,
                        Color.plotlineBackground.opacity(0.7),
                        Color.plotlineBackground
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .frame(height: headerHeight)
    }

    // MARK: - Title Section

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Media type badge
            Text(viewModel.media.isTVSeries ? "TV SERIES" : "MOVIE")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Color.plotlineGold)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.plotlineCard.opacity(0.8))
                .clipShape(Capsule())

            // Title
            Text(viewModel.media.displayTitle)
                .font(.system(.title, weight: .bold))
                .foregroundStyle(.primary)

            // Metadata row
            HStack(spacing: 12) {
                if let year = viewModel.media.year {
                    Label(year, systemImage: "calendar")
                        .font(.subheadline)
                        .foregroundStyle(.primary.opacity(0.9))
                }

                if viewModel.media.voteAverage > 0 {
                    Label(viewModel.media.formattedRating, systemImage: "star.fill")
                        .font(.subheadline)
                        .foregroundStyle(Color.imdbYellow)
                }

                if let totalSeasons = viewModel.media.totalSeasons, viewModel.media.isTVSeries {
                    Label("\(totalSeasons) Seasons", systemImage: "film.stack")
                        .font(.subheadline)
                        .foregroundStyle(.primary.opacity(0.9))
                }
            }
            .labelStyle(.titleAndIcon)
        }
    }

    // MARK: - Backdrop Image

    @ViewBuilder
    private var backdropImage: some View {
        AsyncImage(url: viewModel.media.backdropURL) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            case .failure:
                fallbackView
            case .empty, _:
                Rectangle()
                    .fill(Color.plotlineCard)
                    .shimmering()
            }
        }
    }

    // MARK: - Fallback View

    private var fallbackView: some View {
        ZStack {
            if let posterURL = viewModel.media.posterURL {
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

            Image(systemName: viewModel.media.isTVSeries ? "tv" : "film")
                .font(.system(size: 60))
                .foregroundStyle(.primary.opacity(0.3))
        }
    }

    // MARK: - Overview Section

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Overview")
                .font(.system(.headline, weight: .semibold))
                .foregroundStyle(.primary)

            Text(viewModel.media.overview)
                .font(.body)
                .foregroundStyle(.secondary)
                .lineSpacing(4)
        }
    }

    // MARK: - Episode Grid Loading

    private var episodeGridLoadingView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("IMDb Scores")
                .font(.system(.headline, weight: .semibold))
                .foregroundStyle(.primary)

            VStack(spacing: 6) {
                ForEach(0..<8, id: \.self) { _ in
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.plotlineCard)
                            .frame(width: 32, height: 36)
                        ForEach(0..<5, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.plotlineCard)
                                .frame(width: 58, height: 36)
                        }
                    }
                    .shimmering()
                }
            }
        }
    }
}

// MARK: - Scroll Offset Key

struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Preview

#Preview("TV Series Detail") {
    NavigationStack {
        MediaDetailView(media: .preview)
    }
}

#Preview("Movie Detail") {
    NavigationStack {
        MediaDetailView(media: .moviePreview)
    }
}
