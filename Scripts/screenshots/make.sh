#!/bin/bash
# Everything, end to end.
#
#   Scripts/screenshots/make.sh              both families
#   Scripts/screenshots/make.sh iphone-69    one family
#
# Capture needs a simulator, a working TMDB key in Plotline/Secrets.plist and
# several minutes. Render needs neither and takes seconds, so iterate on the
# design by running render.sh alone.
#
# The marketing chips in iphone.html/ipad.html — LEVEL 86 · CONSISTENCY 54 ·
# TRAJECTORY 65, BEFORE 8.4 -> AFTER 8.0, SEASON 1 · AVG 8.4 — are numbers
# transcribed by hand from an earlier capture, not read from the screenshots
# this script takes. capture.sh below pulls fresh numbers from a live,
# TMDB-backed simulator run every time it's invoked. If a rating moved since
# those chips were written, a re-run can produce screenshots the chips no
# longer describe, and nothing in this pipeline compares the two — see the
# closing message.
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
printf '\n\033[33mCheck by hand:\033[0m the chip text hardcoded in iphone.html/ipad.html\n'
printf '(LEVEL 86 · CONSISTENCY 54 · TRAJECTORY 65, BEFORE 8.4 -> AFTER 8.0,\n'
printf 'SEASON 1 · AVG 8.4) was transcribed from a past capture, not this one. This\n'
printf 'run just pulled fresh numbers from TMDB — if any moved, those chips now\n'
printf 'contradict the screenshots beneath them, and no check above would catch it.\n'
