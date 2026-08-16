#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# Test: doc-invariant registry runner contract — tests/run-doc-invariants.sh
# =============================================================================
# ci-subject: tests/run-doc-invariants.sh tests/fixtures/doc-invariants.json tests/lib/base-ref.sh tests/fixtures/anchor-resolution-fixture-doc.md
# lane: standing
# budget-secs: SUITE_BUDGET_CEILING_SECS
#
# The runner's own contract, retained from the retired per-cycle suite
# `tests/test-issue-951-registry.sh` at issue #76 (`runner-contract-suite`).
# That suite's legs were not uniform: some asserted the #951 cycle's own
# completion (the five migrated suites are gone, their CI steps are gone, the
# registry manifest-closure row exists, no residual per-issue exemption
# arrays), while the rest are the runner's durable contract. Deleting the file
# whole would have deleted the only test of the runner in a cycle whose central
# mechanism is that runner, so the durable legs were renamed to this
# subject-named suite — the naming this tree already uses for subject-named
# rather than cycle-named specs (adr-0016-conformance-check.sh,
# test-gate-hardening.sh) — and the cycle-completion legs were retired with §5
# disposition rows in docs/doc-invariant-registry.md.
#
# What this suite holds:
#   A  — the registry is declarative data the runner reads via jq, with no
#        per-issue hand-coded branch.
#   B  — the positive leg (every entry PASSes against the current tree) and the
#        negative-teeth leg, the latter now asserting the CONTRACT of
#        `run-doc-invariants.sh --self-test` rather than reimplementing a
#        second mutator (issue #76 `teeth-in-runner`), plus that mode's four
#        non-credit paths driven hermetically: unexpressible shape, ineffective
#        mutation, mutator error, and anchor destruction.
#   C  — the guard-lifecycle rule and the scope field: a non-permanent or
#        diff/count-shaped entry is rejected at load, loudly.
#   D  — the measured false-positive classes the registry design exists to
#        prevent: anchor stability under an upstream insertion, no
#        diff/count/delta predicate, the runner reading no base ref, and
#        whole-file `absent` non-vacuity.
#   E  — anchor well-formedness: a dangling or ambiguous anchor is rejected at
#        load time.
#   L1 — match:"regex" predicate mode, positive and teeth legs.
#   L2 — the section_end heading-pair window, including its own dangling and
#        ambiguous rejections.
#   L3 — the step-0 well-formedness block() guards, one violating fixture each.
#   L4 — the missing-target-file path: a FAIL record, not a crash and not a
#        silent PASS.
#   F  — the shared base-ref resolver's hermetic self-test. It has no other
#        home: the library is consumed by cycle-scoped suites, which are
#        retired at their own merge decision.
#
# Interface assumption (minimal, non-AC-affecting): the runner accepts an
# OPTIONAL positional registry path, so this suite can drive it against fixture
# (bad / mutated) registries without touching the real registry. With no
# argument it MUST default to tests/fixtures/doc-invariants.json — its normal
# CI invocation.
#
# The anchor-resolution negative coverage for the non-heading `section_kind`
# values (AC-a-3 / AC-f, issue #76) has been FOLDED IN below — it previously
# lived in the temporary CI-facing home tests/test-issue-76-runner-self-test-
# contract.sh, whose own header named this file as the fold-in destination.
# Its AC-f body-equality leg did not move: that leg materialised a deleted
# suite from a base-ref snapshot (`git show <base>:<path>`), which is a DELTA
# assertion and therefore cycle-scoped by construction
# (docs/doc-invariant-registry.md §1/§2) — retired with a disposition row in
# that document's §7 rather than carried into a standing suite.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

REGISTRY="$PROJECT_ROOT/tests/fixtures/doc-invariants.json"
RUNNER="$PROJECT_ROOT/tests/run-doc-invariants.sh"
BASEREF_LIB="$PROJECT_ROOT/tests/lib/base-ref.sh"
LIFECYCLE_DOC="$PROJECT_ROOT/docs/doc-invariant-registry.md"
WORKFLOW="$PROJECT_ROOT/.github/workflows/e2e-dummy-target.yml"
ANCHOR_FIXTURE="$PROJECT_ROOT/tests/fixtures/doc-invariants-anchor-fixture.md"
ANCHOR_FIXTURE_REL="tests/fixtures/doc-invariants-anchor-fixture.md"
DIALECT_FIXTURE="$PROJECT_ROOT/tests/fixtures/doc-invariants-dialect-fixture.md"


PASS=0; FAIL=0; TESTS=0

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

assert_true() {
  local desc="$1" condition="$2"
  TESTS=$((TESTS + 1))
  if eval "$condition"; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"
    FAIL=$((FAIL + 1))
  fi
}

assert_false() {
  local desc="$1" condition="$2"
  TESTS=$((TESTS + 1))
  if eval "$condition"; then
    echo "  FAIL: $desc (forbidden condition held)"
    FAIL=$((FAIL + 1))
  else
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  fi
}

# run_runner <registry-path> — invokes the runner against an alternate
# registry (see interface assumption above). Prints combined stdout/stderr.
run_runner() {
  local registry="$1"
  ( cd "$PROJECT_ROOT" && bash "$RUNNER" "$registry" ) 2>&1
}

# verdict_for_id <registry-path> <id> -> echoes PASS|FAIL|MISSING
verdict_for_id() {
  local registry="$1" id="$2" out
  out="$(run_runner "$registry")"
  printf '%s\n' "$out" | grep -F "$id" | grep -oE 'PASS|FAIL' | head -1 || echo "MISSING"
}

TMP_ROOT="$PROJECT_ROOT/tests/fixtures/.tmp-run-doc-invariants-$$"
cleanup() { rm -rf "$TMP_ROOT" 2>/dev/null || true; }
trap cleanup EXIT

# Sweep this suite's own signal-aborted scratch residue before creating this
# run's tree (issue #100). Scoped to THIS suite's prefix, never a bare
# `.tmp-*` wildcard: tests/test-push-context-base-ref.sh owns a sibling prefix
# in the same directory and the two run concurrently in one checkout. Prefix
# scoping alone still leaves a concurrent instance of THIS suite exposed, so a
# candidate is deleted only when its PID suffix is definitively absent — the
# EXIT trap above means live-owner trees are never residue.
sweep_stale_scratch() {
  local prefix="$PROJECT_ROOT/tests/fixtures/.tmp-run-doc-invariants-" cand suffix
  for cand in "$prefix"*; do
    [ -d "$cand" ] || continue
    suffix="${cand##*-}"
    case "$suffix" in ''|*[!0-9]*) continue ;; esac
    kill -0 "$suffix" 2>/dev/null && continue
    rm -rf "$cand" 2>/dev/null || true
  done
}
sweep_stale_scratch

mkdir -p "$TMP_ROOT"

# =============================================================================
echo "=== AC1 (A): registry is declarative data, parseable, no per-issue hand-code ==="

assert_true "registry file exists (tests/fixtures/doc-invariants.json)" "[ -f '$REGISTRY' ]"
assert_true "registry parses and .invariants is a non-empty array" \
  "[ -f '$REGISTRY' ] && jq -e '(.invariants | type == \"array\") and (.invariants | length > 0)' '$REGISTRY' >/dev/null 2>&1"
