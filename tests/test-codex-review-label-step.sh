#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# Test: codex-review wrapper prompt permits/requires the blocked-by-review
#       label-clear step (issue: clean-review label policy vs. wrapper prompt)
# =============================================================================
# Background: scripts/review/codex-review-pr.sh feeds Codex a fixed prompt that
# ends in a SENTINEL line. The previous sentinel ("Limit the action to posting
# the review comment; ...") could be read as "comment only", which silently
# dropped the .codex/review.md required step: on a clean review (no confirmed
# Critical/High/Medium), the Codex reviewer must remove the `blocked-by-review`
# gate label. That label is the pipeline gate; the orchestrator (Claude /
# AutoFlow) is forbidden from clearing it (hook-enforced), so ONLY the isolated
# `codex exec` reviewer session can. The prompt must therefore direct the
# reviewer to perform BOTH the comment step AND the label step, while still
# forbidding approve / request-changes / merge / close.
#
# This guards the ACTUAL string literals in the wrapper: it extracts the real
# `SENTINEL=` / `PROMPT=` assignment lines from the script and evals them with
# the same surrounding variables the script sets (PR / REPO / repo_clause /
# gh_suffix), then asserts on the rendered prompt for both the host PR
# (no --repo) and a sub-repo PR (--repo present).
#
# Harness convention: set -euo pipefail, assert_true, canonical Results line,
# exit 1 iff F>0.
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WRAPPER="$PROJECT_ROOT/scripts/review/codex-review-pr.sh"

PASS=0
FAIL=0
TESTS=0

assert_true() {
  local desc="$1" condition="$2"
  TESTS=$((TESTS + 1))
  if eval "$condition"; then
    echo "  PASS: $desc"; PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"; FAIL=$((FAIL + 1))
  fi
}

echo "=============================================="
echo "codex-review wrapper — blocked-by-review label step in prompt"
echo "=============================================="

# Extract the real assignment lines so the test guards the file, not a copy.
SENTINEL_LINE="$(grep -E '^SENTINEL=' "$WRAPPER")"
PROMPT_LINE="$(grep -E '^PROMPT=' "$WRAPPER")"

assert_true "wrapper defines a SENTINEL assignment" "[[ -n \"\$SENTINEL_LINE\" ]]"
assert_true "wrapper defines a PROMPT assignment"   "[[ -n \"\$PROMPT_LINE\" ]]"

# Render the prompt for a given REPO by evaluating the real assignments under the
# same variables the wrapper sets around them.
render_prompt() {
  local PR="$1" REPO="$2" repo_clause gh_suffix SENTINEL PROMPT
  if [[ -n "$REPO" ]]; then
    repo_clause=" The PR is in the ${REPO} repository (a sub-repo, NOT this one): pass '--repo ${REPO}' to EVERY gh command — diff, view, comment, and the label step defined in .codex/review.md."
    gh_suffix=" --repo ${REPO}"
  else
    repo_clause=""
    gh_suffix=""
  fi
  eval "$SENTINEL_LINE"
  eval "$PROMPT_LINE"
  RENDER_SENTINEL="$SENTINEL"
  RENDER_PROMPT="$PROMPT"
}

# ---------------------------------------------------------------------------
# Host PR render (no --repo).
# ---------------------------------------------------------------------------
echo "Host PR (no --repo):"
render_prompt 999 ""
HOST_PROMPT="$RENDER_PROMPT"
HOST_SENTINEL="$RENDER_SENTINEL"

# The sentinel positively enumerates the label step (not 'comment only') and
# still forbids approve / request-changes / merge / close. The step's detailed
# conditions (Critical/High/Medium gating, failure reporting) live in
# .codex/review.md — the prompt references it via "Follow ... .codex/review.md"
# rather than duplicating them, so this test asserts the reference, not a copy.
assert_true "host: sentinel permits the comment + label step (not 'comment only')" \
  "printf '%s' \"\$HOST_SENTINEL\" | grep -qi 'posting the review comment and performing the .codex/review.md blocked-by-review label step'"
assert_true "host: sentinel still forbids approve/request-changes/merge/close" \
  "printf '%s' \"\$HOST_SENTINEL\" | grep -qi 'leave approve, request-changes, merge, and close to the reviewer'"
assert_true "host: old 'Limit the action to posting the review comment' wording removed" \
  "! printf '%s' \"\$HOST_SENTINEL\" | grep -qi 'Limit the action to posting the review comment'"
assert_true "host: prompt directs the reviewer to follow .codex/review.md" \
  "printf '%s' \"\$HOST_PROMPT\" | grep -q 'Follow AGENTS.md and .codex/review.md'"
# The prompt must end with the sentinel (the wrapper's own tail integrity check).
assert_true "host: prompt ends with the sentinel tail" \
  "[[ \"\$HOST_PROMPT\" == *\"\$HOST_SENTINEL\" ]]"

# ---------------------------------------------------------------------------
# Sub-repo PR render (--repo present) — the pre-existing repo_clause is the
# mechanism that carries the --repo target onto the label step (req 5).
# ---------------------------------------------------------------------------
echo "Sub-repo PR (--repo dummy-org/dummy-subrepo):"
render_prompt 999 "dummy-org/dummy-subrepo"
SUB_PROMPT="$RENDER_PROMPT"

assert_true "sub-repo: repo_clause routes --repo onto EVERY gh command incl. the label step" \
  "printf '%s' \"\$SUB_PROMPT\" | grep -q \"pass '--repo dummy-org/dummy-subrepo' to EVERY gh command\" && printf '%s' \"\$SUB_PROMPT\" | grep -q 'the label step defined in .codex/review.md'"

# ---------------------------------------------------------------------------
# Results.
# ---------------------------------------------------------------------------
echo ""
echo "=============================="
echo "Results: $PASS/$TESTS passed, $FAIL failed"
echo "=============================="

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
exit 0
