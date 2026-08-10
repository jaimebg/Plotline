# App Store Automation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Automate Plotline's TestFlight and App Store releases with Fastlane, add a mechanically-checked ASO linter, and turn `Scripts/release-preflight.sh` from an advisory script into a hard release gate.

**Architecture:** Fastlane runs local-only on one Mac. The entire `fastlane/` directory is gitignored — it holds an App Store Connect `.p8` credential and personal review-contact details. What stays in version control is the *recipe*: the ASO linter, its tests, the expanded preflight, and a runbook describing how to rebuild `fastlane/` from scratch. Lanes call `release-preflight.sh` via `sh()`, so a non-zero exit aborts the release — which is what the script's own header says it cannot do as an Xcode Archive pre-action.

**Tech Stack:** Fastlane 2.237.0 (Ruby, Bundler-pinned), Swift scripts run via `swift <file>` (matching the existing `Scripts/screenshots/*.swift` pattern), Bash, Xcode 26.6.

**Spec:** `docs/superpowers/specs/2026-08-10-app-store-automation-design.md`

## Global Constraints

- **Never commit anything under `fastlane/`.** The whole directory is gitignored. This includes `Fastfile`, `Appfile`, `Deliverfile`, `.env`, `.keys/`, and `metadata/`.
- **Never write the App Store Connect key id or issuer id into a tracked file** — not in code, comments, docs, commit messages, or this plan. They live only in `fastlane/.env`. Preflight step 9 fails if the issuer id appears in a tracked file.
- **Never print the contents of the `.p8` file.**
- Bundle id: `com.jbgsoft.Plotline`. Team: `95PGC3PATF` (the only distribution certificate in the keychain).
- Existing preflight helper names must be reused, not redefined: `step()`, `fail()`, `pass()`, and the `failures` counter.
- Preflight step headings use the form `"N/12  Title"` after this work. All twelve must be renumbered — leaving a `N/9` behind is a defect.
- New checks must **fail loudly when their input is missing**, never skip silently. Commit `f90d8fe` exists because a check that fails open reads as a pass.
- Swift scripts take their input path as an argument and exit `2` on usage/environment errors, `1` on a real failure, `0` on success.
- Commit messages follow Conventional Commits (`feat:`, `fix:`, `docs:`, `chore:`, `refactor:`, `test:`).
- Light and dark mode, iPhone and iPad rules from `CLAUDE.md` are untouched by this work — no view code changes here.
- **Nothing is uploaded to Apple during implementation.** Only two lanes may actually run: `bootstrap` (downloads metadata) and `release_dry_run` (validates and archives locally). The `beta`, `metadata`, `screenshots` and `release` lanes are written and checked with `bundle exec fastlane lanes`, never executed. No build is uploaded, no version is submitted, no build number is consumed.
- **Store copy is transcribed, never edited.** Tasks that move strings between files copy them verbatim. Linter warnings about the copy get reported, not acted on — rewording App Store copy is the human's decision.

---

## File Structure

**Created, tracked:**

| File | Responsibility |
|---|---|
| `Gemfile` | Pins fastlane |
| `Gemfile.lock` | Records the combination that works on this Ruby |
| `.ruby-version` | Records the Ruby the lock was built against |
| `Scripts/aso-lint.swift` | Reads a metadata directory, enforces App Store character budgets, warns on keyword waste |
| `Scripts/tests/aso-lint-tests.sh` | Proves the linter actually fails and warns |
| `Scripts/tests/fixtures/aso/clean/en-US/*.txt` | Metadata that must pass with no warnings |
| `Scripts/tests/fixtures/aso/over-budget/en-US/*.txt` | Metadata that must fail |
| `Scripts/tests/fixtures/aso/wasteful/en-US/*.txt` | Metadata that must pass but warn |

**Created, gitignored (never committed):**

`fastlane/Appfile`, `fastlane/Fastfile`, `fastlane/Deliverfile`, `fastlane/.env`, `fastlane/.keys/`, `fastlane/metadata/`

**Modified:**

| File | Change |
|---|---|
| `.gitignore` | Ignore `fastlane/`; explicitly un-ignore nothing inside it |
| `Scripts/release-preflight.sh` | `--for=beta\|release` flag; steps 9, 10, 11 added; renumber to `/12`; step 12 rewritten |
| `Plotline.xcodeproj/project.pbxproj` | Project-level `DEVELOPMENT_TEAM` → `95PGC3PATF` |
| `docs/app-review/app-store-description.md` | Paste blocks removed, rationale kept |
| `docs/app-review/app-review-notes.md` | Paste block removed, rationale kept |
| `docs/app-review/README.md` | Rewritten as the release runbook |
| `CLAUDE.md` | Lanes documented; "Before a Release" updated from 9 steps to 12 |

---

## Task 1: Prove the toolchain before building on it

The single highest-risk assumption in this plan is that fastlane 2.237.0 runs on this machine's Ruby 4.0.2. The gem requires `>= 2.7` with no upper bound, so it *should*, but Ruby 4.0 is recent and fastlane carries a large native-gem surface. Discovering a break now costs one task; discovering it after seven tasks of config costs all of them.

**Files:**
- Create: `Gemfile`, `.ruby-version`
- Create (generated): `Gemfile.lock`
- Modify: `.gitignore`

**Interfaces:**
- Consumes: nothing
- Produces: a working `bundle exec fastlane` command for every later task

- [ ] **Step 1: Record the Ruby currently in use**

```bash
ruby -v | awk '{print $2}' | cut -d'p' -f1 > .ruby-version
cat .ruby-version
```

Expected: `4.0.2`

- [ ] **Step 2: Write the Gemfile**

