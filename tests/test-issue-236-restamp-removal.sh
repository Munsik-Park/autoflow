#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# Test: a re-stamp reconciles the target against the manifest it previously
#       installed (packaging — the install script's stamp). `setup/init.sh
#       --target` removes an artifact upstream dropped when its on-disk content
#       is still what AutoFlow shipped, and keeps and names everything else.
# =============================================================================
# Subject: setup/init.sh > reconcile_removed — previous installed manifest vs
# new manifest by dest; remove a `copy` whose on-disk sha256 equals the
# previous manifest's, keep and name everything else.
#
# Cases:
#   AC1-REMOVED       previous-only `copy`, on-disk hash == previous manifest
#                     -> removed, `REMOVED: <dest>` printed
#   AC2-MODIFIED      previous-only `copy`, on-disk hash differs -> kept,
#                     `KEPT: <dest>` names the hash difference
#   AC2-NONCOPY       previous-only scaffold / shim-stamp / json-merge rows ->
#                     kept, `KEPT:` names the kind
#   AC2-NOHASH        previous-only `copy` with sha256 null -> kept
#   AC2-UNSAFE        previous-only `copy` whose dest escapes the target ->
#                     not touched, `KEPT:` names the unsafe dest
#   AC2-SYMLINK-DIR   previous-only `copy` under a parent that is a symlink to
#                     outside the target, outside file's hash == previous
#                     manifest -> outside file survives, `KEPT:` names the
#                     symlink
#   AC2-SYMLINK-LEAF  previous-only `copy` that is itself a symlink -> kept
#   AC3-ABSENT        previous-only `copy` already gone -> `ABSENT:` line
#   AC3-SUMMARY       the count line reports removed / kept / absent
#   AC3-MANIFEST      the new manifest replaces the previous one
#   AC4-NO-PREV       first stamp (no installed manifest) -> nothing removed,
#                     a pre-existing unrelated file survives
#   AC4-UNREADABLE    installed manifest is not JSON -> nothing removed, WARN,
#                     exit 0, the new manifest is installed
#   IDEMPOTENT        same-version re-stamp -> no REMOVED line, "No artifact
#                     left behind"
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

INIT_SH="$REPO_ROOT/setup/init.sh"
MANIFEST="$REPO_ROOT/setup/manifest.json"
CUR_VER="$(jq -r '.version' "$MANIFEST")"

PASS=0; FAIL=0
pass()  { echo "  PASS: $1"; PASS=$((PASS + 1)); }
failc() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT INT TERM

# Hermetic: no real plugin registry or clone leaks into a verdict.
export CLAUDE_CONFIG_DIR="$WORK/empty-config"
mkdir -p "$CLAUDE_CONFIG_DIR"
unset CLAUDE_PLUGIN_ROOT AUTOFLOW_MARKETPLACE_ROOT

sha() { shasum -a 256 "$1" 2>/dev/null | awk '{print $1}'; }

# stamp <target> — a real init.sh stamp; sets STAMP_OUT / STAMP_RC.
stamp() {
  mkdir -p "$1"
  STAMP_OUT=$(bash "$INIT_SH" --target "$1" 2>&1)
  STAMP_RC=$?
}

echo "=== re-stamp reconciles the previous installed manifest ==="

# ── AC4-NO-PREV: first stamp removes nothing ─────────────────────────────────
echo "== AC4-NO-PREV: first stamp (no installed manifest) — nothing reconciled =="
T0="$WORK/t-first"; mkdir -p "$T0/scripts/test"
printf 'mine\n' > "$T0/scripts/test/mine.sh"
stamp "$T0"
if [ "$STAMP_RC" -eq 0 ] && [ -f "$T0/scripts/test/mine.sh" ] \
   && printf '%s\n' "$STAMP_OUT" | grep -q 'No previous installed manifest' \
   && ! printf '%s\n' "$STAMP_OUT" | grep -q '^REMOVED: '; then
  pass "AC4-NO-PREV: no installed manifest -> nothing removed, an unrelated pre-existing file survives"
