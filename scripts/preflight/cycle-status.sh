#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Apache-2.0
# =============================================================================
# Cycle status — the facts PREFLIGHT is decided from (ADR-0025 D8)
# =============================================================================
# Reads and reports. It changes nothing: no fetch, no checkout, no branch or
# file is created, moved or deleted, no state file is written, and nothing is
# sent to GitHub but reads. What is done with a fact — which attempt is
# cleared, how an interrupted attempt resumes — is the orchestrator's
# (docs/units/preparation.md); which attempt the requested issue enters, and
# how, follows from the facts alone and is printed as the `entry:` line.
#
# Records live under the record root (scripts/lib/records.sh, issue #466): an
# attempt — one run of an issue — has its directory
# `<record-root>/<repo-key>/<stamp>-issue-<N>/`, keyed by its dev branch
# `dev-<stamp>-issue-<N>` (`dev/<stamp>-issue-<N>` before issue #490), and
# belongs to the checkout its `checkout` file names.
#
# Reported:
#   - the working tree: the checked-out branch and its dirty paths
#   - the default branch against its remote-tracking ref, as of the last fetch
#   - the AutoFlow this run uses — the root this script runs from, the plugin
#     name and version its .claude-plugin/plugin.json names, and, when that
#     root is a git work tree of its own, its HEAD and whether it is dirty: the
#     plugin record PREFLIGHT writes to the ledger (ADR-0027 D4)
#   - the record root and this checkout
#   - a state file left in the checkout's own `.autoflow/` (before #466)
#   - per attempt of this repository not yet marked completed: its owner
#     (`this`, `other <path>` — a checkout still there — or `gone <path>`),
#     its state (`active`, `phase`, `mode`, `cycle`, or `none` — no state
#     file: in its criterion review stage, ready to start, or on the
#     abbreviated path), its dev branch with each side and, for a state file
#     that is not active or no state file, its pull request
#   - `cleanup:` per attempt of this checkout whose pull request is merged or
#     closed — the Post-Merge Cleanup it is owed
#   - with --issue N: `criterion:` for each attempt of N with no state file
#     this checkout could start; each dev branch carrying N's number with no
#     attempt record (`record=none`, issue #433); for the attempt the entry
#     names, each gate's recorded scores (count, min, avg), `verdict` and
#     `remedy_class`, the artifacts in its directory, the ledger's last attempt
#     markers and the last local-checks record of the current cycle; and the
#     `entry:` line
#
# The entry (issues #466 AC3, #465), evaluated in order:
#   stop in-tree-records   a state file is still in the checkout's .autoflow/
#   hold <key>             another issue's attempt of this checkout is active
#   stop multiple-active   this checkout has two or more active attempts
#   resume <key>           this checkout's attempt of N is active
#   on the checked-out branch, when it is an attempt of N — taken over first
#   (`claim <key>`) when its checkout is gone:
#     stop other-checkout <key>   its checkout is still there
#     start <key>                 no state file, criterion READY, no pull
#                                 request
#     criterion-review <key>      no state file, criterion NOT READY — the
#                                 attempt's criterion review stage runs
#     abbreviated <key>           no state file, criterion READY, an open
#                                 pull request — on the abbreviated path,
#                                 which the full cycle does not enter
#     review-response <key>       not active, an open pull request
#     paused <key>                not active, awaiting-user or no open PR
#   otherwise, among this checkout's attempts of N (cleared ones aside):
#     start / criterion-review / review-response <key>
#                                     exactly one is ready to start, still in
#                                     its criterion review stage, or has a
#                                     state file and an open pull request
#     stop candidates <key> …         two or more — check one's dev branch out
#     none-to-enter <key>:<kind> …    none of those, but attempts of N are
#                                     still here (paused, abbreviated, or a
#                                     fact unread)
#     new                             no attempt of N left — a new attempt
#                                     may be made (autoflow-records new)
# These are facts. What the session does with them — a new attempt the
# operator asked for (`new`), a claim, a dirty tree, an unread fact — is its
# judgment (docs/units/preparation.md > Modes).
#
# Exit codes:
#   0   every fact was read
#   3   a fact could not be read — a `gh` lookup failed, a state file is not
#       JSON, or the AutoFlow root's plugin.json could not be read; the line
#       that reports it says which
#   7   the record root is undetermined or unusable — the marker line
#       `record-root: UNDETERMINED …` / `record-root: UNUSABLE …` says why;
#       no attempt is read and no entry is printed
#   64  usage
#
# Usage: scripts/preflight/cycle-status.sh [--issue N]
# =============================================================================

