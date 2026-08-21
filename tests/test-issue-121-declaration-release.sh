#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: .claude/hooks/check-autoflow-gate.sh .claude/hooks/check-read-dedup.sh .claude/workflows/ .github/workflows/contract-suites.yml CLAUDE.md README.md docs/adr/0015-autoflow-distribution-plugin-plus-thin-root-layer.md docs/autoflow-guide.md docs/doc-invariant-registry.md docs/external-review-sequencing.md docs/git-workflow.md docs/repo-boundary-rules.md docs/teammate-contracts.md plugin/autoflow/hooks/check-autoflow-gate.sh plugin/autoflow/hooks/check-read-dedup.sh scripts/test/check-manifest-regen-clean.sh scripts/test/suite-coverage.sh scripts/test/suite-manifest.sh setup/manifest.json tests/fixtures/doc-invariants.json tests/plugin/verify-package.sh tests/test-issue-109-doc-assertions.sh tests/test-issue-27-composition-oracle.sh tests/test-issue-62-sequential-rounds.sh tests/test-issue-67-deliberation-record.sh tests/test-issue-69-verification-depth.sh tests/test-issue-788-host-purity-delta.sh tests/test-issue-798-topology-flip.sh tests/test-issue-799-inert-cleanup.sh tests/test-issue-952-wizard-removal.sh tests/test-issue-955-subagent-background-ban.sh tests/test-push-context-base-ref.sh
# lane: cycle-scoped
# retire-with: #121
# cycle-arm: #121
# budget-secs: SUITE_BUDGET_CEILING_SECS
# out-of-tree-inputs: yes
# =============================================================================
# Test: out-of-tree declaration release + verdict-inheritance restoration —
# Issue #121
# =============================================================================
# Verification design: .autoflow/issue-121-verification-design.md. This file is
# the cycle-scoped carrier of the layers that document's "New spec file"
# paragraph assigns to it:
#
#   L1  declaration-state              (+ delta-scanner-untouched, opposite direction)
#   L2  declaration-reason-token       (real scripts/test/suite-coverage.sh)
#   L3  ci-subject-accuracy            (token/reference predicate over executable bodies)
#   L4  symbol-closure                 (both directions, per symbol)
#   L5  id-inventory-closure           (banner axis, header axis, cross-file axis)
#   L6  converted-arm-consumer-closure (pin membership re-derived + comment-borne alternate)
#   L7  provenance-state               (registry §16 rows, supersession, promoted entry shape)
#   L8  subsumption-differential       (each *dropped — redundant* arm's fault → carrier reds)
#   L9  residue-differential           (each *with recorded coverage loss* row, both directions)
#   L10 array-subject-enumeration      (§12's coupling passage — the N1 resolution, below)
#
# WHY THIS SUITE EXISTS AT ALL. Every existing lint in this tree checks that a
# declaration is PRESENT when it is needed. None checks that one was REMOVED
# when it stopped being needed — `check-suite-manifest.sh`'s out-of-tree
# obligation is presence-only, and the coverage resolver reads `yes` without
# judging it. That asymmetry is the merge-cleanup gap the issue names as its
# root cause, and this suite is its first carrier.
#
# LEAF RULE (scripts/test/check-suite-leaf.sh). This suite drives PRODUCT
# scripts (suite-coverage.sh, check-manifest-regen-clean.sh) and reads suite
# files as text; the only suite it EXECUTES is tests/plugin/verify-package.sh,
# and only inside a scratch copy of the tree at a perturbed on-disk state,
# which the lint's I4 row admits by construction (a scratch root is not the
# registered sibling; the sibling's own unperturbed CI step cannot stand in for
# a negative control). The real runs the verification design names as witnesses
# for `converted-arm-consumer-closure`, `id-inventory-closure`'s cross-file
# direction and `array-subject-enumeration` belong to the whole-tree sweep
# (`scripts/test/run-suites.sh --all`), which executes each of those suites
# under its own name — re-running them here would be exactly the duplicate
# execution the leaf rule denies. What this suite carries instead is the STATE
# predicate half of each of those rows, which no run reads.
#
# N1 RESOLUTION (GATE:PLAN #3, "Carried into DISPATCH"). This suite is
# `lane: cycle-scoped` with `retire-with: #121`, and it declares a path
# allow-list array, so it also carries `cycle-arm: #121`. It therefore does NOT
# enter the set docs/doc-invariant-registry.md §12's coupling passage names:
# that passage's subject is the STANDING suites that carry a cycle-scoped arm
# ("This tree's three such suites ... are standing"), which is the converse the
# passage deliberately leaves unasserted. L10 below is scoped to that set
# accordingly — derived from the tree, never from a literal list written here —
# so this suite's own array cannot falsify it.
#
# N2 RESOLUTION: `# lane: cycle-scoped` + `# retire-with: #121` are declared in
# the header above, alongside the four registration parts §4 already names.
#
# N4 RESOLUTION: L9's `.claude/hooks/**` residue drive set carries the third
# case as well — an edit to a `.claude/hooks/**` file other than
# check-autoflow-gate.sh whose plugin mirror is updated in the same diff, which
# the deleted arms rejected and the carrier admits.
#
# RED-TIME EXPECTATION. Every leg below whose subject is the ABSENCE of an arm,
# a symbol, an id, a token or a declaration FAILs at RED — the arms are still
# present at HEAD. The legs that assert RETENTION (the 788 declaration, the
# kept symbols, the surviving `ci-subject` tokens) are non-vacuity controls and
# PASS both pre- and post-change BY DESIGN: without them a GREEN that deleted
# everything, or a resolver that stopped emitting reason tokens at all, would
# satisfy the absence halves. Each such arm is labelled `(guard, PASS pre+post)`
# in its own description, so a reader can separate the two classes from the
# run output alone. The differential legs (L8/L9) are likewise stated in both
# directions and each direction is labelled.
#
# ON `select-suites.sh` — the verification design's `ci-subject-accuracy`
# method (a) is REFUTED at this HEAD and is not implemented. That method drives
# the real selector over a delta naming only `tests/lib/base-ref.sh` and
# requires suites 67/69/27 NOT to be SELECTED. The selector short-circuits on
# `tests/lib/**` before it ever reaches the `ci-subject` token loop
# (scripts/test/select-suites.sh:191-194 sets `lib_touched`, consumed at
# :208 ahead of the token match at :217-227), so EVERY enumerated suite is
# SELECTED on such a delta whether or not it declares the token. The leg would
# be green on the defective tree and green on the correct one — vacuous in both
# directions. A12 states the property over tokens and reads, not over the
# selector, so L3 holds it with method (b) alone.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=scripts/test/suite-manifest.sh
. "$PROJECT_ROOT/scripts/test/suite-manifest.sh"
# shellcheck source=tests/lib/base-ref.sh
. "$PROJECT_ROOT/tests/lib/base-ref.sh"

REGISTRY_MD="$PROJECT_ROOT/docs/doc-invariant-registry.md"
INVARIANTS_JSON="$PROJECT_ROOT/tests/fixtures/doc-invariants.json"
GUIDE="$PROJECT_ROOT/docs/autoflow-guide.md"
INV109="$PROJECT_ROOT/tests/test-issue-109-doc-assertions.sh"
PUSHCTX="$PROJECT_ROOT/tests/test-push-context-base-ref.sh"

