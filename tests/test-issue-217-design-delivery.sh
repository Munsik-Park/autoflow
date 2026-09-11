#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: docs/adr/**
# lane: cycle-scoped
# retire-with: #217
# cycle-arm: #217
# budget-secs: SUITE_BUDGET_CEILING_SECS
# =============================================================================
# Test: issue #217 design delivery — the eight `delivery-check` rows of
# .autoflow/issue-217-verification-design.md, one check group per row.
# =============================================================================
# WHAT THIS IS. Issue #217 ships no runtime change that can fail: every
# acceptance-criterion row is typed `delivery-check`, so RED/GREEN semantics do
# not apply (ADR-0022 decision 2) and no `driving` test exists to fail first.
# What can be wrong is the COMPLETENESS OF THE RECORD — a decision the ADR never
# fixes, an enumerated rule no disposition word claims, a superseded record that
# still reads as governing. Each group below is the executable form of one row's
# `Method` cell, and its failure message is that row's `Failure mode` cell.
#
# ADMISSION (docs/autoflow-guide.md > RED > Admission), answered before this
# file existed:
#   - Does an existing standing lint hold the property tree-wide? NO. This tree
#     has no `tests/*adr*` suite and no suite asserting README-row ↔ `## Status`
#     agreement; GATE:QUALITY's reference-integrity sweep triggers on relocation
#     and renaming, which this cycle's diff does not perform, so it never fires
#     (verification design > *Removed from the agreement*).
#   - Is the check delivery-pinned to this cycle's landed diff? YES — its
#     subject is the documents this cycle lands. Hence `lane: cycle-scoped` with
#     `retire-with: #217`, the default for that answer, not an exception.
#   - Does the check compare against a checked-in basis? NO. It asserts presence
#     and disposition in the delivered document set; it resolves no base ref and
#     reads no out-of-tree state, so no `out-of-tree-inputs` declaration is owed.
#
# ONE FILE, EIGHT GROUPS. The eight rows read ONE subject surface (`docs/adr/**`
# — ADR-0024, the ADR registry, and the two ADRs whose status records the cycle
# repairs), so eight files would be eight headers, eight CI steps and eight
# retirements over one subject. Each row keeps its own failure mode
# distinguishable through its `AC…:` message prefix, which is what the
# one-check-per-unique-failure-mode rule protects. The leaf rule holds: this
# suite invokes no other suite.
#
# THE DELIVERED FORM THESE CHECKS READ (the feature design's own form, so that
# GREEN transcribing the design satisfies them):
#   - ADR-0024 is the single file matching `docs/adr/0024-*.md`, and it carries
#     BOTH the D1–D6 decision record AND the adjustment-scope table (feature
#     design > *Deliverable*: "a new ADR … recording … decisions D1–D6 and
#     ADR-0019's supersede scope — plus the confirmed adjustment scope").
#   - A DECISION ENTRY is a structural line naming the decision: a markdown
#     heading, or a bold-lead list item (`1. **D1 …**`, `- **D1 …**`), which is
#     the form ADR-0019/0022 already use under `## Decision`.
#   - An ADJUSTMENT-SCOPE ROW is a markdown table row `| <rule or device> |
#     <disposition> |`. "Carries exactly one of the closed vocabulary" is read
#     as: the disposition cell LEADS with exactly one of `deleted` / `replaced`
#     / `retained` / `conditional`. A later vocabulary word inside the same
#     cell's reason text is part of the reason, not a second disposition — the
#     feature design's own Area-2 doc-remedy row has that shape.
#   - The one admitted exception is the `docs/adr/README.md` ADR-0024 row, which
#     the feature design declares `additive` ("a new record, not a fate of an
#     existing rule; outside the four-word vocabulary by construction").
#
# ROW → GROUP MAP (verification design > Acceptance-criteria table):
#   AC1a  ADR-0024's decision headings × {M, D1–D6, ADR-0019 d1/d2/d3, the
#         register, the shared store}. Fails when a decision or a supersede row
#         is absent, so a sub-issue implements what the record never fixed.
#   AC1b  the two-sided supersede/amend records: both `## Status` bodies and
#         both README rows in composite form, plus the additive 0024 row. Fails
#         when ADR-0024 lands while ADR-0019/0022 still read as governing —
#         every link resolves, so no reference check fires.
#   AC2   closed-vocabulary join over the issue body's Area-1 enumeration.
#   AC3   the single declared prefix `.autoflow/issue-{N}-local/` AND the
#         standing tracked-file predicate assigned to a named sub-issue.
#   AC4   closed-vocabulary join over Area-2, including ADR-0019 d3's retained
#         obligations and their re-homed governing record.
#   AC5   the opt-in declaration site × the one shared resolver × each of
#         {header contract, selector, D7} calling it.
#   AC6   both unconditional-route sites, the three classifier stages, and the
#         fail-closed rule cited at `docs/autoflow-guide.md:1814`.
#   AC7   closed-vocabulary join over Area-3, extended to the `lane:
#         cycle-scoped` dependents (GATE:PLAN finding F-1) and the five ADR
#         status/registry sites.
#
# The Area-1/2/3 subjects below are the ISSUE BODY's own enumeration
# (.autoflow/issue-217-body.md > `### 조정 범위`), which is what AC2/AC4/AC7's
# "모두 / 일치" is a set relation over. Each is matched by the citation the
# feature design's table carries for it, with a subject phrase as the
# alternative, so a row that cites the site under either spelling is found.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# The fixed set of delivered documents this cycle-scoped suite is licensed to
# read — ADR-0024 itself (slug fixed at GREEN, so the row is the glob the
# feature design writes), the ADR registry, and the two ADRs whose status
# records the cycle repairs. Declared as a path allow-list array per
# scripts/test/suite-manifest.sh's cycle-scoped grammar; the array is the
# suite's own existence precondition below, not a decorative declaration.
allow_list=(
  "docs/adr/0024-*.md"
  "docs/adr/README.md"
  "docs/adr/0019-scope-fit-verification-policy.md"
  "docs/adr/0022-test-necessity-and-three-tier-ac-guard.md"
)

