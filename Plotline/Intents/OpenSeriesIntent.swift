import AppIntents

/// Opens a series' detail screen.
///
/// Spotlight runs this when someone taps an indexed series, and the Siri
/// verdict snippet's "Open in Plotline" button runs it too. As an `OpenIntent`
/// it always runs in the app's own process with the app in front, so it can
/// hand the series straight to the view hierarchy — on a cold launch before
/// any view exists, which is why `DiscoveryView` also consumes it on appear.
struct OpenSeriesIntent: OpenIntent {
    static let title: LocalizedStringResource = "Open Series"
    static let description = IntentDescription("Open a series' analysis in Plotline")

    @Parameter(title: "Series")
    var target: SeriesEntity

    /// Registered in `PlotlineApp.init()`.
    @Dependency
    private var deepLinkManager: DeepLinkManager

    init() {}

    init(series: SeriesEntity) {
        self.target = series
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        deepLinkManager.openDetail(
            PendingDetail(tmdbId: target.id, mediaType: .tv, name: target.name)
        )
        return .result()
    }
}