else
  failc "AC4-NO-PREV: rc=$STAMP_RC mine.sh=$([ -f "$T0/scripts/test/mine.sh" ] && echo present || echo gone); $(printf '%s\n' "$STAMP_OUT" | grep -i 'previous\|REMOVED' | head -2 | tr '\n' ' ')"
fi

# ── The reconciliation arms: a stamped target whose installed manifest is
#    rewritten as a synthetic "previous" version carrying rows the real
#    manifest does not. ──────────────────────────────────────────────────────
echo "== AC1 / AC2 / AC3: re-stamp over a synthetic previous manifest =="
T1="$WORK/t-prev"; stamp "$T1"
if [ "$STAMP_RC" -ne 0 ] || [ ! -f "$T1/.claude/autoflow/manifest.json" ]; then
  failc "SETUP: initial stamp into $T1 failed (rc=$STAMP_RC)"
else
  mkdir -p "$T1/scripts/test" "$T1/cfg"
  printf 'owned by autoflow\n'   > "$T1/scripts/test/stale-owned.sh"
  printf 'edited by the target\n' > "$T1/scripts/test/stale-edited.sh"
  printf 'no hash\n'             > "$T1/scripts/test/stale-nohash.sh"
  printf 'scaffold\n'            > "$T1/cfg/stale-scaffold.json"
  printf 'merged\n'              > "$T1/cfg/stale-merged.json"
  printf 'shim\n'                > "$T1/STALE-SHIM.md"
  printf 'outside\n'             > "$WORK/escape.sh"
  mkdir -p "$WORK/outside-dir"
  printf 'retired, outside the target\n' > "$WORK/outside-dir/retired.sh"
  ln -s ../../outside-dir "$T1/scripts/retired-dir"       # target/scripts/retired-dir -> $WORK/outside-dir
  printf 'link target\n' > "$T1/scripts/test/link-target.sh"
  ln -s link-target.sh "$T1/scripts/test/stale-link.sh"
  H_OWNED="$(sha "$T1/scripts/test/stale-owned.sh")"
  H_RETIRED="$(sha "$WORK/outside-dir/retired.sh")"
  H_LINK="$(sha "$T1/scripts/test/link-target.sh")"
  jq --arg h "$H_OWNED" --arg hr "$H_RETIRED" --arg hl "$H_LINK" '
    .version = "0.0.1"
    | .artifacts += [
        {source:"x", dest:"scripts/test/stale-owned.sh",  tier:"root-layer", kind:"copy",       sha256:$h},
        {source:"x", dest:"scripts/test/stale-edited.sh", tier:"root-layer", kind:"copy",       sha256:"0000000000000000000000000000000000000000000000000000000000000000"},
        {source:"x", dest:"scripts/test/stale-nohash.sh", tier:"root-layer", kind:"copy",       sha256:null},
        {source:"x", dest:"scripts/test/stale-gone.sh",   tier:"root-layer", kind:"copy",       sha256:"1111111111111111111111111111111111111111111111111111111111111111"},
        {source:"x", dest:"../escape.sh",                 tier:"root-layer", kind:"copy",       sha256:"2222222222222222222222222222222222222222222222222222222222222222"},
        {source:"x", dest:"scripts/retired-dir/retired.sh", tier:"root-layer", kind:"copy",     sha256:$hr},
        {source:"x", dest:"scripts/test/stale-link.sh",   tier:"root-layer", kind:"copy",       sha256:$hl},
        {source:"x", dest:"cfg/stale-scaffold.json",      tier:"root-layer", kind:"scaffold",   sha256:"3333333333333333333333333333333333333333333333333333333333333333"},
        {source:"x", dest:"cfg/stale-merged.json",        tier:"root-layer", kind:"json-merge", sha256:"4444444444444444444444444444444444444444444444444444444444444444"},
        {source:"x", dest:"STALE-SHIM.md",                tier:"root-layer", kind:"shim-stamp", sha256:"5555555555555555555555555555555555555555555555555555555555555555"}
      ]' "$T1/.claude/autoflow/manifest.json" > "$WORK/prev.json" \
    && mv "$WORK/prev.json" "$T1/.claude/autoflow/manifest.json"
  stamp "$T1"

  if [ "$STAMP_RC" -eq 0 ] && [ ! -e "$T1/scripts/test/stale-owned.sh" ] \
     && printf '%s\n' "$STAMP_OUT" | grep -q '^REMOVED: scripts/test/stale-owned.sh (copy; sha256 matched the previous manifest'; then
    pass "AC1-REMOVED: a previous-only copy whose on-disk sha256 equals the previous manifest's is removed and named"
  else
    failc "AC1-REMOVED: rc=$STAMP_RC present=$([ -e "$T1/scripts/test/stale-owned.sh" ] && echo yes || echo no); $(printf '%s\n' "$STAMP_OUT" | grep 'stale-owned' | head -1)"
  fi

  if [ -f "$T1/scripts/test/stale-edited.sh" ] \
     && printf '%s\n' "$STAMP_OUT" | grep -q '^KEPT: scripts/test/stale-edited.sh (copy; sha256 differs from the previous manifest'; then
    pass "AC2-MODIFIED: a previous-only copy whose on-disk sha256 differs is kept, the line names the difference"
  else
    failc "AC2-MODIFIED: present=$([ -f "$T1/scripts/test/stale-edited.sh" ] && echo yes || echo no); $(printf '%s\n' "$STAMP_OUT" | grep 'stale-edited' | head -1)"
  fi

  _nc_ok=1
  for _row in "cfg/stale-scaffold.json:scaffold" "cfg/stale-merged.json:json-merge" "STALE-SHIM.md:shim-stamp"; do
    _d="${_row%%:*}"; _k="${_row##*:}"
    [ -f "$T1/$_d" ] || _nc_ok=0
    printf '%s\n' "$STAMP_OUT" | grep -q "^KEPT: $_d ($_k; " || _nc_ok=0
  done
  if [ "$_nc_ok" = 1 ] && ! printf '%s\n' "$STAMP_OUT" | grep '^KEPT: ' | grep -E 'scaffold|json-merge|shim-stamp' | grep -qv 'never removes'; then
    pass "AC2-NONCOPY: scaffold / json-merge / shim-stamp rows are kept, each line naming the kind and that a re-stamp never removes it"
  else
    failc "AC2-NONCOPY: $(printf '%s\n' "$STAMP_OUT" | grep -E 'stale-scaffold|stale-merged|STALE-SHIM' | tr '\n' ' ')"
  fi

  if [ -f "$T1/scripts/test/stale-nohash.sh" ] \
     && printf '%s\n' "$STAMP_OUT" | grep -q '^KEPT: scripts/test/stale-nohash.sh (copy; the previous manifest records no sha256'; then
    pass "AC2-NOHASH: a previous-only copy with no recorded sha256 is kept (ownership unconfirmable)"
  else
    failc "AC2-NOHASH: $(printf '%s\n' "$STAMP_OUT" | grep 'stale-nohash' | head -1)"
  fi

  if [ -f "$WORK/escape.sh" ] \
     && printf '%s\n' "$STAMP_OUT" | grep -q '^KEPT: \.\./escape\.sh (copy; unsafe dest'; then
    pass "AC2-UNSAFE: a dest that escapes the target is never touched and is named as unsafe"
  else
    failc "AC2-UNSAFE: escape.sh present=$([ -f "$WORK/escape.sh" ] && echo yes || echo no); $(printf '%s\n' "$STAMP_OUT" | grep 'escape' | head -1)"
  fi

  if [ -f "$WORK/outside-dir/retired.sh" ] && [ -L "$T1/scripts/retired-dir" ] \
     && printf '%s\n' "$STAMP_OUT" | grep -q '^KEPT: scripts/retired-dir/retired.sh (copy; a symlink on the path or a parent outside the target'; then
    pass "AC2-SYMLINK-DIR: a parent symlinked outside the target is refused even with a matching hash — the outside file survives"
  else
    failc "AC2-SYMLINK-DIR: outside present=$([ -f "$WORK/outside-dir/retired.sh" ] && echo yes || echo no); $(printf '%s\n' "$STAMP_OUT" | grep 'retired' | head -1)"
  fi

  if [ -L "$T1/scripts/test/stale-link.sh" ] && [ -f "$T1/scripts/test/link-target.sh" ] \
     && printf '%s\n' "$STAMP_OUT" | grep -q '^KEPT: scripts/test/stale-link.sh (copy; a symlink on the path'; then
    pass "AC2-SYMLINK-LEAF: a previous-only copy that is itself a symlink is kept, its link target untouched"
  else
    failc "AC2-SYMLINK-LEAF: $(printf '%s\n' "$STAMP_OUT" | grep 'stale-link' | head -1)"
  fi

  if printf '%s\n' "$STAMP_OUT" | grep -q '^ABSENT: scripts/test/stale-gone.sh (copy; already absent'; then
    pass "AC3-ABSENT: a previous-only copy already gone from disk is reported as ABSENT"
  else
    failc "AC3-ABSENT: $(printf '%s\n' "$STAMP_OUT" | grep 'stale-gone' | head -1)"
  fi

  if printf '%s\n' "$STAMP_OUT" | grep -q 'Reconciled against the previous installed manifest: 1 removed, 8 kept, 1 already absent'; then
    pass "AC3-SUMMARY: the count line reports 1 removed / 8 kept / 1 already absent"
  else
    failc "AC3-SUMMARY: $(printf '%s\n' "$STAMP_OUT" | grep 'Reconciled' | head -1)"
  fi

  if [ "$(jq -r '.version' "$T1/.claude/autoflow/manifest.json")" = "$CUR_VER" ]; then
    pass "AC3-MANIFEST: the new manifest ($CUR_VER) replaced the previous one after reconciliation"
  else
    failc "AC3-MANIFEST: installed manifest version is $(jq -r '.version' "$T1/.claude/autoflow/manifest.json"), expected $CUR_VER"
  fi

  # ── IDEMPOTENT: a same-version re-stamp reconciles nothing ──
  stamp "$T1"
  if [ "$STAMP_RC" -eq 0 ] && printf '%s\n' "$STAMP_OUT" | grep -q "No artifact left behind by the previous installed manifest ($CUR_VER -> $CUR_VER)" \
     && ! printf '%s\n' "$STAMP_OUT" | grep -q '^REMOVED: ' && [ -f "$T1/scripts/test/stale-edited.sh" ]; then
    pass "IDEMPOTENT: a same-version re-stamp removes nothing and says so"
  else
    failc "IDEMPOTENT: rc=$STAMP_RC; $(printf '%s\n' "$STAMP_OUT" | grep -i 'left behind\|REMOVED' | head -2 | tr '\n' ' ')"
  fi
