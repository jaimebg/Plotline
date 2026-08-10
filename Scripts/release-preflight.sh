#!/bin/bash
# Everything that has to be true before a Plotline release, in one place.
#
# A BARRIER, when a lane runs it. The release lanes in fastlane/Fastfile call
# this through sh(), and a non-zero exit aborts the lane. It is still ALSO
# wired to the scheme's Archive pre-action, and there it only warns — a
# pre-action that exits non-zero does not reliably abort an archive in recent
# Xcode. Same script, two callers, two strengths: the lane stops, the
# pre-action tells you.
#
# Usage: release-preflight.sh [--for=beta|--for=release]
#   --for=release  (default) every check, including the screenshot set
#   --for=beta     skips step 8: a TestFlight build of an in-progress version
#                  legitimately has no marketing screenshots yet
set -uo pipefail

cd "$(dirname "$0")/.." || exit 1

DEVICE="iPhone 17"
BUNDLE_ID="com.jbgsoft.Plotline"
DATASET="Plotline/Resources/PlotlineDataset.json"
SCHEMES_DIR="Plotline.xcodeproj/xcshareddata/xcschemes"
SCHEME_FILE="$SCHEMES_DIR/Plotline.xcscheme"
MAX_DATASET_AGE_DAYS=90   # A judgement, not a calculation. Change it here.

MODE=release
for arg in "$@"; do
    case "$arg" in
        --for=beta)    MODE=beta ;;
        --for=release) MODE=release ;;
        *)
            printf 'unknown argument: %s\nusage: %s [--for=beta|--for=release]\n' \
                "$arg" "$(basename "$0")" >&2
            exit 2
            ;;
    esac
done

failures=0
step()  { printf '\n\033[1m▸ %s\033[0m\n' "$1"; }
fail()  { printf '\033[31m  ✗ %s\033[0m\n' "$1"; failures=$((failures + 1)); }
pass()  { printf '\033[32m  ✓ %s\033[0m\n' "$1"; }

# $1 = extra env assignment, or empty. $2 = extra xcodebuild args, or empty.
# Both unquoted on purpose: empty expands to nothing rather than to an empty
# argument. Always uninstalls first — the UI suite asserts a clean container
# and would otherwise report the container, not the code.
#
# Uninstalls from "$DEVICE" by name, not "booted": "booted" resolves to
# whichever simulator answers first, and on a machine with a second
# simulator left booted from an earlier iPad pass that is not the device
# `-destination` below is about to test on. That let an uninstall succeed
# against the wrong device while the suite ran against a dirty container on
# the right one — silently, because the result was discarded. Naming the
# device makes the uninstall act on the exact simulator the suite runs on.
#
# Verified directly (not assumed): `simctl uninstall` exits 0 as a silent
# no-op when there is nothing installed to remove, so a real "first run,
# nothing to clean" is never mistaken for a failure here. A non-zero exit
# means the device itself could not be reached — most likely $DEVICE no
# longer names a real simulator. That case sets `suite_skipped`, in its own
# variable rather than in the return code, so it can never be confused with
# an exit code xcodebuild itself might produce; the caller reads it to avoid
# printing a second, misleading "pass red" on top of the specific reason
# already given below.
#
# The whole run is written to $SUITE_LOG and only its tail is shown, so a
# caller can still ask the full output a question — which step 2 does.
suite_skipped=0
SUITE_LOG=$(mktemp -t plotline-preflight-suite)
trap 'rm -f "$SUITE_LOG"' EXIT
run_suite() {
    suite_skipped=0
    # Booted here, not once at the top: `xcodebuild test` leaves the
    # simulator shut down when it exits, so without this, the second pass's
    # uninstall below runs against a Shutdown device and reports a failure
    # that is about the device rather than the code. `simctl boot` on an
    # already-booted device is not a no-op — it fails with "Unable to boot
    # device in current state: Booted" and a non-zero exit — but that failure
    # is harmless: it is suppressed (2>/dev/null) and its exit code is never
    # checked, so it is still safe to call before every pass instead of once
    # before the first.
    xcrun simctl boot "$DEVICE" 2>/dev/null
    xcrun simctl bootstatus "$DEVICE" -b >/dev/null 2>&1
    if ! xcrun simctl uninstall "$DEVICE" "$BUNDLE_ID"; then
        # `fail`, not a hard stop: -e is deliberately absent so one bad
        # step does not stop the rest of the preflight from reporting
        # everything else wrong in the same pass.
        fail "could not uninstall $BUNDLE_ID from $DEVICE — the suite below did not run"
        suite_skipped=1
        return 1
    fi
    env $1 xcodebuild -project Plotline.xcodeproj -scheme Plotline \
        -destination "platform=iOS Simulator,name=$DEVICE" $2 test > "$SUITE_LOG" 2>&1
    local result=$?
    tail -20 "$SUITE_LOG"
    return "$result"
}

