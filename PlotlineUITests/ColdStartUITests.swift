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
            // An explicitly set environment variable beats the bundled
            // Secrets.plist, and an empty value still counts as set, so the
            // app runs with no key and TMDB yields nothing.
            // `testDiscoverMatchesTheModeThisPassClaims` is what checks this
            // arrived; without it the whole suite could run live and say so
            // nowhere.
            app.launchEnvironment["TMDB_API_KEY"] = ""
        }
        // Printed rather than asserted, because no assertion here can do this
        // job: the suite reads PLOTLINE_UITEST_MODE to *choose* its mode, so
        // if xcodebuild's TEST_RUNNER_ forwarding ever broke, the variable
        // would simply be absent, the suite would starve the app, every test
        // would pass, and the release preflight would print "live pass green"
        // over a second starved pass. Step 2 of Scripts/release-preflight.sh
        // greps this line for `live` and fails the step when it says
        // `starved`. Do not change the format without changing that grep.
        print("PLOTLINE_UITEST_MODE_OBSERVED=\(isLiveMode ? "live" : "starved")")
        app.launch()
    }

    /// Asserts the suite's own precondition instead of trusting the runner.
    ///
    /// Favorites and the watchlist persist in SwiftData, in a store no launch
    /// argument can reach — only uninstalling the app removes it. The store is
    /// not in the app's own container but in the shared app-group one,
    /// `group.com.jbgsoft.Plotline`; the simulator takes that with the app,
    /// but only while the device is booted, which is what makes the
    /// preflight's device-by-name uninstall load-bearing rather than tidy.
    ///
    /// A run that skipped the uninstall would otherwise pass green while
    /// testing a state no reviewer ever sees.
    func testContainerIsClean() {
        openTab("Favorites")

        // Zero is what a clean container looks like — and also what a screen
        // that has not drawn yet looks like. Wait for the tab to be on screen
        // first, so the count below is a count of the Favorites tab rather
        // than of nothing.
        XCTAssertTrue(
            app.navigationBars["Favorites"].waitForExistence(timeout: 10),
            "the Favorites tab never drew, so the row count below would say nothing about the container"
        )

        let savedRows = app.descendants(matching: .any)
            .matching(identifier: UITestAnchors.favoritesSavedRow)
        XCTAssertEqual(
            savedRows.count, 0,
            """
            The simulator container matched \(savedRows.count) accessibility \
            elements carrying the saved-favorite row identifier — a count of \
            elements, not of favorites, since XCUITest can report more than \
            one per row — so this run is not testing a clean install. \
            Uninstall com.jbgsoft.Plotline from the simulator this suite just \
            ran on, by name rather than by `booted`, and run it again; \
            Scripts/release-preflight.sh does exactly that against the device \
            it then tests.
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
            // No scrolling here on purpose: `statsContent` is a plain `VStack`
            // inside a `ScrollView`, not a lazy one, so all three identifiers
            // are in the tree whether or not they are on screen.
            let section = app.descendants(matching: .any)[anchor]
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

    /// Proves the pass ran in the mode it says it ran in.
    ///
    /// Every other assertion here is silent about this. Starved, the suite's
    /// whole claim is that the *bundled dataset* fills five tabs with no TMDB
    /// key — but if `launchEnvironment["TMDB_API_KEY"] = ""` never reached
    /// `Secrets`, the app would be pulling live content and every other test
    /// here would still be green, having proved nothing about the dataset.
    /// That is the app's Guideline 4.2 defence, so it cannot rest on an
    /// assumption.
    ///
    /// `testDiscoverShowsCuratedShelves` does not cover this: `curatedShelves`
    /// iterates `DatasetStore.shared.lists` unconditionally, so it renders the
    /// same with a live key as without one.
    ///
    /// Discover's network sections are the observable, because they are the
    /// one place where the two outcomes are mutually exclusive: no content and
    /// an error renders `discoverNetworkError`; anything else renders
    /// `discoverTrendingMovies`, including a fetch that succeeds with zero
    /// results — `MediaSection` draws a placeholder rather than nothing when
    /// empty, so this anchor proves the fetch did not fail, not that it
    /// returned content.
    func testDiscoverMatchesTheModeThisPassClaims() {
        openTab("Discover")

        if isLiveMode {
            XCTAssertTrue(
                scrollToAnchor(UITestAnchors.discoverTrendingMovies).exists,
                """
                This pass declares itself live, but Discover never rendered \
                its TMDB-backed sections. Either TMDB answered with nothing \
                — a bad key, or a rate limit — or the anchor moved. Either \
                way nothing below this line exercised the live recomputation \
                path, which is the only reason the live pass exists.
                """
            )
        } else {
            XCTAssertTrue(
                scrollToAnchor(UITestAnchors.discoverNetworkError).exists,
                """
                Discover never rendered its TMDB failure state. Either the \
                empty TMDB_API_KEY in launchEnvironment did not reach \
                Secrets — in which case this pass ran against live TMDB and \
                proves nothing about the bundled dataset, which is what it \
                exists to prove — or the anchor moved.
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

    /// Scrolls until the anchor is in the tree, or gives up and returns an
    /// element that does not exist, for the caller to assert on.
    ///
    /// Discover's network sections sit below five curated shelves inside a
    /// `LazyVStack`, and XCUITest cannot see a view SwiftUI has not built yet,
    /// so on the first screen their absence means nothing either way.
    private func scrollToAnchor(_ identifier: String, maximumSwipes: Int = 12) -> XCUIElement {
        let element = app.descendants(matching: .any)[identifier]
        if element.waitForExistence(timeout: 5) { return element }

        for _ in 0..<maximumSwipes {
            app.swipeUp(velocity: .fast)
            if element.waitForExistence(timeout: 1) { return element }
        }
        return element
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
