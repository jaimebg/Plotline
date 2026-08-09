# App Store Screenshots Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce 16 App Store screenshots — 8 iPhone 6.9" portrait and 8 iPad 13" landscape — from a reproducible pipeline that captures real app screens by accessibility identifier and composes them in static HTML.

**Architecture:** Two halves joined by one orchestrator. An XCUITest navigates the app by the identifiers in `AccessibilityAnchors` and emits eight raw PNGs per device family via `XCTAttachment`; a host script extracts them from the `.xcresult`. Then a static HTML sheet lays all eight marketing frames out in one row, Chrome headless renders that row in a single pass, and a CoreGraphics script cuts it into eight files. Rendering the whole row at once is what makes the shared device scenes and the continuous curve line up: they are never separated, so they cannot drift.

**Tech Stack:** XCUITest (Swift), `xcrun simctl`, `xcrun xcresulttool`, Chrome headless, `swift` run as a script with CoreGraphics/ImageIO, bash, `python3` (stdlib only, for the attachment manifest).

## Global Constraints

- **Design spec:** `docs/superpowers/specs/2026-08-09-app-store-screenshots-design.md`. Every visual value below is copied from it; do not invent new ones.
- **Output sizes, exact:** iPhone 6.9" = **1320×2868** portrait. iPad 13" = **2752×2064** landscape. A file one pixel off is a failure, not a rounding.
- **Output location:** `screenshots/<MARKETING_VERSION>/iphone-69/01..08.png` and `screenshots/<MARKETING_VERSION>/ipad-13/01..08.png`. `MARKETING_VERSION` is read from the build system, never from a grep of `project.pbxproj` — that file carries six copies of the key, one per target/configuration.
- **Canvas:** linear gradient at 175°, `#0E0E12 → #17110B`. Identical on all 16.
- **Accent:** `#E8A33D`. Curve stroke uses it at 78% opacity; the fill gradient runs from 13% to 0%.
- **Bezels:** `#2A2A2E`.
- **Type:** headline `system-ui` weight 800, letter-spacing −0.025em, line-height 1.04. Evidence chip `ui-monospace` on `rgba(12,12,14,.6)` with a `rgba(232,163,61,.42)` border.
- **Shared scenes:** one device scene spans frames **1·2·3**, a second spans **6·7·8**. Frames 4 and 5 carry a single device.
- **App captures are dark mode.**
- **Copy rule, inherited from the app:** no headline or chip may claim more than the screenshot beneath it demonstrates. Chip numbers are transcribed from the captured screenshot, never authored from `PlotlineDataset.json` — the app recomputes live and the two can disagree.
- **No new runtime dependencies.** No Homebrew, no Node, no npm. `sips` cannot crop with an offset, which is why the slicer is Swift.
- **Do not modify `Plotline/`** except to add an accessibility identifier that a capture step proves is missing. Never navigate by screen coordinates.
- **Chrome flag warning:** `--default-background-color=0` aborts the render with `Expected a hex RGB or RGBA value`. The sheet paints its own background; the flag is not used.

---

## File Structure

**Create:**

| Path | Responsibility |
|---|---|
| `Scripts/screenshots/slice.swift` | Cut one sheet PNG into N equal-width frames. Nothing else. |
| `Scripts/screenshots/verify.swift` | Report a PNG's dimensions and the RGB hex at a sampled point. Used by tests and by the release check. |
| `Scripts/screenshots/tests/run-tests.sh` | The slicer's own test: render a fixture, cut it, assert every frame's colour. |
| `Scripts/screenshots/tests/slice-fixture.html` | Eight solid-colour frames with known values. |
| `PlotlineUITests/ScreenshotCaptureTests.swift` | Navigate to the eight screens and attach a screenshot of each. |
| `Scripts/screenshots/capture.sh` | Boot a device, pin its status bar and locale, run the capture suite, extract PNGs from the `.xcresult`. |
| `Scripts/screenshots/frame.css` | The visual system: canvas, curve, headline, chip, bezel, scene geometry. Shared by both sheets. |
| `Scripts/screenshots/curve.js` | Emit the shared curve path and per-frame SVG windows. One deterministic curve, no randomness at render time. |
| `Scripts/screenshots/iphone.html` | The eight iPhone frames in one row. |
| `Scripts/screenshots/ipad.html` | The eight iPad frames in one row, landscape, headline in a top band. |
| `Scripts/screenshots/render.sh` | Chrome → sheet PNG → slice → verify sizes. |
| `Scripts/screenshots/make.sh` | Orchestrator: capture then render, per family. |

**Modify:**

| Path | Change |
|---|---|
| `Scripts/release-preflight.sh` | Add step 9: the screenshot set for the current version exists at the right sizes. |
| `CLAUDE.md` | Document the command and the pipeline in Build Commands. |

**Delete (Task 7 only, never earlier):** `.asc/screenshots.json`, `screenshots/koubou.yaml`, `screenshots/framed/`, `screenshots/raw/*.png` (the eight loose files), `screenshots/*.png` (the six loose files), and the two loose PNGs inside `screenshots/1.4.0/`.

**`screenshots/<MARKETING_VERSION>/` is not deleted.** `MARKETING_VERSION` is `1.4.0` today, so `render.sh` writes into `screenshots/1.4.0/iphone-69/` and `screenshots/1.4.0/ipad-13/` — the same directory that holds the previous submission's two hand-made PNGs. Only those two files go; the directory stays and is where Tasks 4 and 5 put their output. Deleting the directory would destroy the work of the two tasks before it.

---

## Task 1: The slicer, and a test that can fail

Nothing else works if the cut is off by a pixel, and an off-by-one is invisible to the eye on a dark canvas. This task builds the cutter and a test that would catch it.

**Files:**
- Create: `Scripts/screenshots/slice.swift`
- Create: `Scripts/screenshots/verify.swift`
- Create: `Scripts/screenshots/tests/slice-fixture.html`
- Create: `Scripts/screenshots/tests/run-tests.sh`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `swift Scripts/screenshots/slice.swift <sheet.png> <frameWidth> <count> <outDir> <startIndex>` — writes `<outDir>/NN.png` for `NN` from `startIndex`, zero-padded to two digits. Exits 1 on any mismatch, 2 on bad arguments.
  - `swift Scripts/screenshots/verify.swift size <file.png>` — prints `WIDTHxHEIGHT`.
  - `swift Scripts/screenshots/verify.swift pixel <file.png> <x> <y>` — prints six uppercase hex digits, e.g. `E8A33D`.

- [ ] **Step 1: Write the failing test**

Create `Scripts/screenshots/tests/slice-fixture.html`. Eight frames, eight unmistakably different colours, at the real iPhone frame width so the test exercises the production geometry:

```html
<!doctype html>
<html><head><meta charset="utf-8"><style>
  html, body { margin: 0; padding: 0; }
  .sheet { display: flex; width: 10560px; height: 2868px; }
  .f { width: 1320px; height: 2868px; }
</style></head><body>
  <div class="sheet">
    <div class="f" style="background:#110000"></div>
    <div class="f" style="background:#220000"></div>
    <div class="f" style="background:#330000"></div>
    <div class="f" style="background:#440000"></div>
    <div class="f" style="background:#550000"></div>
    <div class="f" style="background:#660000"></div>
    <div class="f" style="background:#770000"></div>
    <div class="f" style="background:#880000"></div>
  </div>
</body></html>
```

