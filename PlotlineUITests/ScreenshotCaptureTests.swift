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
/// Navigation goes through the identifiers in `UITestAnchors`, never through
/// coordinates. If a screen turns out to be unreachable by identifier, add the
/// anchor to `Plotline/Support/AccessibilityAnchors.swift` and its twin here —
/// do not tap a point.
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
            scrollTo(app.staticTexts["Streaming data provided by JustWatch"])
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
            XCTAssertTrue(
                app.staticTexts.containing(
                    NSPredicate(format: "label BEGINSWITH %@", "Falls off after season")
                ).firstMatch.exists,
                """
                The Walking Dead rendered no decline verdict, so frame 2's \
                headline would claim a fall the screenshot does not show. \
                Do not ship this capture; pick another series with a \
                declinePoint in PlotlineDataset.json.
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

    /// Swipes until the element is hittable, then stops. Ten swipes is well
    /// past the length of the detail screen; failing loudly beats a capture of
    /// whatever happened to be on screen.
    private func scrollTo(_ element: XCUIElement) {
        for _ in 0..<10 {
            if element.exists && element.isHittable { return }
            app.swipeUp()
        }
        XCTFail("never reached \(element.debugDescription) after ten swipes")
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
        let image = UIDevice.current.userInterfaceIdiom == .pad
            ? raw.rotated90CounterClockwise()
            : raw
        let attachment = XCTAttachment(image: image)
        attachment.name = String(format: "%02d", index)
        attachment.lifetime = .keepAlways
        add(attachment)
        print("PLOTLINE_SHOT=\(String(format: "%02d", index)) \(label)")
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
