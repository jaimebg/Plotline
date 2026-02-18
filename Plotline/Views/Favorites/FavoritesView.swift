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
                        .onAppear { handleFavoriteDetailOpened() }
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
                .foregroundStyle(Color.plotlinePrimary)
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
