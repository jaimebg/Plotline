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
    }

    func testCaptureAll() throws {
        capture(1, of: "discover") {
            XCTAssertTrue(
                app.descendants(matching: .any)
                    .matching(identifier: UITestAnchors.discoverShelf).firstMatch
                    .waitForExistence(timeout: 30),
                "Discover never drew a shelf, so there is nothing to photograph"
            )
        }
    }

    /// Waits for the screen to be ready, then attaches the capture under a
    /// two-digit name that `capture.sh` maps straight to `NN.png`.
    private func capture(_ index: Int, of label: String, _ arrive: () -> Void) {
        arrive()
        // Let the last poster and any symbol effect settle. XCUITest returns
        // as soon as an element exists, which is earlier than "drawn".
        Thread.sleep(forTimeInterval: 2.0)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = String(format: "%02d", index)
        attachment.lifetime = .keepAlways
        add(attachment)
        print("PLOTLINE_SHOT=\(String(format: "%02d", index)) \(label)")
    }
}
