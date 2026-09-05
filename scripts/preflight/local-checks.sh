#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# PREFLIGHT target-declared local checks (issue #181)
# =============================================================================
# The call site for a target repository's OWN readiness procedure. A target
# that requires a per-clone setup step (a commit-hook installer, a generated
# config, a toolchain probe — anything its own docs call "a required step of
# this repo's setup") declares it in the target-owned scaffold
# `.claude/autoflow.local.json`; PREFLIGHT runs the declarations through this
# script before DIAGNOSE and stops fail-closed when one does not pass.
#
# The framework knows NO specific tool. It runs what the target declared,
# reads only the exit status, and records the outcome. What a check probes,
# how it repairs, and what it prints are the target's business.
#
# Declaration shape (`preflight.local_checks`, an array; every key but `check`
# optional):
#
#   { "preflight": { "local_checks": [
#       { "name":   "commit-hooks",
#         "check":  "bash scripts/setup/hooks.sh --check",
#         "repair": "bash scripts/setup/hooks.sh --install" } ] } }
#
#   name   : label used in the report and the ledger record (default: the
#            check command itself).
#   check  : the command run at PREFLIGHT. Exit 0 = ready. Run through
#            `bash -c` from the repository root, so a target may declare a
#            script path with arguments or a plain shell command.
#   repair : optional. When `check` fails and `repair` is declared, `repair`
#            runs once and `check` is re-run; the re-run's exit is the verdict.
#            Without `repair`, the first failure is the verdict.
#
# Absent file, absent `.preflight`, absent or empty `.preflight.local_checks`
# → no-op: exit 0, one line `PREFLIGHT local checks: none declared`, and the
# same line as the ledger record when a ledger is given. A declared list that
# cannot be read as declared (jq missing, malformed JSON, `.preflight` or
# `.preflight.local_checks` of the wrong type, an entry without a string
# `check`) is a usage error — exit 2 — never a silent no-op: a target that
# wrote a declaration meant it to run.
#
# Ledger record (`--ledger <path>`, issue #181 requirement 3): appended as a
# level-3 record entry — no identifier, outside the `O`/`F` namespaces, in the
# same class as `green-tree` / `verify-detection` — so `ledger-entry-id.sh
# check` ignores it and the gate hook, which reads the ledger advisorily only,
# is unchanged. The state file is never touched.
#
#   ### preflight-local-checks | cycle: <C>
#   - result: none declared
#   ### preflight-local-checks | cycle: <C>
#   - result: PASS commit-hooks=PASS(repaired) toolchain=PASS
#   ### preflight-local-checks | cycle: <C>
#   - result: FAIL commit-hooks=FAIL(repair-declined) toolchain=PASS
#
# Exit codes:
#   0 = none declared, or every declared check passed (after repair if any)
#   1 = at least one declared check failed → fail-closed PREFLIGHT stop
#   2 = usage / declaration error (nothing executed)
#
# Usage: scripts/preflight/local-checks.sh [--config <path>] [--ledger <path>]
#                                          [--cycle <C>] [--root <dir>]
#                                          [--no-repair]
# =============================================================================

set -uo pipefail

TAG="preflight-local-checks"
CONFIG="${AUTOFLOW_LOCAL_CONFIG:-.claude/autoflow.local.json}"
LEDGER=""
CYCLE="${AUTOFLOW_CYCLE:-1}"
ROOT=""
NO_REPAIR=0

usage() {
  echo "Usage: $0 [--config <path>] [--ledger <path>] [--cycle <C>] [--root <dir>] [--no-repair]"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --config)  [ $# -ge 2 ] || { echo "[$TAG] --config requires a value" >&2; exit 2; }; CONFIG="$2"; shift 2 ;;
    --ledger)  [ $# -ge 2 ] || { echo "[$TAG] --ledger requires a value" >&2; exit 2; }; LEDGER="$2"; shift 2 ;;
    --cycle)   [ $# -ge 2 ] || { echo "[$TAG] --cycle requires a value" >&2; exit 2; }; CYCLE="$2"; shift 2 ;;
    --root)    [ $# -ge 2 ] || { echo "[$TAG] --root requires a value" >&2; exit 2; }; ROOT="$2"; shift 2 ;;
    --no-repair) NO_REPAIR=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "[$TAG] unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [ -z "$ROOT" ]; then
  ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
fi
cd "$ROOT" || { echo "[$TAG] cannot enter root: $ROOT" >&2; exit 2; }

# ---------------------------------------------------------------------------
# Ledger record writer. Heading + one `- result:` line, appended verbatim.
# ---------------------------------------------------------------------------
record() {
  local line="$1"
  echo "$line"
  if [ -n "$LEDGER" ]; then
    mkdir -p "$(dirname "$LEDGER")" 2>/dev/null || true
    {
      echo ""
      echo "### $TAG | cycle: $CYCLE"
      echo "- result: $line"
    } >> "$LEDGER" || { echo "[$TAG] cannot append to ledger: $LEDGER" >&2; exit 2; }
  fi
}