PASS=0
FAIL=0
pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
failc() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

# ---------------------------------------------------------------------------
# Subjects
# ---------------------------------------------------------------------------
ADR=""
for cand in "$PROJECT_ROOT"/docs/adr/0024-*.md; do
  [ -f "$cand" ] || continue
  ADR="$cand"
  break
done
ADR_NAME="${ADR#"$PROJECT_ROOT"/}"
README="$PROJECT_ROOT/docs/adr/README.md"
ADR19="$PROJECT_ROOT/docs/adr/0019-scope-fit-verification-policy.md"
ADR22="$PROJECT_ROOT/docs/adr/0022-test-necessity-and-three-tier-ac-guard.md"

# Newline-normalised body, so a proximity assertion is not defeated by the
# document's own line wrapping.
NORM=""
if [ -n "$ADR" ]; then
  NORM="$(tr '\n' ' ' < "$ADR" | tr -s ' ')"
fi

# Full-file line extractions, computed once and reused by the primitives below
# instead of re-scanning the same unchanging file on every one of their many
# calls (expect_disposition/adr_decision_entry/readme_row are each called
# repeatedly over the same subject).
ADR_TABLE_ROWS=""
ADR_DECISION_LINES=""
if [ -n "$ADR" ]; then
  ADR_TABLE_ROWS="$(grep -E '^[[:space:]]*\|' "$ADR")"
  ADR_DECISION_LINES="$(grep -E '^[[:space:]]*(#{2,6}[[:space:]]|([-*]|[0-9]+\.)[[:space:]]*\*\*|\*\*)' "$ADR")"
fi
README_TABLE_ROWS=""
if [ -f "$README" ]; then
  README_TABLE_ROWS="$(grep -E '^[[:space:]]*\|' "$README")"
fi

echo "=============================================="
echo "issue #217 design delivery — cycle-scoped checks"
echo "=============================================="
for want in "${allow_list[@]}"; do
  # shellcheck disable=SC2086
  if compgen -G "$PROJECT_ROOT/$want" >/dev/null 2>&1; then
    echo "  SUBJECT: $want present"
  else
    echo "  SUBJECT: $want ABSENT — the checks over it fail below"
  fi
done
echo

# ---------------------------------------------------------------------------
# Primitives
# ---------------------------------------------------------------------------
no_adr() {
  failc "$1 — no docs/adr/0024-*.md in the tree (the cycle's deliverable is absent)"
}

# adr_has <ere> <label> — the pattern occurs anywhere in ADR-0024's body.
adr_has() {
  local rx="$1" label="$2"
  if [ -z "$ADR" ]; then no_adr "$label"; return; fi
  if printf '%s' "$NORM" | grep -qiE "$rx"; then
    pass "$label"
  else
    failc "$label — no match for /$rx/ in $ADR_NAME"
  fi
}