step "1/12  App suite, starved of TMDB"
run_suite "" ""
status=$?
if [ "$suite_skipped" -eq 1 ]; then
    :   # already reported, with the reason
elif [ "$status" -eq 0 ]; then
    pass "starved pass green"
else
    fail "starved pass red"
fi

step "2/12  Cold-start suite, live against TMDB"
# The only place this runs, and only the UI suite: the unit tests neither touch
# the network nor change between the two passes. A red here can mean a real
# defect or a TMDB rate limit; read the failure before treating it as either.
run_suite "TEST_RUNNER_PLOTLINE_UITEST_MODE=live" "-only-testing:PlotlineUITests"
status=$?
# Green is not enough here. The mode is delivered by xcodebuild stripping the
# TEST_RUNNER_ prefix; if that forwarding ever breaks, the variable is simply
# absent, ColdStartUITests falls back to its starved default, every assertion
# still passes, and this step would print "live pass green" over a second copy
# of step 1 — with the live recomputation path, the only thing this pass
# exists to exercise, untouched. No assertion inside the suite can catch that:
# it reads the same absent variable and concludes, correctly for what it can
# see, that this is a starved pass. So the suite reports the mode it observed
# and this is what reads it back.
if [ "$suite_skipped" -eq 1 ]; then
    :   # already reported, with the reason
elif [ "$status" -ne 0 ]; then
    fail "live pass red — check whether TMDB rate-limited before blaming the code"
elif ! grep -q 'PLOTLINE_UITEST_MODE_OBSERVED=live' "$SUITE_LOG"; then
    fail "the suite passed but never reported running in live mode — TEST_RUNNER_PLOTLINE_UITEST_MODE did not reach the runner, so this was a second starved pass"
else
    pass "live pass green, and the suite reported it ran live"
fi

# `ShippedDatasetTests` lives in this package and is the only suite that opens
# Plotline/Resources/PlotlineDataset.json as a file on disk, asserts the full
# set of cross-list invariants, and scans it for a leaked key. The app's own
# ColdStartTests and DatasetStoreTests read the copy of that same file inside
# the built bundle. DatasetStoreTests.listsResolve asserts, at full strength,
# the same invariant as ShippedDatasetTests.listsOnlyReferenceKnownEntries.
# ColdStartTests checks a weaker form of that same invariant — every list
# resolves to at least one entry — but neither suite asserts the rest, or the
# secret scan, and `xcodebuild test` never runs this package at all.
step "3/12  Generator suite (the only tests that open the committed dataset)"
if (cd Tools/DatasetGenerator && swift test 2>&1 | tail -10); then
    pass "shipped dataset invariants hold"
else
    fail "shipped dataset invariants broken"
fi

step "4/12  Dataset freshness"
if [ ! -f "$DATASET" ]; then
    fail "$DATASET does not exist"
