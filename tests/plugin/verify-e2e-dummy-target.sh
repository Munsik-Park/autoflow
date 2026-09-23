#!/bin/sh
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# Test: throwaway dummy-target E2E suite
# =============================================================================
# Stamps the thin-root bundle into a realistic, zero-submodule dummy library
# target -- its own git history, a foreign package.json/src/ payload, a README
# and a pre-existing CLAUDE.md -- and checks that the install lands intact and
# resolves from the installed location. Plain POSIX sh + jq/cmp/grep/awk/git
# only (no bats, no node/npm).
#
# Legs (category):
#
#   W-E1 install into the dummy target (packaging):
#     E1a   make_dummy_target() yields a realistic, zero-submodule fixture (the
#           precondition E1c-E1e rest on)
#     E1b   `setup/init.sh --target <dummy> </dev/null` exits 0 (non-interactive)
#     E1c   pre-existing CLAUDE.md prose survives + shim fence present
#     E1d   the foreign payload stays byte-unchanged and every new file lands
#           under a dest class the manifest's copy rows install to
#     E1e   second install run is idempotent (single fence, byte-identical)
#
#   W-E2 installed-bundle host purity (hygiene, retained):
#     E2a   installed .claude/autoflow/** host-purity-tokens.txt hits are a
#           RATCHET against tests/fixtures/e2e-bundle-purity-baseline.txt (no
#           new offender beyond the baseline; no baseline entry gone clean
#           without a ratchet-down edit)
#
#   W-E3 installed manifest closure and clean drift-check (packaging):
#     E3a   every kind:copy manifest dest exists on disk in the installed target
#     E3a-x shipped methodology-step scripts are installed executable
#     E3b   installed drift-check.sh exits 0 on the clean install (in-target)
#     E3c   no installed file embeds the source repo's path, and the installed
#           drift-check.sh still exits 0 with the source repo out of reach
#
#   W-E4 installed settings wiring and gate-hook smoke (packaging):
#     E4w   the post-install .claude/settings.json carries the marketplace
#           wiring (extraKnownMarketplaces) via assert_marketplace_wiring()
#     E4w-nv  negative self-test: assert_marketplace_wiring() FAILs on a
#           settings copy with extraKnownMarketplaces dropped
#     E4b   the packaged gate hook, invoked once, returns a decision: a benign
#           command is allowed (exit 0)
# =============================================================================

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)

INIT_SH="$REPO_ROOT/setup/init.sh"
MANIFEST="$REPO_ROOT/setup/manifest.json"
HOOK="$REPO_ROOT/plugin/autoflow/hooks/check-autoflow-gate.sh"
TOKENS="$REPO_ROOT/tests/fixtures/host-purity-tokens.txt"
E2A_BASELINE="$REPO_ROOT/tests/fixtures/e2e-bundle-purity-baseline.txt"
IMPORT_LINE='@./.claude/autoflow/METHODOLOGY.md'

PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

pass()  { PASS_COUNT=$((PASS_COUNT + 1)); printf 'PASS: %s\n' "$1"; }
failc() { FAIL_COUNT=$((FAIL_COUNT + 1)); printf 'FAIL: %s [stage:%s] -- %s\n' "$1" "$2" "$3"; }
skipc() { SKIP_COUNT=$((SKIP_COUNT + 1)); printf 'SKIP: %s [stage:%s] -- %s\n' "$1" "$2" "$3"; }

# ── Helpers ───────────────────────────────────────────────────────────────────

sha256_of() {
  _h=$(shasum -a 256 "$1" 2>/dev/null | awk '{print $1}')
  [ -n "$_h" ] || _h=$(sha256sum "$1" 2>/dev/null | awk '{print $1}')
  printf '%s' "$_h"
}

