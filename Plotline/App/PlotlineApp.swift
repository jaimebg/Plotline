import SwiftData
import SwiftUI

/// Main entry point for the Plotline application
@main
struct PlotlineApp: App {
    @State private var themeManager = ThemeManager.shared
    @State private var favoritesManager = FavoritesManager()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([FavoriteItem.self])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(\.themeManager, themeManager)
                .environment(\.favoritesManager, favoritesManager)
                .onAppear {
                    favoritesManager.configure(with: sharedModelContainer.mainContext)
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
