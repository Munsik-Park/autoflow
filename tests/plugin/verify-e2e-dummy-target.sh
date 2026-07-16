#!/bin/sh
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# Test: throwaway dummy-target E2E acceptance suite — Issue #797 [#785-S10]
# =============================================================================
# Composes the already-CI-covered unit mechanisms (install, manifest, drift,
# host-purity, single-repo HANDOFF) into one re-runnable regression against a
# real, structurally-different, zero-submodule dummy library target — the
# PILOT gate before claude-autoflow itself becomes the first reversal case
# (S11a #798). Plain POSIX sh + jq/cmp/diff/grep/awk/git only (no bats, no
# node/npm), matching tests/plugin/verify-install-into-target.sh's harness form.
#
# This suite COMPOSES, it does not duplicate: install/manifest/drift/
# host-purity unit-level assertions stay owned by
# tests/plugin/verify-install-into-target.sh and
# tests/test-issue-788-host-purity-delta.sh (delegated below as whole-suite
# regressions). This suite's own new assertions are the composition-only
# surface — the realistic fixture, non-destructive install into pre-existing
# content, installed-fs manifest/drift parity, and the gate-hook scores-branch
# + host-script HANDOFF runtime arms (the plugin-delivered hook RESOLUTION path
# — ${CLAUDE_PLUGIN_ROOT} substitution — is owned by verify-package.sh AC4,
# :230-298, not here).
#
# Acceptance criteria (canonical IDs from
#   .autoflow/issue-797-feature-design.md §5, reconciled with
#   .autoflow/issue-797-verification-design.md §1):
#
#   W-E1 provisioning & install composition:
#     E1a   make_dummy_target() yields a realistic, zero-submodule fixture
#     E1b   `setup/init.sh --target <dummy> </dev/null` exits 0 (non-interactive)
#     E1c   pre-existing CLAUDE.md prose survives + shim fence present
#     E1d   installer disturbs only .claude/**, CLAUDE.md fence, CLAUDE.local.md,
#           scripts/review/**, scripts/preflight/**, scripts/handoff/**,
#           scripts/cleanup/**, .codex/**, AGENTS.md
#           (#979 reviewer-backend delivery, source-path-preserved dests,
#           ledger E12; scripts/handoff/**, scripts/cleanup/** widened for
#           issue #10 manifest-registration-gap fix)
#     E1e   second install run is idempotent (single fence, byte-identical)
#
#   W-E2 bundle-in-target host-purity (composition boundary of item 4):
#     E2a   installed .claude/autoflow/** host-purity-tokens.txt hits are a
#           RATCHET against tests/fixtures/e2e-bundle-purity-baseline.txt (no
#           new offender beyond the baseline; no baseline entry gone clean
#           without a ratchet-down edit) -- ledger E15, supersedes the
#           absolute zero-hit scan pending epic #785 S11a/S11b
#     E2b   this suite's own fixture-generator paths are not host-purity-scanned
#     E-Rc  tests/test-issue-788-host-purity-delta.sh whole-suite exits 0
#
#   W-E3 manifest & drift composition (boundary of items 5/6):
#     E3a   every kind:copy manifest dest exists on disk in the installed target
#     E3b   installed drift-check.sh exits 0 on the clean install (in-target)
#     E3c   installed drift-check.sh still exits 0 with the source repo relocated
#           out of reach (source/network independence in the composed context)
#     E3d   injected content drift -> installed drift-check.sh exits 1, D1 class
#           (non-vacuity arm guarding E3b/E3c)
#
#   W-E4 single-repo HANDOFF gate behavior (item 7, gate-hook scores-branch
#   composition; plugin-delivered hook RESOLUTION is verify-package.sh AC4,
#   :230-298 -- cross-referenced, not duplicated here):
#     E4w   (pre-assertion, before E4a) the dummy target's post-init.sh
#           .claude/settings.json actually landed the plugin-enable wiring
#           (enabledPlugins + extraKnownMarketplaces) via assert_plugin_enabled()
#     E4w-nv  (permanent negative self-test, immediately after E4w) a scratch
#           settings copy with enabledPlugins dropped -> assert_plugin_enabled()
#           FAILs (proves E4w's predicate discriminates a broken pin)
#     E4x   (issue #963 AC1 E-leg) the same post-init.sh settings.json also
#           carries env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS == "1" (Agent
#           Teams enablement, settings-pin.json)
#     E4x-nv  (permanent negative self-test, immediately after E4x) a scratch
#           settings copy with .env dropped -> the env predicate FAILs
#           (proves E4x's predicate discriminates a broken pin)
#     E4a   seeded PASS state -> `gh pr create` admitted (exit 0) via the
#           gate hook's scores-gated branch, driven with CLAUDE_PROJECT_DIR=<dummy>
#           against the plugin-package hook copy
#     E4b   `gh pr merge` denied unconditionally (exit 2)
#     E4c   `git push origin main` denied while active:true (exit 2)
#     E4d   NOT-passing AUDIT/GATE:QUALITY scores -> `gh pr create` denied (exit 2)
#     E4-claim  (after E4d) static self-check: the retired over-claim phrase
#           (see _E4CLAIM_PATTERN below) is absent whole-suite, and the
#           corrected claim + AC4 cross-reference are present in the W-E4 region
#     E4e   installed docs/autoflow-guide.md documents the single-repo
#           no-`blocked-by-subrepo`-label Merge-Sequencing rule
#
#   W-E4' HOST-runtime label observation (item-7 runtime gap):
#     E4f   `--no-subrepo-dep` invocation of the HOST create-host-pr.sh (run
#           under bash, a gh-stub on PATH) carries --draft + blocked-by-review,
#           NOT blocked-by-subrepo
#     E4g   contrast arm (same entrypoint, no flag) -> blocked-by-subrepo IS
#           present (non-vacuity guard on E4f)
#     E4h   no-merge invariant: the gh stub records no `gh pr merge` across
#           the E4f/E4g invocations (independently captured logs, via the
#           shared log_has_merge() helper)
#     E4h-nv  (permanent non-vacuity self-test, after E4h) a synthesized
#           E4f-window log carrying a `merge` token -> log_has_merge() detects it
#
#   W-E5 generalization-defect capture discipline (item 8):
#     E5a   F3 (manual-scenarios-797.md) exists, prescribes the live-LLM-cycle
#           pilot, carries the generalization-defect->S-stage/#-issue recording
#           template, and marks every deferred step NOT-automated with a reason
#     E5b   failc() self-attributes: a forced failure line carries both the
#           failing AC id and its owning-stage tag (self-tested)
#
#   W-R regression (baseline unaffected by this branch):
#     E-Ra  tests/plugin/verify-install-into-target.sh whole-suite exits 0
#     E-Rb  tests/plugin/verify-package.sh whole-suite exits 0
#
#   NOT automated (E/M types — see tests/plugin/manual-scenarios-797.md):
#     E-M1  a live AutoFlow LLM cycle reasoning-driven inside the dummy target
#     E-M2  a real `gh pr create` against a live GitHub remote from the target
#
# RED framing (feature §5 / verification §5): before this file exists, every
# EA-*/E-series assertion is unreachable (suite absent). Once authored, the
# composed mechanisms it drives (install/manifest/drift/host-purity/gate-hook/
# create-host-pr.sh) are already merged on `main` (#788, #790-#796 CLOSED), so
# a correct composition is expected to PASS immediately — a RED-state FAIL
# here would localize a genuine composition/ordering defect, which is
# precisely the surface #797 targets (verification §5 RED-first note). F2 (CI
# workflow wiring) is the only artifact this suite's authoring does not itself
# provide and is Developer-AI/GREEN scope.
# =============================================================================

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)

