#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# PREFLIGHT — the steps that are fixed, run as one call (ADR-0025 D8)
# =============================================================================
# Reads every `.autoflow/issue-*.json` state file against its dev branch and
# its pull request, clears the cycles whose PR is merged or closed, selects the
# requested issue's mode from its own state, syncs the branch the mode works
# on, runs the fail-closed readiness checks, and creates the dev branch and the
# state file (new issue) or sets the state up for the next cycle
# (review-response). What it reports is fact; where an interrupted cycle
# resumes is the orchestrator's judgment over those facts
# (docs/phases/preflight.md > Resume).
#
# It never pushes and never opens a pull request. A remote dev branch left
# behind by a merged or closed PR is named on a `remote-branch-to-delete:`
# line and the run stops (exit 12) before any state file is active, so the
# orchestrator deletes it with `git push origin --delete <branch>` — a command
# the gate hook sees, and admits only while no cycle is active — and runs this
# again.
#
# Subcommands
#   status [--issue N]
#       Read-only. One fact block per state file; with --issue, that issue's
#       gate records, artifacts and ledger markers as well. Exit 0.
#   enter --issue N [--title T]
#       The PREFLIGHT run for issue N.
#   review-response --issue N [--keep-analysis]
#       The review-response setup alone, on the checked-out dev branch: the
#       local checks for the next cycle, the previous cycle's artifacts renamed
#       to `issue-N-c<C>-*`, the state file moved to the next cycle. `enter`
#       runs it when it selects that mode; HANDOFF runs it for a `design`
#       re-entry inside the session. `--keep-analysis` leaves the analysis
#       report and the GATE:HYPOTHESIS records in place (a re-entry that starts
#       at ARCHITECT).
#
# Exit codes (enter / review-response)
#   0   ready — `mode: new-issue | review-response | resume`; the record is
#       written to `.autoflow/issue-N-preflight.md`
#   10  hold — another issue's state file reads `active:true`
#   11  paused — issue N is inactive at `phase: awaiting-user`, or inactive
#       with no open PR (a pause for a human decision); its state is unchanged
#   12  a cleared cycle left its dev branch on the remote (named on
#       `remote-branch-to-delete:` lines); the requested issue is untouched —
#       delete each branch and run again
#   20  the working tree is dirty (the paths are listed). At entry nothing was
#       changed; after the local checks (which may leave the tree dirty) the
#       mode's branch is already checked out and synced. A resume does not
#       stop on a dirty tree — it reports the count
#   21  sync failed — `git fetch`, or a fast-forward of the branch the mode
#       works on
#   22  the requested issue's dev branch is missing, matches more than one
#       name, exists with no state file, or cannot be checked out or created
#   30  bundle drift (`.claude/autoflow/drift-check.sh`)
#   31  the configured reviewer backend's CLI is absent
#   32  a target-declared local check failed
#   33  the local-check declaration is unreadable
#   40  a `gh` read failed (pull request or issue lookup)
#   41  a state file is unreadable as JSON
#   42  archiving a cleared issue failed
#   64  usage
#
# Usage: scripts/preflight/preflight.sh <status|enter|review-response> [options]
# =============================================================================

set -uo pipefail

TAG="preflight"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  echo "Usage: $0 status [--issue N]"
  echo "       $0 enter --issue N [--title T]"
  echo "       $0 review-response --issue N [--keep-analysis]"
}

SUB="${1:-}"
[ $# -gt 0 ] && shift
ISSUE=""
TITLE=""
KEEP_ANALYSIS=0
while [ $# -gt 0 ]; do
  case "$1" in
    --issue) [ $# -ge 2 ] || { usage >&2; exit 64; }; ISSUE="${2#\#}"; shift 2 ;;
    --title) [ $# -ge 2 ] || { usage >&2; exit 64; }; TITLE="$2"; shift 2 ;;
    --keep-analysis) KEEP_ANALYSIS=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "[$TAG] unknown argument: $1" >&2; usage >&2; exit 64 ;;
  esac
done
case "$SUB" in
  status) ;;
  enter|review-response) [ -n "$ISSUE" ] || { usage >&2; exit 64; } ;;
  -h|--help) usage; exit 0 ;;
  *) usage >&2; exit 64 ;;
esac
case "$ISSUE" in
  *[!0-9]*) echo "[$TAG] --issue takes an issue number: $ISSUE" >&2; exit 64 ;;
