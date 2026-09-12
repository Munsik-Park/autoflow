#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: setup/init.sh setup/manifest.json setup/thin-root-layer/drift-check.sh plugin/autoflow/skills/install/scripts/detect.sh plugin/autoflow/skills/install/SKILL.md docs/tool-delivery-contract.md setup/SETUP-GUIDE.md README.md
# budget-secs: SUITE_BUDGET_CEILING_SECS
# =============================================================================
# Test: issue #236 — a re-stamp reconciles the target against the manifest it
#       previously installed. Before this change `setup/init.sh --target`
#       applied only the new manifest's rows, so an artifact upstream dropped
#       (#228 / a72e265: scripts/test/green-tree-*.sh, suite-coverage.sh)
#       stayed on the target after the 0.2.3 re-stamp and was removed by hand
#       (connev-llm/llmroute#629). R4 already named the manifest as the
#       authority for removal; no device performed it.
# =============================================================================
# Subjects:
#   setup/init.sh                        — reconcile_removed: previous installed
#                                          manifest vs new manifest by dest;
#                                          remove a `copy` whose on-disk sha256
#                                          equals the previous manifest's, keep
#                                          and name everything else
#   setup/thin-root-layer/drift-check.sh — D4 `removed-upstream` WARN forecasts
#                                          the re-stamp instead of "does not
#                                          remove it"
#   plugin/autoflow/skills/install/scripts/detect.sh — STALE_COUNT /
#                                          STALE_UPSTREAM= lines for the skill's
#                                          pre-confirmation disclosure
#   SKILL.md / R4 / SETUP-GUIDE / README  — describe the new behaviour
#
# Cases (AC ids from the issue):
#   AC1-REMOVED       previous-only `copy`, on-disk hash == previous manifest
#                     -> removed, `REMOVED: <dest>` printed
#   AC2-MODIFIED      previous-only `copy`, on-disk hash differs -> kept,
#                     `KEPT: <dest>` names the hash difference
#   AC2-NONCOPY       previous-only scaffold / shim-stamp / json-merge rows ->
#                     kept, `KEPT:` names the kind
#   AC2-NOHASH        previous-only `copy` with sha256 null -> kept
#   AC2-UNSAFE        previous-only `copy` whose dest escapes the target ->
#                     not touched, `KEPT:` names the unsafe dest
#   AC3-ABSENT        previous-only `copy` already gone -> `ABSENT:` line
#   AC3-SUMMARY       the count line reports removed / kept / absent
#   AC4-NO-PREV       first stamp (no installed manifest) -> nothing removed,
#                     a pre-existing unrelated file survives
#   AC4-UNREADABLE    installed manifest is not JSON -> nothing removed, WARN,
#                     exit 0, the new manifest is installed
#   IDEMPOTENT        same-version re-stamp -> no REMOVED line, "No artifact
#                     left behind"
#   D4-FORECAST-RM    clone drops a copy row, on-disk unchanged -> WARN says a
#                     re-stamp removes it
#   D4-FORECAST-KEEP  clone drops a copy row, on-disk modified -> WARN says a
#                     re-stamp keeps it
#   D4-NONCOPY        clone drops the scaffold row -> WARN says never removed
#   D4-OLD-PHRASE     "a re-stamp does not remove it" is gone from drift-check
#   DET-STALE         detect.sh carries the WARN as STALE_COUNT=1 +
#                     STALE_UPSTREAM= naming the dest
#   DET-NONE          a matching clone -> STALE_COUNT=0, no STALE_UPSTREAM=
#   DOC-*             R4, SETUP-GUIDE, README, SKILL.md describe the rule
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