INIT_SH="$REPO_ROOT/setup/init.sh"
MANIFEST="$REPO_ROOT/setup/manifest.json"
HOOK="$REPO_ROOT/plugin/autoflow/hooks/check-autoflow-gate.sh"
TOKENS="$REPO_ROOT/tests/fixtures/host-purity-tokens.txt"
HOST_PURITY_PATHS="$REPO_ROOT/tests/fixtures/host-purity-paths.txt"
E2A_BASELINE="$REPO_ROOT/tests/fixtures/e2e-bundle-purity-baseline.txt"
CREATE_HOST_PR="$REPO_ROOT/scripts/handoff/create-host-pr.sh"
VERIFY_INSTALL="$REPO_ROOT/tests/plugin/verify-install-into-target.sh"
VERIFY_PACKAGE="$REPO_ROOT/tests/plugin/verify-package.sh"
HOST_PURITY_SUITE="$REPO_ROOT/tests/test-issue-788-host-purity-delta.sh"
MANUAL_SCENARIOS="$REPO_ROOT/tests/plugin/manual-scenarios-797.md"
SELF_PATH_REL="tests/plugin/verify-e2e-dummy-target.sh"
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

# glob_match <path> <glob> — scanner-equivalent glob semantics (per
# tests/fixtures/host-purity-paths.txt header): `**` matches any characters
# including `/`; a single `*` matches within one path segment (not `/`);
# every other character is literal.
glob_match() {
  _gm_pat_ere=$(printf '%s' "$2" \
    | sed -e 's/[.[\^$()+{}|]/\\&/g' \
          -e 's/\*\*/@@DBLSTAR@@/g' \
          -e 's/\*/[^\/]*/g' \
          -e 's/@@DBLSTAR@@/.*/g')
  printf '%s' "$1" | grep -qE "^${_gm_pat_ere}\$"
}

# path_is_host_scanned <repo-relative-path> — total per-path precedence
# (allow > exclude > include) per tests/fixtures/host-purity-paths.txt header.
# Prints "yes"/"no".
path_is_host_scanned() {
  _phs_path="$1"
  _phs_included=0; _phs_excluded=0; _phs_allowed=0
  while IFS= read -r _phs_line; do
    case "$_phs_line" in
      ''|'#'*) continue ;;
    esac
    _phs_kind=$(printf '%s' "$_phs_line" | awk '{print $1}')
    _phs_pat=$(printf '%s' "$_phs_line" | awk '{print $2}')
    [ -n "$_phs_pat" ] || continue
    case "$_phs_kind" in
      include) glob_match "$_phs_path" "$_phs_pat" && _phs_included=1 ;;
      exclude) glob_match "$_phs_path" "$_phs_pat" && _phs_excluded=1 ;;
      allow)   glob_match "$_phs_path" "$_phs_pat" && _phs_allowed=1 ;;
    esac
  done < "$HOST_PURITY_PATHS"
  if [ "$_phs_included" -eq 1 ] && [ "$_phs_excluded" -eq 0 ] && [ "$_phs_allowed" -eq 0 ]; then
    printf 'yes'
  else
    printf 'no'
  fi
}

# gate_bash_json <command> — synthesize a PreToolUse Bash payload.
gate_bash_json() {
  printf '{"tool_name":"Bash","tool_input":{"command":%s}}' "$(printf '%s' "$1" | jq -Rs .)"
}

