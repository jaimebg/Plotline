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

# The "122 SERIES" chip (frame 5) is the one chip that is not TMDB-derived —
# it counts `entries` in PlotlineDataset.json, and the design spec grounds it
# there explicitly. Unlike the other three chips (checked only by eye, because
# they come from a live capture this script has no independent way to
# recompute), this one has a second, static source of truth sitting right in
# the repo, so it gets an actual check instead of a warning: regenerating the
# dataset (preflight step 4/9, every ~90 days) changes the entry count without
# touching this hardcoded string, and nothing else would catch the drift.
DATASET="Plotline/Resources/PlotlineDataset.json"
chip_count=$(grep -oE '[0-9]+ SERIES · SHIPPED INSIDE THE APP' "Scripts/screenshots/$SHEET" | grep -oE '^[0-9]+')
if [ -z "$chip_count" ]; then
    echo "could not find the 'N SERIES · SHIPPED INSIDE THE APP' chip text in $SHEET" >&2
    exit 1
fi
dataset_count=$(python3 -c "import json; print(len(json.load(open('$DATASET'))['entries']))" 2>/dev/null)
if [ -z "$dataset_count" ]; then
    echo "could not count entries in $DATASET" >&2
    exit 1
fi
if [ "$chip_count" != "$dataset_count" ]; then
    echo "$SHEET's chip says $chip_count SERIES but $DATASET has $dataset_count entries — update the chip text (it is transcribed by hand, not read live)" >&2
    exit 1
fi
echo "==> chip's $chip_count SERIES matches $DATASET's $dataset_count entries"

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

# Every check above can pass on eight empty bezels: file count, pixel
# dimensions, and the font probe all read fine even when every <img src> in
# the sheet failed to resolve — proven by rendering the sheet with its raw
# image paths pointed at a nonexistent directory, which produced a correctly
# sized sheet, a passing font probe, a successful slice, and eight
# correctly-sized frames with headline, chip and curve intact but an empty
# device. The existence check above tests the path THIS SCRIPT computes
# (screenshots/raw/$FAMILY/NN.png); the sheet carries its own separate copy of
# that same path (iphone.html:69,89 / ipad.html:73,100), and nothing until now
# checked that the two agree, or that the PNG at the end of it actually
# decoded. An undecodable raw PNG, or Chrome silently dropping an image on the
# 22016px-wide iPad sheet, would fail exactly the same way.
#
# Each frame's hero device is centred at 50cqw horizontally by construction —
# every scene hero and every single-device frame is drawn left:50%-anchored —
# so X is one constant per family. Y is the vertical centre of that frame's
# hero device box (top% + half its cqw-derived height), independently worked
# out from the same geometry iphone.html/ipad.html hard-code rather than
# copied from it, so a bug shared between the sheet and this check can't
# quietly agree. Rotation is around each device's own centre (CSS default
# transform-origin), so a few degrees of tilt does not move this point.
#
# When the image behind that point failed to load in the reproduction above,
# every one of these samples read exactly #2A2A2E — the .device background
# colour, which paints through because .device itself always renders even
# when its <img> does not. That is checked here; the canvas gradient's own
# two stops are checked too, in case a different failure leaves the device
# box itself unpainted instead.
case "$FAMILY" in
    iphone-69) HERO_X=660;  HERO_Y=(1681 1624 1681 1700 1700 1652 1710 1652) ;;
    ipad-13)   HERO_X=1376; HERO_Y=(1315 1273 1315 1284 1370 1294 1335 1294) ;;
esac
BEZEL="2A2A2E"
CANVAS_TOP="0E0E12"
CANVAS_BOTTOM="17110B"
# 3, not something rounder: Color.plotlineBackground (#121212, sampled for
# real at frame 2's hero on the iPad sheet) is only 4 channels away from
# CANVAS_TOP. Tolerance 4 flagged that real content as canvas — caught by
# actually running this check, not assumed. 3 is the largest tolerance that
# still lets #121212 through while catching the bezel match, which measured
# exactly 0 away in every reproduction.
TOL=3

close_to() {
    # $1 = sampled hex (RRGGBB), $2 = reference hex (RRGGBB). True if every
    # channel is within $TOL — tight enough that no real content colour
    # sampled from a shipped frame (checked by hand against this branch's own
    # captures) falls inside it, loose enough to survive rounding.
    local sample=$1 ref=$2 chan off sv rv d
    for chan in 0 1 2; do
        off=$((chan * 2))
        sv=$(printf '%d' "0x${sample:$off:2}")
        rv=$(printf '%d' "0x${ref:$off:2}")
        d=$((sv - rv)); d=${d#-}
        [ "$d" -gt "$TOL" ] && return 1
    done
    return 0
}

i=0
for idx in 01 02 03 04 05 06 07 08; do
    y=${HERO_Y[$i]}
    sample=$(swift Scripts/screenshots/verify.swift pixel "$OUT/$idx.png" "$HERO_X" "$y")
    # verify.swift pixel writes its failure (unreadable PNG, an (x,y) outside
    # the image, a missing swift toolchain) to stderr and this script's
    # `set -uo pipefail` has no `-e`, so a dead subshell just leaves $sample
    # empty rather than stopping anything. An empty string fails both
    # `close_to` calls below — every channel comparison reads it as 0 — so the
    # bezel/canvas check silently passed on no data at all, and this printed
    # the same green line it prints on real content. Reject anything that
    # isn't a full RGB hex sample before it reaches that comparison, the same
    # way the size checks above fail closed on `got=""`.
    if ! [[ "$sample" =~ ^[0-9A-Fa-f]{6}$ ]]; then
        echo "$OUT/$idx.png: pixel probe at ($HERO_X,$y) returned no sample (\"$sample\") instead of a hex colour — verify.swift pixel likely failed. Run \`swift Scripts/screenshots/verify.swift pixel $OUT/$idx.png $HERO_X $y\` directly to see why (an unreadable PNG, a coordinate outside the image, or a missing swift toolchain are the known causes)." >&2
        exit 1
    fi
    if close_to "$sample" "$BEZEL" || close_to "$sample" "$CANVAS_TOP" || close_to "$sample" "$CANVAS_BOTTOM"; then
        echo "$OUT/$idx.png: pixel ($HERO_X,$y), inside the hero device, is #$sample — bezel or canvas colour, not app content. This frame's screenshot did not load." >&2
        exit 1
    fi
    i=$((i + 1))
done
echo "==> hero pixel in all $n frames reads as app content, not bezel/canvas"

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