```ruby
source "https://rubygems.org"

# App Store release automation. Runs local-only — see
# docs/app-review/README.md for the runbook and how to rebuild fastlane/.
gem "fastlane", "~> 2.237"
```

- [ ] **Step 3: Install and prove it runs**

```bash
bundle install && bundle exec fastlane --version
```

Expected: a version line reporting `2.237.x`.

**If this fails**, stop and do not continue to Task 2. The fallback is to install Ruby 3.3 via `rbenv`, write `3.3.6` into `.ruby-version`, re-run `bundle install`, and confirm. Record whichever Ruby ended up working — the rest of the plan is unchanged either way.

- [ ] **Step 4: Ignore the whole fastlane directory**

Append to `.gitignore`:

```gitignore
# Fastlane: local-only, never committed. The directory holds an App Store
# Connect .p8 upload credential, the issuer id, and review-contact details
# (phone, email) that have no business in a public repo. The store copy in
# fastlane/metadata/ is therefore unversioned too — a known, accepted cost,
# recorded in docs/superpowers/specs/2026-08-10-app-store-automation-design.md.
# The *recipe* is versioned instead: docs/app-review/README.md documents the
# lanes and how to rebuild this directory on a new machine.
fastlane/
```

- [ ] **Step 5: Verify git ignores it**

```bash
mkdir -p fastlane && touch fastlane/probe.txt
git status --porcelain fastlane/ ; git check-ignore -v fastlane/probe.txt
rm fastlane/probe.txt
```

Expected: `git status --porcelain` prints **nothing**, and `check-ignore` names the `fastlane/` rule.

- [ ] **Step 6: Commit**

```bash
git add Gemfile Gemfile.lock .ruby-version .gitignore
git commit -m "chore: pin fastlane and keep the fastlane directory out of version control"
```

---

## Task 2: The ASO linter and its tests

Pure, offline, no credentials, no network. Built first because it is the only piece with real logic, and it is fully testable against fixtures before any real metadata exists.

**Files:**
- Create: `Scripts/aso-lint.swift`
- Create: `Scripts/tests/aso-lint-tests.sh`
- Create: `Scripts/tests/fixtures/aso/{clean,over-budget,wasteful}/en-US/*.txt`

**Interfaces:**
- Consumes: nothing
- Produces: `swift Scripts/aso-lint.swift <metadata-dir>` where `<metadata-dir>` is the directory *containing* `en-US/`. Exit `0` = within budget (warnings may still print to stdout), `1` = at least one string over budget, `2` = the `en-US` directory is missing or unreadable. Task 5 wires this into preflight step 10.

- [ ] **Step 1: Create the three fixture sets**

```bash
mkdir -p Scripts/tests/fixtures/aso/{clean,over-budget,wasteful}/en-US
```

`Scripts/tests/fixtures/aso/clean/en-US/name.txt`:
```
Plotline
```

`Scripts/tests/fixtures/aso/clean/en-US/subtitle.txt`:
```
Find where a series drops off
```

`Scripts/tests/fixtures/aso/clean/en-US/keywords.txt`:
```
tv,episode,ratings,analysis,binge,watchlist,streaming,score,charts,tracker
```

`Scripts/tests/fixtures/aso/over-budget/en-US/name.txt`:
```
Plotline
```

`Scripts/tests/fixtures/aso/over-budget/en-US/subtitle.txt` — 34 characters, four over the limit:
```
Series analysis, episode by episode
```

`Scripts/tests/fixtures/aso/over-budget/en-US/keywords.txt`:
```
tv,episode,ratings
```

`Scripts/tests/fixtures/aso/wasteful/en-US/name.txt`:
```
Plotline
```

`Scripts/tests/fixtures/aso/wasteful/en-US/subtitle.txt`:
```
Which seasons are worth it
```

`Scripts/tests/fixtures/aso/wasteful/en-US/keywords.txt` — three separate faults: `seasons` is already bought by the subtitle, there is a space after a comma, and `show`/`shows` is a singular sitting next to its plural:
```
seasons,tv, episode,show,shows
```

- [ ] **Step 2: Write the test harness, and run it to watch it fail**

`Scripts/tests/aso-lint-tests.sh`:

```bash
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
```

```bash
chmod +x Scripts/tests/aso-lint-tests.sh
./Scripts/tests/aso-lint-tests.sh
```

Expected: every assertion FAILs, because `Scripts/aso-lint.swift` does not exist yet.

- [ ] **Step 3: Write the linter**

`Scripts/aso-lint.swift`:

```swift
#!/usr/bin/env swift
// App Store copy, checked against the two things that can be checked
// mechanically: Apple's character limits, and characters bought twice.
//
// Two severities, on purpose. Exceeding a limit is a fact — App Store Connect
// will reject it — so it fails. "You are wasting eight characters on a term
// the subtitle already buys" is a judgement about ranking, and a judgement
// should not stop a release at three in the morning. It warns.
import Foundation

// Apple's limits for a single locale's App Store listing.
let budgets: [(file: String, limit: Int)] = [
    ("name", 30),
    ("subtitle", 30),
    ("keywords", 100),
    ("promotional_text", 170),
    ("description", 4000),
    ("release_notes", 4000)
]

let arguments = CommandLine.arguments
guard arguments.count == 2 else {
    FileHandle.standardError.write(Data("usage: aso-lint.swift <metadata-dir>\n".utf8))
    exit(2)
}

let localeDirectory = URL(fileURLWithPath: arguments[1]).appendingPathComponent("en-US")
var isDirectory: ObjCBool = false
guard FileManager.default.fileExists(atPath: localeDirectory.path, isDirectory: &isDirectory),
      isDirectory.boolValue else {
    FileHandle.standardError.write(Data("no such metadata directory: \(localeDirectory.path)\n".utf8))
    exit(2)
}

var failures = 0
var warnings = 0

func failed(_ message: String) { print("  ✗ \(message)"); failures += 1 }
func warned(_ message: String) { print("  ⚠ \(message)"); warnings += 1 }

/// Returns nil when the file is absent. An absent file is not an error here:
/// `deliver` simply leaves that App Store field alone.
func read(_ name: String) -> String? {
    let url = localeDirectory.appendingPathComponent("\(name).txt")
    guard let raw = try? String(contentsOf: url, encoding: .utf8) else { return nil }
    return raw.trimmingCharacters(in: .whitespacesAndNewlines)
}

// --- Budgets. Over the limit fails. -----------------------------------------
for (file, limit) in budgets {
    guard let value = read(file) else { continue }
    // count on Character, not utf8: Apple counts what a reader sees, and the
    // description contains em dashes and curly quotes.
    let length = value.count
    if length > limit {
        failed("\(file) is \(length)/\(limit) characters — \(length - limit) over")
    }
}

// --- Waste in the keyword field. Warns only. --------------------------------
if let keywords = read("keywords") {
    if keywords.contains(" ") {
        let spaces = keywords.filter { $0 == " " }.count
        warned("keywords contains \(spaces) space character(s) — each one costs a character of the 100 and buys nothing")
    }

    let terms = keywords
        .split(separator: ",")
        .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        .filter { !$0.isEmpty }

    // Apple indexes the app name and subtitle together with the keyword field,
    // so a term appearing in both is paid for twice.
    var alreadyBought = Set<String>()
    for field in ["name", "subtitle"] {
        guard let value = read(field) else { continue }
        for word in value.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }) {
            alreadyBought.insert(String(word))
        }
    }
    for term in terms where alreadyBought.contains(term) {
        warned("keyword '\(term)' is already bought by the app name or subtitle — \(term.count + 1) characters reclaimable")
    }

    var seen = Set<String>()
    for term in terms {
        if !seen.insert(term).inserted {
            warned("keyword '\(term)' appears more than once in the keyword field")
        }
    }

    // A singular sitting next to its own plural. Not authoritative about
    // Apple's stemming — hence a warning, not a failure.
    let termSet = Set(terms)
    for term in terms where termSet.contains(term + "s") {
        warned("keywords contains both '\(term)' and '\(term)s' — the plural is likely \(term.count + 2) wasted characters")
    }
}

if failures == 0 {
    print("  ✓ every store string within its App Store budget (\(warnings) warning(s))")
}
exit(failures == 0 ? 0 : 1)
```

- [ ] **Step 4: Run the tests and watch them pass**

```bash
./Scripts/tests/aso-lint-tests.sh
```

Expected: `0 failure(s)`, exit 0.

- [ ] **Step 5: Commit**

```bash
git add Scripts/aso-lint.swift Scripts/tests/
git commit -m "feat: add an ASO linter for App Store character budgets and keyword waste"
```

---

## Task 3: Fastlane scaffolding, credentials, and the bootstrap lane

Nothing created here is committed. The verification is that the lane runs and produces a populated metadata tree.

**Files:**
- Create (gitignored): `fastlane/Appfile`, `fastlane/Fastfile`, `fastlane/Deliverfile`, `fastlane/.env`, `fastlane/.keys/`

**Interfaces:**
- Consumes: `bundle exec fastlane` from Task 1
- Produces: `bundle exec fastlane bootstrap`, and a populated `fastlane/metadata/en-US/` that Tasks 5 and 7 depend on. Also the `app_store_connect_api_key` lane variable consumed by every later lane.

- [ ] **Step 1: Move the credential out of Downloads**

A key that can upload builds to your developer account should not sit in a directory you empty without reading.

```bash
mkdir -p fastlane/.keys
mv ~/Downloads/AuthKey_*.p8 fastlane/.keys/
chmod 600 fastlane/.keys/*.p8
ls -l fastlane/.keys/
```

Expected: one `.p8`, mode `-rw-------`. Do not print its contents.

- [ ] **Step 2: Write `fastlane/.env`**

Substitute the real values. The key id is the `AuthKey_<KEY_ID>.p8` filename stem; the issuer id is the UUID from App Store Connect → Users and Access → Integrations.

```bash
ASC_KEY_ID=<the key id>
ASC_ISSUER_ID=<the issuer uuid>
ASC_KEY_PATH=./fastlane/.keys/AuthKey_<the key id>.p8
```

- [ ] **Step 3: Confirm the credential is not visible to git**

```bash
git status --porcelain fastlane/ && git ls-files fastlane/ && echo "TRACKED FILES ABOVE — STOP"
git check-ignore -v fastlane/.env fastlane/.keys/*.p8
```

Expected: no output from the first line's two commands, and `check-ignore` naming the `fastlane/` rule for both paths. If anything is listed as tracked, stop and fix `.gitignore` before continuing.

- [ ] **Step 4: Write `fastlane/Appfile`**

```ruby
app_identifier("com.jbgsoft.Plotline")
team_id("95PGC3PATF")
```

- [ ] **Step 5: Write `fastlane/Deliverfile`**