assert_true "every registry entry carries id/file/predicate/scope" \
  "[ -f '$REGISTRY' ] && jq -e 'all(.invariants[]; has(\"id\") and has(\"file\") and has(\"predicate\") and has(\"scope\"))' '$REGISTRY' >/dev/null 2>&1"
assert_true "every registry entry's predicate is one of present/absent/ordered" \
  "[ -f '$REGISTRY' ] && jq -e 'all(.invariants[]; .predicate == \"present\" or .predicate == \"absent\" or .predicate == \"ordered\")' '$REGISTRY' >/dev/null 2>&1"
assert_true "registry ids are unique" \
  "[ -f '$REGISTRY' ] && jq -e '([.invariants[].id] | length) == ([.invariants[].id] | unique | length)' '$REGISTRY' >/dev/null 2>&1"

assert_true "runner script exists (tests/run-doc-invariants.sh)" "[ -f '$RUNNER' ]"
assert_false "runner does not hardcode registry heading text (data-driven discovery, no per-invariant branch)" \
  "[ -f '$RUNNER' ] && grep -qF 'PR Flow' '$RUNNER'"
assert_true "runner reads the registry via jq (no per-issue if/else literal branches)" \
  "[ -f '$RUNNER' ] && grep -qF 'jq' '$RUNNER'"
assert_false "runner does not hand-code per-issue literal branches (794/796/797/800/949)" \
  "[ -f '$RUNNER' ] && grep -qE 'issue-?(794|796|797|800|949)' '$RUNNER'"

# =============================================================================
echo ""
AC1_POSITIVE_LEG_OUT=""
if [ -f "$REGISTRY" ] && [ -f "$RUNNER" ]; then
  AC1_POSITIVE_LEG_OUT="$(run_runner "$REGISTRY")"
fi
assert_true "positive leg: every registry entry PASSes against the current tree" \
  "[ -f '$REGISTRY' ] && [ -f '$RUNNER' ] && printf '%s\n' \"\$AC1_POSITIVE_LEG_OUT\" | grep -qE '^Results: ' && ! printf '%s\n' \"\$AC1_POSITIVE_LEG_OUT\" | grep -qE '^  FAIL:'"

# Negative-teeth leg (C1, generic/data-driven — no hardcoded per-id fixtures):
# for every present/absent/ordered entry, a mutated copy of its target file
# must flip the verdict to FAIL, proving the migrated check still bites.
#
# The leg itself now lives in the runner, behind `--self-test` (issue #76
# `teeth-in-runner`): the equivalence question the promotion path had no
# mechanism for is answered by the same binary that evaluates the registry, so
# it inherits the runner's CI registration instead of sitting in a suite
# nothing executes. What this suite asserts is therefore the mode's CONTRACT,
# not a private reimplementation of it — a second mutator here would be the
# thing the promotion removed.
#
# The contract, unchanged in substance from the retired in-suite leg: the
# mutation is match-aware (a fixed-string removal applied to a match:"regex"
# entry strips 0 lines whenever the pattern carries ERE metacharacters, and the
# leg would then misread a perfectly intact check as "no teeth"); and an
# INEFFECTIVE mutation is a FAILURE, never a skip. A byte-identical mutation, a
# mutator error, an unexpressible shape (absent + match:"regex" — injection
# cannot synthesise a string in an arbitrary ERE's language) and, for the
# non-heading anchor kinds, a mutation that leaves the anchor unresolvable are
# each counted into the denominator and NOT into the credited set, with a
# diagnostic naming the entry. No entry is ever dropped from the denominator,
# so the leg cannot be made vacuous by adding a shape the mutator does not
# handle.

# run_self_test [registry-path] — drives the runner's mutation-teeth mode.
# Defaults to the real registry (its CI invocation). The optional argument
# drives the mode against a single-entry fixture registry so its OWN failure
# paths are exercised hermetically — see the self-tests below.
run_self_test() {
  local registry="${1:-$REGISTRY}"
  [ -f "$registry" ] && [ -f "$RUNNER" ] || return 1
  ( cd "$PROJECT_ROOT" && bash "$RUNNER" --self-test "$registry" ) 2>&1
}

SELFTEST_REAL_OUT="$(run_self_test)"
SELFTEST_REAL_RC=$?

assert_true "negative-teeth leg: every present/absent/ordered entry FAILs its mutated copy (data-driven, C1, via run-doc-invariants.sh --self-test)" \
  "[ '$SELFTEST_REAL_RC' -eq 0 ]"
assert_false "negative-teeth leg: no entry is reported as a non-credit (unexpressible shape / ineffective mutation / mutator error / unresolvable anchor)" \
  "printf '%s' \"\$SELFTEST_REAL_OUT\" | grep -q 'NO-TEETH'"
assert_true "negative-teeth leg: the denominator is the whole registry — the reported total equals the registry's entry count" \
  "[ \"\$(printf '%s' \"\$SELFTEST_REAL_OUT\" | sed -n 's/^Self-test results: [0-9]*\/\([0-9]*\) .*/\1/p')\" = \"\$(jq -r '.invariants | length' '$REGISTRY')\" ]"

# ---------------------------------------------------------------------------
# Teeth-leg self-tests — issue #26, VERIFY step-3 FINDING 3-E / step-4
# FINDING 4-A (.autoflow/issue-26-verify-checks.md §1.6, §2.2).
#
# The three failure paths above are fail-loud scaffolding for entry shapes the
# real registry does not hold today, so deleting any of them left the suite at
# 93/93 — un-exercised code guarding the exact round-1 regression (a mutation
# that changes nothing must never be read as "the entry bit"). Each is now
# driven against a hermetic single-entry registry, asserting BOTH halves of the
# documented contract: the entry is counted into `total` and NOT into `ok` (the
# leg returns non-zero, never a silent skip), and a diagnostic NAMES the shape.
#
# Each fixture literal is chosen so the leg's verdict INVERTS if its branch is
# removed — e.g. the absent+regex witness carries no ERE metacharacter, so a
# mutator without that branch would EOF-append it, the runner would report FAIL,
# and the entry would be wrongly credited. That is what makes these legs
# discriminate rather than merely pass.
# ---------------------------------------------------------------------------

TEETH_SELFTEST_DIR="$TMP_ROOT/teeth-selftest"
mkdir -p "$TEETH_SELFTEST_DIR"

mk_selftest_registry() {     # <out-path> <one-entry-json>
  printf '{"$comment":"teeth-leg self-test (#26)","invariants":[%s]}\n' "$2" > "$1"
}

# (a) absent + match:"regex" — injection cannot synthesise a witness for an
#     arbitrary ERE, so the mutator refuses the shape by design.
mk_selftest_registry "$TEETH_SELFTEST_DIR/absent-regex.json" \
  "{\"id\":\"26-selftest-absent-regex\",\"origin_issue\":26,\"intent\":\"existence\",\"file\":\"$ANCHOR_FIXTURE_REL\",\"section\":null,\"predicate\":\"absent\",\"match\":\"regex\",\"literal\":\"selftest-absent-regex-witness-26\",\"scope\":\"permanent\"}"
