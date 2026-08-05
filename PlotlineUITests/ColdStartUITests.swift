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

    func testDiscoverShowsCuratedShelves() {
        openTab("Discover")
        let shelves = app.descendants(matching: .any)
            .matching(identifier: UITestAnchors.discoverShelf)
        XCTAssertTrue(
            shelves.firstMatch.waitForExistence(timeout: 10),
            "Discover rendered no curated shelf at all"
        )
        // Only the shelves scrolled into view have materialised. The dataset
        // ships five; ColdStartTests is what asserts that number exactly.
        XCTAssertGreaterThanOrEqual(
            shelves.count, 2,
            "Discover showed only \(shelves.count) curated shelves on first screen"
        )
    }

    func testWatchlistOffersSuggestionsWithNothingSaved() {
        openTab("Watchlist")
        assertShelf(UITestAnchors.watchlistSuggestions, tab: "Watchlist")
    }

    /// Two assertions, not one, and that is the whole point.
    ///
    /// The rejected build showed the empty-state invitation *instead of* the
    /// rest of the tab. A suite that only checked the invitation was there
    /// would have passed on the build that got rejected.
    func testStatsKeepsItsUserIndependentSectionsWhenNothingIsSaved() {
        openTab("Stats")

        let invitation = app.descendants(matching: .any)[UITestAnchors.statsYourStatsEmpty]
        XCTAssertTrue(
            invitation.waitForExistence(timeout: 10),
            "Stats did not show the empty-state invitation with nothing saved"
        )

        for anchor in [
            UITestAnchors.statsCompare,
            UITestAnchors.statsCareerProfiles,
            UITestAnchors.statsTrends,
        ] {
            let section = app.descendants(matching: .any)[anchor]
            if !section.exists {
                app.swipeUp()
            }
            XCTAssertTrue(
                section.waitForExistence(timeout: 5),
                """
                Stats is missing \"\(anchor)\" with nothing saved. This section \
                analyses TMDB, not the user's library, and gating it behind \
                saved favorites is the defect that got 1.3.0 rejected.
                """
            )
        }
    }

    func testSettingsIsReachableAndPopulated() {
        openTab("Settings")
        let rows = app.descendants(matching: .any)
            .matching(identifier: UITestAnchors.settingsRow)
        XCTAssertTrue(
            rows.firstMatch.waitForExistence(timeout: 10),
            "Settings rendered no rows"
        )
        XCTAssertGreaterThanOrEqual(rows.count, 2, "Settings showed only \(rows.count) rows")
    }

    // MARK: - Helpers

    private func openTab(_ name: String) {
        // The tab bar on iPhone; on iPad under .sidebarAdaptable this renders
        // as a horizontal tab bar that only fits four items at this width.
        // The fifth (Settings) sits behind a "Next Page" control rather than
        // a chevron — page forward once and look again before giving up.
        var button = tabButton(name)
        if !button.exists {
            let nextPage = app.buttons["Next Page"]
            if nextPage.waitForExistence(timeout: 5) {
                nextPage.tap()
                button = tabButton(name)
            }
        }
        XCTAssertTrue(
            button.waitForExistence(timeout: 10),
            "no way to reach the \(name) tab"
        )
        button.tap()
    }

    /// `.firstMatch`, not the bare `app.buttons[name]` subscript: on iPad the
    /// floating tab bar renders each item as two nested elements sharing the
    /// same label — a rendering quirk, not two tabs — and resolving that to
    /// exactly one match throws "multiple matching elements found" at tap
    /// time. iPhone has only the one element, so `.firstMatch` is a no-op
    /// there.
    private func tabButton(_ name: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label == %@", name)).firstMatch
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
