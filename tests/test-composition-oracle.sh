#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: scripts/architect/composition-oracle.sh
# lane: standing
# budget-secs: SUITE_BUDGET_CEILING_SECS
# =============================================================================
# Test: the composition-oracle T ∩ S classifier (issue #206)
# =============================================================================
# scripts/architect/composition-oracle.sh reads the composition-oracle
# determination block of ONE verification design file and classifies it as
# exactly one of intersection / empty / unknown/error. Asserted by running the
# real script as a process over inline fixture files; nothing stubs the parser
# or the file read.
#
# Failure mode no other layer catches: the classifier returns the wrong outcome
# for an input — a wrong class, two outcomes collapsed into one, a classifying
# result line under a non-classifying status, a wrong evaluated-block field, or
# a missing, undeclared-empty, unestablished, stale or malformed-latest input
# read as a computed result.
#
# The fixtures are instances of the record grammar, not its definition: that
# lives once, in docs/autoflow-guide.md > Composition oracle.
#
# What each case holds the script to:
#   - one classifying result line on stdout, `result: intersection` or
#     `result: empty`, and none at all under unknown/error;
#   - exit statuses: the two classifying values are not pinned here. They are
#     read from the first intersection and empty runs, then held to D3-1:
#     outside {1, 2, 126, 127}, different from each other, and paired with
#     their own result line on every run;
#   - the evaluated block: stdout names `base` or `round <n>`, format free;
#   - unknown/error: stdout prints a cause, wording free.
# =============================================================================

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CO="$PROJECT_ROOT/scripts/architect/composition-oracle.sh"

PASS=0; FAIL=0; SKIP=0
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

INT_RX='^result: intersection([[:space:]].*)?$'
EMP_RX='^result: empty([[:space:]].*)?$'
CLS_RX='^result: (intersection|empty)([[:space:]].*)?$'
UNSEEN='(not observed)'
S_INT="$UNSEEN"; S_EMP="$UNSEEN"

OUT=""; RC=0; CASE_ERR=""

fixture()  { cat > "$T/$1.md"; }            # fixture <name>   (markdown on stdin)
fx()       { printf '%s' "$T/$1.md"; }
run()      { OUT="$(cd "$PROJECT_ROOT" && bash "$CO" "$1" 2>/dev/null)"; RC=$?; }

has_line() { grep -qE -- "$1" <<<"$OUT"; }
no_line()  { ! grep -qE -- "$1" <<<"$OUT"; }
has_token() { grep -qE "(^|[^[:alnum:]_-])$1([^[:alnum:]_-]|$)" <<<"$OUT"; }
names_base()  { grep -qiE '(^|[^[:alnum:]_])base([^[:alnum:]_]|$)' <<<"$OUT"; }
names_round() { grep -qiE "(^|[^[:alnum:]_])round[[:space:]]+$1([^[:alnum:]_]|$)" <<<"$OUT"; }
no_round()    { ! grep -qiE '(^|[^[:alnum:]_])round[[:space:]]+[0-9]+' <<<"$OUT"; }
not_round()   { ! names_round "$1"; }
eq() { [ "$1" = "$2" ]; }
ne() { [ "$1" != "$2" ]; }
not_generic() { case " 1 2 126 127 " in *" $1 "*) return 1 ;; esac; return 0; }

need() { local d="$1"; shift; "$@" || CASE_ERR="$CASE_ERR; $d"; }
finish() {
  local first
  first="$(sed -n 1p <<<"$OUT")"
  if [ -z "$CASE_ERR" ]; then
    echo "  PASS: $1"; PASS=$((PASS + 1))
  else
    echo "  FAIL: $1 — exit $RC, stdout line 1: '${first}'${CASE_ERR}"; FAIL=$((FAIL + 1))
  fi
  CASE_ERR=""
}

expect_intersection() { # <identifier>...
  local id
  need "no 'result: intersection' line" has_line "$INT_RX"
  need "a 'result: empty' line as well" no_line "$EMP_RX"
  need "exit status is not the intersection status ($S_INT)" eq "$RC" "$S_INT"
  for id in "$@"; do need "stdout does not name intersecting identifier '$id'" has_token "$id"; done
}
expect_empty() {
  need "no 'result: empty' line" has_line "$EMP_RX"
  need "a 'result: intersection' line as well" no_line "$INT_RX"
  need "exit status is not the empty status ($S_EMP)" eq "$RC" "$S_EMP"
}
expect_unknown() {
  need "a classifying result line is on stdout" no_line "$CLS_RX"
  need "exit status is the intersection status ($S_INT)" ne "$RC" "$S_INT"
  need "exit status is the empty status ($S_EMP)" ne "$RC" "$S_EMP"
  need "stdout prints no cause" has_line '[^[:space:]]'
}