SELFTEST_ABSENT_REGEX_OUT="$(run_self_test "$TEETH_SELFTEST_DIR/absent-regex.json")"
SELFTEST_ABSENT_REGEX_RC=$?

assert_true "teeth self-test (a): an absent+match:\"regex\" entry is NOT credited with teeth — leg returns non-zero (FINDING 3-E)" \
  "[ '$SELFTEST_ABSENT_REGEX_RC' -ne 0 ]"
assert_true "teeth self-test (a): the diagnostic names the unsupported shape, not a generic no-teeth message" \
  "printf '%s' \"\$SELFTEST_ABSENT_REGEX_OUT\" | grep -qF 'unsupported shape: absent + match:\"regex\"'"

# (b) byte-identical mutation — the literal matches no line, so `grep -v`
#     reproduces the source exactly and the "mutation" proves nothing.
mk_selftest_registry "$TEETH_SELFTEST_DIR/byte-identical.json" \
  "{\"id\":\"26-selftest-byte-identical\",\"origin_issue\":26,\"intent\":\"existence\",\"file\":\"$ANCHOR_FIXTURE_REL\",\"section\":null,\"predicate\":\"present\",\"match\":\"fixed\",\"literal\":\"selftest-literal-absent-from-the-fixture-26\",\"scope\":\"permanent\"}"
SELFTEST_BYTE_IDENTICAL_OUT="$(run_self_test "$TEETH_SELFTEST_DIR/byte-identical.json")"
SELFTEST_BYTE_IDENTICAL_RC=$?

assert_true "teeth self-test (b): a byte-identical mutation is NOT credited with teeth — leg returns non-zero (round-1 failure class)" \
  "[ '$SELFTEST_BYTE_IDENTICAL_RC' -ne 0 ]"
assert_true "teeth self-test (b): the diagnostic names the byte-identity hazard" \
  "printf '%s' \"\$SELFTEST_BYTE_IDENTICAL_OUT\" | grep -qF 'byte-identical'"

# (c) mutator error — an invalid ERE makes grep exit 2 and leave an EMPTY
#     destination, which is NOT byte-identical to the source. FINDING 4-A: the
#     gate must consult `why`, or this shape is silently credited with teeth.
mk_selftest_registry "$TEETH_SELFTEST_DIR/mutator-error.json" \
  "{\"id\":\"26-selftest-mutator-error\",\"origin_issue\":26,\"intent\":\"existence\",\"file\":\"$ANCHOR_FIXTURE_REL\",\"section\":null,\"predicate\":\"present\",\"match\":\"regex\",\"literal\":\"[unclosed\",\"scope\":\"permanent\"}"
SELFTEST_MUTATOR_ERROR_OUT="$(run_self_test "$TEETH_SELFTEST_DIR/mutator-error.json")"
SELFTEST_MUTATOR_ERROR_RC=$?

assert_true "teeth self-test (c): a mutator error (invalid ERE) is NOT credited with teeth — leg returns non-zero (FINDING 4-A)" \
  "[ '$SELFTEST_MUTATOR_ERROR_RC' -ne 0 ]"
assert_true "teeth self-test (c): the diagnostic names the mutator error, as the leg's own comment promises" \
  "printf '%s' \"\$SELFTEST_MUTATOR_ERROR_OUT\" | grep -qF 'mutator error (match=regex)'"

# (d) anchor destruction — issue #76 `teeth-mode-anchor-destruction`. A "line"
#     entry's body IS its anchored line, so a whole-line mutator would delete
#     the anchor itself and leave it resolving to zero lines — Step 0b's
#     dangling condition. In-process there is no separate invocation to die at
#     the load gate, so the non-credit has to be written rather than inherited:
#     this fixture's literal IS the anchor prefix, which no mutation can remove
#     without destroying the anchor, and the mode must name that as a
#     non-credit instead of crediting it or aborting the whole run.
mk_selftest_registry "$TEETH_SELFTEST_DIR/anchor-destruction.json" \
  "{\"id\":\"76-selftest-anchor-destruction\",\"origin_issue\":76,\"intent\":\"existence\",\"file\":\"tests/fixtures/anchor-resolution-fixture-doc.md\",\"section\":\"| 3 |\",\"section_kind\":\"line\",\"predicate\":\"present\",\"match\":\"fixed\",\"literal\":\"| 3 |\",\"scope\":\"permanent\"}"
SELFTEST_ANCHOR_DESTRUCTION_OUT="$(run_self_test "$TEETH_SELFTEST_DIR/anchor-destruction.json")"
SELFTEST_ANCHOR_DESTRUCTION_RC=$?

assert_true "teeth self-test (d): an entry whose literal overlaps its own column-1 anchor prefix is NOT credited with teeth — mode returns non-zero (#76 teeth-mode-anchor-destruction)" \
  "[ '$SELFTEST_ANCHOR_DESTRUCTION_RC' -ne 0 ]"
assert_true "teeth self-test (d): the run does NOT abort — the entry is named in a diagnostic rather than silently dropped" \
  "printf '%s' \"\$SELFTEST_ANCHOR_DESTRUCTION_OUT\" | grep -qF '76-selftest-anchor-destruction'"
assert_false "teeth self-test (d): the unresolvable-anchor path never reaches block()'s abort — no BLOCK line is emitted from mutation evaluation" \
  "printf '%s' \"\$SELFTEST_ANCHOR_DESTRUCTION_OUT\" | grep -q '^BLOCK:'"

# =============================================================================
echo ""
echo "=== AC2 (C): guard-lifecycle rule (retirement + promotion) + scope enforcement ==="

assert_true "docs/doc-invariant-registry.md exists" "[ -f '$LIFECYCLE_DOC' ]"
assert_true "lifecycle doc states the retirement/deactivation condition" \
  "[ -f '$LIFECYCLE_DOC' ] && grep -qiE 'retire|deactivat' '$LIFECYCLE_DOC'"
assert_true "lifecycle doc states the promotion procedure" \
  "[ -f '$LIFECYCLE_DOC' ] && grep -qi 'promot' '$LIFECYCLE_DOC'"
assert_true "lifecycle doc states the two-lane partition (permanent vs cycle-scoped)" \
  "[ -f '$LIFECYCLE_DOC' ] && grep -qi 'cycle-scoped' '$LIFECYCLE_DOC' && grep -qi 'permanent' '$LIFECYCLE_DOC'"

assert_true "real registry: every entry's scope is exactly \"permanent\"" \
  "[ -f '$REGISTRY' ] && jq -e 'all(.invariants[]; .scope == \"permanent\")' '$REGISTRY' >/dev/null 2>&1"