esac

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "[$TAG] not inside a git repository" >&2; exit 64; }
cd "$ROOT" || exit 64
AF=".autoflow"
mkdir -p "$AF"

LOG="$(mktemp)"
trap 'rm -f "$LOG"' EXIT
say() { printf '%s\n' "$*" | tee -a "$LOG"; }

# The record is written on a ready exit only: a stop leaves the previous
# cycle's record, not yet renamed, as it is.
finish_ready() {
  cp "$LOG" "$AF/issue-$ISSUE-preflight.md"
  echo "record: $AF/issue-$ISSUE-preflight.md"
  exit 0
}

default_branch() {
  local b
  b="$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null)" && { printf '%s' "${b#origin/}"; return; }
  printf 'main'
}

# The issue-scoped dev branch is named `dev/<date>-issue-<N>`; both the local
# and the origin refs are read, so a branch that exists on one side only is
# still found.
branches_of() {
  {
    git for-each-ref --format='%(refname:lstrip=2)' "refs/heads/dev/*-issue-$1"
    git for-each-ref --format='%(refname:lstrip=3)' "refs/remotes/origin/dev/*-issue-$1"
  } | sort -u
}
has_local()  { git show-ref --verify --quiet "refs/heads/$1"; }
has_remote() { git show-ref --verify --quiet "refs/remotes/origin/$1"; }

# pr_of <branch> — "<number> <STATE> <url>" of the branch's pull request (an
# open one when there is one, otherwise the most recently updated), or empty.
pr_of() {
  local out
  out="$(gh pr list --head "$1" --state all --limit 30 --json number,state,url,updatedAt 2>/dev/null)" || return 1
  printf '%s' "$out" | jq -r 'sort_by(.updatedAt) | ((map(select(.state == "OPEN")) | last) // last) | if . == null then "" else "\(.number) \(.state) \(.url)" end'
}

state_field() { jq -r "$2" "$AF/issue-$1.json" 2>/dev/null; }

state_issues() {
  local f n
  for f in "$AF"/issue-*.json; do
    [ -f "$f" ] || continue
    n="${f##*/issue-}"; n="${n%.json}"
    case "$n" in ''|*[!0-9]*) continue ;; esac
    printf '%s\n' "$n"
  done | sort -n
}

# Facts about one issue's cycle, read from its state file, its branch and its
# pull request. Sets F_ACTIVE F_PHASE F_MODE F_CYCLE F_BRANCH F_BRANCH_COUNT
# F_PR F_PR_STATE F_PR_URL. Returns 41 on an unreadable state file, 40 on a
# failed PR lookup.
read_facts() {
  local n="$1" line
  jq -e . "$AF/issue-$n.json" >/dev/null 2>&1 || return 41
  F_ACTIVE="$(state_field "$n" '.active // false')"
  F_PHASE="$(state_field "$n" '.phase // ""')"
  F_MODE="$(state_field "$n" '.mode // ""')"
  F_CYCLE="$(state_field "$n" '.cycle // 1')"
  F_BRANCH="$(branches_of "$n")"
  F_BRANCH_COUNT="$(printf '%s' "$F_BRANCH" | grep -c . || true)"
  F_PR=""; F_PR_STATE=""; F_PR_URL=""; F_PR_LOOKUP="ok"
  if [ "$F_BRANCH_COUNT" = "1" ]; then
    line="$(pr_of "$F_BRANCH")" || { F_PR_LOOKUP="failed"; return 40; }
    if [ -n "$line" ]; then
      F_PR="${line%% *}"; line="${line#* }"
      F_PR_STATE="${line%% *}"; F_PR_URL="${line#* }"
    fi
  fi
  return 0
}

print_facts() {
  say "issue #$1: active=$F_ACTIVE phase=${F_PHASE:-unset} mode=${F_MODE:-unset} cycle=$F_CYCLE"
  case "$F_BRANCH_COUNT" in
    0) say "  branch: none" ;;
    1) say "  branch: $F_BRANCH (local=$(has_local "$F_BRANCH" && echo yes || echo no) origin=$(has_remote "$F_BRANCH" && echo yes || echo no))" ;;
    *) say "  branch: ambiguous — $(printf '%s' "$F_BRANCH" | tr '\n' ' ')" ;;
  esac
  if [ "$F_PR_LOOKUP" = "failed" ]; then say "  pr: lookup failed"
  elif [ -n "$F_PR" ]; then say "  pr: #$F_PR $F_PR_STATE $F_PR_URL"
  elif [ "$F_BRANCH_COUNT" = "0" ]; then say "  pr: not looked up (no dev branch to look it up by)"
  else say "  pr: none"; fi
}