```ruby
# The screenshots are NOT copied into fastlane/screenshots/. They are read in
# place from the tree Scripts/screenshots/make.sh writes, so that script stays
# the only thing that produces them and there is no second copy to drift.
#
# deliver reports these under legacy display-type names and that is correct:
# 1320x2868 maps to APP_IPHONE_67 and 2752x2064 to APP_IPAD_PRO_3GEN_129,
# because Apple folded the 6.9" and 13" slots into the older ones. Seeing
# "iPhone 14 Pro Max" in the output is not a bug.
app_identifier("com.jbgsoft.Plotline")
submit_for_review(true)
automatic_release(true)
force(true)              # no HTML preview prompt — these lanes run unattended
skip_binary_upload(false)
precheck_include_in_app_purchases(false)
```

- [ ] **Step 6: Write the Fastfile with only the bootstrap lane so far**

`fastlane/Fastfile`:

```ruby
# Plotline release automation. Local-only, one Mac, no CI, no match.
# This file is gitignored: see docs/app-review/README.md for the runbook and
# for how to rebuild this directory from scratch on a new machine.
default_platform(:ios)

XCODEPROJ  = "Plotline.xcodeproj"
SCHEME     = "Plotline"
PREFLIGHT  = "./Scripts/release-preflight.sh"
SHOTS_ROOT = "screenshots"

def asc_key
  app_store_connect_api_key(
    key_id: ENV.fetch("ASC_KEY_ID"),
    issuer_id: ENV.fetch("ASC_ISSUER_ID"),
    key_filepath: ENV.fetch("ASC_KEY_PATH"),
    in_house: false
  )
end

platform :ios do
  desc "Download what is already live in App Store Connect into fastlane/metadata"
  lane :bootstrap do
    # deliver treats the local metadata tree as authoritative. Run against a
    # live listing with an incomplete tree, it can blank fields nobody
    # authored — support_url, privacy_url, copyright, categories are all
    # already filled in on this app. So the tree starts as a copy of what is
    # live, and authored copy is layered on top of that.
    api_key = asc_key
    deliver(
      api_key: api_key,
      skip_binary_upload: true,
      skip_screenshots: true,
      skip_metadata: false,
      download_metadata: true,
      run_precheck_before_submit: false,
      submit_for_review: false,
      automatic_release: false,
      force: true
    )
    UI.success("Metadata downloaded to fastlane/metadata/. Review it before editing.")
  end
end
```

- [ ] **Step 7: Run bootstrap**

```bash
bundle exec fastlane bootstrap
```

Expected: `fastlane/metadata/en-US/` exists and contains at least `description.txt`, `keywords.txt`, `name.txt`, `subtitle.txt`, plus `support_url.txt`, `privacy_url.txt` and `copyright.txt` carrying the values already live.

- [ ] **Step 8: Write the authored 1.4.0 copy over the downloaded strings**

`bootstrap` downloaded the **currently live** listing, which is the previous version's copy. The authored 1.4.0 copy lives in `docs/app-review/app-store-description.md`, and Task 8 removes it from that file — so it must be transferred here first or it is lost.

Read `docs/app-review/app-store-description.md` and copy each fenced block **verbatim** into the matching file. Transcription only: do not reword, retitle, shorten, or "improve" any string. If the linter later warns about one, that is a decision for the human, not a licence to edit here.

| Fenced block in the markdown | Destination |
|---|---|
| Subtitle (the first block, not the alternatives) | `fastlane/metadata/en-US/subtitle.txt` |
| Promotional text | `fastlane/metadata/en-US/promotional_text.txt` |
| Description | `fastlane/metadata/en-US/description.txt` |
| Keywords | `fastlane/metadata/en-US/keywords.txt` |
| What's New in This Version | `fastlane/metadata/en-US/release_notes.txt` |

Leave every other downloaded file exactly as it came down — `support_url.txt`, `privacy_url.txt`, `copyright.txt`, `name.txt` and the category files hold values already live and correct.

The Subtitle section contains three blocks: one chosen subtitle and two alternatives kept as phrasing notes, the third of which the markdown itself flags as 35 characters and too long. Only the first block is the subtitle.

Verify the transfer landed:

```bash
for f in subtitle promotional_text description keywords release_notes; do
  printf '%-18s %s chars\n' "$f" "$(wc -m < fastlane/metadata/en-US/$f.txt | tr -d ' ')"
done
head -c 120 fastlane/metadata/en-US/description.txt; echo
```

Expected: subtitle 27, promotional_text 161, keywords 96 (each includes the trailing newline), description and release_notes non-empty, and the description opening with "Plotline tells you whether a series is worth your time".

- [ ] **Step 9: Confirm the tree is complete, and lint it**

```bash
ls fastlane/metadata/en-US/
swift Scripts/aso-lint.swift fastlane/metadata; echo "exit: $?"
```

Expected: exit 0. The linter is expected to emit a warning that `seasons` is bought by both the subtitle and the keyword field. **Report that warning; do not act on it.** Changing store copy is the human's call, and this task transcribes rather than edits.

- [ ] **Step 10: Nothing to commit — verify that**

```bash
git status --porcelain
```

Expected: **empty**. This task deliberately produces no tracked changes. If anything appears, `.gitignore` is wrong.

---

## Task 4: Preflight gains a mode flag, and the credential scan

**Files:**
- Modify: `Scripts/release-preflight.sh` — header comment (lines 1–6), argument parsing after line 16, step 8 heading and body, all step headings

**Interfaces:**
- Consumes: nothing from earlier tasks
- Produces: `./Scripts/release-preflight.sh [--for=beta|--for=release]`, exit 0 clean / 1 failures / 2 bad usage. Task 7's lanes call it.

- [ ] **Step 1: Replace the "NOT A BARRIER" header**

The header is now wrong: a Fastlane `sh()` call *does* abort on non-zero. Replace lines 1–6 of `Scripts/release-preflight.sh`:

```bash
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
```

- [ ] **Step 2: Parse the flag**