INIT_SH="$REPO_ROOT/setup/init.sh"
MANIFEST="$REPO_ROOT/setup/manifest.json"
DRIFT_SRC="$REPO_ROOT/setup/thin-root-layer/drift-check.sh"
DETECT_SH="$REPO_ROOT/plugin/autoflow/skills/install/scripts/detect.sh"
SKILL_MD="$REPO_ROOT/plugin/autoflow/skills/install/SKILL.md"
CONTRACT_MD="$REPO_ROOT/docs/tool-delivery-contract.md"
GUIDE_MD="$REPO_ROOT/setup/SETUP-GUIDE.md"
README_MD="$REPO_ROOT/README.md"
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

# run_drift <target> [VAR=value ...] — the installed detector; DRIFT_OUT / DRIFT_RC.
run_drift() {
  local t="$1"; shift
  DRIFT_OUT=$(env CLAUDE_PROJECT_DIR="$t" "$@" sh "$t/.claude/autoflow/drift-check.sh" 2>&1)
  DRIFT_RC=$?
}

# mk_clone <dir> <jq-filter> — a marketplace clone whose manifest is the real
# one under <filter>, with the real drift-check oracle (detect.sh runs it).
mk_clone() {
  mkdir -p "$1/setup/thin-root-layer" "$1/.claude-plugin" "$1/scripts/lib"
  jq "$2" "$MANIFEST" > "$1/setup/manifest.json"
  cp "$DRIFT_SRC" "$1/setup/thin-root-layer/drift-check.sh"
  cp "$REPO_ROOT/scripts/lib/plugin-root.sh" "$1/scripts/lib/plugin-root.sh"
  cp "$REPO_ROOT/.claude-plugin/marketplace.json" "$1/.claude-plugin/marketplace.json"
}

# run_detect <target> <clone> — DETECT_OUT / DETECT_RC.
run_detect() {
  DETECT_OUT=$(TARGET_ROOT="$1" PLUGIN_CACHE_ROOT="$2" bash "$DETECT_SH" 2>&1)
  DETECT_RC=$?
}

# A copy row every real manifest carries, to drop from a synthetic clone.
COPY_DEST="scripts/lib/plugin-root.sh"

