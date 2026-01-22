import SwiftUI

/// Main tab view with Discover and Favorites tabs
struct MainTabView: View {
    @Environment(\.themeManager) private var themeManager

    var body: some View {
        TabView {
            DiscoveryView()
                .tabItem {
                    Label("Discover", systemImage: "sparkles")
                }

            FavoritesView()
                .tabItem {
                    Label("Favorites", systemImage: "heart.fill")
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