# adr_near <ere-a> <ere-b> <window> <label> — both patterns occur within
# <window> BYTES of each other, in either order.
#
# Written as an offset comparison rather than as one `($a).{0,$w}($b)` regex,
# because a bounded repetition above 255 is not portable: the BSD grep of a
# macOS host rejects it outright ("maximum repetition exceeds 255", exit 2), and
# a `grep -q` call reads that failure as "no match" — a silent FAIL on a
# conforming document, on the developer host only, invisible in CI. `grep -ob`
# reports every match's offset on both greps, so the distance is computed here
# instead of being asked of the regex engine. Byte distance rather than
# character distance is deliberate and harmless: multi-byte punctuation only
# shortens the effective reach, and every window below is set well above the
# span its two patterns actually need.
adr_near() {
  local a="$1" b="$2" w="$3" label="$4" pa pb x y d
  if [ -z "$ADR" ]; then no_adr "$label"; return; fi
  pa="$(printf '%s' "$NORM" | grep -obiE "$a" 2>/dev/null | cut -d: -f1)"
  pb="$(printf '%s' "$NORM" | grep -obiE "$b" 2>/dev/null | cut -d: -f1)"
  if [ -z "$pa" ]; then
    failc "$label — no match for /$a/ in $ADR_NAME"
    return
  fi
  if [ -z "$pb" ]; then
    failc "$label — no match for /$b/ in $ADR_NAME"
    return
  fi
  for x in $pa; do
    for y in $pb; do
      d=$((x - y))
      [ "$d" -lt 0 ] && d=$(( -d ))
      if [ "$d" -le "$w" ]; then
        pass "$label"
        return
      fi
    done
  done
  failc "$label — /$a/ and /$b/ both occur in $ADR_NAME but never within $w bytes of each other"
}

# adr_decision_entry <ere> <label> — a structural line (heading, or a bold-lead
# list item) naming the decision.
adr_decision_entry() {
  local rx="$1" label="$2"
  if [ -z "$ADR" ]; then no_adr "$label"; return; fi
  if printf '%s\n' "$ADR_DECISION_LINES" | grep -qE "$rx"; then
    pass "$label"
  else
    failc "$label — no decision entry (heading or bold-lead list item) matching /$rx/ in $ADR_NAME"
  fi
}

# row_cell <row-text> <n> — the n-th cell of a markdown table row, with `\|`
# escapes preserved (the Area-1 runner/selector row carries one).
row_cell() {
  printf '%s' "$1" | sed 's/\\|/@@PIPE@@/g' | awk -F'|' -v n="$2" '{ print $(n + 1) }' | sed 's/@@PIPE@@/|/g'
}

leading_word() {
  printf '%s' "$1" | sed -e 's/[*`_]//g' -e 's/^[[:space:]]*//' -e 's/^\([A-Za-z][A-Za-z-]*\).*/\1/' | cut -c1-40
}

# expect_disposition <subject-ere> <label> [extra-admitted-word]
expect_disposition() {
  local rx="$1" label="$2" extra="${3:-}" row cell word
  if [ -z "$ADR" ]; then no_adr "$label"; return; fi
  row="$(printf '%s\n' "$ADR_TABLE_ROWS" | grep -iE "$rx" | head -n 1)"
  if [ -z "$row" ]; then
    failc "$label — no adjustment-scope row matching /$rx/ in $ADR_NAME"
    return
  fi
  cell="$(row_cell "$row" 2)"
  word="$(leading_word "$cell")"
  case "$word" in
    deleted|replaced|retained|conditional)
      pass "$label — disposition '$word'" ;;
    *)
      if [ -n "$extra" ] && [ "$word" = "$extra" ]; then
        pass "$label — disposition '$word'"
      else
        failc "$label — the row's disposition cell leads with '${word:-<empty>}', not one of deleted|replaced|retained|conditional${extra:+|$extra}"
      fi
      ;;
  esac
}

# status_body <adr-path> — the text of the ADR's `## Status` section.
status_body() {
  awk '/^## Status/ { f = 1; next } /^## / { if (f) exit } f' "$1"
}