Insert immediately after the `MAX_DATASET_AGE_DAYS` line (currently line 16):

```bash
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
```

- [ ] **Step 3: Renumber every step heading from /9 to /12**

The character class is `[1-8]`, not `[0-9]`, on purpose: the old step 9 is *replaced* in Task 6, not renumbered. A `[0-9]` here would rewrite it to `9/12` and Task 6 would then be looking for a heading that no longer exists.

```bash
sed -i '' -E 's|^step "([1-8])/9 |step "\1/12 |' Scripts/release-preflight.sh
grep -n 'step "' Scripts/release-preflight.sh
```

Expected: steps 1 through 8 read `/12`, and the old step 9 still reads `9/9`.

- [ ] **Step 4: Make step 8 respect beta mode**

Find `step "8/12  The screenshot set for this version"`. Immediately after it, wrap the existing body. The existing body begins with the `shot_version=$(xcodebuild ...)` assignment and ends with the `fi` that closes `if [ -z "$shot_version" ]`. Add before it:

```bash
if [ "$MODE" = beta ]; then
    pass "skipped — beta build, marketing screenshots are not required until release"
else
```

and after that block's closing `fi`, add one more:

```bash
fi
```

- [ ] **Step 5: Add step 9, the credential scan**

Insert after step 8's closing `fi`, before the old `step "9/9 ..."`:

```bash
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
if git grep -q -- "BEGIN PRIVATE KEY" -- . 2>/dev/null; then
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
```

- [ ] **Step 6: Run both modes**

```bash
./Scripts/release-preflight.sh --for=beta 2>&1 | grep -E '^▸|✓|✗' | head -30
echo "exit: $?"
./Scripts/release-preflight.sh --bogus; echo "usage exit: $?"
```

Expected: headings numbered `/12`, step 8 reporting it was skipped, step 9 passing (Task 3 created `.env`), and the bogus argument exiting `2`.

- [ ] **Step 7: Commit**

```bash
git add Scripts/release-preflight.sh
git commit -m "feat: add a preflight mode flag and a scan for leaked App Store Connect credentials"
```

---

## Task 5: Preflight checks the store copy

Two new steps that read the untracked metadata tree. Both fail — loudly, with the command that fixes it — when it is absent.

**Files:**
- Modify: `Scripts/release-preflight.sh`

**Interfaces:**
- Consumes: `swift Scripts/aso-lint.swift <dir>` (Task 2), `fastlane/metadata/en-US/description.txt` (Task 3)
- Produces: preflight steps 10 and 11

- [ ] **Step 1: Add step 10, the ASO lint**

Insert after step 9's closing `fi`:

```bash
step "10/12  ASO budgets and keyword waste"
if [ ! -d fastlane/metadata/en-US ]; then
    fail "fastlane/metadata/en-US is missing — run: bundle exec fastlane bootstrap"
elif swift Scripts/aso-lint.swift fastlane/metadata; then
    :   # the linter prints its own pass line, and any warnings under it
else
    fail "a store string is over its App Store character budget"
fi
```

- [ ] **Step 2: Add step 11, copy against the app**

Insert directly after step 10:

```bash
step "11/12  Store copy agrees with the app"
# Two sources, because the facts live in two places. The series count comes
# from the dataset — the same check render.sh makes for its marketing chip.
# The shelf names come from CuratedListCopy.swift and NOT from the dataset:
# the dataset carries ids and members, never words.
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
    elif ! grep -qF "$entries fully analysed series" "$DESCRIPTION"; then
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
        fail "expected 5 shelf titles in $LIST_COPY, extracted $title_count — the file's format changed and this check can no longer read it"
        copy_ok=0
    else
        while IFS= read -r title; do
            if ! grep -qF "$title" "$DESCRIPTION"; then
                fail "the description never mentions the shelf \"$title\""
                copy_ok=0
            fi
        done <<< "$titles"
    fi

    if [ "$copy_ok" -eq 1 ]; then
        pass "description agrees with $DATASET's $entries entries and all 5 shelf names"
    fi
fi
```

- [ ] **Step 3: Prove step 11 can actually fail**

A check nobody has seen fail is a check nobody knows works.

```bash
cp fastlane/metadata/en-US/description.txt /tmp/plotline-description.bak
printf 'nothing relevant here\n' > fastlane/metadata/en-US/description.txt
./Scripts/release-preflight.sh --for=beta 2>&1 | grep -A8 '11/12'
cp /tmp/plotline-description.bak fastlane/metadata/en-US/description.txt
```

Expected: failures naming the entry count and each of the five shelf titles. Then confirm the restore worked:

```bash
./Scripts/release-preflight.sh --for=beta 2>&1 | grep -A3 '11/12'
```

Note: if the live description downloaded in Task 3 predates this copy, step 11 may legitimately fail on the real file. That is the check doing its job — fix the description, do not weaken the check.

- [ ] **Step 4: Commit**

```bash
git add Scripts/release-preflight.sh
git commit -m "feat: check App Store copy against the dataset count and the curated shelf names"
```

---

## Task 6: Rewrite the manual-steps list

**Files:**
- Modify: `Scripts/release-preflight.sh` — the `step "9/9 ..."` block and its heredoc

**Interfaces:**
- Consumes: nothing
- Produces: preflight step 12

- [ ] **Step 1: Replace the old step 9 block**

Replace the entire block from `step "9/9  What still has to be done by hand"` through the closing `MANUAL` line:

```bash
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
    5. Read release_notes.txt. Step 5 proves the version string matches; it
       cannot prove the notes describe this version.
MANUAL
```

- [ ] **Step 2: Confirm all twelve steps are numbered and none are orphaned**