# Load-time rejection: a fixture registry entry with scope != "permanent"
# must be rejected by the runner before any doc evaluation (§3.3, §4 step 0).
cat > "$TMP_ROOT/reg-cycle-scoped.json" <<JSON
{"\$comment":"AC2 rejection fixture","invariants":[{"id":"951-fixture-cycle-scoped","origin_issue":951,"intent":"existence","file":"CLAUDE.md","section":null,"predicate":"present","match":"fixed","literal":"CLAUDE.md","scope":"cycle-scoped"}]}
JSON
assert_true "runner REJECTS (non-zero exit) a fixture entry with scope != permanent (AC2 mechanism)" \
  "[ -f '$RUNNER' ] && ! ( cd '$PROJECT_ROOT' && bash '$RUNNER' '$TMP_ROOT/reg-cycle-scoped.json' >/dev/null 2>&1 )"
# Captured before the assert (not piped live): under `set -o pipefail` a pipe
# whose upstream command exits non-zero (the BLOCK) fails the whole pipeline
# even when grep finds its match downstream, so `run_runner ... | grep ...`
# cannot be used as a live assert_true condition here.
cycle_scoped_out=""
if [ -f "$RUNNER" ]; then
  cycle_scoped_out="$(run_runner "$TMP_ROOT/reg-cycle-scoped.json")"
fi
assert_true "rejection is a loud BLOCK, not a silent pass-through" \
  "printf '%s' \"\$cycle_scoped_out\" | grep -qiE 'block|reject|invalid|scope'"

# =============================================================================
echo ""
echo "=== AC3 (D): the 4 measured false positives + 3 #955-cycle observations, non-occurrence ==="

# --- Case 1: positional fragility (line window shifted +22 lines) ---
CASE1_FILE_REL="tests/fixtures/.tmp-run-doc-invariants-$$/case1-fixture.md"
CASE1_FILE_ABS="$PROJECT_ROOT/$CASE1_FILE_REL"
cat > "$CASE1_FILE_ABS" <<'MD'
## Case1 Heading

case1-marker-token present here.
MD
cat > "$TMP_ROOT/reg-case1.json" <<JSON
{"\$comment":"case1 fixture","invariants":[{"id":"951-case1-fragility","origin_issue":951,"intent":"existence","file":"$CASE1_FILE_REL","section":"Case1 Heading","predicate":"present","match":"fixed","literal":"case1-marker-token","scope":"permanent"}]}
JSON
v_before="$(verdict_for_id "$TMP_ROOT/reg-case1.json" 951-case1-fragility)"
{ printf '\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n'; cat "$CASE1_FILE_ABS"; } > "$CASE1_FILE_ABS.shifted" && mv "$CASE1_FILE_ABS.shifted" "$CASE1_FILE_ABS"
v_after="$(verdict_for_id "$TMP_ROOT/reg-case1.json" 951-case1-fragility)"
assert_true "case 1: anchor-based entry PASSes before a +22-line upstream insertion" "[ '$v_before' = 'PASS' ]"
assert_true "case 1: verdict is UNCHANGED after the heading is shifted +22 lines (anchor, not line-window)" \
  "[ '$v_before' = '$v_after' ] && [ '$v_after' = 'PASS' ]"

# --- Case 2/8: net-new [MUST] over-report / exemption-array accretion unrepresentable ---
assert_true "case 2/8: registry contains NO diff/count/delta predicate field" \
  "[ -f '$REGISTRY' ] && jq -e '[.invariants[] | select(has(\"diff\") or has(\"count\") or (.predicate | test(\"diff|delta|count\")))] | length == 0' '$REGISTRY' >/dev/null 2>&1"
cat > "$TMP_ROOT/reg-diffcount.json" <<JSON
{"\$comment":"case2/8 rejection fixture","invariants":[{"id":"951-fixture-diffcount","origin_issue":951,"intent":"existence","file":"CLAUDE.md","section":null,"predicate":"diff_count","match":"fixed","literal":"[MUST]","scope":"permanent"}]}
JSON
assert_true "case 2/8: runner REJECTS a diff/count-predicate entry at load" \
  "[ -f '$RUNNER' ] && ! ( cd '$PROJECT_ROOT' && bash '$RUNNER' '$TMP_ROOT/reg-diffcount.json' >/dev/null 2>&1 )"

# --- Case 3/6: cross-cycle bleed + self-referential trap (state-only property) ---
assert_false "case 3/6: runner source reads NO diff (no git diff / --name-only / rev-list ...)" \
  "[ -f '$RUNNER' ] && grep -qE 'git diff|git rev-list.*\.\.\.|--name-only' '$RUNNER'"
# Behavioral: touching the registry's own scope file (self-referential, case
# 6) between two runs must not change an unrelated entry's verdict.
if [ -f "$REGISTRY" ] && [ -f "$RUNNER" ]; then
  cp "$REGISTRY" "$TMP_ROOT/reg-selfref.json"
  v1="$(verdict_for_id "$TMP_ROOT/reg-selfref.json" 794-AC1-ordering-target-centric)"
  printf '\n// touched registry (case 6 self-referential probe)\n' >> "$TMP_ROOT/reg-selfref.json.touch-marker" 2>/dev/null || true
  echo "  //no-op" >> "$TMP_ROOT/reg-selfref.json" 2>/dev/null || true
  v2="$(verdict_for_id "$TMP_ROOT/reg-selfref.json" 794-AC1-ordering-target-centric)"
  assert_true "case 6: touching a guard's own scope/registry file does not change an unrelated entry's verdict" "[ '$v1' = '$v2' ]"
else
  assert_true "case 6: touching a guard's own scope/registry file does not change an unrelated entry's verdict" "false"
fi

# --- Case 7: 799 "diff must not touch CLAUDE.md" prohibition — structural barring only (ledger E8) ---
cat > "$TMP_ROOT/reg-prohibition.json" <<JSON
{"\$comment":"case7 rejection fixture","invariants":[{"id":"951-fixture-prohibition","origin_issue":799,"intent":"coherence","file":"CLAUDE.md","section":null,"predicate":"diff_absent","match":"fixed","literal":"CLAUDE.md","scope":"permanent"}]}
JSON
assert_true "case 7: runner REJECTS a diff/prohibition-shaped entry (structural barring only, 799 migration deferred)" \
  "[ -f '$RUNNER' ] && ! ( cd '$PROJECT_ROOT' && bash '$RUNNER' '$TMP_ROOT/reg-prohibition.json' >/dev/null 2>&1 )"

# --- 797-style whole-file absent non-vacuity (C5) ---
DIALECT_SEEDED_REL="tests/fixtures/.tmp-run-doc-invariants-$$/dialect-seeded.md"
DIALECT_SEEDED_ABS="$PROJECT_ROOT/$DIALECT_SEEDED_REL"
cp "$DIALECT_FIXTURE" "$DIALECT_SEEDED_ABS"
printf '\nwrong-dialect-marker-951\n' >> "$DIALECT_SEEDED_ABS"
cat > "$TMP_ROOT/reg-dialect-clean.json" <<JSON
{"\$comment":"C5 clean","invariants":[{"id":"951-fixture-dialect","origin_issue":797,"intent":"coherence","file":"tests/fixtures/doc-invariants-dialect-fixture.md","section":null,"predicate":"absent","match":"fixed","literal":"wrong-dialect-marker-951","scope":"permanent"}]}
JSON
cat > "$TMP_ROOT/reg-dialect-seeded.json" <<JSON
{"\$comment":"C5 seeded","invariants":[{"id":"951-fixture-dialect","origin_issue":797,"intent":"coherence","file":"$DIALECT_SEEDED_REL","section":null,"predicate":"absent","match":"fixed","literal":"wrong-dialect-marker-951","scope":"permanent"}]}
JSON
assert_true "C5 non-vacuity: clean tree (literal absent) -> entry PASSes" \
  "[ -f '$RUNNER' ] && [ \"\$(verdict_for_id '$TMP_ROOT/reg-dialect-clean.json' 951-fixture-dialect)\" = 'PASS' ]"
