import SwiftUI

/// Main entry point for the Plotline application
@main
struct PlotlineApp: App {
    @State private var themeManager = ThemeManager.shared

    var body: some Scene {
        WindowGroup {
            DiscoveryView()
                .environment(\.themeManager, themeManager)
        }
    }
}
