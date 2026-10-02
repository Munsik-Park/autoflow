#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# Run the codex external review of a pull request and keep it as a review record.
#
# The review protocol (Korean output, severity ranking, output format) lives in
# AGENTS.md and .codex/review.md and is loaded automatically because Codex runs
# in the repository working directory. This wrapper supplies the target PR
# number, the optional sub-repo selector, the record file, and the fixed
# sandbox / approval flags. The review is written to the record file only: it
# posts no PR comment and changes no label — the aggregation of every review of
# the PR posts the one comment and sets `blocked-by-review`
# (docs/units/delivery.md > Review aggregation).
#
# codex runs only when `.claude/autoflow.local.json` names it as an external
# reviewer (docs/reviewer-backend.md); the orchestrator launches this wrapper
# once per pull request and round for it. Model and effort come from the shared
# resolver (scripts/review/lib/review-config.sh).
#
# Per-PR review (Model A): every PR — the host PR AND each sub-repo PR — is
# reviewed on its OWN diff, over its OWN repository's tree — a submodule's
# contents belong to the submodule PR's review, never the host's
# (.codex/review.md > Before Reviewing). Pass `--repo owner/name` to review a
# sub-repo PR (the wrapper then tells Codex to pass `--repo` to every gh
# command); omit `--repo` to review the host PR (the current repository).
#
# Usage: scripts/review/codex-review-pr.sh --pr <number> --out <record file>
#                                          [--repo <owner/name>] [--expected-head <branch>]
set -euo pipefail

_CRP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$_CRP_DIR/lib/review-config.sh"

USAGE="Usage: $0 --pr <number> --out <record file> [--repo <owner/name>] [--expected-head <branch>]"
PR=""
OUT=""
REPO=""
EXPECTED_HEAD=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --pr)
      PR="${2:-}"
      shift 2
      ;;
    --out)
      OUT="${2:-}"
      shift 2
      ;;
    --repo)
      REPO="${2:-}"
      shift 2
      ;;
    --expected-head)
      EXPECTED_HEAD="${2:-}"
      shift 2
      ;;
    -h|--help)
      echo "$USAGE"
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      echo "$USAGE" >&2
      exit 2
      ;;
  esac
done

if [[ -z "$PR" || -z "$OUT" ]]; then
  echo "$USAGE" >&2
  exit 2
fi

cd "$(git rev-parse --show-toplevel)"

# The record lands inside the working directory codex's workspace-write sandbox
# may write to.
case "$OUT" in
  /*|*..*)
    echo "[codex-review] --out takes a path relative to the repository root, without '..': $OUT" >&2
    exit 2
    ;;
esac
mkdir -p "$(dirname "$OUT")"
rm -f "$OUT"

# Model / effort resolution: a present-but-unreadable file, an empty model or
# effort, or an effort outside codex's vocabulary fails closed here (exit 2) —
# no reviewer launches on a rejected config.
resolve_reviewer_settings codex-review codex
build_review_backend_args

if [[ -n "$REPO" ]]; then
  repo_clause=" The PR is in the ${REPO} repository (a sub-repo, NOT this one): pass '--repo ${REPO}' to EVERY gh command."
  gh_suffix=" --repo ${REPO}"
else
  repo_clause=""
  gh_suffix=""
fi

# Start check 1 — target sanity: the PR is reachable and OPEN, and (when
# --expected-head is given) its head branch matches. Reachable + OPEN rejects a
# missing or already-closed target; the head match is the independent signal
# that catches a clipped --pr value landing on another real PR (e.g. 579 read
# as 57). Pass --expected-head <branch> for that truncation coverage.
pr_meta=$(gh pr view "$PR" ${gh_suffix} --json state,headRefName -q '"\(.state)\t\(.headRefName)"' 2>/dev/null) || {
  echo "[codex-review] PR #${PR}${REPO:+ in ${REPO}} is unreachable — recheck the --pr value." >&2
  exit 3
}
pr_state=${pr_meta%%$'\t'*}
pr_head=${pr_meta#*$'\t'}
if [[ "$pr_state" != "OPEN" ]]; then
  echo "[codex-review] PR #${PR}${REPO:+ in ${REPO}} is ${pr_state}; review targets an OPEN PR." >&2
  exit 3
fi
if [[ -n "$EXPECTED_HEAD" && "$pr_head" != "$EXPECTED_HEAD" ]]; then
  echo "[codex-review] PR #${PR} head '${pr_head}' differs from the expected '${EXPECTED_HEAD}' — recheck the --pr value." >&2
  exit 3
fi

# Build the review prompt as one value, ending with a fixed sentinel line. The
# sentinel names the one permitted action — writing the record file — so the
# AGENTS.md / .codex/review.md defaults cannot add a comment or a label change.
# (No backticks: in this double-quoted string they would be command
# substitution.)
SENTINEL="Limit your actions to writing that review file; post no PR comment, change no label, and leave approve, request-changes, merge, and close untouched."
PROMPT="Review pull request #${PR}. Follow AGENTS.md and .codex/review.md.${repo_clause} Use the local gh CLI to fetch the PR diff and metadata for #${PR} ('gh pr diff ${PR}${gh_suffix}', 'gh pr view ${PR}${gh_suffix}'). Write the whole review, in the .codex/review.md Output Format, to the file ${OUT} (relative to the repository root). ${SENTINEL}"

# Start check 2 — whole prompt: the prompt keeps its sentinel tail, so an
# edited or clipped prompt stays here instead of reaching codex partial.
if [[ "$PROMPT" != *"$SENTINEL" ]]; then
  echo "[codex-review] prompt is incomplete — the sentinel tail is missing." >&2
  exit 4
fi

# Start marker — lands in the captured output at once, so a watcher confirms
# this wrapper reached the reviewer call. It names the effective model/effort
# and nothing else from the environment, so the log stays free of credentials.
echo "[codex-review] starting codex for PR #${PR}${REPO:+ (${REPO})} ($(review_config_summary)) at $(date -u +%Y-%m-%dT%H:%M:%SZ)"

if codex exec \
     -s workspace-write \
     -c sandbox_workspace_write.network_access=true \
     -c approval_policy="never" \
     ${REVIEW_BACKEND_ARGS[@]+"${REVIEW_BACKEND_ARGS[@]}"} \
     "$PROMPT" < /dev/null; then
  codex_rc=0
else
  codex_rc=$?
fi

# The record is the review's output: a run that left no record failed.
if [[ "$codex_rc" -eq 0 && ! -s "$OUT" ]]; then
  echo "[codex-review] codex exited 0 but left no review record at ${OUT}." >&2
  codex_rc=5
fi

echo "[review] codex completed for PR #${PR} (exit=${codex_rc})"
exit "$codex_rc"