Create `Scripts/screenshots/tests/run-tests.sh`:

```bash
#!/bin/bash
# The slicer's own test. Renders eight known colours, cuts them, and checks
# every frame — including its left and right edge, one pixel in. An off-by-one
# offset shifts a neighbour's colour into an edge, and nothing else here would
# see it.
set -uo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/../../.." && pwd)
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
WORK=$(mktemp -d -t plotline-slice-test)
trap 'rm -rf "$WORK"' EXIT

failures=0
fail() { printf '\033[31mFAIL\033[0m  %s\n' "$1"; failures=$((failures + 1)); }
pass() { printf '\033[32mok\033[0m    %s\n' "$1"; }

EXPECTED=(110000 220000 330000 440000 550000 660000 770000 880000)

"$CHROME" --headless --disable-gpu --hide-scrollbars \
    --force-device-scale-factor=1 \
    --screenshot="$WORK/sheet.png" --window-size=10560,2868 \
    "file://$HERE/slice-fixture.html" >/dev/null 2>&1

if [ ! -f "$WORK/sheet.png" ]; then
    fail "Chrome produced no sheet at 10560x2868"
    exit 1
fi

size=$(swift "$ROOT/Scripts/screenshots/verify.swift" size "$WORK/sheet.png")
if [ "$size" != "10560x2868" ]; then
    fail "sheet rendered $size, expected 10560x2868"
else
    pass "sheet rendered at 10560x2868"
fi

swift "$ROOT/Scripts/screenshots/slice.swift" "$WORK/sheet.png" 1320 8 "$WORK/out" 1 >/dev/null
if [ $? -ne 0 ]; then fail "slice.swift exited non-zero"; fi

for i in 1 2 3 4 5 6 7 8; do
    f=$(printf '%s/out/%02d.png' "$WORK" "$i")
    want=${EXPECTED[$((i - 1))]}

    if [ ! -f "$f" ]; then fail "frame $i missing"; continue; fi

    got_size=$(swift "$ROOT/Scripts/screenshots/verify.swift" size "$f")
    [ "$got_size" = "1320x2868" ] || fail "frame $i is $got_size, expected 1320x2868"

    # Left edge, centre and right edge. The edges are what catch an offset.
    for x in 1 660 1318; do
        got=$(swift "$ROOT/Scripts/screenshots/verify.swift" pixel "$f" "$x" 1400)
        if [ "$got" != "$want" ]; then
            fail "frame $i at x=$x is #$got, expected #$want — the cut is offset"
        fi
    done
done

[ "$failures" -eq 0 ] && pass "all eight frames cut exactly" 
printf '\n%s failure(s)\n' "$failures"
[ "$failures" -eq 0 ]
```

Make it executable: `chmod +x Scripts/screenshots/tests/run-tests.sh`

- [ ] **Step 2: Run it to verify it fails**

Run: `./Scripts/screenshots/tests/run-tests.sh`

Expected: FAIL. `slice.swift` and `verify.swift` do not exist, so `swift` reports the source file cannot be found and every frame check fails.

- [ ] **Step 3: Write `verify.swift`**

```swift
import CoreGraphics
import Foundation
import ImageIO

// verify.swift size <file.png>            -> "1320x2868"
// verify.swift pixel <file.png> <x> <y>   -> "E8A33D"
//
// Two jobs in one file on purpose: both read a PNG through ImageIO, and the
// release check and the slicer's test each need both.

func die(_ message: String) -> Never {
    FileHandle.standardError.write((message + "\n").data(using: .utf8)!)
    exit(2)
}

func loadImage(_ path: String) -> CGImage {
    guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        die("cannot read \(path) as an image")
    }
    return image
}

let args = CommandLine.arguments
guard args.count >= 3 else {
    die("usage: verify.swift size <file.png> | verify.swift pixel <file.png> <x> <y>")
}

switch args[1] {
case "size":
    let image = loadImage(args[2])
    print("\(image.width)x\(image.height)")

case "pixel":
    guard args.count == 5, let x = Int(args[3]), let y = Int(args[4]) else {
        die("usage: verify.swift pixel <file.png> <x> <y>")
    }
    let image = loadImage(args[2])
    guard x >= 0, y >= 0, x < image.width, y < image.height else {
        die("(\(x),\(y)) is outside \(image.width)x\(image.height)")
    }
    // Draw the single pixel into a known 8-bit RGBA context rather than
    // trusting the source's colour space, bit depth or alpha layout.
    var pixel = [UInt8](repeating: 0, count: 4)
    guard let context = CGContext(
        data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        die("cannot create a sampling context")
    }
    context.draw(image, in: CGRect(x: -x, y: -(image.height - 1 - y),
                                   width: image.width, height: image.height))
    print(String(format: "%02X%02X%02X", pixel[0], pixel[1], pixel[2]))

default:
    die("unknown command \(args[1])")
}
```

- [ ] **Step 4: Write `slice.swift`**

```swift
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// slice.swift <sheet.png> <frameWidth> <count> <outDir> <startIndex>
//
// Cuts one wide sheet into equal-width frames. The width check is the point:
// a sheet that came back short — a render that ran out of memory, a stylesheet
// that failed to load — would otherwise be cut into frames that are each the
// right size and all wrong.

func die(_ message: String, _ code: Int32) -> Never {
    FileHandle.standardError.write((message + "\n").data(using: .utf8)!)
    exit(code)
}

let args = CommandLine.arguments
guard args.count == 6,
      let frameWidth = Int(args[2]),
      let count = Int(args[3]),
      let startIndex = Int(args[5]) else {
    die("usage: slice.swift <sheet.png> <frameWidth> <count> <outDir> <startIndex>", 2)
}

guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: args[1]) as CFURL, nil),
      let sheet = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
    die("cannot read \(args[1]) as an image", 1)
}

guard sheet.width == frameWidth * count else {
    die("sheet is \(sheet.width)px wide; \(count) frames of \(frameWidth) need \(frameWidth * count)", 1)
}

let outDir = URL(fileURLWithPath: args[4])
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

for i in 0..<count {
    let rect = CGRect(x: i * frameWidth, y: 0, width: frameWidth, height: sheet.height)
    guard let frame = sheet.cropping(to: rect) else {
        die("cropping frame \(i + 1) failed", 1)
    }
    let url = outDir.appendingPathComponent(String(format: "%02d.png", startIndex + i))
    guard let destination = CGImageDestinationCreateWithURL(
        url as CFURL, UTType.png.identifier as CFString, 1, nil
    ) else {
        die("cannot write \(url.path)", 1)
    }
    CGImageDestinationAddImage(destination, frame, nil)
    guard CGImageDestinationFinalize(destination) else {
        die("finalising \(url.path) failed", 1)
    }
    print("\(url.lastPathComponent) \(frame.width)x\(frame.height)")
}
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `./Scripts/screenshots/tests/run-tests.sh`

Expected: every line `ok`, `0 failure(s)`, exit 0.

- [ ] **Step 6: Prove the test can fail**

Temporarily change `slice.swift` line `let rect = CGRect(x: i * frameWidth, ...)` to `x: i * frameWidth + 1`, then run the test again.

Expected: FAIL on the right edge of at least one frame — `frame N at x=1318 is #..., expected #... — the cut is offset`. Revert the change with `git checkout Scripts/screenshots/slice.swift` and re-run to confirm green.