set -uo pipefail

TAG="cycle-status"
ISSUE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --issue) [ $# -ge 2 ] || { echo "Usage: $0 [--issue N]" >&2; exit 64; }; ISSUE="${2#\#}"; shift 2 ;;
    -h|--help) echo "Usage: $0 [--issue N]"; exit 0 ;;
    *) echo "[$TAG] unknown argument: $1" >&2; echo "Usage: $0 [--issue N]" >&2; exit 64 ;;
  esac
done
case "$ISSUE" in
  *[!0-9]*) echo "[$TAG] --issue takes an issue number: $ISSUE" >&2; exit 64 ;;
esac

SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "[$TAG] not inside a git repository" >&2; exit 64; }
cd "$ROOT" || exit 64
# shellcheck source=scripts/lib/records.sh
. "$SELF_DIR/../lib/records.sh"
TOP="$(af_checkout_top "$ROOT")"
KEY="$(autoflow_repo_key "$ROOT")"
incomplete=0

# "<number> <STATE> <url>" of the branch's pull request (an open one when there
# is one, otherwise the most recently updated), or empty. `gh pr list --head`
# also lists a fork's pull request whose branch has the same name, so only one
# gh reports as opened from this repository counts.
pr_of() {
  local out
  out="$(gh pr list --head "$1" --state all --limit 30 --json number,state,url,updatedAt,isCrossRepository 2>/dev/null)" || return 1
  printf '%s' "$out" | jq -r 'map(select(.isCrossRepository == false)) | sort_by(.updatedAt) | ((map(select(.state == "OPEN")) | last) // last) | if . == null then "" else "\(.number) \(.state) \(.url)" end'
}
side() { if git show-ref --verify --quiet "$1"; then echo yes; else echo no; fi; }

# The result line of the last `### preflight-local-checks | cycle: <C>` record.
last_local_checks() {
  [ -f "$1" ] || { echo "none"; return; }
  awk -v c="$2" '
    $0 == "### preflight-local-checks | cycle: " c { want = 1; next }
    want && /^- result: / { sub(/^- result: (PREFLIGHT local checks: )?/, ""); last = $0; want = 0 }
    END { print (last == "" ? "none" : last) }' "$1"
}