# ---------------------------------------------------------------------------
# Fixtures — well-formed records
# ---------------------------------------------------------------------------
fixture c1-intersection <<'MD'
# Issue #9001 — Verification Design

## Risk line

If this change is wrong, a stamped target reads a stale value.

## Acceptance criteria → verification

| Issue AC | Acceptance criterion | Type | Kind | Method | Reason |
|---|---|---|---|---|---|
| AC1 | the value is read once | automated | driving | L1 | — |

## Verification depth

| Layer | Form | Failure it alone catches |
|---|---|---|
| L1 | one spec over fixtures | the wrong value |

```bash
bash tests/example.sh
```

## Composition oracle

```composition-oracle
T:
- t1 | D1
- t2 | D4
- t3 | D7
S:
- t1 | docs/adr/0018-verification-depth-justification.md
- t3 | #800
- t9 | O4
```

**Oracles**
- t1 → L1. Trace: t1.
- t3 → existing coverage. Trace: t3.
MD

fixture c2-empty-disjoint <<'MD'
## Composition oracle

```composition-oracle
T:
- manifest-row | D7
S:
- ledger-heading | O2
```
MD

fixture c3-empty-exact-identifiers <<'MD'
## Composition oracle

```composition-oracle
T:
- t1 | D1
- surface-submit | D2
S:
- t10 | #27
- rgb-surface-submit | docs/adr/0020-acceptance-criterion-authority.md
```
MD

fixture c4-declared-empty-s <<'MD'
## Composition oracle

```composition-oracle
T:
- t1 | D1
S: none | no ADR, prior issue design or ledger entry names t1
```
MD

fixture c5-declared-empty-both <<'MD'
## Composition oracle

```composition-oracle
T: none | the change surface names no shared state
S: none | no settled decision governs this surface
```
MD

# ---------------------------------------------------------------------------
# Fixtures — unestablished inputs (D2, D3, D4)
# ---------------------------------------------------------------------------
fixture u3-prose-only <<'MD'
## Composition oracle

T ∩ S computed by hand: the change surface names `t1`; no settled decision names it.

**Determination: no intersection.**
MD

fixture u4-empty-block <<'MD'
## Composition oracle

```composition-oracle
```
MD

fixture u5-t-absent <<'MD'
## Composition oracle

```composition-oracle
S:
- t9 | #27
```
MD

fixture u6-s-absent <<'MD'
## Composition oracle

```composition-oracle
T:
- t1 | D1
```
MD

fixture u7-t-empty-undeclared <<'MD'
## Composition oracle

```composition-oracle
T:
S:
- t9 | #27
```
MD

fixture u8-s-empty-undeclared <<'MD'
## Composition oracle

```composition-oracle
T:
- t1 | D1
S:
```
MD

fixture u9-entry-without-identifier <<'MD'
## Composition oracle

```composition-oracle
T:
- t1 | D1
- | D4
S:
- t9 | #27
```
MD

fixture u10-entry-without-source <<'MD'
## Composition oracle

```composition-oracle
T:
- t1 | D1
S:
- t9 | #27
- t1 |
```
MD

fixture u11-declaration-plus-entries <<'MD'
## Composition oracle

```composition-oracle
T:
- t1 | D1
S: none | no settled decision names t1
- t9 | #27
```
MD

fixture u12-declaration-without-ground <<'MD'
## Composition oracle

```composition-oracle
T:
- t1 | D1
S: none
```
MD

# ---------------------------------------------------------------------------
# Fixtures — delta rounds (t2). The restated block is the payload of one
# `supersedes` bullet under a Decision 15 delta heading
# (docs/autoflow-guide.md:415,417).
# ---------------------------------------------------------------------------
fixture d1-latest-intersection-over-stale-empty <<'MD'
## Composition oracle

```composition-oracle
T:
- t1 | D1
S:
- t9 | #27
```