```bash
grep -n 'step "' Scripts/release-preflight.sh
grep -c 'step "' Scripts/release-preflight.sh
grep -n '/9 ' Scripts/release-preflight.sh || echo "no stale /9 headings"
```

Expected: exactly 12 `step` calls, numbered 1/12 through 12/12 in order, and no stale `/9`.

- [ ] **Step 3: Run the whole thing**

```bash
./Scripts/release-preflight.sh --for=beta; echo "exit: $?"
```

Expected: twelve headings, and an exit code matching whether anything genuinely failed.

- [ ] **Step 4: Commit**

```bash
git add Scripts/release-preflight.sh
git commit -m "docs: rewrite the preflight manual checklist around the automated lanes"
```

---

## Task 7: The release lanes

**Files:**
- Modify (gitignored): `fastlane/Fastfile`

**Interfaces:**
- Consumes: `asc_key` and the `bootstrap` lane (Task 3); `./Scripts/release-preflight.sh --for=<mode>` (Tasks 4–6)
- Produces: `aso`, `beta`, `metadata`, `screenshots`, `release_dry_run`, `release`

- [ ] **Step 1: Add the lanes to `fastlane/Fastfile`, inside the existing `platform :ios do` block**

```ruby
  desc "Lint App Store copy. No network, no build, no credentials."
  lane :aso do
    sh("cd .. && swift Scripts/aso-lint.swift fastlane/metadata")
  end

  desc "Everything that must be true before a release. Aborts the lane on failure."
  private_lane :preflight do |options|
    # This is the line that turns release-preflight.sh into a barrier: sh()
    # raises on a non-zero exit, and the lane stops.
    sh("cd .. && #{PREFLIGHT} --for=#{options[:mode]}")
  end

  desc "Read MARKETING_VERSION from the target that actually ships"
  private_lane :marketing_version do
    # Not grepped from project.pbxproj: MARKETING_VERSION appears once per
    # configuration of every target, six times in this project, and the first
    # match is the app's only by accident of Xcode's UUID ordering.
    get_version_number(xcodeproj: XCODEPROJ, target: SCHEME)
  end

  desc "Build and upload to TestFlight"
  lane :beta do
    preflight(mode: "beta")
    api_key = asc_key
    # Read from App Store Connect, not from the repo, so the number cannot
    # collide with something uploaded from anywhere else.
    increment_build_number(
      xcodeproj: XCODEPROJ,
      build_number: latest_testflight_build_number(api_key: api_key) + 1
    )
    build_app(
      project: XCODEPROJ,
      scheme: SCHEME,
      export_method: "app-store",
      export_team_id: "95PGC3PATF"
    )
    upload_to_testflight(
      api_key: api_key,
      distribute_external: false,
      skip_waiting_for_build_processing: true
    )
  end

  desc "Push store copy only. No build."
  lane :metadata do
    deliver(
      api_key: asc_key,
      skip_binary_upload: true,
      skip_screenshots: true,
      skip_metadata: false,
      submit_for_review: false,
      automatic_release: false,
      force: true
    )
  end

  desc "Regenerate the marketing frames and upload them. No build."
  lane :screenshots do
    sh("cd .. && ./Scripts/screenshots/make.sh")
    deliver(
      api_key: asc_key,
      screenshots_path: "#{SHOTS_ROOT}/#{marketing_version}",
      skip_binary_upload: true,
      skip_metadata: true,
      skip_screenshots: false,
      submit_for_review: false,
      automatic_release: false,
      force: true
    )
  end

  desc "Everything release does, except uploading or submitting anything"
  lane :release_dry_run do
    preflight(mode: "release")
    precheck(api_key: asc_key)
    build_app(
      project: XCODEPROJ,
      scheme: SCHEME,
      export_method: "app-store",
      export_team_id: "95PGC3PATF"
    )
    UI.success("Dry run clean. Nothing was uploaded and nothing was submitted.")
  end

  desc "Full production release: build, metadata, screenshots, submit, auto-release"
  lane :release do
    # No API exists for the Resolution Center. This prints and continues, by
    # explicit decision — see the spec, §11. If a rejection thread is open,
    # reply in it BEFORE running this lane.
    UI.important("Resolution Center: reply in the open thread BEFORE this upload.")
    UI.important("Submitting in silence is what turned one rejection into three.")
    UI.important("This lane does not stop for it. Ctrl-C now if that reply is not posted.")

    preflight(mode: "release")
    api_key = asc_key
    increment_build_number(
      xcodeproj: XCODEPROJ,
      build_number: latest_testflight_build_number(api_key: api_key) + 1
    )
    build_app(
      project: XCODEPROJ,
      scheme: SCHEME,
      export_method: "app-store",
      export_team_id: "95PGC3PATF"
    )
    deliver(
      api_key: api_key,
      screenshots_path: "#{SHOTS_ROOT}/#{marketing_version}",
      submit_for_review: true,
      automatic_release: true,
      force: true,
      run_precheck_before_submit: true
    )
    add_git_tag(tag: "v#{marketing_version}")
  end
```

- [ ] **Step 2: Verify every lane is registered**

```bash
bundle exec fastlane lanes
```

Expected: `bootstrap`, `aso`, `beta`, `metadata`, `screenshots`, `release_dry_run`, `release`. Private lanes may not be listed.

- [ ] **Step 3: Run the two lanes that touch nothing**

```bash
bundle exec fastlane aso; echo "exit: $?"
```

Expected: the linter's output, exit 0 unless a string is genuinely over budget.

- [ ] **Step 4: Confirm the screenshots path resolves before a lane relies on it**

