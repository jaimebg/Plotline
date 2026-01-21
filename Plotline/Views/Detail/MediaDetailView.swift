import SwiftUI

/// Detail view for movies and TV series
struct MediaDetailView: View {
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
                        seasonSection
                    }

                    // Additional info
                    additionalInfoSection
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
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .opacity(titleVisible ? 1 : 0)
            }
        }
        .preferredColorScheme(.dark)
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
                .foregroundStyle(.white)

            // Metadata row
            HStack(spacing: 12) {
                if let year = viewModel.media.year {
                    Label(year, systemImage: "calendar")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.9))
                }

                if viewModel.media.voteAverage > 0 {
                    Label(viewModel.media.formattedRating, systemImage: "star.fill")
                        .font(.subheadline)
                        .foregroundStyle(Color.imdbYellow)
                }

                if let totalSeasons = viewModel.media.totalSeasons, viewModel.media.isTVSeries {
                    Label("\(totalSeasons) Seasons", systemImage: "film.stack")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.9))
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
            case .empty:
                Rectangle()
                    .fill(Color.plotlineCard)
                    .overlay {
                        ProgressView()
                            .tint(.white.opacity(0.5))
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
                .foregroundStyle(.white.opacity(0.3))
        }
    }

    // MARK: - Overview Section

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Overview")
                .font(.system(.headline, weight: .semibold))
                .foregroundStyle(.white)

            Text(viewModel.media.overview)
                .font(.body)
                .foregroundStyle(.secondary)
                .lineSpacing(4)
        }
    }

    // MARK: - Season Section (TV Series)

    @ViewBuilder
    private var seasonSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header with season picker
            HStack {
                Text("Episodes")
                    .font(.system(.headline, weight: .semibold))
                    .foregroundStyle(.white)

                Spacer()

                // Season picker
                if viewModel.totalSeasons > 1 {
                    Menu {
                        ForEach(viewModel.seasonNumbers, id: \.self) { season in
                            Button("Season \(season)") {
                                Task {
                                    await viewModel.selectSeason(season)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text("Season \(viewModel.selectedSeason)")
                                .font(.subheadline)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                        }
                        .foregroundStyle(Color.plotlineGold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.plotlineCard)
                        .clipShape(Capsule())
                    }
                }
            }

            // Season stats
            if viewModel.hasEpisodes {
                seasonStatsView
            }

            // Episode list or loading/error state
            if viewModel.isLoadingEpisodes {
                episodeLoadingView
            } else if viewModel.episodesError != nil, !viewModel.hasEpisodes {
                episodeErrorView
            } else if viewModel.hasEpisodes {
                episodeListView
            } else {
                Text("No episode data available")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }

            // Episode ratings graph
            if viewModel.hasEpisodes {
                SeriesGraphView(
                    episodes: viewModel.episodes,
                    seasonNumber: viewModel.selectedSeason
                )
            }
        }
    }

    // MARK: - Season Stats

    private var seasonStatsView: some View {
        HStack(spacing: 16) {
            if let avg = viewModel.averageEpisodeRating {
                StatCard(
                    title: "Average",
                    value: String(format: "%.1f", avg),
                    icon: "chart.line.uptrend.xyaxis"
                )
            }

            if let highest = viewModel.highestRatedEpisode {
                StatCard(
                    title: "Highest",
                    value: highest.formattedRating,
                    subtitle: "E\(highest.episodeNumber)",
                    icon: "arrow.up"
                )
            }

            if let lowest = viewModel.lowestRatedEpisode {
                StatCard(
                    title: "Lowest",
                    value: lowest.formattedRating,
                    subtitle: "E\(lowest.episodeNumber)",
                    icon: "arrow.down"
                )
            }
        }
    }

    // MARK: - Episode List

    private var episodeListView: some View {
        VStack(spacing: 8) {
            ForEach(viewModel.episodes) { episode in
                EpisodeRow(episode: episode)
            }
        }
    }

    private var episodeLoadingView: some View {
        VStack(spacing: 8) {
            ForEach(0..<5, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.plotlineCard)
                    .frame(height: 60)
                    .shimmering()
            }
        }
    }

    private var episodeErrorView: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
            Text("Could not load episodes")
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.plotlineCard)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Additional Info

    private var additionalInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Information")
                .font(.system(.headline, weight: .semibold))
                .foregroundStyle(.white)

            VStack(spacing: 8) {
                if let imdbId = viewModel.media.imdbId {
                    InfoRow(label: "IMDb ID", value: imdbId)
                }

                InfoRow(label: "Type", value: viewModel.media.isTVSeries ? "TV Series" : "Movie")

                if viewModel.media.voteCount > 0 {
                    InfoRow(label: "Vote Count", value: "\(viewModel.media.voteCount.formatted())")
                }

                if viewModel.isTVSeries, viewModel.totalSeasons > 0 {
                    InfoRow(label: "Total Seasons", value: "\(viewModel.totalSeasons)")
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    var subtitle: String? = nil
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(Color.plotlineGold)

            Text(value)
                .font(.system(.title3, design: .monospaced, weight: .bold))
                .foregroundStyle(.white)

            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.plotlineCard)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        if let subtitle = subtitle {
            return "\(title): \(value), \(subtitle)"
        }
        return "\(title): \(value)"
    }
}

struct EpisodeRow: View {
    let episode: EpisodeMetric

    var body: some View {
        HStack(spacing: 12) {
            // Episode number
            Text("\(episode.episodeNumber)")
                .font(.system(.headline, design: .monospaced, weight: .bold))
                .foregroundStyle(Color.plotlineGold)
                .frame(width: 30)

            // Title
            VStack(alignment: .leading, spacing: 2) {
                Text(episode.title)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(episode.shortCode)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Rating
            if episode.hasValidRating {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(Color.imdbYellow)
                    Text(episode.formattedRating)
                        .font(.system(.subheadline, design: .monospaced, weight: .semibold))
                        .foregroundStyle(.white)
                }
            } else {
                Text("N/A")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.plotlineCard)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        var label = "Episode \(episode.episodeNumber): \(episode.title)"
        if episode.hasValidRating {
            label += ", rated \(episode.formattedRating) out of 10"
        } else {
            label += ", no rating available"
        }
        return label
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.plotlineCard)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
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