A cutter whose test has not been seen failing is not evidence of anything. Do not skip this step.

- [ ] **Step 7: Commit**

```bash
git add Scripts/screenshots/slice.swift Scripts/screenshots/verify.swift Scripts/screenshots/tests
git commit -m "feat: cut a screenshot sheet into frames, with a test that catches an offset"
```

---

## Task 2: The capture pipeline, end to end, with one screen

Prove the whole capture path — skip guard, launch environment, attachment, extraction, renaming — on a single screenshot before writing seven more that all depend on it.

**Files:**
- Create: `PlotlineUITests/ScreenshotCaptureTests.swift`
- Create: `Scripts/screenshots/capture.sh`

**Interfaces:**
- Consumes: `Scripts/screenshots/verify.swift` from Task 1.
- Produces:
  - `Scripts/screenshots/capture.sh <family>` where `<family>` is `iphone-69` or `ipad-13`. Writes `screenshots/raw/<family>/NN.png`.
  - `ScreenshotCaptureTests.captureAll()` — one test method that walks every screen in order and attaches each as `NN`, zero-padded.

- [ ] **Step 1: Write the capture suite with one screen**

Create `PlotlineUITests/ScreenshotCaptureTests.swift`:

```swift
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
```

- [ ] **Step 2: Run it to verify it is skipped by default**

Run:

```bash
xcodebuild -project Plotline.xcodeproj -scheme Plotline \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -only-testing:PlotlineUITests/ScreenshotCaptureTests test 2>&1 | tail -20
```

Expected: the suite reports as **skipped**, not failed, and the run succeeds. This is the guard that keeps it out of the normal loop; confirm it before relying on it.

- [ ] **Step 3: Write `capture.sh`**

Create `Scripts/screenshots/capture.sh`:

```bash
#!/bin/bash
# Capture the raw app screens for one device family.
#
#   Scripts/screenshots/capture.sh iphone-69
#   Scripts/screenshots/capture.sh ipad-13
#
# Everything the capture depends on and the test cannot set itself is set
# here: which device, dark mode, and a status bar that does not read like a
# Tuesday afternoon in Spain.
set -uo pipefail

FAMILY=${1:-}
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
cd "$ROOT" || exit 1

case "$FAMILY" in
    iphone-69) DEVICE="iPhone 17 Pro Max"; EXPECT="1320x2868" ;;
    ipad-13)   DEVICE="iPad Pro 13-inch (M5)"; EXPECT="2752x2064" ;;
    *) echo "usage: $0 iphone-69|ipad-13" >&2; exit 2 ;;
esac

OUT="screenshots/raw/$FAMILY"
BUNDLE=$(mktemp -d -t plotline-shots)/result.xcresult
EXPORT=$(mktemp -d -t plotline-export)

echo "==> booting $DEVICE"
xcrun simctl boot "$DEVICE" 2>/dev/null
if ! xcrun simctl bootstatus "$DEVICE" -b >/dev/null 2>&1; then
    echo "could not boot $DEVICE" >&2; exit 1
fi

xcrun simctl ui "$DEVICE" appearance dark
xcrun simctl status_bar "$DEVICE" override \
    --time "9:41" --batteryState charged --batteryLevel 100 \
    --wifiBars 3 --cellularBars 4 --dataNetwork wifi

echo "==> capturing"
xcodebuild -project Plotline.xcodeproj -scheme Plotline \
    -destination "platform=iOS Simulator,name=$DEVICE" \
    -only-testing:PlotlineUITests/ScreenshotCaptureTests \
    -resultBundlePath "$BUNDLE" \
    TEST_RUNNER_PLOTLINE_SCREENSHOT_CAPTURE=1 \
    test > "$EXPORT/xcodebuild.log" 2>&1
status=$?
if [ $status -ne 0 ]; then
    echo "capture run failed; last 40 lines:" >&2
    tail -40 "$EXPORT/xcodebuild.log" >&2
    exit 1
fi

echo "==> extracting attachments"
xcrun xcresulttool export attachments \
    --path "$BUNDLE" --output-path "$EXPORT/attachments" >/dev/null || exit 1

rm -rf "$OUT" && mkdir -p "$OUT"
python3 - "$EXPORT/attachments" "$OUT" <<'PY'
import json, os, shutil, sys
src, dst = sys.argv[1], sys.argv[2]
manifest = json.load(open(os.path.join(src, "manifest.json")))
moved = 0
for test in manifest:
    for att in test.get("attachments", []):
        name = (att.get("suggestedHumanReadableName") or "").split(".")[0]
        if not (len(name) == 2 and name.isdigit()):
            continue
        shutil.copyfile(os.path.join(src, att["exportedFileName"]),
                        os.path.join(dst, name + ".png"))
        moved += 1
print(f"copied {moved} screenshot(s)")
PY

count=$(ls "$OUT"/*.png 2>/dev/null | wc -l | tr -d ' ')
echo "==> $count file(s) in $OUT"
for f in "$OUT"/*.png; do
    got=$(swift Scripts/screenshots/verify.swift size "$f")
    if [ "$got" != "$EXPECT" ]; then
        echo "$f is $got, expected $EXPECT" >&2; exit 1
    fi
done
echo "all captures are $EXPECT"
```

Make it executable: `chmod +x Scripts/screenshots/capture.sh`

- [ ] **Step 4: Run the capture and check one file comes out**

Run: `./Scripts/screenshots/capture.sh iphone-69`

Expected: `copied 1 screenshot(s)`, then `1 file(s) in screenshots/raw/iphone-69`, then `all captures are 1320x2868`.

Open `screenshots/raw/iphone-69/01.png` and look at it. The status bar must read **9:41** and the date must be in English. If it is not, the launch arguments did not arrive — fix that before continuing, because seven more screenshots will inherit it.

- [ ] **Step 5: Commit**

```bash
git add PlotlineUITests/ScreenshotCaptureTests.swift Scripts/screenshots/capture.sh
git commit -m "feat: capture app screens by accessibility identifier for the store listing"
```

---

## Task 3: The remaining seven screens

**Files:**
- Modify: `PlotlineUITests/ScreenshotCaptureTests.swift`
- Modify (only if a step proves an anchor missing): `Plotline/Support/AccessibilityAnchors.swift`, `PlotlineUITests/UITestAnchors.swift`

**Interfaces:**
- Consumes: `capture(_:of:_:)` and `app` from Task 2.
- Produces: eight PNGs per family in `screenshots/raw/<family>/`.

- [ ] **Step 1: Read what the screens actually are before writing navigation**

The UI moved during this plan's own design: `StandoutEpisodesView` was removed and the analysis section is now `PlotlineScoreCard` + `SeriesVerdictsView`, and the genre grid moved to open with search rather than sit above the feed. Do not write navigation from memory.

Run:

```bash
sed -n '1,120p' Plotline/Views/Discovery/DiscoveryView.swift
sed -n '1,60p' Plotline/Views/Detail/Analysis/SeriesAnalysisSection.swift
grep -n "accessibilityIdentifier" -r Plotline/Views | head -40
```

Write down, for each of the eight screens, which identifier or label reaches it. Where nothing does, add the anchor in **both** `AccessibilityAnchors.swift` and `UITestAnchors.swift` — the duplication is deliberate and documented in both files.

