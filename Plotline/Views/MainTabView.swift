import SwiftUI

/// Tab selection values for type-safe programmatic navigation
enum AppTab: Hashable {
    case discover
    case favorites
    case watchlist
    case stats
    case settings
}

/// Main tab view with Discover, Favorites, and Settings tabs using iOS 18+ Tab API
struct MainTabView: View {
    @Environment(\.themeManager) private var themeManager
    @Environment(\.deepLinkManager) private var deepLinkManager
    @State private var selectedTab: AppTab = .discover

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Discover", systemImage: "sparkles", value: .discover) {
                DiscoveryView()
            }

            Tab("Favorites", systemImage: "heart.fill", value: .favorites) {
                FavoritesView()
            }

            Tab("Watchlist", systemImage: "eye.fill", value: .watchlist) {
                WatchlistView()
            }

            Tab("Stats", systemImage: "chart.bar.fill", value: .stats) {
                StatsView()
            }

            Tab("Settings", systemImage: "gear", value: .settings) {
                SettingsView()
            }
        }
        .tint(Color.plotlinePrimary)
        .preferredColorScheme(themeManager.colorScheme)
        .onChange(of: deepLinkManager.pendingTab) { _, newTab in
            if let tab = newTab {
                selectedTab = tab
                deepLinkManager.pendingTab = nil
            }
        }
    }
}

// MARK: - Preview

#Preview {
    MainTabView()
}