report_detail() {  # <attempt dir> <issue> <cycle> — what a resume is judged from
  local d="$1" n="$2" f m
  local led="$d/issue-$n-ledger.md"
  echo "  gates:"
  jq -r '
    def num: if type == "object" then .score else . end;
    (.phases // {}) | to_entries[] |
    "    \(.key): " +
    ( (.value.scores // {}) as $s
      | if ($s | length) == 0 then "no scores"
        else ([$s[] | num]) as $v | "scores=\($v | length) min=\($v | min) avg=\(($v | add) / ($v | length) * 100 | round / 100)" end )
    + (if .value.verdict != null and .value.verdict != "" then " verdict=\"\(.value.verdict)\"" else "" end)
    + (if .value.remedy_class != null then " remedy_class=\(.value.remedy_class)" else "" end)
  ' "$d/issue-$n.json" 2>/dev/null
  echo "  artifacts:"
  for f in "$d"/issue-"$n"-*; do
    [ -e "$f" ] || continue
    case "${f##*/}" in issue-"$n"-c[0-9]*-*) continue ;; esac
    echo "    ${f##*/}"
  done
  if [ -f "$led" ]; then
    echo "  ledger markers (last of each):"
    for m in gate-autofix rebuttal review-autofix reentry-decision; do
      grep -n -E "^## .*\[$m\][[:space:]]*$" "$led" | tail -1 | sed 's/^/    /'
    done
    echo "  last local-checks record (cycle $3): $(last_local_checks "$led" "$3")"
  else
    echo "  ledger: none"
  fi
}

dirty="$(git status --porcelain)"
BRANCH="$(git symbolic-ref --quiet --short HEAD 2>/dev/null)" || BRANCH=""
echo "working tree: branch ${BRANCH:-(detached HEAD)}, $(printf '%s' "$dirty" | grep -c . || true) dirty path(s)"
[ -n "$dirty" ] && printf '%s\n' "$dirty" | sed 's/^/  /'

DEFAULT="$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null)" || DEFAULT="origin/main"
DEFAULT="${DEFAULT#origin/}"
if git show-ref --verify --quiet "refs/heads/$DEFAULT" && git show-ref --verify --quiet "refs/remotes/origin/$DEFAULT"; then
  echo "default branch: $DEFAULT at $(git rev-parse --short "$DEFAULT"), origin/$DEFAULT at $(git rev-parse --short "origin/$DEFAULT") as of the last fetch — ahead $(git rev-list --count "origin/$DEFAULT..$DEFAULT"), behind $(git rev-list --count "$DEFAULT..origin/$DEFAULT")"
elif git show-ref --verify --quiet "refs/remotes/origin/$DEFAULT"; then
  echo "default branch: $DEFAULT — no local branch; origin/$DEFAULT at $(git rev-parse --short "origin/$DEFAULT") as of the last fetch"
else
  echo "default branch: $DEFAULT — no local branch or no remote-tracking ref"
fi

# The AutoFlow this run uses: the root this script runs from is the root the
# session loaded (ADR-0027 D3), which `claude plugin list` does not show for a
# `--plugin-dir` session. Read from the root, never from the target.
AF_ROOT="$(cd "$SELF_DIR/../.." && pwd)"
af_plugin="$(jq -r '"\(.name) \(.version)"' "$AF_ROOT/.claude-plugin/plugin.json" 2>/dev/null)" || af_plugin=""
echo "autoflow root: $AF_ROOT"
if [ -n "$af_plugin" ]; then
  echo "  plugin: $af_plugin"
else
  echo "  plugin: unreadable ($AF_ROOT/.claude-plugin/plugin.json)"; incomplete=1
fi
af_top="$(git -C "$AF_ROOT" rev-parse --show-toplevel 2>/dev/null)" || af_top=""
if [ -n "$af_top" ] && [ "$(cd "$af_top" && pwd -P)" = "$(cd "$AF_ROOT" && pwd -P)" ]; then
  af_dirty="$(git -C "$AF_ROOT" status --porcelain 2>/dev/null | grep -c .)"
  if [ "$af_dirty" -eq 0 ]; then af_state=clean; else af_state="dirty ($af_dirty path(s))"; fi
  echo "  git: $(git -C "$AF_ROOT" rev-parse HEAD 2>/dev/null) $af_state"
else
  echo "  git: not a git work tree"
fi

if ! af_record_root "$TOP"; then
  af_record_root_marker
  exit "$AF_RECORD_ROOT_EXIT"
fi
R="$AF_RECORD_ROOT"
echo "record root: $R"
echo "checkout: $TOP (repository key $KEY)"

# A state file in the checkout's own .autoflow/ is a cycle recorded before the
# record root (issue #466): it is moved to the record root before anything else.
legacy=""
for f in .autoflow/*-issue-*/issue-*.json; do
  [ -f "$f" ] || continue
  n="${f##*/issue-}"; n="${n%.json}"
  case "$n" in ''|*[!0-9]*) continue ;; esac
  dn="${f%/*}"; dn="${dn##*/}"
  case "$dn" in *-issue-"$n") ;; *) continue ;; esac
  legacy="${legacy:+$legacy }$f"
done
if [ -n "$legacy" ]; then echo "in-tree state files: $legacy"; else echo "in-tree state files: none"; fi