## Delta — round 2 (GATE:PLAN FAIL)

- composition-oracle determination: restated in full below — supersedes the base composition-oracle determination
  ```composition-oracle
  T:
  - t1 | D1
  - t4 | D9
  S:
  - t4 | F12
  ```
MD

fixture d2-latest-empty-over-stale-intersection <<'MD'
## Composition oracle

```composition-oracle
T:
- t1 | D1
S:
- t1 | #27
```

## Delta — round 2 (GATE:PLAN FAIL)

- composition-oracle determination: restated in full below — supersedes the base composition-oracle determination
  ```composition-oracle
  T:
  - t2 | D3
  S:
  - t9 | #27
  ```
MD

fixture d3-block-round-not-last-round <<'MD'
## Composition oracle

```composition-oracle
T:
- t1 | D1
S:
- t9 | #27
```

## Delta — round 2 (GATE:PLAN FAIL)

- composition-oracle determination: restated in full below — supersedes the base composition-oracle determination
  ```composition-oracle
  T:
  - t1 | D1
  S:
  - t1 | F7
  ```

## Delta — round 3 (un-agreed re-discussion)

- AC2 method: L1 over the delta fixture — supersedes the AC2 row
MD

fixture u13-malformed-latest <<'MD'
## Composition oracle

```composition-oracle
T:
- t1 | D1
S:
- t9 | #27
```

## Delta — round 2 (GATE:PLAN FAIL)

- composition-oracle determination: restated in full below — supersedes the base composition-oracle determination
  ```composition-oracle
  T:
  - t1 | D1
  S:
  - t7 | F3
  - t9 |
  ```
MD

echo "subject: scripts/architect/composition-oracle.sh ($([ -f "$CO" ] && echo present || echo absent))"

# ---------------------------------------------------------------------------
# D3-1: the two classifying statuses, observed with their own result lines
# ---------------------------------------------------------------------------
echo "=== [AC2] classifying statuses (D3-1) ==="
run "$(fx c1-intersection)"
if has_line "$INT_RX" && no_line "$EMP_RX"; then S_INT="$RC"; fi
run "$(fx c2-empty-disjoint)"
if has_line "$EMP_RX" && no_line "$INT_RX"; then S_EMP="$RC"; fi
need "no exit status was observed with 'result: intersection'" ne "$S_INT" "$UNSEEN"
need "no exit status was observed with 'result: empty'" ne "$S_EMP" "$UNSEEN"
need "the intersection status $S_INT is a generic failure status" not_generic "$S_INT"
need "the empty status $S_EMP is a generic failure status" not_generic "$S_EMP"
need "intersection and empty share one status" ne "$S_INT" "$S_EMP"
finish "[AC2] intersection and empty each have their own status, outside {1, 2, 126, 127} (intersection=$S_INT, empty=$S_EMP)"

# ---------------------------------------------------------------------------
# AC1 / AC2: well-formed records are classified
# ---------------------------------------------------------------------------
echo "=== [AC1][AC2] well-formed records ==="
run "$(fx c1-intersection)"
expect_intersection t1 t3
need "stdout does not name the base determination as the evaluated block" names_base
need "stdout names a delta round for a record that has none" no_round
finish "[AC1][AC2] a structured record amid ordinary design prose is classified intersection, naming t1 and t3, evaluated: base"

run "$(fx c2-empty-disjoint)"
expect_empty
finish "[AC2] two established, disjoint sets are empty"

run "$(fx c3-empty-exact-identifiers)"
expect_empty
finish "[AC2] identifiers match exactly — t1/t10 and surface-submit/rgb-surface-submit do not meet"

run "$(fx c4-declared-empty-s)"
expect_empty
finish "[AC1][AC2] a list carrying D2's declaration with a ground is established: empty"

run "$(fx c5-declared-empty-both)"
expect_empty
finish "[AC1][AC2] both lists declared empty with grounds: empty"

# ---------------------------------------------------------------------------
# AC3 (trace t1): every unestablished input is unknown/error, never empty
# ---------------------------------------------------------------------------
echo "=== [AC3 · t1] unestablished inputs ==="
run "$T/absent.md"
expect_unknown
finish "[AC3 · t1] an absent file is unknown/error"

