#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# Test: V4 oracle hardening + trap-based temp cleanup — Issue #7 (cycle-scoped)
# =============================================================================
# Cycle-scoped RED suite per the verification design
# (.autoflow/issue-7-verification-design.md §1.0 canonical AC set, §5 Red
# plan) and its companion feature design (.autoflow/issue-7-feature-design.md
# §5). This suite is the guard for `tests/test-issue-1-guard-contract.sh`'s
# two hardening gaps: R1 (the seeding helper `emit_own_record` discards the
# real emitter's exit status/output, so an emitter regression is invisible to
# the meta-suite) and R2 (every temp copy is deleted by a paired inline
# `rm -rf`, with no `trap ... EXIT` safety net for an aborted run).
#
# F1 (tests/test-issue-1-guard-contract.sh) and F9
# (.github/workflows/e2e-dummy-target.yml) are Developer-AI/GREEN scope and
# are READ-ONLY here. This suite only reads them and asserts on their
# behavior/content.
#
# AC -> section map (verification design §1.0):
#   AC-7-1/2/3/4  -> R1, O2 real-fault-injection legs (this file's O2 block)
#                    + O1 clean-run legs (AC-7-4 ordering, AC-7-6)
#   AC-7-5/AC-7-5n -> R2, structural fence (always live) + O3 interrupt legs
#                    (DEFERRED-OBSERVABLE at RED — see the O3 section below)
#   AC-7-6/6a/6b/6c -> Preservation fences (already green pre-GREEN; they do
#                    not depend on F1's hardening, only on F1's existing
#                    behavior + the guard's own non-interference)
#   AC-7-7/7a/7b/7c/7d -> Scope/CI registration. AC-7-7 (six-suite membership)
#                    is satisfied by this same RED commit's F2-F7 edits, so it
#                    is a fence, not a discriminator. AC-7-7a/7d are genuine
#                    RED discriminators (F9 is GREEN scope, unregistered at
#                    HEAD — B4/B11). AC-7-7b is a DELTA-lane fence, environment
#                    -dependent on a resolvable base ref. AC-7-7c is self-timed.
#
# Injection route (settled — verification §1 R1 D-1′, ledger E3): a call-site
# `sed` applied to a tar-copy's own two `emit_own_record "$TMP_V4*" ...` call
# sites, appending a literal `Bogus` third argument, guarded by an `-eq 2`
# applied-count check. At HEAD the hardened helper's third parameter does not
# exist yet, so this `sed` lands on call sites that ignore the extra argument
# and the O2 run is indistinguishable from a clean run — that IS the headline
# RED discriminator (ledger E4), not a coverage gap.
#
# RED-authoring note (deviation from a literal reading of the verification
# design, per the ledger E15 GATE:PLAN carry-forward findings, mirroring the
# convention `tests/test-issue-27-composition-oracle.sh` established):
#   1. AC-7-5(a)'s structural fence anchors on EXECUTABLE `mktemp -d` sites
#      only (comment-only mentions at tests/test-issue-1-guard-contract.sh:11
#      and :106 are excluded) — the design's literal count-based fence is not
#      implementable as written without this filter.
#   2. AC-7-5 / AC-7-5n have no observable seam until GREEN ships
#      `GUARD_CONTRACT_WORKROOT_PARENT` support in F1. This suite detects
#      that support at run time and, when absent, prints a DEFERRED-OBSERVABLE
#      note instead of a live assertion — it does NOT fake a Red signal for
#      this leg. Once GREEN ships the seam, the same run of this suite
#      activates the live O3 legs automatically (no suite edit needed).
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

GUARD_SUITE_REL="tests/test-issue-1-guard-contract.sh"
GUARD_SUITE="$PROJECT_ROOT/$GUARD_SUITE_REL"
WORKFLOW="$PROJECT_ROOT/.github/workflows/e2e-dummy-target.yml"
DIGEST="$PROJECT_ROOT/docs/cycle-digest.jsonl"
BASE_REF_LIB="$PROJECT_ROOT/tests/lib/base-ref.sh"

