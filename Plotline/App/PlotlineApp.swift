import AppIntents
import SwiftData
import SwiftUI

@main
struct PlotlineApp: App {
    @State private var themeManager = ThemeManager.shared
    @State private var favoritesManager = FavoritesManager()
    @State private var watchlistManager = WatchlistManager()
    @State private var deepLinkManager: DeepLinkManager

    let sharedModelContainer: ModelContainer

    init() {
        let container = SharedModelContainer.make()
        let deepLinks = DeepLinkManager()
        sharedModelContainer = container
        _deepLinkManager = State(initialValue: deepLinks)

        // Registered here, not when the window appears: an App Intent run on a
        // cold launch can execute before any scene exists, and resolving an
        // unregistered `@Dependency` is fatal.
        AppDependencyManager.shared.add(dependency: container)
        AppDependencyManager.shared.add(dependency: deepLinks)

        // Expired cache files are otherwise only removed when their exact key is
        // read again. Runs on the caches' own actors, off the main thread.
        Task.detached(priority: .utility) {
            await TMDBService.pruneExpiredCaches()
        }
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(\.themeManager, themeManager)
                .environment(\.favoritesManager, favoritesManager)
                .environment(\.watchlistManager, watchlistManager)
                .environment(\.deepLinkManager, deepLinkManager)
                .onAppear {
                    favoritesManager.configure(with: sharedModelContainer.mainContext)
                    watchlistManager.configure(with: sharedModelContainer.mainContext)
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