# What a resume is judged from: each gate's record, the artifacts on disk, the
# ledger's open-attempt markers and the last local-checks record.
print_cycle_detail() {
  local n="$1" led="$AF/issue-$1-ledger.md" f
  say "  gates:"
  jq -r '
    def num: if type == "object" then .score else . end;
    (.phases // {}) | to_entries[] |
    "    \(.key): " +
    ( (.value.scores // {}) as $s
      | if ($s | length) == 0 then "no scores"
        else ([$s[] | num] ) as $v | "scores=\($v | length) min=\($v | min) avg=\(($v | add) / ($v | length) * 100 | round / 100)" end )
    + (if .value.verdict != null and .value.verdict != "" then " verdict=\"\(.value.verdict)\"" else "" end)
    + (if .value.remedy_class != null then " remedy_class=\(.value.remedy_class)" else "" end)
  ' "$AF/issue-$n.json" 2>/dev/null | while IFS= read -r f; do say "$f"; done
  say "  artifacts:"
  for f in "$AF"/issue-"$n"-*; do
    [ -e "$f" ] || continue
    case "${f##*/}" in issue-"$n"-c[0-9]*-*) continue ;; esac
    say "    ${f##*/}"
  done
  if [ -f "$led" ]; then
    say "  ledger markers (last of each):"
    for f in gate-autofix rebuttal review-autofix reentry-decision; do
      grep -n -E "^## .*\[$f\][[:space:]]*$" "$led" | tail -1 | while IFS= read -r line; do say "    $line"; done
    done
    say "  last local-checks record (cycle $F_CYCLE): $(last_local_checks "$led" "$F_CYCLE")"
  else
    say "  ledger: none"
  fi
}

# The result line of the last `### preflight-local-checks | cycle: <C>` record.
last_local_checks() {
  [ -f "$1" ] || { echo "none"; return; }
  awk -v c="$2" '
    $0 == "### preflight-local-checks | cycle: " c { want = 1; next }
    want && /^- result: / { sub(/^- result: (PREFLIGHT local checks: )?/, ""); last = $0; want = 0 }
    END { print (last == "" ? "none" : last) }' "$1"
}

dirty_stop() {
  local paths
  paths="$(git status --porcelain)"
  [ -z "$paths" ] && return 0
  say "stop: the working tree is dirty — resolve it (stash, commit, or discard with the user's approval) and run this again"
  printf '%s\n' "$paths" | while IFS= read -r line; do say "  $line"; done
  exit 20
}

run_local_checks() {
  local cycle="$1" rc
  bash "$SCRIPT_DIR/local-checks.sh" --ledger "$AF/issue-$ISSUE-ledger.md" --cycle "$cycle" 2>&1 | tee -a "$LOG"
  rc="${PIPESTATUS[0]}"
  case "$rc" in
    0) return 0 ;;
    1) say "stop: a target-declared local check failed"; exit 32 ;;
    3) say "stop: the local checks passed and left the working tree dirty — resolve it and run this again"; exit 20 ;;
    *) say "stop: the local-check declaration is unreadable (.claude/autoflow.local.json > preflight.local_checks)"; exit 33 ;;
  esac
}

# The two stop conditions that do not depend on the cycle number.
run_bundle_checks() {
  if [ -f .claude/autoflow/manifest.json ]; then
    if sh .claude/autoflow/drift-check.sh 2>&1 | tee -a "$LOG"; [ "${PIPESTATUS[0]}" -ne 0 ]; then
      say "stop: bundle drift — repair as the failing leg names (docs/phases/preflight.md > Stop conditions)"
      exit 30
    fi
  else
    say "drift-check: not run (no installed manifest)"
  fi
  if bash "$SCRIPT_DIR/check-review-backend.sh" 2>&1 | tee -a "$LOG"; [ "${PIPESTATUS[0]}" -ne 0 ]; then
    say "stop: the configured reviewer backend is not available"
    exit 31
  fi
  say "reviewer backend: available"
}

