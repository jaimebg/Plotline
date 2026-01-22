import SwiftData
import SwiftUI

/// Main view for displaying and managing favorited movies and series
struct FavoritesView: View {
    @Environment(\.themeManager) private var themeManager
    @Environment(\.favoritesManager) private var favoritesManager
    @State private var viewModel = FavoritesViewModel()
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
            content
                .background(Color.plotlineBackground)
                .navigationTitle("Favorites")
                .navigationBarTitleDisplayMode(.large)
                .navigationDestination(for: MediaItem.self) { item in
                    MediaDetailView(media: item)
                        .navigationTransition(.zoom(sourceID: item.id, in: namespace))
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        sortMenu
                    }
                }
        }
        .environment(\.navigationNamespace, namespace)
        .preferredColorScheme(themeManager.colorScheme)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
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

    // MARK: - Filter Picker

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

    // MARK: - Sort Menu

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
                .font(.system(size: 17))
                .foregroundStyle(Color.plotlinePrimary)
        }
    }

    // MARK: - Favorites List

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

    // MARK: - Empty State View

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
                        .font(.system(size: 44))
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

    // MARK: - Filtered Empty State View

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
