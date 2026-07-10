#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# Post a configured-reviewer Korean review comment to a pull request.
#
# The review protocol (Korean output, severity ranking, output format,
# gate-label clearing on a clean review, comment posture otherwise) lives in
# AGENTS.md
# and .codex/review.md and is loaded automatically because Codex runs in the
# repository working directory. This wrapper supplies the target PR number, the
# optional sub-repo selector, and the fixed sandbox / approval flags. The
# prompt's sentinel names the `blocked-by-review` label step so a "comment only"
# reading cannot drop it, but the label is still cleared SOLELY inside this
# isolated reviewer subprocess — the orchestrator (Claude / AutoFlow)
# never removes it, and the gate hook denies any orchestrator attempt.
#
# Reviewer backend (issue #979): the backend is read from
# .claude/autoflow.local.json (`.review.backend`, default `codex`; absent =>
# codex). `codex` runs `codex exec` in the repo working dir (unchanged). `claude`
# runs `claude -p` in a NEUTRAL cwd AND with every CLAUDE-prefixed env var
# scrubbed from the subprocess — both are required to isolate the reviewer as the
# sole authorized label clearer: a nested Claude Code session otherwise attaches
# the child to the parent session's project context (via inherited
# CLAUDECODE / CLAUDE_CODE_*) and loads its .claude gate hooks despite the neutral
# cwd (witnessed on PR #981). It also injects .codex/review.md via
# --system-prompt-file, seals tools to `Bash(gh *)`, passes `--repo` on every gh
# call, and unsets ANTHROPIC_API_KEY to force subscription/OAuth billing. See
# docs/reviewer-backend.md.
#
# Per-PR review gate (Model A): every PR — the host PR AND each sub-repo PR —
# is reviewed on its OWN diff, and its OWN `blocked-by-review` label is cleared
# by its OWN review. Pass `--repo owner/name` to review a sub-repo PR (the
# wrapper then tells Codex to pass `--repo` to every gh command, so fetch /
# comment / label-clear all target that repo); omit `--repo` to review the host
# PR (the current repository). See docs/external-review-sequencing.md.
#
# Posting account: inherited from the local `gh` authentication. It is NOT
# hardcoded.
#
# Usage: scripts/review/codex-review-pr.sh --pr <number> [--repo <owner/name>] [--expected-head <branch>]
set -euo pipefail

# Shared claude-backend isolation preamble (issue #979 cycle 9 §3.2): the
# CLAUDE* env scrub + OAuth carve-out live in ONE place, sourced by both this
# wrapper and check-review-backend.sh --probe, so the Round-7 drift class cannot
# recur. Resolve relative to this script's own directory (cwd is neutralized
# below for the claude call).
_CRP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$_CRP_DIR/lib/claude-isolation.sh"

PR=""
REPO=""
EXPECTED_HEAD=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --pr)
      PR="${2:-}"
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
      echo "Usage: $0 --pr <number> [--repo <owner/name>] [--expected-head <branch>]"
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      echo "Usage: $0 --pr <number> [--repo <owner/name>] [--expected-head <branch>]" >&2
      exit 2
      ;;
  esac
done

if [[ -z "$PR" ]]; then
  echo "Usage: $0 --pr <number> [--repo <owner/name>] [--expected-head <branch>]" >&2
  exit 2
fi

cd "$(git rev-parse --show-toplevel)"

# Reviewer backend selection (issue #979). Read from the target-owned scaffold
# .claude/autoflow.local.json; default codex when the file or key is absent.
BACKEND="codex"
BACKEND_CFG=".claude/autoflow.local.json"
if [[ -f "$BACKEND_CFG" ]]; then
  # Present file: distinguish "valid JSON, key absent" (jq exits 0, prints the
  # codex default) from a PARSE FAILURE. Branch on jq's exit status instead of
  # swallowing it with an or-echo fallback: a malformed config must fail closed,
  # not silently downgrade a configured backend (issue #979 AC-2/AC-3; symmetric with
  # set-review-backend.sh's write-side unparseable-refuse).
  if ! BACKEND="$(jq -r '.review.backend // "codex"' "$BACKEND_CFG" 2>/dev/null)"; then
    echo "[codex-review] ${BACKEND_CFG} is present but not valid JSON — refusing to fall back to codex (a configured backend must not be silently downgraded). Fix or remove the file." >&2
    exit 2
  fi
  if [[ -z "$BACKEND" ]]; then
    echo "[codex-review] ${BACKEND_CFG} sets an empty .review.backend — refusing to fall back to codex (an empty configured value must not be silently downgraded). Set a valid backend or remove the key." >&2
    exit 2
  fi
fi

case "$BACKEND" in
  codex|claude) ;;
  *)
    echo "[codex-review] unknown review backend '${BACKEND}' — expected 'codex' or 'claude' (configured in .claude/autoflow.local.json)." >&2
    exit 2
    ;;
esac

