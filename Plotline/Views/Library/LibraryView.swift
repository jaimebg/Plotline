import StoreKit
import SwiftUI

/// The two halves of the Library tab.
///
/// The raw value is what `@AppStorage` persists, so renaming a case forgets
/// every viewer's last choice — change the title instead.
enum LibrarySegment: String, CaseIterable, Identifiable {
    case watchlist
    case favorites

    var id: Self { self }

    var title: String {
        switch self {
        case .watchlist: "Watchlist"
        case .favorites: "Favorites"
        }
    }
}

/// Watchlist and Favorites in one tab, switched by a segmented control that
/// remembers the viewer's last choice.
///
/// Owns the navigation stack and every piece of state that has to outlive a
/// segment switch — each segment's filter and sort, and which favourites
/// already counted towards the review prompt — so switching back and forth
/// loses nothing, as it lost nothing when they were separate tabs.
struct LibraryView: View {
    static let segmentStorageKey = "library.segment"

    @Environment(\.themeManager) private var themeManager
    @Environment(\.deepLinkManager) private var deepLinkManager
    @Environment(\.requestReview) private var requestReview
    @AppStorage(LibraryView.segmentStorageKey) private var segment: LibrarySegment = .watchlist
    @State private var favoritesViewModel = FavoritesViewModel()
    @State private var watchlistFilter: WatchlistFilter = .all
    @State private var watchlistSort: FavoriteSort = .dateAdded
    @State private var navigationPath = NavigationPath()
    /// Favourites whose detail already counted towards the review prompt this
    /// session. See `handleFavoriteDetailOpened(_:)`.
    @State private var countedDetailOpens: Set<String> = []
    @Namespace private var namespace

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                segmentPicker
                    .padding(.horizontal)
                    .padding(.top, 8)

                switch segment {
                case .watchlist:
                    WatchlistSegment(filter: $watchlistFilter, sort: $watchlistSort, namespace: namespace)
                case .favorites:
                    FavoritesSegment(viewModel: favoritesViewModel, namespace: namespace)
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .background(Color.plotlineBackground)
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: MediaItem.self) { item in
                MediaDetailView(media: item)
                    .navigationTransition(.zoom(sourceID: item.id, in: namespace))
            }
            .navigationDestination(for: FavoriteDetailRoute.self) { route in
                MediaDetailView(media: route.item)
                    .navigationTransition(.zoom(sourceID: route.item.id, in: namespace))
                    .onAppear { handleFavoriteDetailOpened(route.item) }
            }
        }
        .environment(\.navigationNamespace, namespace)
        .preferredColorScheme(themeManager.colorScheme)
        // Both, as with `MainTabView`'s tab: a segment requested before this
        // view exists produces no change for `onChange` to see.
        .onAppear { consumePendingSegment() }
        .onChange(of: deepLinkManager.pendingLibrarySegment) { _, _ in
            consumePendingSegment()
        }
    }

    private var segmentPicker: some View {
        Picker("Library section", selection: $segment) {
            ForEach(LibrarySegment.allCases) { segment in
                Text(segment.title).tag(segment)
            }
        }
        .pickerStyle(.segmented)
        .readableWidth(420)
    }

    private func consumePendingSegment() {
        guard let pending = deepLinkManager.pendingLibrarySegment else { return }
        deepLinkManager.pendingLibrarySegment = nil
        // A deep link lands on the root of the segment it names, not on
        // whatever detail screen was last left open in the tab.
        navigationPath = NavigationPath()
        segment = pending
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
}

// MARK: - Preview

#Preview {
    LibraryView()
}
