import AppIntents

/// Siri intent that opens the app and searches for a title
struct SearchPlotlineIntent: AppIntent {
    static var title: LocalizedStringResource = "Search Plotline"
    static var description = IntentDescription("Search for a movie or TV series in Plotline")
    static var openAppWhenRun = true

    @Parameter(title: "Title")
    var query: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        UserDefaults(suiteName: "group.com.jbgsoft.Plotline")?.set(query, forKey: "siri_search_query")
        return .result(dialog: "Searching for \(query)...")
    }
}
