#!/bin/sh
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# Test: thin-root-layer acceptance suite
# =============================================================================
# Packaging and manifest checks over the thin-root layer's shipped sources:
# the CLAUDE.md @import shim, the .claude/workflows scripts, and the committed
# settings pin. Plain POSIX sh + jq/grep/awk/shasum only -- no bats, no new
# runtime dependency.
#
#   AC1a/AC1b  packaging  the shim carries exactly one pinned import line, inside
#                         the AUTOFLOW-IMPORT fence setup/init.sh re-stamps by
#   AC2b       packaging  both root-layer workflow scripts exist at their
#                         manifest source paths
#   AC4a       packaging  settings-pin.json is valid JSON and registers the
#                         autoflow marketplace
#              manifest   the pin's marketplace name matches marketplace.json .name
#   AC1 M-leg / AC4 dual-hash
#              manifest   the manifest copy and json-merge rows both pin the
#                         current settings-pin.json sha256
# =============================================================================

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)

SHIM="$REPO_ROOT/setup/thin-root-layer/claude-md-shim.md"
PIN="$REPO_ROOT/setup/thin-root-layer/settings-pin.json"
MARKETPLACE="$REPO_ROOT/.claude-plugin/marketplace.json"
IMPORT_LINE='@./.claude/autoflow/METHODOLOGY.md'

PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  printf 'PASS: %s\n' "$1"
}

failc() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf 'FAIL: %s -- %s\n' "$1" "$2"
}

skipc() {
  SKIP_COUNT=$((SKIP_COUNT + 1))
  printf 'SKIP: %s -- %s\n' "$1" "$2"
}

# ── AC1a: shim artifact exists, exactly one pinned import line ─────────────
echo "== AC1a: CLAUDE.md @import shim artifact =="
if [ -f "$SHIM" ]; then
  pass "AC1a: setup/thin-root-layer/claude-md-shim.md exists"
  IMPORT_COUNT=$(grep -cF "$IMPORT_LINE" "$SHIM" 2>/dev/null || echo 0)
  if [ "$IMPORT_COUNT" -eq 1 ]; then
    pass "AC1a: exactly one pinned import line '$IMPORT_LINE'"
  else
    failc "AC1a" "import line count=$IMPORT_COUNT (expected 1) for literal '$IMPORT_LINE'"
  fi
else
  failc "AC1a" "shim artifact missing at $SHIM"
fi

# ── AC1b: marker fence + import-line-inside-markers keystone ───────────────
echo "== AC1b: AUTOFLOW-IMPORT marker fence (non-vacuity: import line INSIDE markers) =="
if [ -f "$SHIM" ]; then
  BEGIN_LINE=$(grep -n 'AUTOFLOW-IMPORT:BEGIN' "$SHIM" | head -1 | cut -d: -f1)
  END_LINE=$(grep -n 'AUTOFLOW-IMPORT:END' "$SHIM" | head -1 | cut -d: -f1)
  if [ -n "$BEGIN_LINE" ] && [ -n "$END_LINE" ] && [ "$BEGIN_LINE" -lt "$END_LINE" ]; then
    pass "AC1b: BEGIN/END markers present and BEGIN precedes END"
    BETWEEN=$(awk -v b="$BEGIN_LINE" -v e="$END_LINE" 'NR>b && NR<e' "$SHIM")
    if [ -n "$BETWEEN" ] && printf '%s\n' "$BETWEEN" | grep -qF "$IMPORT_LINE"; then
      pass "AC1b keystone: the import line sits strictly BETWEEN the markers (non-empty range, contains import)"
    else
      failc "AC1b keystone" "import line not found strictly between BEGIN/END (range content: '$BETWEEN')"
    fi
  else
    failc "AC1b" "markers missing or BEGIN does not precede END (begin_line=$BEGIN_LINE end_line=$END_LINE)"
  fi
else
  failc "AC1b" "shim artifact missing at $SHIM"
fi

# ── AC2b: both root-layer workflow scripts exist ───────────────────────────
echo "== AC2b: root-layer workflow scripts present at their manifest source paths =="
if [ -f "$REPO_ROOT/.claude/workflows/architect-deliberation.js" ] && [ -f "$REPO_ROOT/.claude/workflows/verify-cause-branch.js" ]; then
  pass "AC2b: both source workflow scripts exist at .claude/workflows/"
else
  failc "AC2b" "one or both source workflow scripts missing under .claude/workflows/"
fi

