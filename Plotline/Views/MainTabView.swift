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
        .tabViewStyle(.sidebarAdaptable)
        .tint(Color.plotlineAccent)
        .preferredColorScheme(themeManager.colorScheme)
        // Also on appear: a tab requested before this view exists would
        // otherwise stay pending, and the next identical request would then
        // produce no change to react to.
        .onAppear { consumePendingTab() }
        .onChange(of: deepLinkManager.pendingTab) { _, _ in
            consumePendingTab()
        }
    }

    private func consumePendingTab() {
        guard let tab = deepLinkManager.pendingTab else { return }
        selectedTab = tab
        deepLinkManager.pendingTab = nil
    }
}

// MARK: - Preview

#Preview {
    MainTabView()
}