# make_dummy_target <dir> — byte-reproducible generator (EA-FIX-a) of a
# structurally-real, zero-submodule dummy JS-style library: its own git
# history, a foreign package.json/src/ payload, README.md, and a pre-existing
# CLAUDE.md with prose OUTSIDE any AUTOFLOW fence. No .gitmodules (zero
# submodules -> single-repo topology per CLAUDE.md > Deployment Topology).
make_dummy_target() {
  _dir="$1"
  mkdir -p "$_dir/src"
  cat > "$_dir/package.json" <<'PKGJSON'
{
  "name": "throwaway-lib",
  "version": "0.0.0",
  "private": true,
  "description": "throwaway dummy library target for claude-autoflow's #797 E2E suite"
}
PKGJSON
  cat > "$_dir/src/index.js" <<'INDEXJS'
// throwaway-lib -- trivial pre-existing library source (foreign payload).
module.exports = function add(a, b) {
  return a + b;
};
INDEXJS
  cat > "$_dir/README.md" <<'READMEMD'
# throwaway-lib

A throwaway, non-deployed dummy library target used only by claude-autoflow's
#797 E2E regression. Not a real package; never published.
READMEMD
  cat > "$_dir/CLAUDE.md" <<'CLAUDEMD'
# throwaway-lib operating notes

This is the target project's OWN pre-existing prose, authored before any
AutoFlow install. It lives outside any AUTOFLOW-IMPORT fence and must survive
the shim stamp untouched.
CLAUDEMD
  ( cd "$_dir" \
    && git init -q \
    && git -c user.email=test@example.com -c user.name=test add -A \
    && git -c user.email=test@example.com -c user.name=test commit -q -m "initial commit (dummy target)" \
  )
}

# gate_bash_json <command> — synthesize a PreToolUse Bash payload.
gate_bash_json() {
  printf '{"tool_name":"Bash","tool_input":{"command":%s}}' "$(printf '%s' "$1" | jq -Rs .)"
}

# assert_marketplace_wiring <settings-json-path> — shared E4w/E4w-nv
# predicate (narrowed by issue #245): true iff the given
# settings file has extraKnownMarketplaces["autoflow"].source.repo ==
# "Munsik-Park/autoflow" -- an explicit value comparison, not `// empty`
# truthiness, so a dropped key FAILs rather than silently passing.
#
# It asserts that the install-time MARKETPLACE wiring landed. It does NOT
# assert that the plugin will load: after issue #245 there is no target-local
# witness of enablement at all, because enablement is user-scope state outside
# the repository that neither the installer nor the detector can reach. That
# is a real reduction in what a stamped target can self-verify, accepted
# deliberately as the price of removing the project-scope-record generator and
# written down here rather than left to be inferred from a check that quietly
# disappeared. If this suite ever gains a real loader invocation, provisioning
# user scope becomes legitimate in the same moment.
assert_marketplace_wiring() {
  _ape_settings="$1"
  [ -f "$_ape_settings" ] || return 1
  jq -e '
    (.extraKnownMarketplaces["autoflow"].source.repo == "Munsik-Park/autoflow")
  ' "$_ape_settings" >/dev/null 2>&1
}

# ── Temp targets ──────────────────────────────────────────────────────────────
DUMMY=$(mktemp -d)         # primary: E1a-e, E2a, E3a/b, E4w, E4b
SNAP_DIR=$(mktemp -d)      # E1d: pre-install snapshots of foreign payload
PRE_LIST_FILE=$(mktemp)
POST_LIST_FILE=$(mktemp)
CLAUDE_SNAP1=$(mktemp)
RELOC_PARENT=$(mktemp -d)  # E3c: relocated-target independence check
E2A_CURRENT=$(mktemp)      # E2a: current installed-bundle offender set (sorted)
E2A_BASELINE_SORTED=$(mktemp)  # E2a: committed ratchet baseline, normalized+sorted
SETTINGS_NV=$(mktemp)      # E4w-nv: scratch settings copy with the asserted pin key dropped

