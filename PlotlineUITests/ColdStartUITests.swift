import XCTest

/// The session an App Store reviewer has: a clean install, nothing saved.
///
/// Version 1.3.0 was rejected under Guideline 4.2 because `StatsView` wrapped
/// Compare, Career Profiles and Trends — none of which need user data — in a
/// check for saved favorites, so a reviewer with an empty library concluded
/// the app had nothing in it. `ColdStartTests` covers the dataset behind those
/// screens; nothing covered the screens. This does.
///
/// Two conditions, neither covering the other. Starved of TMDB this proves the
/// bundled dataset carries all five tabs on its own; live it is the only pass
/// that exercises the recomputation path, which can empty a screen the dataset
/// had filled.
final class ColdStartUITests: XCTestCase {
    private var app: XCUIApplication!

    /// `live` runs against real TMDB and is launched only by the release
    /// preflight. Anything else — including the variable being absent — starves
    /// the app, which is the deterministic default the normal test loop uses.
    private var isLiveMode: Bool {
        ProcessInfo.processInfo.environment["PLOTLINE_UITEST_MODE"] == "live"
    }

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        if !isLiveMode {
            // Beats the bundled Secrets.plist since Task 2. An empty value
            // counts as set, so the app runs with no key and TMDB yields
            // nothing.
            app.launchEnvironment["TMDB_API_KEY"] = ""
        }
        app.launch()
    }

    /// Asserts the suite's own precondition instead of trusting the runner.
    ///
    /// Favorites and the watchlist persist in SwiftData, inside the app
    /// container, so no launch argument can clear them — only uninstalling
    /// can. A run that skipped the uninstall would otherwise pass green while
    /// testing a state no reviewer ever sees.
    func testContainerIsClean() {
        openTab("Favorites")
        let savedRows = app.descendants(matching: .any)
            .matching(identifier: UITestAnchors.favoritesSavedRow)
        XCTAssertEqual(
            savedRows.count, 0,
            """
            The simulator container carried \(savedRows.count) saved favorites, \
            so this run is not testing a clean install. Run \
            `xcrun simctl uninstall booted com.jbgsoft.Plotline` first, or use \
            Scripts/release-preflight.sh which does it for you.
            """
        )
    }

    func testFavoritesOffersSuggestionsWithNothingSaved() {
        openTab("Favorites")
        assertShelf(UITestAnchors.favoritesSuggestions, tab: "Favorites")
    }

    // MARK: - Helpers

    private func openTab(_ name: String) {
        // The tab bar on iPhone, the sidebar on iPad under .sidebarAdaptable.
        let button = app.buttons[name]
        XCTAssertTrue(
            button.waitForExistence(timeout: 10),
            "no way to reach the \(name) tab"
        )
        button.tap()
    }

    /// A shelf must exist and show something. The exact counts — five lists,
    /// twelve suggestions, sixty titles — stay in `ColdStartTests`, which sees
    /// the whole dataset. XCUITest only sees what materialised on screen, and
    /// these shelves are `LazyHStack`s, so asserting a full count here would
    /// go red for a reason that has nothing to do with the defect.
    private func assertShelf(_ identifier: String, tab: String, minimumCards: Int = 2) {
        let shelf = app.descendants(matching: .any)[identifier]
        XCTAssertTrue(
            shelf.waitForExistence(timeout: 10),
            "the \(tab) tab is missing its content anchor \"\(identifier)\""
        )

        let cards = shelf.descendants(matching: .any)
            .matching(identifier: UITestAnchors.mediaCard)
        XCTAssertGreaterThanOrEqual(
            cards.count, minimumCards,
            "the \(tab) tab rendered its container but only \(cards.count) cards in it"
        )
    }
}