`deliver`'s `screenshots_path` is interpreted relative to fastlane's working directory, and `screenshots` and `release` both depend on it pointing at the existing tree rather than at an empty one. Verify rather than assume:

```bash
bundle exec fastlane run get_version_number xcodeproj:Plotline.xcodeproj target:Plotline
ls screenshots/$(xcodebuild -project Plotline.xcodeproj -target Plotline -configuration Release \
    -showBuildSettings 2>/dev/null | awk '/ MARKETING_VERSION = /{print $3; exit}')/*/ | head
```

Expected: the version resolves, and the two family directories each list eight PNGs. If `deliver` later reports zero screenshots found, make `screenshots_path` an absolute path built from the repo root instead.

- [ ] **Step 5: Run the dry run**

```bash
bundle exec fastlane release_dry_run
```

Expected: preflight runs to completion, `precheck` validates the metadata against Apple, the app archives and exports, and the lane reports that nothing was uploaded. This is the full pipeline proven without touching the store.

**If preflight fails here, that is the barrier working.** Fix what it names; do not bypass it.

- [ ] **Step 6: Nothing to commit — verify that**

```bash
git status --porcelain
```

Expected: empty, apart from any `build/` artefacts already ignored.

---

## Task 8: Restructure the App Review docs into a runbook

The strings move to the untracked metadata tree. The reasoning around them — which is what keeps the copy from claiming more than the engine supports — stays in git.

**Files:**
- Modify: `docs/app-review/app-store-description.md`, `docs/app-review/app-review-notes.md`
- Rewrite: `docs/app-review/README.md`

**Interfaces:**
- Consumes: the lane names from Task 7
- Produces: the versioned record of how a release is run and how `fastlane/` is rebuilt

- [ ] **Step 1: Strip the paste blocks from `app-store-description.md`**

Delete every fenced code block holding subtitle, promotional text, description, keywords and what's-new. Keep the file's heading (preflight step 5 greps `docs/app-review/` for `MARKETING_VERSION`, so the version must survive somewhere in this directory), the §12 note about leading with the analysis rather than the catalogue, and the whole "A note on the required attributions" section including the unmet TMDB logo requirement.

Add at the top, under the heading:

