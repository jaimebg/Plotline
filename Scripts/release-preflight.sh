#!/bin/bash
# Everything that has to be true before a Plotline release, in one place.
#
# NOT A BARRIER. This is also wired to the scheme's Archive pre-action, and a
# pre-action that exits non-zero does not reliably abort an archive in recent
# Xcode. It tells you at the right moment; it does not stop you.
set -uo pipefail

cd "$(dirname "$0")/.." || exit 1

DEVICE="iPhone 17"
BUNDLE_ID="com.jbgsoft.Plotline"
DATASET="Plotline/Resources/PlotlineDataset.json"
SCHEMES_DIR="Plotline.xcodeproj/xcshareddata/xcschemes"
SCHEME_FILE="$SCHEMES_DIR/Plotline.xcscheme"
MAX_DATASET_AGE_DAYS=90   # A judgement, not a calculation. Change it here.

failures=0
step()  { printf '\n\033[1m▸ %s\033[0m\n' "$1"; }
fail()  { printf '\033[31m  ✗ %s\033[0m\n' "$1"; failures=$((failures + 1)); }
pass()  { printf '\033[32m  ✓ %s\033[0m\n' "$1"; }

xcrun simctl boot "$DEVICE" 2>/dev/null
xcrun simctl bootstatus "$DEVICE" -b >/dev/null 2>&1

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

step "1/8  App suite, starved of TMDB"
run_suite "" ""
status=$?
if [ "$suite_skipped" -eq 1 ]; then
    :   # already reported, with the reason
elif [ "$status" -eq 0 ]; then
    pass "starved pass green"
else
    fail "starved pass red"
fi

step "2/8  Cold-start suite, live against TMDB"
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
# Plotline/Resources/PlotlineDataset.json as a file on disk, asserts its
# cross-list invariants and scans it for a leaked key. The app's own
# ColdStartTests and DatasetStoreTests read the copy of that same file inside
# the built bundle, so they see its contents but none of those invariants —
# and `xcodebuild test` never runs this package at all.
step "3/8  Generator suite (the only tests that open the committed dataset)"
if (cd Tools/DatasetGenerator && swift test 2>&1 | tail -10); then
    pass "shipped dataset invariants hold"
else
    fail "shipped dataset invariants broken"
fi

step "4/8  Dataset freshness"
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

step "5/8  Version coherence with the App Review artefacts"
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

step "6/8  No trace of OMDb"
if grep -rq "omdbapi" --include="*.swift" --include="*.plist" Plotline/ Tools/; then
    fail "a reference to omdbapi.com is back"
else
    pass "no omdbapi reference in any .swift or .plist under Plotline/ or Tools/"
fi

step "7/8  Shared schemes: no leaked secret, and the UI suite still serialised"
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
# `parallelizable = "NO"` is what makes every uninstall in run_suite mean
# anything: with parallelization on, Xcode clones the simulator and runs the
# tests on the clones, so the device named in -destination — the one this
# script uninstalls from — is no longer the container the suite runs in.
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
    elif ! printf '%s' "$ui_testable" | grep -qE 'parallelizable *= *"NO"'; then
        fail "$SCHEME_FILE no longer marks PlotlineUITests parallelizable = \"NO\" — parallel runs happen on simulator clones, so the uninstalls above stop reaching the container under test"
    else
        pass "PlotlineUITests is still parallelizable = \"NO\", so it runs on the device -destination names and not on a clone"
    fi
fi

step "8/8  What still has to be done by hand"
cat <<'MANUAL'
  App Store Connect is not automated, on purpose — see docs/app-review/README.md.
  In this order:
    1. Reply in the existing Resolution Center thread. Before uploading anything.
    2. Upload the build.
    3. Update description, subtitle, promotional text, keywords, what's new.
    4. Replace the screenshots.
    5. Paste the App Review Notes.
    6. Request the call from the Resolution Center.
MANUAL

if [ "$failures" -eq 0 ]; then
    printf '\n\033[32mPreflight clean.\033[0m Nothing above blocks a release.\n'
    exit 0
fi
printf '\n\033[31m%s check(s) failed.\033[0m\n' "$failures"
exit 1
