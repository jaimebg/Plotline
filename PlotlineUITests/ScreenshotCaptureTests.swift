import UIKit
import XCTest

/// Produces the raw App Store screenshots. Not a test of anything: it drives
/// the app to eight known screens and attaches a capture of each.
///
/// It lives in the UI test target because that is the only way to tap through
/// a real build, and it is skipped unless `PLOTLINE_SCREENSHOT_CAPTURE` says
/// otherwise, so `xcodebuild test` never runs it. Two reasons that matters:
/// it needs a working TMDB key, which the normal loop deliberately withholds,
/// and it is slow.
///
/// Navigation mostly finds its target by visible English label, not by
/// identifier: "Where to Watch", "Plotline Score", "Episode Ratings",
/// "Episode Scores", "What the Numbers Say", "Compare Movies & Series",
/// "Decade Battle", "Ratings", "Empty comparison slot". Renaming any of
/// those strings breaks a capture. Only three lookups go through
/// `UITestAnchors` (the Discover shelf, and the Compare and Trends section
/// anchors in Stats), and one more is a bare element index
/// (`app.navigationBars.buttons.element(boundBy: 0)`). `scrollTo`/`step`
/// scroll by normalized window coordinates — that's a drag gesture, not a
/// lookup. If a screen turns out to be unreachable any other way, add an
/// anchor to `Plotline/Support/AccessibilityAnchors.swift` and its twin
/// here rather than reaching for a raw point.
final class ScreenshotCaptureTests: XCTestCase {
    private var app: XCUIApplication!

    private var isEnabled: Bool {
        ProcessInfo.processInfo.environment["PLOTLINE_SCREENSHOT_CAPTURE"] == "1"
    }

    override func setUpWithError() throws {
        try XCTSkipUnless(
            isEnabled,
            """
            Screenshot capture is off. It is skipped by default because it \
            needs a real TMDB key and takes minutes; run it through \
            Scripts/screenshots/capture.sh, which sets \
            TEST_RUNNER_PLOTLINE_SCREENSHOT_CAPTURE=1.
            """
        )
        continueAfterFailure = false
        app = XCUIApplication()
        // The status bar is pinned host-side by capture.sh; the locale has to
        // come in here, or an English UI ships under a Spanish date.
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        // iPad ships landscape screenshots. Setting this from inside the test
        // is the only reliable way: rotating the simulator through its Device
        // menu was tried three ways during design and the framebuffer stayed
        // portrait every time. Setting it before `launch()` was also tried —
        // all eight captures came back 2064x2752 (portrait) — so the request
        // has to reach a running app, and even then the rotation is not
        // instantaneous: without the settle below, the first capture can
        // still be taken before the framebuffer catches up.
        if UIDevice.current.userInterfaceIdiom == .pad {
            XCUIDevice.shared.orientation = .landscapeLeft
            Thread.sleep(forTimeInterval: 2.0)
        }
    }