echo "=== Issue #236 — re-stamp reconciles the previous installed manifest ==="

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
  H_OWNED="$(sha "$T1/scripts/test/stale-owned.sh")"
  jq --arg h "$H_OWNED" '
    .version = "0.0.1"
    | .artifacts += [
        {source:"x", dest:"scripts/test/stale-owned.sh",  tier:"root-layer", kind:"copy",       sha256:$h},
        {source:"x", dest:"scripts/test/stale-edited.sh", tier:"root-layer", kind:"copy",       sha256:"0000000000000000000000000000000000000000000000000000000000000000"},
        {source:"x", dest:"scripts/test/stale-nohash.sh", tier:"root-layer", kind:"copy",       sha256:null},
        {source:"x", dest:"scripts/test/stale-gone.sh",   tier:"root-layer", kind:"copy",       sha256:"1111111111111111111111111111111111111111111111111111111111111111"},
        {source:"x", dest:"../escape.sh",                 tier:"root-layer", kind:"copy",       sha256:"2222222222222222222222222222222222222222222222222222222222222222"},
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

  if printf '%s\n' "$STAMP_OUT" | grep -q '^ABSENT: scripts/test/stale-gone.sh (copy; already absent'; then
    pass "AC3-ABSENT: a previous-only copy already gone from disk is reported as ABSENT"
  else
    failc "AC3-ABSENT: $(printf '%s\n' "$STAMP_OUT" | grep 'stale-gone' | head -1)"
  fi

  if printf '%s\n' "$STAMP_OUT" | grep -q 'Reconciled against the previous installed manifest: 1 removed, 6 kept, 1 already absent'; then
    pass "AC3-SUMMARY: the count line reports 1 removed / 6 kept / 1 already absent"
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

# ── D4 forecast wording ──────────────────────────────────────────────────────
echo "== D4: the removed-upstream WARN forecasts what the re-stamp does =="
T3="$WORK/t-d4"; stamp "$T3"
if [ ! -f "$T3/.claude/autoflow/drift-check.sh" ]; then
  failc "SETUP: stamp into $T3 did not deliver drift-check.sh"
else
  C_RM="$WORK/clone-drop-copy"
  mk_clone "$C_RM" 'del(.artifacts[] | select(.dest == "'"$COPY_DEST"'"))'
  run_drift "$T3" AUTOFLOW_MARKETPLACE_ROOT="$C_RM"
  if [ "$DRIFT_RC" -eq 0 ] && printf '%s\n' "$DRIFT_OUT" | grep -q "^WARN: D4 -- installed artifact no longer shipped upstream: $COPY_DEST (copy, on-disk sha256 equals the installed manifest's — a re-stamp removes it)"; then
    pass "D4-FORECAST-RM: an unmodified copy upstream dropped -> WARN says a re-stamp removes it (exit 0)"
  else
    failc "D4-FORECAST-RM: rc=$DRIFT_RC; $(printf '%s\n' "$DRIFT_OUT" | grep 'no longer shipped' | head -1)"
  fi

  T4="$WORK/t-d4-mod"; stamp "$T4"
  printf '\n# local edit\n' >> "$T4/$COPY_DEST"
  run_drift "$T4" AUTOFLOW_MARKETPLACE_ROOT="$C_RM"
  if printf '%s\n' "$DRIFT_OUT" | grep -q "^WARN: D4 -- installed artifact no longer shipped upstream: $COPY_DEST (copy, on-disk content differs from the installed manifest or is not the shipped file — a re-stamp keeps it"; then
    pass "D4-FORECAST-KEEP: a modified copy upstream dropped -> WARN says a re-stamp keeps it"
  else
    failc "D4-FORECAST-KEEP: $(printf '%s\n' "$DRIFT_OUT" | grep 'no longer shipped' | head -1)"
  fi

  C_SC="$WORK/clone-drop-scaffold"
  mk_clone "$C_SC" 'del(.artifacts[] | select(.dest == ".claude/autoflow/spawn-policy.json"))'
  run_drift "$T3" AUTOFLOW_MARKETPLACE_ROOT="$C_SC"
  if [ "$DRIFT_RC" -eq 0 ] && printf '%s\n' "$DRIFT_OUT" | grep -q '^WARN: D4 -- installed artifact no longer shipped upstream: .claude/autoflow/spawn-policy.json (scaffold — a re-stamp never removes a scaffold artifact'; then
    pass "D4-NONCOPY: a scaffold upstream dropped -> WARN says a re-stamp never removes it"
  else
    failc "D4-NONCOPY: rc=$DRIFT_RC; $(printf '%s\n' "$DRIFT_OUT" | grep 'no longer shipped' | head -1)"
  fi

  if ! grep -q 'a re-stamp does not remove it' "$DRIFT_SRC"; then
    pass "D4-OLD-PHRASE: the pre-#236 wording 'a re-stamp does not remove it' is gone from drift-check.sh"
  else
    failc "D4-OLD-PHRASE: drift-check.sh still says 'a re-stamp does not remove it'"
  fi

  # ── detect.sh carries the WARN for the skill's pre-confirmation disclosure ──
  echo "== detect.sh: STALE_COUNT / STALE_UPSTREAM= =="
  run_detect "$T3" "$C_RM"
  if [ "$DETECT_RC" -eq 0 ] && printf '%s\n' "$DETECT_OUT" | grep -q '^STALE_COUNT=1$' \
     && printf '%s\n' "$DETECT_OUT" | grep -q "^STALE_UPSTREAM=$COPY_DEST (copy, on-disk sha256 equals the installed manifest's — a re-stamp removes it)$"; then
    pass "DET-STALE: detect.sh reports STALE_COUNT=1 and a STALE_UPSTREAM= line naming the dest and the forecast"
  else
    failc "DET-STALE: rc=$DETECT_RC; $(printf '%s\n' "$DETECT_OUT" | grep '^STALE' | tr '\n' ' ')"
  fi
  if printf '%s\n' "$DETECT_OUT" | grep -q '^DRIFT_STATE=clean$'; then
    pass "DET-STALE-NOT-DRIFT: the removed-upstream WARN does not move DRIFT_STATE (clean)"
  else
    failc "DET-STALE-NOT-DRIFT: $(printf '%s\n' "$DETECT_OUT" | grep '^DRIFT_STATE' )"
  fi

  C_EQ="$WORK/clone-equal"
  mk_clone "$C_EQ" '.'
  run_detect "$T3" "$C_EQ"
  if printf '%s\n' "$DETECT_OUT" | grep -q '^STALE_COUNT=0$' && ! printf '%s\n' "$DETECT_OUT" | grep -q '^STALE_UPSTREAM='; then
    pass "DET-NONE: a clone equal to the installed manifest -> STALE_COUNT=0, no STALE_UPSTREAM= line"
  else
    failc "DET-NONE: $(printf '%s\n' "$DETECT_OUT" | grep '^STALE' | tr '\n' ' ')"
  fi
fi

# ── Docs ─────────────────────────────────────────────────────────────────────
echo "== DOC: R4 / SETUP-GUIDE / README / SKILL.md describe the reconciliation =="
if grep -q 'reconciles\*\* the target against the manifest it' "$CONTRACT_MD" && grep -q 'issue #236' "$CONTRACT_MD" \
   && grep -q 'kind `copy`, on-disk sha256 equal to the previous manifest' "$CONTRACT_MD"; then
  pass "DOC-CONTRACT: R4 states the reconciliation rule (copy + equal sha256 removed; the rest kept and reported)"
else
  failc "DOC-CONTRACT: docs/tool-delivery-contract.md R4 does not state the #236 reconciliation rule"
fi
if grep -q 'A re-stamp also \*\*reconciles\*\*' "$GUIDE_MD" && grep -q 'REMOVED:' "$GUIDE_MD" && grep -q 'KEPT:' "$GUIDE_MD" \
   && ! grep -q 'an artifact upstream no longer ships is a `WARN` you dispose of by hand' "$GUIDE_MD"; then
  pass "DOC-SETUP-GUIDE: the re-stamp section and the D4 row describe removal by ownership and the REMOVED:/KEPT: lines"
else
  failc "DOC-SETUP-GUIDE: setup/SETUP-GUIDE.md does not describe the #236 re-stamp reconciliation, or still says D4's dropped artifact is disposed of by hand"
fi
if grep -q 'A re-stamp also' "$README_MD" && grep -q 'when their content is still what AutoFlow shipped' "$README_MD"; then
  pass "DOC-README: README names the re-stamp removal"
else
  failc "DOC-README: README.md does not name the re-stamp removal"
fi
STEP1=$(awk '/^## Step 1/{f=1} /^## Step 2/{f=0} f' "$SKILL_MD")
STEP4=$(awk '/^## Step 4/{f=1} f' "$SKILL_MD")
if printf '%s\n' "$STEP1" | grep -q 'STALE_UPSTREAM=' && printf '%s\n' "$STEP1" | grep -q 'before Step 3'; then
  pass "DOC-SKILL-STEP1: Step 1 discloses the STALE_UPSTREAM= lines before the confirmation"
else
  failc "DOC-SKILL-STEP1: SKILL.md Step 1 does not disclose STALE_UPSTREAM= before Step 3"
fi
if printf '%s\n' "$STEP4" | grep -q 'REMOVED: <dest>' && printf '%s\n' "$STEP4" | grep -q 'Reconciled artifacts (issue #236)' \
   && printf '%s\n' "$STEP4" | grep -q 'git -C "\$TARGET_ROOT" grep -n -I --untracked'; then
  pass "DOC-SKILL-STEP4: Step 4 reports the REMOVED:/KEPT: lines dest by dest and runs the read-only reference probe"
else
  failc "DOC-SKILL-STEP4: SKILL.md Step 4 lacks the reconciled-artifacts report or the reference probe"
fi

echo ""
echo "=== Summary: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