# readme_row <link-fragment-ere> — the registry row linking that ADR file.
readme_row() {
  [ -f "$README" ] || return 1
  printf '%s\n' "$README_TABLE_ROWS" | grep -iE "$1" | head -n 1
}

# =============================================================================
# AC1a — ADR-0024's decision record is complete
# Failure mode: ADR-0024 lands but one decision or one ADR-0019 supersede row is
# absent, so a sub-issue implements a decision the record never fixed and a
# later cycle re-derives it differently.
# =============================================================================
echo "-- AC1a: ADR-0024 decision record"
adr_decision_entry 'two-layer|two layer|(^|[^A-Za-z0-9])M[[:space:]]*(—|–|-|:)' \
  "AC1a: decision entry for M (the two-layer verification model)"
for d in 1 2 3 4 5 6; do
  adr_decision_entry "(^|[^A-Za-z0-9])D$d([^0-9]|\$)" \
    "AC1a: decision entry for D$d"
done
adr_near 'decisions?[[:space:]]+1([^0-9]|$)' 'supersed' 300 \
  "AC1a: ADR-0019 decision 1 carries a recorded supersede scope"
adr_near 'decisions?[[:space:]]+2([^0-9]|$)|decisions?[[:space:]]+1[^A-Za-z0-9]{1,3}2' 'supersed' 300 \
  "AC1a: ADR-0019 decision 2 carries a recorded supersede scope"
adr_near 'decisions?[[:space:]]+3([^0-9]|$)|decisions?[[:space:]]+1[^A-Za-z0-9]{1,3}3' 'supersed' 300 \
  "AC1a: ADR-0019 decision 3 carries a recorded supersede scope"
adr_near 'green-tree register' 'retire|supersed|deleted' 300 \
  "AC1a: the Green-tree register's fate is recorded"
adr_near 'shared store' 'retire|supersed|deleted' 300 \
  "AC1a: the shared store's fate is recorded"
echo

# =============================================================================
# AC1b — the superseded/amended records stopped presenting themselves as
# governing.
# Failure mode: ADR-0024 lands while ADR-0019's and ADR-0022's own records still
# read as unsuperseded and unamended — every link resolves, so no reference
# check fires, and the next cycle's ADR-conformance check reads a superseded
# decision as governing (docs/autoflow-guide.md:734; docs/adr/0018-…:101).
# =============================================================================
echo "-- AC1b: two-sided supersede/amend records"

# check_composite_status <text> <rel-ere> <label> <subject-phrase> — the
# shared three-step "does this composite status record supersede/amend
# ADR-0024" check both AC1b sites below need, differing only in what text and
# subject phrase they supply (a '## Status' section body vs. a registry row's
# status cell).
check_composite_status() {
  local text="$1" rel="$2" label="$3" subject="$4"
  if ! printf '%s' "$text" | grep -qE 'Proposed|Accepted|Deprecated|Superseded'; then
    failc "$label — $subject carries no base status word, so the composite form is not present"
    return
  fi
  if ! printf '%s' "$text" | grep -qiE 'ADR-0024|0024-'; then
    failc "$label — $subject does not reference ADR-0024"
    return
  fi
  if ! printf '%s' "$text" | grep -qiE "$rel"; then
    failc "$label — $subject references ADR-0024 but records no /$rel/ relation"
    return
  fi
  pass "$label"
}

check_status_line() {
  # $1 file, $2 human name, $3 relation ERE (supersed|amend), $4 label
  local file="$1" name="$2" rel="$3" label="$4" body
  if [ ! -f "$file" ]; then failc "$label — $name not found"; return; fi
  body="$(status_body "$file" | tr '\n' ' ' | tr -s ' ')"
  check_composite_status "$body" "$rel" "$label" "the '## Status' section"
}

check_readme_row() {
  # $1 link ERE, $2 relation ERE, $3 label
  local rx="$1" rel="$2" label="$3" row cell
  if [ ! -f "$README" ]; then failc "$label — docs/adr/README.md not found"; return; fi
  row="$(readme_row "$rx")"
  if [ -z "$row" ]; then failc "$label — no registry row matching /$rx/"; return; fi
  cell="$(row_cell "$row" 2)"
  check_composite_status "$cell" "$rel" "$label" "the registry row's status cell"
}

check_status_line "$ADR19" "docs/adr/0019-scope-fit-verification-policy.md" 'supersed' \
  "AC1b: ADR-0019 '## Status' records the supersede in composite form"
