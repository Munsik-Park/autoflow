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
#   --repo <owner/name> Optional. Forwarded to every `gh` call (cross-repo
#                       selector, mirrors scripts/review/codex-review-pr.sh).
#                       Omitted => the current repository (host PR).
#   -h | --help         Usage to stdout, exit 0.
#
# Tunables (env vars — the Approach-5 timeout / reconfirm policy as parameters):
#   CI_POLL_TIMEOUT_SECS   (default 900) Total finite poll budget (deadline).
#                          Generous so a normally-slow Jenkins build is not clipped.
#   CI_POLL_INTERVAL_SECS  (default 20)  Sleep between poll iterations — also
#                          caps the one-shot precheck read (pre_bound =
#                          min(CI_POLL_INTERVAL_SECS, remaining-to-deadline)).
#   Both validated as non-negative integers; non-numeric -> exit 64.
#
# Exit-code contract (feature §4):
#   0   CI green         — >=1 check present and every element green.
#   10  not mergeable    — CONFLICTING/DIRTY/!MERGEABLE at precheck OR on a
#                          mid-poll flip; stderr carries the reserved
#                          [HANDOFF-INTERNAL-RETRY] token. No poll on precheck.
#                          Only on a JSON-confirmed read; a failed/timed-out/
#                          empty/non-JSON read — at the precheck OR mid-poll —
#                          falls through to the bounded poll (or, mid-poll, to a
#                          retry within the budget), never 10.
#   11  0 checks         — MERGEABLE but no check ever published within the bound.
#   12  red build        — a check concluded FAILURE/ERROR/CANCELLED/TIMED_OUT.
#   13  still pending     — checks present but never all-green at the deadline (slow CI).
#   14  inconclusive     — could not confirm mergeable within the bound; gh
#                          transport/auth/parse failure suspected (NOT a
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
  "$@" >"$outfile" 2>/dev/null &
  local pid=$!
  ( sleep "$bound"; if kill -0 "$pid" 2>/dev/null; then kill "$pid" 2>/dev/null; echo fired >"$marker"; fi ) &
  local wpid=$!
  wait "$pid" 2>/dev/null
  GH_RC=$?
  if [ -s "$marker" ]; then
    GH_TIMED_OUT=1
  else
    kill "$wpid" 2>/dev/null
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
    def has_start:
      if .__typename == "CheckRun" then (.startedAt // "") != ""
      else (.createdAt // "") != "" end;
    ( .statusCheckRollup // [] )
    | group_by(ident)
    | map(
        ( [ .[] | select(non_terminal) ] ) as $nt
        | ( [ .[] | select(non_terminal | not) ] ) as $tm
        | if ($nt | length) == 0 then
            max_by(ts_key + [ (if green_entry then 0 else 1 end) ])
          elif ($tm | length) > 0
               and ([ $nt[] | has_start ] | all)
               and (($tm | max_by(start_key) | start_key) > ($nt | max_by(start_key) | start_key))
          then
            ( $tm | max_by(ts_key + [ (if green_entry then 0 else 1 end) ]) )
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

# is_not_mergeable <mergeable> <mergeStateStatus> -> rc 0 iff not mergeable.
is_not_mergeable() {
  [ "$1" != "MERGEABLE" ] || [ "$2" = "CONFLICTING" ] || [ "$2" = "DIRTY" ]
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
  else
    mergeable_confirmed=1
    if is_not_mergeable "$pre_mergeable" "$pre_state"; then
      echo "[HANDOFF-INTERNAL-RETRY] not mergeable (mergeStateStatus=${pre_state:-unknown}) — do NOT wait on CI; branch by cause (gitlink -> Reconcile preflight; other conflict -> rebase origin/main); HANDOFF internal retry" >&2
      exit 10
    fi
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
  # Reached only on a well-formed read (non-empty parsed mergeable) — confirm
  # the mergeable state was observed this cycle.
  mergeable_confirmed=1
  if is_not_mergeable "$m" "$s"; then
    echo "[HANDOFF-INTERNAL-RETRY] not mergeable (mergeStateStatus=${s:-unknown}) — PR flipped mid-poll; do NOT wait on CI; branch by cause (gitlink -> Reconcile preflight; other conflict -> rebase origin/main); HANDOFF internal retry" >&2
    exit 10
  fi

  stats="$(printf '%s' "$body" | classify_rollup)"
  read -r total fail green <<<"${stats:-0 0 0}"
  total="${total:-0}"; fail="${fail:-0}"; green="${green:-0}"

  if [ "$fail" -gt 0 ]; then
    echo "a check concluded failure/error/cancelled/timed_out — red CI (route to RED)" >&2
    exit 12
  fi
  if [ "$total" -gt 0 ] && [ "$green" -eq "$total" ]; then
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
  echo "[HANDOFF-INTERNAL-RETRY] could not confirm PR mergeable state within ${CI_POLL_TIMEOUT_SECS}s — gh transport/auth/network failure suspected (not a merge conflict); check gh auth/connectivity and re-run — NOT green" >&2
  exit 14
fi
if [ "$saw_checks" -eq 0 ]; then
  echo "MERGEABLE but no check published within ${CI_POLL_TIMEOUT_SECS}s — suspect webhook / scan fallback (PeriodicFolderTrigger / synchronize re-push); NOT green" >&2
  exit 11
else
  echo "checks still pending after ${CI_POLL_TIMEOUT_SECS}s (slow CI) — inconclusive, re-run with a larger CI_POLL_TIMEOUT_SECS or escalate; NOT green" >&2
  exit 13
fi
