import SwiftUI

/// Tab selection values for type-safe programmatic navigation
enum AppTab: Hashable {
    case discover
    case favorites
    case settings
}

/// Main tab view with Discover, Favorites, and Settings tabs using iOS 18+ Tab API
struct MainTabView: View {
    @Environment(\.themeManager) private var themeManager
    @State private var selectedTab: AppTab = .discover

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Discover", systemImage: "sparkles", value: .discover) {
                DiscoveryView()
            }

            Tab("Favorites", systemImage: "heart.fill", value: .favorites) {
                FavoritesView()
            }

            Tab("Settings", systemImage: "gear", value: .settings) {
                SettingsView()
            }
        }
        .tint(Color.plotlinePrimary)
        .preferredColorScheme(themeManager.colorScheme)
    }
}

// MARK: - Preview

#Preview {
    MainTabView()
}