# ── AC4a: settings-pin artifact + no-skew cross-check ──────────────────────
echo "== AC4a: settings-pin.json artifact =="
if [ -f "$PIN" ] && jq -e . "$PIN" >/dev/null 2>&1; then
  pass "AC4a: setup/thin-root-layer/settings-pin.json exists and is valid JSON"
  EKM=$(jq -r '.extraKnownMarketplaces["autoflow"] // empty' "$PIN")
  # The pin always asserts at least the marketplace entry. This is not an
  # incidental presence check: D1's json-merge leg is the fixed-point test
  # `(.[0] * .[1]) == .[0]`, whose discriminating power is exactly the number
  # of keys the pin asserts -- at zero keys it passes against any settings file
  # whatsoever.
  if [ -n "$EKM" ] && [ "$EKM" != "null" ]; then
    pass "AC4a: extraKnownMarketplaces.autoflow present (the pin is never empty -- D1's json-merge leg keeps a subject to discriminate)"
  else
    failc "AC4a" "extraKnownMarketplaces.autoflow missing -- an empty pin makes D1's json-merge leg pass against any settings file whatsoever"
  fi
  if [ -f "$MARKETPLACE" ] && jq -e . "$MARKETPLACE" >/dev/null 2>&1; then
    MP_NAME=$(jq -r '.name // empty' "$MARKETPLACE")
    PIN_MP_KEY=$(jq -r '.extraKnownMarketplaces | keys[0] // empty' "$PIN")
    if [ -n "$PIN_MP_KEY" ] && [ "$PIN_MP_KEY" = "$MP_NAME" ]; then
      pass "AC4a keystone (re-anchored, issue #245): the pin's marketplace name '$PIN_MP_KEY' matches marketplace.json's declared .name (no skew)"
    else
      failc "AC4a keystone" "the pin's marketplace name '$PIN_MP_KEY' != marketplace.json .name '$MP_NAME' -- the two-file no-skew fact lost the witness the retired composed <plugin>@<marketplace> token used to carry"
    fi
  else
    failc "AC4a keystone" "marketplace.json missing/invalid at $MARKETPLACE — cannot cross-check"
  fi
else
  failc "AC4a" "settings-pin.json missing or invalid JSON at $PIN"
fi

# ── AC1 M-leg / AC4 dual-hash: manifest hash conformance, side-effect-free
# read-only form. Recompute the pin's sha256 ONCE and assert BOTH the manifest
# "copy" row (dest .claude/autoflow/settings-pin.json) AND the "json-merge" row
# (dest .claude/settings.json) equal it. Never runs
# setup/gen-manifest-hashes.sh (it overwrites setup/manifest.json
# unconditionally) -- pure JSON/hash read, no working-tree mutation.
echo "== AC1 M-leg / AC4 dual-hash (issue #963): manifest copy+json-merge rows both pin the current settings-pin.json sha256 =="
MANIFEST_JSON="$REPO_ROOT/setup/manifest.json"
if [ -f "$PIN" ] && [ -f "$MANIFEST_JSON" ]; then
  if command -v shasum >/dev/null 2>&1; then
    PIN_SHA=$(shasum -a 256 "$PIN" | awk '{print $1}')
  else
    PIN_SHA=$(sha256sum "$PIN" | awk '{print $1}')
  fi
  COPY_SHA=$(jq -r '[.artifacts[] | select(.kind == "copy" and .dest == ".claude/autoflow/settings-pin.json")][0].sha256 // empty' "$MANIFEST_JSON")
  MERGE_SHA=$(jq -r '[.artifacts[] | select(.kind == "json-merge" and .dest == ".claude/settings.json")][0].sha256 // empty' "$MANIFEST_JSON")
  if [ -n "$PIN_SHA" ] && [ "$COPY_SHA" = "$PIN_SHA" ]; then
    pass "AC1 M-leg: manifest copy row (dest .claude/autoflow/settings-pin.json) sha256 == current shasum -a 256 of settings-pin.json"
  else
    failc "AC1 M-leg" "manifest copy row sha256 ('$COPY_SHA') != current settings-pin.json sha256 ('$PIN_SHA')"
  fi
  if [ -n "$PIN_SHA" ] && [ "$MERGE_SHA" = "$PIN_SHA" ]; then
    pass "AC4 dual-hash: manifest json-merge row (dest .claude/settings.json) sha256 == current shasum -a 256 of settings-pin.json"
  else
    failc "AC4 dual-hash" "manifest json-merge row sha256 ('$MERGE_SHA') != current settings-pin.json sha256 ('$PIN_SHA')"
  fi
else
  failc "AC1 M-leg / AC4 dual-hash" "settings-pin.json ($PIN) or manifest.json ($MANIFEST_JSON) missing"
fi

# ── Summary ───────────────────────────────────────────────────────────────
echo "=============================================="
echo "RESULT: $PASS_COUNT passed, $FAIL_COUNT failed, $SKIP_COUNT skipped (of $((PASS_COUNT + FAIL_COUNT)) checks)"
if [ "$FAIL_COUNT" -gt 0 ]; then
  exit 1
fi
exit 0
