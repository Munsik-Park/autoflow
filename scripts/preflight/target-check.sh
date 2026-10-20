#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Apache-2.0
# =============================================================================
# PREFLIGHT target check — the target-owned files agree with the AutoFlow that
# runs them (ADR-0027 D4; docs/units/preparation.md > Stop conditions)
# =============================================================================
# Run from the AutoFlow root the session loads: the definitions, the readout,
# the selector and the default policy are the ones beside this script, and the
# target is the git toplevel of the working directory. It reads the target's
# files as data and executes none of them. It changes nothing.
#
# Legs (the D6 and D7 legs of the retired drift-check, kept by ADR-0027 D4):
#   D6  the target's own spawn policy, `.claude/autoflow/spawn-policy.json`,
#       when the target keeps one: `spawn-policy.sh check` over it against the
#       loaded agent definitions (phase-row effort equals the definition's
#       `effort:` frontmatter; every agent_type is shipped), and its row set
#       against the plugin's default policy — a `phases` / `workflow_sites`
#       row the default carries and the target's copy lacks, or a `phases` row
#       whose agent_type differs, is named. Model values and workflow_sites
#       effort are the target's own and are never compared. A target with no
#       policy of its own PASSes: the plugin's default answers its readouts.
#   D7  on a target that opted into the suite plane
#       (`.claude/autoflow.local.json` > tests > suite_plane: true, resolved by
#       scripts/test/suite-manifest.sh > suite_plane_opted_in): every
#       executable spec under the target's tests/** declares a usable
#       `# ci-subject:` header — the selector's own `--check-headers` stage. A
#       target that has not opted in PASSes without the selector being
#       consulted; a declaration that is present but unreadable is a FAIL.
#
# Exit: 0 every leg passed; 1 any FAIL (a PREFLIGHT stop condition); 64 usage.
#
# Usage: bash <autoflow-root>/scripts/preflight/target-check.sh
# =============================================================================

set -uo pipefail

TAG="target-check"
case "${1:-}" in
  "") ;;
  -h|--help) echo "Usage: $0"; exit 0 ;;
  *) echo "[$TAG] unknown argument: $1" >&2; echo "Usage: $0" >&2; exit 64 ;;
esac

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AF_ROOT="$(cd "$SELF_DIR/../.." && pwd)"
TARGET_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "[$TAG] not inside a git repository" >&2; exit 64; }

SPAWN_POLICY_SH="$AF_ROOT/scripts/spawn-policy/spawn-policy.sh"
DEFAULT_POLICY="$AF_ROOT/.claude/autoflow/spawn-policy.json"
SELECT_SUITES_SH="$AF_ROOT/scripts/test/select-suites.sh"
SUITE_MANIFEST_SH="$AF_ROOT/scripts/test/suite-manifest.sh"

FAIL_COUNT=0
pass()  { printf 'PASS: %s\n' "$1"; }
failc() { FAIL_COUNT=$((FAIL_COUNT + 1)); printf 'FAIL: %s -- %s\n' "$1" "$2"; }
hint()  { printf 'HINT: %s\n' "$1"; }

if ! command -v jq >/dev/null 2>&1; then
  failc "$TAG" "jq is required but not found"
  exit 1
fi

echo "target: $TARGET_ROOT"
echo "autoflow root: $AF_ROOT"

# ── D6: the target's spawn policy vs the loaded agent definitions ────────────
echo "== D6: the target's spawn policy vs the loaded agent definitions =="
_policy="$TARGET_ROOT/.claude/autoflow/spawn-policy.json"
if [ ! -f "$_policy" ]; then
  pass "D6: the target keeps no .claude/autoflow/spawn-policy.json — the plugin's default policy ($DEFAULT_POLICY) answers its readouts"
