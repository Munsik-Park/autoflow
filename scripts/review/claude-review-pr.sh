#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Apache-2.0
# Run the claude review of a pull request and keep it as a review record.
#
# The review rules are claude's rule file — docs/review/review-claude.md of the
# AutoFlow tree this wrapper ships in, or the file `.review.claude.rules` names —
# whose text the prompt carries, with the text of the lenses file
# `.review.claude.lenses` names when there is one. claude runs non-interactively
# (`claude -p`) in the reviewed repository's working directory, with Read, Grep
# and Glob on any path, the gh reads the review needs and the commands Claude
# Code treats as read-only, beside what the operator's own settings allow;
# every other tool is denied without a prompt
# (`--permission-mode dontAsk`), and the reviewed repository's own settings and
# CLAUDE.md, whose permission rules would add tools in a trusted checkout, are
# not loaded (`--setting-sources user`). Its final message is the
# review, which this wrapper writes to the record file: it posts no PR comment
# and changes no label — the aggregation of every review of the PR writes the
# one report.
#
# The review module launches this wrapper once per pull request and round when
# the reviewer configuration (docs/reviewer-backend.md) — the operator's
# `~/.autoflow/config.json` — names claude or names no reviewer. Model, effort,
# rule file and lenses file come from the shared resolver
# (scripts/review/lib/review-config.sh); the wrapper prints its `source:` and
# `user-config:` lines. When the user file cannot be read as configured, the
# wrapper prints the fixed marker line `user-config: UNREADABLE <path> —
# <error>`, starts no claude and exits 6.
#
# `--records <dir>` names the attempt's record directory — the one the
# invocation names (`records`, ADR-0038 D4) —, where claude reads the earlier
# runs' work; it and the AutoFlow tree are added to claude's working
# directories (`--add-dir`).
#
# Per-PR review: `--repo owner/name` reviews a sub-repo PR (the prompt tells
# claude to pass `--repo` to every gh command); without it the PR is the
# current repository's.
#
# The record file is an absolute path outside the checkout's tree — in the
# run's output directory under the attempt's record directory, which the
# caller names (`--out`).
#
# Usage: scripts/review/claude-review-pr.sh --pr <number> --out <record file>
#                                           [--repo <owner/name>] [--expected-head <branch>]
#                                           [--records <attempt-dir>]
set -euo pipefail

_CRP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$_CRP_DIR/lib/review-config.sh"
AF_ROOT="$(cd "$_CRP_DIR/../.." && pwd)"

USAGE="Usage: $0 --pr <number> --out <record file> [--repo <owner/name>] [--expected-head <branch>] [--records <attempt-dir>]"
PR=""
OUT=""
REPO=""
EXPECTED_HEAD=""
RECORDS=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --pr) PR="${2:-}"; shift 2 ;;
    --out) OUT="${2:-}"; shift 2 ;;
    --repo) REPO="${2:-}"; shift 2 ;;
    --expected-head) EXPECTED_HEAD="${2:-}"; shift 2 ;;
    --records) RECORDS="${2:-}"; shift 2 ;;
    -h|--help) echo "$USAGE"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; echo "$USAGE" >&2; exit 2 ;;
  esac
done

if [[ -z "$PR" || -z "$OUT" ]]; then
  echo "$USAGE" >&2
  exit 2
fi

cd "$(git rev-parse --show-toplevel)"
TOP="$(pwd -P)"