cleanup() {
  rm -rf "$DUMMY" "$SNAP_DIR" "$PRE_LIST_FILE" "$POST_LIST_FILE" \
         "$CLAUDE_SNAP1" "$RELOC_PARENT" \
         "$E2A_CURRENT" "$E2A_BASELINE_SORTED" "$SETTINGS_NV"
}
# Hermetic plugin discovery (issue #167): drift-check.sh D2/D4/D5 resolve the
# installed plugin and the marketplace clone through scripts/lib/plugin-root.sh
# from ${CLAUDE_CONFIG_DIR:-~/.claude}/plugins. Point that at an empty scratch
# dir so a developer machine's real plugin cache / marketplace clone never
# leaks into a clean-install exit-0 or a D2 SKIP expectation below; a leg that
# needs a plugin root passes CLAUDE_PLUGIN_ROOT explicitly.
HERMETIC_CONFIG_DIR=$(mktemp -d)
export CLAUDE_CONFIG_DIR="$HERMETIC_CONFIG_DIR"
unset CLAUDE_PLUGIN_ROOT AUTOFLOW_MARKETPLACE_ROOT
trap 'cleanup; rm -rf "$HERMETIC_CONFIG_DIR"' EXIT INT TERM

# ══════════════════════════════════════════════════════════════════════════════
# W-E1 — install into the dummy target
# ══════════════════════════════════════════════════════════════════════════════

echo "== E1a: make_dummy_target() yields a realistic, zero-submodule fixture =="
make_dummy_target "$DUMMY"
if [ -f "$DUMMY/package.json" ] && [ -d "$DUMMY/src" ] && [ -f "$DUMMY/README.md" ]; then
  pass "E1a: package.json + src/ + README.md present (foreign payload)"
else
  failc "E1a" "S5/#792" "package.json/src/README.md not all present in $DUMMY"
fi
if [ -s "$DUMMY/CLAUDE.md" ] && ! grep -qF 'AUTOFLOW-IMPORT:BEGIN' "$DUMMY/CLAUDE.md"; then
  pass "E1a: pre-existing non-empty CLAUDE.md with no AUTOFLOW fence yet"
else
  failc "E1a" "S5/#792" "CLAUDE.md missing, empty, or already fenced pre-install"
fi
if [ ! -e "$DUMMY/.gitmodules" ]; then
  pass "E1a: no .gitmodules (zero-submodule -> single-repo topology)"
else
  failc "E1a" "S5/#792" ".gitmodules present in generated fixture (not zero-submodule)"
fi

# Pre-install snapshots (E1d) — captured before E1b's install runs.
cp "$DUMMY/package.json" "$SNAP_DIR/package.json"
cp "$DUMMY/src/index.js" "$SNAP_DIR/index.js"
cp "$DUMMY/README.md" "$SNAP_DIR/README.md"
( cd "$DUMMY" && find . -type f -not -path './.git/*' | sort ) > "$PRE_LIST_FILE"

echo "== E1b: non-interactive install into the realistic dummy target =="
DRIVE_PASS=0
if [ -f "$INIT_SH" ]; then
  DRIVE_OUT=$(bash "$INIT_SH" --target "$DUMMY" </dev/null 2>&1)
  DRIVE_CODE=$?
  if [ "$DRIVE_CODE" -eq 0 ]; then
    pass "E1b: init.sh --target exits 0 non-interactively against the realistic fixture"
    DRIVE_PASS=1
  else
    failc "E1b" "S5/#792" "init.sh --target exited $DRIVE_CODE; first line: $(printf '%s\n' "$DRIVE_OUT" | head -1)"
  fi
else
  failc "E1b" "S5/#792" "setup/init.sh missing at $INIT_SH"
fi

DUMMY_CLAUDE="$DUMMY/CLAUDE.md"