ALLOW_LIST_SUITES=(
  "tests/test-issue-798-topology-flip.sh"
  "tests/test-issue-799-inert-cleanup.sh"
  "tests/test-issue-848-doc-assertions.sh"
  "tests/test-issue-955-subagent-background-ban.sh"
  "tests/test-issue-846-doc-assertions.sh"
  "tests/test-issue-952-wizard-removal.sh"
)
CANONICAL_PATHS=(
  "tests/test-issue-1-guard-contract.sh"
  "tests/test-issue-7-oracle-hardening.sh"
  "tests/manual/issue-7-manual-scenarios.md"
)

PASS=0; FAIL=0; TESTS=0
SECONDS=0

# ---------------------------------------------------------------------------
# Helpers (assert_* pattern per tests/test-issue-1-guard-contract.sh)
# ---------------------------------------------------------------------------

assert_true() {
  local desc="$1" condition="$2"
  TESTS=$((TESTS + 1))
  if (cd "$PROJECT_ROOT" && eval "$condition"); then
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
  if (cd "$PROJECT_ROOT" && eval "$condition"); then
    echo "  FAIL: $desc (forbidden condition held)"
    FAIL=$((FAIL + 1))
  else
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  fi
}

note_deferred() {
  echo "  DEFERRED-OBSERVABLE: $1"
}

# Extracts a suite file's own allow_list=( ... ) array block (not a
# whole-file grep — a path mentioned only in a surrounding comment outside
# the block must not satisfy membership).
extract_allow_list_block() {
  awk '/allow_list=\(/{f=1; next} f && /^  \)/{f=0} f' "$1"
}

# Membership check against an already-extracted allow_list block (caller
# extracts once per suite file, not once per path, to avoid re-scanning the
# same file for every canonical path checked against it).
assert_allow_list_membership() {
  local desc="$1" block="$2" path="$3"
  TESTS=$((TESTS + 1))
  if printf '%s\n' "$block" | grep -qF "\"$path\""; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"
    FAIL=$((FAIL + 1))
  fi
}

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

make_temp_copy() {
  local tmp
  tmp="$(mktemp -d)"
  (cd "$PROJECT_ROOT" && tar --exclude='.git' -cf - .) | (cd "$tmp" && tar -xf -) 2>/dev/null
  mkdir -p "$tmp/.autoflow" "$tmp/docs"
  printf '%s' "$tmp"
}

