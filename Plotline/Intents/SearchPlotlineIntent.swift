import AppIntents

/// Siri intent that opens the app and searches for a title
struct SearchPlotlineIntent: AppIntent {
    static var title: LocalizedStringResource = "Search Plotline"
    static var description = IntentDescription("Search for a movie or TV series in Plotline")
    static var openAppWhenRun = true

    @Parameter(title: "Title")
    var query: String

    /// Registered in `PlotlineApp.init()`. With `openAppWhenRun` the intent
    /// runs in the app's own process, so it can hand the query straight to the
    /// view hierarchy instead of leaving it in shared defaults for the next
    /// activation to find — which missed the run that wrote it.
    @Dependency
    private var deepLinkManager: DeepLinkManager

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        deepLinkManager.pendingSearchQuery = query
        deepLinkManager.pendingTab = .discover
        return .result(dialog: "Searching for \(query)...")
    }
}