- [ ] **Step 2: Write the eight-screen walk**

Replace `testCaptureAll` in `PlotlineUITests/ScreenshotCaptureTests.swift`:

```swift
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

        capture(1, of: "plotline score") {
            XCTAssertTrue(
                app.staticTexts["Plotline Score"].waitForExistence(timeout: 30),
                "the Plotline Score card never appeared on the detail screen"
            )
        }
        capture(3, of: "season chart") {
            scrollTo(app.staticTexts["Episode Ratings"])
        }
        capture(4, of: "episode grid") {
            scrollTo(app.staticTexts["All Episodes"])
        }
        capture(6, of: "where to watch") {
            scrollTo(app.staticTexts["Streaming data provided by JustWatch"])
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
            let compare = app.descendants(matching: .any)
                .matching(identifier: UITestAnchors.statsCompare).firstMatch
            XCTAssertTrue(compare.waitForExistence(timeout: 20), "Compare never appeared in Stats")
            compare.tap()
        }
        capture(8, of: "trends") {
            app.navigationBars.buttons.element(boundBy: 0).tap()
            let trends = app.descendants(matching: .any)
                .matching(identifier: UITestAnchors.statsTrends).firstMatch
            XCTAssertTrue(trends.waitForExistence(timeout: 20), "Trends never appeared in Stats")
            trends.tap()
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
        field.tap()
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
        openTab("Discover")
        XCTAssertTrue(
            app.searchFields.firstMatch.waitForExistence(timeout: 20),
            "never got back to the Discover root"
        )
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
```

The section titles above (`"What the Numbers Say"`, `"Episode Ratings"`, `"All Episodes"`, `"Streaming data provided by JustWatch"`) are the strings the views draw today. Step 1 is where you confirm each one; correct any that have changed rather than leaving a wait that will time out.

- [ ] **Step 3: Run the capture and count**

Run: `./Scripts/screenshots/capture.sh iphone-69`

Expected: `copied 8 screenshot(s)`, `8 file(s)`, `all captures are 1320x2868`.

- [ ] **Step 4: Look at all eight**

Open every file in `screenshots/raw/iphone-69/`. Each must show the screen its number claims, fully drawn — no skeleton placeholders, no half-loaded posters, no scroll caught mid-flight. This is the step that no assertion above replaces.

Write down the real numbers visible in `01.png` (level, consistency, trajectory) and in `02.png` (the averages either side of the decline). Task 4 needs them for the evidence chips, and the spec forbids taking them from the dataset.

- [ ] **Step 5: Add landscape for iPad and capture that family**

Add to `setUpWithError()`, immediately before `app.launch()`:

```swift
        // iPad ships landscape screenshots. Setting this from inside the test
        // is the only reliable way: rotating the simulator through its Device
        // menu was tried three ways during design and the framebuffer stayed
        // portrait every time.
        if UIDevice.current.userInterfaceIdiom == .pad {
            XCUIDevice.shared.orientation = .landscapeLeft
        }
```

Add `import UIKit` at the top of the file.

Run: `./Scripts/screenshots/capture.sh ipad-13`

Expected: `copied 8 screenshot(s)` and `all captures are 2752x2064`. If any file comes back `2064x2752`, the rotation did not take before the capture — move the orientation line after `app.launch()` and add a two-second settle.

Look at all eight of these too.

- [ ] **Step 6: Commit**

```bash
git add PlotlineUITests/ScreenshotCaptureTests.swift Plotline/Support/AccessibilityAnchors.swift PlotlineUITests/UITestAnchors.swift
git commit -m "feat: capture all eight store screens on iPhone and iPad"
```

---

## Task 4: The visual system and the iPhone sheet

**Files:**
- Create: `Scripts/screenshots/frame.css`
- Create: `Scripts/screenshots/curve.js`
- Create: `Scripts/screenshots/iphone.html`
- Create: `Scripts/screenshots/render.sh`

**Interfaces:**
- Consumes: `screenshots/raw/iphone-69/01..08.png` from Task 3; `slice.swift` and `verify.swift` from Task 1.
- Produces:
  - `Scripts/screenshots/render.sh <family>` — renders the sheet, cuts it, checks every frame's size, and writes `screenshots/<MARKETING_VERSION>/<family>/NN.png`.
  - `curve.js` global `PlotlineCurve.svg(windowIndex, frameCount)` returning an SVG string for one frame's window on the shared curve.

- [ ] **Step 1: Write the curve**

Create `Scripts/screenshots/curve.js`:

```javascript
// One curve across the whole set. Each frame renders the same path and shows
// its own window through the SVG viewBox, so continuity is a property of the
// geometry rather than of eight numbers agreeing.
//
// The jitter is a fixed linear congruential sequence, not Math.random: the
// same sheet has to render the same way on every machine and every rerun.
(function (global) {
  var UNITS_PER_FRAME = 400;
  var HEIGHT = 867;

  function points(frameCount) {
    var width = UNITS_PER_FRAME * frameCount;
    var seed = 7;
    function rnd() {
      seed = (seed * 1103515245 + 12345) % 2147483648;
      return seed / 2147483648;
    }
    var pts = [];
    for (var x = -40; x <= width + 40; x += 40) {
      var t = x / width;
      var arc = 600 - 300 * Math.sin(Math.PI * Math.pow(t, 0.85)) + 70 * Math.sin(t * 7.5);
      pts.push([x, arc + (rnd() - 0.5) * 70]);
    }
    return pts;
  }

  function path(pts, close, frameCount) {
    var width = UNITS_PER_FRAME * frameCount;
    var d = 'M' + pts[0][0] + ',' + pts[0][1].toFixed(1);
    for (var i = 1; i < pts.length; i++) {
      var a = pts[i - 1], b = pts[i], mx = (a[0] + b[0]) / 2;
      d += ' C' + mx + ',' + a[1].toFixed(1) + ' ' + mx + ',' + b[1].toFixed(1) +
           ' ' + b[0] + ',' + b[1].toFixed(1);
    }
    if (close) d += ' L' + (width + 40) + ',' + (HEIGHT + 40) + ' L-40,' + (HEIGHT + 40) + ' Z';
    return d;
  }

  var counter = 0;

  global.PlotlineCurve = {
    /// `viewTop`/`viewHeight` let the iPad sheet crop the curve vertically
    /// without changing where it runs horizontally.
    svg: function (windowIndex, frameCount, viewTop, viewHeight) {
      var pts = points(frameCount);
      var line = path(pts, false, frameCount);
      var fill = path(pts, true, frameCount);
      var id = 'plc' + (counter++);
      var top = viewTop === undefined ? 0 : viewTop;
      var height = viewHeight === undefined ? HEIGHT : viewHeight;
      return '<svg class="curve" preserveAspectRatio="none" viewBox="' +
        (windowIndex * UNITS_PER_FRAME) + ' ' + top + ' ' + UNITS_PER_FRAME + ' ' + height + '">' +
        '<defs><linearGradient id="' + id + '" x1="0" y1="0" x2="0" y2="1">' +
        '<stop offset="0%" stop-color="#E8A33D" stop-opacity=".13"/>' +
        '<stop offset="100%" stop-color="#E8A33D" stop-opacity="0"/>' +
        '</linearGradient></defs>' +
        '<path d="' + fill + '" fill="url(#' + id + ')"/>' +
        '<path d="' + line + '" fill="none" stroke="#E8A33D" stroke-opacity=".78" ' +
        'stroke-width="3.2" stroke-linecap="round"/></svg>';
    }
  };
})(window);
```

