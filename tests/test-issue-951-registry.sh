#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# Test: doc-invariant registry + single runner + base-ref resolver — Issue #951
# =============================================================================
# RED->GREEN harness per .autoflow/issue-951-verification-design.md (ROUND 1-3,
# Test AI ACCEPT) and .autoflow/issue-951-feature-design.md, converged decisions
# in .autoflow/issue-951-ledger.md (E4-E15). assert_true/assert_false pattern
# per tests/test-issue-794-doc-assertions.sh; hermetic temp-repo pattern for
# base-ref.sh per tests/test-issue-788-host-purity-delta.sh (DR-1 precedent).
#
# Interface assumption (minimal, non-AC-affecting): tests/run-doc-invariants.sh
# accepts an OPTIONAL positional arg — an alternate registry JSON path — so
# this suite can hermetically drive the runner against fixture (bad/mutated)
# registries without touching the real tests/fixtures/doc-invariants.json.
# With no arg it MUST default to tests/fixtures/doc-invariants.json (its
# normal CI invocation, feature §6.1). This mirrors base-ref.sh's own
# override-first precedence (feature §4.1) and the #788 --base/--head
# injection seam; it is an implementation-interface detail, not an AC change.
#
# Migration set (pinned, ledger/feature §6): 794, 796, 797, 800, 949.
#
# Coverage map (verification design §1-§4, feature §7):
#   AC1 - registry declarative + parseable, no per-issue hand-code (A)
#       - capture-before-delete baseline + positive/negative/coverage-floor
#         fidelity legs (B), window-equivalence spot-check (ledger E12) (B)
#   AC2 - lifetime rule doc (C), scope field required (C), runner rejects
#         non-permanent/diff-predicate entries at load (C)
#   AC3 - cases 1/2/3/6/7/8 (D), 797 non-vacuity positive control / C5 (D)
#   AC4 - base-ref.sh hermetic self-test (F), ledger E10 (no live call site
#         this cycle -> library-level contract only, no caller wrapper test)
#   AC5 - CI convergence static YAML + discovery self-test (G)
#   C6  - anchor well-formedness: dangling/ambiguous anchor rejection (E)
#   Deletion (H), manifest closure / DR-8 (I), DR-6 no exemption arrays (J),
#   DR-7 self-registration in e2e-dummy-target.yml paths: (K)
#
# RED expectation: registry/runner/lib/doc do not exist yet at HEAD, so every
# assertion in sections A-B (structural+fidelity), C (mechanism), D (repro
# cases requiring the runner), E (C6), F (base-ref.sh absent), G/H (CI
# convergence/deletion), I (manifest closure) FAILs. A handful of
# preservation-type checks (pre-existing docs present, 794/796/797 already
# absent as individual CI steps) are expected to PASS now and remain PASS
# post-GREEN — matching the precedent in tests/test-issue-794-doc-assertions.sh.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

REGISTRY="$PROJECT_ROOT/tests/fixtures/doc-invariants.json"
RUNNER="$PROJECT_ROOT/tests/run-doc-invariants.sh"
BASEREF_LIB="$PROJECT_ROOT/tests/lib/base-ref.sh"
LIFECYCLE_DOC="$PROJECT_ROOT/docs/doc-invariant-registry.md"
WORKFLOW="$PROJECT_ROOT/.github/workflows/e2e-dummy-target.yml"
BASELINE="$PROJECT_ROOT/tests/fixtures/doc-invariants-baseline.txt"
ANCHOR_FIXTURE="$PROJECT_ROOT/tests/fixtures/doc-invariants-anchor-fixture.md"
ANCHOR_FIXTURE_REL="tests/fixtures/doc-invariants-anchor-fixture.md"
DIALECT_FIXTURE="$PROJECT_ROOT/tests/fixtures/doc-invariants-dialect-fixture.md"
INDEX_MD="$PROJECT_ROOT/docs/INDEX.md"
MAINTAINED_DOCS="$PROJECT_ROOT/docs/maintained-docs.md"
MANIFEST_JSON="$PROJECT_ROOT/setup/manifest.json"

OLD_SUITES=(
  "$PROJECT_ROOT/tests/test-issue-794-doc-assertions.sh"
  "$PROJECT_ROOT/tests/test-issue-796-doc-assertions.sh"
  "$PROJECT_ROOT/tests/test-issue-797-doc-invocation.sh"
  "$PROJECT_ROOT/tests/test-issue-800-doc-assertions.sh"
  "$PROJECT_ROOT/tests/test-issue-949-manifest-regen-doc.sh"
)

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