check_readme_row '0019-scope-fit-verification-policy\.md' 'supersed' \
  "AC1b: docs/adr/README.md's ADR-0019 row records the supersede in composite form"
check_status_line "$ADR22" "docs/adr/0022-test-necessity-and-three-tier-ac-guard.md" 'amend' \
  "AC1b: ADR-0022 '## Status' records the amendment in composite form"
check_readme_row '0022-test-necessity-and-three-tier-ac-guard\.md' 'amend' \
  "AC1b: docs/adr/README.md's ADR-0022 row records the amendment in composite form"
if [ ! -f "$README" ]; then
  failc "AC1b: docs/adr/README.md carries the additive ADR-0024 row — README not found"
elif [ -n "$(readme_row '0024-[A-Za-z0-9-]*\.md')" ]; then
  pass "AC1b: docs/adr/README.md carries the additive ADR-0024 row"
else
  failc "AC1b: docs/adr/README.md carries no row linking 0024-*.md — the new record is unregistered"
fi
echo

# =============================================================================
# AC2 — closed-vocabulary join over the issue body's Area-1 enumeration.
# Failure mode: an enumerated local-execution rule carries no disposition word,
# so no sub-issue owns it and the phase still requires the run AC2 forbids.
# =============================================================================
echo "-- AC2: Area 1 ([MUST]/[DENY] local-execution rules)"
expect_disposition ':1462([^0-9]|$)|VALIDATE step 1' \
  "AC2/A1-1: VALIDATE step 1 whole-tree sweep and its quiesce (guide:1462, :1464)"
expect_disposition ':949([^0-9]|$)|GREEN step 5' \
  "AC2/A1-2: GREEN step 5 / VERIFY step 1 / REFINE step 2 capture-point run (guide:949, :985, :1413-1416)"
expect_disposition ':900([^0-9]|$)|whole-tree[- ]run' \
  "AC2/A1-3: whole-tree-run prohibition (guide:900, autoflow-implementer.md:38)"
expect_disposition 'submodule-common-rules\.md:262|runner/selector' \
  "AC2/A1-4: runner/selector-only execution and its idiom (submodule-common-rules.md:262, :277)"
expect_disposition 'autoflow-tester\.md:11|RED-entry|RED entry' \
  "AC2/A1-5: RED-entry select-suites derivation (autoflow-tester.md:11)"
expect_disposition 'teammate-contracts\.md:67|inherited' \
  "AC2/A1-6: inherited reporting and green-tree discharge (teammate-contracts.md:67, :112, :127; evaluation-system.md:141, :143)"
expect_disposition ':349([^0-9]|$)|header contract and suite-disposition' \
  "AC2/A1-7: header contract and suite-disposition derivation (guide:349, RED > Completion)"
echo

# =============================================================================
# AC3 — the structural guarantee and its confirming means.
# Failure mode: ADR-0024 names the store but assigns the predicate to no one, so
# the structural guarantee ships with no confirming means and AC3's second
# clause is discharged by nobody.
# =============================================================================
echo "-- AC3: cycle-layer store prefix and confirming predicate"
adr_has '\.autoflow/issue-\{N\}-local' \
  "AC3: ADR-0024 names '.autoflow/issue-{N}-local/' as the single declared prefix"
adr_near 'tracked[^.]{0,30}predicate|predicate[^.]{0,30}tracked' 'sub-issue' 400 \
  "AC3: the standing tracked-file predicate over that prefix is assigned to a named sub-issue"
echo

# =============================================================================
# AC4 — closed-vocabulary join over the issue body's Area-2 enumeration.
# Failure mode: an evaluation criterion keeps a subject the model deletes, so
# the gate reports clean on a surface it no longer inspects.
# =============================================================================
echo "-- AC4: Area 2 (evaluation criteria)"
expect_disposition ':717([^0-9]|$)|GATE:PLAN .Test plan' \
  "AC4/A2-1: GATE:PLAN 'Test plan' (guide:717, evaluation-system.md:67)"
expect_disposition ':1608([^0-9]|$)|Test quality' \
  "AC4/A2-2: GATE:QUALITY 'Test quality' test-asset disposition (guide:1608-1614)"
expect_disposition 'evaluation-system\.md:69|Test coverage' \
  "AC4/A2-3: GATE:QUALITY 'Test coverage' (evaluation-system.md:69)"
