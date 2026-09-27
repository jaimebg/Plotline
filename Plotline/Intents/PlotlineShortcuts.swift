import AppIntents

/// Provides Siri Shortcuts for discovery in the Shortcuts app and Siri suggestions
struct PlotlineShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        // A phrase may interpolate only an AppEntity or AppEnum parameter, and
        // must name the app. The phrases that name a series match the query's
        // suggested entities — the bundled dataset; the plain phrase lets Siri
        // ask "Which series?" for anything else.
        AppShortcut(
            intent: GetPlotlineVerdictIntent(),
            phrases: [
                "How does \(\.$series) hold up in \(.applicationName)",
                "What's the \(.applicationName) Score of \(\.$series)",
                "Get the \(.applicationName) verdict on \(\.$series)",
                "\(.applicationName) verdict for \(\.$series)",
                "Get a \(.applicationName) verdict",
            ],
            shortTitle: "Plotline Verdict",
            systemImageName: "chart.xyaxis.line"
        )

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