echo "== E1c: pre-existing CLAUDE.md prose survives + shim fence present =="
if [ "$DRIVE_PASS" -eq 1 ] && [ -f "$DUMMY_CLAUDE" ]; then
  if grep -qF 'OWN pre-existing prose' "$DUMMY_CLAUDE"; then
    pass "E1c: pre-existing target prose survives install"
  else
    failc "E1c" "S5/#792" "pre-existing CLAUDE.md prose lost after install"
  fi
  BEGIN_L=$(grep -n 'AUTOFLOW-IMPORT:BEGIN' "$DUMMY_CLAUDE" 2>/dev/null | head -1 | cut -d: -f1)
  END_L=$(grep -n 'AUTOFLOW-IMPORT:END' "$DUMMY_CLAUDE" 2>/dev/null | head -1 | cut -d: -f1)
  if [ -n "$BEGIN_L" ] && [ -n "$END_L" ] && [ "$BEGIN_L" -lt "$END_L" ]; then
    BETWEEN=$(awk -v b="$BEGIN_L" -v e="$END_L" 'NR>b && NR<e' "$DUMMY_CLAUDE")
    if printf '%s\n' "$BETWEEN" | grep -qF "$IMPORT_LINE"; then
      pass "E1c: AUTOFLOW-IMPORT fence present with the @-import inside"
    else
      failc "E1c" "S5/#792" "import line not found strictly between fence markers"
    fi
  else
    failc "E1c" "S5/#792" "AUTOFLOW-IMPORT:BEGIN/END markers missing or malformed"
  fi
else
  failc "E1c" "S5/#792" "prerequisite E1b failed or CLAUDE.md absent"
fi

