#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# scripts/handoff/confirm-ci-green.sh
#
# HANDOFF step 5 — deterministic "confirm CI is green" helper.
#
# Promotes the topology-independent step-5 invariant from prose
# (docs/autoflow-guide.md step 5) into a single enforceable invocation so the
# orchestrator never hand-writes a polling loop again (issue #25). It reads
# `mergeable`/`mergeStateStatus` FIRST and early-exits on CONFLICTING/DIRTY
# WITHOUT ever entering a poll (the PR #321 infinite-wait class); only when the
# PR is MERGEABLE/CLEAN does it run a finite, deadline-bounded poll that
# distinguishes "green" from "0 checks published" (webhook / scan-fallback
# suspect), "red build", and "still-pending at timeout" (slow CI) via layered
# exit codes — never reading a clean-but-empty status as green.
#
# Observe-only: it performs no merge, no CI re-trigger, and no conflict
# resolution. Conflict *resolution* stays topology-specific and lives in the
# docs (gitlink reconcile → docs/external-review-sequencing.md; other conflict
# → rebase origin/main). This script owns only the *confirmation*.
#
# Usage:
#   scripts/handoff/confirm-ci-green.sh --pr <N> [--repo <owner/name>]
#
# Options:
#   --pr <N>            Required. PR number to confirm. Non-numeric/missing -> exit 64.
#   --repo <owner/name> Optional. Forwarded to every `gh pr view` call (cross-repo
#                       selector, mirrors scripts/review/codex-review-pr.sh).
#                       Omitted => the current repository (host PR). The
#                       superseded-run lookup (`gh api .../actions/runs/<id>`,
#                       issue #274) names its repository from the check's
#                       detailsUrl instead.
#   -h | --help         Usage to stdout, exit 0.
#
# Tunables (env vars — the Approach-5 timeout / reconfirm policy as parameters):
#   CI_POLL_TIMEOUT_SECS   (default 900) Total finite poll budget (deadline).
#                          Generous so a normally-slow CI build is not clipped.
#   CI_POLL_INTERVAL_SECS  (default 20)  Sleep between poll iterations — also
#                          caps the one-shot precheck read (pre_bound =
#                          min(CI_POLL_INTERVAL_SECS, remaining-to-deadline)).
#   Both validated as non-negative integers; non-numeric -> exit 64.
#
# Exit-code contract (feature §4):
#   0   CI green         — >=1 check present and every element green.
#   10  not mergeable    — a CONFIRMED CONFLICTING/DIRTY value at precheck OR on
#                          a mid-poll flip; stderr carries the reserved
#                          [HANDOFF-INTERNAL-RETRY] token. No poll on precheck.
#                          Only on a JSON-confirmed read; a failed/timed-out/
#                          empty/non-JSON read — at the precheck OR mid-poll —
#                          falls through to the bounded poll (or, mid-poll, to a
#                          retry within the budget), never 10.
#   Undetermined mergeability: a still-computing UNKNOWN is an uncertain read
#   that falls through to the bounded poll, never 10. Both fields are read:
#   an UNKNOWN mergeStateStatus is unsettled and never confirms, even beside
#   a MERGEABLE value.
#   11  0 checks         — MERGEABLE but no check ever published within the bound.
#   12  red build        — a check concluded FAILURE/ERROR/CANCELLED/TIMED_OUT.
#                          A CANCELLED check of a run superseded by a newer run of
#                          the same workflow is not counted (drop_superseded_runs).
#   13  no green verdict  — checks present but the run never reached the exit-0
#                          verdict at the deadline. THREE cases land here: checks
#                          still pending (slow CI); the confirmed-then-
#                          undetermined case — mergeability was confirmed once
#                          (so it is not 14) and the rollup is already
#                          all-green, but mergeability never re-settled before
#                          the deadline, and exit 0 is contracted as "green on
#                          a PR whose mergeable state was confirmed", so the
#                          undetermined arm withholds it; and an all-green
#                          rollup whose superseded-run lookup (issue #274) never
#                          resolved every candidate run's workflow, which
#                          withholds exit 0 the same way.
#   14  inconclusive     — could not confirm mergeable within the bound; gh
#                          transport/auth/parse failure, or a mergeability that
#                          never settled within the bound, suspected (NOT a
#                          conflict); bounded; stderr carries the reserved
#                          [HANDOFF-INTERNAL-RETRY] token. NOT green.
#   64  usage / bad arg / bad env int.
#
# `set -uo pipefail` (not -e): the poll intentionally tolerates a transient
# `gh` non-zero within the budget rather than crashing.
# =============================================================================

