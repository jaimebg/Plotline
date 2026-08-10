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

# testCaptureAll attaches exactly one capture per numbered frame, 1 through 8.
EXPECTED_COUNT=8

OUT="screenshots/raw/$FAMILY"
BUNDLE=$(mktemp -d -t plotline-shots)/result.xcresult
EXPORT=$(mktemp -d -t plotline-export)

echo "==> booting $DEVICE"
xcrun simctl boot "$DEVICE" 2>/dev/null
if ! xcrun simctl bootstatus "$DEVICE" -b >/dev/null 2>&1; then
    echo "could not boot $DEVICE" >&2; exit 1
fi

# The simulator's own system locale, not the app's. -AppleLanguages/-AppleLocale
# (set as launch arguments by ScreenshotCaptureTests) only reach the app
# process — the status bar is drawn by the OS around it and follows the
# device's locale instead, so an English UI can still ship under a Spanish
# clock: "Lunes 10 de agosto" instead of "Mon Aug 10". That is the exact
# defect the design spec calls out from the hand-made submission this
# pipeline replaced, and it showed up on iPad (whose status bar has room for
# a date) even after the app-side fix.
EXPECT_LOCALE="en_US"
EXPECT_LANGUAGES="(en)"
if ! xcrun simctl spawn "$DEVICE" defaults write -g AppleLocale -string "$EXPECT_LOCALE"; then
    echo "could not set AppleLocale on $DEVICE; captures would ship the sim's system locale" >&2
    exit 1
fi
if ! xcrun simctl spawn "$DEVICE" defaults write -g AppleLanguages -array "en"; then
    echo "could not set AppleLanguages on $DEVICE; captures would ship the sim's system language" >&2
    exit 1
fi

# Read both back rather than trusting the writes landed: a silent no-op has
# cost a full run on this script twice before (TEST_RUNNER_ forwarding, the
# attachment-name parser), both invisible until something checked.
got_locale=$(xcrun simctl spawn "$DEVICE" defaults read -g AppleLocale 2>/dev/null)
if [ "$got_locale" != "$EXPECT_LOCALE" ]; then
    echo "AppleLocale reads back as '$got_locale' after writing $EXPECT_LOCALE on $DEVICE; the write did not take" >&2
    exit 1
fi
got_languages=$(xcrun simctl spawn "$DEVICE" defaults read -g AppleLanguages 2>/dev/null | tr -d '[:space:]')
if [ "$got_languages" != "$EXPECT_LANGUAGES" ]; then
    echo "AppleLanguages reads back as '$got_languages' after writing en on $DEVICE; the write did not take" >&2
    exit 1
fi

# The write alone does not move the status bar: SpringBoard reads locale
# once at launch and holds it in memory, so it keeps drawing the old one
# until it restarts. `launchctl stop` kills it; launchd runs it as a
# LaunchDaemon and restarts it automatically, this time reading the locale
# just written. The xcodebuild run below takes minutes, which is far more
# settle time than the respring itself needs, but a fixed sleep is still
# here so a screenshot taken this instant would not race it.
echo "==> respringing $DEVICE for the new locale to take effect"
if ! xcrun simctl spawn "$DEVICE" launchctl stop com.apple.SpringBoard; then
    echo "could not respring $DEVICE; the status bar would keep the old locale" >&2
    exit 1
fi
sleep 5

if ! xcrun simctl ui "$DEVICE" appearance dark; then
    echo "could not force dark appearance on $DEVICE; captures would ship light-mode" >&2
    exit 1
fi
if ! xcrun simctl status_bar "$DEVICE" override \
    --time "9:41" --batteryState charged --batteryLevel 100 \
    --wifiBars 3 --cellularBars 4 --dataNetwork wifi; then
    echo "could not override the status bar on $DEVICE; captures would ship the real clock" >&2
    exit 1
fi

echo "==> capturing"
# TEST_RUNNER_PLOTLINE_SCREENSHOT_CAPTURE=1 has to be a real environment
# variable on the xcodebuild process, not a later positional argument:
# xcodebuild's TEST_RUNNER_ forwarding reads its own process environment, and
# bash only treats a VAR=value token as one when it precedes the command name.
# Verified empirically — putting it after `test` left the suite skipped with
# no error, since the guard's XCTSkipUnless treats "absent" and "off" the same.
TEST_RUNNER_PLOTLINE_SCREENSHOT_CAPTURE=1 \
xcodebuild -project Plotline.xcodeproj -scheme Plotline \
    -destination "platform=iOS Simulator,name=$DEVICE" \
    -only-testing:PlotlineUITests/ScreenshotCaptureTests \
    -resultBundlePath "$BUNDLE" \
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
import json, os, re, shutil, sys
src, dst = sys.argv[1], sys.argv[2]
manifest = json.load(open(os.path.join(src, "manifest.json")))
moved = 0
for test in manifest:
    for att in test.get("attachments", []):
        human = att.get("suggestedHumanReadableName") or ""
        # xcresulttool does not hand back the attachment name verbatim: it
        # appends "_<sequence>_<UUID>" before the extension to keep names
        # unique, e.g. "01_0_3D4AB1CF-....png" for an attachment named "01".
        # Match the leading two-digit index rather than the whole stem.
        match = re.match(r"^(\d{2})_", human)
        if not match:
            continue
        name = match.group(1)
        shutil.copyfile(os.path.join(src, att["exportedFileName"]),
                        os.path.join(dst, name + ".png"))
        moved += 1
print(f"copied {moved} screenshot(s)")
PY

count=$(ls "$OUT"/*.png 2>/dev/null | wc -l | tr -d ' ')
echo "==> $count file(s) in $OUT"
if [ "$count" -ne "$EXPECTED_COUNT" ]; then
    echo "expected $EXPECTED_COUNT screenshot(s) but found $count in $OUT; the run is incomplete — check the xcodebuild log for a retried or skipped frame before trusting anything in this directory" >&2
    exit 1
fi
for f in "$OUT"/*.png; do
    got=$(swift Scripts/screenshots/verify.swift size "$f")
    if [ "$got" != "$EXPECT" ]; then
        echo "$f is $got, expected $EXPECT" >&2; exit 1
    fi
done
echo "all captures are $EXPECT"
