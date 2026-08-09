#!/bin/bash
# The slicer's own test. Renders eight known colours, cuts them, and checks
# every frame at both of its true edge columns — 0 and frameWidth-1 — plus the
# centre. A one-pixel offset moves a neighbour's colour into an edge column,
# and nothing else here would see it.
#
# The edge columns are literal, not "one pixel in". On a 1320-wide frame the
# columns are 0..1319: with a +1 offset, local column 1318 still lands inside
# the frame's own colour and only 1319 crosses into the neighbour. Sampling
# 1 and 1318 makes this suite blind to exactly the defect it exists for.
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

    # Left edge, centre, right edge. The two edge columns are what catch an
    # offset; the centre only proves the frame is not blank.
    for x in 0 660 1319; do
        got=$(swift "$ROOT/Scripts/screenshots/verify.swift" pixel "$f" "$x" 1400)
        if [ "$got" != "$want" ]; then
            fail "frame $i at x=$x is #$got, expected #$want — the cut is offset"
        fi
    done
done

[ "$failures" -eq 0 ] && pass "all eight frames cut exactly"
printf '\n%s failure(s)\n' "$failures"
[ "$failures" -eq 0 ]