else
  _d6_fail_before=$FAIL_COUNT
  _d6_err="$(mktemp)"
  # Effort projection + agent-type membership: the readout's own `check`,
  # pointed at the target's policy. Its stderr is the finding list.
  (cd / && AUTOFLOW_SPAWN_POLICY="$_policy" bash "$SPAWN_POLICY_SH" check >/dev/null 2>"$_d6_err")
  _d6_rc=$?
  if [ "$_d6_rc" -ne 0 ]; then
    while IFS= read -r _l; do
      case "$_l" in
        "spawn-policy check: "*) failc "D6" "${_l#spawn-policy check: }" ;;
        "spawn-policy: "*)       failc "D6" "${_l#spawn-policy: }" ;;
        *)                       hint "D6: $_l" ;;
      esac
    done < "$_d6_err"
    [ "$FAIL_COUNT" -gt "$_d6_fail_before" ] || failc "D6" "spawn-policy.sh check exited $_d6_rc on $_policy"
  fi
  rm -f "$_d6_err"
  # Required-row set: the plugin's default carries every row the current
  # version requires. Compared: key presence, and a phases row's agent_type.
  if ! jq -e '(.phases | type) == "object"' "$DEFAULT_POLICY" >/dev/null 2>&1; then
    failc "D6" "the plugin's default policy $DEFAULT_POLICY is not usable (missing, invalid JSON or no phases object) — the required-row comparison could not run"
  elif ! jq -e '(.phases | type) == "object"' "$_policy" >/dev/null 2>&1; then
    failc "D6" "$_policy is not usable (invalid JSON or no phases object) — the required-row comparison could not run"
  elif _d6_rows="$(jq -n -r --arg q "'" --slurpfile t "$_policy" --slurpfile s "$DEFAULT_POLICY" '
      ($t[0]) as $t | ($s[0]) as $s
      | ( [ $s.phases | to_entries[] | select($t.phases[.key] == null)
            | "missing phases row \($q)\(.key)\($q) (agent_type \(.value.agent_type), effort \(.value.effort|tostring)) — required by the current version; add it from the default policy" ] )
      + ( [ $s.phases | to_entries[] | select($t.phases[.key] != null and $t.phases[.key].agent_type != .value.agent_type)
            | "phases row \($q)\(.key)\($q) names agent_type \($q)\($t.phases[.key].agent_type)\($q), but the current version names \($q)\(.value.agent_type)\($q) — update the row to the agent_type and effort the default policy carries" ] )
      + ( [ ($s.workflow_sites // {}) | to_entries[] | .key as $wf | .value | to_entries[]
            | select((($t.workflow_sites // {})[$wf] // {})[.key] == null)
            | "missing workflow_sites row \($q)\($wf).\(.key)\($q) — required by the current version (the workflow fails closed without it); add it from the default policy" ] )
      | .[]' 2>/dev/null)"; then
    while IFS= read -r _l; do
      [ -n "$_l" ] && failc "D6" "$_l"
    done <<EOF_ROWS
$_d6_rows
EOF_ROWS
  else
    failc "D6" "could not compute the row relation between $_policy and $DEFAULT_POLICY (jq failed) — the required-row comparison could not run"
  fi
  if [ "$FAIL_COUNT" -eq "$_d6_fail_before" ]; then
    pass "D6: the target's policy ($_policy) agrees with the loaded agent definitions ($AF_ROOT/agents) and carries every row the default requires"
  else
    hint "D6: the policy is the target's own — edit $_policy: set each named row to the loaded definition's values ($AF_ROOT/agents), and add each missing row from $DEFAULT_POLICY. Model values and workflow_sites effort are the target's to keep. Deleting the file hands the readouts to the plugin's default."
  fi
fi

# ── D7: suite headers the selector requires, on an opted-in target ───────────
echo "== D7: suite headers the selector requires =="
_decl="$TARGET_ROOT/.claude/autoflow.local.json"
_plane="$(bash -c '
  . "$1" || exit 3
  suite_plane_opted_in "$2"; rc=$?
  if [ "$rc" -eq 0 ]; then echo in
  elif [ "$rc" -eq "$SUITE_PLANE_NOT_OPTED_IN" ]; then echo out
  elif [ "$rc" -eq "$SUITE_PLANE_UNREADABLE" ]; then echo unreadable
  else echo "resolver-exit-$rc"; fi
' _ "$SUITE_MANIFEST_SH" "$TARGET_ROOT" 2>/dev/null)"
case "$_plane" in
  in)
    _out="$(mktemp)"; _err="$(mktemp)"
    bash "$SELECT_SUITES_SH" --check-headers --root "$TARGET_ROOT" >"$_out" 2>"$_err"
    _rc=$?
    # Each exit is accepted only with the evidence its contract promises: 0
    # carries the headers-OK record, 1 names at least one suite.
    if [ "$_rc" -eq 0 ] && grep -q '^select-suites: headers OK — ' "$_err"; then
      pass "D7: suite headers OK — $(sed -n 's/^select-suites: headers OK — //p' "$_err")"
    elif [ "$_rc" -eq 1 ] && [ -s "$_out" ]; then
      while IFS= read -r _s; do
        [ -n "$_s" ] && failc "D7" "$_s declares no usable '# ci-subject:' header — the selector BLOCKs every selection until it does"
      done < "$_out"
      hint "D7: back-fill '# ci-subject:' (with '# budget-secs:') in each named suite per <autoflow-root>/docs/units/build.md > Header contract > Adopting the contract over existing suites; a sourced helper rather than a standalone spec moves under tests/lib/. Re-check with: bash $SELECT_SUITES_SH --check-headers"
    else
      failc "D7" "select-suites.sh --check-headers exited $_rc without its verdict record ($(sed -n 1p "$_err")) — the suite-header check could not run"
    fi
    rm -f "$_out" "$_err"
    ;;
  out)
    pass "D7: suite plane not opted in — $_decl declares no tests > suite_plane opt-in, so no '# ci-subject:' header is owed (ADR-0024 D3)"
    ;;
  unreadable)
    failc "D7" "$_decl is present but its JSON could not be read — the suite plane's applicability cannot be decided from an unreadable declaration; repair the file"
    ;;
  *)
    failc "D7" "the suite-plane resolver ($SUITE_MANIFEST_SH > suite_plane_opted_in) returned '${_plane:-nothing}' instead of a verdict — the suite-header check could not run"
    ;;
esac

echo "=============================================="
printf 'RESULT: target-check %d failed\n' "$FAIL_COUNT"
[ "$FAIL_COUNT" -eq 0 ] || exit 1
exit 0
