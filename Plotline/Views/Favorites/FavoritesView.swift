import StoreKit
import SwiftData
import SwiftUI

/// Main view for displaying and managing favorited movies and series
struct FavoritesView: View {
    @Environment(\.themeManager) private var themeManager
    @Environment(\.favoritesManager) private var favoritesManager
    @Environment(\.requestReview) private var requestReview
    @State private var viewModel = FavoritesViewModel()
    @State private var navigationPath = NavigationPath()
    /// Favourites whose detail already counted towards the review prompt this
    /// session. See `handleFavoriteDetailOpened(_:)`.
    @State private var countedDetailOpens: Set<String> = []
    @Namespace private var namespace

    private var filteredFavorites: [FavoriteItem] {
        viewModel.filteredAndSorted(favoritesManager.favorites)
    }

    /// Spring animation for list reorganization
    private var reorderAnimation: Animation {
        .spring(response: 0.4, dampingFraction: 0.75, blendDuration: 0.1)
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            favoritesContent
                .background(Color.plotlineBackground)
                .navigationTitle("Favorites")
                .navigationBarTitleDisplayMode(.large)
                .navigationDestination(for: MediaItem.self) { item in
                    MediaDetailView(media: item)
                        .navigationTransition(.zoom(sourceID: item.id, in: namespace))
                        .onAppear { handleFavoriteDetailOpened(item) }
                }
                .toolbar {
                    if !favoritesManager.favorites.isEmpty {
                        ToolbarItem(placement: .topBarTrailing) {
                            sortMenu
                        }
                    }
                }
        }
        .environment(\.navigationNamespace, namespace)
        .preferredColorScheme(themeManager.colorScheme)
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
                .foregroundStyle(Color.plotlineAccent)
                .accessibilityLabel("Sort favorites")
        }
    }

    private var favoritesList: some View {
        List {
            ForEach(filteredFavorites, id: \.tmdbId) { favorite in
                NavigationLink(value: favorite.toMediaItem()) {
                    FavoriteRow(favorite: favorite)
                }
                .matchedTransitionSource(id: favorite.tmdbId, in: namespace)
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        withAnimation(reorderAnimation) {
                            favoritesManager.removeFavorite(tmdbId: favorite.tmdbId)
                        }
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            }
        }
        .listStyle(.plain)
        .scrollIndicators(.hidden)
    }

    private var emptyStateView: some View {
        SuggestionsEmptyState(
            title: "No Favorites Yet",
            message: "Tap the heart on anything you love and it lands here.",
            systemImage: "heart",
            shelfIdentifier: AccessibilityAnchors.favoritesSuggestions
        )
    }

    /// Counts a favourite's detail screen towards the review prompt once per
    /// title per session.
    ///
    /// `onAppear` also fires when the user pops back to the detail from a
    /// screen pushed on top of it (a cast member's career, a franchise entry),
    /// and each of those used to count as another visit.
    private func handleFavoriteDetailOpened(_ item: MediaItem) {
        let key = "\(item.isTVSeries ? "tv" : "movie"):\(item.id)"
        guard countedDetailOpens.insert(key).inserted else { return }

        ReviewManager.recordFavoriteDetailOpened()
        if ReviewManager.shouldRequestReview() {
            ReviewManager.markReviewRequested()
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(2))
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