assert_true "C5 non-vacuity: seeded wrong-dialect literal -> entry FAILs (proves the absent check has teeth)" \
  "[ -f '$RUNNER' ] && [ \"\$(verdict_for_id '$TMP_ROOT/reg-dialect-seeded.json' 951-fixture-dialect)\" = 'FAIL' ]"

# =============================================================================
echo ""
echo "=== C6 (E): anchor well-formedness — dangling / ambiguous anchor rejected at load ==="

cat > "$TMP_ROOT/reg-anchor-unique.json" <<JSON
{"\$comment":"C6 positive control","invariants":[{"id":"951-fixture-anchor-unique","origin_issue":951,"intent":"existence","file":"$ANCHOR_FIXTURE_REL","section":"Unique Heading","predicate":"present","match":"fixed","literal":"unique-heading-body","scope":"permanent"}]}
JSON
assert_true "C6 positive control: a section resolving to exactly one heading is accepted and PASSes" \
  "[ -f '$RUNNER' ] && [ \"\$(verdict_for_id '$TMP_ROOT/reg-anchor-unique.json' 951-fixture-anchor-unique)\" = 'PASS' ]"

cat > "$TMP_ROOT/reg-anchor-dangling.json" <<JSON
{"\$comment":"C6 dangling anchor","invariants":[{"id":"951-fixture-anchor-dangling","origin_issue":951,"intent":"existence","file":"$ANCHOR_FIXTURE_REL","section":"Nonexistent Heading Zzz","predicate":"present","match":"fixed","literal":"x","scope":"permanent"}]}
JSON
assert_true "C6: runner REJECTS an anchor resolving to 0 headings (dangling anchor)" \
  "[ -f '$RUNNER' ] && ! ( cd '$PROJECT_ROOT' && bash '$RUNNER' '$TMP_ROOT/reg-anchor-dangling.json' >/dev/null 2>&1 )"
# Captured before the assert (pipefail contradiction, see cycle_scoped_out above).
dangling_out=""
if [ -f "$RUNNER" ]; then
  dangling_out="$(run_runner "$TMP_ROOT/reg-anchor-dangling.json")"
fi
assert_true "C6: dangling-anchor rejection message names the hazard" \
  "printf '%s' \"\$dangling_out\" | grep -qi 'dangling\|no heading\|0 match'"

cat > "$TMP_ROOT/reg-anchor-ambiguous.json" <<JSON
{"\$comment":"C6 ambiguous anchor","invariants":[{"id":"951-fixture-anchor-ambiguous","origin_issue":951,"intent":"existence","file":"$ANCHOR_FIXTURE_REL","section":"Duplicate Heading","predicate":"present","match":"fixed","literal":"x","scope":"permanent"}]}
JSON
assert_true "C6: runner REJECTS an anchor resolving to >1 headings (ambiguous anchor)" \
  "[ -f '$RUNNER' ] && ! ( cd '$PROJECT_ROOT' && bash '$RUNNER' '$TMP_ROOT/reg-anchor-ambiguous.json' >/dev/null 2>&1 )"
# Captured before the assert (pipefail contradiction, see cycle_scoped_out above).
ambiguous_out=""
if [ -f "$RUNNER" ]; then
  ambiguous_out="$(run_runner "$TMP_ROOT/reg-anchor-ambiguous.json")"
fi
assert_true "C6: ambiguous-anchor rejection message names the hazard" \
  "printf '%s' \"\$ambiguous_out\" | grep -qi 'ambiguous\|>1 match\|multiple'"

# =============================================================================
echo ""
echo "=== L1: match:\"regex\" — design-mandated predicate mode (feature design match enum fixed|regex, round-2) ==="

REGEX_FILE_REL="tests/fixtures/.tmp-run-doc-invariants-$$/regex-fixture.md"
REGEX_FILE_ABS="$PROJECT_ROOT/$REGEX_FILE_REL"
cat > "$REGEX_FILE_ABS" <<'MD'
## Regex Heading

marker-482-token appears here.
MD
cat > "$TMP_ROOT/reg-regex.json" <<JSON
{"\$comment":"L1 match:regex","invariants":[{"id":"951-fixture-regex","origin_issue":951,"intent":"existence","file":"$REGEX_FILE_REL","section":"Regex Heading","predicate":"present","match":"regex","literal":"marker-[0-9]+-token","scope":"permanent"}]}
JSON
assert_true "L1 positive leg: match:regex literal (ERE) matches -> entry PASSes" \
  "[ -f '$RUNNER' ] && [ \"\$(verdict_for_id '$TMP_ROOT/reg-regex.json' 951-fixture-regex)\" = 'PASS' ]"

# Teeth leg: mutate the fixture so the ERE no longer matches (no digit run).
printf '## Regex Heading\n\nno-marker-token-here\n' > "$REGEX_FILE_ABS"
assert_true "L1 teeth leg: match:regex literal no longer matches mutated fixture -> entry FAILs" \
  "[ -f '$RUNNER' ] && [ \"\$(verdict_for_id '$TMP_ROOT/reg-regex.json' 951-fixture-regex)\" = 'FAIL' ]"

# =============================================================================
echo ""
echo "=== L2: section_end heading-pair window — design-mandated (feature §3.2/§3.3, ledger E4, round-2) ==="

SECTIONEND_FILE_REL="tests/fixtures/.tmp-run-doc-invariants-$$/section-end-fixture.md"
SECTIONEND_FILE_ABS="$PROJECT_ROOT/$SECTIONEND_FILE_REL"
cat > "$SECTIONEND_FILE_ABS" <<'MD'
### Section Start

section-end-marker-inside token near the start.

This paragraph mentions Section End in prose, not as a heading — a
coincidental body-line match must NOT close the window early.

#### Sub Heading

section-end-marker-nested token under a deeper heading, still inside the pair.

### Section End

section-end-marker-outside token must NOT be found (outside the pair).
MD
cat > "$TMP_ROOT/reg-sectionend-inside.json" <<JSON
{"\$comment":"L2 inside pair","invariants":[{"id":"951-fixture-sectionend-inside","origin_issue":951,"intent":"existence","file":"$SECTIONEND_FILE_REL","section":"Section Start","section_end":"Section End","predicate":"present","match":"fixed","literal":"section-end-marker-nested","scope":"permanent"}]}
JSON
assert_true "L2a: literal under a nested sub-heading, past a coincidental body-line mention of the end anchor, is found inside the pair (no early close)" \
  "[ -f '$RUNNER' ] && [ \"\$(verdict_for_id '$TMP_ROOT/reg-sectionend-inside.json' 951-fixture-sectionend-inside)\" = 'PASS' ]"