TMP_ROOT="$PROJECT_ROOT/tests/fixtures/.tmp-951-$$"
cleanup() { rm -rf "$TMP_ROOT" 2>/dev/null || true; }
trap cleanup EXIT
mkdir -p "$TMP_ROOT"

# =============================================================================
echo "=== Pre-flight: target files present (pre-existing docs, expected PASS now) ==="
assert_true "present: CLAUDE.md" "[ -f '$PROJECT_ROOT/CLAUDE.md' ]"
assert_true "present: docs/INDEX.md" "[ -f '$INDEX_MD' ]"
assert_true "present: docs/maintained-docs.md" "[ -f '$MAINTAINED_DOCS' ]"
assert_true "present: setup/manifest.json" "[ -f '$MANIFEST_JSON' ]"
assert_true "present: .github/workflows/e2e-dummy-target.yml" "[ -f '$WORKFLOW' ]"
assert_true "capture-before-delete baseline exists (this RED run, E5)" "[ -s '$BASELINE' ]"

# =============================================================================
echo ""
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
assert_true "registry volume is on the order of 80-120 entries (feature §6 estimate)" \
  "[ -f '$REGISTRY' ] && jq -e '(.invariants | length) >= 60' '$REGISTRY' >/dev/null 2>&1"

assert_true "runner script exists (tests/run-doc-invariants.sh)" "[ -f '$RUNNER' ]"
assert_false "runner does not hardcode registry heading text (data-driven discovery, no per-invariant branch)" \
  "[ -f '$RUNNER' ] && grep -qF 'PR Flow' '$RUNNER'"
assert_true "runner reads the registry via jq (no per-issue if/else literal branches)" \
  "[ -f '$RUNNER' ] && grep -qF 'jq' '$RUNNER'"
assert_false "runner does not hand-code per-issue literal branches (794/796/797/800/949)" \
  "[ -f '$RUNNER' ] && grep -qE 'issue-?(794|796|797|800|949)' '$RUNNER'"

# =============================================================================
echo ""
echo "=== AC1 (B): fidelity — capture-before-delete baseline reproduction (§DR-3/C1, ledger E5) ==="

# Positive leg: every registry entry evaluates PASS against the CURRENT
# (pre-migration) tree — the permanent invariants already hold today, which
# is exactly what the captured baseline shows for the migrated suites.
assert_true "positive leg: every registry entry PASSes against the current tree" \
  "[ -f '$REGISTRY' ] && [ -f '$RUNNER' ] && run_runner '$REGISTRY' | grep -qE '^Results: ' && ! run_runner '$REGISTRY' | grep -qE '^  FAIL:'"

# Coverage-floor leg: each migrated suite (794/796/797/800/949) is
# represented by at least one registry entry via origin_issue provenance —
# a coverage floor standing in for "every permanent assertion transcribed"
# (full completeness is the manual migration-map judgement per verification
# design §1/§3 — see tests/manual/issue-951-manual-scenarios.md).
for oi in 794 796 797 800 949; do
  assert_true "coverage floor: registry carries >=1 entry with origin_issue == $oi" \
    "[ -f '$REGISTRY' ] && jq -e '[.invariants[] | select(.origin_issue == $oi)] | length >= 1' '$REGISTRY' >/dev/null 2>&1"
done