expect_disposition 'ADR-0019 decision 3|decision 3 \(evaluator|evaluator execution discipline' \
  "AC4/A2-4: ADR-0019 decision 3 (evaluator execution discipline)"
expect_disposition ':1472([^0-9]|$)|VALIDATE failure routing' \
  "AC4/A2-5: VALIDATE failure routing by ci-subject (guide:1472, remedy-route.sh)"
expect_disposition ':1691([^0-9]|$)|doc. remedy step 3|remedy step 3' \
  "AC4/A2-6: GATE:QUALITY 'doc' remedy step 3 selected-suites run (guide:1691-1695)"
adr_near 'teammate-contracts' 'governing record' 400 \
  "AC4: ADR-0019 d3's governing-record pointer is re-homed on ADR-0024 (teammate-contracts.md:62-65)"
adr_has 'anchor' \
  "AC4: ADR-0019 d3's retained obligation — resolve an anchor before executing — is carried in ADR-0024's body"
adr_has 'sampling' \
  "AC4: ADR-0019 d3's retained obligation — representative sampling escalating to exhaustive — is carried in ADR-0024's body"
adr_has 'wall-clock' \
  "AC4: ADR-0019 d3's retained obligation — declared wall-clock cap with 'not-searched' items — is carried in ADR-0024's body"
echo

# =============================================================================
# AC5 — the opt-in declaration site, the one resolver, and its three callers.
# Failure mode: the opt-in has no site a device can read, so the sub-issue
# conditions D7 on a predicate that does not exist and a non-opted-in target
# still stops at PREFLIGHT — the exact #213 state AC5 removes.
# =============================================================================
echo "-- AC5: target opt-in declaration site and the shared resolver"
adr_has '\.claude/autoflow\.local\.json' \
  "AC5: the opt-in declaration site '.claude/autoflow.local.json' is named"
adr_has 'tests\.command' \
  "AC5: the declared test command key 'tests.command' is named"
adr_has 'tests\.suite_plane' \
  "AC5: the suite-plane opt-in key 'tests.suite_plane' is named"
adr_has 'shared[^.]{0,20}resolver|one resolver|single resolver' \
  "AC5: a single shared opt-in resolver is named"
adr_near 'check-suite-manifest|header contract' 'resolver' 400 \
  "AC5: the header contract calls the shared resolver"
adr_near 'select-suites|selector' 'resolver' 400 \
  "AC5: the selector calls the shared resolver"
adr_near 'D7|drift-check' 'resolver' 400 \
  "AC5: drift-check D7's new opt-in-keyed arm calls the shared resolver"
echo

# =============================================================================
# AC6 — the CI-failure route is a rule pair, and both sites plus the classifier
# are named.
# Failure mode: the route is changed at CLAUDE.md:314 and not at
# docs/autoflow-guide.md:1803, so the script's own exit-12 contract still says
# RED and two records disagree.
# =============================================================================
echo "-- AC6: CI-layer failure re-entry"
adr_has 'CLAUDE\.md:314' \
  "AC6: the first unconditional-route site (CLAUDE.md:314) is named"
adr_has 'autoflow-guide\.md:1803|:1803([^0-9]|$)' \
  "AC6: the second unconditional-route site (docs/autoflow-guide.md:1803) is named"
adr_near 'ci-subject' 'stage 1|classifier' 500 \
  "AC6: classifier stage 1 — the failing check's suite 'ci-subject' header on an opted-in target"
adr_near 'output' 'stage 2|tagging role' 500 \
  "AC6: classifier stage 2 — the tagging role's separate read of the failing check's output"
adr_near 'operator' 'PAUSE|stage 3' 500 \
  "AC6: classifier stage 3 — not classifiable with confidence → 'operator' → PAUSE"
adr_has 'autoflow-guide\.md:1814|:1814([^0-9]|$)' \
  "AC6: the fail-closed rule at docs/autoflow-guide.md:1814 is cited"
echo

# =============================================================================
# AC7 — closed-vocabulary join over the issue body's Area-3 enumeration,
# extended to the `lane: cycle-scoped` dependents (GATE:PLAN finding F-1) and
# the five ADR status/registry sites.
# Failure mode: an enforcement device keeps a subject the new rules delete, and
# nothing names it.
# =============================================================================
echo "-- AC7: Area 3 (enforcement devices)"
expect_disposition 'check-autoflow-gate\.sh:28|backgrounded' \
  "AC7/A3-1: backgrounded run-suites deny (check-autoflow-gate.sh:28)"
