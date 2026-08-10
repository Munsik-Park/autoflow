#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# AC-59-15(b) — full-tree sweep determination driver (D24)
# =============================================================================
# Verification design (.autoflow/issue-59-verification-design.md §12.2 D24,
# §5.4 AC-59-15(b)): the change surface for issue #59 is determined by
# EXECUTING the tree against a real committed diff, not by enumerating
# suites — three live guards (N1/N2/N3, §0.3) escaped every static
# `grep -ln 'allow_list\|disallowed'` / `grep -ln 'git ls-files'` sweep either
# design used, one of them reaching into a directory (`tests/plugin/`)
# neither glob covers. The three static sweeps remain a CROSS-CHECK on this
# execution result; they are never a substitute for it.
#
# This is a STANDALONE driver, run once at VERIFY against the real committed
# diff — NOT a lane inside tests/test-issue-59-adoption-evidence-discipline.sh
# (AC-59-15(a) lives there). Two measured reasons it is kept out of the cycle
# suite (§12.2 D24):
#   (i) the glob `tests/test-issue-*.sh` contains the cycle suite itself, so
#       an in-suite sweep would be directly self-recursive (this script's own
#       filename deliberately does NOT match that glob, for the same reason);
#   (ii) the sweep's runtime is dominated by test-issue-952-wizard-removal.sh
#       (measured > 280s, its AC5 (T2) drives two full tests/plugin/
#       install-into-target runs) and by the ~18 delegating/aggregating
#       suites (grep -lE 'bash .*tests/' tests/*.sh), so it cannot share
#       AC-59-11d's per-lane budget inside the cycle suite.
#
# Contract: asserts that the set of tests/test-issue-*.sh suites (excluding
# this cycle's own, self-excluded below) that REGRESS against `main` is a
# SUBSET of the suites this cycle's acceptance criteria already name
# (AC-59-11d ∪ AC-59-14 ∪ AC-59-17 ∪ AC-59-18). A regression the cycle's own
# ACs do not cover means a live guard escaped this cycle's design the same
# way N1/N2/N3 escaped rounds 1-7.
#
# Budget: >= 600s wall-clock (F16/D24). Run under a timeout shorter than that
# and a real failure becomes indistinguishable from a kill — report the run
# INCONCLUSIVE in that case, never PASSED (the same discipline AC-59-15
# exists to enforce on the re-run lanes it gates).
#
# A base whose worktree could not be created is INCONCLUSIVE, never `ALREADY
# RED`: `base_exit` is only meaningful when the base run actually executed.
#
# Usage: bash tests/issue-59-full-sweep-driver.sh [BASE_REF]
#   BASE_REF defaults to resolve_base_ref (tests/lib/base-ref.sh).
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BASEREF_LIB="$PROJECT_ROOT/tests/lib/base-ref.sh"
SWEEP_MIN_ELAPSED="${SWEEP_MIN_ELAPSED:-600}"

# The suites this cycle's own acceptance criteria already name as expected to
# regress/change — a hit here is EXPECTED, not a new finding (AC-59-11d ∪
# AC-59-14 ∪ AC-59-17 ∪ AC-59-18).
NAMED_SUITES=(
  "test-issue-798-topology-flip.sh"
  "test-issue-799-inert-cleanup.sh"
  "test-issue-846-doc-assertions.sh"
  "test-issue-848-doc-assertions.sh"
  "test-issue-952-wizard-removal.sh"
  "test-issue-955-subagent-background-ban.sh"
  "test-issue-27-composition-oracle.sh"
  "test-issue-985-doc-assertions.sh"
)

is_named() {
  local f="$1" n
  for n in "${NAMED_SUITES[@]}"; do
    [[ "$f" == "$n" ]] && return 0
  done
  return 1
}

BASE_REF="${1:-}"
if [[ -z "$BASE_REF" && -f "$BASEREF_LIB" ]]; then
  # shellcheck source=/dev/null
  . "$BASEREF_LIB"
  BASE_REF="$(cd "$PROJECT_ROOT" && resolve_base_ref || true)"
fi

if [[ -z "$BASE_REF" ]]; then
  echo "INCONCLUSIVE: no comparison base resolvable — never counted PASSED"
  exit 2
fi

START_TS=$(date +%s)
UNNAMED_REGRESSIONS=()
NAMED_REGRESSIONS=()
CLEAN=()
INCONCLUSIVE=()

