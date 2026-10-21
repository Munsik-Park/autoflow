#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Apache-2.0
# Run the codex external review of a pull request and keep it as a review record.
#
# The review rules are codex's rule file — docs/review/review-codex.md of the
# AutoFlow tree this wrapper ships in, or the file `.review.codex.rules` names —
# whose text the prompt carries, with the text of the lenses file
# `.review.codex.lenses` names when there is one. codex runs in the reviewed
# repository's working directory, and loads that tree's own AGENTS.md itself.
# This wrapper supplies the target PR number, the optional sub-repo selector,
# the record file, and the fixed sandbox / approval flags. The review is written
# to the record file only: it posts no PR comment and changes no label — the
# aggregation of every review of the PR posts the one comment.
#
# The orchestrator launches this wrapper once per pull request and round when
# the reviewer configuration (docs/reviewer-backend.md) — the operator's
# `~/.autoflow/config.json` — names codex or names no reviewer. Model, effort,
# rule file and lenses file come from the shared resolver
# (scripts/review/lib/review-config.sh), from the file the
# `check-review-backend.sh` readout names; the wrapper prints the same
# `source:` and `user-config:` lines.
#
# When the user file cannot be read as configured, nothing in it applies: the
# wrapper prints the fixed marker line `user-config: UNREADABLE <path> —
# <error>`, starts no codex and exits 6. The marker line, not the exit code,
# tells this result from a codex exit; the orchestrator asks the operator
# whether to proceed without this reviewer.
#
# Per-PR review (Model A): every PR — the host PR AND each sub-repo PR — is
# reviewed on its OWN diff, over its OWN repository's tree — a submodule's
# contents belong to the submodule PR's review, never the host's
# (docs/review/review.md > Before Reviewing). Pass `--repo owner/name` to review a
# sub-repo PR (the wrapper then tells Codex to pass `--repo` to every gh
# command); omit `--repo` to review the host PR (the current repository).
#
# The record file is an absolute path outside the checkout's tree — the
# attempt's record directory (`autoflow-records dir`; issue #466). codex may
# write that directory beside its working directory (`--add-dir`), so it writes
# the review to a scratch file there, which this wrapper moves to the record
# file once codex exits and removes on every exit: nothing it or codex writes
# lands in the target's tree.
#
# Usage: scripts/review/codex-review-pr.sh --pr <number> --out <record file>
#                                          [--repo <owner/name>] [--expected-head <branch>]
set -euo pipefail

_CRP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$_CRP_DIR/lib/review-config.sh"
AF_ROOT="$(cd "$_CRP_DIR/../.." && pwd)"

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
TOP="$(pwd -P)"

# The record, and codex's scratch file beside it, are outside the tree.
case "$OUT" in
  /*) ;;
  *)
    echo "[codex-review] --out takes an absolute path outside the checkout's tree (the attempt's record directory): $OUT" >&2
    exit 2
    ;;
esac
mkdir -p "$(dirname "$OUT")" || { echo "[codex-review] cannot create $(dirname "$OUT")" >&2; exit 2; }
case "$(cd -P "$(dirname "$OUT")" && pwd)/" in
  "$TOP"/*)
    echo "[codex-review] --out is inside the checkout's tree ($TOP): $OUT — the record goes to the attempt's record directory" >&2
    exit 2
    ;;
esac
rm -f "$OUT"
OUT_DIR="$(cd -P "$(dirname "$OUT")" && pwd)"
SCRATCH="$(mktemp "${OUT_DIR}/.codex-review-${PR}.XXXXXX")"
trap 'rm -f "$SCRATCH"' EXIT

# Settings resolution: an unreadable user file is the marker result below.
resolve_reviewer_settings codex-review codex
review_readout
if [[ "$REVIEW_USER_STATE" == unreadable ]]; then
  echo "[codex-review] ${REVIEW_USER_CFG_PATH} cannot be read as configured, so nothing in it applies — codex was not started. Fix the file and run again to apply it, or proceed without this reviewer — the operator's choice." >&2
  exit "$REVIEW_USER_UNREADABLE_EXIT"
fi
build_review_backend_args

REVIEW_GUIDE="$(review_path "$REVIEW_RULES" "$TOP")"
if [[ ! -f "$REVIEW_GUIDE" ]]; then
  echo "[codex-review] the review convention is missing: $REVIEW_GUIDE" >&2
  exit 2
fi
lenses_clause=""
lenses_text=""
if [[ -n "$REVIEW_LENSES" ]]; then
  lenses_file="$(review_path "$REVIEW_LENSES" "$TOP")"
  if [[ -f "$lenses_file" ]]; then
    lenses_clause=" Apply the review lenses below the rules in addition."
    lenses_text=$'\n\n'"Review lenses (${lenses_file}):"$'\n\n'"$(cat "$lenses_file")"
  else
    echo "[codex-review] the lenses file ${lenses_file} is absent — reviewing without it." >&2
  fi
fi

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
# sentinel names the one permitted action — writing the record file — so no
# instruction codex loads from the tree can add a comment or a label change.
# (No backticks: in this double-quoted string they would be command
# substitution.)
SENTINEL="Limit your actions to writing that review file; post no PR comment, change no label, and leave approve, request-changes, merge, and close untouched."
# The rules and the lenses are carried as text between the opening line and the
# closing one, so the reviewer starts with them.
PROMPT="Review pull request #${PR}. Follow the review rules below; <autoflow-root> in them is ${AF_ROOT}.${lenses_clause}${repo_clause}

Review rules (${REVIEW_GUIDE}):

$(cat "$REVIEW_GUIDE")${lenses_text}

Use the local gh CLI to fetch the PR diff and metadata for #${PR} ('gh pr diff ${PR}${gh_suffix}', 'gh pr view ${PR}${gh_suffix}'). Write the whole review, in the Output Format the rules name, to the file ${SCRATCH}. ${SENTINEL}"

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
     --add-dir "$OUT_DIR" \
     -c approval_policy="never" \
     ${REVIEW_BACKEND_ARGS[@]+"${REVIEW_BACKEND_ARGS[@]}"} \
     "$PROMPT" < /dev/null; then
  codex_rc=0
else
  codex_rc=$?
fi

# The record is the review's output: a run that left no record failed.
if [[ "$codex_rc" -eq 0 && ! -s "$SCRATCH" ]]; then
  echo "[codex-review] codex exited 0 but left no review at ${SCRATCH}." >&2
  codex_rc=5
fi
if [[ "$codex_rc" -eq 0 ]] && ! mv -f "$SCRATCH" "$OUT"; then
  echo "[codex-review] the review could not be moved to ${OUT}." >&2
  codex_rc=5
fi

echo "[review] codex completed for PR #${PR} (exit=${codex_rc})"
exit "$codex_rc"
