import SwiftData
import SwiftUI

@main
struct PlotlineApp: App {
    @State private var themeManager = ThemeManager.shared
    @State private var favoritesManager = FavoritesManager()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([FavoriteItem.self])
        let cloudConfig = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )

        do {
            return try ModelContainer(for: schema, configurations: [cloudConfig])
        } catch {
            print("CloudKit unavailable, using local storage: \(error.localizedDescription)")
            let localConfig = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none
            )
            do {
                return try ModelContainer(for: schema, configurations: [localConfig])
            } catch {
                print("Schema migration failed, creating fresh store: \(error.localizedDescription)")
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
                .onAppear {
                    favoritesManager.configure(with: sharedModelContainer.mainContext)
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