echo "Full-tree sweep driver (issue #59, D24) — base: $BASE_REF"
echo "Self-excluding: tests/test-issue-59-*.sh"
echo ""

for suite in "$PROJECT_ROOT"/tests/test-issue-*.sh; do
  base="$(basename "$suite")"
  # Self-exclusion (i): this cycle's own suite would be directly self-recursive.
  [[ "$base" == *issue-59-* ]] && continue

  echo "=== $base ==="
  cur_out="$(cd "$PROJECT_ROOT" && bash "$suite" 2>&1)"
  cur_exit=$?

  base_setup_fail=""
  worktree="$(mktemp -d "${TMPDIR:-/tmp}/autoflow-sweep-wt.XXXXXX" 2>/dev/null)" || worktree=""
  if [[ -z "$worktree" ]]; then
    base_setup_fail="mktemp -d failed"
  else
    git -C "$PROJECT_ROOT" worktree add -q --detach "$worktree" "$BASE_REF" 2>/dev/null
    add_status=$?
    [[ "$add_status" -ne 0 ]] && base_setup_fail="git worktree add exit $add_status"
  fi

  base_out=""
  base_exit=-1
  base_measured=0
  base_present=0
  if [[ -z "$base_setup_fail" ]]; then
    if [[ -f "$worktree/tests/$base" ]]; then
      base_present=1
      base_out="$(cd "$worktree" && bash "tests/$base" 2>&1)"
      base_exit=$?
      base_measured=1
    fi
    git -C "$PROJECT_ROOT" worktree remove --force "$worktree" 2>/dev/null
  else
    [[ -n "$worktree" ]] && rm -rf "$worktree"
  fi

  if [[ "$cur_exit" -eq 0 ]]; then
    echo "  clean (exit 0)"
    CLEAN+=("$base")
  elif [[ -n "$base_setup_fail" ]]; then
    echo "  INCONCLUSIVE: base worktree setup failed for $base ($base_setup_fail) — base never measured; not classified as an existing red base or as a regression"
    INCONCLUSIVE+=("$base")
  elif [[ "$base_present" -eq 0 ]]; then
    echo "  NEW AT HEAD: $base absent at $BASE_REF — no base run to compare against, cur exit $cur_exit"
    CLEAN+=("$base")
  elif [[ "$base_measured" -eq 1 && $base_exit -ne 0 ]]; then
    echo "  ALREADY RED on $BASE_REF (not a #59 regression) — cur exit $cur_exit, base exit $base_exit"
    CLEAN+=("$base")
  elif is_named "$base"; then
    echo "  REGRESSED (named — expected by this cycle's own ACs)"
    NAMED_REGRESSIONS+=("$base")
  else
    echo "  REGRESSED (UNNAMED — not covered by AC-59-11d/14/17/18)"
    UNNAMED_REGRESSIONS+=("$base")
  fi
done

END_TS=$(date +%s)
ELAPSED=$((END_TS - START_TS))

echo ""
echo "=============================="
echo "Elapsed: ${ELAPSED}s (budget >= ${SWEEP_MIN_ELAPSED}s — a shorter run is INCONCLUSIVE, never PASSED)"
echo "Clean/already-red: ${#CLEAN[@]}"
echo "Named regressions (expected): ${#NAMED_REGRESSIONS[@]} ${NAMED_REGRESSIONS[*]:-}"
echo "Unnamed regressions (NEW finding): ${#UNNAMED_REGRESSIONS[@]} ${UNNAMED_REGRESSIONS[*]:-}"
echo "Inconclusive (base never measured): ${#INCONCLUSIVE[@]} ${INCONCLUSIVE[*]:-}"
echo "=============================="

if [[ "$ELAPSED" -lt "$SWEEP_MIN_ELAPSED" ]]; then
  echo "INCONCLUSIVE: elapsed ${ELAPSED}s < ${SWEEP_MIN_ELAPSED}s budget — result not trustworthy under this budget, never counted PASSED"
  exit 2
fi

if [[ "${#UNNAMED_REGRESSIONS[@]}" -gt 0 ]]; then
  echo "FAIL: unnamed regression(s) found — a live guard escaped this cycle's design"
  exit 1
fi

if [[ "${#INCONCLUSIVE[@]}" -gt 0 ]]; then
  echo "INCONCLUSIVE: ${#INCONCLUSIVE[@]} suite(s) never measured — never counted PASSED"
  exit 2
fi

echo "PASS: every regression against $BASE_REF is a suite this cycle's own acceptance criteria already name"
exit 0