fi

# ── AC4-UNREADABLE: an installed manifest that is not JSON removes nothing ──
echo "== AC4-UNREADABLE: unreadable installed manifest -> nothing removed =="
T2="$WORK/t-unreadable"; stamp "$T2"
mkdir -p "$T2/scripts/test"; printf 'stale\n' > "$T2/scripts/test/stale.sh"
printf '{ not json' > "$T2/.claude/autoflow/manifest.json"
stamp "$T2"
if [ "$STAMP_RC" -eq 0 ] && [ -f "$T2/scripts/test/stale.sh" ] \
   && printf '%s\n' "$STAMP_OUT" | grep -q 'Previous installed manifest .* could not be read .* nothing removed' \
   && [ "$(jq -r '.version' "$T2/.claude/autoflow/manifest.json" 2>/dev/null)" = "$CUR_VER" ]; then
  pass "AC4-UNREADABLE: unreadable previous manifest -> WARN, nothing removed, exit 0, new manifest installed"
else
  failc "AC4-UNREADABLE: rc=$STAMP_RC stale=$([ -f "$T2/scripts/test/stale.sh" ] && echo present || echo gone) ver=$(jq -r '.version' "$T2/.claude/autoflow/manifest.json" 2>/dev/null); $(printf '%s\n' "$STAMP_OUT" | grep -i 'previous' | head -1)"
fi

echo ""
echo "=== Summary: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
