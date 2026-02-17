import AppIntents

/// Provides Siri Shortcuts for discovery in the Shortcuts app and Siri suggestions
struct PlotlineShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: WhatShouldIWatchIntent(),
            phrases: [
                "What should I watch on \(.applicationName)",
                "Suggest something on \(.applicationName)",
                "Give me a \(.applicationName) recommendation",
            ],
            shortTitle: "What Should I Watch?",
            systemImageName: "sparkles.tv"
        )

        AppShortcut(
            intent: ShowMyStatsIntent(),
            phrases: [
                "Show my \(.applicationName) stats",
                "My \(.applicationName) collection",
            ],
            shortTitle: "My Stats",
            systemImageName: "chart.bar.fill"
        )

        AppShortcut(
            intent: SearchPlotlineIntent(),
            phrases: [
                "Search on \(.applicationName)",
                "Find something on \(.applicationName)",
            ],
            shortTitle: "Search",
            systemImageName: "magnifyingglass"
        )
    }
}