# ── Attempts of this repository ──
# Parallel arrays, one slot per attempt not marked completed.
A_KEY=(); A_BRANCH=(); A_ISSUE=(); A_DIR=(); A_OWN=(); A_OWNER=(); A_STATE=(); A_ACTIVE=(); A_PHASE=(); A_CYCLE=(); A_PR=()
completed=0
for d in "$R/$KEY"/*-issue-*; do
  [ -d "$d" ] || continue
  k="${d##*/}"
  af_attempt_key "dev-$k" >/dev/null || continue
  if [ -e "$d/completed" ]; then completed=$((completed + 1)); continue; fi
  n="$(af_attempt_issue "$k")"
  owner=""
  [ -f "$d/checkout" ] && { IFS= read -r owner < "$d/checkout" || true; }
  if [ "$owner" = "$TOP" ]; then own=this
  elif af_checkout_live "$owner" "$KEY"; then own=other
  else own=gone; fi
  st=none; act=""; ph=""; cy=""
  if [ -f "$d/issue-$n.json" ]; then
    if jq -e . "$d/issue-$n.json" >/dev/null 2>&1; then
      st=file
      act="$(jq -r '.active // false' "$d/issue-$n.json")"
      ph="$(jq -r '.phase // "unset"' "$d/issue-$n.json")"
      cy="$(jq -r '.cycle // 1' "$d/issue-$n.json")"
    else
      st=unreadable; incomplete=1
    fi
  fi
  A_KEY+=("$k"); A_BRANCH+=("$(af_attempt_branch "$d")"); A_ISSUE+=("$n"); A_DIR+=("$d"); A_OWN+=("$own"); A_OWNER+=("$owner")
  A_STATE+=("$st"); A_ACTIVE+=("$act"); A_PHASE+=("$ph"); A_CYCLE+=("$cy"); A_PR+=("")
done

# The pull request of an attempt whose state file is not active, or that has no
# state file — looked up for this checkout's attempts (cleanup) and for every
# attempt of the requested issue (its entry).
i=0
while [ "$i" -lt "${#A_KEY[@]}" ]; do
  if { [ "${A_STATE[$i]}" = none ] || { [ "${A_STATE[$i]}" = file ] && [ "${A_ACTIVE[$i]}" != true ]; }; } \
     && { [ "${A_OWN[$i]}" = this ] || [ "${A_ISSUE[$i]}" = "$ISSUE" ]; }; then
    if line="$(pr_of "${A_BRANCH[$i]}")"; then
      A_PR[$i]="${line:-none}"
    else
      A_PR[$i]="lookup-failed"; incomplete=1
    fi
  fi
  i=$((i + 1))
done

pr_state() { local p="${A_PR[$1]}"; case "$p" in ''|none|lookup-failed) printf '%s' "$p" ;; *) p="${p#* }"; printf '%s' "${p%% *}" ;; esac; }

i=0
[ "${#A_KEY[@]}" -eq 0 ] && echo "attempts: none"
while [ "$i" -lt "${#A_KEY[@]}" ]; do
  k="${A_KEY[$i]}"; b="${A_BRANCH[$i]}"
  case "${A_OWN[$i]}" in
    this)  ow="this" ;;
    other) ow="other ${A_OWNER[$i]}" ;;
    gone)  ow="gone ${A_OWNER[$i]:-(no checkout recorded)}" ;;
  esac
  case "${A_STATE[$i]}" in
    none) sd="none (no state file — its criterion review stage, ready to start, or on the abbreviated path)" ;;
    unreadable) sd="unreadable (${A_DIR[$i]}/issue-${A_ISSUE[$i]}.json)" ;;
    file) sd="active=${A_ACTIVE[$i]} phase=${A_PHASE[$i]} mode=$(jq -r '.mode // "unset"' "${A_DIR[$i]}/issue-${A_ISSUE[$i]}.json") cycle=${A_CYCLE[$i]}" ;;
  esac
  echo "attempt $k (issue #${A_ISSUE[$i]}): owner=$ow state=$sd"
  echo "  dir: ${A_DIR[$i]}"
  echo "  branch: $b (local=$(side "refs/heads/$b") origin=$(side "refs/remotes/origin/$b"))"
  case "${A_PR[$i]}" in
    '') ;;
    none) echo "    pr: none" ;;
    lookup-failed) echo "    pr: lookup failed" ;;
    *) echo "    pr: #${A_PR[$i]}" ;;
  esac
  i=$((i + 1))
done
[ "$completed" -gt 0 ] && echo "completed attempts: $completed"

# Post-Merge Cleanup owed: this checkout's attempts whose pull request is merged
# or closed. An attempt whose checkout is gone is not cleared from here — it is
# taken over first (issue #466 AC4).
CLEARED=" "
i=0
while [ "$i" -lt "${#A_KEY[@]}" ]; do
  if [ "${A_OWN[$i]}" = this ]; then
    case "$(pr_state "$i")" in
      MERGED|CLOSED) echo "cleanup: ${A_KEY[$i]} branch ${A_BRANCH[$i]} (pr #${A_PR[$i]%% *} $(pr_state "$i"))"; CLEARED="$CLEARED${A_KEY[$i]} " ;;
    esac
  fi
  i=$((i + 1))