- [ ] **Step 2: Write the shared stylesheet**

Create `Scripts/screenshots/frame.css`:

```css
/* The visual system, shared by both sheets. Every value here is from
   docs/superpowers/specs/2026-08-09-app-store-screenshots-design.md §3. */

html, body { margin: 0; padding: 0; background: #0E0E12; }

.sheet { display: flex; }

.frame {
  position: relative;
  overflow: hidden;
  container-type: inline-size;
  background: linear-gradient(175deg, #0E0E12 0%, #17110B 100%);
  flex: 0 0 auto;
}

.curve { position: absolute; top: 0; left: 0; width: 100%; height: 100%; }

/* A scene three frames wide, slid left by whole frames. Each frame shows its
   own window; the devices are never cut apart, so they cannot misalign. */
.stage {
  position: absolute; top: 0; left: 0; height: 100%;
  width: 300cqw;
  transform: translateX(calc(var(--window) * -100cqw));
}

.device {
  position: absolute;
  background: #2A2A2E;
  overflow: hidden;
  box-shadow: 0 3cqw 7cqw rgba(0, 0, 0, .72);
}
.device img { display: block; width: 100%; height: 100%; object-fit: cover; }

.phone { border-radius: 9% / 4.1%; padding: 1.1%; }
.phone img { border-radius: 8% / 3.6%; object-position: top center; }

.tablet { border-radius: 3.4% / 2.6%; padding: .8%; }
.tablet img { border-radius: 3% / 2.2%; object-position: top center; }

.headline {
  position: absolute; z-index: 5;
  color: #fff;
  font-family: system-ui, -apple-system, sans-serif;
  font-weight: 800;
  letter-spacing: -.025em;
  line-height: 1.04;
  text-shadow: 0 2px 20px rgba(0, 0, 0, .55);
}
.headline em { font-style: normal; color: #E8A33D; }

.chip {
  position: absolute; z-index: 5;
  font-family: ui-monospace, "SF Mono", Menlo, monospace;
  color: rgba(255, 255, 255, .85);
  background: rgba(12, 12, 14, .6);
  border: 1px solid rgba(232, 163, 61, .42);
  border-radius: 99px;
  white-space: nowrap;
}
.chip b { color: #E8A33D; font-weight: 600; }

/* Rendered off-canvas and measured by render.sh. If the headline face fell
   back to a substitute, this element's width changes and the render is
   rejected — a sheet in the wrong font looks perfectly plausible otherwise. */
#font-probe {
  position: absolute; left: -9999px; top: 0;
  font-family: system-ui, -apple-system, sans-serif;
  font-weight: 800; font-size: 200px; letter-spacing: -.025em;
  white-space: nowrap;
}
```

- [ ] **Step 3: Write the iPhone sheet**

Create `Scripts/screenshots/iphone.html`. Replace the two chip strings marked below with the numbers you wrote down in Task 3 Step 4 — they must match the captures, not the dataset.

```html
<!doctype html>
<html><head><meta charset="utf-8">
<link rel="stylesheet" href="frame.css">
<style>
  .frame { width: 1320px; height: 2868px; }
  .sheet { width: 10560px; height: 2868px; }
  .headline { left: 7%; right: 7%; top: 5.5%; font-size: 7.4cqw; }
  .headline.centred { text-align: center; }
  .chip { left: 7%; top: 21%; font-size: 3.1cqw; padding: 1.1cqw 2.6cqw; }
  .chip.centred { left: 50%; transform: translateX(-50%); }
</style></head><body>
<div class="sheet" id="sheet"></div>
<div id="font-probe">Plotline</div>
<script src="curve.js"></script>
<script>
// Chip text is transcribed from the capture beneath it. See the spec's copy
// rule: the app recomputes live, so the dataset is not a source for these.
var FRAMES = [
  { head: 'A 0–100 score,<br>and the <em>arithmetic</em><br>behind it',
    chip: 'LEVEL <b>86</b> · CONSISTENCY <b>54</b> · TRAJECTORY <b>65</b>' },
  { head: 'It tells you where<br>a series <em>falls off</em>',
    chip: 'BEFORE <b>8.4</b> → AFTER <b>8.0</b>' },
  { head: 'Every episode,<br>every season,<br><em>plotted</em>', chip: null },
  { head: 'Every rated episode,<br><em>at a glance</em>', chip: null, centred: true },
  { head: 'Shelves you won\'t<br>find <em>anywhere else</em>',
    chip: '122 SERIES · SHIPPED INSIDE THE APP', centred: true },
  { head: 'Where to watch it,<br><em>in your region</em>', chip: null },
  { head: 'Any two titles,<br><em>side by side</em>', chip: null },
  { head: 'Genres and decades,<br><em>charted</em>', chip: null }
];

// Two shared scenes. Offsets are cqw — percentages of ONE frame's width —
// across a stage three frames wide. Scene A spans frames 1·2·3, scene B
// spans 6·7·8; frames 4 and 5 carry a single upright device.
var SCENE_A = [
  { left: 2,   top: 34, width: 62, rotate: -9 },
  { left: 74,  top: 27, width: 74, rotate: 4 },
  { left: 158, top: 36, width: 66, rotate: -13 },
  { left: 232, top: 30, width: 70, rotate: 7 }
];
var SCENE_B = [
  { left: -8,  top: 31, width: 70, rotate: 11 },
  { left: 66,  top: 38, width: 60, rotate: -6 },
  { left: 132, top: 28, width: 76, rotate: 3 },
  { left: 222, top: 35, width: 64, rotate: -10 }
];
// Which raw capture each device in a scene shows, in scene order.
var SCENE_A_SHOTS = ['01', '02', '03', '01'];
var SCENE_B_SHOTS = ['06', '07', '08', '06'];

function device(shot, d) {
  return '<div class="device phone" style="left:' + d.left + 'cqw;top:' + d.top +
    '%;width:' + d.width + 'cqw;aspect-ratio:1320/2400;transform:rotate(' + d.rotate + 'deg)">' +
    '<img src="../../screenshots/raw/iphone-69/' + shot + '.png" alt=""></div>';
}

function stage(scene, shots, windowIndex) {
  var html = '<div class="stage" style="--window:' + windowIndex + '">';
  for (var i = 0; i < scene.length; i++) html += device(shots[i], scene[i]);
  return html + '</div>';
}

var out = '';
for (var i = 0; i < 8; i++) {
  var f = FRAMES[i];
  out += '<div class="frame">' + PlotlineCurve.svg(i, 8);
  if (i < 3) {
    out += stage(SCENE_A, SCENE_A_SHOTS, i);
  } else if (i >= 5) {
    out += stage(SCENE_B, SCENE_B_SHOTS, i - 5);
  } else {
    out += '<div class="device phone" style="left:50%;top:30%;width:70cqw;' +
           'aspect-ratio:1320/2400;transform:translateX(-50%)">' +
           '<img src="../../screenshots/raw/iphone-69/0' + (i + 1) + '.png" alt=""></div>';
  }
  out += '<div class="headline' + (f.centred ? ' centred' : '') + '">' + f.head + '</div>';
  if (f.chip) out += '<div class="chip' + (f.centred ? ' centred' : '') + '">' + f.chip + '</div>';
  out += '</div>';
}
document.getElementById('sheet').innerHTML = out;
document.title = 'ready:' + document.getElementById('font-probe').getBoundingClientRect().width.toFixed(1);
</script></body></html>
```

