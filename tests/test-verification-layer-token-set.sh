#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: docs/adr/0024-two-layer-verification-and-target-owned-tests.md scripts/gate/
# lane: standing
# budget-secs: SUITE_BUDGET_CEILING_SECS
# =============================================================================
# Test: the standing-category token set the layer check enforces is the closed
#       list ADR-0024 D1 writes down.
# =============================================================================
# STANDING suite (`automated / standing: cross-file`), subject-named, no issue
# number — docs/autoflow-guide.md > RED > Naming.
#
# WHAT IT PROTECTS, and what its absence costs. ADR-0024 D1's list is closed and
# "categories are extended by revising this ADR, never by describing a new one
# in a row". The defect this catches is the revision landing on one side only:
# the ADR's list changes and the device keeps enforcing the superseded set, or
# the device gains a token the ADR never admitted. Both states are silent — the
# device stays green on every design it sees, and the ADR reads correctly to a
# human — and both surface only after merge. That is `cross-file`'s own named
# case: "a rule and its enforcement device" stating the same fact.
#
# THE AGREEMENT IS ASSERTED IN BOTH DIRECTIONS. A per-token acceptance loop
# alone catches only the ADR gaining a token; set equality against the device's
# own declared set catches the ADR losing one while the device still admits it.
# The behavioural leg then pins the declared set to the enforced one, so
# `--list-tokens` cannot degrade into a decorative list the arm agrees with
# while the membership arm enforces something else.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ADR="$PROJECT_ROOT/docs/adr/0024-two-layer-verification-and-target-owned-tests.md"
DEVICE="$PROJECT_ROOT/scripts/gate/verification-layer-check.sh"

PASS=0; FAIL=0
pass()  { echo "  PASS: $1"; PASS=$((PASS + 1)); }
failc() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT INT TERM

echo "=== verification-layer check: the enforced token set is ADR-0024 D1's closed list ==="

# ---------------------------------------------------------------------------
# The ADR side — the tokens as written, read out of D1's own table.
# ---------------------------------------------------------------------------
adr_tokens() {
  awk '/^\*\*Closed `standing` categories\.\*\*/ { on = 1; next }
       on && /^\*\*Declaration site\.\*\*/ { exit }
       on && /^\| *`[a-z-]+` *\|/ { print }' "$ADR" \
    | sed -E 's/^\| *`([a-z-]+)` *\|.*/\1/' | sort -u
}
mapfile -t ADR_TOKENS < <(adr_tokens)

if [ "${#ADR_TOKENS[@]}" -ge 1 ]; then
  pass "ADR-PARSE: ADR-0024 D1's closed list resolved to ${#ADR_TOKENS[@]} token(s): ${ADR_TOKENS[*]}"
else
  failc "ADR-PARSE: ADR-0024 D1's token table did not resolve — every arm below would be vacuous"
fi

# ---------------------------------------------------------------------------
# The device side — its own declared set.
# ---------------------------------------------------------------------------
if [ ! -f "$DEVICE" ]; then
  failc "DEVICE-PRESENT: scripts/gate/verification-layer-check.sh is absent — nothing enforces the closed list"
else
  pass "DEVICE-PRESENT: scripts/gate/verification-layer-check.sh is present"
fi

DEV_OUT="$(bash "$DEVICE" --list-tokens 2>/dev/null)"; DEV_RC=$?
mapfile -t DEV_TOKENS < <(printf '%s\n' "$DEV_OUT" | grep -E '^[a-z-]+$' | sort -u)

if [ "$DEV_RC" -eq 0 ] && [ "${#DEV_TOKENS[@]}" -ge 1 ]; then
  pass "DEVICE-DECLARES: --list-tokens exits 0 and declares ${#DEV_TOKENS[@]} token(s)"
else
  failc "DEVICE-DECLARES: --list-tokens exited $DEV_RC with ${#DEV_TOKENS[@]} token(s) — the device states no set to compare"
fi

if [ "$(printf '%s\n' "${ADR_TOKENS[@]+"${ADR_TOKENS[@]}"}")" = "$(printf '%s\n' "${DEV_TOKENS[@]+"${DEV_TOKENS[@]}"}")" ]; then
  pass "SET-EQUALITY: the device enforces exactly the tokens ADR-0024 D1 writes down"
else
  failc "SET-EQUALITY: ADR='${ADR_TOKENS[*]:-none}' device='${DEV_TOKENS[*]:-none}' — the rule and its enforcement device state different facts"
fi

# ---------------------------------------------------------------------------
# The behavioural leg — the declared set is the enforced set.
# ---------------------------------------------------------------------------
fixture() {
  local f="$1" cell="$2"
  { echo "# Verification Design — fixture"
    echo
    echo '| Issue AC | Acceptance criterion | Type | Kind | Method | Failure mode | Reason |'
    echo '|----------|----------------------|------|------|--------|--------------|--------|'
    echo "| AC1 | fixture criterion | $cell | driving | a method | a failure mode | — |"
  } > "$f"
}

for tok in ${ADR_TOKENS[@]+"${ADR_TOKENS[@]}"}; do
  fixture "$WORK/ok.md" "automated / standing: $tok"
  bash "$DEVICE" "$WORK/ok.md" >/dev/null 2>&1
  if [ $? -eq 0 ]; then
    pass "ENFORCES-ADMITS: a row typed 'automated / standing: $tok' is admitted, as D1 writes it"
  else
    failc "ENFORCES-ADMITS: the device rejects '$tok', a token ADR-0024 D1 admits"
  fi
done

fixture "$WORK/bad.md" 'automated / standing: zz-not-a-category'
OUT="$(bash "$DEVICE" "$WORK/bad.md" 2>&1)"; RC=$?
if [ "$RC" -eq 1 ] && grep -qF 'zz-not-a-category' <<<"$OUT"; then
  pass "ENFORCES-REJECTS: a token outside D1's closed list is reported by name and fails — the set relation ADR-0024:159-161 requires"
else
  failc "ENFORCES-REJECTS: rc=$RC on an out-of-list token; $(tr '\n' ' ' <<<"$OUT" | cut -c1-300)"
fi

echo
echo "=============================================="
echo "PASS: $PASS  FAIL: $FAIL"
echo "=============================================="
[ "$FAIL" -eq 0 ] || exit 1
exit 0