done

[ -n "$ISSUE" ] || { [ "$incomplete" -eq 0 ] || exit 3; exit 0; }

# ── The requested issue ──
# A dev branch carrying the issue's number with no attempt record is not an
# attempt: reported, never deleted (issue #433).
{
  git for-each-ref --format='%(refname:lstrip=2)' "refs/heads/dev/*-issue-$ISSUE" "refs/heads/dev-*-issue-$ISSUE"
  git for-each-ref --format='%(refname:lstrip=3)' "refs/remotes/origin/dev/*-issue-$ISSUE" "refs/remotes/origin/dev-*-issue-$ISSUE"
} | sort -u | while IFS= read -r b; do
  [ -n "$b" ] || continue
  k="$(af_attempt_key "$b")" && [ -d "$R/$KEY/$k" ] && continue
  echo "dev branch with no attempt record: $b (local=$(side "refs/heads/$b") origin=$(side "refs/remotes/origin/$b")) record=none"
done

entry=""
entry_slot=""
claim=""
emit_entry() { entry="$1"; entry_slot="${2:-}"; }

# kind_of <slot> — how an attempt of N would be entered, cleared ones aside.
kind_of() {
  local i="$1"
  case "${A_STATE[$i]}" in
    unreadable) echo unreadable; return ;;
    none)
      case "$(pr_state "$i")" in MERGED|CLOSED) echo cleared; return ;; esac
      case "${CRIT[$i]:-}" in
        NOT-READY) echo criterion-review ;;
        READY) case "$(pr_state "$i")" in OPEN) echo abbreviated ;; none) echo start ;; *) echo unread ;; esac ;;
        *) echo unread ;;
      esac
      return ;;
  esac
  if [ "${A_ACTIVE[$i]}" = true ]; then echo resume; return; fi
  case "$(pr_state "$i")" in
    MERGED|CLOSED) echo cleared; return ;;
    lookup-failed) echo unread; return ;;
  esac
  if [ "${A_PHASE[$i]}" != awaiting-user ] && [ "$(pr_state "$i")" = OPEN ]; then echo review-response; else echo paused; fi
}

active_own=(); i=0
while [ "$i" -lt "${#A_KEY[@]}" ]; do
  [ "${A_OWN[$i]}" = this ] && [ "${A_ACTIVE[$i]}" = true ] && active_own+=("$i")
  i=$((i + 1))
done

branch_slot=""
if k="$(af_attempt_key "$BRANCH")"; then
  i=0
  while [ "$i" -lt "${#A_KEY[@]}" ]; do
    [ "${A_KEY[$i]}" = "$k" ] && [ "${A_ISSUE[$i]}" = "$ISSUE" ] && branch_slot="$i"
    i=$((i + 1))
  done
fi

# Criterion readiness of every attempt of N with no state file that this
# checkout could start — its own, or the one on the checked-out branch.
CRIT=()
i=0
while [ "$i" -lt "${#A_KEY[@]}" ]; do
  if [ "${A_ISSUE[$i]}" = "$ISSUE" ] && [ "${A_STATE[$i]}" = none ] && { [ "${A_OWN[$i]}" = this ] || [ "$i" = "$branch_slot" ]; }; then
    out="$(bash "$SELF_DIR/criterion-ready.sh" status --issue "$ISSUE" --branch "${A_BRANCH[$i]}" 2>&1)"
    case "$?" in
      0) CRIT[$i]=READY ;;
      1) CRIT[$i]=NOT-READY ;;
      *) CRIT[$i]=UNREAD; incomplete=1 ;;
    esac
    echo "criterion: ${A_KEY[$i]} — $(printf '%s' "$out" | tail -1)"
  fi
  i=$((i + 1))
done

if [ -n "$legacy" ]; then
  emit_entry "stop in-tree-records — move them to the record root first ($AF_ROOT/scripts/migrate/migrate-in-tree-records.sh)"
elif [ "${#active_own[@]}" -ge 2 ]; then
  emit_entry "stop multiple-active — this checkout has $(for s in "${active_own[@]}"; do printf '%s ' "${A_KEY[$s]}"; done)active; one attempt runs at a time in a checkout"
