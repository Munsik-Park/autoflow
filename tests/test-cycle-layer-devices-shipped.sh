#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: setup/manifest.json setup/gen-manifest-hashes.sh setup/init.sh scripts/gate/verification-layer-check.sh scripts/test/check-cycle-layer-index.sh
# budget-secs: SUITE_BUDGET_CEILING_SECS
# =============================================================================
# Test: the cycle-layer device is a bundle artifact — a fresh stamp delivers it,
#       byte-identical to the manifest's recorded hash, and it runs to a verdict
#       from the stamped tree — while the layer-token device stays home.
# =============================================================================
# STANDING suite (`automated / standing: cross-file`), subject-named.
#
# ADR-0024 D2's standing predicate that no `.autoflow/issue-{N}-local/` asset
# entered the merged tree (scripts/test/check-cycle-layer-index.sh) is every
# target's, delivered by S4 (issue #229): "installed on a newly stamped target
# and matching the manifest hash". The closed-list token check GATE:QUALITY runs
# over a verification design (scripts/gate/verification-layer-check.sh, ADR-0024
# D1) is this repository's own convention and is NOT delivered (issue #238): a
# target's retention is judged by the reviewer from the PR body, not by a token.
# Both directions are asserted — a delivered row that reaches the target, and an
# undelivered device that does not.
#
# WHY A STAMP AND NOT A MANIFEST READ. A manifest row is a promise; what a target
# executes is the file init.sh copied. The legs therefore stamp a scratch target
# and compare THREE hashes for the device — source, manifest row, installed copy
# — and then run it from the stamped tree: a file that is present but does not
# run is not delivered. The fixed-point property of the manifest as a whole is
# scripts/test/check-manifest-regen-clean.sh's; this suite is about these rows.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MANIFEST="$REPO_ROOT/setup/manifest.json"
INIT_SH="$REPO_ROOT/setup/init.sh"

PASS=0; FAIL=0
pass()  { echo "  PASS: $1"; PASS=$((PASS + 1)); }
failc() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }
sha() { shasum -a 256 "$1" | cut -d' ' -f1; }

DEVICES=(scripts/test/check-cycle-layer-index.sh)
NOT_SHIPPED=scripts/gate/verification-layer-check.sh

echo "=== ADR-0024 devices shipped (#229 AC7; #238 scope) ==="

if ! command -v jq >/dev/null 2>&1; then
  failc "jq is unavailable — the manifest cannot be read, and a skipped check is never a pass"
  echo "PASS: $PASS  FAIL: $FAIL"; exit 1
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT INT TERM
T="$WORK/target"; mkdir -p "$T"
export CLAUDE_CONFIG_DIR="$WORK/empty-config"; mkdir -p "$CLAUDE_CONFIG_DIR"
unset CLAUDE_PLUGIN_ROOT AUTOFLOW_MARKETPLACE_ROOT

if ! bash "$INIT_SH" --target "$T" >"$WORK/init.log" 2>&1; then
  failc "SETUP: setup/init.sh --target failed: $(tail -n 2 "$WORK/init.log" | tr '\n' ' ')"
  echo "PASS: $PASS  FAIL: $FAIL"; exit 1
fi

for d in "${DEVICES[@]}"; do
  row_sha="$(jq -r --arg s "$d" '.artifacts[] | select(.source == $s and .kind == "copy" and .dest == $s) | .sha256' "$MANIFEST")"
  if [ -n "$row_sha" ] && [ "$row_sha" != null ]; then
    pass "ROW: $d is a copy row with dest == source in setup/manifest.json"
  else
    failc "ROW: $d has no copy row (dest == source) in setup/manifest.json"
    continue
  fi
  if [ -f "$T/$d" ]; then
    pass "STAMPED: $d is delivered by a fresh stamp"
  else
    failc "STAMPED: $d is absent from the stamped target"
    continue
  fi
  src_sha="$(sha "$REPO_ROOT/$d")"; inst_sha="$(sha "$T/$d")"
  if [ "$src_sha" = "$row_sha" ] && [ "$inst_sha" = "$row_sha" ]; then
    pass "HASH: $d — source, manifest row and installed copy agree (${row_sha:0:12})"
  else
    failc "HASH: $d — source=${src_sha:0:12} manifest=${row_sha:0:12} installed=${inst_sha:0:12}"
  fi
done

# The layer-token device stays in this repository: no manifest row names it and
# no stamp delivers it (issue #238).
row_n="$(jq -r --arg s "$NOT_SHIPPED" '[.artifacts[] | select(.source == $s or .dest == $s)] | length' "$MANIFEST")"
if [ "$row_n" = 0 ]; then
  pass "NOT-SHIPPED: $NOT_SHIPPED has no row in setup/manifest.json"
else
  failc "NOT-SHIPPED: $NOT_SHIPPED has $row_n row(s) in setup/manifest.json — the layer-token check is this repository's convention, not a target's"
fi
if [ ! -e "$T/$NOT_SHIPPED" ]; then
  pass "NOT-SHIPPED: $NOT_SHIPPED is absent from the stamped target"
else
  failc "NOT-SHIPPED: $NOT_SHIPPED was delivered to the stamped target"
fi
if [ -x "$REPO_ROOT/$NOT_SHIPPED" ] && out="$(bash "$REPO_ROOT/$NOT_SHIPPED" --list-tokens 2>&1)" && [ -n "$out" ]; then
  pass "HOME: $NOT_SHIPPED still runs in this repository ($(printf '%s\n' "$out" | grep -c .) token(s))"
else
  failc "HOME: $NOT_SHIPPED does not run in this repository"
fi

# The delivered device runs to a verdict from the stamped tree — a delivered
# file that cannot execute there is not a delivered device.

git -C "$T" init -q && git -C "$T" -c user.email=t@example.invalid -c user.name=t -c commit.gpgsign=false add -A \
  && git -C "$T" -c user.email=t@example.invalid -c user.name=t -c commit.gpgsign=false commit -q -m stamp
out="$(cd "$T" && bash scripts/test/check-cycle-layer-index.sh 2>&1)"; rc=$?
if [ "$rc" -eq 0 ]; then
  pass "RUNS: check-cycle-layer-index.sh answers OK over the stamped target's index (no cycle-layer asset tracked)"
else
  failc "RUNS: check-cycle-layer-index.sh rc=$rc: $(head -n 2 <<<"$out" | tr '\n' ' ' | cut -c1-200)"
fi
mkdir -p "$T/.autoflow/issue-9-local" && printf '#!/bin/sh\nexit 0\n' > "$T/.autoflow/issue-9-local/ac1.sh"
git -C "$T" add -f .autoflow/issue-9-local/ac1.sh
out="$(cd "$T" && bash scripts/test/check-cycle-layer-index.sh 2>&1)"; rc=$?
if [ "$rc" -ne 0 ] && grep -qF 'issue-9-local/ac1.sh' <<<"$out"; then
  pass "RUNS: check-cycle-layer-index.sh names a cycle-layer asset forced into the stamped target's index"
else
  failc "RUNS: check-cycle-layer-index.sh did not name the forced asset (rc=$rc): $(head -n 2 <<<"$out" | tr '\n' ' ' | cut -c1-200)"
fi

echo
echo "=============================================="
echo "PASS: $PASS  FAIL: $FAIL"
echo "=============================================="
[ "$FAIL" -eq 0 ] || exit 1
exit 0