cp "$(fx c1-intersection)" "$T/u2-unreadable.md"; chmod 000 "$T/u2-unreadable.md"
if [ -r "$T/u2-unreadable.md" ]; then
  echo "  SKIP: [AC3 · t1] an unreadable file — this user reads a mode-000 file, so the case cannot be built here"
  SKIP=$((SKIP + 1))
else
  run "$T/u2-unreadable.md"
  expect_unknown
  finish "[AC3 · t1] an unreadable file is unknown/error"
fi

run "$(fx u3-prose-only)"
expect_unknown
finish "[AC3 · t1] a prose 'Determination: no intersection.' with no block is unknown/error"

run "$(fx u4-empty-block)"
expect_unknown
finish "[AC3 · t1] an empty block is unknown/error (D2)"

run "$(fx u5-t-absent)"
expect_unknown
finish "[AC3 · t1] a block without the T list is unknown/error"

run "$(fx u6-s-absent)"
expect_unknown
finish "[AC3 · t1] a block without the S list is unknown/error"

run "$(fx u7-t-empty-undeclared)"
expect_unknown
finish "[AC3 · t1] a T list left empty without D2's declaration is unknown/error"

run "$(fx u8-s-empty-undeclared)"
expect_unknown
finish "[AC3 · t1] an S list left empty without D2's declaration is unknown/error"

run "$(fx u9-entry-without-identifier)"
expect_unknown
finish "[AC3 · t1] an entry without an identifier is unknown/error"

run "$(fx u10-entry-without-source)"
expect_unknown
finish "[AC3 · t1] an entry without a source is unknown/error"

run "$(fx u11-declaration-plus-entries)"
expect_unknown
finish "[AC3 · t1] an empty declaration together with entries is unknown/error"

run "$(fx u12-declaration-without-ground)"
expect_unknown
finish "[AC3 · t1] an empty declaration without its one-line ground is unknown/error (D2)"

# ---------------------------------------------------------------------------
# t2: the latest block in document order, restated inside a delta round (D4, D3-3)
# ---------------------------------------------------------------------------
echo "=== [t2] delta rounds ==="
run "$(fx d1-latest-intersection-over-stale-empty)"
expect_intersection t4
need "stdout does not name round 2 as the evaluated block" names_round 2
finish "[AC3 · t2] the round-2 restated block is computed (intersection t4), not the stale base block's empty"

run "$(fx d2-latest-empty-over-stale-intersection)"
expect_empty
need "stdout does not name round 2 as the evaluated block" names_round 2
finish "[AC2 · t2] the round-2 restated block is computed (empty), neither the base block nor a union of blocks"

run "$(fx d3-block-round-not-last-round)"
expect_intersection t1
need "stdout does not name round 2, the round the latest block sits in" names_round 2
need "stdout names round 3, a round that restates no block" not_round 3
finish "[AC2 · t2] the evaluated block is named by the round it sits in (round 2), not the last delta round"

run "$(fx u13-malformed-latest)"
expect_unknown
finish "[AC3 · t2] a malformed latest block is unknown/error, with no fallback to the earlier well-formed block"

# ---------------------------------------------------------------------------
# D3-2: the output attached to the artifact never parses as a block
# ---------------------------------------------------------------------------
echo "=== [AC1 · D3-2] re-run over the recorded artifact ==="
cp "$(fx c1-intersection)" "$T/r1-recorded.md"
before="$(cksum < "$T/r1-recorded.md")"
run "$T/r1-recorded.md"
OUT0="$OUT"; RC0="$RC"
after="$(cksum < "$T/r1-recorded.md")"
need "the record is not classified intersection before the attachment" has_line "$INT_RX"
need "exit status is not the intersection status ($S_INT)" eq "$RC" "$S_INT"
need "the script changed the file it read" eq "$before" "$after"
printf '\nComposition-oracle output, attached as the shell produced it:\n\n%s\n\nexit status: %s\n' "$OUT0" "$RC0" >> "$T/r1-recorded.md"
run "$T/r1-recorded.md"
need "a re-run over the artifact does not reproduce the attached stdout" eq "$OUT" "$OUT0"
need "a re-run over the artifact does not reproduce the attached exit status" eq "$RC" "$RC0"
finish "[AC1 · D3-2] with its own output attached, the record re-runs to the same stdout and exit status"

echo
echo "Tests: $PASS passed, $FAIL failed, $SKIP skipped"
[ "$FAIL" -eq 0 ]
