#!/bin/bash
# The ASO linter's own test. A linter that approves everything is worse than
# no linter — it converts an unchecked risk into a false sense of coverage —
# so each fixture asserts a specific verdict, not merely "it ran".
set -uo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/../.." && pwd)
LINT="$ROOT/Scripts/aso-lint.swift"
FIX="$HERE/fixtures/aso"

failures=0
fail() { printf '\033[31mFAIL\033[0m  %s\n' "$1"; failures=$((failures + 1)); }
pass() { printf '\033[32mok\033[0m    %s\n' "$1"; }

run() { swift "$LINT" "$1" 2>&1; }

# --- clean: exit 0, and no warning line at all -------------------------------
out=$(run "$FIX/clean"); code=$?
[ "$code" -eq 0 ] && pass "clean fixture exits 0" || fail "clean fixture exited $code, expected 0"
if printf '%s' "$out" | grep -q '⚠'; then
    fail "clean fixture produced a warning it should not have:"$'\n'"$out"
else
    pass "clean fixture warns about nothing"
fi

# --- over-budget: must exit 1, and must name the offending file --------------
out=$(run "$FIX/over-budget"); code=$?
[ "$code" -eq 1 ] && pass "over-budget fixture exits 1" || fail "over-budget fixture exited $code, expected 1"
printf '%s' "$out" | grep -q 'subtitle' \
    && pass "over-budget fixture names subtitle" \
    || fail "over-budget fixture did not name subtitle:"$'\n'"$out"
# 34 characters against a 30 limit. Asserting the number catches an off-by-one
# in the budget table that a bare "it failed" would let through.
printf '%s' "$out" | grep -q '34/30' \
    && pass "over-budget fixture reports 34/30" \
    || fail "over-budget fixture did not report 34/30:"$'\n'"$out"

# --- wasteful: within budget, so exit 0, but all three wastes reported -------
out=$(run "$FIX/wasteful"); code=$?
[ "$code" -eq 0 ] && pass "wasteful fixture exits 0 (waste warns, never fails)" \
                  || fail "wasteful fixture exited $code, expected 0"
for want in "seasons" "space" "shows"; do
    printf '%s' "$out" | grep -q "$want" \
        && pass "wasteful fixture reports '$want'" \
        || fail "wasteful fixture never mentioned '$want':"$'\n'"$out"
done

# --- missing directory: exit 2, distinct from a real lint failure ------------
run "$FIX/does-not-exist" >/dev/null 2>&1; code=$?
[ "$code" -eq 2 ] && pass "missing metadata directory exits 2" \
                  || fail "missing directory exited $code, expected 2"

printf '\n%s failure(s)\n' "$failures"
[ "$failures" -eq 0 ]