- [ ] **Step 4: Write `render.sh`**

Create `Scripts/screenshots/render.sh`:

```bash
#!/bin/bash
# Render one family's sheet in a single pass and cut it into eight files.
#
#   Scripts/screenshots/render.sh iphone-69
#   Scripts/screenshots/render.sh ipad-13
#
# One pass per family on purpose: the shared device scenes and the curve run
# across frame boundaries, and a sheet that is never separated cannot drift.
# 10560x2868 and 22016x2064 were both measured to render whole.
set -uo pipefail

FAMILY=${1:-}
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
cd "$ROOT" || exit 1
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

case "$FAMILY" in
    iphone-69) SHEET="iphone.html"; W=1320; H=2868 ;;
    ipad-13)   SHEET="ipad.html";   W=2752; H=2064 ;;
    *) echo "usage: $0 iphone-69|ipad-13" >&2; exit 2 ;;
esac
COUNT=8
SHEET_W=$((W * COUNT))

VERSION=$(xcodebuild -project Plotline.xcodeproj -target Plotline -configuration Release \
    -showBuildSettings 2>/dev/null | awk '/ MARKETING_VERSION = /{print $3; exit}')
if [ -z "$VERSION" ]; then
    echo "MARKETING_VERSION could not be read from the Plotline target, Release configuration" >&2
    exit 1
fi

for i in 01 02 03 04 05 06 07 08; do
    if [ ! -f "screenshots/raw/$FAMILY/$i.png" ]; then
        echo "screenshots/raw/$FAMILY/$i.png is missing — run capture.sh $FAMILY first" >&2
        exit 1
    fi
done

WORK=$(mktemp -d -t plotline-render)
trap 'rm -rf "$WORK"' EXIT

echo "==> rendering $SHEET at ${SHEET_W}x${H}"
"$CHROME" --headless --disable-gpu --hide-scrollbars \
    --force-device-scale-factor=1 \
    --virtual-time-budget=10000 \
    --screenshot="$WORK/sheet.png" --window-size="$SHEET_W,$H" \
    "file://$ROOT/Scripts/screenshots/$SHEET" >/dev/null 2>&1

if [ ! -f "$WORK/sheet.png" ]; then
    echo "Chrome produced no sheet" >&2; exit 1
fi
got=$(swift Scripts/screenshots/verify.swift size "$WORK/sheet.png")
if [ "$got" != "${SHEET_W}x${H}" ]; then
    echo "sheet is $got, expected ${SHEET_W}x${H}" >&2; exit 1
fi

OUT="screenshots/$VERSION/$FAMILY"
rm -rf "$OUT"
swift Scripts/screenshots/slice.swift "$WORK/sheet.png" "$W" "$COUNT" "$OUT" 1 || exit 1

for f in "$OUT"/*.png; do
    got=$(swift Scripts/screenshots/verify.swift size "$f")
    if [ "$got" != "${W}x${H}" ]; then
        echo "$f is $got, expected ${W}x${H}" >&2; exit 1
    fi
done
n=$(ls "$OUT"/*.png | wc -l | tr -d ' ')
if [ "$n" -ne "$COUNT" ]; then echo "$n file(s) in $OUT, expected $COUNT" >&2; exit 1; fi

echo "==> $n frames at ${W}x${H} in $OUT"
```

Make it executable: `chmod +x Scripts/screenshots/render.sh`

- [ ] **Step 5: Render and check the sizes**

Run: `./Scripts/screenshots/render.sh iphone-69`

Expected: `8 frames at 1320x2868 in screenshots/<version>/iphone-69`.

- [ ] **Step 6: Prove the size check can fail**

Temporarily change `--window-size="$SHEET_W,$H"` to `--window-size="$((SHEET_W - 100)),$H"` and re-run.

Expected: `sheet is 10460x2868, expected 10560x2868`, exit 1. Revert with `git checkout Scripts/screenshots/render.sh` — or undo the edit if not yet committed — and re-run to confirm green.

- [ ] **Step 7: Look at all eight**

Open `screenshots/<version>/iphone-69/01.png` through `08.png`.

Check, in this order: the curve continues across every boundary without a step; the devices in frames 1·2·3 are one scene and the same in 6·7·8; no headline overlaps a device edge; every chip number matches the screenshot underneath it; nothing is cut off at a frame edge that should not be.

- [ ] **Step 8: Commit**

```bash
git add Scripts/screenshots/frame.css Scripts/screenshots/curve.js Scripts/screenshots/iphone.html Scripts/screenshots/render.sh
git commit -m "feat: compose the iPhone store screenshots from one panoramic sheet"
```

---

## Task 5: The iPad sheet

**Files:**
- Create: `Scripts/screenshots/ipad.html`

**Interfaces:**
- Consumes: `frame.css`, `curve.js`, `render.sh` from Task 4; `screenshots/raw/ipad-13/01..08.png` from Task 3.
- Produces: `screenshots/<MARKETING_VERSION>/ipad-13/01..08.png`.

- [ ] **Step 1: Write the iPad sheet**

Create `Scripts/screenshots/ipad.html`. Same system, landscape canvas, headline in a full-width top band — the two alternatives were tried during design and rejected: a left column breaks the headline into too many lines, and overlaying it on the scene depends on there being dark pixels underneath, which stops being true as soon as a capture has a bright poster there.