state_template_phases='{
  "gate_hypothesis_structure": { "evaluator": "", "scores": {} },
  "gate_hypothesis_cause":     { "evaluator": "", "scores": {}, "verdict": "pending" },
  "gate_plan":                 { "evaluator": "", "scores": {} },
  "audit":                     { "evaluator": "", "scores": {} },
  "gate_quality":              { "evaluator": "", "scores": {} }
}'

write_state() {  # <jq filter> [jq args...]; rewrites the requested issue's state file in place
  local f="$AF/issue-$ISSUE.json" tmp
  tmp="$(mktemp "$AF/.issue-$ISSUE.json.XXXXXX")"
  if jq "$@" "$f" > "$tmp"; then mv "$tmp" "$f"; else rm -f "$tmp"; say "stop: cannot rewrite $f"; exit 41; fi
}

add_progress_label() {
  if gh issue edit "$ISSUE" --add-label "status:in-progress" >/dev/null 2>&1; then
    say "label: status:in-progress added to #$ISSUE"
  else
    say "label: status:in-progress not added to #$ISSUE (the label may not exist in this repository)"
  fi
}

# The review-response setup on the checked-out dev branch.
review_response_setup() {
  local prev new f base
  prev="$(state_field "$ISSUE" '.cycle // 1')"
  new=$((prev + 1))
  run_local_checks "$new"
  # The previous cycle's artifacts take the `c<C>-` infix. What spans cycles
  # stays: the ledger, the advisor records its entries point at, the per-PR
  # findings files and the cycle-layer store (a directory, so never matched).
  for f in "$AF"/issue-"$ISSUE"-*.md; do
    [ -f "$f" ] || continue
    base="${f##*/}"
    case "$base" in
      issue-"$ISSUE"-c[0-9]*-*) continue ;;
      issue-"$ISSUE"-ledger.md|issue-"$ISSUE"-advisor-*|issue-"$ISSUE"-review-findings*.md) continue ;;
      issue-"$ISSUE"-analysis.md) [ "$KEEP_ANALYSIS" -eq 1 ] && continue ;;
    esac
    mv "$f" "$AF/issue-$ISSUE-c$prev-${base#issue-"$ISSUE"-}"
    say "renamed: $base -> issue-$ISSUE-c$prev-${base#issue-"$ISSUE"-}"
  done
  if [ "$KEEP_ANALYSIS" -eq 1 ]; then
    write_state --argjson c "$new" --argjson t "$state_template_phases" \
      '.active = true | .mode = "review-response" | .phase = "in-progress" | .cycle = $c
       | .phases.gate_plan = $t.gate_plan | .phases.audit = $t.audit | .phases.gate_quality = $t.gate_quality'
  else
    write_state --argjson c "$new" --argjson t "$state_template_phases" \
      '.active = true | .mode = "review-response" | .phase = "in-progress" | .cycle = $c | .phases = $t'
  fi
  say "state: $AF/issue-$ISSUE.json -> active=true mode=review-response cycle=$new$([ "$KEEP_ANALYSIS" -eq 1 ] && echo ' (analysis report and GATE:HYPOTHESIS records kept)')"
  add_progress_label
}

# ── status ───────────────────────────────────────────────────────────────────
if [ "$SUB" = "status" ]; then
  say "branch: $(git rev-parse --abbrev-ref HEAD) — $(git status --porcelain | grep -c . || true) dirty path(s)"
  found=0
  for n in $(state_issues); do
    found=1
    read_facts "$n"; rc=$?
    if [ "$rc" -eq 41 ]; then say "issue #$n: state file unreadable"; continue; fi
    print_facts "$n"
    [ "$n" = "$ISSUE" ] && print_cycle_detail "$n"
  done
  [ "$found" -eq 0 ] && say "state files: none"
  exit 0
fi

# ── review-response (the setup alone) ────────────────────────────────────────
if [ "$SUB" = "review-response" ]; then
  [ -f "$AF/issue-$ISSUE.json" ] || { echo "[$TAG] no state file for issue #$ISSUE" >&2; exit 64; }
  jq -e . "$AF/issue-$ISSUE.json" >/dev/null 2>&1 || { say "stop: $AF/issue-$ISSUE.json is unreadable"; exit 41; }
  dirty_stop
  say "mode: review-response"
  review_response_setup
  finish_ready
fi