set -uo pipefail

usage() {
  echo "usage: $0 --pr <N> [--repo <owner/name>]" >&2
}

PR=""
REPO=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --pr)
      [ "$#" -ge 2 ] || { echo "missing value for --pr" >&2; usage; exit 64; }
      PR="$2"; shift 2 ;;
    --repo)
      [ "$#" -ge 2 ] || { echo "missing value for --repo" >&2; usage; exit 64; }
      REPO="$2"; shift 2 ;;
    -h|--help) echo "usage: $0 --pr <N> [--repo <owner/name>]"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; usage; exit 64 ;;
  esac
done

# --pr required and numeric.
case "$PR" in
  ''|*[!0-9]*) usage; exit 64 ;;
esac

# Env tunables: default when unset/empty, then validate as non-negative ints.
CI_POLL_TIMEOUT_SECS="${CI_POLL_TIMEOUT_SECS:-900}"
CI_POLL_INTERVAL_SECS="${CI_POLL_INTERVAL_SECS:-20}"
case "$CI_POLL_TIMEOUT_SECS" in ''|*[!0-9]*) echo "CI_POLL_TIMEOUT_SECS must be a non-negative integer" >&2; exit 64 ;; esac
case "$CI_POLL_INTERVAL_SECS" in ''|*[!0-9]*) echo "CI_POLL_INTERVAL_SECS must be a non-negative integer" >&2; exit 64 ;; esac
[ "$CI_POLL_INTERVAL_SECS" -lt 1 ] && CI_POLL_INTERVAL_SECS=1

# --repo forwarded to every gh call when provided.
REPO_ARGS=()
[ -n "$REPO" ] && REPO_ARGS=(--repo "$REPO")

# Bounded execution (feature D3 / DCR-5): prefer timeout/gtimeout, else a
# sleep+kill watchdog (holds on macOS with no GNU timeout — the incident box).
# Captures the command's stdout to $2 (a tempfile, NOT a $(...) subshell — a
# subshell would lose the RC/TIMED_OUT globals; ledger E14). Sets GH_RC and
# GH_TIMED_OUT (1 iff the watchdog fired). Used for the precheck and per
# in-loop `gh` round-trip so a hung call (stalled network / no-TTY auth
# prompt) is killed and control returns for the deadline re-test.
gh_bounded() {
  local bound="$1" outfile="$2"; shift 2
  GH_TIMED_OUT=0
  local tbin=""
  if command -v timeout >/dev/null 2>&1; then
    tbin="timeout"
  elif command -v gtimeout >/dev/null 2>&1; then
    tbin="gtimeout"
  fi
  if [ -n "$tbin" ]; then
    "$tbin" "$bound" "$@" >"$outfile" 2>/dev/null
    GH_RC=$?
    [ "$GH_RC" -eq 124 ] && GH_TIMED_OUT=1
    return 0
  fi
  local marker; marker="$(mktemp)"
  set -m
  "$@" >"$outfile" 2>/dev/null </dev/null &
  local pid=$!
  ( sleep "$bound"
    if kill -0 "$pid" 2>/dev/null; then
      echo fired >"$marker"
      kill -TERM -"$pid" 2>/dev/null || kill "$pid" 2>/dev/null
    fi
  ) >/dev/null 2>&1 &
  local wpid=$!
  set +m
  wait "$pid" 2>/dev/null
  GH_RC=$?
  if [ -s "$marker" ]; then
    GH_TIMED_OUT=1
  else
    kill -TERM -"$wpid" 2>/dev/null || kill "$wpid" 2>/dev/null
  fi
  wait "$wpid" 2>/dev/null
  rm -f "$marker" 2>/dev/null
  return 0
}

