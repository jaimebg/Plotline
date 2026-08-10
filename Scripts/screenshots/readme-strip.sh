#!/bin/bash
# Join a family's eight composed frames back into the single wide strip the
# README embeds on one line.
#
#   Scripts/screenshots/readme-strip.sh            # iphone-69, current version
#   Scripts/screenshots/readme-strip.sh ipad-13 1.4.0
#
# Reads screenshots/<version>/<family>/ — the frames that were uploaded to App
# Store Connect — and writes screenshots/readme-<family>.png. The README points
# at that fixed path, not at a versioned one, so bumping MARKETING_VERSION does
# not turn the README's image into a broken link; re-run this after a new
# screenshot set and the same path carries the new artwork.
set -uo pipefail

FAMILY=${1:-iphone-69}
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
cd "$ROOT" || exit 1

case "$FAMILY" in
    iphone-69) W=1320; H=2868; TARGET_W=2640 ;;
    ipad-13)   W=2752; H=2064; TARGET_W=2752 ;;
    *) echo "usage: $0 [iphone-69|ipad-13] [version]" >&2; exit 2 ;;
esac
COUNT=8

VERSION=${2:-}
if [ -z "$VERSION" ]; then
    VERSION=$(xcodebuild -project Plotline.xcodeproj -target Plotline -configuration Release \
        -showBuildSettings 2>/dev/null | awk '/ MARKETING_VERSION = /{print $3; exit}')
fi
if [ -z "$VERSION" ]; then
    echo "MARKETING_VERSION could not be read from the Plotline target, Release configuration" >&2
    exit 1
fi

SRC="screenshots/$VERSION/$FAMILY"
FRAMES=()
for i in 01 02 03 04 05 06 07 08; do
    if [ ! -f "$SRC/$i.png" ]; then
        echo "$SRC/$i.png is missing — run Scripts/screenshots/make.sh first" >&2
        exit 1
    fi
    got=$(swift Scripts/screenshots/verify.swift size "$SRC/$i.png")
    if [ "$got" != "${W}x${H}" ]; then
        echo "$SRC/$i.png is $got, expected ${W}x${H}" >&2
        exit 1
    fi
    FRAMES+=("$SRC/$i.png")
done

OUT="screenshots/readme-$FAMILY.png"
swift Scripts/screenshots/strip.swift "$OUT" "$TARGET_W" "${FRAMES[@]}" || exit 1

# The strip is a downscale of $COUNT frames, so its height is fixed by the
# source aspect ratio. Checking it catches a frame that slipped through at the
# right width and the wrong height, which would shear the whole row.
expected_h=$(awk -v w="$TARGET_W" -v cw="$((W * COUNT))" -v h="$H" 'BEGIN{printf "%d", (h * w / cw) + 0.5}')
got=$(swift Scripts/screenshots/verify.swift size "$OUT")
if [ "$got" != "${TARGET_W}x${expected_h}" ]; then
    echo "$OUT is $got, expected ${TARGET_W}x${expected_h}" >&2
    exit 1
fi

echo "==> $OUT ($got) from $SRC"