# ── enter ────────────────────────────────────────────────────────────────────
# An interrupted cycle may have left work uncommitted: a resume reports the
# dirty paths as a fact. Every other mode starts from a clean tree.
if [ "$(jq -r '.active // false' "$AF/issue-$ISSUE.json" 2>/dev/null)" = "true" ]; then
  say "working tree: $(git status --porcelain | grep -c . || true) dirty path(s)"
else
  dirty_stop
fi
if ! git fetch --prune origin >/dev/null 2>&1; then
  say "stop: git fetch origin failed"
  exit 21
fi
DEFAULT="$(default_branch)"

# Prior-cycle resolution: every state file against its branch and its PR.
hold=""
stale_remote=""
own_state="absent"
for n in $(state_issues); do
  read_facts "$n"; rc=$?
  if [ "$rc" -eq 41 ]; then say "stop: $AF/issue-$n.json is unreadable — repair it"; exit 41; fi
  if [ "$rc" -eq 40 ]; then say "stop: the pull request lookup for issue #$n failed (gh)"; exit 40; fi
  print_facts "$n"
  if [ "$F_PR_STATE" = "MERGED" ] || [ "$F_PR_STATE" = "CLOSED" ]; then
    if [ "$(git rev-parse --abbrev-ref HEAD)" = "$F_BRANCH" ]; then
      git checkout --quiet "$DEFAULT" || { say "stop: cannot leave $F_BRANCH for $DEFAULT"; exit 21; }
    fi
    if has_local "$F_BRANCH"; then
      git branch -D "$F_BRANCH" >/dev/null 2>&1 && say "  cleared: local branch $F_BRANCH deleted"
    fi
    if has_remote "$F_BRANCH"; then
      say "  remote-branch-to-delete: $F_BRANCH"
      stale_remote="${stale_remote:+$stale_remote }$F_BRANCH"
    fi
    if out="$(bash "$SCRIPT_DIR/../cleanup/cleanup-issue.sh" "$n" 2>&1)"; then
      say "  cleared: $(printf '%s' "$out" | tail -1)"
    else
      say "stop: archiving issue #$n failed"
      printf '%s\n' "$out" | while IFS= read -r line; do say "  $line"; done
      exit 42
    fi
    continue
  fi
  if [ "$n" = "$ISSUE" ]; then
    own_state="present"
    OWN_ACTIVE="$F_ACTIVE"; OWN_PHASE="$F_PHASE"; OWN_CYCLE="$F_CYCLE"
    OWN_BRANCH="$F_BRANCH"; OWN_BRANCH_COUNT="$F_BRANCH_COUNT"; OWN_PR_STATE="$F_PR_STATE"; OWN_PR="$F_PR"
    continue
  fi
  if [ "$F_ACTIVE" = "true" ]; then
    hold="${hold:+$hold }#$n"
  elif [ "$F_BRANCH_COUNT" = "0" ]; then
    say "  pending: issue #$n has no dev branch on either side, so its pull request cannot be looked up — if it is merged or closed, archive it with scripts/cleanup/cleanup-issue.sh $n"
  elif [ -z "$F_PR" ]; then
    say "  pending: issue #$n is paused with no pull request — its files stay in place"
  fi
done

if [ -n "$hold" ]; then
  say "stop: another issue is mid-cycle ($hold) — one issue runs at a time"
  exit 10
fi

# A push is the orchestrator's own command, and the hook admits it only while
# no cycle is active — so the run stops here, before this issue's state is
# created or reactivated. A resume is already active: the deletion waits until
# the hook admits a push.
if [ -n "$stale_remote" ]; then
  if [ "$own_state" = "present" ] && [ "$OWN_ACTIVE" = "true" ]; then
    say "note: the remote branch(es) above cannot be deleted while this cycle is active (the hook gates every push) — delete them once it admits a push"
  else
    say "stop: a cleared cycle left its dev branch on the remote — delete each with 'git push origin --delete <branch>' and run this again"
    exit 12
  fi
fi

sync_default() {
  git checkout --quiet "$DEFAULT" || { say "stop: cannot check out $DEFAULT"; exit 21; }
  if ! git merge --quiet --ff-only "origin/$DEFAULT" >/dev/null 2>&1; then
    say "stop: $DEFAULT does not fast-forward to origin/$DEFAULT"
    exit 21
  fi
  say "sync: $DEFAULT at $(git rev-parse --short HEAD) (origin/$DEFAULT)"
}