case "$OUT" in
  /*) ;;
  *)
    echo "[claude-review] --out takes an absolute path outside the checkout's tree (the attempt's record directory): $OUT" >&2
    exit 2
    ;;
esac
mkdir -p "$(dirname "$OUT")" || { echo "[claude-review] cannot create $(dirname "$OUT")" >&2; exit 2; }
case "$(cd -P "$(dirname "$OUT")" && pwd)/" in
  "$TOP"/*)
    echo "[claude-review] --out is inside the checkout's tree ($TOP): $OUT — the record goes to the attempt's record directory" >&2
    exit 2
    ;;
esac
if [[ -n "$RECORDS" && ! -d "$RECORDS" ]]; then
  echo "[claude-review] --records is not a directory: $RECORDS" >&2
  exit 2
fi
rm -f "$OUT"
SCRATCH="$(mktemp "$(dirname "$OUT")/.claude-review-${PR}.XXXXXX")"
trap 'rm -f "$SCRATCH"' EXIT

resolve_reviewer_settings claude-review claude
review_readout
if [[ "$REVIEW_USER_STATE" == unreadable ]]; then
  echo "[claude-review] ${REVIEW_USER_CFG_PATH} cannot be read as configured, so nothing in it applies — claude was not started. Fix the file and run again to apply it." >&2
  exit "$REVIEW_USER_UNREADABLE_EXIT"
fi
build_review_backend_args

REVIEW_GUIDE="$(review_path "$REVIEW_RULES" "$TOP")"
if [[ ! -f "$REVIEW_GUIDE" ]]; then
  echo "[claude-review] the review convention is missing: $REVIEW_GUIDE" >&2
  exit 2
fi
lenses_clause=""
lenses_text=""
add_dirs=(--add-dir "$AF_ROOT" --add-dir "$(dirname "$REVIEW_GUIDE")")
if [[ -n "$REVIEW_LENSES" ]]; then
  lenses_file="$(review_path "$REVIEW_LENSES" "$TOP")"
  if [[ -f "$lenses_file" ]]; then
    lenses_clause=" Apply the review lenses below the rules in addition."
    lenses_text=$'\n\n'"Review lenses (${lenses_file}):"$'\n\n'"$(cat "$lenses_file")"
    add_dirs+=(--add-dir "$(dirname "$lenses_file")")
  else
    echo "[claude-review] the lenses file ${lenses_file} is absent — reviewing without it." >&2
  fi
fi
records_clause=""
if [[ -n "$RECORDS" ]]; then
  RECORDS="$(cd "$RECORDS" && pwd -P)"
  records_clause=" The attempt's record directory is ${RECORDS}."
  add_dirs+=(--add-dir "$RECORDS")
fi

if [[ -n "$REPO" ]]; then
  repo_clause=" The PR is in the ${REPO} repository (a sub-repo, NOT this one): pass '--repo ${REPO}' to EVERY gh command."
  gh_suffix=" --repo ${REPO}"
else
  repo_clause=""
  gh_suffix=""
fi

# Target sanity: the PR is reachable and OPEN, and (with --expected-head) on
# that head branch — a clipped --pr value that lands on another real PR stops
# here.
pr_meta=$(gh pr view "$PR" ${gh_suffix} --json state,headRefName -q '"\(.state)\t\(.headRefName)"' 2>/dev/null) || {
  echo "[claude-review] PR #${PR}${REPO:+ in ${REPO}} is unreachable — recheck the --pr value." >&2
  exit 3
}
pr_state=${pr_meta%%$'\t'*}
pr_head=${pr_meta#*$'\t'}
if [[ "$pr_state" != "OPEN" ]]; then
  echo "[claude-review] PR #${PR}${REPO:+ in ${REPO}} is ${pr_state}; review targets an OPEN PR." >&2
  exit 3
fi
if [[ -n "$EXPECTED_HEAD" && "$pr_head" != "$EXPECTED_HEAD" ]]; then
  echo "[claude-review] PR #${PR} head '${pr_head}' differs from the expected '${EXPECTED_HEAD}' — recheck the --pr value." >&2
  exit 3
fi

# The prompt ends with a fixed sentinel; review-start-check.sh finds the run by
# its opening `Review pull request #<N>. `.
SENTINEL="Limit your actions to reading; post no PR comment, change no label, and leave approve, request-changes, merge, and close untouched."
# The rules and the lenses are carried as text between the opening line and the
# closing one, so the reviewer starts with them.
PROMPT="Review pull request #${PR}. Follow the review rules below; <autoflow-root> in them is ${AF_ROOT}.${lenses_clause}${records_clause}${repo_clause}

Review rules (${REVIEW_GUIDE}):

$(cat "$REVIEW_GUIDE")${lenses_text}

Use the local gh CLI to read the PR diff and metadata for #${PR} ('gh pr diff ${PR}${gh_suffix}', 'gh pr view ${PR}${gh_suffix}'). Reply with the whole review, in the Output Format the rules name, as your final message. ${SENTINEL}"
if [[ "$PROMPT" != *"$SENTINEL" ]]; then
  echo "[claude-review] prompt is incomplete — the sentinel tail is missing." >&2
  exit 4
fi

echo "[claude-review] starting claude for PR #${PR}${REPO:+ (${REPO})} ($(review_config_summary)) at $(date -u +%Y-%m-%dT%H:%M:%SZ)"

if claude -p "$PROMPT" \
     --permission-mode dontAsk --setting-sources user \
     --allowedTools Read Grep Glob "Bash(gh pr view:*)" "Bash(gh pr diff:*)" "Bash(gh issue view:*)" \
     "${add_dirs[@]}" \
     ${REVIEW_BACKEND_ARGS[@]+"${REVIEW_BACKEND_ARGS[@]}"} \
     --output-format text < /dev/null > "$SCRATCH"; then
  claude_rc=0
else
  claude_rc=$?
fi

if [[ "$claude_rc" -eq 0 && ! -s "$SCRATCH" ]]; then
  echo "[claude-review] claude exited 0 but returned no review." >&2
  claude_rc=5
fi
if [[ "$claude_rc" -eq 0 ]] && ! mv -f "$SCRATCH" "$OUT"; then
  echo "[claude-review] the review could not be moved to ${OUT}." >&2
  claude_rc=5
fi

echo "[review] claude completed for PR #${PR} (exit=${claude_rc})"
exit "$claude_rc"