```html
<!doctype html>
<html><head><meta charset="utf-8">
<link rel="stylesheet" href="frame.css">
<style>
  .frame { width: 2752px; height: 2064px; }
  .sheet { width: 22016px; height: 2064px; }
  /* Top band: full width, centred, with the devices entering beneath it. */
  .headline { left: 5%; right: 5%; top: 6%; font-size: 5.4cqw; text-align: center; }
  .chip { left: 50%; transform: translateX(-50%); top: 29%; font-size: 2.2cqw; padding: .9cqw 2cqw; }
</style></head><body>
<div class="sheet" id="sheet"></div>
<div id="font-probe">Plotline</div>
<script src="curve.js"></script>
<script>
var FRAMES = [
  { head: 'A 0–100 score,<br>and the <em>arithmetic</em> behind it',
    chip: 'LEVEL <b>86</b> · CONSISTENCY <b>54</b> · TRAJECTORY <b>65</b>' },
  { head: 'It tells you where a series <em>falls off</em>',
    chip: 'BEFORE <b>8.4</b> → AFTER <b>8.0</b>' },
  { head: 'Every episode, every season, <em>plotted</em>', chip: null },
  { head: 'Every rated episode, <em>at a glance</em>', chip: null },
  { head: 'Shelves you won\'t find <em>anywhere else</em>',
    chip: '122 SERIES · SHIPPED INSIDE THE APP' },
  { head: 'Where to watch it, <em>in your region</em>', chip: null },
  { head: 'Any two titles, <em>side by side</em>', chip: null },
  { head: 'Genres and decades, <em>charted</em>', chip: null }
];

// Landscape tablets are wide, so the scenes sit lower and overlap less than
// the phone ones; the top band needs the room.
var SCENE_A = [
  { left: -4,  top: 44, width: 52, rotate: -6 },
  { left: 52,  top: 38, width: 60, rotate: 3 },
  { left: 118, top: 46, width: 54, rotate: -9 },
  { left: 180, top: 40, width: 58, rotate: 5 },
  { left: 246, top: 45, width: 52, rotate: -4 }
];
var SCENE_B = [
  { left: -6,  top: 41, width: 56, rotate: 7 },
  { left: 54,  top: 47, width: 50, rotate: -5 },
  { left: 112, top: 39, width: 60, rotate: 2 },
  { left: 178, top: 45, width: 54, rotate: -8 },
  { left: 240, top: 42, width: 56, rotate: 4 }
];
var SCENE_A_SHOTS = ['01', '02', '03', '01', '02'];
var SCENE_B_SHOTS = ['06', '07', '08', '06', '07'];

function device(shot, d) {
  return '<div class="device tablet" style="left:' + d.left + 'cqw;top:' + d.top +
    '%;width:' + d.width + 'cqw;aspect-ratio:2752/1900;transform:rotate(' + d.rotate + 'deg)">' +
    '<img src="../../screenshots/raw/ipad-13/' + shot + '.png" alt=""></div>';
}

function stage(scene, shots, windowIndex) {
  var html = '<div class="stage" style="--window:' + windowIndex + '">';
  for (var i = 0; i < scene.length; i++) html += device(shots[i], scene[i]);
  return html + '</div>';
}

var out = '';
for (var i = 0; i < 8; i++) {
  var f = FRAMES[i];
  // The curve is windowed vertically too: on a 4:3 canvas the full 867-unit
  // height would push it under the devices entirely.
  out += '<div class="frame">' + PlotlineCurve.svg(i, 8, 200, 500);
  if (i < 3) {
    out += stage(SCENE_A, SCENE_A_SHOTS, i);
  } else if (i >= 5) {
    out += stage(SCENE_B, SCENE_B_SHOTS, i - 5);
  } else {
    out += '<div class="device tablet" style="left:50%;top:36%;width:74cqw;' +
           'aspect-ratio:2752/1900;transform:translateX(-50%)">' +
           '<img src="../../screenshots/raw/ipad-13/0' + (i + 1) + '.png" alt=""></div>';
  }
  out += '<div class="headline">' + f.head + '</div>';
  if (f.chip) out += '<div class="chip">' + f.chip + '</div>';
  out += '</div>';
}
document.getElementById('sheet').innerHTML = out;
document.title = 'ready:' + document.getElementById('font-probe').getBoundingClientRect().width.toFixed(1);
</script></body></html>
```

Replace the chip numbers with the ones read off the iPad captures in Task 3 Step 5, exactly as on iPhone.

- [ ] **Step 2: Render**

Run: `./Scripts/screenshots/render.sh ipad-13`

Expected: `8 frames at 2752x2064 in screenshots/<version>/ipad-13`.

If Chrome returns no file or a short sheet at 22016 px, fall back to two half-sheets as the spec describes: copy `ipad.html` to `ipad-a.html` and `ipad-b.html`, render frames 1-4 and 5-8 separately with `--window-size=11008,2064`, and slice each with `startIndex` 1 and 5. The boundary falls between frames 4 and 5, where no scene is shared, so nothing else changes. Record in the commit message that the single pass failed on this machine.

- [ ] **Step 3: Look at all eight**

Open every file. Same checks as Task 4 Step 7, plus one specific to landscape: the top band must not collide with the tallest device in any frame, and the headline must be one or two lines everywhere — three means the band is too narrow for that string and the string gets shortened, not the band.

- [ ] **Step 4: Commit**

```bash
git add Scripts/screenshots/ipad.html
git commit -m "feat: compose the iPad store screenshots in landscape"
```

---

## Task 6: The orchestrator and the font check

A sheet that fell back to a substitute font renders perfectly plausibly and is wrong. Nothing so far would notice.

**Files:**
- Create: `Scripts/screenshots/make.sh`
- Modify: `Scripts/screenshots/render.sh`

**Interfaces:**
- Consumes: `capture.sh`, `render.sh`.
- Produces: `Scripts/screenshots/make.sh [iphone-69|ipad-13]` — with no argument, both families end to end.

- [ ] **Step 1: Measure the expected probe width**

Both sheets set `document.title` to `ready:<width>`, the rendered width of `Plotline` at 200px in the headline face. Read the real value:

```bash
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless --disable-gpu \
  --dump-dom "file://$PWD/Scripts/screenshots/iphone.html" 2>/dev/null | grep -o 'ready:[0-9.]*' | head -1
```

Write the number down. It is machine-independent for a given font, and that is the point: if the face changes, it moves.

- [ ] **Step 2: Add the font check to `render.sh`**

Insert immediately after the `if [ ! -f "$WORK/sheet.png" ]` block. Substitute the number you measured in Step 1 for `<probe-width>` — it cannot be written here because it is a property of the font as installed, which is exactly what the check exists to detect:

```bash
# A missing headline face falls back to something plausible and the sheet
# still looks fine, so the size checks below would all pass on a wrong render.
# The sheet measures a known string and puts the width in its title; if that
# moved, the font is not the one the design specifies.
EXPECTED_PROBE=<probe-width>
probe=$("$CHROME" --headless --disable-gpu --dump-dom \
    "file://$ROOT/Scripts/screenshots/$SHEET" 2>/dev/null |
    grep -o 'ready:[0-9.]*' | head -1 | cut -d: -f2)
if [ -z "$probe" ]; then
    echo "the sheet did not report a font probe width" >&2; exit 1
fi
delta=$(awk -v a="$probe" -v b="$EXPECTED_PROBE" 'BEGIN{d=a-b; print (d<0?-d:d)}')
if awk -v d="$delta" 'BEGIN{exit !(d > 2)}'; then
    echo "headline font probe is ${probe}px, expected ~${EXPECTED_PROBE}px — the face fell back" >&2
    exit 1
fi
```

- [ ] **Step 3: Prove the font check can fail**

In `frame.css`, temporarily change the `.headline` and `#font-probe` `font-family` to `"NoSuchFace", monospace`, then run `./Scripts/screenshots/render.sh iphone-69`.

Expected: `headline font probe is ...px, expected ~...px — the face fell back`, exit 1. Revert with `git checkout Scripts/screenshots/frame.css` and re-run to confirm green.

- [ ] **Step 4: Write `make.sh`**

```bash
#!/bin/bash
# Everything, end to end.
#
#   Scripts/screenshots/make.sh              both families
#   Scripts/screenshots/make.sh iphone-69    one family
#
# Capture needs a simulator, a working TMDB key in Plotline/Secrets.plist and
# several minutes. Render needs neither and takes seconds, so iterate on the
# design by running render.sh alone.
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)

families=${1:-}
if [ -z "$families" ]; then families="iphone-69 ipad-13"; fi

for family in $families; do
    printf '\n\033[1m=== %s ===\033[0m\n' "$family"
    "$HERE/capture.sh" "$family" || exit 1
    "$HERE/render.sh" "$family" || exit 1
done

printf '\n\033[32mDone.\033[0m Look at every file before uploading — nothing above checks that a\n'
printf 'headline promises only what its screenshot shows.\n'
```