cat > "$TMP_ROOT/reg-sectionend-outside.json" <<JSON
{"\$comment":"L2 outside pair","invariants":[{"id":"951-fixture-sectionend-outside","origin_issue":951,"intent":"existence","file":"$SECTIONEND_FILE_REL","section":"Section Start","section_end":"Section End","predicate":"absent","match":"fixed","literal":"section-end-marker-outside","scope":"permanent"}]}
JSON
assert_true "L2b: literal past the section_end heading is correctly excluded from the window (heading-pair actually bounds it)" \
  "[ -f '$RUNNER' ] && [ \"\$(verdict_for_id '$TMP_ROOT/reg-sectionend-outside.json' 951-fixture-sectionend-outside)\" = 'PASS' ]"

cat > "$TMP_ROOT/reg-sectionend-dangling.json" <<JSON
{"\$comment":"L2c dangling section_end","invariants":[{"id":"951-fixture-sectionend-dangling","origin_issue":951,"intent":"existence","file":"$ANCHOR_FIXTURE_REL","section":"Unique Heading","section_end":"Nonexistent Heading Zzz","predicate":"present","match":"fixed","literal":"x","scope":"permanent"}]}
JSON
assert_true "L2c: runner REJECTS a section_end resolving to 0 headings (dangling)" \
  "[ -f '$RUNNER' ] && ! ( cd '$PROJECT_ROOT' && bash '$RUNNER' '$TMP_ROOT/reg-sectionend-dangling.json' >/dev/null 2>&1 )"
# Captured before the assert (pipefail contradiction, see cycle_scoped_out above).
sectionend_dangling_out=""
if [ -f "$RUNNER" ]; then
  sectionend_dangling_out="$(run_runner "$TMP_ROOT/reg-sectionend-dangling.json")"
fi
assert_true "L2c: dangling section_end rejection message names the hazard" \
  "printf '%s' \"\$sectionend_dangling_out\" | grep -qi 'dangling\|no heading\|0 match'"

cat > "$TMP_ROOT/reg-sectionend-ambiguous.json" <<JSON
{"\$comment":"L2d ambiguous section_end","invariants":[{"id":"951-fixture-sectionend-ambiguous","origin_issue":951,"intent":"existence","file":"$ANCHOR_FIXTURE_REL","section":"Unique Heading","section_end":"Duplicate Heading","predicate":"present","match":"fixed","literal":"x","scope":"permanent"}]}
JSON
assert_true "L2d: runner REJECTS a section_end resolving to >1 headings (ambiguous)" \
  "[ -f '$RUNNER' ] && ! ( cd '$PROJECT_ROOT' && bash '$RUNNER' '$TMP_ROOT/reg-sectionend-ambiguous.json' >/dev/null 2>&1 )"
# Captured before the assert (pipefail contradiction, see cycle_scoped_out above).
sectionend_ambiguous_out=""
if [ -f "$RUNNER" ]; then
  sectionend_ambiguous_out="$(run_runner "$TMP_ROOT/reg-sectionend-ambiguous.json")"
fi
assert_true "L2d: ambiguous section_end rejection message names the hazard" \
  "printf '%s' \"\$sectionend_ambiguous_out\" | grep -qi 'ambiguous\|>1 match\|multiple'"

# =============================================================================
echo ""
echo "=== L3: step-0 well-formedness block() guards — one violating fixture each (round-2) ==="

# L3a — registry file not found.
missing_reg_out=""
if [ -f "$RUNNER" ]; then
  missing_reg_out="$(run_runner "$TMP_ROOT/does-not-exist-951.json")"
fi
assert_true "L3a: runner REJECTS a nonexistent registry path (non-zero exit)" \
  "[ -f '$RUNNER' ] && ! ( cd '$PROJECT_ROOT' && bash '$RUNNER' '$TMP_ROOT/does-not-exist-951.json' >/dev/null 2>&1 )"
assert_true "L3a: rejection message names the hazard (not found)" \
  "printf '%s' \"\$missing_reg_out\" | grep -qi 'not found'"

# L3b — malformed JSON.
printf '{ this is not valid json' > "$TMP_ROOT/reg-malformed.json"
malformed_out=""
if [ -f "$RUNNER" ]; then
  malformed_out="$(run_runner "$TMP_ROOT/reg-malformed.json")"
fi
assert_true "L3b: runner REJECTS malformed JSON (non-zero exit)" \
  "[ -f '$RUNNER' ] && ! ( cd '$PROJECT_ROOT' && bash '$RUNNER' '$TMP_ROOT/reg-malformed.json' >/dev/null 2>&1 )"
assert_true "L3b: rejection message names the hazard (not valid JSON)" \
  "printf '%s' \"\$malformed_out\" | grep -qi 'not valid json'"

# L3c — empty .invariants array.
printf '{"invariants": []}' > "$TMP_ROOT/reg-empty.json"
empty_out=""
if [ -f "$RUNNER" ]; then
  empty_out="$(run_runner "$TMP_ROOT/reg-empty.json")"
fi
assert_true "L3c: runner REJECTS an empty .invariants array (non-zero exit)" \
  "[ -f '$RUNNER' ] && ! ( cd '$PROJECT_ROOT' && bash '$RUNNER' '$TMP_ROOT/reg-empty.json' >/dev/null 2>&1 )"
assert_true "L3c: rejection message names the hazard (non-empty array)" \
  "printf '%s' \"\$empty_out\" | grep -qi 'non-empty array'"

# L3d — entry missing a required field (predicate omitted).
printf '{"invariants": [{"id":"951-fixture-missing-field","file":"CLAUDE.md","scope":"permanent"}]}' > "$TMP_ROOT/reg-missing-field.json"
missing_field_out=""
if [ -f "$RUNNER" ]; then
  missing_field_out="$(run_runner "$TMP_ROOT/reg-missing-field.json")"
fi
assert_true "L3d: runner REJECTS an entry missing a required field (non-zero exit)" \
  "[ -f '$RUNNER' ] && ! ( cd '$PROJECT_ROOT' && bash '$RUNNER' '$TMP_ROOT/reg-missing-field.json' >/dev/null 2>&1 )"
assert_true "L3d: rejection message names the hazard (id/file/predicate/scope)" \
  "printf '%s' \"\$missing_field_out\" | grep -qi 'id/file/predicate/scope'"

# L3e — duplicate ids.
printf '{"invariants": [{"id":"951-dup","file":"CLAUDE.md","predicate":"present","literal":"x","scope":"permanent"},{"id":"951-dup","file":"CLAUDE.md","predicate":"present","literal":"y","scope":"permanent"}]}' > "$TMP_ROOT/reg-dup-ids.json"
dup_out=""
if [ -f "$RUNNER" ]; then
  dup_out="$(run_runner "$TMP_ROOT/reg-dup-ids.json")"
fi
assert_true "L3e: runner REJECTS duplicate entry ids (non-zero exit)" \
  "[ -f '$RUNNER' ] && ! ( cd '$PROJECT_ROOT' && bash '$RUNNER' '$TMP_ROOT/reg-dup-ids.json' >/dev/null 2>&1 )"