# Negative-teeth leg (C1, generic/data-driven — no hardcoded per-id fixtures):
# for every present/absent/ordered entry, a mutated copy of its target file
# (literal stripped/injected, or the 'before' anchor removed) must flip the
# verdict to FAIL, proving the migrated check still bites.
mutation_teeth_check() {
  [ -f "$REGISTRY" ] && [ -f "$RUNNER" ] || return 1
  local ids total=0 ok=0 tdir
  ids="$(jq -r '.invariants[].id' "$REGISTRY" 2>/dev/null)" || return 1
  [ -n "$ids" ] || return 1
  tdir="$TMP_ROOT/teeth"
  mkdir -p "$tdir"
  local id entry file predicate literal before section match srcfile mutated relmut regfile verdict
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    entry="$(jq -c --arg id "$id" '.invariants[] | select(.id == $id)' "$REGISTRY")"
    file="$(printf '%s' "$entry" | jq -r '.file')"
    predicate="$(printf '%s' "$entry" | jq -r '.predicate')"
    srcfile="$PROJECT_ROOT/$file"
    [ -f "$srcfile" ] || continue
    mutated="$tdir/$(basename "$file").$$.mut"
    case "$predicate" in
      present)
        literal="$(printf '%s' "$entry" | jq -r '.literal')"
        grep -vF "$literal" "$srcfile" > "$mutated" 2>/dev/null || cp "$srcfile" "$mutated"
        ;;
      absent)
        literal="$(printf '%s' "$entry" | jq -r '.literal')"
        section="$(printf '%s' "$entry" | jq -r '.section // ""')"
        if [ -n "$section" ]; then
          # Section-scoped absent entry: an EOF-append lands OUTSIDE a
          # non-last target section (the runner's extractor closes the body
          # at the next same-or-higher-level heading / section_end / ---
          # terminator), so the runner would correctly record PASS and this
          # leg would misread the intact check as "no teeth". Inject the
          # literal INSIDE the section instead — immediately after the
          # section heading line, the earliest line of the extracted body
          # (in scope for every terminator shape). Heading match mirrors the
          # runner's extract_section: strip leading #s + trailing whitespace,
          # exact text equality. The literal is passed via ENVIRON (not
          # awk -v) so backslashes are not escape-processed.
          MUT_LIT="$literal" awk -v h="$section" '
            { print }
            !done && /^#{1,6} +/ {
              t=$0; sub(/^#{1,6} +/,"",t); sub(/[ \t]+$/,"",t)
              if (t==h) { print ENVIRON["MUT_LIT"]; done=1 }
            }
          ' "$srcfile" > "$mutated"
        else
          # Whole-file entry: any location is in scope — EOF-append suffices.
          cp "$srcfile" "$mutated"
          printf '\n%s\n' "$literal" >> "$mutated"
        fi
        ;;
      ordered)
        before="$(printf '%s' "$entry" | jq -r '.before')"
        grep -vF "$before" "$srcfile" > "$mutated" 2>/dev/null || cp "$srcfile" "$mutated"
        ;;
      *) continue ;;
    esac
    total=$((total + 1))
    relmut="tests/fixtures/.tmp-951-$$/teeth/$(basename "$mutated")"
    regfile="$tdir/reg-$$.json"
    jq --arg id "$id" --arg file "$relmut" \
      '{ "$comment": "teeth-fixture", invariants: [ (.invariants[] | select(.id == $id) | .file = $file) ] }' \
      "$REGISTRY" > "$regfile"
    verdict="$(verdict_for_id "$regfile" "$id")"
    [ "$verdict" = "FAIL" ] && ok=$((ok + 1))
  done <<EOF_IDS
$ids
EOF_IDS
  [ "$total" -gt 0 ] && [ "$ok" -eq "$total" ]
}
assert_true "negative-teeth leg: every present/absent/ordered entry FAILs its mutated fixture (data-driven, C1)" \
  "mutation_teeth_check"

# Window-equivalence spot-check (ledger E12 worked example): the 794 ordering
# entry over CLAUDE.md's level-3 "### PR Flow" heading is self-contained
# (body 363-368) and both anchors resolve inside it without widening to
# section:null.
assert_true "window-equivalence spot-check: 794-AC1-ordering-target-centric present with file=CLAUDE.md section='PR Flow'" \
  "[ -f '$REGISTRY' ] && jq -e '.invariants[] | select(.id == \"794-AC1-ordering-target-centric\") | (.file == \"CLAUDE.md\") and (.section == \"PR Flow\") and (.predicate == \"ordered\")' '$REGISTRY' >/dev/null 2>&1"
assert_true "window-equivalence spot-check: that entry PASSes against real CLAUDE.md (body covers both anchors, ledger E12)" \
  "[ -f '$REGISTRY' ] && [ -f '$RUNNER' ] && [ \"\$(verdict_for_id '$REGISTRY' 794-AC1-ordering-target-centric)\" = 'PASS' ]"

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
CASE1_FILE_REL="tests/fixtures/.tmp-951-$$/case1-fixture.md"
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
assert_true "case 7: 799's live suite is untouched this cycle (test-issue-799-inert-cleanup.sh still present)" \
  "[ -f '$PROJECT_ROOT/tests/test-issue-799-inert-cleanup.sh' ]"

# --- 797-style whole-file absent non-vacuity (C5) ---
DIALECT_SEEDED_REL="tests/fixtures/.tmp-951-$$/dialect-seeded.md"
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

# --- Retired-guard dispositions recorded (C3, ledger E13) ---
assert_true "retired-guard dispositions recorded: feature/docs record disposition for each retired DELTA guard" \
  "[ -f '$LIFECYCLE_DOC' ] && grep -qi 'dropped\|promot\|deferred' '$LIFECYCLE_DOC'"

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