CONVERTED=(
  "tests/test-issue-67-deliberation-record.sh"
  "tests/test-issue-69-verification-depth.sh"
  "tests/test-issue-798-topology-flip.sh"
  "tests/test-issue-799-inert-cleanup.sh"
  "tests/test-issue-952-wizard-removal.sh"
  "tests/test-issue-955-subagent-background-ban.sh"
  "tests/test-issue-27-composition-oracle.sh"
)
KEEPS_DECLARATION="tests/test-issue-788-host-purity-delta.sh"

PASS=0; FAIL=0; TESTS=0

assert_true() {
  local desc="$1" condition="$2"
  TESTS=$((TESTS + 1))
  if (cd "$PROJECT_ROOT" && eval "$condition"); then
    echo "  PASS: $desc"; PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"; FAIL=$((FAIL + 1))
  fi
}

note_deferred() { echo "  DEFERRED-OBSERVABLE: $1"; }

# ---------------------------------------------------------------------------
# Text helpers. Each reads the tree; none carries a literal the tree does not.
# ---------------------------------------------------------------------------

# `grep -q` SHORT-CIRCUITS: it exits at the first match, which SIGPIPEs a
# producer that has not finished writing, and under `set -o pipefail` that
# turns a TRUE match into a non-zero pipeline status — a silent false verdict,
# the #964 hazard class. It produced one during this suite's own RED run: the
# orphan predicate over tests/test-issue-62-sequential-rounds.sh reported PASS
# while the symbol was plainly still defined, because the match landed at line
# 72 of ~500 and the upstream filter died mid-write. `gq` reads its input to
# EOF instead (grep -c must count every line), so the producer always
# completes; its exit status is `grep -q`'s unchanged — 0 iff at least one line
# matched. Every membership test in this file goes through it.
gq() { grep -c "$@" >/dev/null; }

# The suite's leading comment block, on the same boundary
# tests/test-issue-109-doc-assertions.sh's own `suite_header` helper uses.
hdr_block() { awk '/^set -uo pipefail/{exit} {print}' "$1"; }

# The executable body: every line that is not a whole-line comment. The
# comment-only exclusion is not coined here — check-suite-manifest.sh's own
# self-test fixture tests/test-fx-oot-commentonly.sh names `resolve_base_ref`
# on a `#` line and is required to CONFORM, so the sibling out-of-tree field
# already reads a comment mention as a non-reference.
exec_body() { grep -vE '^[[:space:]]*#' "$1"; }

# Bare-token occurrence count of an id inside a text blob (the bounded form
# tests/test-issue-109-doc-assertions.sh uses for its header arms).
bounded_count() {
  printf '%s\n' "$2" | grep -oE "(^|[^A-Za-z0-9_-])$1([^A-Za-z0-9_.-]|\$)" | grep -c . || true
}

# Every `echo "=== <id> ..."` banner in a suite that retains no assert_true /
# assert_false between it and the next banner. This is the BANNER id axis: the
# id that names the section header, which need not be any id its arms carry.
assertless_banners() {
  awk '
    /echo "=== /{
      if (cur != "" && !seen) print cur
      l = $0
      sub(/.*echo "=== /, "", l)
      sub(/[[:space:]].*$/, "", l)
      sub(/".*$/, "", l)
      cur = l; seen = 0; next
    }
    /assert_true|assert_false/{ if (cur != "") seen = 1 }
    END { if (cur != "" && !seen) print cur }
  ' "$1"
}

# A shell array literal's body, located by name. Handles the single-line form
# (`NAME=("a" "b")`) and the multi-line form closed by a column-1 `)`.
array_block() {
  awk -v n="$2" '
    !f && index($0, n "=(") == 1 {
      f = 1; print
      if ($0 ~ /\)[[:space:]]*$/) exit
      next
    }
    f { print; if ($0 ~ /^\)/) exit }
  ' "$1"
}
array_has()  { array_block "$1" "$2" | gq -F "\"$3\""; }
array_derefs() { grep -cF "\${$2[@]}" "$1"; }

# Which arrays in a file carry a given quoted member.
arrays_holding() {
  local file="$1" member="$2" name
  for name in $(grep -oE '^[A-Za-z_][A-Za-z0-9_]*=\(' "$file" | sed 's/=($//;s/=(//' | sort -u); do
    array_has "$file" "$name" "$member" && printf '%s\n' "$name"
  done
}