assert_true "L3e: rejection message names the hazard (unique)" \
  "printf '%s' \"\$dup_out\" | grep -qi 'unique'"

# =============================================================================
echo ""
echo "=== L4: missing-target-file path — entry.file absent at eval time (round-2) ==="

cat > "$TMP_ROOT/reg-missing-file.json" <<JSON
{"\$comment":"L4 missing target file","invariants":[{"id":"951-fixture-missing-file","origin_issue":951,"intent":"existence","file":"tests/fixtures/doc-invariants-nonexistent-951.md","section":null,"predicate":"present","match":"fixed","literal":"x","scope":"permanent"}]}
JSON
missing_file_out=""
if [ -f "$RUNNER" ]; then
  missing_file_out="$(run_runner "$TMP_ROOT/reg-missing-file.json")"
fi
assert_true "L4: registry is well-formed (this is NOT a load-time BLOCK) — Results summary still prints" \
  "printf '%s' \"\$missing_file_out\" | grep -qE '^Results: '"
assert_true "L4: runner does not crash — records the entry FAIL (not silent PASS) and exits non-zero" \
  "[ -f '$RUNNER' ] && ! ( cd '$PROJECT_ROOT' && bash '$RUNNER' '$TMP_ROOT/reg-missing-file.json' >/dev/null 2>&1 )"
assert_true "L4: FAIL message names the hazard (missing target file)" \
  "printf '%s' \"\$missing_file_out\" | grep -qi 'missing target file'"

# =============================================================================
echo ""
echo "=== AC4 (F): shared base-ref resolver — hermetic self-test (ledger E10, library-only) ==="

mk_temp_repo() {
  local dir="$1"
  git init -q "$dir"
  ( cd "$dir" && git config user.email t@example.com && git config user.name t \
      && printf 'a\n' > a.txt && git add a.txt && git commit -q -m init )
}

# (a) explicit override resolves to that commit
REPO_A="$TMP_ROOT/repo-a"
mk_temp_repo "$REPO_A"
SHA_A="$(git -C "$REPO_A" rev-parse HEAD)"
assert_true "resolve_base_ref: explicit override resolves to that commit" \
  "[ -f '$BASEREF_LIB' ] && out=\$( cd '$REPO_A' && bash -c 'source \"$BASEREF_LIB\" && resolve_base_ref \"$SHA_A\"' ) && [ -n \"\$out\" ]"

# (b) GITHUB_BASE_REF set + origin/<branch> present -> resolves via origin
# Round-2 fidelity fix (VERIFY step-4 finding): explicitly PIN the origin's
# branch to a literal "main" before cloning, rather than relying on the
# ambient `git config init.defaultBranch` also being "main" (which held only
# incidentally in the round-1 sandbox). Mirrors REPO_C/REPO_D's own explicit
# pinning below — this is what makes the GITHUB_BASE_REF+origin leg
# (tests/lib/base-ref.sh:34-38) genuinely exercised regardless of host git
# config, instead of possibly falling through unnoticed to the origin/main
# fallback leg (:39-41) on a differently-configured runner.
REPO_B_ORIGIN="$TMP_ROOT/repo-b-origin"
REPO_B="$TMP_ROOT/repo-b"
mk_temp_repo "$REPO_B_ORIGIN"
( cd "$REPO_B_ORIGIN" && git branch -m main 2>/dev/null; true )
git clone -q "$REPO_B_ORIGIN" "$REPO_B" 2>/dev/null
( cd "$REPO_B" && git config user.email t@example.com && git config user.name t \
    && printf 'b\n' > b.txt && git add b.txt && git commit -q -m second )
assert_true "resolve_base_ref: GITHUB_BASE_REF + origin/<branch> resolves via origin (branch pinned explicitly, not ambient-default-dependent)" \
  "[ -f '$BASEREF_LIB' ] && [ \"\$(git -C '$REPO_B_ORIGIN' symbolic-ref --short HEAD)\" = 'main' ] && ( cd '$REPO_B' && GITHUB_BASE_REF=main bash -c 'source \"$BASEREF_LIB\" && resolve_base_ref' >/dev/null 2>&1 )"

# (c) no override/no GITHUB_BASE_REF, no origin, local main present -> resolves via local main
REPO_C="$TMP_ROOT/repo-c"
mk_temp_repo "$REPO_C"
( cd "$REPO_C" && git branch main 2>/dev/null; git checkout -q -b feature-branch 2>/dev/null \
    && printf 'c\n' > c.txt && git add c.txt && git commit -q -m feature )
assert_true "resolve_base_ref: falls back to local 'main' when no override/GITHUB_BASE_REF/origin" \
  "[ -f '$BASEREF_LIB' ] && ( cd '$REPO_C' && env -u GITHUB_BASE_REF bash -c 'source \"$BASEREF_LIB\" && resolve_base_ref' >/dev/null 2>&1 )"

# (d) none resolvable -> loud non-zero return, not silent
REPO_D="$TMP_ROOT/repo-d"
mk_temp_repo "$REPO_D"
# `git branch -D <branch>` fails while HEAD is checked out on that branch
# ("cannot delete branch used by worktree" / "checked out at"), leaving the
# branch present and the base resolvable — detach HEAD first so the local
# default branch can actually be deleted, making the base genuinely
# unresolvable (no override, no GITHUB_BASE_REF, no origin, no local main).
( cd "$REPO_D" && default_branch="$(git symbolic-ref --short HEAD)" \
    && git checkout -q --detach \
    && git branch -D "$default_branch" >/dev/null 2>&1; true )
assert_true "resolve_base_ref: unresolvable base (no override/env/origin/main) returns non-zero (loud, not silent)" \
  "[ -f '$BASEREF_LIB' ] && ! ( cd '$REPO_D' && env -u GITHUB_BASE_REF bash -c 'source \"$BASEREF_LIB\" && resolve_base_ref' >/dev/null 2>&1 )"

# =============================================================================
echo ""
echo "=== AC-a-3 / AC-f (folded in from the retired issue-76 runner-self-test contract suite) ==="

FIXDIR="$PROJECT_ROOT/tests/fixtures"

# ---------------------------------------------------------------------------
# AC-a-3 — --self-test mode exists and is exhaustive.
# ---------------------------------------------------------------------------
assert_true "AC-a-3: run-doc-invariants.sh --help/usage mentions --self-test" \
  "grep -qF -- '--self-test' '$RUNNER'"

assert_true "AC-a-3: run-doc-invariants.sh --self-test exits 0 against the real registry (every entry demonstrates teeth)" \
  "bash '$RUNNER' --self-test >'$TMP_ROOT/selftest.out' 2>&1"

assert_true "AC-a-3: --self-test reports a Results: line distinct from the default-mode PASS/FAIL line format" \
  "grep -qi 'self-test\|teeth\|mutation' '$TMP_ROOT/selftest.out' 2>/dev/null"

assert_true "AC-a-3: default (no-flag) run-doc-invariants.sh behavior is unchanged (still exits 0/1 on the real registry with no --self-test side effects)" \
  "bash '$RUNNER' >'$TMP_ROOT/default.out' 2>&1; grep -qF 'Results:' '$TMP_ROOT/default.out'"