# ---------------------------------------------------------------------------
# Read the declaration. Absent → none declared. Present → fail closed on any
# shape the contract above does not admit.
# ---------------------------------------------------------------------------
if [ ! -f "$CONFIG" ]; then
  record "PREFLIGHT local checks: none declared"
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "[$TAG] $CONFIG is present but jq is not on PATH — cannot read preflight.local_checks; refusing to treat a possible declaration as none. Install jq." >&2
  exit 2
fi
if ! jq -e . "$CONFIG" >/dev/null 2>&1; then
  echo "[$TAG] $CONFIG is not valid JSON — refusing to treat a possible declaration as none. Fix the file." >&2
  exit 2
fi

SECTION_TYPE="$(jq -r '.preflight | type' "$CONFIG")"
case "$SECTION_TYPE" in
  null) record "PREFLIGHT local checks: none declared"; exit 0 ;;
  object) ;;
  *) echo "[$TAG] $CONFIG sets .preflight to a $SECTION_TYPE, expected an object." >&2; exit 2 ;;
esac

LIST_TYPE="$(jq -r '.preflight.local_checks | type' "$CONFIG")"
case "$LIST_TYPE" in
  null) record "PREFLIGHT local checks: none declared"; exit 0 ;;
  array) ;;
  *) echo "[$TAG] $CONFIG sets .preflight.local_checks to a $LIST_TYPE, expected an array." >&2; exit 2 ;;
esac

COUNT="$(jq -r '.preflight.local_checks | length' "$CONFIG")"
if [ "$COUNT" -eq 0 ]; then
  record "PREFLIGHT local checks: none declared"
  exit 0
fi

# Validate every entry before executing any (whole-list, so a rejected
# declaration leaves no half-executed run).
BAD="$(jq -r '
  .preflight.local_checks | to_entries[]
  | select((.value|type) != "object"
           or ((.value.check|type) != "string") or (.value.check == "")
           or ((.value.repair|type) != "null" and ((.value.repair|type) != "string" or .value.repair == ""))
           or ((.value.name|type) != "null" and ((.value.name|type) != "string" or .value.name == "")))
  | .key' "$CONFIG")"
if [ -n "$BAD" ]; then
  for i in $BAD; do
    echo "[$TAG] $CONFIG .preflight.local_checks[$i] is not { \"check\": <non-empty string>, \"repair\"?: <non-empty string>, \"name\"?: <non-empty string> }." >&2
  done
  exit 2
fi

# ---------------------------------------------------------------------------
# Run. Output of each declared command goes to the operator's terminal; this
# script reads only the exit status.
# ---------------------------------------------------------------------------
OVERALL=PASS
SUMMARY=""
i=0
while [ "$i" -lt "$COUNT" ]; do
  NAME="$(jq -r --argjson i "$i" '.preflight.local_checks[$i].name // .preflight.local_checks[$i].check' "$CONFIG")"
  CHECK="$(jq -r --argjson i "$i" '.preflight.local_checks[$i].check' "$CONFIG")"
  REPAIR="$(jq -r --argjson i "$i" '.preflight.local_checks[$i].repair // ""' "$CONFIG")"
  # A name is one token in the ledger record.
  NAME="${NAME//[[:space:]]/_}"

  echo "[$TAG] $NAME: check: $CHECK"
  bash -c "$CHECK" </dev/null
  RC=$?
  if [ "$RC" -eq 0 ]; then
    OUTCOME="PASS"
  elif [ -n "$REPAIR" ] && [ "$NO_REPAIR" -eq 0 ]; then
    echo "[$TAG] $NAME: check failed (exit $RC); repair: $REPAIR"
    bash -c "$REPAIR" </dev/null
    RRC=$?
    if [ "$RRC" -ne 0 ]; then
      echo "[$TAG] $NAME: repair failed (exit $RRC)" >&2
      OUTCOME="FAIL(repair-failed)"
    else
      echo "[$TAG] $NAME: re-check: $CHECK"
      bash -c "$CHECK" </dev/null
      RC2=$?
      if [ "$RC2" -eq 0 ]; then
        OUTCOME="PASS(repaired)"
      else
        echo "[$TAG] $NAME: re-check failed after repair (exit $RC2)" >&2
        OUTCOME="FAIL(after-repair)"
      fi
    fi
  elif [ -n "$REPAIR" ]; then
    echo "[$TAG] $NAME: check failed (exit $RC); repair declared but --no-repair given" >&2
    OUTCOME="FAIL(repair-declined)"
  else
    echo "[$TAG] $NAME: check failed (exit $RC); no repair declared" >&2
    OUTCOME="FAIL"
  fi
  case "$OUTCOME" in FAIL*) OVERALL=FAIL ;; esac
  SUMMARY="$SUMMARY $NAME=$OUTCOME"
  i=$((i + 1))
done

record "PREFLIGHT local checks: $OVERALL$SUMMARY"

if [ "$OVERALL" = "FAIL" ]; then
  echo "[$TAG] a target-declared local check did not pass — PREFLIGHT stops before DIAGNOSE (fail-closed). Run the declared repair, or fix the declaration in $CONFIG, then re-run." >&2
  exit 1
fi
exit 0
