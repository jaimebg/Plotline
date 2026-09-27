import SwiftUI

/// The pushed value for a favourite's detail screen.
///
/// Distinct from a bare `MediaItem` so `LibraryView` can tell a favourite's
/// detail apart from a watchlist or suggestion one: only a favourite's counts
/// towards the review prompt.
struct FavoriteDetailRoute: Hashable {
    let item: MediaItem
}

/// The Favorites half of the Library tab: saved titles with a type filter,
/// sorting and swipe-to-remove, or suggestions from the bundled dataset when
/// nothing is saved.
///
/// Carries no `NavigationStack` of its own; `LibraryView` provides it, along
/// with the state that has to survive switching segments.
struct FavoritesSegment: View {
    @Environment(\.favoritesManager) private var favoritesManager
    @Bindable var viewModel: FavoritesViewModel
    let namespace: Namespace.ID

    private var filteredFavorites: [FavoriteItem] {
        viewModel.filteredAndSorted(favoritesManager.favorites)
    }

    /// Spring animation for list reorganization
    private var reorderAnimation: Animation {
        .spring(response: 0.4, dampingFraction: 0.75, blendDuration: 0.1)
    }

    var body: some View {
        favoritesContent
            .toolbar {
                if !favoritesManager.favorites.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        sortMenu
                    }
                }
            }
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
                NavigationLink(value: FavoriteDetailRoute(item: favorite.toMediaItem())) {
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

    private var filteredEmptyStateView: some View {
        ContentUnavailableView(
            "No \(viewModel.filter.rawValue)",
            systemImage: viewModel.filter == .movies ? "film" : "tv",
            description: Text("You haven't added any \(viewModel.filter.rawValue.lowercased()) to your favorites yet")
        )
    }
}