    func testCaptureAll() throws {
        // 5 first: Discover is where the app starts, and the detail screens
        // are reached from it. Attachment order does not have to match frame
        // order — the name does.
        capture(5, of: "discover shelves") {
            XCTAssertTrue(
                shelf.waitForExistence(timeout: 30),
                "Discover never drew a shelf, so there is nothing to photograph"
            )
        }

        openSeriesDetail(named: "Breaking Bad")

        // `scrollTo` only swipes up, so these four have to run in the order
        // they actually appear on the page, not in frame-number order: Where
        // to Watch sits above the analysis section, not below the episode
        // grid as an earlier reading of this screen assumed — `MediaDetailView`
        // answers "can I watch this" before "will I like it". Confirmed by
        // inspecting a captured frame 1 that showed Overview/Where to Watch
        // instead of the score card when frame 1 ran first without its own
        // scroll.
        capture(6, of: "where to watch") {
            // Framed by the section's own header, not the attribution
            // caption at its foot. `scrollTo` pins its target near the top
            // of the screen, and the header is what belongs there: pinning
            // the caption instead would push the provider logos above it
            // mostly off-screen, which frames the wrong part of this
            // section's own subject.
            scrollTo(app.staticTexts["Where to Watch"])
        }
        capture(1, of: "plotline score") {
            scrollTo(app.staticTexts["Plotline Score"])
        }
        capture(3, of: "season chart") {
            scrollTo(app.staticTexts["Episode Ratings"])
        }
        capture(4, of: "episode grid") {
            scrollTo(app.staticTexts["Episode Scores"])
        }

        // Frame 2's headline says a series falls off, so it has to photograph
        // one that does. Breaking Bad's declinePoint is null — it never
        // declines — so shooting its verdicts under that headline would be the
        // exact defect the copy rule exists to prevent. The Walking Dead falls
        // off after season 6 and is in the bundled dataset.
        returnToDiscover()
        openSeriesDetail(named: "The Walking Dead")
        capture(2, of: "decline verdict") {
            scrollTo(app.staticTexts["What the Numbers Say"])
            let decline = app.staticTexts.containing(
                NSPredicate(format: "label BEGINSWITH %@", "Falls off after season")
            ).firstMatch
            // `.exists` alone is true anywhere in the accessibility tree,
            // including off-screen, so it would not catch this verdict
            // rendering somewhere `scrollTo` failed to bring into frame —
            // the same class of gap frame 8's `waitForExistence` + implicit
            // on-screen check below (a navigation bar, always visible when
            // present) closes for the Decade Battle push. `isHittable`
            // additionally requires the element sit within the visible
            // window, which is what the capture actually shows.
            XCTAssertTrue(
                decline.waitForExistence(timeout: 5) && decline.isHittable,
                """
                The Walking Dead rendered no decline verdict, or it isn't \
                visible on screen, so frame 2's headline would claim a fall \
                the screenshot does not show. Do not ship this capture; \
                pick another series with a declinePoint in \
                PlotlineDataset.json.
                """
            )
        }

        openTab("Stats")
        capture(7, of: "compare") {
            let compareSection = app.descendants(matching: .any)
                .matching(identifier: UITestAnchors.statsCompare).firstMatch
            XCTAssertTrue(compareSection.waitForExistence(timeout: 20), "Compare never appeared in Stats")
            // `UITestAnchors.statsCompare` marks the section's wrapping
            // VStack, not the NavigationLink inside it — SwiftUI attaches the
            // identifier to the first accessibility-native descendant it
            // finds, which is the "Compare" header text, not the button row
            // below it. Tapping that identifier taps inert text and never
            // navigates, so the actual push goes through the link's own
            // visible label instead.
            let compareLink = app.staticTexts["Compare Movies & Series"]
            XCTAssertTrue(compareLink.waitForExistence(timeout: 5), "Compare Movies & Series link never appeared")
            compareLink.tap()

            // Frame 7's headline claims a real comparison, so the capture has
            // to show one. `CompareView`'s empty state — three dashed slots
            // and "Add at least 2 titles to compare" — is a real screen, but
            // not what the headline promises. Breaking Bad and The Walking
            // Dead are both reachable through the same TMDB search an empty
            // slot opens, and both carry analysis, so the filled comparison
            // shows real numbers rather than a placeholder.
            addCompareSlot(named: "Breaking Bad")
            addCompareSlot(named: "The Walking Dead")

            let comparison = app.descendants(matching: .any)["Ratings"]
            // Same gap as frame 2's check: `waitForExistence` alone proves
            // the element is somewhere in the tree, not that it's on the
            // screen this capture takes. `isHittable` proves the latter.
            XCTAssertTrue(
                comparison.waitForExistence(timeout: 10) && comparison.isHittable,
                """
                Compare filled two slots but never rendered a visible \
                comparison, so frame 7 would still show the empty state \
                under a headline that claims two titles side by side.
                """
            )
        }
        capture(8, of: "trends") {
            app.navigationBars.buttons.element(boundBy: 0).tap()
            let trendsSection = app.descendants(matching: .any)
                .matching(identifier: UITestAnchors.statsTrends).firstMatch
            XCTAssertTrue(trendsSection.waitForExistence(timeout: 20), "Trends never appeared in Stats")
            // Same reasoning as Compare above: the anchor sits on the
            // section's VStack, not on either trend card. Decade Battle is
            // the first of `TrendsView`'s two cards; its label is the whole
            // card combined into one button-traited element, so it is found
            // by its title rather than an exact full-label match.
            let decadeBattle = app.buttons.matching(
                NSPredicate(format: "label BEGINSWITH %@", "Decade Battle")
            ).firstMatch
            XCTAssertTrue(decadeBattle.waitForExistence(timeout: 5), "Decade Battle trend card never appeared")
            decadeBattle.tap()

            // Frame 7's own "Ratings" check exists for the same reason: a
            // tap registering is not proof the push happened. Without this,
            // a slow push animation racing `capture`'s fixed sleep could ship
            // a screenshot of the Trends list under a headline that claims
            // Decade Battle, and nothing would catch it — the file would
            // still be the right size. `DecadeBattleView` sets this as its
            // `.navigationTitle`, so it is cheap and specific to wait for.
            XCTAssertTrue(
                app.navigationBars["Decade Battle"].waitForExistence(timeout: 10),
                """
                Decade Battle never pushed after the tap, so frame 8 would \
                still show the Trends list under a headline that claims \
                Decade Battle.
                """
            )
        }
    }