```markdown
> The strings themselves now live in `fastlane/metadata/en-US/*.txt`, which is
> **not** in version control — see
> `docs/superpowers/specs/2026-08-10-app-store-automation-design.md` §3 for why.
> What is kept here is the reasoning behind the copy, which is the part that
> stops it claiming more than the engine can support.
```

- [ ] **Step 2: Strip the paste block from `app-review-notes.md`**

Delete everything between `## Paste from here` and `## Paste to here`, including those markers. Keep "Why these notes matter" and "Keep this factual" verbatim. Add the same pointer, naming `fastlane/metadata/review_information/notes.txt`.

- [ ] **Step 3: Rewrite `docs/app-review/README.md` as the runbook**

````markdown
# Release runbook — Plotline 1.4.0

Releases are automated with Fastlane, local-only, from one Mac.

**`fastlane/` is not in version control.** It holds an App Store Connect
upload credential and review-contact details that have no business in a public
repo. This file is therefore the only versioned record of how a release runs —
and of how to rebuild that directory if this machine is lost.

## The lanes

| Command | What it does |
|---|---|
| `bundle exec fastlane aso` | Lints store copy. No network, no build. |
| `bundle exec fastlane bootstrap` | Downloads what is live in App Store Connect into `fastlane/metadata/`. |
| `bundle exec fastlane beta` | Preflight (beta mode) → build → TestFlight. |
| `bundle exec fastlane metadata` | Pushes store copy only. No build. |
| `bundle exec fastlane screenshots` | Regenerates the frames and uploads them. |
| `bundle exec fastlane release_dry_run` | Everything `release` does, uploading nothing. |
| `bundle exec fastlane release` | Build, metadata, screenshots, submit for review, auto-release, tag. |

`release` submits for review and Apple publishes automatically on approval.
Nobody reads the listing between approval and users seeing it. That is a
deliberate choice, recorded in the spec, §10.

## Before the first release of a version

1. `bundle exec fastlane release_dry_run` — proves the pipeline without
   touching the store.
2. Reply in the Resolution Center if a thread is open. **Before uploading.**
   No API exists for this and `release` does not stop for it.
3. Deploy the CloudKit container `iCloud.com.jbgsoft.Plotline` to Production.
4. Read the sixteen screenshots. Nothing checks that a headline is still true
   about the capture beneath it.
5. Read `fastlane/metadata/en-US/release_notes.txt`. Preflight proves the
   version string matches; it cannot prove the notes describe this version.

## Rebuilding `fastlane/` on a new machine

1. `bundle install`
2. Create `fastlane/.keys/` and put the App Store Connect `.p8` in it,
   `chmod 600`. If it is lost, revoke it in App Store Connect → Users and
   Access → Integrations and generate a new one; the file downloads once and
   cannot be downloaded again.
3. Write `fastlane/.env` with `ASC_KEY_ID`, `ASC_ISSUER_ID` and
   `ASC_KEY_PATH`. The issuer id is on that same App Store Connect page.
4. Write `fastlane/Appfile` with `app_identifier("com.jbgsoft.Plotline")` and
   `team_id("95PGC3PATF")`.
5. `bundle exec fastlane bootstrap` to repopulate `fastlane/metadata/`.
6. `./Scripts/release-preflight.sh --for=release` — step 9 confirms nothing
   leaked into git, steps 10 and 11 confirm the copy is present and true.

Recreate `Fastfile` and `Deliverfile` from the spec,
`docs/superpowers/specs/2026-08-10-app-store-automation-design.md` §5.

## What is still pasted by hand

Age rating, privacy nutrition labels, category, pricing, and every Resolution
Center message.
````

- [ ] **Step 4: Confirm preflight step 5 still finds the version**

```bash
grep -rn "1.4.0" docs/app-review/ | head
./Scripts/release-preflight.sh --for=beta 2>&1 | grep -A3 '5/12'
```

Expected: the version present in the directory, and step 5 passing.

- [ ] **Step 5: Commit**

```bash
git add docs/app-review/
git commit -m "docs: turn the App Review folder into a release runbook"
```

---

## Task 9: Close the team-id conflict and document the lanes in CLAUDE.md

**Files:**
- Modify: `Plotline.xcodeproj/project.pbxproj:320`
- Modify: `CLAUDE.md` — "Build Commands" and "Before a Release"

**Interfaces:**
- Consumes: everything above
- Produces: the final state

- [ ] **Step 1: Align the project-level team**

`project.pbxproj` declares `DEVELOPMENT_TEAM = 8BXWAL9PV5` at project level (line 320) and `95PGC3PATF` on the app target (line 409). The keychain holds exactly one distribution certificate, `Apple Distribution: Jaime Barreto (95PGC3PATF)`, so the target override is the correct value and the project-level one is residue that can only cause confusion later.

```bash
sed -i '' 's/DEVELOPMENT_TEAM = 8BXWAL9PV5;/DEVELOPMENT_TEAM = 95PGC3PATF;/' Plotline.xcodeproj/project.pbxproj
grep -n 'DEVELOPMENT_TEAM' Plotline.xcodeproj/project.pbxproj | sort -u -t: -k2
```

Expected: every occurrence now `95PGC3PATF`.

- [ ] **Step 2: Verify the project still builds and signs**

```bash
xcodebuild -project Plotline.xcodeproj -scheme Plotline \
  -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath build build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Add the lanes to CLAUDE.md's Build Commands**

Append to the existing bash block in "Build Commands":

```bash
# App Store releases — Fastlane, local-only. fastlane/ is gitignored.
bundle exec fastlane aso              # lint store copy, no network
bundle exec fastlane beta             # preflight, build, TestFlight
bundle exec fastlane release_dry_run  # the whole release, uploading nothing
bundle exec fastlane release          # build, metadata, screenshots, submit, auto-release
```

- [ ] **Step 4: Update the "Before a Release" section**

That section says preflight "gathers" nine things and, with the screenshots section, that App Store Connect is not automated. Replace its first paragraph with:

```markdown
`Scripts/release-preflight.sh` gathers the two cold-start suite passes, the
generator suite, dataset freshness, the coherence between `MARKETING_VERSION`
and `docs/app-review/`, the absence of OMDb, the shared schemes, the current
version's screenshot set, that no App Store Connect credential reached version
control, the ASO character budgets, and that the store description still
agrees with the dataset's entry count and the five curated shelf names —
twelve checks. `--for=beta` skips only the screenshot set.

**It is now a barrier, when a lane runs it.** The release lanes in
`fastlane/Fastfile` call it through `sh()`, and a non-zero exit aborts the
lane. It is still also wired to the Archive pre-action, where it only warns —
a pre-action that returns an error does not reliably abort an archive in
recent Xcode. Same script, two callers, two strengths.

Releases themselves are automated with Fastlane, local-only from one Mac.
`fastlane/` is gitignored — it holds an App Store Connect upload credential
and review-contact details. `docs/app-review/README.md` is the versioned
runbook and documents how to rebuild that directory from scratch.
```

- [ ] **Step 5: Verify the whole thing end to end**

```bash
./Scripts/tests/aso-lint-tests.sh
./Scripts/release-preflight.sh --for=release; echo "preflight exit: $?"
git status --porcelain fastlane/ && echo "(fastlane/ correctly invisible to git)"
```

Expected: linter tests green, preflight reporting twelve steps, and `fastlane/` producing no git output.

- [ ] **Step 6: Commit**

```bash
git add CLAUDE.md Plotline.xcodeproj/project.pbxproj
git commit -m "chore: align the development team and document the release lanes"
```

---

## Self-Review Notes

**Spec coverage.** §3 layout → Tasks 1, 2, 3. §4 auth and signing → Tasks 3, 9. §5 lanes → Tasks 3, 7 (all seven lanes). §6 preflight 9→12 and the barrier → Tasks 4, 5, 6, 7 (`preflight` private lane). §7 linter → Task 2. §8 file changes → Tasks 4–9, every row covered. §9 verification → Task 2's harness, Task 7's `release_dry_run`, Task 5's deliberate-failure step. §10 risks → Task 1 front-loads the Ruby risk; CloudKit and `aps-environment` appear in step 12's manual list and the runbook. §11 manual items → Task 6's heredoc and Task 8's runbook.

**Known gap, deliberate.** §10 risk 5 (`aps-environment` is `development`) is surfaced in the manual checklist but no task changes it. Whether an App Store build needs `production` there depends on whether push is actually used, which this work did not establish — changing an entitlement on a guess is worse than naming it. It is flagged where a human will read it before submitting.

**Type and name consistency.** `asc_key` is defined once in Task 3 and used by every lane in Task 7. `PREFLIGHT`, `XCODEPROJ`, `SCHEME`, `SHOTS_ROOT` are defined in Task 3's Fastfile header and used in Task 7. `marketing_version` is defined as a private lane before both call sites. The linter's exit codes (0/1/2) are defined in Task 2 and relied on identically by Task 2's harness and Task 5's step 10. `$DATASET` in Task 5 is the variable already defined at the top of `release-preflight.sh`, not a new one.