RELEASE_DATE="$(grep -oE "RELEASE_DATE='[^']*'" "$GUARD_SUITE" | head -1 | sed -E "s/^RELEASE_DATE='([^']*)'$/\1/")"
[ -n "$RELEASE_DATE" ] || RELEASE_DATE="2026-07-11"

# =============================================================================
# O1 — clean live-tree run (AC-7-6, AC-7-6a, AC-7-6c, AC-7-4 ordering)
# =============================================================================
echo "=== O1 — clean live-tree run ==="

PRE_GIT_STATUS="$(git -C "$PROJECT_ROOT" status --porcelain)"
PRE_DIGEST_SHA="$(sha256_of "$DIGEST")"

LIVE_OUT="$(bash "$GUARD_SUITE" 2>&1)"
LIVE_RC=$?
export LIVE_OUT

POST_GIT_STATUS="$(git -C "$PROJECT_ROOT" status --porcelain)"
POST_DIGEST_SHA="$(sha256_of "$DIGEST")"

# AC-7-6b — cleanup never touches the live tree (non-optional; fences the
# highest-consequence concern in the design). Wrapped around this leg now;
# the O3 interrupt legs are wrapped the same way once GREEN ships the seam
# (see the O3 section below).
assert_true "AC-7-6b-git-clean: git status --porcelain unchanged around the live-tree O1 run" \
  "[ \"\$PRE_GIT_STATUS\" = \"\$POST_GIT_STATUS\" ]"
assert_true "AC-7-6b-digest-sha-unchanged: live docs/cycle-digest.jsonl SHA-256 unchanged around the live-tree O1 run" \
  "[ '$PRE_DIGEST_SHA' = '$POST_DIGEST_SHA' ]"

assert_true "AC-7-6-exit0: live-tree run exits 0" "[ '$LIVE_RC' -eq 0 ]"
assert_true "AC-7-6-0failed: live-tree Results line reports 0 failed" \
  "printf '%s' \"\$LIVE_OUT\" | grep -qE 'Results: [0-9]+/[0-9]+ passed, 0 failed'"
assert_true "AC-7-6-total-ge-32: live-tree total test count is >= 32" \
  "[ \"\$(printf '%s' \"\$LIVE_OUT\" | grep -oE 'Results: [0-9]+/[0-9]+' | grep -oE '/[0-9]+' | tr -d '/')\" -ge 32 ]"

for d in "V4-emit-rc-2026-07-15" "V4-emit-rc-$RELEASE_DATE" \
         "V4-emit-appended-one-2026-07-15" "V4-emit-appended-one-$RELEASE_DATE" \
         "V4-emit-date-2026-07-15" "V4-emit-date-$RELEASE_DATE"; do
  assert_true "AC-7-6-desc-present: live-tree run PASSes $d" \
    "printf '%s' \"\$LIVE_OUT\" | grep -qE '^  PASS: $d'"
done

assert_true "AC-7-6a-own-record-pass: V4-own-record-pass keeps its description and still PASSes" \
  "printf '%s' \"\$LIVE_OUT\" | grep -qE '^  PASS: V4-own-record-pass'"
assert_true "AC-7-6a-boundary-pass: V4-boundary-pass keeps its description and still PASSes" \
  "printf '%s' \"\$LIVE_OUT\" | grep -qE '^  PASS: V4-boundary-pass'"

assert_false "AC-7-6c-no-rm-stderr: a clean run emits no 'rm:' stderr" \
  "printf '%s' \"\$LIVE_OUT\" | grep -qF 'rm:'"
assert_false "AC-7-6c-no-enoent-stderr: a clean run emits no 'No such file or directory' stderr" \
  "printf '%s' \"\$LIVE_OUT\" | grep -qF 'No such file or directory'"

assert_true "AC-7-4-ordering: all three V4-emit-* lines (both legs) appear before the first V4-own-record-pass line" \
  "awk '/V4-emit-(rc|appended-one|date)-/{if (!e) e=NR} /V4-own-record-pass/{if (!o) o=NR} END{exit !(e && o && e<o)}' <<<\"\$LIVE_OUT\""

# =============================================================================
# O2 — fail-loud emit via real invalid input (D-1′ call-site sed injection)
# =============================================================================
echo ""
echo "=== O2 — fail-loud emit, driven by real invalid input (D-1′ injection) ==="

TMP_O2="$(make_temp_copy)"
sed -i.bak -E 's/^(emit_own_record "\$TMP_V4[AB]" .*)$/\1 Bogus/' "$TMP_O2/$GUARD_SUITE_REL"
APPLIED_COUNT="$(grep -cE '^emit_own_record .* Bogus$' "$TMP_O2/$GUARD_SUITE_REL")"
assert_true "R1-injection-applied: the D-1′ sed applies to exactly 2 call sites (not the emit_own_record() definition line)" \
  "[ '$APPLIED_COUNT' -eq 2 ]"

O2_OUT="$(cd "$TMP_O2" && bash "$GUARD_SUITE_REL" 2>&1)"
O2_RC=$?
export O2_OUT
rm -rf "$TMP_O2"

assert_true "AC-7-1-exit1: O2 injected run exits 1" "[ '$O2_RC' -eq 1 ]"
assert_true "AC-7-1-failed-ge-6: O2 injected run Results line reports a failed count >= 6 (per-leg triple failure, both legs — not 'exactly one failure')" \
  "[ \"\$(printf '%s' \"\$O2_OUT\" | grep -oE 'Results: [0-9]+/[0-9]+ passed, [0-9]+ failed' | grep -oE '[0-9]+ failed' | grep -oE '[0-9]+')\" -ge 6 ]"
assert_true "AC-7-1-diagnostic: O2 injected run output carries the emit-cycle-digest: diagnostic prefix" \
  "printf '%s' \"\$O2_OUT\" | grep -qF 'emit-cycle-digest:'"

for d in "V4-emit-rc-2026-07-15" "V4-emit-rc-$RELEASE_DATE"; do
  assert_true "AC-7-1-FAIL: O2 injected run reports FAIL: $d" \
    "printf '%s' \"\$O2_OUT\" | grep -qE '^  FAIL: $d'"
done
for d in "V4-emit-appended-one-2026-07-15" "V4-emit-appended-one-$RELEASE_DATE"; do
  assert_true "AC-7-2-FAIL: O2 injected run reports FAIL: $d (post-pre = 0, not 1 — the copy's digest stays at its inherited line count, never absent)" \
    "printf '%s' \"\$O2_OUT\" | grep -qE '^  FAIL: $d'"
done
for d in "V4-emit-date-2026-07-15" "V4-emit-date-$RELEASE_DATE"; do
  assert_true "AC-7-3-FAIL: O2 injected run reports FAIL: $d" \
    "printf '%s' \"\$O2_OUT\" | grep -qE '^  FAIL: $d'"
done

# =============================================================================
# R2 — AC-7-5(a) structural fence (executable mktemp -d site count, comments
# excluded — GATE:PLAN carry-forward finding, ledger E15 item 1)
# =============================================================================
echo ""
echo "=== R2 — AC-7-5(a) structural fence ==="

MKTEMP_SITES="$(grep -n 'mktemp -d' "$GUARD_SUITE" | grep -vE '^[0-9]+:[[:space:]]*#')"
LACKING_WORKROOT="$(printf '%s\n' "$MKTEMP_SITES" | grep -vc -- '-p "\$WORKROOT"')"
assert_true "AC-7-5a-structural-fence: exactly one executable mktemp -d site lacks -p \"\$WORKROOT\" (the WORKROOT creation line itself; comment-only mentions at :11/:106 excluded)" \
  "[ '$LACKING_WORKROOT' -eq 1 ]"

# =============================================================================
# R2 — O3: aborted-run cleanup (AC-7-5n) — DEFERRED-OBSERVABLE until GREEN
# ships GUARD_CONTRACT_WORKROOT_PARENT support (verification design §1 R2;
# ledger E15 item 2). This suite detects the seam at run time; once GREEN
# ships it, re-running this suite (no edit needed) activates the live legs.
# =============================================================================
echo ""
echo "=== R2 — O3: aborted-run cleanup (AC-7-5n) ==="

if grep -q 'GUARD_CONTRACT_WORKROOT_PARENT' "$GUARD_SUITE"; then
  for SIG in TERM INT; do
    PARENT_DIR="$(mktemp -d)"
    PRE_O3_GIT_STATUS="$(git -C "$PROJECT_ROOT" status --porcelain)"
    PRE_O3_DIGEST_SHA="$(sha256_of "$DIGEST")"

    # No `( ... ) &` subshell wrapper here — VERIFY round 2 measured that
    # `kill -TERM` on a subshell-wrapper PID does not propagate to the guard
    # process it wraps (SIGTERM is delivered to the exact PID only, unlike
    # SIGINT's foreground-process-group propagation), so the guard survives
    # 3/3 and the TERM leg never observes a real interrupt. Launching bash
    # directly in the background makes `$!` the guard-suite process itself,
    # so both TERM and INT are delivered to the process the trap is on.
    GUARD_CONTRACT_WORKROOT_PARENT="$PARENT_DIR" bash "$GUARD_SUITE" >/dev/null 2>&1 &
    CHILD_PID=$!

    NON_VACUOUS=1
    for _ in $(seq 1 150); do
      if [ -n "$(ls -A "$PARENT_DIR" 2>/dev/null)" ]; then
        NON_VACUOUS=0
        break
      fi
      sleep 0.1
    done

    kill -"$SIG" "$CHILD_PID" 2>/dev/null
    wait "$CHILD_PID" 2>/dev/null
    sleep 0.3

    # B20 — do NOT assert on the child's exit status (rc 0 on an INT-killed
    # child carries no cleanup signal). Only the poll (non-vacuous) and the
    # post-reap parent-empty state are asserted.
    assert_true "AC-7-5n-$SIG-non-vacuous: the guard-created parent became non-empty before the signal (a real mktemp -d root was created — makes the leg non-vacuous)" \
      "[ '$NON_VACUOUS' -eq 0 ]"
    assert_true "AC-7-5n-$SIG-parent-empty: the parent still exists and is empty after reap + settle" \
      "[ -d '$PARENT_DIR' ] && [ -z \"\$(ls -A '$PARENT_DIR' 2>/dev/null)\" ]"

    POST_O3_GIT_STATUS="$(git -C "$PROJECT_ROOT" status --porcelain)"
    POST_O3_DIGEST_SHA="$(sha256_of "$DIGEST")"
    assert_true "AC-7-6b-$SIG-git-clean: git status --porcelain unchanged around the interrupted $SIG leg" \
      "[ '$PRE_O3_GIT_STATUS' = '$POST_O3_GIT_STATUS' ]"
    assert_true "AC-7-6b-$SIG-digest-sha-unchanged: live docs/cycle-digest.jsonl SHA-256 unchanged around the interrupted $SIG leg" \
      "[ '$PRE_O3_DIGEST_SHA' = '$POST_O3_DIGEST_SHA' ]"

    rm -rf "$PARENT_DIR" 2>/dev/null
  done
else
  note_deferred "AC-7-5n (interrupt-leg oracle): tests/test-issue-1-guard-contract.sh does not yet support GUARD_CONTRACT_WORKROOT_PARENT (verification design R2 §1; ledger E15 item 2). No seam exists to observe until GREEN ships it — no Red signal is faked for this leg. AC-7-5's structural fence above already asserts live. Re-run this suite after GREEN to activate the live O3 legs."
fi

# =============================================================================
# AC-7-7 — six prior-cycle scope guards admit this cycle's change surface
# (membership only, scoped to each suite's own allow_list=( ... ) block).
# This is satisfied by this same RED commit's F2-F7 edits, so it is a fence,
# not a discriminator against GREEN.
# =============================================================================
echo ""
echo "=== AC-7-7 — prior-cycle scope-guard allow-list membership ==="

for suite in "${ALLOW_LIST_SUITES[@]}"; do
  suite_block="$(extract_allow_list_block "$PROJECT_ROOT/$suite")"
  for p in "${CANONICAL_PATHS[@]}"; do
    assert_allow_list_membership "AC-7-7-membership: $suite allow_list block admits \"$p\"" \
      "$suite_block" "$p"
  done
done

# =============================================================================
# AC-7-7a / AC-7-7d — F8/F1 CI registration (F9, Developer-AI/GREEN scope;
# genuine RED discriminators — B4/B11 confirm zero hits at HEAD)
# =============================================================================
echo ""
echo "=== AC-7-7a / AC-7-7d — workflow CI registration ==="

assert_true "AC-7-7a-pr-paths: pull_request paths: names tests/test-issue-7-oracle-hardening.sh" \
  "awk '/^  pull_request:/{f=1} /^  push:/{f=0} f' '$WORKFLOW' | grep -qF 'tests/test-issue-7-oracle-hardening.sh'"
assert_true "AC-7-7a-push-paths: push paths: names tests/test-issue-7-oracle-hardening.sh" \
  "awk '/^  push:/{f=1} f' '$WORKFLOW' | grep -qF 'tests/test-issue-7-oracle-hardening.sh'"
assert_true "AC-7-7a-run-step: workflow has a run: step invoking tests/test-issue-7-oracle-hardening.sh" \
  "grep -qE 'run: bash tests/test-issue-7-oracle-hardening\\.sh' '$WORKFLOW'"

assert_true "AC-7-7d-pr-paths: pull_request paths: names tests/test-issue-1-guard-contract.sh (ledger E15 item 2 — AC-7-7d's permanence claim requires the workflow to actually trigger when F1 itself changes)" \
  "awk '/^  pull_request:/{f=1} /^  push:/{f=0} f' '$WORKFLOW' | grep -qF 'tests/test-issue-1-guard-contract.sh'"
assert_true "AC-7-7d-push-paths: push paths: names tests/test-issue-1-guard-contract.sh (ledger E15 item 2)" \
  "awk '/^  push:/{f=1} f' '$WORKFLOW' | grep -qF 'tests/test-issue-1-guard-contract.sh'"
assert_true "AC-7-7a-f10-pr-paths: pull_request paths: names tests/manual/issue-7-manual-scenarios.md (ledger E15 item 3 — issue-26/27 manual-scenario paths: registration precedent)" \
  "awk '/^  pull_request:/{f=1} /^  push:/{f=0} f' '$WORKFLOW' | grep -qF 'tests/manual/issue-7-manual-scenarios.md'"
assert_true "AC-7-7a-f10-push-paths: push paths: names tests/manual/issue-7-manual-scenarios.md (ledger E15 item 3)" \
  "awk '/^  push:/{f=1} f' '$WORKFLOW' | grep -qF 'tests/manual/issue-7-manual-scenarios.md'"
assert_true "AC-7-7d-run-step: workflow has a run: step invoking tests/test-issue-1-guard-contract.sh as its own permanent step" \
  "grep -qE 'run: bash tests/test-issue-1-guard-contract\\.sh' '$WORKFLOW'"

# =============================================================================
# AC-7-7b — DELTA lane fence: change surface ⊆ allow-list; the emitter is
# byte-identical to base. Environment-dependent (needs a resolvable base
# ref) — deferred, not faked, when none is resolvable in this environment.
# =============================================================================
echo ""
echo "=== AC-7-7b — DELTA-lane fence (change surface, emitter untouched) ==="

# shellcheck source=tests/lib/base-ref.sh
source "$BASE_REF_LIB"
if BASE_REF="$(resolve_base_ref 2>/dev/null)" && [ -n "$BASE_REF" ]; then
  CHANGED="$(git -C "$PROJECT_ROOT" diff --name-only "$BASE_REF"...HEAD 2>/dev/null)"
  # docs/cycle-digest.jsonl: HANDOFF step 6.7 mandates a digest co-ride commit
  # in the same PR (CLAUDE.md > AutoFlow State Tracking > Companion artifact);
  # the six sibling scope-guard suites (798, 799, 846, 848, 952, 955) already
  # admit this path in their own allow-lists.
  ALLOW_SURFACE="tests/test-issue-1-guard-contract.sh
tests/test-issue-798-topology-flip.sh
tests/test-issue-799-inert-cleanup.sh
tests/test-issue-848-doc-assertions.sh
tests/test-issue-955-subagent-background-ban.sh
tests/test-issue-846-doc-assertions.sh
tests/test-issue-952-wizard-removal.sh
tests/test-issue-7-oracle-hardening.sh
.github/workflows/e2e-dummy-target.yml
tests/manual/issue-7-manual-scenarios.md
docs/cycle-digest.jsonl"
  # The change-surface subset property holds only for the issue-7 cycle's own
  # dev branch (the F1-F10 surface is that PR's contract, not every PR's) —
  # this workflow runs on every PR matching its paths: filter, so enforce the
  # subset lane only on an issue-7 dev branch (GITHUB_HEAD_REF in PR CI, the
  # checked-out branch locally); the emitter byte-identity fence is branch-
  # independent and stays enforced on every run.
  HEAD_BRANCH="${GITHUB_HEAD_REF:-$(git -C "$PROJECT_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null)}"
  case "$HEAD_BRANCH" in
    dev/*-issue-7|dev/*-issue-7-*)
      OUT_OF_SURFACE="$(comm -23 <(printf '%s\n' "$CHANGED" | sort -u) <(printf '%s\n' "$ALLOW_SURFACE" | sort -u))"
      export OUT_OF_SURFACE
      assert_true "AC-7-7b-change-surface-subset: git diff --name-only vs base is a subset of the F1-F10 allow-list" \
        "[ -z \"\$OUT_OF_SURFACE\" ]"
      ;;
    *)
      note_deferred "AC-7-7b-change-surface-subset: cycle-scoped subset lane inert off the issue-7 dev branch (head: ${HEAD_BRANCH:-unknown}) — the F1-F10 surface is the issue-7 PR's contract, not this branch's."
      ;;
  esac
  assert_true "AC-7-7b-emitter-unchanged: scripts/handoff/emit-cycle-digest.sh is byte-identical to base" \
    "git diff --quiet '$BASE_REF' -- scripts/handoff/emit-cycle-digest.sh"
else
  note_deferred "AC-7-7b: no resolvable base ref in this environment (resolve_base_ref returned non-zero) — DELTA-lane fence skipped, not faked."
fi

# =============================================================================
# AC-7-7c — F8 completes in < 180 s (self-timed)
# =============================================================================
echo ""
echo "=== AC-7-7c — runtime budget ==="

TOTAL_ELAPSED=$SECONDS
assert_true "AC-7-7c-under-budget: this suite completes within the 180s CI budget (elapsed ${TOTAL_ELAPSED}s)" \
  "[ '$TOTAL_ELAPSED' -lt 180 ]"

# =============================================================================
# Results
# =============================================================================
echo ""
echo "=============================="
echo "Results: $PASS/$TESTS passed, $FAIL failed"
echo "=============================="

[[ $FAIL -gt 0 ]] && exit 1
exit 0
