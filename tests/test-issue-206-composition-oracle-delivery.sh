#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: scripts/architect/composition-oracle.sh docs/autoflow-guide.md setup/manifest.json setup/init.sh
# lane: cycle-scoped
# retire-with: #206
# cycle-arm: #206
# budget-secs: SUITE_BUDGET_CEILING_SECS
# =============================================================================
# Delivery check: the composition-oracle classifier reaches stamped targets at
# the path the stamped guide gives (issue #206, D7)
# =============================================================================
# Verification-design row: Issue AC `—`, disposition `delivery-check`. RED/GREEN
# semantics do not apply; it asserts this cycle's landed delivery and retires
# with #206.
#
# Failure mode no other layer catches: the script is not delivered to stamped
# targets at the path the stamped guide gives. tests/test-composition-oracle.sh
# runs the script in this repository, test/workflows/run.mjs reads the Record
# prompt, the existing real-stamp suites deliver only rows already listed, and
# E1d only limits which files a stamp may create.
#
# Oracle: a real `setup/init.sh --target` stamp into a scratch target; delivery
# is decided on the stamped tree, never on a manifest row.
#   D-stamp  the stamp exits 0 non-interactively;
#   D-guide  the stamped guide's `#### Composition oracle` clause names the
#            classifier's path;
#   D-found  a regular file exists at that path in the stamped target;
#   D-runs   the stamped copy, run from the target root over a well-formed
#            record, prints a classifying `result:` line under a status outside
#            {1, 2, 126, 127}. A delivered script whose own dependencies were
#            not delivered leaves the same absent output D7 names.
# =============================================================================

set -uo pipefail

# The paths of this cycle's landed diff the check asserts over: the classifier,
# the clause that tells a target to run it, and the manifest row that ships it.
allow_list=(
  "scripts/architect/composition-oracle.sh"
  "docs/autoflow-guide.md"
  "setup/manifest.json"
)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INIT_SH="$PROJECT_ROOT/setup/init.sh"
CLASSIFIER="${allow_list[0]}"
STAMPED_GUIDE=".claude/autoflow/docs/autoflow-guide.md"

PASS=0; FAIL=0
pass()  { echo "  PASS: $1"; PASS=$((PASS + 1)); }
failc() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

TGT="$(mktemp -d)"
trap 'rm -rf "$TGT"' EXIT

echo "== D-stamp: setup/init.sh --target <scratch> exits 0 non-interactively =="
stamp_log="$(bash "$INIT_SH" --target "$TGT" </dev/null 2>&1)"; stamp_rc=$?
if [ "$stamp_rc" -eq 0 ]; then
  pass "D-stamp: the stamp exited 0"
else
  failc "D-stamp: the stamp exited $stamp_rc: $(tail -n 3 <<<"$stamp_log")"
fi

echo "== D-guide: the stamped guide's Composition oracle clause names $CLASSIFIER =="
clause=""
if [ -f "$TGT/$STAMPED_GUIDE" ]; then
  clause="$(awk '/^#### Composition oracle[[:space:]]*$/ { f = 1; next } f && /^(#|##|###|####) / { exit } f { print }' "$TGT/$STAMPED_GUIDE")"
fi
if [ -z "$clause" ]; then
  failc "D-guide: the stamped target carries no '#### Composition oracle' clause at $STAMPED_GUIDE"
elif grep -qF -- "$CLASSIFIER" <<<"$clause"; then
  pass "D-guide: the stamped clause names $CLASSIFIER"
else
  failc "D-guide: the stamped clause names no $CLASSIFIER — a target is not told to run the classifier at its path"
fi

echo "== D-found: a regular file at $CLASSIFIER in the stamped target =="
if [ -f "$TGT/$CLASSIFIER" ]; then
  pass "D-found: $CLASSIFIER is present in the stamped target"
else
  failc "D-found: $CLASSIFIER is absent from the stamped target"
fi

echo "== D-runs: the stamped copy classifies a well-formed record from the target root =="
cat > "$TGT/record.md" <<'MD'
## Composition oracle

```composition-oracle
T:
- t1 | D1
S:
- t1 | docs/adr/0018-verification-depth-justification.md
```
MD
run_out="$(cd "$TGT" && bash "$CLASSIFIER" record.md 2>/dev/null)"; run_rc=$?
case " 1 2 126 127 " in
  *" $run_rc "*) generic=1 ;;
  *)             generic=0 ;;
esac
if [ "$generic" -eq 0 ] && grep -qE '^result: (intersection|empty)([[:space:]].*)?$' <<<"$run_out"; then
  pass "D-runs: the stamped copy ran to a classifying result (exit $run_rc)"
else
  failc "D-runs: the stamped copy did not run to a classifying result — exit $run_rc, stdout line 1: '$(sed -n 1p <<<"$run_out")'"
fi

echo
echo "Tests: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
