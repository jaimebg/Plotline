import SwiftUI

/// "Your Plotline" daily pick card showing personalized recommendations
struct DailyPickView: View {
    @Environment(\.favoritesManager) private var favoritesManager
    @Environment(\.navigationNamespace) private var namespace
    @State private var viewModel = DailyPickViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack {
                Text("Today's Pick for You")
                    .font(.system(.title2, weight: .bold))
                    .foregroundStyle(.primary)

                Spacer()

                if viewModel.hasPick {
                    Button {
                        Task {
                            await viewModel.refreshPick(
                                favorites: favoritesManager.favorites,
                                favoriteIds: favoritesManager.favoriteIds
                            )
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)
                            .symbolEffect(.rotate, isActive: viewModel.isLoading)
                    }
                }
            }
            .padding(.horizontal)

            // Content
            if favoritesManager.favorites.isEmpty {
                emptyFavoritesView
            } else if viewModel.isLoading {
                loadingView
            } else if let recommendation = viewModel.recommendation,
                      let basedOn = viewModel.basedOnFavorite {
                NavigationLink(value: recommendation) {
                    DailyPickCard(
                        recommendation: recommendation,
                        basedOnTitle: basedOn.title
                    )
                    .if(namespace != nil) { view in
                        view.matchedTransitionSource(id: recommendation.id, in: namespace!)
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
            } else {
                errorView
            }
        }
        .task {
            await viewModel.loadDailyPick(
                favorites: favoritesManager.favorites,
                favoriteIds: favoritesManager.favoriteIds
            )
        }
        .onChange(of: favoritesManager.favorites.count) { oldValue, newValue in
            if oldValue == 0 && newValue > 0 {
                Task {
                    await viewModel.loadDailyPick(
                        favorites: favoritesManager.favorites,
                        favoriteIds: favoritesManager.favoriteIds
                    )
                }
            }
        }
    }

    // MARK: - Empty Favorites View

    private var emptyFavoritesView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.plotlinePrimary.opacity(0.15),
                            Color.plotlineGold.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: 12) {
                Image(systemName: "heart.circle")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.plotlinePrimary)
                    .symbolEffect(.pulse.wholeSymbol, options: .repeating)

                Text("Add Your Favorites")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text("Tap the heart on any movie or series to get personalized recommendations")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .padding(.vertical, 32)
        }
        .frame(height: 200)
        .padding(.horizontal)
    }

    // MARK: - Loading View

    private var loadingView: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color.plotlineCard)
            .frame(height: 200)
            .shimmering()
            .padding(.horizontal)
    }

    // MARK: - Error View

    private var errorView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.plotlineCard)

            VStack(spacing: 8) {
                Image(systemName: "film.stack")
                    .font(.system(size: 32))
                    .foregroundStyle(.secondary)

                Text("No recommendations available")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button("Try Again") {
                    Task {
                        await viewModel.refreshPick(
                            favorites: favoritesManager.favorites,
                            favoriteIds: favoritesManager.favoriteIds
                        )
                    }
                }
                .font(.subheadline)
                .foregroundStyle(Color.plotlinePrimary)
            }
        }
        .frame(height: 180)
        .padding(.horizontal)
    }
}

// MARK: - Daily Pick Card

struct DailyPickCard: View {
    let recommendation: MediaItem
    let basedOnTitle: String

    @State private var imageLoaded = false

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Backdrop image
            AsyncImage(url: recommendation.backdropURL) { phase in
                switch phase {
                case .empty:
                    Rectangle()
                        .fill(Color.plotlineCard)
                        .shimmering()
                        .onAppear { imageLoaded = false }

                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .onAppear { imageLoaded = true }

                case .failure:
                    fallbackImage
                        .onAppear { imageLoaded = true }

                @unknown default:
                    Rectangle().fill(Color.plotlineCard)
                }
            }

            if imageLoaded {
                // Gradient overlay
                LinearGradient(
                    colors: [
                        .clear,
                        .black.opacity(0.3),
                        .black.opacity(0.85)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Content overlay
                VStack(alignment: .leading, spacing: 8) {
                    // "Because you liked" badge
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .font(.caption2)
                        Text("Because you liked **\(basedOnTitle)**")
                            .font(.caption)
                    }
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial.opacity(0.8))
                    .clipShape(Capsule())

                    Spacer()

                    // Title and metadata
                    VStack(alignment: .leading, spacing: 6) {
                        Text(recommendation.displayTitle)
                            .font(.system(.title3, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(2)

                        HStack(spacing: 12) {
                            if let year = recommendation.year {
                                Text(year)
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.8))
                            }

                            if recommendation.voteAverage > 0 {
                                HStack(spacing: 4) {
                                    Image(systemName: "star.fill")
                                        .font(.caption)
                                        .foregroundStyle(Color.imdbYellow)
                                    Text(recommendation.formattedRating)
                                        .font(.subheadline)
                                        .foregroundStyle(.white)
                                }
                            }

                            Text(recommendation.isTVSeries ? "Series" : "Movie")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.7))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(.white.opacity(0.2))
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(16)
            }
        }
        .frame(height: 200)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 6)
    }

    private var fallbackImage: some View {
        ZStack {
            if let posterURL = recommendation.posterURL {
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

            Image(systemName: recommendation.isTVSeries ? "tv" : "film")
                .font(.system(size: 40))
                .foregroundStyle(.white.opacity(0.3))
        }
    }
}

// MARK: - Preview

#Preview("With Pick") {
    NavigationStack {
        ScrollView {
            DailyPickView()
                .padding(.vertical)
        }
        .background(Color.plotlineBackground)
    }
}