else
    generated=$(plutil -extract generatedAt raw -o - "$DATASET" 2>/dev/null)
    if [ -z "$generated" ] || [ "$generated" = "null" ]; then
        fail "$DATASET declares no generatedAt — regenerate it with Tools/DatasetGenerator"
    else
        # -u because the trailing Z is UTC: without it `date` reads the
        # timestamp in local time, and every zone behind UTC turns a dataset
        # generated minutes ago into one dated in the future.
        gen_epoch=$(date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$generated" +%s 2>/dev/null)
        if [ -z "$gen_epoch" ]; then
            fail "generatedAt is not ISO8601: $generated"
        else
            now_epoch=$(date +%s)
            if [ "$gen_epoch" -gt "$now_epoch" ]; then
                fail "generatedAt ($generated) is in the future — check the clock that produced it"
            else
                age_days=$(( ( now_epoch - gen_epoch ) / 86400 ))
                if [ "$age_days" -gt "$MAX_DATASET_AGE_DAYS" ]; then
                    fail "dataset is $age_days days old (limit $MAX_DATASET_AGE_DAYS)"
                else
                    pass "dataset is $age_days days old"
                fi
            fi
        fi
    fi
fi

step "5/12  Version coherence with the App Review artefacts"
# Asked of the build system rather than grepped out of project.pbxproj:
# MARKETING_VERSION appears once per configuration of every target, six times
# in this project, and the first one a grep finds is the app's only because
# Xcode's generated UUIDs happen to sort it there. This names the target and
# the configuration that ships.
version=$(xcodebuild -project Plotline.xcodeproj -target Plotline \
          -configuration Release -showBuildSettings 2>/dev/null \
          | grep -m1 ' MARKETING_VERSION = ' | sed 's/.*= //' | tr -d ' ')
# An empty $version would make the grep below match every line of every file
# — an empty pattern matches unconditionally — turning a missing key into a
# silent pass instead of the failure it actually is. Guard it explicitly.
if [ -z "$version" ]; then
    fail "MARKETING_VERSION could not be read from the Plotline target's Release configuration"
elif grep -rq "$version" docs/app-review/; then
    pass "project and docs/app-review both say $version"
else
    fail "project says $version but no file in docs/app-review/ mentions it"
fi

step "6/12  No trace of OMDb"
if grep -rq "omdbapi" --include="*.swift" --include="*.plist" Plotline/ Tools/; then
    fail "a reference to omdbapi.com is back"
else
    pass "no omdbapi reference in any .swift or .plist under Plotline/ or Tools/"
fi

step "7/12  Shared schemes: no leaked secret, and the UI suite still serialised"
# xcshareddata/ used to be gitignored wholesale to keep a scheme-embedded API
# key out of git, which also meant the UI suite's <TestAction> entry and the
# Archive pre-action that runs this script could never be versioned. The
# condition for lifting that blanket rule was replacing it with this visible
# check: no shared scheme may declare an environment variable carrying a
# value. A populated `value` attribute inside <EnvironmentVariables> would be
# committed to git in plain text, unlike Plotline/Secrets.plist, which stays
# gitignored. Every scheme in the directory is checked, because .gitignore
# versions the whole directory, not one file.
#
# The regex tolerates any spacing around `=`: Xcode writes `value = "…"`, a
# hand edit writes `value="…"`, and both would ship the same secret.
shopt -s nullglob
schemes=("$SCHEMES_DIR"/*.xcscheme)
shopt -u nullglob
if [ "${#schemes[@]}" -eq 0 ]; then
    fail "no shared scheme in $SCHEMES_DIR — this check has nothing to read, and the UI suite's test action is versioned nowhere"
else
    leaked=0
    for scheme in "${schemes[@]}"; do
        if awk '/<EnvironmentVariables>/,/<\/EnvironmentVariables>/' "$scheme" \
                | grep -qE 'value *= *"[^"]'; then
            fail "$scheme declares an environment variable with a value — it would be committed in plain text"
            leaked=1
        fi
    done
    if [ "$leaked" -eq 0 ]; then
        pass "no <EnvironmentVariables> value in ${#schemes[@]} shared scheme(s) — command-line arguments and pre-action scripts are not read by this check"
    fi
fi

# Separate from the scan above and specific to this one scheme, because this
# is where the UI target's testable lives.
#
# What makes every uninstall in run_suite mean anything is that
# PlotlineUITests runs non-parallel: with parallelization on, Xcode clones
# the simulator and runs the tests on the clones, so the device named in
# -destination — the one this script uninstalls from — is no longer the
# container the suite runs in. `parallelizable = "YES"` is the only value
# that turns that on. An absent attribute is Xcode's default for a UI test
# target and already means non-parallel — confirmed independently in this
# same release's screenshot captures, which pin the status bar by name on
# `-destination` and show it correctly in every shot, which a clone would
# not — so this only fails on an explicit "YES", not on the attribute being
# unset.
# The attribute has already been lost once on this branch — a local
# `xcodebuild test` run put it back to YES, and a person happened to notice.
# This is so the next time it is not a person.
if [ ! -f "$SCHEME_FILE" ]; then
    fail "$SCHEME_FILE is missing — cannot check that the UI suite still runs serially"
else
    ui_testable=$(awk '
        /<TestableReference/ { block = "" }
        { block = block $0 "\n" }
        /<\/TestableReference>/ { if (block ~ /PlotlineUITests\.xctest/) printf "%s", block }
    ' "$SCHEME_FILE")
    if [ -z "$ui_testable" ]; then
        fail "$SCHEME_FILE declares no PlotlineUITests testable — the cold-start suite does not run from this scheme at all"
    elif printf '%s' "$ui_testable" | grep -qE 'parallelizable *= *"YES"'; then
        fail "$SCHEME_FILE marks PlotlineUITests parallelizable = \"YES\" — parallel runs happen on simulator clones, so the uninstalls above stop reaching the container under test"
    else
        pass "PlotlineUITests is not parallelizable = \"YES\" (absent or explicit \"NO\" both run on the device -destination names, not a clone)"
    fi
fi

step "8/12  The screenshot set for this version"
# Asked of the build system for the same reason step 5 does: a grepped
# MARKETING_VERSION would be the first of six matches in project.pbxproj, not
# necessarily this target's. An empty result is guarded explicitly — an
# unguarded empty $shot_version would still resolve to a real (wrong)
# directory name here, "screenshots//family", rather than to the empty
# pattern step 5 warns about, but it is just as much a silent wrong answer.
if [ "$MODE" = beta ]; then
    pass "skipped — beta build, marketing screenshots are not required until release"
else
    shot_version=$(xcodebuild -project Plotline.xcodeproj -target Plotline -configuration Release \
        -showBuildSettings 2>/dev/null | awk '/ MARKETING_VERSION = /{print $3; exit}')
    if [ -z "$shot_version" ]; then
        fail "MARKETING_VERSION could not be read from the Plotline target's Release configuration — cannot locate the screenshot set"
    else
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
    fi
fi

step "9/12  No App Store Connect credential in version control"
# The repo is public and now has an upload credential living beside it. This
# is the same idea as step 7's scheme scan, aimed at the new secret.
#
# The issuer id cannot be hardcoded here — writing it into a tracked file is
# the very thing this step exists to prevent. It is read at runtime from the
# untracked .env and then searched for among tracked files.
cred_ok=1
tracked=$(git ls-files fastlane 2>/dev/null)
if [ -n "$tracked" ]; then
    fail "git is tracking files under fastlane/ — that directory must stay local:"
    printf '      %s\n' $tracked
    cred_ok=0
fi
if [ -n "$(git ls-files '*.p8' 2>/dev/null)" ]; then
    fail "git is tracking a .p8 private key"
    cred_ok=0
fi
# Assembled at runtime, not written as one literal: a check that greps
# every tracked file for a PEM header would otherwise match its own
# source line and fail forever on a repo with no leak in it at all.
pem_header="BEGIN PRIVATE"' KEY'
if git grep -q -- "$pem_header" -- . 2>/dev/null; then
    fail "a PEM private key block appears in a tracked file"
    cred_ok=0
fi
if [ -f fastlane/.env ]; then
    issuer=$(grep -m1 '^ASC_ISSUER_ID=' fastlane/.env | cut -d= -f2- | tr -d "\"' ")
    if [ -z "$issuer" ]; then
        fail "fastlane/.env has no ASC_ISSUER_ID — cannot check whether it leaked"
        cred_ok=0
    elif git grep -q -- "$issuer" -- . 2>/dev/null; then
        fail "the App Store Connect issuer id appears in a tracked file"
        cred_ok=0
    fi
else
    # Not a pass. Without the .env this check cannot run at all, and a check
    # that silently reports success when it did not run is the fail-open
    # pattern commit f90d8fe was written to close.
    fail "fastlane/.env is missing — cannot verify the issuer id has not leaked; run: bundle exec fastlane bootstrap"
    cred_ok=0
fi
if [ "$cred_ok" -eq 1 ]; then
    pass "no key, issuer id or fastlane file under version control"
fi

step "10/12  ASO budgets and keyword waste"
if [ ! -d fastlane/metadata/en-US ]; then
    fail "fastlane/metadata/en-US is missing — run: bundle exec fastlane bootstrap"
elif swift Scripts/aso-lint.swift fastlane/metadata; then
    :   # the linter prints its own pass line, and any warnings under it
else
    fail "a store string is over its App Store character budget"
fi

step "11/12  Store copy agrees with the app"
# Two sources, because the facts live in two places. The series count comes
# from counting entries in the dataset; the shelf names come from
# CuratedListCopy.swift and NOT from the dataset, which carries ids and
# members but never words.
#
# render.sh used to make the count check too, for a "122 SERIES" marketing
# chip on frame 5. That chip and its check have been removed. So this is now
# the only mechanical verification of that number anywhere in the project,
# while the claim itself still sits in the public App Store description.
DESCRIPTION="fastlane/metadata/en-US/description.txt"
LIST_COPY="Plotline/Models/CuratedListCopy.swift"
if [ ! -f "$DESCRIPTION" ]; then
    fail "$DESCRIPTION is missing — run: bundle exec fastlane bootstrap"
else
    copy_ok=1

    entries=$(python3 -c "import json;print(len(json.load(open('$DATASET'))['entries']))" 2>/dev/null)
    if [ -z "$entries" ]; then
        fail "could not count entries in $DATASET"
        copy_ok=0
    elif ! grep -qF -- "$entries fully analysed series" "$DESCRIPTION"; then
        fail "$DATASET has $entries entries but the description does not say \"$entries fully analysed series\""
        copy_ok=0
    fi

    # Title lines in CuratedListCopy end with a quote then a comma; subtitle
    # lines do not. That makes the extraction sensitive to the file's format,
    # so the count is asserted: a reformat must fail here rather than quietly
    # check zero titles and pass.
    titles=$(grep -oE '^ +"[^"]+",$' "$LIST_COPY" | sed 's/^ *"//; s/",$//')
    title_count=$(printf '%s\n' "$titles" | grep -c .)
    if [ "$title_count" -ne 5 ]; then
        fail "expected 5 shelf titles in $LIST_COPY, extracted $title_count — either the extraction pattern no longer matches this file's format, or a shelf was legitimately added or removed; if the list genuinely changed, update the 5 in this check to $title_count, otherwise fix the extraction pattern"
        copy_ok=0
    else
        while IFS= read -r title; do
            if ! grep -qF -- "$title" "$DESCRIPTION"; then
                fail "the description never mentions the shelf \"$title\""
                copy_ok=0
            fi
        done <<< "$titles"
    fi

    if [ "$copy_ok" -eq 1 ]; then
        pass "description agrees with $DATASET's $entries entries and all 5 shelf names"
    fi
fi

step "12/12  What still has to be done by hand"
cat <<'MANUAL'
  Most of this list is now automated — see docs/app-review/README.md for the
  lanes. What no API can do, in this order:

    1. Reply in the Resolution Center thread. BEFORE uploading anything.
       There is no API for this and the release lane does NOT stop for it;
       it prints this warning and continues. Resubmitting in silence is what
       turned one rejection into three.
    2. Deploy the CloudKit container iCloud.com.jbgsoft.Plotline to
       Production. A build can be approved and still fail to sync favorites
       and the watchlist for real users if this is skipped.
    3. Age rating, privacy nutrition labels, category and pricing.
    4. Read the sixteen screenshots before they go up. Nothing checks that
       each headline is still true about the capture beneath it.
    5. Read fastlane/metadata/en-US/release_notes.txt. NOTHING checks it.
       Step 5 only proves docs/app-review/ mentions the current
       MARKETING_VERSION — it never opens release_notes.txt.
MANUAL

if [ "$failures" -eq 0 ]; then
    printf '\n\033[32mPreflight clean.\033[0m Nothing above blocks a release.\n'
    exit 0
fi
printf '\n\033[31m%s check(s) failed.\033[0m\n' "$failures"
exit 1