# The derived base-ref subject set, recomputed with the CONSUMING file's own
# criteria against the live tree — main-push-registered `run: bash tests/…`
# steps, minus that file's own EXEMPT_HERMETIC_DRIVERS and its own path,
# filtered through the real `suite_reads_out_of_tree_state`. Membership is
# derived, never compared against a list written into this suite.
derive_pushctx_subjects() {
  local self_rel="tests/test-push-context-base-ref.sh" wf rel exempt
  exempt="$(array_block "$PUSHCTX" EXEMPT_HERMETIC_DRIVERS | grep -oE '"[^"]*"' | tr -d '"')"
  for wf in "$PROJECT_ROOT"/.github/workflows/*.yml; do
    gq -E 'branches: *\[ *main *\]' "$wf" 2>/dev/null || continue
    grep -oE 'run: *bash +tests/[A-Za-z0-9/_.-]+\.sh' "$wf" | sed -E 's/^run: *bash +//'
  done | sort -u | while read -r rel; do
    [ -n "$rel" ] || continue
    [ -f "$PROJECT_ROOT/$rel" ] || continue
    [ "$rel" = "$self_rel" ] && continue
    printf '%s\n' "$exempt" | gq -xF "$rel" && continue
    suite_reads_out_of_tree_state "$PROJECT_ROOT/$rel" && printf '%s\n' "$rel"
  done
}

# --- differential drivers -------------------------------------------------
# Each driver builds its OWN scratch copy of the real tree, applies one named
# perturbation to it, drives one real carrier over it, and removes it. `.git`
# and the gitignored `.autoflow` are excluded — neither is an input to any
# carrier driven below, and copying `.git` would dominate this suite's runtime.
# The working tree is NEVER written.
#
# The scratch root is assigned from `mktemp -d` INSIDE each driver rather than
# passed in as a positional. That is not a style choice: check-suite-leaf.sh's
# I4 row exempts an invocation whose path root is a variable this file assigns
# from `mktemp` / `git worktree add`, and a positional parameter carries no
# such provenance, so the plugin verifier's drive below reads as a D5 sibling
# invocation under any other shape. The perturbation is therefore passed as a
# FUNCTION NAME and applied to the driver's own root.

scratch_copy() {              # <dest dir>
  ( cd "$PROJECT_ROOT" && tar --exclude='./.git' --exclude='./.autoflow' -cf - . ) \
    | ( cd "$1" && tar -xf - ) 2>/dev/null
}

perturb_none()            { :; }
perturb_adr0015()         { printf '\n<!-- issue-121 differential -->\n' >> "$1/docs/adr/0015-autoflow-distribution-plugin-plus-thin-root-layer.md"; }
perturb_claude_md()       { printf '\n<!-- issue-121 differential -->\n' >> "$1/CLAUDE.md"; }
perturb_guide()           { printf '\n<!-- issue-121 differential -->\n' >> "$1/docs/autoflow-guide.md"; }
perturb_registered_wf()   { printf '\n// issue-121 differential\n' >> "$1/.claude/workflows/architect-deliberation.js"; }
perturb_unregistered_wf() { printf '// issue-121 differential\n' > "$1/.claude/workflows/issue-121-residue.js"; }
perturb_gate_hook_only()  { printf '\n# issue-121 differential\n' >> "$1/.claude/hooks/check-autoflow-gate.sh"; }
perturb_third_hook()      { printf '#!/usr/bin/env bash\ntrue\n' > "$1/.claude/hooks/check-issue-121-residue.sh"; }
perturb_dedup_mirrored()  {
  printf '\n# issue-121 differential\n' \
    | tee -a "$1/.claude/hooks/check-read-dedup.sh" >> "$1/plugin/autoflow/hooks/check-read-dedup.sh"
}

# FIXED POINT verdict of the real regeneration lint after one perturbation.
# Prints `red` or `green`; anything else is a driver failure, reported as such
# rather than silently read as either verdict.
fixed_point_after() {         # <perturbation function name>
  local S out
  S="$(mktemp -d)"
  scratch_copy "$S"
  "$1" "$S"
  out="$(bash "$PROJECT_ROOT/scripts/test/check-manifest-regen-clean.sh" --root "$S" 2>&1)"
  rm -rf "$S"
  if printf '%s\n' "$out" | gq -F 'FIXED POINT leg OK'; then
    printf 'green\n'
  elif printf '%s\n' "$out" | gq -F 'FIXED POINT leg'; then
    printf 'red\n'
  else
    printf 'driver-error\n'
  fi
}

# AC5-parity verdict of the real plugin verifier after one perturbation. Keyed
# on the parity records rather than on the whole-suite exit code: the row's
# carrier is AC5's byte-equality half, and a scratch copy can perturb unrelated
# legs of that suite without saying anything about it.
ac5_parity_after() {          # <perturbation function name>
  local S out
  S="$(mktemp -d)"
  scratch_copy "$S"
  "$1" "$S"
  out="$(sh "$S/tests/plugin/verify-package.sh" 2>&1)"
  rm -rf "$S"
  if printf '%s\n' "$out" | gq '^FAIL: AC5 parity'; then
    printf 'red\n'
  elif printf '%s\n' "$out" | gq '^PASS: AC5 parity'; then
    printf 'green\n'
  else
    printf 'driver-error\n'
  fi
}

# =============================================================================
echo ""
echo "=== L1 declaration-state — the converted suites carry no out-of-tree header, and the delta scanner keeps its own ==="
# The header lint CONFORMS on a stale `yes` and equally on a retained explicit
# `no`, and the resolver decides its reason token from `yes` alone. The
# retained-`no` spelling is therefore the one state no other layer in the tree
# reads, which is what this leg is for.

for s in "${CONVERTED[@]}"; do
  assert_true "L1 declaration-state: $s carries no '# out-of-tree-inputs:' header line at all (a retained explicit 'no' conforms to every existing lint)" \
    "! hdr_block '$PROJECT_ROOT/$s' | gq -E '^# out-of-tree-inputs:'"
  assert_true "L1 declaration-state: suite_reads_out_of_tree_state returns false for $s (per-file acceptance is the predicate, not a reading of the diff)" \
    "! suite_reads_out_of_tree_state '$PROJECT_ROOT/$s'"
done

assert_true "L1 delta-scanner-untouched (guard, PASS pre+post): $KEEPS_DECLARATION still declares '# out-of-tree-inputs: yes' — it is a diff-scoped scanner by construction, the essential case the field exists for" \
  "hdr_block '$PROJECT_ROOT/$KEEPS_DECLARATION' | gq -E '^# out-of-tree-inputs: yes\$'"
assert_true "L1 delta-scanner-untouched (guard, PASS pre+post): $KEEPS_DECLARATION still carries its AC10b classifier assertion literal" \
  "gq -F 'AC10b' '$PROJECT_ROOT/$KEEPS_DECLARATION'"

# =============================================================================
echo ""
echo "=== L2 declaration-reason-token — the real coverage resolver no longer excludes a converted suite from inheritance ==="
# `--ledger` and `--cycle` are MANDATORY arguments, not omissions: suite-coverage.sh
# rejects a missing or empty value with exit 2 BEFORE any per-suite record is
# emitted, under which this leg's predicate would pass vacuously over the empty
# set. The empty-register state is a path to an existing empty file — the shape
# the resolver's own self-test drives. The assertion is nonetheless
# register-content-independent: the declared-reader rule is Step 2 of the fold,
# decided from the header before any register entry is consulted, and both
# remaining causes a converted suite can draw under `--candidates all`
# (`no-entry`, `dirty-worktree`) are non-`out-of-tree-inputs`.

COV_LEDGER="$(mktemp)"
: > "$COV_LEDGER"
COV_REC="$(bash "$PROJECT_ROOT/scripts/test/suite-coverage.sh" \
  --root "$PROJECT_ROOT" --ledger "$COV_LEDGER" --cycle 121 --candidates all 2>&1 >/dev/null)"
rm -f "$COV_LEDGER"

assert_true "L2 non-vacuity pre-condition: the resolver emitted per-suite RUN:/INHERIT: records (a dropped --ledger/--cycle exits 2 and emits none, under which every predicate below passes over the empty set)" \
  "[ \"\$(printf '%s\n' \"\$COV_REC\" | grep -cE '^(RUN|INHERIT): ')\" -gt 0 ]"

for s in "${CONVERTED[@]}"; do
  assert_true "L2 declaration-reason-token: the resolver's record for $s carries no 'out-of-tree-inputs' reason token" \
    "! printf '%s\n' \"\$COV_REC\" | grep -E \"^(RUN|INHERIT): \$(printf '%s' '$s' | sed 's/[.]/[.]/g') \" | gq -F 'out-of-tree-inputs'"
done

assert_true "L2 declaration-reason-token (non-vacuity control, PASS pre+post): the resolver's record for $KEEPS_DECLARATION STILL carries the 'out-of-tree-inputs' reason token — without this half, a resolver that stopped emitting reason tokens at all would satisfy every clause above" \
  "printf '%s\n' \"\$COV_REC\" | grep -E \"^(RUN|INHERIT): \$(printf '%s' '$KEEPS_DECLARATION' | sed 's/[.]/[.]/g') \" | gq -F 'out-of-tree-inputs'"

# =============================================================================
echo ""
echo "=== L3 ci-subject-accuracy — no edited file's declared trigger surface has stopped describing what the file reads ==="
# Both halves are REGRESSION-SCOPED to what this cycle's deletions moved, and
# the reason is recorded rather than discovered here: the absolute forms are
# false at HEAD for files inside the scope, for gaps this cycle neither creates
# nor repairs (suite 69's `ls docs/adr/00*-verification-depth*.md` glob with no
# token that resolves it; its zero-reader `scripts/test/check-suite-leaf.sh` and
# `tests/lib/harness-pins.sh` tokens; suite 62's comment-only
# `docs/doc-invariant-registry.md` token; and the header-line-only tokens of
# tests/test-issue-103-cycle-scope-repoint.sh and
# tests/test-push-context-base-ref.sh). Either absolute form would red on a tree
# in which every edit of this cycle is correct.

# Over-selection — the token whose LAST executable read leaves with the arms.
for s in tests/test-issue-67-deliberation-record.sh \
         tests/test-issue-69-verification-depth.sh \
         tests/test-issue-27-composition-oracle.sh; do
  assert_true "L3 over-selection: $s no longer declares the 'tests/lib/base-ref.sh' ci-subject token — its last executable read left with the deleted arms" \
    "! suite_header_field '$PROJECT_ROOT/$s' ci-subject | tr ' ' '\n' | gq -xF 'tests/lib/base-ref.sh'"
  assert_true "L3 over-selection (companion state): $s's executable body carries no occurrence of 'tests/lib/base-ref.sh' — the token and the read leave together" \
    "! exec_body '$PROJECT_ROOT/$s' | gq -F 'tests/lib/base-ref.sh'"
done

# Under-selection — a token a SURVIVING executable read still depends on is not
# removed with the arms. tests/test-workflow-trigger-conformance.sh's
# co-subsumption pair additionally requires each of suite 27's three tokens
# below to stay inside its set, so dropping one reds a file outside this
# cycle's change surface.
for tok in tests/lib/harness-pins.sh tests/run-doc-invariants.sh tests/fixtures/doc-invariants.json; do
  assert_true "L3 under-selection (guard, PASS pre+post): tests/test-issue-27-composition-oracle.sh still declares '$tok' — a surviving executable read depends on it, and the co-subsumption pair requires it" \
    "suite_header_field '$PROJECT_ROOT/tests/test-issue-27-composition-oracle.sh' ci-subject | tr ' ' '\n' | gq -xF '$tok'"
done

# Clear-instance record, asserted rather than left as prose: suite 62 is a
# consumer this cycle edits, and every one of its declared tokens that has an
# executable reader at all keeps one outside the deleted arms.
for tok in setup/manifest.json .claude/workflows/architect-deliberation.js .claude/workflows/verify-cause-branch.js; do
  assert_true "L3 under-selection (guard, PASS pre+post): tests/test-issue-62-sequential-rounds.sh still declares '$tok' and still reads it in its executable body outside the deleted AC-62-36 arms" \
    "suite_header_field '$PROJECT_ROOT/tests/test-issue-62-sequential-rounds.sh' ci-subject | tr ' ' '\n' | gq -xF '$tok' && exec_body '$PROJECT_ROOT/tests/test-issue-62-sequential-rounds.sh' | gq -F '$tok'"
done

# =============================================================================
echo ""
echo "=== L4 symbol-closure — no edited file keeps a definition or assignment whose only reader was a deleted arm, and none loses a symbol a surviving arm calls ==="
# Per SYMBOL, not per file, and over BOTH symbol kinds — this cycle's orphans
# include function definitions and shell variable assignments alike. An
# uncalled function is inert, so the whole-tree sweep stays green over every
# one of these; the header lints do not read suite bodies; and the out-of-tree
# predicate returns false on an orphan, because the orphan carries no base-ref
# call site of its own.

orphan_gone() {   # <file> <symbol>
  ! exec_body "$PROJECT_ROOT/$1" | gq -E "(^|[^A-Za-z0-9_])$2([^A-Za-z0-9_]|\$)"
}

# --- orphan direction (the arms take their last readers with them) ---
assert_true "L4 orphan: tests/test-issue-67-deliberation-record.sh no longer defines or calls note_deferred — its sole call site was the deleted block's off-branch arm" \
  "orphan_gone tests/test-issue-67-deliberation-record.sh note_deferred"
assert_true "L4 orphan: tests/test-issue-67-deliberation-record.sh no longer assigns or reads HEAD_BRANCH — its only reader was the deleted case" \
  "orphan_gone tests/test-issue-67-deliberation-record.sh HEAD_BRANCH"
assert_true "L4 orphan: tests/test-issue-69-verification-depth.sh no longer defines or calls on_issue_branch" \
  "orphan_gone tests/test-issue-69-verification-depth.sh on_issue_branch"
assert_true "L4 orphan: tests/test-issue-69-verification-depth.sh no longer assigns or reads HEAD_BRANCH" \
  "orphan_gone tests/test-issue-69-verification-depth.sh HEAD_BRANCH"
assert_true "L4 orphan: tests/test-issue-27-composition-oracle.sh no longer defines or calls extract_step4_block — its sole call site sat inside the deleted AC-27-9-diff region" \
  "orphan_gone tests/test-issue-27-composition-oracle.sh extract_step4_block"
assert_true "L4 orphan: tests/test-issue-27-composition-oracle.sh no longer assigns or reads BASEREF_LIB — all its readers sat inside the deleted region" \
  "orphan_gone tests/test-issue-27-composition-oracle.sh BASEREF_LIB"
assert_true "L4 orphan: tests/test-issue-955-subagent-background-ban.sh no longer defines or calls skip_no_base — both call sites were in the deleted AC4-DOGFOOD / AC-PRESERVE-deletion-audit arms" \
  "orphan_gone tests/test-issue-955-subagent-background-ban.sh skip_no_base"
assert_true "L4 orphan: tests/test-issue-955-subagent-background-ban.sh no longer assigns or reads CYCLE_DIFF_FILES" \
  "orphan_gone tests/test-issue-955-subagent-background-ban.sh CYCLE_DIFF_FILES"
assert_true "L4 orphan: tests/test-issue-62-sequential-rounds.sh no longer defines or calls extract_arm_window — its sole reader was check_arm_structural, itself read only by the deleted AC-62-36(i) assignments" \
  "orphan_gone tests/test-issue-62-sequential-rounds.sh extract_arm_window"
assert_true "L4 orphan: tests/test-issue-62-sequential-rounds.sh no longer defines or calls check_arm_structural" \
  "orphan_gone tests/test-issue-62-sequential-rounds.sh check_arm_structural"
assert_true "L4 orphan: tests/test-issue-62-sequential-rounds.sh no longer defines or calls the mutator stale_workflow_manifest_row — its only readers were the deleted (iii) assignments" \
  "orphan_gone tests/test-issue-62-sequential-rounds.sh stale_workflow_manifest_row"
assert_true "L4 orphan: tests/test-issue-62-sequential-rounds.sh no longer defines or calls the mutator delete_workflow_and_manifest_row — its only readers were the deleted (iv) assignments" \
  "orphan_gone tests/test-issue-62-sequential-rounds.sh delete_workflow_and_manifest_row"

# --- retention direction, and the one externally-pinned exception ---
assert_true "L4 retention (guard, PASS pre+post): tests/test-issue-27-composition-oracle.sh still defines count_heading — a surviving arm calls it, which is the asymmetry that makes this per-symbol" \
  "gq -E '^count_heading\(\)' '$PROJECT_ROOT/tests/test-issue-27-composition-oracle.sh'"
assert_true "L4 retention (guard, PASS pre+post): tests/test-issue-955-subagent-background-ban.sh still defines extract_section" \
  "gq -E '^extract_section\(\)' '$PROJECT_ROOT/tests/test-issue-955-subagent-background-ban.sh'"
assert_true "L4 retention (guard, PASS pre+post): tests/test-issue-69-verification-depth.sh still defines note_deferred — the AC:manifest-fresh deferral arm still calls it, unlike suite 67's" \
  "gq -E '^note_deferred\(\)' '$PROJECT_ROOT/tests/test-issue-69-verification-depth.sh'"
assert_true "L4 retention (recorded exception, PASS pre+post): tests/test-issue-62-sequential-rounds.sh still defines guard_result_at_ref_mutated despite losing all four call sites — tests/test-cycle-arm-residue.sh asserts its retention by name, so it is a symbol another file requires rather than an orphan" \
  "gq -E '^guard_result_at_ref_mutated\(\)' '$PROJECT_ROOT/tests/test-issue-62-sequential-rounds.sh'"

# =============================================================================
echo ""
echo "=== L5 id-inventory-closure — no arm id this cycle retires survives as a name the tree still advertises ==="
# Three directions on TWO id axes. (a) is keyed on the BANNER's id, (b) and (c)
# on the ARM's id, and the two coincide in four of this cycle's five files but
# NOT in tests/test-issue-799-inert-cleanup.sh, where the emptied arms
# AC3-guard / AC3-nores / AC6-scope sit under banners named AC8 and AC10.

# --- (a) banner axis: no section banner survives with no assertion under it ---
for pair in \
  "tests/test-issue-798-topology-flip.sh:AC6" \
  "tests/test-issue-798-topology-flip.sh:AC7" \
  "tests/test-issue-798-topology-flip.sh:AC9" \
  "tests/test-issue-799-inert-cleanup.sh:AC8" \
  "tests/test-issue-799-inert-cleanup.sh:AC10" \
  "tests/test-issue-952-wizard-removal.sh:AC5" \
  "tests/test-issue-955-subagent-background-ban.sh:AC4" \
  "tests/test-issue-62-sequential-rounds.sh:AC-62-36"; do
  f="${pair%%:*}"; id="${pair##*:}"
  assert_true "L5 banner axis: $f echoes no '=== $id ' section banner — the banner's arms all left, so the header announces an empty region" \
    "! gq -F -- 'echo \"=== $id ' '$PROJECT_ROOT/$f'"
done

assert_true "L5 banner axis (total form): no banner in any edited suite retains zero assertions between it and the next banner" \
  "[ -z \"\$(for f in ${CONVERTED[*]} tests/test-issue-62-sequential-rounds.sh; do assertless_banners \"$PROJECT_ROOT/\$f\"; done)\" ]"

assert_true "L5 banner axis (guard, PASS pre+post): tests/test-issue-27-composition-oracle.sh KEEPS its '=== AC-27-9 ' banner — its sibling AC-27-9-literal survives, which is the recorded non-instance" \
  "gq -F -- 'echo \"=== AC-27-9 ' '$PROJECT_ROOT/tests/test-issue-27-composition-oracle.sh'"

# --- (b) header axis: no Scope / RED-expectation line names a retired id ---
for pair in \
  "tests/test-issue-798-topology-flip.sh:AC6" \
  "tests/test-issue-798-topology-flip.sh:AC7" \
  "tests/test-issue-798-topology-flip.sh:AC9" \
  "tests/test-issue-799-inert-cleanup.sh:AC3-guard" \
  "tests/test-issue-799-inert-cleanup.sh:AC3-nores" \
  "tests/test-issue-799-inert-cleanup.sh:AC6-scope" \
  "tests/test-issue-799-inert-cleanup.sh:AC8" \
  "tests/test-issue-799-inert-cleanup.sh:AC10"; do
  f="${pair%%:*}"; id="${pair##*:}"
  assert_true "L5 header axis: $f's leading comment block carries no bounded occurrence of the retired id '$id'" \
    "[ \"\$(bounded_count '$id' \"\$(hdr_block '$PROJECT_ROOT/$f')\")\" -eq 0 ]"
done

assert_true "L5 header axis: tests/test-issue-62-sequential-rounds.sh's *Retired (#107)* header note no longer records AC-62-36(iii)/(iv) as ungated and live, and no longer names stale_workflow_manifest_row as an extant mutator" \
  "! hdr_block '$PROJECT_ROOT/tests/test-issue-62-sequential-rounds.sh' | gq -F 'stale_workflow_manifest_row below'"
assert_true "L5 header axis: tests/test-issue-62-sequential-rounds.sh's header records the AC-62-36 retirement rather than advertising a live arm nothing executes" \
  "hdr_block '$PROJECT_ROOT/tests/test-issue-62-sequential-rounds.sh' | gq -E 'AC-62-36.*(retired|#121)'"

assert_true "L5 header axis (guard, PASS pre+post): tests/test-issue-799-inert-cleanup.sh's header STILL names the surviving id 'AC6-ci' — this is per-id, not per-prefix" \
  "[ \"\$(bounded_count 'AC6-ci' \"\$(hdr_block '$PROJECT_ROOT/tests/test-issue-799-inert-cleanup.sh')\")\" -ge 1 ]"

# --- (c) cross-file axis, with the destination constraint ---
for id in AC3-guard AC3-nores AC6-scope; do
  assert_true "L5 cross-file axis: tests/test-issue-109-doc-assertions.sh's LIVE_799_BARE_IDS no longer pins '$id' as an id the 799 body executes" \
    "! array_has '$INV109' LIVE_799_BARE_IDS '$id'"
  assert_true "L5 cross-file axis: '$id' lands in a header-absence array OTHER than LIVE_799_BARE_IDS, so its absence from the 799 header is pinned by an executable rather than merely stripped" \
    "[ -n \"\$(arrays_holding '$INV109' '$id' | grep -vx LIVE_799_BARE_IDS)\" ]"
  assert_true "L5 destination constraint: every array in tests/test-issue-109-doc-assertions.sh that names '$id' has exactly ONE consumer — an array a second assertion re-uses as another cycle's registry-claim witness set (STALE_799_IDS, COMPOUND_799_SPELLINGS) is refused as a destination" \
    "[ -n \"\$(arrays_holding '$INV109' '$id' | grep -vx LIVE_799_BARE_IDS)\" ] && ! arrays_holding '$INV109' '$id' | grep -vx LIVE_799_BARE_IDS | while read -r a; do [ \"\$(array_derefs '$INV109' \"\$a\")\" -eq 1 ] || echo bad; done | gq bad"
done

for id in AC6 AC7 AC9; do
  assert_true "L5 cross-file axis: tests/test-issue-109-doc-assertions.sh's GROUP_D_798 names the emptied banner id '$id'" \
    "array_has '$INV109' GROUP_D_798 '$id'"
done
for id in AC8 AC10; do
  assert_true "L5 cross-file axis: tests/test-issue-109-doc-assertions.sh's GROUP_D_799 names the emptied banner id '$id' — an id no deleted arm carries, which is why the banner axis is stated separately" \
    "array_has '$INV109' GROUP_D_799 '$id'"
done

assert_true "L5 destination constraint (control, PASS pre+post): STALE_799_IDS has more than one consumer at HEAD — its own header-absence loop and the §13.2 issue-#116 registry-claim composite — which is the fact that refuses it as a destination" \
  "[ \"\$(array_derefs '$INV109' STALE_799_IDS)\" -gt 1 ]"

# =============================================================================
echo ""
echo "=== L6 converted-arm-consumer-closure — the derived base-ref subject set keeps a live pinned member, chosen by rule ==="
# The real runs of the coupled consumers are the whole-tree sweep's (leaf
# rule); what no run reads, and what this leg carries, is (a) whether the
# repointed literal is a MEMBER of the set the consuming file's own derivation
# produces — a green run also admits a pin deleted outright — and (b) the
# recorded ALTERNATE, which lives in a comment that no assertion in any file
# executes over.

DERIVED="$(derive_pushctx_subjects)"
assert_true "L6 non-vacuity pre-condition: the re-derived base-ref subject set is non-empty" \
  "[ -n \"\$DERIVED\" ]"

PIN_UNDER="$(grep -F 'regression guard against silent under-derivation' -A 2 "$PUSHCTX" | grep -oE "tests/[A-Za-z0-9/_.-]+\.sh" | head -1)"
PIN_NATIVE="$(grep -F 'AC-native-coverage-premise-{depth,reach} (real tree)' -A 2 "$PUSHCTX" \
  | tr -d '\\' | grep -oE 'tests/[A-Za-z0-9/_.-]+\.sh' | head -1)"

assert_true "L6 pin (a) (guard, PASS pre+post — suite 27 is in the derived set at HEAD; its discriminator is the converted-set arm below): the under-derivation regression guard's pinned literal ('${PIN_UNDER:-<none>}') is a member of the set tests/test-push-context-base-ref.sh's own derive_subjects produces — derived from the tree, never from a list written into this suite" \
  "[ -n '$PIN_UNDER' ] && printf '%s\n' \"\$DERIVED\" | gq -xF '$PIN_UNDER'"
assert_true "L6 pin (a) (guard, PASS pre+post — same reason): the AC-native-coverage-premise arm's pinned literal ('${PIN_NATIVE:-<none>}') is a member of that same derived set — the two pins are one decision and move together" \
  "[ -n '$PIN_NATIVE' ] && printf '%s\n' \"\$DERIVED\" | gq -xF '$PIN_NATIVE'"
assert_true "L6 pin (a): neither pinned literal is one of the seven suites this cycle converts — a pin inside the converted set leaves the derived set the moment its resolver call goes" \
  "! printf '%s\n' '${CONVERTED[*]}' | tr ' ' '\n' | gq -xF '${PIN_UNDER:-<none>}' && ! printf '%s\n' '${CONVERTED[*]}' | tr ' ' '\n' | gq -xF '${PIN_NATIVE:-<none>}'"

ALTERNATE="$(grep -iE 'is the alternate|alternate is' "$PUSHCTX" | grep -oE 'tests/[A-Za-z0-9/_.-]+\.sh' | head -1)"
assert_true "L6 alternate (b): the repoint's comment block names an alternate BY PATH ('${ALTERNATE:-<none>}') — the block carries one at HEAD which this cycle refutes, so a rewrite that silently drops it, or invents one at GREEN, passes every run in this layer and still fails A17" \
  "[ -n '$ALTERNATE' ] && [ -f '$PROJECT_ROOT/$ALTERNATE' ]"
assert_true "L6 alternate (b): the file the comment names declares '# lane: standing' — check 1 of the selection rule (pin a subject whose base-ref call cannot leave with a cycle), resolved against that file itself rather than against a name written here" \
  "[ -n '$ALTERNATE' ] && gq -E '^# lane: standing\$' '$PROJECT_ROOT/$ALTERNATE'"
assert_true "L6 alternate (b): the file the comment names declares no 'cycle-arm' field anywhere — check 2 of the selection rule" \
  "[ -n '$ALTERNATE' ] && ! gq -E '^# cycle-arm:' '$PROJECT_ROOT/$ALTERNATE'"
assert_true "L6 alternate (b): the file the comment names carries a merge-base call dominated by no branch gate — check 3 of the selection rule; the digest suite fails exactly here, both its resolver calls sitting inside dev/*-issue-71 gates" \
  "[ -n '$ALTERNATE' ] && gq 'merge-base' '$PROJECT_ROOT/$ALTERNATE' && ! gq -E 'dev/\*-issue-' '$PROJECT_ROOT/$ALTERNATE'"
assert_true "L6 alternate (b): the file the comment names is a member of the derived subject set at HEAD, so a future repoint has a candidate already checked" \
  "[ -n '$ALTERNATE' ] && printf '%s\n' \"\$DERIVED\" | gq -xF '$ALTERNATE'"

# =============================================================================
echo ""
echo "=== L7 provenance-state — every deletion has a registry row, and no surviving row states a disposition over an executable this cycle retires ==="
# Two directions over the same prose subject. Nothing RUNS against a
# disposition cell, so no run — including the consumer layer's — reads the
# second, and a tree satisfying the first alone still ships a registry that
# asserts a permanence over an executable that no longer exists.

SEC16="$(awk '/^## 16\./{f=1} f{print} f&&/^## 17\./{exit}' "$REGISTRY_MD")"
assert_true "L7 §16 exists: docs/doc-invariant-registry.md carries a new '## 16. Migration provenance — retired-guard dispositions (issue #121)' section (§13=#109, §14=#119, §15=#123; the convention is one numbered section per issue)" \
  "printf '%s\n' \"\$SEC16\" | gq -E '^## 16\..*issue #121'"

# The disposition vocabulary is DERIVED from §5's own column, so a label coined
# by GREEN is refused rather than silently admitted.
VOCAB="$(awk '/^## 5\./{f=1} f{print} f&&/^## 6\./{exit}' "$REGISTRY_MD" \
  | grep -oE '\*\*(dropped — [a-z-]+(, with recorded coverage loss)?|promoted → [^*|]+)\*\*' | sed 's/\*\*//g' | sort -u)"
assert_true "L7 vocabulary non-vacuity: §5's disposition column yields a non-empty label set to check §16's rows against" \
  "[ -n \"\$VOCAB\" ]"

for arm in "AC6b" "AC7b" "AC9" "AC3-guard" "AC3-nores" "AC6-scope" "AC5" "AC4-DOGFOOD" "AC-PRESERVE-deletion-audit" "AC-27-9-diff" "AC-62-36"; do
  assert_true "L7 provenance row: §16 carries a row naming the deleted arm '$arm'" \
    "printf '%s\n' \"\$SEC16\" | gq -F -- '$arm'"
done

assert_true "L7 disposition vocabulary: every disposition §16 states is drawn verbatim from §5's existing set — this cycle coins no new label" \
  "[ -n \"\$SEC16\" ] && [ -z \"\$(printf '%s\n' \"\$SEC16\" | grep -oE '\*\*(dropped — [a-zé -]+(, with recorded coverage loss)?|promoted → [^*|]+)\*\*' | sed 's/\*\*//g' | sort -u | grep -vxF \"\$VOCAB\")\" ]"

assert_true "L7 residue in words: §16 states the recorded residue for the '.claude/hooks/**' row (a cycle adding a THIRD file under .claude/hooks/ fails the deleted arms and is outside the carrier's fixed pair)" \
  "printf '%s\n' \"\$SEC16\" | gq -iE 'residue' && printf '%s\n' \"\$SEC16\" | gq -F '.claude/hooks/'"
assert_true "L7 residue in words: §16 states the recorded residue for the '.claude/workflows/**' row, INCLUDING the shape-guard half this round adds — the arm's own differential controls (AC-62-36(iii)/(iv)) retire with it, so the post-retirement state is FIXED POINT's content predicate alone" \
  "printf '%s\n' \"\$SEC16\" | gq -F '.claude/workflows/' && printf '%s\n' \"\$SEC16\" | gq -F 'FIXED POINT'"
assert_true "L7 residue in words: §16's marker-promotion row states its narrowing — a marker line added AFTER the promotion is ungoverned, and an edit confined to a governed line's unpinned remainder is admitted where the DELTA caught it" \
  "printf '%s\n' \"\$SEC16\" | gq -F 'Secondary (multi-repo)' && printf '%s\n' \"\$SEC16\" | gq -iE 'narrow'"

assert_true "L7 supersession (second direction): §16 supersedes §12.1's AC-62-36(iii) and AC-62-36(iv) disposition rows BY NAME — rows that merely sit beside them leave the registry asserting a permanent property over an executable that no longer exists" \
  "printf '%s\n' \"\$SEC16\" | gq -F 'AC-62-36(iii)' && printf '%s\n' \"\$SEC16\" | gq -F 'AC-62-36(iv)' && printf '%s\n' \"\$SEC16\" | gq -iE 'supersede'"

assert_true "L7 kept-row re-anchor (guard, PASS pre+post — the anchor resolves at HEAD and reds mid-GREEN when the deletions above the range land): §12.1's kept row for guard_result_at_ref_mutated cites a tests/test-issue-62-sequential-rounds.sh line range that CONTAINS the definition line on the post-change file — the range is derived from the produced tree, never written at design time" \
  "R=\"\$(grep -oE 'tests/test-issue-62-sequential-rounds\.sh:[0-9]+-[0-9]+' '$REGISTRY_MD' | head -1)\"; [ -n \"\$R\" ] && S=\"\${R##*:}\"; A=\"\${S%%-*}\"; B=\"\${S##*-}\"; D=\"\$(grep -n '^guard_result_at_ref_mutated()' '$PROJECT_ROOT/tests/test-issue-62-sequential-rounds.sh' | head -1 | cut -d: -f1)\"; [ -n \"\$D\" ] && [ \"\$D\" -ge \"\$A\" ] && [ \"\$D\" -le \"\$B\" ]"

# --- promoted entries: shape fixed at design time, and per-LINE granularity ---
NEW_ENTRIES="$(jq -r '[.invariants[] | select(.origin_issue == 121)]' "$INVARIANTS_JSON")"
assert_true "L7 promotion: tests/fixtures/doc-invariants.json carries entries with origin_issue 121" \
  "[ \"\$(printf '%s' \"\$NEW_ENTRIES\" | jq 'length')\" -gt 0 ]"
assert_true "L7 promotion shape: every origin_issue-121 entry is predicate 'present', match 'fixed', file-scoped with no section, scope 'permanent' — the shape that routes the runner's witness to mutate_remove_lines and so is credited teeth rather than NO-TEETH" \
  "N=\"\$(printf '%s' \"\$NEW_ENTRIES\" | jq 'length')\"; [ \"\$N\" -gt 0 ] && [ \"\$(printf '%s' \"\$NEW_ENTRIES\" | jq '[.[] | select(.predicate==\"present\" and .match==\"fixed\" and .section==null and .scope==\"permanent\")] | length')\" = \"\$N\" ]"
assert_true "L7 promotion shape: no origin_issue-121 literal contains an embedded newline — the runner's schema check refuses one with a registry-wide BLOCK, not a per-entry red, which is why each literal is a single source line or a clause of one" \
  "[ \"\$(printf '%s' \"\$NEW_ENTRIES\" | jq 'length')\" -gt 0 ] && [ \"\$(printf '%s' \"\$NEW_ENTRIES\" | jq '[.[] | select(.literal | test(\"\n\"))] | length')\" -eq 0 ]"
assert_true "L7 promotion drop: NO origin_issue-121 entry carries a 'services/librechat' literal — that arm is dropped, not promoted, and owes a *dropped — cycle-local* §16 row and no registry entry" \
  "[ \"\$(printf '%s' \"\$NEW_ENTRIES\" | jq 'length')\" -gt 0 ] && [ \"\$(printf '%s' \"\$NEW_ENTRIES\" | jq '[.[] | select(.literal | test(\"services/librechat\"))] | length')\" -eq 0 ]"

# Marker promotion: one entry per marker LINE, derived from the tree. A
# file-scoped `present` entry still passes after one of several markers in the
# same file is deleted — exactly the loss the DELTA caught — so the count is
# the property, not the presence.
while IFS= read -r mf; do
  [ -n "$mf" ] || continue
  n="$(grep -c 'Secondary (multi-repo):' "$PROJECT_ROOT/$mf")"
  assert_true "L7 marker promotion granularity: '$mf' carries $n '*Secondary (multi-repo):*' marker line(s) in the deleted arms' scope, and at least that many origin_issue-121 entries name it — one entry per LINE, since a file-scoped presence entry survives the deletion of one of several markers" \
    "[ \"\$(printf '%s' \"\$NEW_ENTRIES\" | jq --arg f '$mf' '[.[] | select(.file==\$f)] | length')\" -ge $n ]"
done < <(cd "$PROJECT_ROOT" && grep -rl 'Secondary (multi-repo):' docs/ CLAUDE.md README.md 2>/dev/null | sort -u)

STEP4_LINES="$(awk '/^4\. Mock-boundary fidelity check \(Test AI\):/{f=1} f{ if ($0 ~ /^```/) exit; print }' "$GUIDE" | grep -c .)"
assert_true "L7 step-4 promotion granularity: at least $STEP4_LINES origin_issue-121 entries name docs/autoflow-guide.md — one per LINE of the VERIFY step-4 block, since the block's one prose sentence wraps across consecutive source lines and a sentence-shaped literal would carry an embedded newline" \
  "[ \"\$(printf '%s' \"\$NEW_ENTRIES\" | jq '[.[] | select(.file==\"docs/autoflow-guide.md\")] | length')\" -ge $STEP4_LINES ]"

# =============================================================================
echo ""
echo "=== L8 subsumption-differential — every arm disposed *dropped — redundant* really is subsumed ==="
# Every other layer verifies the tree is GREEN after deletion, which a genuine
# coverage loss also satisfies. This layer's red state is a carrier that stays
# green: the row is mis-disposed, and the resolution is a design decision, NOT
# a re-label applied here.

assert_true "L8 subsumption non-vacuity (control): the FIXED POINT carrier is GREEN over an unperturbed scratch copy of the real tree — without this, a carrier that reds on everything would satisfy every clause below" \
  "[ \"\$(fixed_point_after perturb_none)\" = green ]"

assert_true "L8 subsumption (differential — the CARRIER's behaviour, which this cycle does not change: PASS pre+post; its RED state is a mis-disposed row, not a missing edit) (798 AC7b, *dropped — redundant*): reintroducing the fault that arm caught — a diff hunk against the registered source docs/adr/0015-*.md with no regeneration — makes the named carrier (manifest FIXED POINT) RED" \
  "[ \"\$(fixed_point_after perturb_adr0015)\" = red ]"

assert_true "L8 subsumption (differential, PASS pre+post — as above) (952 AC5, *dropped — redundant*): reintroducing the fault that arm caught — a registered source edited without setup/manifest.json in the same diff — makes the named carrier (manifest FIXED POINT) RED; FIXED POINT is the same-commit-regen obligation in whole-tree state form and needs no diff" \
  "[ \"\$(fixed_point_after perturb_claude_md)\" = red ]"

assert_true "L8 subsumption (differential, PASS pre+post — as above) (955 AC4-DOGFOOD, *dropped — redundant*): the diff-∩-sources fault likewise makes FIXED POINT RED — both arms are registered-source-only by construction, so FIXED POINT's coverage is a superset" \
  "[ \"\$(fixed_point_after perturb_guide)\" = red ]"

# =============================================================================
echo ""
echo "=== L9 residue-differential — every *with recorded coverage loss* row's residue is reproduced, not assumed ==="
# The opposite red state to L8's, which is why the two are separate layers: a
# carrier that UNEXPECTEDLY reds on the residue case falsifies the row's stated
# loss, and the row is mis-disposed.

assert_true "L9 residue non-vacuity (control): the AC5-parity carrier is GREEN over an unperturbed scratch copy of the real tree" \
  "[ \"\$(ac5_parity_after perturb_none)\" = green ]"

assert_true "L9 hooks CARRIED half (differential, PASS pre+post — the carrier's behaviour, not this cycle's edit): an edit to .claude/hooks/check-autoflow-gate.sh without its plugin mirror makes the named carrier (tests/plugin/verify-package.sh AC5 byte parity) RED — byte equality, stricter than the deleted arms' admission test" \
  "[ \"\$(ac5_parity_after perturb_gate_hook_only)\" = red ]"

assert_true "L9 hooks RESIDUE half (differential, PASS pre+post — as above): adding a THIRD file under .claude/hooks/ leaves the carrier GREEN — the deleted arms failed that cycle, AC5 compares a fixed pair of basenames plus the agents directory, and this is the loss §16 must state in words" \
  "[ \"\$(ac5_parity_after perturb_third_hook)\" = green ]"

assert_true "L9 hooks RESIDUE half (differential, PASS pre+post; N4 extension): an edit to a .claude/hooks/** file OTHER than check-autoflow-gate.sh whose plugin mirror is updated in the SAME diff leaves the carrier GREEN — the case the deleted arms rejected and the carrier admits" \
  "[ \"\$(ac5_parity_after perturb_dedup_mirrored)\" = green ]"

assert_true "L9 workflows CARRIED half (differential, PASS pre+post — as above): a REGISTERED .claude/workflows script's content edited without regeneration makes the named carrier (FIXED POINT) RED. This arm re-creates, for this cycle's duration, the differential AC-62-36(iii)/(iv) carried and this cycle retires with its subject" \
  "[ \"\$(fixed_point_after perturb_registered_wf)\" = red ]"

assert_true "L9 workflows RESIDUE half (differential, PASS pre+post — as above): an UNREGISTERED .claude/workflows/*.js leaves FIXED POINT GREEN — gen-manifest-hashes.sh emits workflow rows from a fixed pair of emit_row calls, so a newly added script is in neither the committed nor the regenerated manifest and the fixed point holds. This is the missing-row loss §16 must state" \
  "[ \"\$(fixed_point_after perturb_unregistered_wf)\" = green ]"

# =============================================================================
echo ""
echo "=== L10 array-subject-enumeration — §12's coupling passage names exactly the standing suites that declare an allow-list array ==="
# The two test-issue-103 loops are the executable half and belong to the sweep.
# The registry's PROSE is not code, so no run witnesses it — and it becomes
# false the moment two of the three named suites lose their arrays. Scoped to
# STANDING suites (this suite is cycle-scoped, so its own array is the
# coupling's forward direction, not the converse §12 leaves unasserted).

STANDING_ARRAY_BEARING="$(while IFS= read -r rel; do
  [ -n "$rel" ] || continue
  [ "$(suite_header_field "$PROJECT_ROOT/$rel" lane 2>/dev/null)" = standing ] || continue
  suite_declares_allow_list "$PROJECT_ROOT/$rel" && printf '%s\n' "$rel"
done < <(suite_enumerate "$PROJECT_ROOT") | sort)"

SEC12_PARA="$(awk '/^\*\*Why the coupling is one-directional\.\*\*/{f=1} f{print} f&&/^$/{if(n++)exit}' "$REGISTRY_MD")"
SEC12_NAMED="$(printf '%s\n' "$SEC12_PARA" | grep -oE 'tests/[A-Za-z0-9/_.-]+\.sh' | sort -u)"

assert_true "L10 non-vacuity: §12's one-directional-coupling passage names at least one suite by path, and the tree yields at least one standing array-bearing suite" \
  "[ -n \"\$SEC12_NAMED\" ] && [ -n \"\$STANDING_ARRAY_BEARING\" ]"
assert_true "L10 array-subject-enumeration (guard, PASS pre+post — §12 names exactly {67,69,71} at HEAD and goes false the moment two of the three lose their arrays): the set §12's coupling passage names in prose is EXACTLY the set of STANDING suites declaring a path allow-list array at HEAD, derived from the tree rather than from a literal list written into this suite" \
  "[ \"\$SEC12_NAMED\" = \"\$STANDING_ARRAY_BEARING\" ]"
assert_true "L10 (N1) (guard, PASS pre+post — a property of this suite's own header): this suite is lane cycle-scoped, so its own allow-list array is outside §12's subject set and cannot falsify the predicate above" \
  "[ \"\$(suite_header_field '$PROJECT_ROOT/tests/test-issue-121-declaration-release.sh' lane)\" = 'cycle-scoped' ] && suite_declares_allow_list '$PROJECT_ROOT/tests/test-issue-121-declaration-release.sh'"

# =============================================================================
echo ""
echo "=== cycle-scope-respected — this cycle's own branch diff stays within its declared allow_list ==="
# Reported by THIS arm and by nothing else: check-cycle-scope-guard.sh is
# membership-blind (its subject filter admits a file merely for DECLARING such
# an array, and every `comm -23` in that script sits inside its self-test's
# fixture heredocs, never in its own decision path). So a missing member is
# reported only by the whole-tree sweep taken on this cycle's own dev branch.

HEAD_BRANCH="${GITHUB_HEAD_REF:-$(git -C "$PROJECT_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null)}"
on_issue_branch() {
  case "$HEAD_BRANCH" in
    dev/*-issue-121|dev/*-issue-121-*) return 0 ;;
    *) return 1 ;;
  esac
}

allow_list=(
  # Converted suites (Lane A + Lane B)
  "tests/test-issue-67-deliberation-record.sh"
  "tests/test-issue-69-verification-depth.sh"
  "tests/test-issue-798-topology-flip.sh"
  "tests/test-issue-799-inert-cleanup.sh"
  "tests/test-issue-952-wizard-removal.sh"
  "tests/test-issue-955-subagent-background-ban.sh"
  "tests/test-issue-27-composition-oracle.sh"
  # Consumers taking a mandatory edit in the same commit as the deletion
  "tests/test-issue-103-cycle-scope-repoint.sh"
  "tests/test-issue-103-suite-manifest.sh"
  "tests/test-issue-62-sequential-rounds.sh"
  "tests/test-push-context-base-ref.sh"
  "tests/test-issue-109-doc-assertions.sh"
  "tests/fixtures/issue-109-assertion-baseline-798.txt"
  "tests/fixtures/issue-109-assertion-baseline-799.txt"
  # Registry + the two members a hand-written list drops, neither being an
  # edited suite: the regenerated manifest, and the invariants fixture, which
  # is not a manifest artifact source so nothing else pulls it in.
  "docs/doc-invariant-registry.md"
  "setup/manifest.json"
  "tests/fixtures/doc-invariants.json"
  # New RED artifacts and their registration
  "tests/test-issue-121-declaration-release.sh"
  "tests/manual/issue-121-manual-scenarios.md"
  ".github/workflows/contract-suites.yml"
)

if on_issue_branch; then
  BASE_REF_SCOPE="$(resolve_base_ref)" || true
  if [ -n "${BASE_REF_SCOPE:-}" ]; then
    DIFF_FILES="$(cd "$PROJECT_ROOT" && git diff --name-only "$BASE_REF_SCOPE"...HEAD)"
    UNCOVERED="$(comm -23 <(printf '%s\n' "$DIFF_FILES" | sort -u) <(printf '%s\n' "${allow_list[@]}" | sort -u))"
    assert_true "AC-121-SCOPE: cycle diff set-differenced against the declared allow_list is empty (uncovered: $(printf '%s' "$UNCOVERED" | paste -sd, -))" \
      '[ -z "$UNCOVERED" ]'
  else
    echo "  BLOCK: no comparison base resolvable — AC-121-SCOPE counted FAIL, never skipped"
    TESTS=$((TESTS + 1)); FAIL=$((FAIL + 1))
  fi
else
  note_deferred "AC-121-SCOPE: change-surface guard inert off the issue-121 dev branch (head: ${HEAD_BRANCH:-unknown}) — this cycle's own PR contract, not every branch's."
fi

# =============================================================================
echo ""
echo "Results: $PASS/$TESTS passed, $FAIL failed"
[[ $FAIL -gt 0 ]] && exit 1
exit 0