# log_has_merge <log-file> — shared E4h/E4h-nv predicate (feature §4.2/DCR-4):
# true iff the captured gh-stub argv log contains a bare `merge` token. Both
# the real E4h no-merge assertion and the E4h-nv non-vacuity self-test invoke
# this exact helper, so the self-test exercises E4h's real code path instead
# of a re-typed parallel grep that could silently drift (e.g. lose `-x`).
log_has_merge() {
  grep -qix 'merge' "$1" 2>/dev/null
}

# assert_plugin_enabled <settings-json-path> — shared E4w/E4w-nv predicate
# (feature §3.2/DCR-5): true iff the given settings file has both
# enabledPlugins["autoflow@autoflow"] == true (explicit boolean
# comparison, not `// empty` truthiness -- a dropped key must FAIL, not
# silently pass) and extraKnownMarketplaces["autoflow"].source.repo ==
# "Munsik-Park/autoflow". Both the real E4w wiring pre-assertion and the
# E4w-nv negative self-test invoke this exact helper.
assert_plugin_enabled() {
  _ape_settings="$1"
  [ -f "$_ape_settings" ] || return 1
  jq -e '
    (.enabledPlugins["autoflow@autoflow"] == true)
    and (.extraKnownMarketplaces["autoflow"].source.repo == "Munsik-Park/autoflow")
  ' "$_ape_settings" >/dev/null 2>&1
}

# ── Temp targets ──────────────────────────────────────────────────────────────
DUMMY=$(mktemp -d)         # primary: E1a-e, E2a/b, E3a/b, E4w/a-e
DRIFT_DUMMY=$(mktemp -d)   # E3d: content-drift injection arm
SNAP_DIR=$(mktemp -d)      # E1d: pre-install snapshots of foreign payload
PRE_LIST_FILE=$(mktemp)
POST_LIST_FILE=$(mktemp)
CLAUDE_SNAP1=$(mktemp)
RELOC_PARENT=$(mktemp -d)  # E3c: relocated-target independence check
GH_LOG_F=$(mktemp)         # E4f/E4h: gh-stub argv recording (--no-subrepo-dep invocation)
GH_LOG_G=$(mktemp)         # E4g/E4h: gh-stub argv recording (default invocation)
GH_LOG_NV=$(mktemp)        # E4h-nv: synthesized E4f-window log carrying a forced merge token
MOCK_GH_DIR=$(mktemp -d)
BODY_FILE=$(mktemp)
E2A_CURRENT=$(mktemp)      # E2a: current installed-bundle offender set (sorted)
E2A_BASELINE_SORTED=$(mktemp)  # E2a: committed ratchet baseline, normalized+sorted
SETTINGS_NV=$(mktemp)      # E4w-nv: scratch settings copy with enabledPlugins dropped

cleanup() {
  rm -rf "$DUMMY" "$DRIFT_DUMMY" "$SNAP_DIR" "$PRE_LIST_FILE" "$POST_LIST_FILE" \
         "$CLAUDE_SNAP1" "$RELOC_PARENT" "$GH_LOG_F" "$GH_LOG_G" "$GH_LOG_NV" \
         "$MOCK_GH_DIR" "$BODY_FILE" \
         "$E2A_CURRENT" "$E2A_BASELINE_SORTED" "$SETTINGS_NV"
}
trap cleanup EXIT INT TERM

printf 'body\n' > "$BODY_FILE"

# gh stub — records argv (one element per line) when $GH_INVOCATION_LOG is set,
# then exits 0. Same technique as tests/issue-92/mock-gh (repo's established
# mocked-binary pattern), written independently here (host-script arms only).
MOCK_GH="$MOCK_GH_DIR/gh"
cat > "$MOCK_GH" <<'MOCKGH'
#!/bin/sh
if [ -n "${GH_INVOCATION_LOG:-}" ]; then
  for _a in "$@"; do printf '%s\n' "$_a" >> "$GH_INVOCATION_LOG"; done
fi
exit 0
MOCKGH
chmod +x "$MOCK_GH"

# ══════════════════════════════════════════════════════════════════════════════
# W-E1 — provisioning & install composition
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