checkout_dev() {
  git checkout --quiet "$1" 2>/dev/null || { say "stop: cannot check out $1"; exit 21; }
  if has_remote "$1" && ! git merge --quiet --ff-only "origin/$1" >/dev/null 2>&1; then
    say "stop: $1 does not fast-forward to origin/$1"
    exit 21
  fi
  say "sync: $1 at $(git rev-parse --short HEAD)"
}

if [ "$own_state" = "absent" ]; then
  say "mode: new-issue"
  left="$(branches_of "$ISSUE")"
  if [ -n "$left" ]; then
    say "stop: issue #$ISSUE has no state file but a dev branch exists ($(printf '%s' "$left" | tr '\n' ' ')) — delete a branch a merged or closed pull request left behind, then run this again"
    exit 22
  fi
  if [ -z "$TITLE" ]; then
    TITLE="$(gh issue view "$ISSUE" --json title -q .title 2>/dev/null)" || { say "stop: cannot read issue #$ISSUE (gh)"; exit 40; }
  fi
  sync_default
  run_bundle_checks
  run_local_checks 1
  BRANCH="dev/$(date +%Y-%m-%d)-issue-$ISSUE"
  git checkout --quiet -b "$BRANCH" "$DEFAULT" || { say "stop: cannot create $BRANCH"; exit 22; }
  say "branch: $BRANCH created from $DEFAULT"
  jq -n --arg issue "#$ISSUE" --arg title "$TITLE" --arg date "$(date +%Y-%m-%d)" --argjson t "$state_template_phases" \
    '{active: true, issue: $issue, title: $title, date: $date, cycle: 1, mode: "new-issue", phase: "in-progress", phases: $t}' \
    > "$AF/issue-$ISSUE.json"
  say "state: $AF/issue-$ISSUE.json created (cycle 1)"
  add_progress_label
  finish_ready
fi

if [ "$OWN_ACTIVE" != "true" ] && [ "$OWN_PHASE" = "awaiting-user" ]; then
  say "mode: paused"
  say "stop: issue #$ISSUE is paused for a human decision (phase=awaiting-user$([ -n "$OWN_PR" ] && echo ", pull request #$OWN_PR $OWN_PR_STATE")) — its .autoflow/issue-$ISSUE-* files carry the pending decision; nothing was changed"
  exit 11
fi

if [ "$OWN_BRANCH_COUNT" != "1" ]; then
  say "stop: the dev branch of issue #$ISSUE is $([ "$OWN_BRANCH_COUNT" = "0" ] && echo missing || echo ambiguous) — the cycle cannot be continued from this checkout"
  exit 22
fi

if [ "$OWN_ACTIVE" = "true" ]; then
  say "mode: resume"
  if [ "$(git rev-parse --abbrev-ref HEAD)" != "$OWN_BRANCH" ]; then
    git checkout --quiet "$OWN_BRANCH" 2>/dev/null || { say "stop: cannot check out $OWN_BRANCH from $(git rev-parse --abbrev-ref HEAD)"; exit 22; }
  fi
  say "branch: $OWN_BRANCH at $(git rev-parse --short HEAD)"
  F_CYCLE="$OWN_CYCLE"
  last="$(last_local_checks "$AF/issue-$ISSUE-ledger.md" "$OWN_CYCLE")"
  case "$last" in
    "none declared"|PASS\ *) say "local checks: last record of cycle $OWN_CYCLE — $last" ;;
    *) say "local checks: last record of cycle $OWN_CYCLE is \"$last\" — running them now"; run_local_checks "$OWN_CYCLE" ;;
  esac
  print_cycle_detail "$ISSUE"
  finish_ready
fi

if [ "$OWN_PR_STATE" = "OPEN" ]; then
  say "mode: review-response"
  say "pr: #$OWN_PR"
  checkout_dev "$OWN_BRANCH"
  # The local checks run inside the setup, on the next cycle's number.
  run_bundle_checks
  review_response_setup
  finish_ready
fi

say "mode: paused"
say "stop: issue #$ISSUE is inactive (phase=${OWN_PHASE:-unset}) with no open pull request — a pause for a human decision; its .autoflow/issue-$ISSUE-* files carry the pending decision; nothing was changed"
exit 11
