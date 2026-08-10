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

# A missing headline face falls back to something plausible and the sheet
# still looks fine, so the size checks below would all pass on a wrong render.
# The sheet measures a known string and puts the width in its title; if that
# moved, the font is not the one the design specifies.
#
# Measured with (Chrome 151.0.7922.108, run from the repo root, against
# iphone.html — ipad.html renders the same probe string at the same size in
# the same face and measured identically):
#   "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless --disable-gpu \
#     --dump-dom "file://$PWD/Scripts/screenshots/iphone.html" 2>/dev/null | grep -o 'ready:[0-9.]*' | head -1
# Re-run that and update this constant if the headline face is ever
# deliberately changed (the design spec floats Inter as an alternative to the
# current system-ui face) — a stale EXPECTED_PROBE would reject every render.
EXPECTED_PROBE=662.9
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

# make.sh prints this same warning, but only after a full, successful,
# both-families run — it never fires if capture.sh and render.sh are called
# directly instead, which is exactly what shipped 1.4.0's real screenshots.
# render.sh is the step that turns raw captures into the files that get
# uploaded, and it runs on every path, so the warning belongs here too.
printf '\n\033[33mCheck by hand:\033[0m the chip text hardcoded in iphone.html/ipad.html\n'
printf '(LEVEL 86 · CONSISTENCY 54 · TRAJECTORY 65, BEFORE 8.4 -> AFTER 8.0,\n'
printf 'SEASON 1 · AVG 8.4) was transcribed from a past capture, not this one. This\n'
printf "run composed from whatever is already sitting in screenshots/raw/$FAMILY —\n"
printf 'it pulled nothing from TMDB itself. If those raw captures are stale, or the\n'
printf 'chips were transcribed from a different capture entirely, those chips now\n'
printf 'contradict the screenshots beneath them, and no check above would catch it.\n'
