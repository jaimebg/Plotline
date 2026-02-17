import AppIntents
import SwiftData
import SwiftUI

@main
struct PlotlineApp: App {
    @State private var themeManager = ThemeManager.shared
    @State private var favoritesManager = FavoritesManager()
    @State private var watchlistManager = WatchlistManager()
    @State private var deepLinkManager = DeepLinkManager()
    @Environment(\.scenePhase) private var scenePhase

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([FavoriteItem.self, WatchlistItem.self])
        let cloudConfig = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )

        do {
            return try ModelContainer(for: schema, configurations: [cloudConfig])
        } catch {
            #if DEBUG
            print("CloudKit unavailable, using local storage: \(error.localizedDescription)")
            #endif
            let localConfig = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none
            )
            do {
                return try ModelContainer(for: schema, configurations: [localConfig])
            } catch {
                #if DEBUG
                print("Schema migration failed, creating fresh store: \(error.localizedDescription)")
                #endif
                let storeURL = URL.applicationSupportDirectory.appending(path: "default.store")
                try? FileManager.default.removeItem(at: storeURL)
                return try! ModelContainer(for: schema, configurations: [localConfig])
            }
        }
    }()

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
                    AppDependencyManager.shared.add(dependency: sharedModelContainer)
                }
                .onOpenURL { url in
                    deepLinkManager.handleURL(url)
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        handleSiriSearchQuery()
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }

    private func handleSiriSearchQuery() {
        let sharedDefaults = UserDefaults(suiteName: "group.com.jbgsoft.Plotline")
        if let query = sharedDefaults?.string(forKey: "siri_search_query"), !query.isEmpty {
            sharedDefaults?.removeObject(forKey: "siri_search_query")
            deepLinkManager.pendingSearchQuery = query
            deepLinkManager.pendingTab = .discover
        }
    }
}