Make it executable: `chmod +x Scripts/screenshots/make.sh`

- [ ] **Step 5: Run the whole thing**

Run: `./Scripts/screenshots/make.sh`

Expected: both families capture and render; 16 files under `screenshots/<version>/`.

- [ ] **Step 6: Commit**

```bash
git add Scripts/screenshots/make.sh Scripts/screenshots/render.sh
git commit -m "feat: run the whole screenshot pipeline, and reject a sheet in the wrong font"
```

---

## Task 7: Retire the old pipeline and document the new one

**Files:**
- Delete: `.asc/screenshots.json`, `screenshots/koubou.yaml`, `screenshots/framed/`, the eight loose PNGs in `screenshots/raw/`, the six loose PNGs in `screenshots/`, and the two loose PNGs inside `screenshots/1.4.0/`
- Modify: `CLAUDE.md`
- Modify: `Scripts/release-preflight.sh`

**Interfaces:**
- Consumes: everything above.
- Produces: nothing new.

- [ ] **Step 1: Delete the old pipeline**

```bash
git rm -r .asc/screenshots.json screenshots/koubou.yaml screenshots/framed
git rm screenshots/raw/0*.png
git rm screenshots/1.4.0/iphone-69-analysis.png screenshots/1.4.0/ipad-13-analysis.png
git rm screenshots/discover.png screenshots/detail.png screenshots/detail-scroll.png \
       screenshots/favorites.png screenshots/genres.png screenshots/watchlist.png
```

**Do not `git rm -r screenshots/1.4.0`.** `MARKETING_VERSION` is `1.4.0`, so that directory is where Tasks 4 and 5 wrote the sixteen new screenshots. Only the two hand-made PNGs at its top level go.

Confirm nothing references them: `grep -rn "koubou\|screenshots.json\|screenshots/framed" --include=* . | grep -v "^./docs/superpowers"`

Expected: no hits outside `docs/superpowers/`, where the spec and this plan describe the removal on purpose. If `.asc/` is now empty, remove it too.

- [ ] **Step 2: Add the preflight step**

`Scripts/release-preflight.sh` already defines `step()`, `fail()`, `pass()` and `failures` at lines 18-21; the block below uses them as the other seven steps do.

Insert it immediately before `step "8/8  What still has to be done by hand"` at line 247, then renumber every label — lines 79, 90, 124, 131, 161, 181, 188 become `N/9`, and line 247's becomes `9/9`:

```bash
step "8/9  The screenshot set for this version"
shot_version=$(xcodebuild -project Plotline.xcodeproj -target Plotline -configuration Release \
    -showBuildSettings 2>/dev/null | awk '/ MARKETING_VERSION = /{print $3; exit}')
shot_ok=1
for family in "iphone-69:1320x2868" "ipad-13:2752x2064"; do
    dir="screenshots/$shot_version/${family%%:*}"
    want=${family##*:}
    n=$(ls "$dir"/*.png 2>/dev/null | wc -l | tr -d ' ')
    if [ "$n" -ne 8 ]; then
        fail "$dir has $n screenshot(s), expected 8 — run Scripts/screenshots/make.sh"
        shot_ok=0
        continue
    fi
    for f in "$dir"/*.png; do
        got=$(swift Scripts/screenshots/verify.swift size "$f")
        if [ "$got" != "$want" ]; then
            fail "$f is $got, expected $want"
            shot_ok=0
        fi
    done
done
if [ "$shot_ok" -eq 1 ]; then
    pass "16 screenshots for $shot_version at their required sizes"
fi
```

- [ ] **Step 3: Run the preflight step and prove it can fail**

Run: `./Scripts/release-preflight.sh` and confirm step 8/9 passes.

Then move one file aside — `mv screenshots/<version>/ipad-13/08.png /tmp/` — and run it again.

Expected: `screenshots/<version>/ipad-13 has 7 screenshot(s), expected 8 — run Scripts/screenshots/make.sh`, and the run reports a failure. Move the file back and confirm green.

- [ ] **Step 4: Document it in `CLAUDE.md`**

In the Build Commands block, immediately after the `./Scripts/release-preflight.sh` entry, add:

````markdown
# App Store screenshots — 8 iPhone 6.9" and 8 iPad 13", captured and composed
./Scripts/screenshots/make.sh

# Just recompose from the captures already on disk (seconds, no simulator)
./Scripts/screenshots/render.sh iphone-69
````

And add a short section after "The Bundled Dataset":

````markdown
### App Store Screenshots

`Scripts/screenshots/` produces the store listing images. Two halves:
`capture.sh` drives the app through `ScreenshotCaptureTests`, navigating by the
identifiers in `AccessibilityAnchors` and never by coordinates, and writes eight
raw PNGs per device family. `render.sh` lays all eight marketing frames out in a
single HTML row, renders it in one Chrome pass, and cuts it up.

**The single pass is the design, not an optimisation.** Device scenes and the
rating curve run across frame boundaries; a sheet that is never separated cannot
drift. Both widths — 10560×2868 and 22016×2064 — were measured to render whole.

Chip text is transcribed from the capture beneath it, never from
`PlotlineDataset.json`: the app recomputes analysis live when fresher episodes
arrive, so the two can legitimately disagree, and a marketing chip that
contradicts the screenshot next to it is the same defect as a verdict string
claiming more than its predicate.
````

- [ ] **Step 5: Run everything that has to be true**

```bash
./Scripts/screenshots/tests/run-tests.sh
xcodebuild -project Plotline.xcodeproj -scheme Plotline \
  -destination 'platform=iOS Simulator,name=iPhone 17' test 2>&1 | tail -5
```

Expected: the slicer's tests pass; the app suite is green and `ScreenshotCaptureTests` reports as skipped, not run.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "chore: retire the coordinate-tap screenshot pipeline"
```

---

## Self-Review

**Spec coverage.** §1 (why they are redone) → Task 7 removes the old set. §2 (16 files, exact sizes) → Tasks 4, 5 and the checks in `render.sh`. §3 (visual system) → Task 4 Steps 1-2, with iPad's top band in Task 5. §4 (the eight screens, copy rule, chip transcription) → Task 3 Steps 4-5 and the comments in both sheets. §5 (XCUITest, skip guard, orientation, status bar, locale, extraction) → Tasks 2 and 3. §6 (static HTML, one pass, slicer, no dependencies) → Tasks 1 and 4, with the half-sheet fallback in Task 5 Step 2. §7 (dimensions, count, font, looking) → Task 1 Step 6, Task 4 Steps 5-7, Task 6 Steps 2-3, Task 7 Step 2. §8 (deletions) → Task 7 Step 1. §9 (risks) → carried as comments where each one bites. §10 (what this does not do) → Task 6 Step 4's closing message and the CLAUDE.md text.

**Two spec items deliberately not implemented as written.** The spec's §6 half-sheet split is demoted to a fallback because the single pass was measured to work; the fallback is spelled out in Task 5 Step 2 rather than dropped. And the SF licensing question in §9 stays open — no task resolves it, because it is a decision, not work.

**Known gap, stated rather than hidden.** Task 3 Step 1 requires reading the current view sources before writing navigation, because the UI changed twice during this plan's design. The section titles in Step 2 are today's strings; if one has moved, the step says to correct it rather than to add a coordinate tap.