# ---------------------------------------------------------------------------
# AC-f — anchor-resolution negative coverage, hermetic fixtures.
# ---------------------------------------------------------------------------
assert_true "AC-f: a zero-match 'line' anchor is REJECTED at load time (dangling anchor, not silently skipped)" \
  "out=\$(bash '$RUNNER' '$FIXDIR/anchor-resolution-zero-match-registry.json' 2>&1); ec=\$?; [ \$ec -ne 0 ] && printf '%s' \"\$out\" | grep -qi 'dangling'"

assert_true "AC-f: a multi-match 'line' anchor is REJECTED at load time (ambiguous anchor, not first-match silently)" \
  "out=\$(bash '$RUNNER' '$FIXDIR/anchor-resolution-multi-match-registry.json' 2>&1); ec=\$?; [ \$ec -ne 0 ] && printf '%s' \"\$out\" | grep -qi 'ambiguous'"

assert_true "AC-f: a unique 'line' anchor resolves and its predicate evaluates against exactly that one line" \
  "bash '$RUNNER' '$FIXDIR/anchor-resolution-valid-line-registry.json' >'$TMP_ROOT/valid-line.out' 2>&1; grep -qF 'Results: 2/2 passed' '$TMP_ROOT/valid-line.out'"

assert_true "AC-f: a 'block' anchor with no section_end terminates at the thematic break, excluding the '---' line, and the body does not leak into the next block" \
  "bash '$RUNNER' '$FIXDIR/anchor-resolution-block-thematic-break-registry.json' >'$TMP_ROOT/block-thematic.out' 2>&1; grep -qF 'Results: 2/2 passed' '$TMP_ROOT/block-thematic.out'"

assert_true "AC-f: a 'block' anchor with an explicit section_end terminates there (precedence over any later heading/thematic-break), excluding the terminator line itself from the body" \
  "bash '$RUNNER' '$FIXDIR/anchor-resolution-block-explicit-end-registry.json' >'$TMP_ROOT/block-explicit-end.out' 2>&1; grep -qF 'Results: 3/3 passed' '$TMP_ROOT/block-explicit-end.out'"

# ---------------------------------------------------------------------------
# teeth-mode-anchor-destruction — a mutation that destroys a "line"/"block"
# entry's own anchor is a non-credit with a diagnostic, never an abort of the
# whole --self-test run and never a credited FAIL. The runner emits the two
# labels at tests/run-doc-invariants.sh:490 (`NO-TEETH: … unmigratable shape
# …`, the literal-overlaps-anchor pre-check) and :543/:546 (`TEETH: …` on a
# FAIL verdict, `NO-TEETH: … has no teeth` otherwise). --self-test over a
# small fixture registry exercises each named path hermetically, beside the
# whole-registry run above.
# ---------------------------------------------------------------------------
bash "$RUNNER" --self-test "$FIXDIR/anchor-resolution-valid-line-registry.json" >"$TMP_ROOT/teeth-line.out" 2>&1

assert_true "teeth-mode-anchor-destruction: an ordinary present-literal entry (no anchor overlap) is CREDITED — its mutated copy demonstrates teeth" \
  "grep -qE '^  TEETH: issue-76-fixture-valid-line ' '$TMP_ROOT/teeth-line.out'"

assert_true "teeth-mode-anchor-destruction: an entry whose literal OVERLAPS its own column-1 anchor prefix is a NAMED non-credit, not silently skipped and not falsely credited" \
  "grep -qE '^  NO-TEETH: issue-76-fixture-anchor-overlap-unmigratable ' '$TMP_ROOT/teeth-line.out'"

assert_true "teeth-mode-anchor-destruction: the unmigratable-overlap non-credit names its own reason (literal overlaps its own anchor prefix), distinct from an ineffective-mutation or mutator-error non-credit" \
  "grep -qi '^  NO-TEETH: issue-76-fixture-anchor-overlap-unmigratable .*overlaps its own column-1 anchor prefix' '$TMP_ROOT/teeth-line.out'"

assert_true "teeth-mode-anchor-destruction: the run does not abort on the non-credit entry — the credited entry's own result line is still present in the same run" \
  "grep -qE '^  TEETH: issue-76-fixture-valid-line ' '$TMP_ROOT/teeth-line.out' && grep -qE '^  NO-TEETH: issue-76-fixture-anchor-overlap-unmigratable ' '$TMP_ROOT/teeth-line.out'"

# ---------------------------------------------------------------------------
# AC-c-3 clause 2 — every RETAINED scenario document satisfies at least one of
# the five `manual-doc-closure` dependent kinds:
#   1. a registry entry targets it (id path match on the document file);
#   2. a surviving suite asserts on it (content grep for the basename);
#   3. a docs/maintained-docs.md row registers it;
#   4. a prose document (CLAUDE.md, docs/**) cites it as evidence;
#   5. a RETAINED scenario document cites it.
# A workflow `paths:` entry is explicitly NOT a dependent (manual-doc-
# closure), so it is deliberately not checked here.
# ---------------------------------------------------------------------------
RETAINED_DOCS=(
  issue-27 issue-42 issue-51 issue-52 issue-55 issue-56 issue-59 issue-62
  issue-67 issue-71 issue-795 issue-798 issue-799 issue-800 issue-846
  issue-847 issue-848 issue-985
)
for name in "${RETAINED_DOCS[@]}"; do
  docfile="tests/manual/${name}-manual-scenarios.md"
  [ -f "$PROJECT_ROOT/$docfile" ] || continue
  has_dependent=false
  # Kind 1: registry entry names the document as its file.
  jq -e --arg f "$docfile" '.invariants[] | select(.file == $f)' "$REGISTRY" >/dev/null 2>&1 && has_dependent=true
  # Kind 2: a surviving suite content-references the document's basename.
  base="${name}-manual-scenarios"
  grep -rl -- "$base" "$PROJECT_ROOT/tests" 2>/dev/null | grep -vF "/$docfile" | grep -q . && has_dependent=true
  # Kind 3: a docs/maintained-docs.md row registers it.
  grep -qF "$base" "$PROJECT_ROOT/docs/maintained-docs.md" 2>/dev/null && has_dependent=true
  # Kind 4: a prose document cites it as evidence.
  grep -rlF -- "$base" "$PROJECT_ROOT/CLAUDE.md" "$PROJECT_ROOT/docs" 2>/dev/null | grep -q . && has_dependent=true
  # Kind 5: a retained sibling scenario document cites it.
  grep -rlF -- "$base" "$PROJECT_ROOT/tests/manual" 2>/dev/null | grep -vF "/$docfile" | grep -q . && has_dependent=true
  assert_true "AC-c-3 clause 2: retained scenario document satisfies >=1 of the five dependent kinds — $name" "$has_dependent"
done

# =============================================================================
echo ""
echo "=============================="
echo "Results: $PASS/$TESTS passed, $FAIL failed"
echo "=============================="

[[ $FAIL -gt 0 ]] && exit 1
exit 0