REGEX_FILE_REL="tests/fixtures/.tmp-951-$$/regex-fixture.md"
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

SECTIONEND_FILE_REL="tests/fixtures/.tmp-951-$$/section-end-fixture.md"
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
echo "=== AC5 (G): CI convergence — single runner step replaces per-issue steps ==="

assert_true "workflow references the single runner step (bash tests/run-doc-invariants.sh)" \
  "grep -qF 'run: bash tests/run-doc-invariants.sh' '$WORKFLOW'"
assert_false "workflow no longer runs the #800 doc-assertions step" \
  "grep -qF 'run: bash tests/test-issue-800-doc-assertions.sh' '$WORKFLOW'"
assert_false "workflow no longer runs the #949 manifest-regen-doc step" \
  "grep -qF 'run: bash tests/test-issue-949-manifest-regen-doc.sh' '$WORKFLOW'"
assert_false "workflow paths: no longer lists tests/test-issue-800-doc-assertions.sh" \
  "grep -qF \"'tests/test-issue-800-doc-assertions.sh'\" '$WORKFLOW'"
assert_false "workflow paths: no longer lists tests/test-issue-949-manifest-regen-doc.sh" \
  "grep -qF \"'tests/test-issue-949-manifest-regen-doc.sh'\" '$WORKFLOW'"
assert_true "AC5 case-4a: previously-unregistered 794/796/797 are now reachable through the single runner step" \
  "[ -f '$REGISTRY' ] && jq -e '[.invariants[] | select(.origin_issue == 794 or .origin_issue == 796 or .origin_issue == 797)] | length >= 3' '$REGISTRY' >/dev/null 2>&1"

# =============================================================================
echo ""
echo "=== Deletion (H): the five migrated suites and their two CI steps are gone ==="

for f in "${OLD_SUITES[@]}"; do
  rel="${f#"$PROJECT_ROOT"/}"
  assert_true "deleted: $rel" "[ ! -f '$f' ]"
done

# =============================================================================
echo ""
echo "=== Manifest closure (I): docs/doc-invariant-registry.md enters the closure (§DR-8, ledger E14) ==="

assert_true "docs/INDEX.md links docs/doc-invariant-registry.md (enters the markdown-link closure)" \
  "grep -qF 'doc-invariant-registry.md' '$INDEX_MD'"
assert_true "docs/maintained-docs.md registers docs/doc-invariant-registry.md" \
  "grep -qF 'doc-invariant-registry.md' '$MAINTAINED_DOCS'"
assert_true "setup/manifest.json carries a source+sha256 row for docs/doc-invariant-registry.md" \
  "jq -e '.artifacts[] | select(.source == \"docs/doc-invariant-registry.md\")' '$MANIFEST_JSON' >/dev/null 2>&1"
assert_true "manifest sha256 for the new doc equals its current source hash (freshness, AC2e oracle)" \
  "[ -f '$LIFECYCLE_DOC' ] && manifest_sha=\$(jq -r '.artifacts[] | select(.source == \"docs/doc-invariant-registry.md\") | .sha256' '$MANIFEST_JSON' 2>/dev/null) && actual_sha=\$(shasum -a 256 '$LIFECYCLE_DOC' 2>/dev/null | awk '{print \$1}') && [ -n \"\$manifest_sha\" ] && [ \"\$manifest_sha\" = \"\$actual_sha\" ]"

# =============================================================================
echo ""
echo "=== §DR-6 (J): no residual per-issue exemption arrays ==="

assert_false "registry does not carry an exempt_955_patterns-style array" \
  "[ -f '$REGISTRY' ] && grep -qF 'exempt_955_patterns' '$REGISTRY'"
assert_false "runner does not carry an exempt_955_patterns-style array" \
  "[ -f '$RUNNER' ] && grep -qF 'exempt_955_patterns' '$RUNNER'"

# =============================================================================
echo ""
echo "=== §DR-7 (K): new infra self-registration in e2e-dummy-target.yml paths: ==="

for artifact in 'tests/run-doc-invariants.sh' 'tests/fixtures/doc-invariants.json' 'tests/lib/base-ref.sh'; do
  assert_true "workflow paths: registers $artifact (both pull_request + push blocks, >=2 occurrences)" \
    "[ \"\$(grep -cF \"'$artifact'\" '$WORKFLOW')\" -ge 2 ]"
done

# =============================================================================
# Results
# ---------------------------------------------------------------------------
echo ""
echo "=============================="
echo "Results: $PASS/$TESTS passed, $FAIL failed"
echo "=============================="

[[ $FAIL -gt 0 ]] && exit 1
exit 0