echo "== E1d: installer disturbs only .claude/**, CLAUDE.md fence, CLAUDE.local.md, scripts/review/**, scripts/preflight/**, scripts/handoff/**, scripts/cleanup/**, scripts/issue/**, scripts/ledger/**, scripts/gate/**, scripts/test/**, tests/lib/**, .codex/**, AGENTS.md =="
if [ "$DRIVE_PASS" -eq 1 ]; then
  if cmp -s "$SNAP_DIR/package.json" "$DUMMY/package.json"; then
    pass "E1d: package.json byte-unchanged"
  else
    failc "E1d" "S5/#792" "package.json was modified by install (genericity violated)"
  fi
  if cmp -s "$SNAP_DIR/index.js" "$DUMMY/src/index.js"; then
    pass "E1d: src/index.js byte-unchanged"
  else
    failc "E1d" "S5/#792" "src/index.js was modified by install (genericity violated)"
  fi
  if cmp -s "$SNAP_DIR/README.md" "$DUMMY/README.md"; then
    pass "E1d: README.md byte-unchanged"
  else
    failc "E1d" "S5/#792" "README.md was modified by install (genericity violated)"
  fi
  ( cd "$DUMMY" && find . -type f -not -path './.git/*' | sort ) > "$POST_LIST_FILE"
  NEW_FILES=$(comm -13 "$PRE_LIST_FILE" "$POST_LIST_FILE")
  BAD_NEW=""
  # The admitted dest classes are where the manifest's root-layer copy and
  # scaffold rows install outside .claude/, each with its source path preserved
  # (scripts/<dir>/*, tests/lib/*, .codex/review.md, AGENTS.md). On a real
  # repository some of these paths pre-exist; the E1a fixture starts without
  # them, so install genuinely creates them here.
  for _nf in $NEW_FILES; do
    case "$_nf" in
      ./.claude/*|./CLAUDE.local.md|./scripts/review/*|./scripts/preflight/*|./scripts/handoff/*|./scripts/cleanup/*|./scripts/issue/*|./scripts/ledger/*|./scripts/spawn-policy/*|./scripts/lib/*|./scripts/architect/*|./scripts/gate/*|./scripts/test/*|./tests/lib/*|./.codex/*|./AGENTS.md) : ;;
      *) BAD_NEW="$BAD_NEW $_nf" ;;
    esac
  done
  if [ -z "$BAD_NEW" ]; then
    pass "E1d: every newly-created path is under .claude/**, CLAUDE.local.md, scripts/review/**, scripts/preflight/**, scripts/handoff/**, scripts/cleanup/**, scripts/issue/**, scripts/ledger/**, scripts/spawn-policy/**, scripts/lib/**, scripts/architect/**, scripts/gate/**, scripts/test/**, tests/lib/**, .codex/**, or AGENTS.md"
  else
    failc "E1d" "S5/#792" "install created file(s) outside .claude//CLAUDE.local.md/scripts/review//scripts/preflight//scripts/handoff//scripts/cleanup//scripts/issue//scripts/ledger//scripts/spawn-policy//scripts/lib//.codex//AGENTS.md:$BAD_NEW"
  fi
else
  failc "E1d" "S5/#792" "skipped -- prerequisite E1b failed"
fi

echo "== E1e: second install run is idempotent (single fence, byte-identical) =="
if [ "$DRIVE_PASS" -eq 1 ] && [ -f "$DUMMY_CLAUDE" ]; then
  cp "$DUMMY_CLAUDE" "$CLAUDE_SNAP1"
  bash "$INIT_SH" --target "$DUMMY" </dev/null >/dev/null 2>&1
  _cnt=$(grep -c 'AUTOFLOW-IMPORT:BEGIN' "$DUMMY_CLAUDE" 2>/dev/null || printf '0')
  if [ "$_cnt" -eq 1 ]; then
    pass "E1e: exactly one AUTOFLOW-IMPORT:BEGIN after second run"
  else
    failc "E1e" "S5/#792" "BEGIN count=$_cnt after second run (not idempotent)"
  fi
  if cmp -s "$CLAUDE_SNAP1" "$DUMMY_CLAUDE"; then
    pass "E1e: CLAUDE.md byte-identical after second run"
  else
    failc "E1e" "S5/#792" "CLAUDE.md differs after second install run"
  fi
else
  failc "E1e" "S5/#792" "prerequisite E1b failed or CLAUDE.md absent"
fi

# ══════════════════════════════════════════════════════════════════════════════
# W-E2 — installed-bundle host purity
# ══════════════════════════════════════════════════════════════════════════════

echo "== E2a: installed .claude/autoflow/** host-purity-token hits are ratcheted against the committed baseline =="
# Ratchet-baseline arm (ledger E15): the installed bundle is NOT yet
# token-clean (epic #785 S11a/S11b burns this down). E2a therefore checks
# the CURRENT offender set against tests/fixtures/e2e-bundle-purity-baseline.txt
# in both directions instead of asserting an absolute zero-hit scan:
#   (a) no offender file may exist beyond the baseline (a NEW leak -> FAIL)
#   (b) no baseline entry may have gone clean (a stale, un-ratcheted-down
#       baseline entry -> FAIL, forcing a baseline edit)
if [ "$DRIVE_PASS" -eq 1 ] && [ -d "$DUMMY/.claude/autoflow" ] && [ -f "$TOKENS" ] && [ -f "$E2A_BASELINE" ]; then
  ( cd "$DUMMY" && grep -rliE -f "$TOKENS" ./.claude/autoflow 2>/dev/null | sed 's#^\./##' ) | sort > "$E2A_CURRENT"
  grep -v '^#' "$E2A_BASELINE" | grep -v '^[[:space:]]*$' | sort > "$E2A_BASELINE_SORTED"
  E2A_NEW_OFFENDERS=$(comm -23 "$E2A_CURRENT" "$E2A_BASELINE_SORTED")
  E2A_STALE_BASELINE=$(comm -13 "$E2A_CURRENT" "$E2A_BASELINE_SORTED")
  if [ -z "$E2A_NEW_OFFENDERS" ]; then
    pass "E2a(new): no installed-bundle offender beyond the committed ratchet baseline"
  else
    failc "E2a" "S2/#788" "new host-purity offender(s) not in tests/fixtures/e2e-bundle-purity-baseline.txt: $(printf '%s' "$E2A_NEW_OFFENDERS" | tr '\n' ' ')"
  fi
  if [ -z "$E2A_STALE_BASELINE" ]; then
    pass "E2a(stale): every ratchet-baseline entry still currently offends (baseline not stale)"
  else
    failc "E2a" "S2/#788" "baseline entry no longer offends -- ratchet it down in tests/fixtures/e2e-bundle-purity-baseline.txt: $(printf '%s' "$E2A_STALE_BASELINE" | tr '\n' ' ')"
  fi
else
  failc "E2a" "S2/#788" "installed .claude/autoflow absent, tokens fixture missing, or baseline fixture missing -- cannot scan"
fi

# ══════════════════════════════════════════════════════════════════════════════
# W-E3 — installed manifest closure and clean drift-check
# ══════════════════════════════════════════════════════════════════════════════

echo "== E3a: every kind:copy manifest dest exists on disk in the installed target =="
if [ "$DRIVE_PASS" -eq 1 ] && [ -f "$MANIFEST" ]; then
  MISSING_DESTS=""
  while IFS= read -r _dest; do
    [ -n "$_dest" ] || continue
    [ -f "$DUMMY/$_dest" ] || MISSING_DESTS="$MISSING_DESTS $_dest"
  done <<COPYDESTS
$(jq -r '.artifacts[] | select(.kind == "copy") | .dest' "$MANIFEST" 2>/dev/null)
COPYDESTS
  if [ -z "$MISSING_DESTS" ]; then
    pass "E3a: manifest<->installed-filesystem closure holds for every kind:copy entry"
  else
    failc "E3a" "S5/#792" "manifest kind:copy dest(s) missing on disk in target:$MISSING_DESTS"
  fi
else
  failc "E3a" "S5/#792" "prerequisite install failed or manifest.json absent"
fi

# ── E3a-x (issue #10): installed exec bit on the shipped methodology-step ─────
# scripts. init.sh copies via plain `cp` (no -p), so
# mode preservation is umask/platform-adjacent, not guaranteed by install
# logic; the Post-Merge Cleanup [MUST] wrapper invokes
# ./scripts/cleanup/cleanup-issue.sh <N> directly and the allow-list entry
# Bash(./scripts/cleanup/cleanup-issue.sh:*) presumes a +x delivered file.
echo "== E3a-x (issue #10): installed exec bit set on the new methodology-step script dests =="
if [ "$DRIVE_PASS" -eq 1 ]; then
  NOT_EXEC=""
  for _xdest in \
    "scripts/handoff/create-host-pr.sh" \
    "scripts/cleanup/cleanup-issue.sh"
  do
    if [ -f "$DUMMY/$_xdest" ]; then
      [ -x "$DUMMY/$_xdest" ] || NOT_EXEC="$NOT_EXEC $_xdest"
    else
      NOT_EXEC="$NOT_EXEC [missing:$_xdest]"
    fi
  done
  if [ -z "$NOT_EXEC" ]; then
    pass "E3a-x: all new methodology-step script dests are installed with the execute bit set"
  else
    failc "E3a-x" "#10" "dest(s) missing or not executable in installed target:$NOT_EXEC"
  fi
else
  failc "E3a-x" "#10" "prerequisite install failed"
fi

DUMMY_DRIFT="$DUMMY/.claude/autoflow/drift-check.sh"

echo "== E3b: installed drift-check.sh exits 0 on the clean install (in-target) =="
if [ -f "$DUMMY_DRIFT" ]; then
  E3B_OUT=$(CLAUDE_PROJECT_DIR="$DUMMY" sh "$DUMMY_DRIFT" 2>&1)
  E3B_CODE=$?
  if [ "$E3B_CODE" -eq 0 ]; then
    pass "E3b: installed drift-check.sh exits 0 on the clean in-target install"
  else
    failc "E3b" "S5/#792" "installed drift-check.sh exited $E3B_CODE on clean install; last line: $(printf '%s\n' "$E3B_OUT" | tail -1)"
  fi
else
  failc "E3b" "S5/#792" "drift-check.sh not installed at $DUMMY_DRIFT"
fi

echo "== E3c: installed drift-check.sh still exits 0 with the source repo relocated out of reach =="
if [ -f "$DUMMY_DRIFT" ]; then
  RELOC="$RELOC_PARENT/relocated-dummy"
  cp -R "$DUMMY" "$RELOC"
  _baked=$(grep -rlF "$REPO_ROOT" "$RELOC" 2>/dev/null)
  if [ -z "$_baked" ]; then
    pass "E3c: no installed file embeds the source repo's absolute path"
  else
    failc "E3c" "S5/#792" "installed file(s) embed the source repo path (hidden dependency): $_baked"
  fi
  E3C_OUT=$(cd "$RELOC_PARENT" && CLAUDE_PROJECT_DIR="$RELOC" sh "$RELOC/.claude/autoflow/drift-check.sh" 2>&1)
  E3C_CODE=$?
  if [ "$E3C_CODE" -eq 0 ]; then
    pass "E3c: relocated installed detector exits 0 with the source repo unreachable"
  else
    failc "E3c" "S5/#792" "relocated detector exited $E3C_CODE (source-repo dependency suspected); last line: $(printf '%s\n' "$E3C_OUT" | tail -1)"
  fi
else
  failc "E3c" "S5/#792" "drift-check.sh not installed -- cannot run relocation-independence check"
fi

# ══════════════════════════════════════════════════════════════════════════════
# W-E4 — installed settings wiring and gate-hook smoke
# ══════════════════════════════════════════════════════════════════════════════

DUMMY_SETTINGS="$DUMMY/.claude/settings.json"

echo "== E4w: post-init.sh target settings.json landed the marketplace wiring =="
if [ "$DRIVE_PASS" -eq 1 ] && assert_marketplace_wiring "$DUMMY_SETTINGS"; then
  pass "E4w: \$DUMMY/.claude/settings.json carries extraKnownMarketplaces for autoflow (install-time marketplace wiring landed; enablement is user-scope and is not asserted here)"
else
  failc "E4w" "single-repo-HANDOFF" "assert_marketplace_wiring failed on $DUMMY_SETTINGS -- settings-pin merge wiring did not land"
fi

echo "== E4w-nv: negative self-test -- assert_marketplace_wiring() FAILs on a tampered settings copy =="
if [ -f "$DUMMY_SETTINGS" ]; then
  jq 'del(.extraKnownMarketplaces["autoflow"])' "$DUMMY_SETTINGS" > "$SETTINGS_NV" 2>/dev/null
  if ! assert_marketplace_wiring "$SETTINGS_NV"; then
    pass "E4w-nv: assert_marketplace_wiring() rejects a settings copy with extraKnownMarketplaces dropped (E4w's predicate discriminates)"
  else
    failc "E4w-nv" "single-repo-HANDOFF" "assert_marketplace_wiring() wrongly accepted a settings copy with extraKnownMarketplaces dropped -- E4w would be vacuous"
  fi
else
  failc "E4w-nv" "single-repo-HANDOFF" "$DUMMY_SETTINGS missing -- cannot build the tampered scratch copy"
fi

# The allow case is the smoke: exit 0 cannot come from a script bash fails to
# parse, whose exit status (2) coincides with the deny status.
echo "== E4b: packaged gate hook smoke -- a benign command is allowed (exit 0) =="
if [ -f "$HOOK" ]; then
  E4B_OUT=$(printf '%s' "$(gate_bash_json 'ls')" | CLAUDE_PROJECT_DIR="$DUMMY" bash "$HOOK" 2>&1)
  E4B_CODE=$?
  if [ "$E4B_CODE" -eq 0 ]; then
    pass "E4b: installed gate hook runs and allows a benign command (exit 0)"
  else
    failc "E4b" "single-repo-HANDOFF" "installed gate hook did not return allow for a benign command (exit $E4B_CODE): $E4B_OUT"
  fi
else
  failc "E4b" "single-repo-HANDOFF" "gate hook missing at $HOOK"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo "=============================================="
echo "RESULT: $PASS_COUNT passed, $FAIL_COUNT failed, $SKIP_COUNT skipped (of $((PASS_COUNT + FAIL_COUNT)) checks)"
if [ "$FAIL_COUNT" -gt 0 ]; then
  exit 1
fi
exit 0