expect_disposition 'check-suite-ci-coverage\.sh:2' \
  "AC7/A3-2: check-suite-ci-coverage.sh no-exemption rule (:26-30)"
expect_disposition 'drift-check\.sh:481' \
  "AC7/A3-3: check-suite-manifest.sh and drift-check D7 (drift-check.sh:481 ff.)"
expect_disposition 'setup/manifest\.json' \
  "AC7/A3-4: setup/manifest.json suite-plane shipping rows"
expect_disposition '0019-[a-z-]*\.md:28-90|ADR-0019 decisions 1' \
  "AC7/A3-5: ADR-0019 decisions 1–3 (0019-…:28-90)"
expect_disposition 'CLAUDE\.md:314' \
  "AC7/A3-6: CLAUDE.md:314 — HANDOFF CI failure → RED, unconditional"

# `lane: cycle-scoped` dependents — the design's own rows …
expect_disposition ':856([^0-9]|$)|`lane`' \
  "AC7/dep-1: the 'lane' header field (guide:856)"
expect_disposition ':857([^0-9]|$)|retire-with' \
  "AC7/dep-2: the 'retire-with' header field (guide:857)"
expect_disposition ':858([^0-9]|$)|cycle-arm' \
  "AC7/dep-3: the 'cycle-arm' header field (guide:858)"
expect_disposition 'suite-manifest\.sh:27([^0-9]|$)|:314-319' \
  "AC7/dep-4: cycle-arm's grammar site (suite-manifest.sh:27, :314-319)"
expect_disposition 'out-of-tree-inputs' \
  "AC7/dep-5: the 'out-of-tree-inputs' field, its lint and its live declarations"
expect_disposition 'test-suite-coverage-agreement\.sh' \
  "AC7/dep-6: tests/test-suite-coverage-agreement.sh"
expect_disposition 'green-tree register' \
  "AC7/dep-7: the Green-tree register and its shared store"
expect_disposition ':1803([^0-9]|$)' \
  "AC7/dep-8: docs/autoflow-guide.md:1803 — confirm-ci-green.sh exit 12 → RED"

# … and the sites GATE:PLAN finding F-1 names as owed before this join executes.
expect_disposition ':482([^0-9]|$)' \
  "AC7/F-1a: delivery-check's definition site guide:482 (D2 falsifies it)"
expect_disposition ':833([^0-9]|$)' \
  "AC7/F-1b: delivery-check's definition site guide:833"
expect_disposition ':879([^0-9]|$)' \
  "AC7/F-1c: delivery-check's definition site guide:879"
expect_disposition ':849([^0-9]|$)' \
  "AC7/F-1d: the lane/retire-with grammar fence (guide:849-850)"
expect_disposition ':865([^0-9]|$)' \
  "AC7/F-1e: the lane adoption item (guide:865)"
expect_disposition ':872([^0-9]|$)' \
  "AC7/F-1f: the cycle-scoped naming rule (guide:872)"
expect_disposition 'suite-manifest\.sh:25([^0-9]|$)|:25-26' \
  "AC7/F-1g: the lane/retire-with grammar site (suite-manifest.sh:25-26)"
expect_disposition 'check-suite-manifest\.sh:87([^0-9]|$)|:87-88' \
  "AC7/F-1h: the lane/retire-with lint arm (check-suite-manifest.sh:87-88)"
expect_disposition 'check-suite-manifest\.sh:96([^0-9]|$)|:96-98' \
  "AC7/F-1i: the lane/retire-with lint arm (check-suite-manifest.sh:96-98)"

# The five ADR status/registry sites, as scope-table rows (AC1b asserts the
# repair itself; these assert that the table claims the sites).
expect_disposition '0019-[a-z-]*\.md:5([^0-9]|$)|README\.md:36' \
  "AC7/adr-1: the ADR-0019 status records (0019-…:5, README.md:36)"
expect_disposition '0022-[a-z-]*\.md:5([^0-9]|$)|README\.md:39' \
  "AC7/adr-2: the ADR-0022 status records (0022-…:5, README.md:39)"
expect_disposition 'ADR-0024 row' \
  "AC7/adr-3: the docs/adr/README.md ADR-0024 row" "additive"
echo

echo "=============================================="
echo "PASS: $PASS  FAIL: $FAIL"
echo "=============================================="

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