if [[ "$BACKEND" == "claude" ]]; then
  # claude runs neutral-cwd → it cannot resolve the repo from `.`, so resolve the
  # effective repo up front and pass --repo on EVERY gh call (host and sub-repo
  # alike).
  EFFECTIVE_REPO="$REPO"
  if [[ -z "$EFFECTIVE_REPO" ]]; then
    EFFECTIVE_REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null)" || true
  fi
  if [[ -z "$EFFECTIVE_REPO" ]]; then
    echo "[codex-review] could not resolve the repository for the claude backend (gh repo view failed)." >&2
    exit 3
  fi
  repo_clause=" The PR is in the ${EFFECTIVE_REPO} repository: pass '--repo ${EFFECTIVE_REPO}' to EVERY gh command — diff, view, comment, and the label step defined in .codex/review.md."
  gh_suffix=" --repo ${EFFECTIVE_REPO}"
elif [[ -n "$REPO" ]]; then
  repo_clause=" The PR is in the ${REPO} repository (a sub-repo, NOT this one): pass '--repo ${REPO}' to EVERY gh command — diff, view, comment, and the label step defined in .codex/review.md."
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
# sentinel enumerates the two permitted review-state actions — the comment and
# the .codex/review.md blocked-by-review label step — so a "comment only"
# reading cannot drop the label step; the step's conditions stay in
# .codex/review.md. (No backticks: in this double-quoted string they would be
# command substitution.)
SENTINEL="Limit review-state actions to posting the review comment and performing the .codex/review.md blocked-by-review label step; leave approve, request-changes, merge, and close to the reviewer."
PROMPT="Review pull request #${PR}. Follow AGENTS.md and .codex/review.md.${repo_clause} Use the local gh CLI to fetch the PR diff and metadata for #${PR} ('gh pr diff ${PR}${gh_suffix}', 'gh pr view ${PR}${gh_suffix}'). Post the review as a PR comment with 'gh pr comment ${PR}${gh_suffix}'. ${SENTINEL}"

# Start check 2 — whole prompt: the prompt keeps its sentinel tail, so an
# edited or clipped prompt stays here instead of reaching codex partial.
if [[ "$PROMPT" != *"$SENTINEL" ]]; then
  echo "[codex-review] prompt is incomplete — the sentinel tail is missing." >&2
  exit 4
fi

# Start marker — lands in the captured output at once, so a watcher confirms
# this wrapper reached the reviewer call.
echo "[codex-review] starting ${BACKEND} for PR #${PR}${REPO:+ (${REPO})} at $(date -u +%Y-%m-%dT%H:%M:%SZ)"

if [[ "$BACKEND" == "claude" ]]; then
  # claude backend (issue #979, D3/D4/§5.2): run headless `claude -p`
  # synchronously in a NEUTRAL cwd AND with the parent session's CLAUDE* env
  # scrubbed, so the target's project .claude gate hooks are not loaded (the
  # reviewer stays the sole label clearer). Neutral cwd alone is insufficient:
  # a nested Claude Code session re-attaches the child to the parent project via
  # inherited CLAUDECODE / CLAUDE_CODE_* env and loads the gate hook anyway
  # (witnessed on PR #981). Inject the shared instruction body via
  # --system-prompt-file (absolute path, since the cwd is neutral); seal tools to
  # `Bash(gh *)` and block edits; force subscription/OAuth billing by unsetting
  # ANTHROPIC_API_KEY.
  INSTRUCTIONS="$(git rev-parse --show-toplevel)/.codex/review.md"
  MODEL="${MODEL:-}"
  if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
    echo "[codex-review] WARNING: ANTHROPIC_API_KEY is set; unsetting it for the claude reviewer subprocess to force subscription/OAuth billing (avoids metered API charges)." >&2
  fi
  # Isolation triple (issue #979 §3.2): the neutral cwd + CLAUDE* env scrub +
  # OAuth carve-out are established by the shared helper (single source of truth
  # sourced above), which sets NEUTRAL_CWD and the CLAUDE_ISOLATION_UNSET
  # `env -u …` array. Neutral cwd alone does NOT isolate the child: a nested
  # `claude -p` inherits CLAUDECODE / CLAUDE_CODE_* and re-attaches to the parent
  # project's gate hooks despite the neutral cwd (witnessed on PR #981). The
  # third layer, `--setting-sources ""` (load no settings sources), is composed
  # below: it excludes the user-scope plugin gate hook that loads in EVERY claude
  # session regardless of cwd or env (also witnessed on PR #981). This wrapper
  # appends its review-specific flags (--system-prompt-file, the `Bash(gh *)`
  # grant, --model).
  build_claude_isolation
  if ( cd "$NEUTRAL_CWD" && env "${CLAUDE_ISOLATION_UNSET[@]}" claude -p "$PROMPT" \
         --system-prompt-file "$INSTRUCTIONS" \
         --setting-sources "" \
         --allowedTools "Bash(gh *)" \
         --disallowedTools "Edit,Write,MultiEdit" \
         --output-format json \
         ${MODEL:+--model "$MODEL"} ); then
    claude_rc=0
  else
    claude_rc=$?
  fi
  cleanup_claude_isolation
  # Completion marker (D3): the claude oracle is this wrapper's synchronous
  # return, not a ~/.codex/sessions rollout probe.
  echo "[review] claude completed for PR #${PR} (exit=${claude_rc})"
  exit "$claude_rc"
fi

codex exec \
  -s workspace-write \
  -c sandbox_workspace_write.network_access=true \
  -c approval_policy="never" \
  "$PROMPT"
