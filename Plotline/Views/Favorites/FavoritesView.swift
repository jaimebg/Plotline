import StoreKit
import SwiftData
import SwiftUI

/// Active list selection for the tab
enum ActiveList: String, CaseIterable {
    case favorites = "Favorites"
    case watchlist = "Watchlist"
}

/// Main view for displaying and managing favorited movies and series
struct FavoritesView: View {
    @Environment(\.themeManager) private var themeManager
    @Environment(\.favoritesManager) private var favoritesManager
    @Environment(\.watchlistManager) private var watchlistManager
    @Environment(\.requestReview) private var requestReview
    @State private var viewModel = FavoritesViewModel()
    @State private var activeList: ActiveList = .favorites
    @State private var watchlistSort: FavoriteSort = .dateAdded
    @State private var navigationPath = NavigationPath()
    @Namespace private var namespace
    @Namespace private var listAnimation

    private var filteredFavorites: [FavoriteItem] {
        viewModel.filteredAndSorted(favoritesManager.favorites)
    }

    /// Spring animation for list reorganization
    private var reorderAnimation: Animation {
        .spring(response: 0.4, dampingFraction: 0.75, blendDuration: 0.1)
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                // Top-level list switcher
                listSwitcher
                    .padding(.horizontal)
                    .padding(.top, 8)

                if activeList == .favorites {
                    favoritesContent
                } else {
                    WatchlistView(sort: $watchlistSort)
                }
            }
            .background(Color.plotlineBackground)
            .navigationTitle(activeList.rawValue)
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: MediaItem.self) { item in
                MediaDetailView(media: item)
                    .navigationTransition(.zoom(sourceID: item.id, in: namespace))
                    .onAppear { handleFavoriteDetailOpened() }
            }
            .toolbar {
                if activeList == .favorites && !favoritesManager.favorites.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        sortMenu
                    }
                }
                if activeList == .watchlist && !watchlistManager.watchlistItems.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        watchlistSortMenu
                    }
                }
            }
        }
        .environment(\.navigationNamespace, namespace)
        .preferredColorScheme(themeManager.colorScheme)
    }

    private var listSwitcher: some View {
        Picker("List", selection: $activeList) {
            ForEach(ActiveList.allCases, id: \.self) { list in
                Text(list.rawValue).tag(list)
            }
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private var favoritesContent: some View {
        if favoritesManager.favorites.isEmpty {
            emptyStateView
        } else {
            VStack(spacing: 0) {
                filterPicker
                    .padding(.horizontal)
                    .padding(.top, 8)

                if filteredFavorites.isEmpty {
                    filteredEmptyStateView
                } else {
                    favoritesList
                }
            }
        }
    }

    private var filterPicker: some View {
        Picker("Filter", selection: Binding(
            get: { viewModel.filter },
            set: { newFilter in
                withAnimation(reorderAnimation) {
                    viewModel.filter = newFilter
                }
            }
        )) {
            ForEach(FavoriteFilter.allCases, id: \.self) { filter in
                Text(filter.rawValue).tag(filter)
            }
        }
        .pickerStyle(.segmented)
    }

    private var sortMenu: some View {
        Menu {
            ForEach(FavoriteSort.allCases, id: \.self) { sort in
                Button {
                    withAnimation(reorderAnimation) {
                        viewModel.sort = sort
                    }
                } label: {
                    Label(sort.rawValue, systemImage: sort.icon)
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .font(.body)
                .foregroundStyle(Color.plotlinePrimary)
        }
    }

    private var watchlistSortMenu: some View {
        Menu {
            ForEach(FavoriteSort.allCases, id: \.self) { sort in
                Button {
                    withAnimation(reorderAnimation) {
                        watchlistSort = sort
                    }
                } label: {
                    Label(sort.rawValue, systemImage: sort.icon)
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .font(.body)
                .foregroundStyle(Color.plotlinePrimary)
        }
    }

    private var favoritesList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredFavorites, id: \.tmdbId) { favorite in
                    NavigationLink(value: favorite.toMediaItem()) {
                        FavoriteRow(favorite: favorite)
                            .matchedGeometryEffect(id: favorite.tmdbId, in: listAnimation)
                            .matchedTransitionSource(id: favorite.tmdbId, in: namespace)
                    }
                    .buttonStyle(.plain)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.9).combined(with: .opacity),
                        removal: .scale(scale: 0.9).combined(with: .opacity)
                    ))
                }
            }
            .padding()
        }
        .scrollIndicators(.hidden)
    }

    private var emptyStateView: some View {
        VStack {
            Spacer()
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
                        .font(.system(.largeTitle, weight: .regular))
                        .imageScale(.large)
                        .foregroundStyle(Color.plotlinePrimary)
                        .symbolEffect(.pulse.wholeSymbol, options: .repeating)

                    Text("No Favorites Yet")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text("Tap the heart on any movie or series to add it to your favorites")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .padding(.vertical, 32)
            }
            .frame(height: 200)
            .padding(.horizontal)
            Spacer()
        }
    }

    private func handleFavoriteDetailOpened() {
        ReviewManager.recordFavoriteDetailOpened()
        if ReviewManager.shouldRequestReview() {
            ReviewManager.markReviewRequested()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                requestReview()
            }
        }
    }

    private var filteredEmptyStateView: some View {
        ContentUnavailableView(
            "No \(viewModel.filter.rawValue)",
            systemImage: viewModel.filter == .movies ? "film" : "tv",
            description: Text("You haven't added any \(viewModel.filter.rawValue.lowercased()) to your favorites yet")
        )
    }
}

// MARK: - Preview

#Preview {
    FavoritesView()
}