elif [ "${#active_own[@]}" -eq 1 ] && [ "${A_ISSUE[${active_own[0]}]}" != "$ISSUE" ]; then
  emit_entry "hold ${A_KEY[${active_own[0]}]} — issue #${A_ISSUE[${active_own[0]}]}'s attempt is active in this checkout (PR Wait Rule)" "${active_own[0]}"
elif [ "${#active_own[@]}" -eq 1 ]; then
  emit_entry "resume ${A_KEY[${active_own[0]}]}" "${active_own[0]}"
elif [ -n "$branch_slot" ] && [ "${A_OWN[$branch_slot]}" = other ]; then
  emit_entry "stop other-checkout ${A_KEY[$branch_slot]} — it belongs to ${A_OWNER[$branch_slot]}, which is still there; it is entered from that checkout" "$branch_slot"
elif [ -n "$branch_slot" ] && [ "$(kind_of "$branch_slot")" != cleared ]; then
  [ "${A_OWN[$branch_slot]}" = gone ] && claim="${A_KEY[$branch_slot]}"
  kd="$(kind_of "$branch_slot")"
  case "$kd" in
    start) emit_entry "start ${A_KEY[$branch_slot]}" "$branch_slot" ;;
    criterion-review) emit_entry "criterion-review ${A_KEY[$branch_slot]} — no [criterion-ready] entry for the current issue body; the attempt's criterion review stage runs on this branch" "$branch_slot" ;;
    abbreviated) emit_entry "abbreviated ${A_KEY[$branch_slot]} — no state file and an open pull request: the attempt is on the abbreviated path, which the full cycle does not enter" "$branch_slot" ;;
    review-response) emit_entry "review-response ${A_KEY[$branch_slot]}" "$branch_slot" ;;
    paused) emit_entry "paused ${A_KEY[$branch_slot]} — report its pending decision" "$branch_slot" ;;
    resume) emit_entry "resume ${A_KEY[$branch_slot]}" "$branch_slot" ;;
    *) emit_entry "stop unreadable ${A_KEY[$branch_slot]} — a fact of it could not be read" "$branch_slot" ;;
  esac
else
  # `new` only when no attempt of N is left: one still here is named, and a new
  # attempt beside it is the operator's explicit request (preparation.md > Modes).
  cands=(); left=(); i=0
  while [ "$i" -lt "${#A_KEY[@]}" ]; do
    if [ "${A_ISSUE[$i]}" = "$ISSUE" ] && [ "${A_OWN[$i]}" = this ]; then
      case "$(kind_of "$i")" in
        start|criterion-review|review-response) cands+=("$i") ;;
        cleared) ;;
        *) left+=("$i") ;;
      esac
    fi
    i=$((i + 1))
  done
  if [ "${#cands[@]}" -eq 1 ] && [ "$(kind_of "${cands[0]}")" = criterion-review ]; then
    emit_entry "criterion-review ${A_KEY[${cands[0]}]} — no [criterion-ready] entry for the current issue body; its dev branch is checked out and the attempt's criterion review stage runs on it" "${cands[0]}"
  elif [ "${#cands[@]}" -eq 1 ]; then
    emit_entry "$(kind_of "${cands[0]}") ${A_KEY[${cands[0]}]}" "${cands[0]}"
  elif [ "${#cands[@]}" -ge 2 ]; then
    emit_entry "stop candidates $(for s in "${cands[@]}"; do printf '%s ' "${A_KEY[$s]}"; done)— check one attempt's dev branch out to name it"
  elif [ "${#left[@]}" -ge 1 ]; then
    emit_entry "none-to-enter $(for s in "${left[@]}"; do printf '%s:%s ' "${A_KEY[$s]}" "$(kind_of "$s")"; done)— attempts of #$ISSUE still in this checkout, none ready to start, in a criterion review stage or with a cycle's open pull request"
  else
    emit_entry "new — no attempt of issue #$ISSUE is left in this checkout"
  fi
fi

if [ -n "$entry_slot" ] && [ "${A_STATE[$entry_slot]}" = file ]; then
  echo "detail: ${A_KEY[$entry_slot]}"
  report_detail "${A_DIR[$entry_slot]}" "${A_ISSUE[$entry_slot]}" "${A_CYCLE[$entry_slot]}"
fi
[ -n "$claim" ] && echo "claim: $claim — its checkout is gone; this checkout takes it over (autoflow-records claim) before entering"
echo "entry: $entry"

[ "$incomplete" -eq 0 ] || exit 3
exit 0
