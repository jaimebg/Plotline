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
SCHEME_FILE="Plotline.xcodeproj/xcshareddata/xcschemes/Plotline.xcscheme"
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
# longer names a real simulator. Returns 2 for that case, distinct from a
# genuine test failure, so the caller does not print a second, misleading
# "pass red" on top of the specific reason already given below.
run_suite() {
    if ! xcrun simctl uninstall "$DEVICE" "$BUNDLE_ID"; then
        # `fail`, not a hard stop: -e is deliberately absent so one bad
        # step does not stop the rest of the preflight from reporting
        # everything else wrong in the same pass.
        fail "could not uninstall $BUNDLE_ID from $DEVICE — the suite below did not run"
        return 2
    fi
    env $1 xcodebuild -project Plotline.xcodeproj -scheme Plotline \
        -destination "platform=iOS Simulator,name=$DEVICE" $2 test 2>&1 | tail -20
    return "${PIPESTATUS[0]}"
}

step "1/8  App suite, starved of TMDB"
run_suite "" ""
status=$?
if [ "$status" -eq 0 ]; then
    pass "starved pass green"
elif [ "$status" -ne 2 ]; then
    fail "starved pass red"
fi

step "2/8  Cold-start suite, live against TMDB"
# The only place this runs, and only the UI suite: the unit tests neither touch
# the network nor change between the two passes. A red here can mean a real
# defect or a TMDB rate limit; read the failure before treating it as either.
run_suite "TEST_RUNNER_PLOTLINE_UITEST_MODE=live" "-only-testing:PlotlineUITests"
status=$?
if [ "$status" -eq 0 ]; then
    pass "live pass green"
elif [ "$status" -ne 2 ]; then
    fail "live pass red — check whether TMDB rate-limited before blaming the code"
fi

step "3/8  Generator suite (the only tests that read the shipped dataset)"
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
        gen_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$generated" +%s 2>/dev/null)
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
version=$(grep -m1 'MARKETING_VERSION' Plotline.xcodeproj/project.pbxproj \
          | sed 's/.*= *//; s/;.*//' | tr -d ' ')
# An empty $version would make the grep below match every line of every file
# — an empty pattern matches unconditionally — turning a missing key into a
# silent pass instead of the failure it actually is. Guard it explicitly.
if [ -z "$version" ]; then
    fail "MARKETING_VERSION could not be read from Plotline.xcodeproj/project.pbxproj"
elif grep -rq "$version" docs/app-review/; then
    pass "project and docs/app-review both say $version"
else
    fail "project says $version but no file in docs/app-review/ mentions it"
fi

step "6/8  No trace of OMDb"
if grep -rq "omdbapi" --include="*.swift" --include="*.plist" Plotline/ Tools/; then
    fail "a reference to omdbapi.com is back"
else
    pass "no reference to omdbapi.com"
fi

step "7/8  No leaked secret in the shared scheme"
# xcshareddata/ used to be gitignored wholesale to keep a scheme-embedded API
# key out of git, which also meant the UI suite's <TestAction> entry and
# Task 6's Archive pre-action could never be versioned. The condition for
# lifting that blanket rule was replacing it with this visible check: the
# shared scheme must declare no environment variable carrying a value. A
# populated `value` attribute inside <EnvironmentVariables> would be
# committed to git in plain text, unlike Plotline/Secrets.plist, which stays
# gitignored.
if [ ! -f "$SCHEME_FILE" ]; then
    fail "$SCHEME_FILE is missing — cannot check it for a leaked secret"
elif awk '/<EnvironmentVariables>/,/<\/EnvironmentVariables>/' "$SCHEME_FILE" \
        | grep -q 'value = "[^"]'; then
    fail "$SCHEME_FILE declares an environment variable with a value — it would be committed in plain text"
else
    pass "$SCHEME_FILE declares no environment variable carrying a value"
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