echo "== E1d: installer disturbs only .claude/**, CLAUDE.md fence, CLAUDE.local.md, scripts/review/**, scripts/preflight/**, scripts/handoff/**, scripts/cleanup/**, .codex/**, AGENTS.md =="
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
  # #979 lockstep update (feature design §4 rows 1-6, §8 OQ3, GATE:PLAN PASS
  # avg 9.0, ledger E12): the reviewer-backend-selection delivery adds four
  # source-path-preserved dests outside .claude/ on a fresh (dummy) target --
  # scripts/review/, scripts/preflight/ (copy rows, mirrors the workflow-file
  # source-path-preserved precedent), .codex/review.md and AGENTS.md (copy +
  # scaffold rows; on a real repo these paths pre-exist, but the E1a dummy
  # fixture starts empty so install genuinely creates them here).
  # issue #10 widening (verification-design DCR-1 / feature design C4): the
  # manifest-registration-gap fix registers 4 methodology-step scripts the
  # stamped docs already instruct a consumer to run. scripts/preflight/scan-
  # cross-issue-recurrence.sh is already covered by the scripts/preflight/*
  # arm above; scripts/handoff/emit-cycle-digest.sh, scripts/handoff/create-
  # host-pr.sh, and scripts/cleanup/cleanup-issue.sh land under
  # scripts/handoff/** and scripts/cleanup/**, neither previously allow-
  # listed, so the case pattern is widened to admit these two new dest
  # classes (same source-path-preserved copy-row shape as scripts/review/*
  # and scripts/preflight/*).
  for _nf in $NEW_FILES; do
    case "$_nf" in
      ./.claude/*|./CLAUDE.local.md|./scripts/review/*|./scripts/preflight/*|./scripts/handoff/*|./scripts/cleanup/*|./.codex/*|./AGENTS.md) : ;;
      *) BAD_NEW="$BAD_NEW $_nf" ;;
    esac
  done
  if [ -z "$BAD_NEW" ]; then
    pass "E1d: every newly-created path is under .claude/**, CLAUDE.local.md, scripts/review/**, scripts/preflight/**, scripts/handoff/**, scripts/cleanup/**, .codex/**, or AGENTS.md"
  else
    failc "E1d" "S5/#792" "install created file(s) outside .claude//CLAUDE.local.md/scripts/review//scripts/preflight//scripts/handoff//scripts/cleanup//.codex//AGENTS.md:$BAD_NEW"
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
# W-E2 — bundle-in-target host-purity (composition boundary of item 4)
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

echo "== E2b: this suite's own fixture-generator path is not host-purity-scanned (self-clean) =="
if [ -f "$HOST_PURITY_PATHS" ]; then
  _scanned=$(path_is_host_scanned "$SELF_PATH_REL")
  if [ "$_scanned" = "no" ]; then
    pass "E2b: $SELF_PATH_REL is not classified host-owned by the DELTA-guard config scope (excluded via tests/**)"
  else
    failc "E2b" "S2/#788" "$SELF_PATH_REL is classified host-owned -- adding this E2E would trip the DELTA guard"
  fi
else
  failc "E2b" "S2/#788" "host-purity-paths.txt missing at $HOST_PURITY_PATHS"
fi

echo "== E-Rc: tests/test-issue-788-host-purity-delta.sh whole-suite regression =="
if [ -f "$HOST_PURITY_SUITE" ]; then
  HP_OUT=$(bash "$HOST_PURITY_SUITE" 2>&1)
  HP_CODE=$?
  HP_RESULT=$(printf '%s\n' "$HP_OUT" | grep -E '^(RESULT|Results):' | tail -1)
  if [ "$HP_CODE" -eq 0 ]; then
    pass "E-Rc: host-purity DELTA-guard suite exits 0 (#788 regression intact) -- $HP_RESULT"
  else
    printf '%s\n' "$HP_OUT" | grep '^FAIL:' | head -10
    failc "E-Rc" "S2/#788" "host-purity DELTA-guard suite exited $HP_CODE -- $HP_RESULT"
  fi
else
  failc "E-Rc" "S2/#788" "tests/test-issue-788-host-purity-delta.sh missing at $HOST_PURITY_SUITE"
fi

# ══════════════════════════════════════════════════════════════════════════════
# W-E3 — manifest & drift composition (boundary of items 5/6)
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

# ── E3a-x (issue #10, DCR-2 settled IN scope): installed exec bit on the 4 ────
# new methodology-step scripts. init.sh:93 copies via plain `cp` (no -p), so
# mode preservation is umask/platform-adjacent, not guaranteed by install
# logic; the Post-Merge Cleanup [MUST] wrapper invokes
# ./scripts/cleanup/cleanup-issue.sh <N> directly and the allow-list entry
# Bash(./scripts/cleanup/cleanup-issue.sh:*) presumes a +x delivered file.
echo "== E3a-x (issue #10): installed exec bit set on the 4 new methodology-step script dests =="
if [ "$DRIVE_PASS" -eq 1 ]; then
  NOT_EXEC=""
  for _xdest in \
    "scripts/preflight/scan-cross-issue-recurrence.sh" \
    "scripts/handoff/emit-cycle-digest.sh" \
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
    pass "E3a-x: all 4 new methodology-step script dests are installed with the execute bit set"
  else
    failc "E3a-x" "#10" "dest(s) missing or not executable in installed target:$NOT_EXEC"
  fi
else
  failc "E3a-x" "#10" "prerequisite install failed"
fi

# ── E3a-y (issue #10, cycle 2, review-response Finding 1): actually EXECUTE ──
# the installed emit-cycle-digest.sh against the fresh dummy target with
# synthesized minimal state, confirming docs/cycle-digest.jsonl creation and
# the path:line stdout. E3a-x above checks only existence + exec bit, not
# execution -- reviewer-cited coverage gap. Placed after E1d's POST_LIST
# capture (:392) so the files this arm creates (docs/cycle-digest.jsonl,
# .autoflow/*) are not in E1d's newly-created-path scan set (verification
# design §3 RR2-AC3 ordering note).
echo "== E3a-y (issue #10 c2): installed emit-cycle-digest.sh executes on a docs-less fresh target =="
if [ "$DRIVE_PASS" -eq 1 ] && [ -f "$DUMMY/scripts/handoff/emit-cycle-digest.sh" ]; then
  if [ -e "$DUMMY/docs/cycle-digest.jsonl" ]; then
    failc "E3a-y" "#10" "precondition violated -- $DUMMY/docs/cycle-digest.jsonl already exists before the run"
  else
    mkdir -p "$DUMMY/.autoflow"
    cat > "$DUMMY/.autoflow/issue-0.json" <<'EOF'
{ "issue": "#0", "cycle": 1, "date": "2026-07-16", "mode": "new-issue", "phases": {} }
EOF
    : > "$DUMMY/.autoflow/ledger.md"
    E3AY_OUT=$(cd "$DUMMY" && bash scripts/handoff/emit-cycle-digest.sh \
      .autoflow/issue-0.json .autoflow/ledger.md "" 2>&1)
    E3AY_CODE=$?
    if [ "$E3AY_CODE" -eq 0 ] && [ -f "$DUMMY/docs/cycle-digest.jsonl" ] \
      && [ "$E3AY_OUT" = "docs/cycle-digest.jsonl:1" ] \
      && jq -e . < "$DUMMY/docs/cycle-digest.jsonl" >/dev/null 2>&1; then
      pass "E3a-y: installed emit-cycle-digest.sh creates docs/cycle-digest.jsonl on a docs-less target and prints docs/cycle-digest.jsonl:1"
    else
      failc "E3a-y" "#10" "exit=$E3AY_CODE stdout='$E3AY_OUT' file-exists=$([ -f "$DUMMY/docs/cycle-digest.jsonl" ] && echo yes || echo no)"
    fi
  fi
else
  failc "E3a-y" "#10" "prerequisite install failed or emit-cycle-digest.sh not installed"
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

echo "== E3d: injected content drift -> installed drift-check.sh exits 1 with D1 class (non-vacuity) =="
make_dummy_target "$DRIFT_DUMMY"
if [ -f "$INIT_SH" ]; then
  bash "$INIT_SH" --target "$DRIFT_DUMMY" </dev/null >/dev/null 2>&1
  _dd_code=$?
else
  _dd_code=1
fi
DRIFT_TARGET_SH="$DRIFT_DUMMY/.claude/autoflow/drift-check.sh"
if [ "$_dd_code" -eq 0 ] && [ -f "$DRIFT_TARGET_SH" ]; then
  _mutate_target="$DRIFT_DUMMY/.claude/autoflow/METHODOLOGY.md"
  if [ -f "$_mutate_target" ]; then
    printf '\nDRIFT_MUTATION_E3D\n' >> "$_mutate_target"
    E3D_OUT=$(CLAUDE_PROJECT_DIR="$DRIFT_DUMMY" sh "$DRIFT_TARGET_SH" 2>&1)
    E3D_CODE=$?
    if [ "$E3D_CODE" -ne 0 ] && printf '%s\n' "$E3D_OUT" | grep -qF 'D1'; then
      pass "E3d: injected content drift caught by the installed detector (non-zero, D1 class)"
    elif [ "$E3D_CODE" -ne 0 ]; then
      pass "E3d: injected content drift caught by the installed detector (non-zero exit)"
    else
      failc "E3d" "S5/#792" "installed detector exited 0 after content mutation (drift not caught -- vacuity risk)"
    fi
  else
    failc "E3d" "S5/#792" "METHODOLOGY.md missing in DRIFT_DUMMY -- cannot mutate for D1 arm"
  fi
else
  failc "E3d" "S5/#792" "install into DRIFT_DUMMY failed (exit $_dd_code) or detector absent"
fi

# ══════════════════════════════════════════════════════════════════════════════
# W-E4 — single-repo HANDOFF gate behavior (gate hook scores-gated admit/deny
# branches, resolved via CLAUDE_PROJECT_DIR=<dummy> against the plugin-package
# hook copy, HOOK=$REPO_ROOT/plugin/autoflow/hooks/... at :98). The plugin-
# delivered hook RESOLUTION seam (${CLAUDE_PLUGIN_ROOT} substitution / decoy)
# is covered behaviorally by verify-package.sh AC4 (:230-298), NOT here --
# E4w below only asserts that the install-time wiring landed (issue-797
# review-response cycle 2, Codex Medium finding 1 / :98,:516).
# ══════════════════════════════════════════════════════════════════════════════

mkdir -p "$DUMMY/.autoflow"
GATE_STATE="$DUMMY/.autoflow/issue-999.json"
DUMMY_SETTINGS="$DUMMY/.claude/settings.json"

echo "== E4w: post-init.sh target settings.json landed the plugin-enable wiring =="
if [ "$DRIVE_PASS" -eq 1 ] && assert_plugin_enabled "$DUMMY_SETTINGS"; then
  pass "E4w: \$DUMMY/.claude/settings.json carries enabledPlugins + extraKnownMarketplaces for autoflow@autoflow"
else
  failc "E4w" "single-repo-HANDOFF" "assert_plugin_enabled failed on $DUMMY_SETTINGS -- settings-pin merge wiring did not land"
fi

echo "== E4w-nv: negative self-test -- assert_plugin_enabled() FAILs on a tampered settings copy =="
if [ -f "$DUMMY_SETTINGS" ]; then
  jq 'del(.enabledPlugins["autoflow@autoflow"])' "$DUMMY_SETTINGS" > "$SETTINGS_NV" 2>/dev/null
  if ! assert_plugin_enabled "$SETTINGS_NV"; then
    pass "E4w-nv: assert_plugin_enabled() rejects a settings copy with enabledPlugins dropped (E4w's predicate discriminates)"
  else
    failc "E4w-nv" "single-repo-HANDOFF" "assert_plugin_enabled() wrongly accepted a settings copy with enabledPlugins dropped -- E4w would be vacuous"
  fi
else
  failc "E4w-nv" "single-repo-HANDOFF" "$DUMMY_SETTINGS missing -- cannot build the tampered scratch copy"
fi

echo "== E4x (issue #963 AC1 E-leg): post-init.sh target settings.json carries the Agent Teams enablement env =="
if [ "$DRIVE_PASS" -eq 1 ] && [ -f "$DUMMY_SETTINGS" ] && jq -e '.env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS == "1"' "$DUMMY_SETTINGS" >/dev/null 2>&1; then
  pass "E4x: \$DUMMY/.claude/settings.json carries env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS == \"1\""
else
  failc "E4x" "single-repo-HANDOFF" "jq -e '.env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS == \"1\"' failed on $DUMMY_SETTINGS -- settings-pin does not ship the Agent Teams enablement env (issue #963)"
fi

echo "== E4x-nv (issue #963): negative self-test -- the env predicate FAILs on a settings copy with .env dropped =="
if [ -f "$DUMMY_SETTINGS" ]; then
  jq 'del(.env)' "$DUMMY_SETTINGS" > "$SETTINGS_NV" 2>/dev/null
  if ! jq -e '.env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS == "1"' "$SETTINGS_NV" >/dev/null 2>&1; then
    pass "E4x-nv: env predicate rejects a settings copy with .env dropped (E4x's predicate discriminates)"
  else
    failc "E4x-nv" "single-repo-HANDOFF" "env predicate wrongly accepted a settings copy with .env dropped -- E4x would be vacuous"
  fi
else
  failc "E4x-nv" "single-repo-HANDOFF" "$DUMMY_SETTINGS missing -- cannot build the tampered scratch copy"
fi

echo "== E4a: seeded PASS state -> gh pr create admitted via the gate hook's scores-gated branch =="
cat > "$GATE_STATE" <<'STATEPASS'
{"active": true, "issue": "#999", "phases": {"audit": {"scores": {"a": {"score": 8}, "b": {"score": 8}}}, "gate_quality": {"scores": {"a": {"score": 8}, "b": {"score": 8}}}}}
STATEPASS
if [ -f "$HOOK" ]; then
  E4A_OUT=$(printf '%s' "$(gate_bash_json 'gh pr create --draft --title t --body-file b.md')" | CLAUDE_PROJECT_DIR="$DUMMY" bash "$HOOK" 2>&1)
  E4A_CODE=$?
  if [ "$E4A_CODE" -eq 0 ]; then
    pass "E4a: gate hook admits gh pr create with PASS scores (exit 0)"
  else
    failc "E4a" "single-repo-HANDOFF" "gate hook denied gh pr create with PASS scores (exit $E4A_CODE): $E4A_OUT"
  fi
else
  failc "E4a" "single-repo-HANDOFF" "gate hook missing at $HOOK"
fi

echo "== E4b: gh pr merge denied unconditionally via the gate hook's scores-gated branch =="
if [ -f "$HOOK" ]; then
  E4B_OUT=$(printf '%s' "$(gate_bash_json 'gh pr merge 999 --squash')" | CLAUDE_PROJECT_DIR="$DUMMY" bash "$HOOK" 2>&1)
  E4B_CODE=$?
  if [ "$E4B_CODE" -eq 2 ]; then
    pass "E4b: gate hook denies gh pr merge (exit 2)"
  else
    failc "E4b" "single-repo-HANDOFF" "gate hook did not deny gh pr merge (exit $E4B_CODE)"
  fi
else
  failc "E4b" "single-repo-HANDOFF" "gate hook missing at $HOOK"
fi

echo "== E4c: git push origin main denied while active:true via the gate hook's scores-gated branch =="
if [ -f "$HOOK" ]; then
  E4C_OUT=$(printf '%s' "$(gate_bash_json 'git push origin main')" | CLAUDE_PROJECT_DIR="$DUMMY" bash "$HOOK" 2>&1)
  E4C_CODE=$?
  if [ "$E4C_CODE" -eq 2 ]; then
    pass "E4c: gate hook denies default-branch push (exit 2)"
  else
    failc "E4c" "single-repo-HANDOFF" "gate hook did not deny default-branch push (exit $E4C_CODE)"
  fi
else
  failc "E4c" "single-repo-HANDOFF" "gate hook missing at $HOOK"
fi

echo "== E4d: NOT-passing AUDIT/GATE:QUALITY scores -> gh pr create denied via the gate hook's scores-gated branch =="
cat > "$GATE_STATE" <<'STATEFAIL'
{"active": true, "issue": "#999", "phases": {"audit": {"scores": {}}, "gate_quality": {"scores": {}}}}
STATEFAIL
if [ -f "$HOOK" ]; then
  E4D_OUT=$(printf '%s' "$(gate_bash_json 'gh pr create --draft --title t --body-file b.md')" | CLAUDE_PROJECT_DIR="$DUMMY" bash "$HOOK" 2>&1)
  E4D_CODE=$?
  if [ "$E4D_CODE" -eq 2 ]; then
    pass "E4d: gate hook denies gh pr create with unscored AUDIT/GATE:QUALITY (exit 2)"
  else
    failc "E4d" "single-repo-HANDOFF" "gate hook did not deny gh pr create with unscored gates (exit $E4D_CODE)"
  fi
else
  failc "E4d" "single-repo-HANDOFF" "gate hook missing at $HOOK"
fi

echo "== E4-claim: claim-accuracy self-check -- retired over-claim phrase absent, corrected claim + AC4 cross-reference present =="
# Built from split literals so the retired phrase never appears CONTIGUOUS
# anywhere in this suite's own source (self-grep safety: the guard must not
# self-match its own pattern definition -- GATE:PLAN Feasibility caveat).
_E4CLAIM_HOOK_TOKEN="installed[- ]gate[- ]hook"
_E4CLAIM_COMP_A="installed-hook"
_E4CLAIM_COMP_B=" composition"
_E4CLAIM_PATTERN="${_E4CLAIM_HOOK_TOKEN}|${_E4CLAIM_COMP_A}${_E4CLAIM_COMP_B}"
SELF_ABS="$REPO_ROOT/$SELF_PATH_REL"
_e4claim_ok=1
if [ -f "$SELF_ABS" ] && grep -inE "$_E4CLAIM_PATTERN" "$SELF_ABS" >/dev/null 2>&1; then
  failc "E4-claim" "single-repo-HANDOFF" "a retired over-claim phrase still survives (whole-suite phrase sweep) in $SELF_ABS"
  _e4claim_ok=0
fi
if ! grep -A8 '^# W-E4 ' "$SELF_ABS" 2>/dev/null | grep -qF 'verify-package.sh AC4'; then
  failc "E4-claim" "single-repo-HANDOFF" "W-E4 region is missing the verify-package.sh AC4 cross-reference"
  _e4claim_ok=0
fi
if ! grep -A8 '^# W-E4 ' "$SELF_ABS" 2>/dev/null | grep -qF 'scores-gated admit/deny'; then
  failc "E4-claim" "single-repo-HANDOFF" "W-E4 region is missing the corrected claim wording (scores-gated admit/deny)"
  _e4claim_ok=0
fi
[ "$_e4claim_ok" -eq 1 ] && pass "E4-claim: no over-claim phrase survives, and the corrected claim + AC4 cross-reference are present"

echo "== E4e: installed docs/autoflow-guide.md documents the single-repo no-blocked-by-subrepo rule =="
INSTALLED_GUIDE="$DUMMY/.claude/autoflow/docs/autoflow-guide.md"
if [ -f "$INSTALLED_GUIDE" ]; then
  if grep -qF 'zero submodules' "$INSTALLED_GUIDE" \
     && grep -qF 'no `blocked-by-subrepo` label' "$INSTALLED_GUIDE"; then
    pass "E4e: installed methodology copy documents the single-repo zero-submodule no-blocked-by-subrepo rule"
  else
    failc "E4e" "single-repo-HANDOFF" "installed autoflow-guide.md lacks the single-repo no-blocked-by-subrepo Merge-Sequencing text"
  fi
else
  failc "E4e" "single-repo-HANDOFF" "installed docs/autoflow-guide.md missing at $INSTALLED_GUIDE"
fi

# ══════════════════════════════════════════════════════════════════════════════
# W-E4' — HOST-runtime label observation (item-7 runtime gap)
# ══════════════════════════════════════════════════════════════════════════════
# create-host-pr.sh is #!/usr/bin/env bash and builds argv with a bash array
# (args=(...) at create-host-pr.sh:47) -- run under bash explicitly, never
# sourced into / run under this suite's POSIX-sh body. Absent from
# setup/manifest.json: never installed into a target (host-script runtime,
# distinct from the E4w/E4a-e gate-hook scores-branch arms above).

echo "== E4f: --no-subrepo-dep host invocation carries --draft + blocked-by-review, NOT blocked-by-subrepo =="
if [ -f "$CREATE_HOST_PR" ]; then
  PATH="$MOCK_GH_DIR:$PATH" GH_INVOCATION_LOG="$GH_LOG_F" \
    bash "$CREATE_HOST_PR" --issue 999 --title "E2E dummy-target test" --body-file "$BODY_FILE" --no-subrepo-dep >/dev/null 2>&1
  E4F_CODE=$?
  if [ "$E4F_CODE" -eq 0 ]; then
    if grep -qFx -- '--draft' "$GH_LOG_F" \
       && grep -qFx -- 'blocked-by-review' "$GH_LOG_F" \
       && ! grep -qFx -- 'blocked-by-subrepo' "$GH_LOG_F"; then
      pass "E4f: --no-subrepo-dep argv carries --draft + blocked-by-review, omits blocked-by-subrepo"
    else
      failc "E4f" "single-repo-HANDOFF" "argv did not match expected single-repo label set: $(cat "$GH_LOG_F" | tr '\n' ' ')"
    fi
  else
    failc "E4f" "single-repo-HANDOFF" "create-host-pr.sh --no-subrepo-dep exited $E4F_CODE"
  fi
else
  failc "E4f" "single-repo-HANDOFF" "scripts/handoff/create-host-pr.sh missing at $CREATE_HOST_PR"
fi

echo "== E4g: contrast arm (no --no-subrepo-dep) -> blocked-by-subrepo IS present (non-vacuity) =="
if [ -f "$CREATE_HOST_PR" ]; then
  PATH="$MOCK_GH_DIR:$PATH" GH_INVOCATION_LOG="$GH_LOG_G" \
    bash "$CREATE_HOST_PR" --issue 999 --title "E2E dummy-target test" --body-file "$BODY_FILE" >/dev/null 2>&1
  E4G_CODE=$?
  if [ "$E4G_CODE" -eq 0 ] && grep -qFx -- 'blocked-by-subrepo' "$GH_LOG_G"; then
    pass "E4g: default (no --no-subrepo-dep) invocation carries blocked-by-subrepo -- proves E4f's absence is flag-caused"
  else
    failc "E4g" "single-repo-HANDOFF" "default invocation did not carry blocked-by-subrepo (exit $E4G_CODE; log: $(cat "$GH_LOG_G" | tr '\n' ' '))"
  fi
else
  failc "E4g" "single-repo-HANDOFF" "scripts/handoff/create-host-pr.sh missing at $CREATE_HOST_PR"
fi

echo "== E4h: no-merge invariant across BOTH the E4f and E4g invocations -- gh stub records no gh pr merge =="
if [ -f "$CREATE_HOST_PR" ]; then
  if log_has_merge "$GH_LOG_F"; then
    failc "E4h" "single-repo-HANDOFF" "gh stub recorded a 'merge' token in the E4f (--no-subrepo-dep) HANDOFF invocation"
  elif log_has_merge "$GH_LOG_G"; then
    failc "E4h" "single-repo-HANDOFF" "gh stub recorded a 'merge' token in the E4g (default) HANDOFF invocation"
  else
    pass "E4h: gh stub recorded no 'gh pr merge' in EITHER HANDOFF entrypoint invocation (E4f + E4g)"
  fi
else
  failc "E4h" "single-repo-HANDOFF" "scripts/handoff/create-host-pr.sh missing at $CREATE_HOST_PR"
fi

echo "== E4h-nv: non-vacuity self-test -- a synthesized E4f-window merge token IS detected by log_has_merge() =="
printf 'merge\n' > "$GH_LOG_NV"
if log_has_merge "$GH_LOG_NV"; then
  pass "E4h-nv: log_has_merge() detects a synthesized merge token in the E4f-window log (E4h's real code path is exercised)"
else
  failc "E4h-nv" "single-repo-HANDOFF" "log_has_merge() failed to detect a synthesized merge token -- E4h's no-merge check would be vacuous"
fi

# ══════════════════════════════════════════════════════════════════════════════
# W-E5 — generalization-defect capture discipline (item 8)
# ══════════════════════════════════════════════════════════════════════════════

echo "== E5a: F3 manual-scenarios-797.md exists, prescribes the live-cycle pilot + defect-recording template =="
if [ -f "$MANUAL_SCENARIOS" ]; then
  _e5a_ok=1
  if ! grep -qiE 'PREFLIGHT|HANDOFF|full.*cycle|live.*cycle' "$MANUAL_SCENARIOS"; then
    failc "E5a" "single-repo-HANDOFF" "F3 lacks live-LLM-cycle pilot step prescription"
    _e5a_ok=0
  fi
  if ! grep -qiE 'generalization.defect' "$MANUAL_SCENARIOS" || ! grep -qiE 'S-stage|S[0-9]|#[0-9]' "$MANUAL_SCENARIOS"; then
    failc "E5a" "single-repo-HANDOFF" "F3 lacks a generalization-defect -> S-stage/#-issue recording template"
    _e5a_ok=0
  fi
  if ! grep -qiE 'NOT.automated|not automated' "$MANUAL_SCENARIOS"; then
    failc "E5a" "single-repo-HANDOFF" "F3 does not explicitly mark deferred steps NOT-automated"
    _e5a_ok=0
  fi
  [ "$_e5a_ok" -eq 1 ] && pass "E5a: F3 exists and covers live-pilot steps, defect-recording template, and NOT-automated marking"
else
  failc "E5a" "single-repo-HANDOFF" "tests/plugin/manual-scenarios-797.md missing at $MANUAL_SCENARIOS"
fi

echo "== E5b: failc() self-attributes -- forced failure emits both the AC id and the owning-stage tag =="
E5B_OUT=$(failc 'E5B-SELFTEST' 'S2/#788' 'synthetic self-test failure (forced, not a real defect)')
if printf '%s\n' "$E5B_OUT" | grep -qF 'E5B-SELFTEST' && printf '%s\n' "$E5B_OUT" | grep -qF '[stage:S2/#788]'; then
  pass "E5b: failc() emits both the failing AC id and the owning-stage tag on a forced failure (self-attributing)"
else
  failc "E5b" "single-repo-HANDOFF" "failc() self-test did not emit expected AC id + stage tag; output=$E5B_OUT"
fi

# ══════════════════════════════════════════════════════════════════════════════
# W-R — regression (baseline unaffected)
# ══════════════════════════════════════════════════════════════════════════════

echo "== E-Ra: verify-install-into-target.sh whole-suite regression =="
if [ -f "$VERIFY_INSTALL" ]; then
  VI_OUT=$(sh "$VERIFY_INSTALL" 2>&1)
  VI_CODE=$?
  VI_RESULT=$(printf '%s\n' "$VI_OUT" | grep '^RESULT:' | head -1)
  if [ "$VI_CODE" -eq 0 ]; then
    pass "E-Ra: verify-install-into-target.sh exits 0 (#792 regression intact) -- $VI_RESULT"
  else
    printf '%s\n' "$VI_OUT" | grep '^FAIL:' | head -10
    failc "E-Ra" "S5/#792" "verify-install-into-target.sh exited $VI_CODE -- $VI_RESULT"
  fi
else
  failc "E-Ra" "S5/#792" "tests/plugin/verify-install-into-target.sh missing at $VERIFY_INSTALL"
fi

echo "== E-Rb: verify-package.sh whole-suite regression =="
if [ -f "$VERIFY_PACKAGE" ]; then
  VP_OUT=$(sh "$VERIFY_PACKAGE" 2>&1)
  VP_CODE=$?
  VP_RESULT=$(printf '%s\n' "$VP_OUT" | grep '^RESULT:' | head -1)
  if [ "$VP_CODE" -eq 0 ]; then
    pass "E-Rb: verify-package.sh exits 0 (#790 regression intact) -- $VP_RESULT"
  else
    printf '%s\n' "$VP_OUT" | grep '^FAIL:' | head -10
    failc "E-Rb" "S5/#792" "verify-package.sh exited $VP_CODE -- $VP_RESULT"
  fi
else
  failc "E-Rb" "S5/#792" "tests/plugin/verify-package.sh missing at $VERIFY_PACKAGE"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo "=============================================="
echo "RESULT: $PASS_COUNT passed, $FAIL_COUNT failed, $SKIP_COUNT skipped (of $((PASS_COUNT + FAIL_COUNT)) checks)"
if [ "$FAIL_COUNT" -gt 0 ]; then
  exit 1
fi
exit 0