# Classify a poll body's statusCheckRollup into "<total> <fail> <green>", one row
# per check identity. A same-identity group with ANY non-terminal (QUEUED/PENDING/
# WAITING/in-progress) entry is pending outright — a stale CANCELLED/FAILURE left by
# a concurrency-cancelled run must not outvote the live replacement run on timestamp
# recency (real CheckRun rollup objects carry no createdAt, so a timestamp key cannot
# rank a null-timestamp replacement above a completed stale entry). Narrowed (c4 §3.3):
# that non-terminal veto is overridden only when a terminal entry is strictly newer, by a
# comparable run-start timestamp (startedAt/createdAt), than EVERY non-terminal sibling
# (each of which must itself carry a comparable run-start) — then the terminal represents
# the group; otherwise the non-terminal-wins pending behavior stands. Timestamp order
# (with a fail-safe non-green tie-break) selects the representative only WITHIN an
# all-terminal group by latest-per-identity dedup (feature #30 c2 §3 / c4 §3.3).
classify_rollup() {
  jq -r '
    def ident:
      if .__typename == "CheckRun" and ((.name // "") != "") then
        ["CheckRun", (.workflowName // ""), .name]
      elif .__typename == "StatusContext" and ((.context // "") != "") then
        ["StatusContext", .context]
      else
        ["RAW", tojson]
      end;
    def green_entry:
      (.__typename == "CheckRun" and (.conclusion | IN("SUCCESS","NEUTRAL","SKIPPED")))
      or (.__typename == "StatusContext" and (.state == "SUCCESS"));
    def fail_entry:
      (.__typename == "CheckRun" and (.conclusion | IN("FAILURE","ERROR","CANCELLED","TIMED_OUT")))
      or (.__typename == "StatusContext" and (.state | IN("FAILURE","ERROR")));
    def non_terminal:
      (.__typename == "CheckRun" and (.conclusion == null))
      or (.__typename == "StatusContext" and (.state | IN("PENDING","EXPECTED")));
    def ts_key: [ .startedAt // "", .completedAt // "", .createdAt // "" ];
    def start_key: [ .startedAt // "", .createdAt // "" ];
    def tie_key: ts_key + [ (if green_entry then 0 else 1 end) ];
    def has_start:
      if .__typename == "CheckRun" then (.startedAt // "") != ""
      else (.createdAt // "") != "" end;
    ( .statusCheckRollup // [] )
    | group_by(ident)
    | map(
        ( [ .[] | select(non_terminal) ] ) as $nt
        | ( [ .[] | select(non_terminal | not) ] ) as $tm
        | if ($nt | length) == 0 then
            max_by(tie_key)
          elif ($tm | length) > 0
               and ([ $nt[] | has_start ] | all)
               and (($tm | max_by(start_key) | start_key) > ($nt | max_by(start_key) | start_key))
          then
            ( $tm | max_by(tie_key) )
          else
            ( $nt | max_by(ts_key) )
          end
      ) as $r
    | ($r | length) as $t
    | ([ $r[] | select(fail_entry) ] | length) as $f
    | ([ $r[] | select(green_entry) ] | length) as $g
    | "\($t) \($f) \($g)"
  ' 2>/dev/null
}

# Superseded-run filter (issue #274), a pre-pass over the poll body whose output
# classify_rollup above reads unchanged: a CANCELLED CheckRun of a SUPERSEDED run
# is dropped from statusCheckRollup. A run is superseded when the rollup carries
# a newer run of the SAME WORKFLOW — the run read from detailsUrl
# (.../<owner>/<repo>/actions/runs/<run_id>/job/<job_id>), "newer" meaning a
# larger run_id (GitHub assigns run ids in creation order), and the workflow
# being the run's workflow_id from the Actions run API, never the workflowName
# display name, which two workflow files may share. The rollup is the PR head
# commit's, so the newer run is on the same head SHA. This covers the cancelled
# row whose name the replacement never repeats — a matrix job cancelled before
# expansion stays "Tests (shard ${{ matrix.shard }})" while the replacement
# expands to "Tests (shard 1)" — which classify_rollup's identity dedup leaves
# alone in its group and counts red. Only CANCELLED is dropped: a FAILURE/ERROR/
# TIMED_OUT row of a superseded run, a CANCELLED row of a workflow's newest run,
# and a row whose run cannot be read from detailsUrl (a non-Actions check) are
# classified as before.
#
# The lookup is narrowed to the candidate runs — every run of a workflowName that
# carries a CANCELLED row of a non-newest run, since two runs of one workflow share
# its display name on one head SHA — so a rollup with no such row issues no call.
# Each lookup is one read-only, bounded `gh api` GET inside the poll deadline, and
# a resolved run is cached for the script's lifetime (a run's workflow never
# changes). While any candidate is unresolved (failed / timed-out lookup), the
# drop falls back to the display-name rule for the red count only and the exit-0
# verdict is withheld (RUN_WF_COMPLETE=0): an unresolved lookup can delay green,
# never grant it, and never turn a lookup failure into a false red.
RUN_REF_JQ='
  def run_ref:
    if .__typename == "CheckRun" and ((.workflowName // "") != "") then
      [ (.detailsUrl // "")
        | capture("^https?://(?<host>[^/]+)/(?<repo>[^/]+/[^/]+)/actions/runs/(?<id>[0-9]+)") ]
      | first
    else
      null
    end;
  def run_num: run_ref | if . == null then null else (.id | tonumber) end;
  def latest_run_by(f):
    reduce ( .[] | run_num as $n | select($n != null) | [ f, $n ] | select(.[0] != null) ) as $p
      ( {}; .[$p[0]] = ([ .[$p[0]] // 0, $p[1] ] | max) );
  def superseded_in($latest; f):
    .__typename == "CheckRun" and .conclusion == "CANCELLED"
    and (f as $k | run_num as $n | $k != null and $n != null and $n < ($latest[$k] // 0));
'

# supersede_candidates — reads a poll body on stdin, prints one "<host>|<owner/repo>|<run_id>"
# line per candidate run whose workflow the superseded-run filter needs.
supersede_candidates() {
  jq -r "$RUN_REF_JQ"'
    ( .statusCheckRollup // [] ) as $rows
    | ( $rows | latest_run_by(.workflowName) ) as $lbn
    | [ $rows[] | select(superseded_in($lbn; .workflowName)) | .workflowName ] as $names
    | [ $rows[] | select(.workflowName as $w | any($names[]; . == $w))
        | run_ref | select(. != null) | "\(.host)|\(.repo)|\(.id)" ]
    | unique | .[]
  ' 2>/dev/null
}

# RUN_WF_CACHE — {"<run_id>": "<host>/<owner>/<repo>#<workflow_id>"} for every run resolved so far.
RUN_WF_CACHE='{}'
RUN_WF_COMPLETE=1

# resolve_run_workflows <body> — resolves the workflow of every candidate run not
# yet in RUN_WF_CACHE, one bounded `gh api` GET per run within the deadline; sets
# RUN_WF_COMPLETE=1 when every candidate is resolved, 0 otherwise.
resolve_run_workflows() {
  local cands c host repo id wid out now remaining
  RUN_WF_COMPLETE=1
  cands="$(printf '%s' "$1" | supersede_candidates)"
  for c in $cands; do
    IFS='|' read -r host repo id <<<"$c"
    if [ "$(printf '%s' "$RUN_WF_CACHE" | jq -r --arg k "$id" 'has($k)')" = "true" ]; then
      continue
    fi
    now="$(date +%s)"; remaining=$(( deadline - now ))
    if [ "$remaining" -le 0 ]; then RUN_WF_COMPLETE=0; break; fi
    out="$(mktemp)"
    gh_bounded "$(clamp_to_interval "$remaining")" "$out" \
      gh api --hostname "$host" "repos/$repo/actions/runs/$id" --jq '.workflow_id'
    wid="$(cat "$out")"; rm -f "$out"
    case "$wid" in
      ''|*[!0-9]*) RUN_WF_COMPLETE=0 ;;
      *)
        if [ "${GH_TIMED_OUT:-0}" -eq 0 ] && [ "${GH_RC:-0}" -eq 0 ]; then
          RUN_WF_CACHE="$(printf '%s' "$RUN_WF_CACHE" | jq -c --arg k "$id" --arg v "$host/$repo#$wid" '.[$k] = $v')"
        else
          RUN_WF_COMPLETE=0
        fi ;;
    esac
  done
}

# drop_superseded_runs — reads a poll body on stdin, writes it back with every
# superseded run's CANCELLED CheckRun removed from statusCheckRollup. Reads
# RUN_WF_CACHE / RUN_WF_COMPLETE, set by resolve_run_workflows for this body.
drop_superseded_runs() {
  jq -c --argjson wf "$RUN_WF_CACHE" --argjson complete "$RUN_WF_COMPLETE" "$RUN_REF_JQ"'
    def wf_key: run_ref as $r | if $r == null then null else $wf[$r.id] end;
    ( .statusCheckRollup // [] ) as $rows
    | ( $rows | latest_run_by(.workflowName) ) as $lbn
    | ( $rows | latest_run_by(wf_key) ) as $lbw
    | .statusCheckRollup = [ $rows[]
        | select(( if $complete == 1 then superseded_in($lbw; wf_key)
                   else superseded_in($lbn; .workflowName) end ) | not) ]
  ' 2>/dev/null
}

# Mergeability is a TRI-state, not a binary (issue #81): GitHub returns
# mergeable=UNKNOWN while it is still computing the merge, which is the normal
# state right after a push. Two predicates, three outcomes — confirmed
# not-mergeable / confirmed mergeable / undetermined. Order matters: a read is
# tested for a CONFIRMED conflict first, so mergeable=UNKNOWN paired with
# mergeStateStatus=DIRTY stays a confirmed conflict and is never demoted to a
# poll. An unrecognised value falls to undetermined, never to not-mergeable, so
# a future enum can end on 11/13/14 but never on a false conflict or a false
# green.

# is_not_mergeable <mergeable> <mergeStateStatus> -> rc 0 iff the read CONFIRMS
# the PR is not mergeable.
is_not_mergeable() {
  [ "$1" = "CONFLICTING" ] || [ "$2" = "DIRTY" ]
}

# is_mergeable_confirmed <mergeable> <mergeStateStatus> -> rc 0 iff both fields
# are settled to a green verdict: mergeable=MERGEABLE and mergeStateStatus is
# not still UNKNOWN. Private helper for is_mergeable_undetermined below.
is_mergeable_confirmed() {
  [ "$1" = "MERGEABLE" ] && [ "$2" != "UNKNOWN" ]
}

# is_mergeable_undetermined <mergeable> <mergeStateStatus> -> rc 0 iff the read
# is well-formed but carries no verdict yet (UNKNOWN / unrecognised value on
# either field): the merge state is consulted too, so a MERGEABLE value whose
# mergeStateStatus is still UNKNOWN withholds confirmation instead of granting
# it. Every other mergeStateStatus value keeps its present meaning.
is_mergeable_undetermined() {
  ! is_not_mergeable "$1" "$2" && ! is_mergeable_confirmed "$1" "$2"
}

# clamp_to_interval <remaining> -> echoes min(CI_POLL_INTERVAL_SECS, remaining),
# floored at 1. Shared clamp used by both the precheck bound and the
# per-iteration poll sub-bound so a `gh_bounded` watchdog call never
# outlives the deadline.
clamp_to_interval() {
  local remaining="$1" b="$CI_POLL_INTERVAL_SECS"
  [ "$remaining" -lt "$b" ] && b="$remaining"
  [ "$b" -lt 1 ] && b=1
  printf '%s' "$b"
}

# sleep_to_deadline — recompute remaining against $deadline and sleep
# min(CI_POLL_INTERVAL_SECS, remaining) so a sleep never overshoots the
# deadline by a full interval. Shared by the in-loop transient-failure
# tolerance branch and the end-of-iteration clamped-sleep.
sleep_to_deadline() {
  local now remaining sl
  now="$(date +%s)"; remaining=$(( deadline - now ))
  if [ "$remaining" -gt 0 ]; then
    sl="$CI_POLL_INTERVAL_SECS"
    [ "$remaining" -lt "$sl" ] && sl="$remaining"
    sleep "$sl"
  fi
}

# ---------------------------------------------------------------------------
# 1. PRECHECK (before any poll) — read mergeable/mergeStateStatus first.
#    The deadline is computed FIRST so the precheck participates in the same
#    finite budget. The precheck is only an EARLY-EXIT optimization for a
#    JSON-confirmed not-mergeable read: any failed/timed-out/empty/non-JSON
#    read falls through to the bounded poll (which re-reads mergeable each
#    iteration), never exit 10.
# ---------------------------------------------------------------------------
deadline=$(( $(date +%s) + CI_POLL_TIMEOUT_SECS ))
saw_checks=0
mergeable_confirmed=0

now="$(date +%s)"; remaining=$(( deadline - now ))
pre_bound="$(clamp_to_interval "$remaining")"

pre_out="$(mktemp)"
gh_bounded "$pre_bound" "$pre_out" \
  gh pr view "$PR" "${REPO_ARGS[@]}" --json mergeable,mergeStateStatus
pre_body="$(cat "$pre_out")"; rm -f "$pre_out"

if [ "${GH_TIMED_OUT:-0}" -eq 1 ] || [ "${GH_RC:-0}" -ne 0 ] || [ -z "$pre_body" ]; then
  : # inconclusive precheck read (timeout / non-zero RC / empty body) — fall through.
else
  pre_mergeable="$(printf '%s' "$pre_body" | jq -r '.mergeable // empty' 2>/dev/null)"
  pre_state="$(printf '%s' "$pre_body" | jq -r '.mergeStateStatus // empty' 2>/dev/null)"
  if [ -z "$pre_mergeable" ]; then
    : # non-empty but non-JSON / field-absent body → jq degraded mergeable to
      # empty: inconclusive, NOT a confirmed conflict; fall through (do NOT set
      # the flag, do NOT classify). A well-formed read never yields an empty
      # mergeable, so empty unambiguously marks a bad read.
  elif is_not_mergeable "$pre_mergeable" "$pre_state"; then
    mergeable_confirmed=1
    echo "[HANDOFF-INTERNAL-RETRY] not mergeable (mergeStateStatus=${pre_state:-unknown}) — do NOT wait on CI; branch by cause (gitlink -> Reconcile preflight; other conflict -> rebase origin/main); HANDOFF internal retry" >&2
    exit 10
  elif is_mergeable_undetermined "$pre_mergeable" "$pre_state"; then
    : # still-computing UNKNOWN on either field (or an unrecognised value): an uncertain read,
      # NOT a confirmed conflict. Fall through to the bounded poll WITHOUT
      # setting the flag, exactly as the empty-read arm does — a never-settling
      # UNKNOWN then lands on exit 14 at the deadline rather than a false green.
  else
    mergeable_confirmed=1
  fi
fi

# ---------------------------------------------------------------------------
# 2. POLL (reached on a mergeable precheck OR a degraded-precheck fall-through),
#    deadline-bounded and finite.
# ---------------------------------------------------------------------------
while [ "$(date +%s)" -lt "$deadline" ]; do
  now="$(date +%s)"
  remaining=$(( deadline - now ))
  [ "$remaining" -le 0 ] && break

  # Per-call watchdog sub-bound: min(interval, remaining-to-deadline), >=1.
  sub_bound="$(clamp_to_interval "$remaining")"

  poll_out="$(mktemp)"
  gh_bounded "$sub_bound" "$poll_out" \
    gh pr view "$PR" "${REPO_ARGS[@]}" --json mergeable,mergeStateStatus,statusCheckRollup
  body="$(cat "$poll_out")"; rm -f "$poll_out"

  # A hung call was killed, or a transient non-zero / empty read: tolerate,
  # re-test the deadline at the loop head, and continue within the budget.
  if [ "${GH_TIMED_OUT:-0}" -eq 1 ] || [ "${GH_RC:-0}" -ne 0 ] || [ -z "$body" ]; then
    sleep_to_deadline
    continue
  fi

  # D5 — re-read mergeable every iteration; early-exit 10 on a mid-poll flip.
  m="$(printf '%s' "$body" | jq -r '.mergeable // empty' 2>/dev/null)"
  s="$(printf '%s' "$body" | jq -r '.mergeStateStatus // empty' 2>/dev/null)"
  # A non-empty but non-JSON / field-absent body → jq degraded mergeable to
  # empty: inconclusive THIS iteration, NOT a confirmed mid-poll flip. Rejoin
  # the transient-tolerance path (skip classification, clamped-sleep, retry
  # within the budget) — symmetric with the precheck [ -z "$pre_mergeable" ]
  # arm. Do NOT set mergeable_confirmed, do NOT classify this read. If every
  # remaining iteration degrades this way through the deadline, the post-loop
  # classifier lands it on exit 11 (healthy precheck already set
  # mergeable_confirmed=1 at the precheck) or exit 14 (precheck also degraded,
  # flag still 0) — never 10.
  if [ -z "$m" ]; then sleep_to_deadline; continue; fi
  # Well-formed read: confirm the mergeable state unless it carries no verdict.
  undetermined=0
  if is_mergeable_undetermined "$m" "$s"; then undetermined=1; else mergeable_confirmed=1; fi
  if is_not_mergeable "$m" "$s"; then
    echo "[HANDOFF-INTERNAL-RETRY] not mergeable (mergeStateStatus=${s:-unknown}) — PR flipped mid-poll; do NOT wait on CI; branch by cause (gitlink -> Reconcile preflight; other conflict -> rebase origin/main); HANDOFF internal retry" >&2
    exit 10
  fi

  resolve_run_workflows "$body"
  stats="$(printf '%s' "$body" | drop_superseded_runs | classify_rollup)"
  read -r total fail green <<<"${stats:-0 0 0}"
  total="${total:-0}"; fail="${fail:-0}"; green="${green:-0}"

  if [ "$fail" -gt 0 ]; then
    echo "a check concluded failure/error/cancelled/timed_out — red CI (route to RED)" >&2
    exit 12
  fi
  # An undetermined read withholds the GREEN verdict only: exit 0 is contracted
  # as "CI green on a PR whose mergeable state was confirmed". The fail>0 branch
  # above and the saw_checks accounting below still run — a concluded failure is
  # true of the read however mergeability resolves, and masking it would sleep a
  # red build to a deadline code that never routes to RED.
  # An unresolved superseded-run lookup withholds the GREEN verdict the same way.
  if [ "$undetermined" -eq 0 ] && [ "$RUN_WF_COMPLETE" -eq 1 ] \
     && [ "$total" -gt 0 ] && [ "$green" -eq "$total" ]; then
    exit 0
  fi
  if [ "$total" -gt 0 ]; then
    saw_checks=1
  fi

  # clamped-sleep: min(interval, remaining) so the loop cannot overshoot the
  # deadline by a full interval.
  sleep_to_deadline
done

# ---------------------------------------------------------------------------
# 3. TIMEOUT — deadline reached without a terminal classification.
# ---------------------------------------------------------------------------
if [ "$mergeable_confirmed" -eq 0 ]; then
  echo "[HANDOFF-INTERNAL-RETRY] could not confirm PR mergeable state within ${CI_POLL_TIMEOUT_SECS}s — gh transport/auth/network failure, or a merge state that never settled (an UNKNOWN mergeable or mergeStateStatus) at the deadline, suspected (not a merge conflict); check gh auth/connectivity and re-run — NOT green" >&2
  exit 14
fi
if [ "$saw_checks" -eq 0 ]; then
  echo "MERGEABLE but no check published within ${CI_POLL_TIMEOUT_SECS}s — suspect CI trigger (webhook delivery / workflow trigger conditions) — re-push to force a synchronize event; NOT green" >&2
  exit 11
else
  echo "checks present but no green verdict after ${CI_POLL_TIMEOUT_SECS}s (slow CI, a confirmed-then-undetermined run whose rollup is green but mergeability never re-settled, or a superseded-run workflow lookup that never completed) — inconclusive, re-run with a larger CI_POLL_TIMEOUT_SECS or escalate; NOT green" >&2
  exit 13
fi