    private var shelf: XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: UITestAnchors.discoverShelf).firstMatch
    }

    /// Opens a series through search rather than by tapping whatever happens
    /// to be first in a shelf: shelf order comes from the dataset and changes
    /// when it is regenerated, and a screenshot set that silently switches
    /// series between runs is not reproducible.
    private func openSeriesDetail(named title: String) {
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 20), "no search field on Discover")
        // A single tap is not reliable here: on iPad, `returnToDiscover` can
        // land on this field while it is still mid-transition from the pop
        // that revealed it. `hasKeyboardFocus` briefly reports true from
        // that earlier state while the real first responder is still
        // catching up, so a pre-check that skips tapping when it already
        // reads true is exactly wrong — it trusts the stale read. Tap
        // unconditionally every time, then confirm focus stuck before
        // typing; `typeText` fails outright with "Neither element nor any
        // descendant has keyboard focus" if it hasn't. `hasKeyboardFocus`
        // isn't an XCUIElement property in this SDK, so it is checked the
        // same way XCTest checks it internally: as a query predicate.
        let focused = app.searchFields.matching(NSPredicate(format: "hasKeyboardFocus == true")).firstMatch
        // Always taps at least once per call, even if `focused` already
        // reads true going in — a stale true from before the tap is the
        // exact failure mode above, so a check-then-tap ordering would just
        // reintroduce it.
        func ensureFocused() {
            for _ in 0..<5 {
                field.tap()
                Thread.sleep(forTimeInterval: 0.4)
                if focused.exists { return }
            }
            XCTAssertTrue(focused.exists, "search field never took keyboard focus")
        }
        ensureFocused()
        // DiscoveryView's search state is `@State` on the view itself, not on
        // the navigation path, so popping back to the Discover root through
        // `returnToDiscover` leaves an earlier query's text sitting in the
        // field. Typing over it without clearing first appends rather than
        // replaces, and the concatenation matches nothing.
        let clear = field.buttons["Clear text"]
        if clear.waitForExistence(timeout: 2) {
            clear.tap()
            // Tapping a different element than the field itself — even one
            // right next to it — can drop keyboard focus on iPad, and this
            // is exactly the leftover-text case that only happens after a
            // `returnToDiscover` round trip, the same state where focus was
            // already fragile enough to need `ensureFocused` once above.
            ensureFocused()
        }
        field.typeText(title)

        let result = app.staticTexts[title].firstMatch
        XCTAssertTrue(
            result.waitForExistence(timeout: 30),
            "search for \(title) returned nothing — is TMDB_API_KEY set?"
        )
        result.tap()
        XCTAssertTrue(
            app.staticTexts["Plotline Score"].waitForExistence(timeout: 30),
            "opened \(title) but no analysis rendered; it may have no episode data"
        )
    }

    /// Fills the next empty Compare slot through the same flow a user would
    /// use: tap the dashed "Add" placeholder, search TMDB, tap the result.
    /// Never by coordinate — the slot is found by the accessibility label
    /// `ComparisonSlotView` gives an empty slot, and the result by the title
    /// text `CompareView`'s own search row renders.
    private func addCompareSlot(named title: String) {
        let emptySlot = app.buttons["Empty comparison slot"].firstMatch
        XCTAssertTrue(
            emptySlot.waitForExistence(timeout: 10),
            "Compare has no empty slot left to add \(title) to"
        )
        emptySlot.tap()

        let field = app.searchFields.firstMatch
        XCTAssertTrue(
            field.waitForExistence(timeout: 20),
            "Compare's search sheet never presented a search field"
        )
        // The sheet's presentation animation can still be settling right
        // after the field appears in the tree, and a tap during that window
        // can land without taking keyboard focus — the same failure mode
        // `openSeriesDetail` guards against on Discover. Retry rather than
        // trust a single tap.
        let focused = app.searchFields.matching(NSPredicate(format: "hasKeyboardFocus == true")).firstMatch
        var didFocus = false
        for _ in 0..<5 {
            field.tap()
            Thread.sleep(forTimeInterval: 0.4)
            if focused.exists { didFocus = true; break }
        }
        XCTAssertTrue(didFocus, "Compare's search field never took keyboard focus")
        field.typeText(title)

        let result = app.staticTexts[title].firstMatch
        XCTAssertTrue(
            result.waitForExistence(timeout: 30),
            "Compare search for \(title) returned nothing — is TMDB_API_KEY set?"
        )
        result.tap()

        // `selectItem` dismisses the sheet synchronously, then fetches the
        // full TMDB detail plus every season's episodes in the background —
        // the slot shows a spinner briefly before its title text reappears,
        // this time on the slot itself rather than the now-dismissed search
        // row.
        XCTAssertTrue(
            app.staticTexts[title].waitForExistence(timeout: 45),
            "\(title) never filled a Compare slot after selection"
        )
    }

    /// Pops back to the Discover root so a second series can be opened. The
    /// tab tap alone leaves the pushed detail screen in place; tapping the
    /// already-selected tab is what pops it.
    private func returnToDiscover() {
        openTab("Discover")
        // On iPad, that first pop can leave the search field focused from the
        // series search that opened the last detail screen — `.searchable`
        // with `.sidebarAdaptable` replaces the whole tab bar with the search
        // overlay while presented, removing every tab button from the tree,
        // not merely covering it. A second tap has nothing to hit in that
        // state, and the field being focused already satisfies this method's
        // job, so only retap if the tab bar is still there to find. iPhone's
        // floating tab bar stays on screen through search, so this is a no-op
        // there and the second tap still runs as before.
        if tabButton("Discover").waitForExistence(timeout: 3) {
            openTab("Discover")
        }
        XCTAssertTrue(
            app.searchFields.firstMatch.waitForExistence(timeout: 20),
            "never got back to the Discover root"
        )
        // The search field existing is not the same as the pop's transition
        // having finished — the same "exists before drawn" gap `capture`
        // works around below. `openSeriesDetail`'s own focus retry loop
        // covers the rest, but starting it mid-transition is what caused it
        // to need retries at all.
        Thread.sleep(forTimeInterval: 0.5)
    }

    /// Scrolls until `element` is pinned within the top 30% of the screen,
    /// not merely hittable somewhere on it.
    ///
    /// The original version stopped the instant the target was hittable,
    /// anywhere on screen. That let two sections that fit on one screen
    /// together settle at the identical scroll position: the Plotline Score
    /// card and the Where to Watch attribution just above it, and the
    /// episode chart and the episode grid just below it. Whichever target a
    /// single swipe made hittable first, the other was hittable too, so the
    /// two captures came back byte-identical — md5-confirmed on both device
    /// families. Framing each target near the top pushes its neighbour
    /// mostly or fully off-screen, so each frame photographs the section its
    /// own headline claims rather than whatever else shares its screen.
    ///
    /// Drags in small steps rather than `swipeUp()`'s near-full-screen
    /// gesture, which is what caused the collision above: when the gap
    /// between two targets is under one screen's height, one big swipe can
    /// carry both past "hittable" in the same motion. Small steps converge
    /// on the top band instead of jumping past it; a step in the other
    /// direction corrects an overshoot rather than compounding it.
    ///
    /// This used to fail roughly half of cold-boot capture attempts,
    /// clearing on an identical retry with no code change — the signature of
    /// a race, not a broken assertion. The cause was geometric, not a
    /// loading race: `step(up:)`'s drag used to cover 0.35 of the window
    /// height, *more* than this method's own 0.3 acceptance band. A step
    /// that size can start just outside the band and land past its far edge
    /// in one motion; the correction on the next iteration then overshoots
    /// back the same way, oscillating until the 25-step cap. `step(up:)`'s
    /// drag is also a flick (`press(forDuration:thenDragTo:)`), so its
    /// momentum — and how far the scroll view actually travels — varies run
    /// to run, which is exactly why an identical retry could clear it.
    /// `scrollStepFraction` now stays well under the band, and `step(up:)`
    /// settles before returning so this method's next read of
    /// `element.frame.minY` is not taken mid-deceleration.
    private func scrollTo(_ element: XCUIElement) {
        // Does not replace the loop below — a `LazyVStack`'s off-screen
        // content genuinely does not exist until scrolled near — but it
        // keeps an already-loaded target from burning a step or two of the
        // 25-step budget while the screen is still settling right after a
        // push.
        _ = element.waitForExistence(timeout: 3)
        let topBand = app.windows.firstMatch.frame.height * 0.3
        for _ in 0..<25 {
            if element.exists {
                let y = element.frame.minY
                if element.isHittable, y >= 0, y <= topBand {
                    return
                }
                step(up: y > topBand)
            } else {
                step(up: true)
            }
        }
        XCTFail("never framed \(element.debugDescription) near the top of the screen after twenty-five scroll steps")
    }

    /// Fraction of the window height one `step(up:)` drags by. Must stay
    /// under `scrollTo`'s 0.3 acceptance-band fraction with real margin, not
    /// just barely under it: `step(up:)`'s drag is a flick, so the distance
    /// the scroll view actually travels varies run to run, and a step that
    /// can reach the far edge of the band in one motion can also overshoot
    /// past it on an unlucky flick.
    private let scrollStepFraction: CGFloat = 0.12

    /// One scroll step, well under a third of a screen — small enough that
    /// `scrollTo` converges on its target instead of jumping past it.
    private func step(up: Bool) {
        let window = app.windows.firstMatch
        let half = scrollStepFraction / 2
        let start = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: up ? 0.5 + half : 0.5 - half))
        let end = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: up ? 0.5 - half : 0.5 + half))
        start.press(forDuration: 0.05, thenDragTo: end)
        // `press(forDuration:thenDragTo:)` is a flick: this call returns as
        // soon as the gesture is injected, not once the scroll view stops
        // moving, and momentum keeps it decelerating afterward. `scrollTo`
        // reads `element.frame.minY` right after calling this; without a
        // settle, that read can land mid-deceleration, so the direction
        // decision for the *next* step is made against a position the
        // scroll view has already left.
        Thread.sleep(forTimeInterval: 0.3)
    }

    private func openTab(_ name: String) {
        var button = tabButton(name)
        if !button.exists {
            let nextPage = app.buttons["Next Page"]
            if nextPage.waitForExistence(timeout: 5) {
                nextPage.tap()
                button = tabButton(name)
            }
        }
        XCTAssertTrue(button.waitForExistence(timeout: 10), "no way to reach the \(name) tab")
        button.tap()
    }

    /// `.firstMatch` because on iPad the floating tab bar renders each item as
    /// two nested elements sharing one label, and resolving that to exactly
    /// one match throws at tap time. Copied from ColdStartUITests, which
    /// learned it on a real iPad.
    private func tabButton(_ name: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label == %@", name)).firstMatch
    }

    /// Waits for the screen to be ready, then attaches the capture under a
    /// two-digit name that `capture.sh` maps straight to `NN.png`.
    private func capture(_ index: Int, of label: String, _ arrive: () -> Void) {
        arrive()
        // Let the last poster and any symbol effect settle. XCUITest returns
        // as soon as an element exists, which is earlier than "drawn".
        Thread.sleep(forTimeInterval: 2.0)
        let raw = XCUIScreen.main.screenshot().image
        // On iPad, after forcing `.landscapeLeft` via `XCUIDevice`, the app's
        // own window genuinely lays out landscape — the sidebar, tab bar and
        // status bar all confirm it — but `XCUIScreen.main.screenshot()`
        // still returns the simulator's raw framebuffer in its un-rotated
        // portrait shape (2064x2752), with the landscape interface drawn
        // rotated inside it. `app.screenshot()` was tried as an alternative
        // and is worse, not better: it reports the expected 2752x2064
        // dimensions, but silently crops to a 2064x2064 square and drops the
        // rest of the content — a defect `capture.sh`'s dimension check
        // would never catch. Rotating the raw, uncropped capture keeps every
        // pixel and fixes the shape in one step; confirmed against a real
        // capture that this direction, not the other, reads upright.
        //
        // The `app.screenshot()` attempt above is why dimensions alone are
        // not trusted to prove this rotation is still correct: that image
        // reported the right 2752x2064, and `capture.sh`'s only automated
        // check is exactly that — width and height — so it would have
        // shipped. Only opening the file and looking found the crop.
        // `assertNotPaddedBlank` below is that look, automated: it samples
        // the strip a crop-to-square bug would leave as solid padding and
        // fails if every sample there is blank, so a future regression that
        // is dimensionally correct but visually wrong — this rotation
        // silently breaking under a different Xcode or simulator runtime,
        // or someone "simplifying" it back to `app.screenshot()` — cannot
        // pass by matching width and height alone. Do not delete this
        // rotation because it looks like unnecessary machinery next to a
        // one-line `app.screenshot()` call; that one-line call is the
        // version already proven wrong.
        let image = UIDevice.current.userInterfaceIdiom == .pad
            ? raw.rotated90CounterClockwise()
            : raw
        if UIDevice.current.userInterfaceIdiom == .pad {
            assertNotPaddedBlank(image, context: "frame \(String(format: "%02d", index)) (\(label))")
        }
        let attachment = XCTAttachment(image: image)
        attachment.name = String(format: "%02d", index)
        attachment.lifetime = .keepAlways
        add(attachment)
        print("PLOTLINE_SHOT=\(String(format: "%02d", index)) \(label)")
    }

    /// Confirms the region a crop-to-square bug would leave blank actually
    /// has content, instead of trusting dimensions alone.
    ///
    /// `app.screenshot()` was tried in place of the rotation above and
    /// reported the correct 2752x2064 while silently cropping to a
    /// 2064x2064 square and padding the remaining ~700px with solid black —
    /// a defect `capture.sh`'s dimension check does not see, because it only
    /// reads width and height. This samples ten points spread across
    /// exactly the strip that crop would have padded (the region beyond the
    /// image's shorter side) and fails if all ten read near-black. Real UI
    /// content never does, even under the app's own dark theme: the darkest
    /// background here, `Color.plotlineBackground`'s `#121212`, is RGB
    /// (18, 18, 18) — above the near-black threshold below — while a
    /// zeroed, unpainted `CGContext` region is exactly (0, 0, 0). Ten
    /// samples, not one, so a single genuinely black pixel — a poster's
    /// shadow, a letterboxed edge — cannot fail this by chance.
    private func assertNotPaddedBlank(_ image: UIImage, context: String) {
        guard let cgImage = image.cgImage else {
            XCTFail("\(context): no cgImage to inspect for padding")
            return
        }
        let width = cgImage.width
        let height = cgImage.height
        guard width != height else { return } // nothing a square crop could pad
        let shorter = min(width, height)
        guard
            let data = cgImage.dataProvider?.data,
            let bytes = CFDataGetBytePtr(data)
        else {
            XCTFail("\(context): could not read pixel data to check for padding")
            return
        }
        let bytesPerRow = cgImage.bytesPerRow
        let bytesPerPixel = max(cgImage.bitsPerPixel / 8, 1)
        let length = CFDataGetLength(data)

        func isNearBlack(x: Int, y: Int) -> Bool {
            let offset = y * bytesPerRow + x * bytesPerPixel
            guard offset + 2 < length else { return true }
            return bytes[offset] < 10 && bytes[offset + 1] < 10 && bytes[offset + 2] < 10
        }

        var samples: [Bool] = []
        if width > height {
            let sampleX = shorter + (width - shorter) / 2
            for y in stride(from: 0, to: height, by: max(height / 10, 1)) {
                samples.append(isNearBlack(x: sampleX, y: y))
            }
        } else {
            let sampleY = shorter + (height - shorter) / 2
            for x in stride(from: 0, to: width, by: max(width / 10, 1)) {
                samples.append(isNearBlack(x: x, y: sampleY))
            }
        }
        XCTAssertFalse(
            samples.allSatisfy { $0 },
            """
            \(context): every sampled pixel in the region a crop-to-square \
            bug would pad reads near-black even though the dimensions are \
            correct. This looks like the app.screenshot() cropping \
            regression, not real content — do not trust this capture.
            """
        )
    }
}

private extension UIImage {
    /// Rotates the image 90° counterclockwise, swapping width and height.
    ///
    /// Works directly on `cgImage` in a plain bitmap `CGContext` rather than
    /// through `UIGraphicsImageRenderer`, deliberately: that renderer's
    /// context has UIKit's flipped, top-left-origin coordinate system, where
    /// a positive `rotate(by:)` angle turns out clockwise rather than
    /// counterclockwise — the first version of this method used it and
    /// rotated the wrong way. A raw `CGContext` here has the standard
    /// bottom-left-origin, Y-up system, where positive angles are
    /// counterclockwise, the same convention confirmed against a real
    /// capture using Python's `Image.rotate(90)`.
    func rotated90CounterClockwise() -> UIImage {
        guard let cgImage else { return self }
        let width = cgImage.width
        let height = cgImage.height
        let colorSpace = cgImage.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: height,
            height: width,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return self }
        // Derivation: rotating (x, y) by +90° gives (-y, x). The image
        // spans x∈[0,width], y∈[0,height], so before any translation the
        // rotated points span x'∈[-height,0], y'∈[0,width]. Translating by
        // (height, 0) before rotating shifts that into x'∈[0,height],
        // y'∈[0,width] — exactly the new (height × width) canvas.
        context.translateBy(x: CGFloat(height), y: 0)
        context.rotate(by: .pi / 2)
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let rotated = context.makeImage() else { return self }
        return UIImage(cgImage: rotated, scale: scale, orientation: .up)
    }
}
